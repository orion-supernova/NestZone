import ComposableArchitecture
import ConvexMobile
import Foundation
import Testing
@testable import NestZone

/// The companion on the server: what it sends, how the screen takes it, and
/// what is sent back. Driven through `TestStore` with a stubbed
/// `CompanionClient`; the stores run non-exhaustively, because `State` carries
/// a dozen values worked out from the rest (`refresh`) and the tests are about
/// the house, the card and the writes.
@MainActor
@Suite("Companion on the server")
struct CompanionServerTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func house(leaves: Int = 150, sparkles: Int = 180, current: Companion? = nil) -> CompanionHouse {
        var house = CompanionHouse()
        house.leaves = leaves
        house.sparkles = sparkles
        house.welcomed = true
        house.current = current
        return house
    }

    private func growing(id: String = "a", species: Species = .magnolia, ready: Bool = false) -> Companion {
        var companion = Companion(species: species, seed: "h-0", startedAt: Self.now.addingTimeInterval(-8 * 86_400))
        companion.id = id
        companion.points = ready ? 64 : 20
        companion.isReady = ready
        companion.pointsReady = ready
        return companion
    }

    private func store(
        _ served: CompanionHouse,
        client: CompanionClient = CompanionClient(),
        clock: TestClock<Duration> = TestClock(),
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

    /// A push of the house, as the server would deliver it.
    private func push(_ house: CompanionHouse) -> CompanionFeature.Action {
        .served(CompanionServed(house: house))
    }

    /// Moves a `TestClock` on in small steps with yields between them, and a
    /// little further than asked. The sleeper that is being waited for is
    /// started by a task of its own, so it may register after the first
    /// step; stepping reaches it however late it does.
    private func advance(_ clock: TestClock<Duration>, by total: Duration, steps: Int = 10) async {
        let step = total / steps
        for _ in 0..<(steps * 2) {
            await Task.megaYield()
            await clock.advance(by: step)
        }
        await Task.megaYield()
    }

    private func waitUntil(_ condition: @Sendable () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
    }

    // MARK: Buying

    private func buyStore(
        gates: [Gate<BuyOutcome>], ids: LockIsolated<[String]> = .init([]), clock: TestClock<Duration> = TestClock()
    ) -> TestStoreOf<CompanionFeature> {
        let calls = LockIsolated(0)
        var client = CompanionClient()
        client.buy = { _, _, requestID, _ in
            ids.withValue { $0.append(requestID) }
            let call = calls.withValue { n -> Int in defer { n += 1 }; return n }
            return try await gates[min(call, gates.count - 1)].wait()
        }
        return store(house(), client: client, clock: clock)
    }

    private func tapBuy(_ store: TestStoreOf<CompanionFeature>) async {
        await store.send(.itemTapped(.decor(.bow)))
        await store.send(.cardBuyTapped)
    }

    @Test("Bought: debited at once, and still debited when the answer folds in")
    func bought() async {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        // In flight: the answer has not come.
        #expect(store.state.house.leaves == 90)
        #expect(store.state.writes.buys.count == 1)
        #expect(store.state.card?.isBought == true)
        gate.release(.bought(paid: Coins(leaves: 60, sparkles: 0), madeUp: nil, jar: Coins(leaves: 90, sparkles: 180), replay: false))
        await store.receive(\.buyAnswered)
        #expect(store.state.served.leaves == 90)
        #expect(store.state.served.owned.contains("bow"))
        #expect(store.state.writes.buys.isEmpty)
        #expect(store.state.card?.isBought == true)
        #expect(store.state.house.leaves == 90)
    }

    @Test("Bought, with no jar in the answer: the entry comes off and the item is owned")
    func boughtWithoutJar() async {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        gate.release(.bought(paid: Coins(leaves: 60, sparkles: 0), madeUp: nil, jar: nil, replay: false))
        await store.receive(\.buyAnswered)
        #expect(store.state.served.leaves == 150)
        #expect(store.state.writes.buys.isEmpty)
        #expect(store.state.served.owned.contains("bow"))
    }

    @Test("Bought, the push first: the answer's jar does not overwrite the served one")
    func boughtPushFirst() async {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        var pushed = house(leaves: 90)
        pushed.owned.insert("bow")
        await store.send(push(pushed))
        #expect(store.state.house.leaves == 90)
        gate.release(.bought(paid: Coins(leaves: 60, sparkles: 0), madeUp: nil, jar: Coins(leaves: 999, sparkles: 0), replay: false))
        await store.receive(\.buyAnswered)
        #expect(store.state.served.leaves == 90)
        #expect(store.state.house.leaves == 90)
    }

    @Test("Owned: rolled back, and the card says it is the house's")
    func owned() async {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        gate.release(.owned)
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        #expect(store.state.card?.purchase == nil)
        #expect(store.state.card?.isBought == false)
        #expect(store.state.served.owned.contains("bow"))
    }

    @Test("Short: rolled back, and the card shows what is missing")
    func short() async throws {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        gate.release(.short(sparkles: 40, price: .leaves(60)))
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        let card = try #require(store.state.card)
        #expect(store.state.step(of: card) == .short(sparkles: 40))
    }

    @Test("Unavailable: rolled back, with a notice on the card")
    func unavailable() async {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        gate.release(.unavailable)
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        #expect(store.state.card?.notice == .unavailable)
    }

    @Test("Price changed: rolled back, and the card asks again at the server's price")
    func priceChanged() async throws {
        let gate = Gate<BuyOutcome>()
        let store = buyStore(gates: [gate])
        await tapBuy(store)
        gate.release(.priceChanged(.leaves(80)))
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        let card = try #require(store.state.card)
        #expect(card.purchase?.price == .leaves(80))
        #expect(store.state.step(of: card) == .pay(Coins(leaves: 80, sparkles: 0)))
    }

    @Test("A lost answer rolls back, and tapping again is the same request id")
    func retryKeepsItsRequestID() async {
        let ids = LockIsolated<[String]>([])
        let first = Gate<BuyOutcome>(), second = Gate<BuyOutcome>()
        let store = buyStore(gates: [first, second], ids: ids)
        await tapBuy(store)
        first.fail(AppError.offline)
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        #expect(store.state.card?.notice == .offline)
        await store.send(.cardBuyTapped)
        #expect(store.state.house.leaves == 90)
        second.release(.bought(paid: Coins(leaves: 60, sparkles: 0), madeUp: nil, jar: Coins(leaves: 90, sparkles: 180), replay: true))
        await store.receive(\.buyAnswered)
        #expect(ids.value.count == 2)
        #expect(ids.value[0] == ids.value[1])
        #expect(store.state.card?.isBought == true)
    }

    @Test("A purchase of something else is a new request id")
    func newTapNewID() async {
        let ids = LockIsolated<[String]>([])
        let first = Gate<BuyOutcome>(), second = Gate<BuyOutcome>()
        let store = buyStore(gates: [first, second], ids: ids)
        await tapBuy(store)
        first.release(.unavailable)
        await store.receive(\.buyAnswered)
        await store.send(.itemTapped(.decor(.terracotta)))
        await store.send(.cardBuyTapped)
        second.release(.unavailable)
        await store.receive(\.buyAnswered)
        #expect(Set(ids.value).count == 2)
    }

    @Test("A write that never answers is rolled back when the clock reaches 15 seconds")
    func timeout() async {
        let clock = TestClock<Duration>()
        var client = CompanionClient()
        // A call that never returns and ignores cancellation, as the real one does.
        // Parked, not dropped: a dropped continuation is a leak the runtime reports.
        let parked = LockIsolated<[CheckedContinuation<Void, Never>]>([])
        let entered = LockIsolated(false)
        client.buy = { _, _, _, _ in
            await withCheckedContinuation { continuation in
                parked.withValue { $0.append(continuation) }
                entered.setValue(true)
            }
            return .owned
        }
        let store = store(house(), client: client, clock: clock)
        await tapBuy(store)
        #expect(store.state.house.leaves == 90)
        await waitUntil { entered.value }
        await advance(clock, by: .seconds(15))
        await store.receive(\.buyAnswered)
        #expect(store.state.house.leaves == 150)
        #expect(store.state.writes.buys.isEmpty)
        #expect(store.state.card?.notice == .offline)
        // The tap's id is kept: a retry is the same purchase.
        #expect(store.state.retry != nil)
    }

    // MARK: Care, layout and holidays roll back

    @Test("Care: the check is there in flight and gone when the write fails")
    func careRollsBack() async {
        let gate = Gate<Bool>()
        var client = CompanionClient()
        client.care = { _ in try await gate.wait() }
        let store = store(house(current: growing()), client: client)
        await store.send(.careTapped)
        #expect(store.state.caredToday)
        gate.fail(AppError.offline)
        await store.receive(\.careAnswered)
        #expect(!store.state.caredToday)
        #expect(store.state.writes.care == nil)
        #expect(store.state.alert == nil)
    }

    @Test("Care: a counted one is folded in and stays")
    func careFolds() async {
        let gate = Gate<Bool>()
        var client = CompanionClient()
        client.care = { _ in try await gate.wait() }
        let store = store(house(current: growing()), client: client)
        await store.send(.careTapped)
        gate.release(true)
        await store.receive(\.careAnswered)
        #expect(store.state.caredToday)
        #expect(store.state.writes.care == nil)
    }

    @Test("Decorate: the layout is there in flight and put back when the write fails")
    func layoutRollsBack() async {
        let gate = Gate<SceneLayout>()
        var client = CompanionClient()
        client.setLayout = { _, _ in try await gate.wait() }
        let store = store(house(current: growing()), client: client)
        await store.send(.decorateTapped)
        await store.send(.spotPicked(.left))
        await store.send(.decorToggled(DecorItem.wateringCan.rawValue))
        await store.send(.decorateDone)
        #expect(store.state.house.layout.left == DecorItem.wateringCan.rawValue)
        gate.fail(AppError.server("no"))
        await store.receive(\.layoutAnswered)
        #expect(store.state.house.layout.left == nil)
        #expect(store.state.alert != nil)
    }

    @Test("Holidays: the choice is there in flight and put back when the write fails")
    func holidaysRollBack() async {
        let gate = Gate<[String]?>()
        var client = CompanionClient()
        client.setHolidays = { _, _ in try await gate.wait() }
        let store = store(house(current: growing()), client: client)
        await store.send(.holidayToggled(.halloween))
        #expect(store.state.house.holidays != nil)
        gate.fail(AppError.server("no"))
        await store.receive(\.holidaysAnswered)
        #expect(store.state.house.holidays == nil)
        #expect(store.state.alert != nil)
    }

    // MARK: Graduating

    private func graduatingStore(gate: Gate<Coins?>, clock: TestClock<Duration> = TestClock()) -> TestStoreOf<CompanionFeature> {
        var client = CompanionClient()
        client.graduate = { _, _ in try await gate.wait() }
        return store(house(current: growing(id: "a", ready: true)), client: client, clock: clock)
    }

    private var graduated: CompanionHouse {
        var house = house(leaves: 250, sparkles: 205)
        house.albumCount = 1
        return house
    }

    @Test("Graduate: shown at once, answered, and let go when the push has the next one")
    func graduateSucceeds() async {
        let gate = Gate<Coins?>()
        let store = graduatingStore(gate: gate)
        await store.send(.ceremonyFinished)
        #expect(store.state.current == nil)
        #expect(store.state.house.leaves == 250)
        #expect(store.state.sheet == .choose)
        gate.release(Coins(leaves: 100, sparkles: 25))
        await store.receive(\.graduateAnswered)
        // Waiting for the push that shows it.
        #expect(store.state.writes.graduating?.isAnswered == true)
        #expect(store.state.house.leaves == 250)
        await store.send(push(graduated))
        #expect(store.state.writes.graduating == nil)
        #expect(store.state.house.leaves == 250)
    }

    @Test("Graduate fails: it is back on Today, ready, with an alert")
    func graduateFails() async {
        let gate = Gate<Coins?>()
        let store = graduatingStore(gate: gate)
        await store.send(.ceremonyFinished)
        gate.fail(AppError.server("Not grown up yet"))
        await store.receive(\.graduateAnswered)
        #expect(store.state.writes.graduating == nil)
        #expect(store.state.current?.id == "a")
        #expect(store.state.isReady)
        #expect(store.state.sheet == nil)
        #expect(store.state.lastPay == nil)
        #expect(store.state.alert != nil)
    }

    @Test("Graduate: a lost answer the push already shows is not an error")
    func graduateTransportFailureShownByPush() async {
        let gate = Gate<Coins?>()
        let store = graduatingStore(gate: gate)
        await store.send(.ceremonyFinished)
        await store.send(push(graduated))
        gate.fail(AppError.offline)
        await store.receive(\.graduateAnswered)
        #expect(store.state.writes.graduating == nil)
        #expect(store.state.alert == nil)
        #expect(store.state.house.albumCount == 1)
    }

    // MARK: Start

    @Test("A failed start takes the companion and the welcome back")
    func startFails() async {
        let gate = Gate<StartOutcome>()
        var client = CompanionClient()
        client.start = { _, _, _, _ in try await gate.wait() }
        var served = CompanionHouse()
        served.welcomed = false
        let store = store(served, client: client)
        await store.send(.chose(.sunflower))
        #expect(store.state.house.current?.species == .sunflower)
        #expect(store.state.house.leaves == 150)
        #expect(store.state.sheet == .welcome)
        gate.fail(AppError.server("no"))
        await store.receive(\.startAnswered)
        #expect(store.state.house.current == nil)
        #expect(store.state.house.leaves == 0)
        #expect(store.state.sheet == nil)
        #expect(store.state.alert != nil)
    }

    @Test("A start whose answer is lost is retried with the same request id")
    func startRetryKeepsID() async {
        let ids = LockIsolated<[String]>([])
        let first = Gate<StartOutcome>(), second = Gate<StartOutcome>()
        var client = CompanionClient()
        client.start = { _, _, _, requestID in
            let call = ids.withValue { ids -> Int in ids.append(requestID); return ids.count }
            return try await (call == 1 ? first : second).wait()
        }
        let store = store(house(), client: client)
        await store.send(.chose(.sunflower))
        first.fail(AppError.offline)
        await store.receive(\.startAnswered)
        #expect(store.state.writes.start == nil)
        await store.send(.alert(.dismiss))
        await store.send(.chose(.sunflower))
        second.release(StartOutcome(companionID: "n"))
        await store.receive(\.startAnswered)
        #expect(ids.value.count == 2)
        #expect(ids.value[0] == ids.value[1])
    }

    @Test("An old choice never makes a later one a replay")
    func staleStartAttempt() async {
        let store = store(house()) { $0.startAttempt = .init(species: .fern, requestID: "old") }
        await store.send(push(house(current: growing(id: "z", species: .sunflower))))
        #expect(store.state.startAttempt == nil)
    }

    @Test("Choosing over a ready one: the graduation under the start plays once, after a pause")
    func startWithGraduated() async {
        let clock = TestClock<Duration>()
        let gate = Gate<StartOutcome>()
        var client = CompanionClient()
        client.start = { _, _, _, _ in try await gate.wait() }
        let store = store(house(current: growing(id: "a", ready: true)), client: client, clock: clock)
        await store.send(.chose(.sunflower))
        gate.release(StartOutcome(
            companionID: "b",
            graduated: GraduatedCompanion(companionID: "a", species: .magnolia, paid: Coins(leaves: 100, sparkles: 25))
        ))
        await store.receive(\.startAnswered)
        #expect(store.state.moment?.species == .magnolia)
        #expect(store.state.lastPay?.coins == Coins(leaves: 100, sparkles: 25))
        // Not in the same breath: the pause lets whatever was closing close.
        #expect(store.state.sheet == nil)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.momentReady)
        #expect(store.state.sheet == .ceremony)
        await store.send(.momentDismissed)
        #expect(store.state.moment == nil)
        #expect(store.state.sheet == nil)
    }

    private func momentStore(
        clock: TestClock<Duration>, configure: @escaping (inout CompanionFeature.State) -> Void
    ) -> TestStoreOf<CompanionFeature> {
        store(house(current: growing(id: "a", ready: true)), clock: clock) { state in
            state.writes.start = .init(
                species: .sunflower, seed: "h-1", startedAt: Self.now, previous: state.served.current,
                welcome: false, floater: nil, previousPay: nil, since: Self.now
            )
            configure(&state)
        }
    }

    private var startAnswer: CompanionFeature.Action {
        .startAnswered(.success(StartOutcome(
            companionID: "b",
            graduated: GraduatedCompanion(companionID: "a", species: .magnolia, paid: Coins(leaves: 100, sparkles: 25))
        )))
    }

    @Test("A graduation under a start waits for the open sheet to close")
    func momentWaitsForTheSheet() async {
        let clock = TestClock<Duration>()
        let store = momentStore(clock: clock) { $0.sheet = .shop }
        await store.send(startAnswer)
        #expect(store.state.moment != nil)
        #expect(store.state.sheet == .shop)
        await advance(clock, by: .seconds(5))
        #expect(store.state.sheet == .shop)
        await store.send(.sheetDismissed)
        #expect(store.state.sheet == nil)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.momentReady)
        #expect(store.state.sheet == .ceremony)
        // Closing the ceremony ends it, and it does not come back.
        await store.send(.sheetDismissed)
        #expect(store.state.moment == nil)
        #expect(store.state.sheet == nil)
    }

    @Test("It does not play over a Decorate that is about to open")
    func momentWaitsForADelayedSheet() async {
        let clock = TestClock<Duration>()
        let store = momentStore(clock: clock) { $0.pendingSheet = .decorate }
        await store.send(startAnswer)
        #expect(store.state.moment != nil)
        #expect(!store.state.momentScheduled)
        await store.send(.decorateTapped)
        #expect(store.state.sheet == .decorate)
        #expect(!store.state.momentScheduled)
        await store.send(.sheetDismissed)
        await advance(clock, by: .milliseconds(450))
        await store.receive(\.momentReady)
        #expect(store.state.sheet == .ceremony)
    }

    // MARK: Entries that outlive their answer

    @Test("An answered start goes when the served companion moves on, or after a while")
    func settleBackstops() {
        var writes = CompanionFeature.State.Writes()
        writes.start = .init(
            species: .fern, seed: "s", startedAt: Self.now, previous: growing(id: "a"), welcome: false,
            floater: nil, previousPay: nil, companionID: "b", since: Self.now
        )
        // Served still shows the old one: it waits.
        writes.settle(against: house(current: growing(id: "a")), now: Self.now.addingTimeInterval(10))
        #expect(writes.start != nil)
        // Somebody else moved on: it goes.
        var moved = writes
        moved.settle(against: house(current: growing(id: "c", species: .sunflower)), now: Self.now.addingTimeInterval(10))
        #expect(moved.start == nil)
        // Nothing ever came: it goes after its patience.
        writes.settle(against: house(current: growing(id: "a")), now: Self.now.addingTimeInterval(500))
        #expect(writes.start == nil)
    }

    // MARK: The stream

    @Test("A stream that ended is opened again after a wait that grows")
    func streamBackoff() async {
        let clock = TestClock<Duration>()
        var client = CompanionClient()
        client.forHome = { _ in .never }
        let store = store(house(), client: client, clock: clock)
        await store.send(.streamEnded(retry: true))
        #expect(store.state.streamRetries == 1)
        await advance(clock, by: .seconds(2))
        await store.receive(\.task)
        await store.send(.streamEnded(retry: true))
        #expect(store.state.streamRetries == 2)
        await advance(clock, by: .seconds(4))
        await store.receive(\.task)
        // A delivery resets it.
        await store.send(push(house()))
        #expect(store.state.streamRetries == 0)
        // A deterministic failure is not retried.
        await store.send(.streamEnded(retry: false))
        #expect(store.state.streamRetries == 0)
    }

    // MARK: Readiness and the Lab

    @Test("Ready is the server's word, with its date for the days not yet passed")
    func readiness() {
        var state = CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)"), now: Self.now)
        var companion = growing()
        companion.points = 64
        companion.pointsReady = true
        companion.isReady = false
        companion.readyAt = Self.now.addingTimeInterval(86_400)
        state.served = house(current: companion)
        state.refresh()
        #expect(!state.isReady)
        state.served.current?.isReady = true
        state.refresh()
        #expect(state.isReady)
    }

    @Test("The server's view of the shop ignores the Lab's day and purchases")
    func serverShopIgnoresLab() {
        var state = CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)"), now: Self.now)
        state.served = house()
        state.$lab.withLock {
            $0.date = Self.now.addingTimeInterval(200 * 86_400)
            $0.owned = ["kilim"]
            $0.leaves = 10_000
        }
        #expect(state.shop.standing(of: DecorItem.kilim) == .have)
        #expect(state.serverShop.standing(of: DecorItem.kilim) != .have)
        #expect(!state.serverAvailable.contains("kilim"))
        var draft = SceneLayout()
        draft.ground = "kilim"
        #expect(state.serverSafe(draft).ground == nil)
    }

    // MARK: The payload

    @Test("A companion without an id is unreadable, not absent")
    func unreadableCurrent() throws {
        let json = #"{"catalogVersion":"x","graduateAt":64,"house":null,"current":{"seed":"s"},"recent":[],"jar":[]}"#
        let payload = try JSONDecoder().decode(CompanionPayload.self, from: Data(json.utf8))
        #expect(payload.isUnreadable)
        #expect(payload.current == nil)
        #expect(CompanionServed(payload).isUnreadable)
    }

    @Test("Unknown kinds and a bad row degrade their own rows")
    func lenientRows() throws {
        let json = #"""
        {"catalogVersion":"x","graduateAt":64,"house":null,"current":null,
         "recent":[{"kind":"hug","at":1000,"userId":null},{"kind":"chore","at":2000,"userId":"u"},{"nope":1}],
         "jar":[{"id":"j","kind":"gift","leaves":1,"sparkles":0,"item":null,"userId":null,"at":3}]}
        """#
        let payload = try JSONDecoder().decode(CompanionPayload.self, from: Data(json.utf8))
        #expect(!payload.isUnreadable)
        #expect(payload.recent.map(\.kind) == [.other, .chore])
        #expect(payload.jar.map(\.kind) == [.other])
        let cards = try JSONDecoder().decode(
            CompanionPayload.Cards.self,
            from: Data(#"[{"uuid":"U","species":"fern","seed":"s","startedAt":1,"graduatedAt":2},{"bad":true}]"#.utf8)
        )
        #expect(cards.cards.count == 1)
    }

    // MARK: Arguments

    private func object(_ args: [String: ConvexEncodable?]) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(try args.convexEncode().utf8)) as? [String: Any])
    }

    @Test("What setPlace and start send")
    func placeAndStartArguments() throws {
        let place = Place(tzOffset: 180, region: "TR")
        let setPlace = try object(.setPlace("h", place))
        #expect(Set(setPlace.keys) == ["homeId", "tzOffset", "region"])
        let start = try object(.start("h", .fern, place, "req-1234"))
        #expect(Set(start.keys) == ["homeId", "species", "requestId", "tzOffset", "region"])
        #expect(start["requestId"] as? String == "req-1234")
        let noRegion = try object(.setPlace("h", Place(tzOffset: 0, region: nil)))
        #expect(Set(noRegion.keys) == ["homeId", "tzOffset"])
    }

    @Test("Every spot of a layout is sent, the empty ones as null")
    func layoutArguments() throws {
        var layout = SceneLayout()
        layout.left = "wateringCan"
        layout.tree = ["fairyLights"]
        let args = try object(.setLayout("h", layout))
        let sent = try #require(args["layout"] as? [String: Any])
        #expect(Set(sent.keys) == ["above", "sky", "weather", "tree", "wearing", "pot", "left", "right", "ground"])
        #expect(sent["left"] as? String == "wateringCan")
        #expect(sent["sky"] is NSNull)
        #expect(sent["tree"] as? [String] == ["fairyLights"])
    }

    @Test("What the import sends: no Sparkles, and only what the file has")
    func importArguments() throws {
        var file = CompanionHouse()
        file.leaves = 40
        file.sparkles = 500
        file.welcomed = true
        file.current = Companion(species: .fern, seed: "s", startedAt: Self.now)
        let args = try object(.importLocal("h", LocalCompanion(file), Place(tzOffset: 180, region: "TR")))
        #expect(args["sparkles"] == nil)
        #expect(args["holidays"] == nil)
        #expect(args["leaves"] as? Int == 40)
        #expect(args["homeId"] as? String == "h")
        #expect((args["current"] as? [String: Any])?["species"] as? String == "fern")
        #expect(args["tzOffset"] != nil)
    }

    // MARK: The old file

    @Test("The MVP's file is offered once per person and home, and never changed")
    func importMark() throws {
        let home = HomeID("test-home-\(UUID().uuidString)")
        let url = LocalCompanion.file(home)
        var file = CompanionHouse()
        file.leaves = 40
        try JSONEncoder().encode(file).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let defaults = UserDefaults(suiteName: "nestie-test-\(UUID().uuidString)")!

        let me: UserID = "me", other: UserID = "other"
        #expect(LocalCompanion.pending(for: home, userID: me, defaults: defaults)?.leaves == 40)
        LocalCompanion.markOffered(home, userID: me, defaults: defaults)
        #expect(LocalCompanion.pending(for: home, userID: me, defaults: defaults) == nil)
        // Another person on the same phone has their own to make.
        #expect(LocalCompanion.pending(for: home, userID: other, defaults: defaults) != nil)
        // The file is still there.
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Only a request that never got through leaves the import unmarked")
    func transportFailures() {
        #expect(AppError.offline.isTransport)
        #expect(AppError.notAuthenticated.isTransport)
        #expect(!AppError.server("closed").isTransport)
        #expect(!AppError.decoding("x").isTransport)
    }
}

/// An answer the test hands out when it chooses, so what the screen shows
/// while a write is in flight can be read.
final class Gate<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var result: Result<T, any Error>?

    func wait() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let ready = lock.withLock { () -> Result<T, any Error>? in
                if let result { return result }
                self.continuation = continuation
                return nil
            }
            if let ready { continuation.resume(with: ready) }
        }
    }

    func release(_ value: T) { finish(.success(value)) }
    func fail(_ error: any Error) { finish(.failure(error)) }

    private func finish(_ outcome: Result<T, any Error>) {
        let waiting = lock.withLock { () -> CheckedContinuation<T, any Error>? in
            result = outcome
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume(with: outcome)
    }
}
