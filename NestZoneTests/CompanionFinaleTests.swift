import ComposableArchitecture
import ConvexMobile
import Foundation
import Testing
@testable import NestZone

/// The finale: "you've grown them all", and growing a favourite again in a
/// new colour. Driven through `TestStore` like the rest of the companion's
/// reducer tests, non-exhaustively.
@MainActor
@Suite("Companion finale")
struct CompanionFinaleTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// A house that has grown every free species but `except`.
    private func house(except: Species? = nil, finaleAt: Date? = nil, current: Companion? = nil) -> CompanionHouse {
        var house = CompanionHouse()
        house.leaves = 150
        house.sparkles = 180
        house.welcomed = true
        house.grown = Species.freeToHave.subtracting(except.map { [$0] } ?? [])
        house.finaleAt = finaleAt
        house.current = current
        return house
    }

    private func growing(id: String = "a", species: Species = .sunflower, ready: Bool = true) -> Companion {
        var companion = Companion(species: species, seed: "h-0", startedAt: Self.now.addingTimeInterval(-8 * 86_400))
        companion.id = id
        companion.points = ready ? 64 : 20
        companion.isReady = ready
        companion.pointsReady = ready
        return companion
    }

    private func store(
        _ served: CompanionHouse, client: CompanionClient = CompanionClient(), clock: TestClock<Duration> = TestClock(),
        configure: (inout CompanionFeature.State) -> Void = { _ in }
    ) -> TestStoreOf<CompanionFeature> {
        var state = CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)"), now: Self.now, region: "TR")
        state.served = served
        state.isLoaded = true
        state.hasRead = true
        state.placeTold = true
        state.importTried = true
        configure(&state)
        state.refresh()
        let store = TestStore(initialState: state) {
            CompanionFeature()
        } withDependencies: {
            $0.companion = client
            $0.continuousClock = clock
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    private func advance(_ clock: TestClock<Duration>, by total: Duration, steps: Int = 10) async {
        let step = total / steps
        for _ in 0..<(steps * 2) {
            await Task.megaYield()
            await clock.advance(by: step)
        }
        await Task.megaYield()
    }

    private let finaleStartAnswer: CompanionFeature.Action = .startAnswered(.success(StartOutcome(
        companionID: "b",
        graduated: GraduatedCompanion(companionID: "a", species: .sunflower, paid: Coins(leaves: 100, sparkles: 25), finale: true)
    )))

    // MARK: The moment

    private func startingStore(clock: TestClock<Duration>, sheet: CompanionFeature.State.Sheet?) -> TestStoreOf<CompanionFeature> {
        store(house(except: .sunflower, current: growing()), clock: clock) { state in
            state.writes.start = .init(
                species: .kitten, seed: "h-1", startedAt: Self.now, previous: state.served.current,
                welcome: false, floater: nil, previousPay: nil, since: Self.now
            )
            state.sheet = sheet
        }
    }

    @Test("The finale under a start is held while a sheet is open, then plays once")
    func finaleHeldBehindASheet() async {
        let clock = TestClock<Duration>()
        let store = startingStore(clock: clock, sheet: .shop)
        await store.send(finaleStartAnswer)
        let moment = store.state.moment
        #expect(moment?.isFinale == true)
        #expect(moment?.isFinaleOnly == false)
        // The album it shows counts the one that just graduated, though the push has not said so.
        #expect(moment?.grown.contains(.sunflower) == true)
        #expect(moment?.grown.count == Species.freeToHave.count)
        #expect(store.state.sheet == .shop)
        await advance(clock, by: .seconds(5))
        #expect(store.state.sheet == .shop)
        await store.send(.sheetDismissed)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.momentReady)
        #expect(store.state.sheet == .ceremony)
        await store.send(.sheetDismissed)
        #expect(store.state.moment == nil)
        await advance(clock, by: .seconds(2))
        #expect(store.state.sheet == nil)
    }

    @Test("It does not play over a sheet that is about to open")
    func finaleWaitsForAPendingSheet() async {
        let clock = TestClock<Duration>()
        let store = store(house(except: .sunflower, current: growing()), clock: clock) { state in
            state.writes.start = .init(
                species: .kitten, seed: "h-1", startedAt: Self.now, previous: state.served.current,
                welcome: false, floater: nil, previousPay: nil, since: Self.now
            )
            state.pendingSheet = .decorate
        }
        await store.send(finaleStartAnswer)
        #expect(store.state.moment?.isFinale == true)
        #expect(!store.state.momentScheduled)
        await advance(clock, by: .seconds(2))
        #expect(store.state.sheet == nil)
    }

    @Test("A finale reported again by a retry is not played twice")
    func finaleKeyedOnTheGraduatedCompanion() async {
        let clock = TestClock<Duration>()
        let store = store(house(except: .sunflower, current: growing()), clock: clock) { state in
            state.finalesHeld = ["a"]
            state.writes.start = .init(
                species: .kitten, seed: "h-1", startedAt: Self.now, previous: state.served.current,
                welcome: false, floater: nil, previousPay: nil, since: Self.now
            )
        }
        await store.send(finaleStartAnswer)
        #expect(store.state.moment == nil)
        await advance(clock, by: .seconds(2))
        #expect(store.state.sheet == nil)
    }

    @Test("The ceremony on Today ends with the answer saying finale: the finale plays alone, then Choose opens")
    func finaleAfterTheCeremonyOnToday() async {
        let clock = TestClock<Duration>()
        let gate = Gate<GraduateOutcome>()
        var client = CompanionClient()
        client.graduate = { _, _ in try await gate.wait() }
        let store = store(house(except: .sunflower, current: growing()), client: client, clock: clock)
        await store.send(.celebrateTapped)
        #expect(store.state.sheet == .ceremony)
        await store.send(.ceremonyFinished)
        // One person: Choose is already on its way up, optimistically.
        #expect(store.state.sheet == .choose)
        gate.release(GraduateOutcome(paid: Coins(leaves: 100, sparkles: 25), finale: true))
        await store.receive(\.graduateAnswered)
        #expect(store.state.moment?.isFinaleOnly == true)
        #expect(store.state.afterMoment == .choose)
        #expect(store.state.sheet == nil)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.momentReady)
        #expect(store.state.sheet == .ceremony)
        await store.send(.momentDismissed)
        #expect(store.state.moment == nil)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.presentPending)
        #expect(store.state.sheet == .choose)
        #expect(store.state.afterMoment == nil)
    }

    @Test("A graduation that is not the finale plays no finale")
    func ordinaryGraduation() async {
        let clock = TestClock<Duration>()
        let store = startingStore(clock: clock, sheet: nil)
        await store.send(.startAnswered(.success(StartOutcome(
            companionID: "b",
            graduated: GraduatedCompanion(companionID: "a", species: .sunflower, paid: nil)
        ))))
        #expect(store.state.moment?.isFinale == false)
    }

    // MARK: Choose

    @Test("Colours are on offer after the finale, for a species grown, and not before")
    func offering() {
        let before = house(except: .sunflower)
        #expect(!before.hasFinished)
        #expect(!before.offersColours(for: .kitten))
        // The server's word, or the list: a house that finished before the date was written.
        #expect(house(except: .sunflower, finaleAt: Self.now).hasFinished)
        let listed = house()
        #expect(listed.finaleAt == nil && listed.hasFinished)
        #expect(listed.offersColours(for: .kitten))
        // A species the house has not grown is not offered in a colour, even after.
        var after = house(finaleAt: Self.now)
        after.grown.remove(.kitten)
        #expect(!after.offersColours(for: .kitten))
        // Colours stay open once finaleAt is set, though the list no longer covers the catalog.
        after.grown.remove(.cactus)
        #expect(after.hasFinished)
        // Grown colours are not offered again.
        var coloured = house(finaleAt: Self.now)
        coloured.grownColours = ["kitten:2", "puppy:1"]
        #expect(coloured.colours(for: .kitten) == [1, 3])
        #expect(coloured.hasGrown(.kitten, colour: 2))
        #expect(coloured.colours(for: .daisy) == [1, 2, 3])
    }

    @Test("Tapping a grown species asks for its colour after the finale; before it, it just grows")
    func growTappedAsksForAColour() async {
        let finished = store(house(finaleAt: Self.now, current: growing(ready: false)))
        await finished.send(.growTapped(.kitten))
        #expect(finished.state.colourChoice == .kitten)
        #expect(finished.state.writes.start == nil)
        await finished.send(.colourDismissed)
        #expect(finished.state.colourChoice == nil)

        var client = CompanionClient()
        client.start = { _, _, _, _, _ in StartOutcome(companionID: "n") }
        let before = store(house(except: .sunflower, current: growing(ready: false)), client: client)
        await before.send(.growTapped(.kitten))
        #expect(before.state.colourChoice == nil)
        #expect(before.state.writes.start?.species == .kitten)
        #expect(before.state.writes.start?.colour == nil)
    }

    // MARK: A coloured start

    @Test("A coloured start is shown at once, sends its colour, and keeps it when the push agrees")
    func colouredStart() async {
        let gate = Gate<StartOutcome>()
        let sent = LockIsolated<[Int?]>([])
        var client = CompanionClient()
        client.start = { _, _, _, _, colour in
            sent.withValue { $0.append(colour) }
            return try await gate.wait()
        }
        let store = store(house(finaleAt: Self.now, current: growing(ready: false)), client: client)
        await store.send(.colourPicked(.kitten, 2))
        #expect(store.state.house.current?.species == .kitten)
        #expect(store.state.house.current?.colour == 2)
        #expect(store.state.colour == 2)
        gate.release(StartOutcome(companionID: "n"))
        await store.receive(\.startAnswered)
        #expect(sent.value == [2])
        var pushed = house(finaleAt: Self.now)
        var next = growing(id: "n", species: .kitten, ready: false)
        next.colour = 2
        pushed.current = next
        await store.send(.served(CompanionServed(house: pushed)))
        #expect(store.state.writes.start == nil)
        #expect(store.state.colour == 2)
    }

    @Test("A coloured start the server refuses puts the companion back, and says why")
    func colouredStartRefused() async {
        let gate = Gate<StartOutcome>()
        var client = CompanionClient()
        client.start = { _, _, _, _, _ in try await gate.wait() }
        let previous = growing(ready: false)
        let store = store(house(finaleAt: Self.now, current: previous), client: client)
        await store.send(.colourPicked(.kitten, 3))
        #expect(store.state.house.current?.colour == 3)
        gate.fail(AppError.server("[CONVEX M(companion:start)] Server Error\nUncaught Error: That colour can't be grown yet\n  at handler"))
        await store.receive(\.startAnswered)
        #expect(store.state.writes.start == nil)
        #expect(store.state.house.current?.id == previous.id)
        #expect(store.state.house.current?.colour == nil)
        #expect(store.state.colour == nil)
        #expect(store.state.alert != nil)
        // A refusal is an answer: the next try is a new request.
        #expect(store.state.startAttempt == nil)
        #expect(AppError.server("Uncaught Error: That colour can't be grown yet").errorDescription
            == String(localized: L10n.colourRefusedLocked))
        #expect(AppError.server("Uncaught Error: There's no such colour").errorDescription
            == String(localized: L10n.colourRefusedNone))
    }

    @Test("A colour is never sent for a house that has not finished, a species it has not grown, or a colour it has")
    func colourGuards() async {
        let calls = LockIsolated(0)
        var client = CompanionClient()
        client.start = { _, _, _, _, _ in calls.withValue { $0 += 1 }; return StartOutcome(companionID: "n") }
        let early = store(house(except: .sunflower, current: growing(ready: false)), client: client)
        await early.send(.colourPicked(.kitten, 1))
        #expect(early.state.writes.start == nil)
        var done = house(finaleAt: Self.now, current: growing(ready: false))
        done.grownColours = ["kitten:1"]
        let late = store(done, client: client)
        await late.send(.colourPicked(.kitten, 1))
        #expect(late.state.writes.start == nil)
        await late.send(.colourPicked(.kitten, 4))
        #expect(late.state.writes.start == nil)
        #expect(calls.value == 0)
    }

    @Test("A request is the same only for the same species and colour")
    func requestIdentity() async {
        let ids = LockIsolated<[String]>([])
        var client = CompanionClient()
        client.start = { _, _, _, requestID, _ in
            ids.withValue { $0.append(requestID) }
            throw AppError.offline
        }
        let store = store(house(finaleAt: Self.now, current: growing(ready: false)), client: client)
        await store.send(.colourPicked(.kitten, 1))
        await store.receive(\.startAnswered)
        await store.send(.alert(.dismiss))
        await store.send(.colourPicked(.kitten, 1))
        await store.receive(\.startAnswered)
        await store.send(.alert(.dismiss))
        await store.send(.colourPicked(.kitten, 2))
        await store.receive(\.startAnswered)
        #expect(ids.value.count == 3)
        #expect(ids.value[0] == ids.value[1])
        #expect(ids.value[1] != ids.value[2])
    }

    // MARK: Wire

    @Test("The new fields decode, every one optional, and a colour this build does not know is the original")
    func decodes() throws {
        let json = #"""
        {"catalogVersion":"x","graduateAt":64,
         "house":{"leaves":1,"sparkles":2,"welcomed":true,"owned":[],"ownedSpecies":[],"grownSpecies":["kitten","magnolia"],
                  "grownColours":["kitten:2","kitten:3"],"finaleAt":5000,"layout":{},"albumCount":2},
         "current":{"id":"a","seed":"s","species":"kitten","colour":2},
         "recent":[],"jar":[]}
        """#
        let payload = try JSONDecoder().decode(CompanionPayload.self, from: Data(json.utf8))
        let served = CompanionServed(payload)
        #expect(served.house.finaleAt == Date(timeIntervalSince1970: 5))
        #expect(served.house.grownColours == ["kitten:2", "kitten:3"])
        #expect(served.house.current?.colour == 2)
        #expect(!payload.isUnreadable)

        let old = #"""
        {"catalogVersion":"x","graduateAt":64,
         "house":{"leaves":1,"sparkles":2,"owned":[],"ownedSpecies":[],"layout":{},"albumCount":0},
         "current":{"id":"a","seed":"s","species":"kitten"},"recent":[],"jar":[]}
        """#
        let before = CompanionServed(try JSONDecoder().decode(CompanionPayload.self, from: Data(old.utf8)))
        #expect(before.house.finaleAt == nil)
        #expect(before.house.grownColours.isEmpty)
        #expect(before.house.current?.colour == nil)

        let odd = #"""
        {"catalogVersion":"x","graduateAt":64,"house":{"leaves":0,"sparkles":0,"grownColours":"nope","finaleAt":"soon","albumCount":0},
         "current":{"id":"a","seed":"s","species":"kitten","colour":9},"recent":[],"jar":[]}
        """#
        let lenient = try JSONDecoder().decode(CompanionPayload.self, from: Data(odd.utf8))
        #expect(!lenient.isUnreadable)
        #expect(lenient.house?.grownColours == [])
        #expect(lenient.house?.finaleAt == nil)
        #expect(lenient.current?.colour == nil)

        let cards = try JSONDecoder().decode(
            CompanionPayload.Cards.self,
            from: Data(#"[{"uuid":"u","species":"kitten","seed":"s","startedAt":1000,"graduatedAt":2000,"colour":3},{"uuid":"v","species":"kitten","seed":"s","startedAt":1000}]"#.utf8)
        )
        #expect(cards.cards.map(\.colour) == [3, nil])
        #expect(Graduate(cards.cards[0]).colour == 3)
    }

    @Test("A start sends its colour only when there is one")
    func startArguments() throws {
        func object(_ args: [String: ConvexEncodable?]) throws -> [String: Any] {
            try #require(JSONSerialization.jsonObject(with: Data(try args.convexEncode().utf8)) as? [String: Any])
        }
        let place = Place(tzOffset: 180, region: "TR")
        let plain = try object(.start("h", .kitten, place, "r1", nil))
        #expect(Set(plain.keys) == ["homeId", "species", "requestId", "tzOffset", "region"])
        let coloured = try object(.start("h", .kitten, place, "r1", 2))
        #expect(Set(coloured.keys) == ["homeId", "species", "requestId", "tzOffset", "region", "colour"])
        #expect(coloured["colour"] as? Double == 2)
    }

    @Test("Every colour has a name for every species, placeholder or not")
    func colourNames() {
        for species in Species.allCases {
            for colour in Colourway.range {
                #expect(!String(localized: species.colourName(colour)).isEmpty)
            }
        }
    }
}
