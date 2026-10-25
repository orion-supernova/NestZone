#if DEBUG
import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// The Lab's pretend house: that it is kept apart from the real one, and that
/// the stand-in server keeps the rules the card depends on.
@MainActor
@Suite("The Lab's pretend house", .serialized)
struct CompanionLabTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A live client that records every call and refuses it: whatever reaches
    /// it is a write to the real house.
    private func tripwire(_ calls: LockIsolated<[String]>) -> CompanionClient {
        @Sendable func hit(_ name: String) { calls.withValue { $0.append(name) } }
        return CompanionClient(
            forHome: { _ in hit("forHome"); return .never },
            album: { _ in hit("album"); return .never },
            setPlace: { _, _ in hit("setPlace"); throw AppError.offline },
            start: { _, _, _, _, _ in hit("start"); throw AppError.offline },
            care: { _ in hit("care"); throw AppError.offline },
            graduate: { _, _ in hit("graduate"); throw AppError.offline },
            ballot: { _, _, _ in hit("ballot"); throw AppError.offline },
            decide: { _ in hit("decide"); throw AppError.offline },
            setLayout: { _, _ in hit("setLayout"); throw AppError.offline },
            setHolidays: { _, _ in hit("setHolidays"); throw AppError.offline },
            importLocal: { _, _, _ in hit("importLocal"); throw AppError.offline },
            buy: { _, _, _, _ in hit("buy"); throw AppError.offline },
            topUp: { _, _ in hit("topUp"); throw AppError.offline }
        )
    }

    private func hosted(
        pretend: Bool, calls: LockIsolated<[String]>, server: FakeNestieServer,
        configure: (inout CompanionFeature.State) -> Void = { _ in }
    ) -> TestStore<CompanionFeature.State, CompanionFeature.Action> {
        var state = CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)"), now: Self.now, region: "TR")
        state.withLab {
            $0.pretend = pretend
            $0.latency = 0
        }
        configure(&state)
        let store = TestStore(initialState: state) {
            CompanionHost()
        } withDependencies: {
            $0.companion = tripwire(calls)
            $0.pretendHouse = server
            $0.continuousClock = TestClock()
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    private func quickServer(_ scenario: String = "growing") -> FakeNestieServer {
        var arguments = Bench.Arguments()
        arguments.scenario = scenario
        arguments.latency = .zero
        return FakeNestieServer(arguments)
    }

    @Test("In pretend mode no write, and no read, reaches the live client")
    func pretendNeverCallsTheLiveClient() async {
        let calls = LockIsolated<[String]>([])
        let server = quickServer()
        let store = hosted(pretend: true, calls: calls, server: server)

        await store.send(.task)
        await store.receive(\.served)
        #expect(store.state.isLoaded)
        #expect(store.state.species == .magnolia)

        // Care, choosing, buying, decorating, the holidays: the writes.
        await store.send(.careTapped)
        await store.receive(\.careAnswered)
        await store.send(.itemTapped(.decor(.bow)))
        await store.send(.cardBuyTapped)
        await store.receive(\.buyAnswered)
        await store.send(.chose(.kitten))
        await store.receive(\.startAnswered)
        await store.send(.dressTapped(.halloween))
        await store.receive(\.layoutAnswered)
        await store.send(.holidayToggled(.christmas))
        await store.receive(\.holidaysAnswered)
        // The Lab's own controls.
        await store.send(.lab(.command(.setLeaves(7))))
        await store.send(.lab(.command(.fillScene)))

        #expect(calls.value.isEmpty, "the live client was called: \(calls.value)")
        // And it really happened, in the pretend house.
        await Task.yield()
        let house = await server.snapshot()
        #expect(house.owned.contains("bow"))
        #expect(house.current?.species == .kitten)
        #expect(house.holidays != nil)
        await store.skipInFlightEffects()
    }

    @Test("Without the switch the same actions do reach the live client, so the test above can fail")
    func realModeCallsTheLiveClient() async {
        let calls = LockIsolated<[String]>([])
        let server = quickServer()
        let store = hosted(pretend: false, calls: calls, server: server) { state in
            var house = CompanionHouse()
            var companion = Companion(species: .magnolia, seed: "s", startedAt: Self.now.addingTimeInterval(-86_400))
            companion.id = "c"
            house.current = companion
            state.served = house
            state.isLoaded = true
            state.refresh()
        }
        await store.send(.task)
        await store.send(.careTapped)
        await store.receive(\.careAnswered)
        #expect(calls.value.contains("forHome"))
        #expect(calls.value.contains("care"))
        await store.skipInFlightEffects()
    }

    @Test("The Lab's controls do nothing on the real house")
    func labCommandsNeedThePretendHouse() async {
        let calls = LockIsolated<[String]>([])
        let server = quickServer()
        let store = hosted(pretend: false, calls: calls, server: server)
        await store.send(.lab(.command(.setLeaves(999))))
        await store.send(.lab(.preset(.brokeJar)))
        await store.send(.lab(.moment(.welcome)))
        await store.send(.lab(.members(3)))
        let house = await server.snapshot()
        #expect(house.leaves == 150)
        #expect(calls.value.isEmpty)
    }

    @Test("Turning the switch resets the card, and the pretend house stays out of the real one's state")
    func switchResets() async {
        let calls = LockIsolated<[String]>([])
        let server = quickServer()
        let store = hosted(pretend: false, calls: calls, server: server) { state in
            state.served.leaves = 1234
            state.isLoaded = true
        }
        await store.send(.lab(.pretend(true)))
        #expect(store.state.served.leaves == 0)
        #expect(!store.state.isLoaded)
        #expect(store.state.isPretend)
        await store.receive(\.task)
        await store.receive(\.served)
        #expect(store.state.served.leaves == 150)
        #expect(calls.value.isEmpty)
        await store.skipInFlightEffects()
    }

    @Test("The live client's lock is right from the action that flips the switch")
    func lockFollowsTheFlip() async {
        let calls = LockIsolated<[String]>([])
        let store = hosted(pretend: false, calls: calls, server: quickServer())
        await store.send(.lab(.pretend(true)))
        #expect(PretendRoute.isOn, "the flipping action must leave the lock on")
        await store.skipReceivedActions()
        await store.send(.lab(.pretend(false)))
        #expect(!PretendRoute.isOn, "and off again when it is flipped back")
        await store.skipReceivedActions()
        await store.skipInFlightEffects()
    }

    @Test("A real write's request ids and the write tokens survive a round trip through the pretend house")
    func roundTrip() async {
        let calls = LockIsolated<[String]>([])
        let attempt = CompanionFeature.State.BuyAttempt(item: .decor(.bow), price: .leaves(60), requestID: "real-rid")
        let start = CompanionFeature.State.StartAttempt(species: .kitten, colour: nil, requestID: "real-start")
        let store = hosted(pretend: false, calls: calls, server: quickServer()) { state in
            state.retry = attempt
            state.startAttempt = start
            state.writeToken = 7
        }
        await store.send(.lab(.pretend(true)))
        await store.skipReceivedActions()
        #expect(store.state.retry == nil, "the pretend house starts with no request ids of the real one")
        #expect(store.state.startAttempt == nil)
        #expect(store.state.writeToken == 7, "tokens never go back to zero")
        // A preset resets the card again; what was set aside stays aside.
        await store.send(.lab(.preset(.brokeJar)))
        await store.skipReceivedActions()
        #expect(store.state.realHold?.retry == attempt)
        await store.send(.lab(.pretend(false)))
        await store.skipReceivedActions()
        #expect(store.state.retry == attempt, "the same purchase, on a retry")
        #expect(store.state.startAttempt == start)
        #expect(store.state.realHold == nil)
        #expect(store.state.writeToken == 7)
        await store.skipInFlightEffects()
    }

    @Test("An answer from the other house touches nothing: a purchase or a settle this card did not make")
    func strayAnswers() async {
        let calls = LockIsolated<[String]>([])
        let store = hosted(pretend: false, calls: calls, server: quickServer()) { state in
            state.withLab { $0.nextBuy = "short" }
            state.served.vote = CompanionVote(
                pollID: "p", openedAt: Self.now, closesAt: Self.now.addingTimeInterval(3_600),
                options: [.init(id: "cherry")], members: 2
            )
        }
        // No write entry, no card: this answer is not for anything here.
        await store.send(.buyAnswered("stray", .success(.owned)))
        #expect(store.state.labSlot.lab.nextBuy == "short", "the armed answer is not spent by a stray one")
        #expect(store.state.card == nil)
        // No settle was asked: the vote stays open and no note appears.
        await store.send(.decideAnswered(.success(.chosen(winner: "cherry"))))
        #expect(store.state.served.vote?.isOpen == true)
        #expect(store.state.voteNote == nil)
        #expect(!store.state.isDeciding)
    }

    @Test("The stand-in follows the real rule for where the house is")
    func placeRule() {
        var house = PretendState.scenario("growing", now: Self.now)
        house.region = nil
        house.tzOffset = nil
        let filled = house.settle(Place(tzOffset: 60, region: "DE"), now: Self.now)
        #expect(filled)
        #expect(house.region == "DE" && house.tzOffset == 60)
        // The same place again changes nothing, and so does a phone that is travelling soon after.
        let same = house.settle(Place(tzOffset: 60, region: "DE"), now: Self.now)
        #expect(!same)
        house.regionMovedAt = Self.now
        let early = house.settle(Place(tzOffset: 180, region: "TR"), now: Self.now.addingTimeInterval(10 * 86_400))
        #expect(!early)
        #expect(house.region == "DE")
        // Thirty days on, it moves, once.
        let moved = house.settle(Place(tzOffset: 180, region: "TR"), now: Self.now.addingTimeInterval(31 * 86_400))
        #expect(moved)
        #expect(house.region == "TR" && house.tzOffset == 180)
        let again = house.settle(Place(tzOffset: 60, region: "DE"), now: Self.now.addingTimeInterval(32 * 86_400))
        #expect(!again)
    }

    @Test("The pretend house defaults to off")
    func defaultsOff() {
        #expect(CompanionLab().pretend == false)
        #expect(!CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)")).isPretend)
    }

    @Test("An old Lab file (points, coins) reads as a fresh Lab")
    func oldFile() throws {
        let json = #"{"mood":"thirsty","bonus":12,"leaves":200,"sparkles":5,"dusk":true,"birthday":true}"#
        let lab = try JSONDecoder().decode(CompanionLab.self, from: Data(json.utf8))
        #expect(lab == CompanionLab())
        let look = try JSONDecoder().decode(LabLook.self, from: Data(json.utf8))
        #expect(look.mood == .thirsty && look.birthday)
    }

    // MARK: The stand-in server's rules

    @Test("Every preset and scenario builds a house the real payload can read")
    func presetsDecode() {
        for preset in PretendPreset.allCases {
            let payload = preset.state(now: Self.now).payload(now: Self.now)
            #expect(!payload.isUnreadable, "\(preset.rawValue)")
        }
        for name in ["fresh", "growing", "ready", "young", "vote", "voteAlone", "finale", "finaleDone"] {
            #expect(!PretendState.scenario(name, now: Self.now).payload(now: Self.now).isUnreadable, "\(name)")
        }
    }

    @Test("Stage up pays the stage once; jumping to a stage pays nothing")
    func stagePay() {
        var house = PretendState.scenario("growing", now: Self.now)
        let before = house.leaves
        house.apply(.setStage(4), now: Self.now)
        #expect(house.leaves == before)
        #expect(house.stage(of: house.current!) == 4)
        house.apply(.stageUp, now: Self.now)
        #expect(house.leaves == before + Rewards.stage.leaves)
        #expect(house.sparkles == 180 + Rewards.stage.sparkles)
        house.apply(.setStage(2), now: Self.now)
        house.apply(.stageUp, now: Self.now)
        #expect(house.leaves == before + Rewards.stage.leaves, "a stage already paid is not paid twice")
    }

    @Test("Ready needs the points and the days")
    func readiness() {
        var house = PretendState.scenario("young", now: Self.now)
        #expect(!house.isReady(house.current!, now: Self.now))
        house.apply(.makeReady, now: Self.now)
        #expect(house.isReady(house.current!, now: Self.now))
    }

    @Test("A vote of three closes when everyone has answered, or on a deadline, or when someone leaves")
    func voteClosing() {
        var house = PretendState.scenario("growing", now: Self.now)
        house.apply(.setMembers(3), now: Self.now)
        house.apply(.openVote, now: Self.now)
        #expect(house.vote?.others.count == 2)
        #expect(house.current?.undecided == true)
        house.apply(.othersAnswerAll, now: Self.now)
        #expect(house.vote?.isOpen == true)
        for option in house.vote!.options { house.apply(.ballot(member: 0, species: option, answer: true), now: Self.now) }
        #expect(house.vote?.isOpen == false)
        #expect(house.vote?.how == "everyone")
        #expect(house.current?.undecided == false)

        var later = PretendState.scenario("growing", now: Self.now)
        later.apply(.setMembers(2), now: Self.now)
        later.apply(.openVote, now: Self.now)
        later.apply(.ballot(member: 1, species: later.vote!.options[0], answer: true), now: Self.now)
        later.apply(.closeVote(.deadline), now: Self.now)
        #expect(later.vote?.how == "deadline")
        #expect(later.vote?.winner == later.vote?.options[0])

        var leaving = PretendState.scenario("vote", now: Self.now)
        for option in leaving.vote!.options where option != "fern" { leaving.apply(.ballot(member: 0, species: option, answer: false), now: Self.now) }
        leaving.apply(.memberLeaves, now: Self.now)
        #expect(leaving.members == 1)
        #expect(leaving.vote?.isOpen == true || leaving.vote?.how == "moved")
    }

    @Test("A graduation in a house of two opens the vote in the same write")
    func graduationOpensVote() async throws {
        let server = quickServer("ready")
        await server.apply(.setMembers(2))
        let outcome = try await server.client.graduate("h", "companion-1")
        #expect(outcome.vote != nil)
        let house = await server.snapshot()
        #expect(house.current?.undecided == true)
        #expect(house.vote?.isOpen == true)
    }

    @Test("The finale scenario: the last free species graduates into the finale")
    func finale() async throws {
        let server = quickServer("finale")
        let outcome = try await server.client.graduate("h", "companion-1")
        #expect(outcome.finale)
        #expect(await server.snapshot().finaleAt != nil)
    }

    @Test("The next purchase gets the answer the Lab armed, once")
    func forcedBuy() async throws {
        let server = quickServer()
        await server.apply(.nextBuy("short"))
        let first = try await server.client.buy("h", .decor(.bow), "a", .leaves(60))
        guard case .short = first else { Issue.record("expected short, got \(first)"); return }
        let second = try await server.client.buy("h", .decor(.bow), "b", .leaves(60))
        guard case .bought = second else { Issue.record("expected bought, got \(second)"); return }
    }

    @Test("The pretend house is written to its file and read back")
    func persistence() async throws {
        let file = FileManager.default.temporaryDirectory.appending(component: "pretend-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var arguments = Bench.Arguments()
        arguments.latency = .zero
        let server = FakeNestieServer(arguments, file: file)
        await server.apply(.setLeaves(4242))
        try await Task.sleep(for: .milliseconds(600))
        let again = FakeNestieServer(arguments, file: file)
        #expect(await again.snapshot().leaves == 4242)
    }
}
#endif
