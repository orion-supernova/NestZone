import ComposableArchitecture
import Foundation
import Testing
@testable import NestZone

/// The order events happen in, recorded by whatever fake is under test.
private actor Events {
    private(set) var log: [String] = []
    func add(_ event: String) { log.append(event) }
}

private struct FakeTransaction: SparkleTransaction {
    let signedTransaction: String
    let events: Events

    func finish() async { await events.add("finish") }
}

/// The jar's top-up and the finishing of a transaction: the server first, and
/// a transaction finished only once the server has it.
@Suite("Sparkle settlement")
struct SparkleSettlementTests {
    private func settle(
        answering status: TopUpOutcome.Status?
    ) async -> (events: [String], sent: [String], outcome: TopUpOutcome?, threw: Bool) {
        let events = Events()
        let sent = LockIsolated<[String]>([])
        let settlement = SparkleSettlement { signed in
            sent.withValue { $0.append(signed) }
            await events.add("topUp")
            guard let status else { throw AppError.offline }
            return TopUpOutcome(status: status, sparkles: 300)
        }
        var outcome: TopUpOutcome?
        var threw = false
        do {
            outcome = try await settlement.settle(FakeTransaction(signedTransaction: "jws-1", events: events))
        } catch {
            threw = true
        }
        return (await events.log, sent.value, outcome, threw)
    }

    @Test("credited, already and revoked are finished, after the server answered", arguments: [
        TopUpOutcome.Status.credited, .already, .revoked,
    ])
    func finishes(status: TopUpOutcome.Status) async {
        let result = await settle(answering: status)
        #expect(result.events == ["topUp", "finish"])
        #expect(result.sent == ["jws-1"])
        #expect(result.outcome?.status == status)
    }

    @Test("invalid, and a status this build does not know, are left unfinished", arguments: [
        TopUpOutcome.Status.invalid, .unknown,
    ])
    func keeps(status: TopUpOutcome.Status) async {
        let result = await settle(answering: status)
        #expect(result.events == ["topUp"])
        #expect(!result.threw)
    }

    @Test("a server that cannot be reached leaves it unfinished and says so")
    func offline() async {
        let result = await settle(answering: nil)
        #expect(result.events == ["topUp"])
        #expect(result.threw)
    }

    @Test("the purchase's account token is the same for the same user, and a v5 UUID")
    func accountToken() throws {
        let first = try #require(SparkleAccount.token(for: "jh7abc"))
        #expect(first == SparkleAccount.token(for: "jh7abc"))
        #expect(first != SparkleAccount.token(for: "jh7abd"))
        #expect(first.uuidString[first.uuidString.index(first.uuidString.startIndex, offsetBy: 14)] == "5")
        #expect(SparkleAccount.token(for: nil) == nil)
        #expect(SparkleAccount.token(for: "") == nil)
        // The server derives the same token (`ACCOUNT_TOKEN_VECTOR`,
        // backend/convex/lib/jar.ts); if the two drift, every top-up is refused.
        #expect(
            SparkleAccount.token(for: "jh7abc123def456ghi789jkl0mn1pq2r")
                == UUID(uuidString: "d04f2213-14a2-506a-8069-fc02089326a9")
        )
    }

    @Test("only the signed-in buyer's transactions are credited")
    func wrongUserSkipped() throws {
        let me = try #require(SparkleAccount.token(for: "me"))
        let other = try #require(SparkleAccount.token(for: "someone-else"))
        #expect(SparkleStoreKit.accepts(me, signedInAs: me))
        #expect(!SparkleStoreKit.accepts(other, signedInAs: me))
        #expect(!SparkleStoreKit.accepts(other, signedInAs: nil))
        // No token: StoreKit testing in Xcode, which only Debug takes.
        #if DEBUG
        #expect(SparkleStoreKit.accepts(nil, signedInAs: me))
        #else
        #expect(!SparkleStoreKit.accepts(nil, signedInAs: me))
        #endif
    }

    @Test("a purchase that was already credited elsewhere is not a success")
    func alreadyIsNotAWin() throws {
        let id = "com.walhallaa.NestZone.sparkles.300"
        #expect(try TopUpOutcome(status: .credited, sparkles: 300).sparklesForPurchase(of: id) == 300)
        #expect(try TopUpOutcome(status: .credited, sparkles: 0).sparklesForPurchase(of: id) == 300)
        #expect(try TopUpOutcome(status: .already, sparkles: 300).sparklesForPurchase(of: id) == 300)
        #expect(throws: SparkleStoreError.refused) { try TopUpOutcome(status: .already, sparkles: 0).sparklesForPurchase(of: id) }
        #expect(throws: SparkleStoreError.refused) { try TopUpOutcome(status: .invalid).sparklesForPurchase(of: id) }
        #expect(throws: SparkleStoreError.notConfirmed) { try TopUpOutcome(status: .unknown).sparklesForPurchase(of: id) }
    }

    @Test("a product id says how many Sparkles it is")
    func productSparkles() {
        #expect(SparklePack.sparkles(inProduct: "com.walhallaa.NestZone.sparkles.2200") == 2200)
        #expect(SparklePack.sparkles(inProduct: "com.walhallaa.NestZone.sparkles.7") == 0)
    }

    @Test("best value is worked out from the real prices")
    func bestValue() {
        let packs = [
            SparklePack(id: "a", sparkles: 300, displayPrice: "₺99", price: 99),
            SparklePack(id: "b", sparkles: 1000, displayPrice: "₺250", price: 250),
        ]
        #expect(SparklePack.bestValue(packs) == "b")
        #expect(SparklePack.bestValue([packs[0], SparklePack(id: "c", sparkles: 5000, displayPrice: nil)]) == nil)
    }
}

/// The purchase card's store: what each way of buying a pack ends in.
@MainActor
@Suite("Sparkle store in the companion")
struct SparkleStoreFeatureTests {
    private nonisolated static let pack = SparklePack(id: "com.walhallaa.NestZone.sparkles.300", sparkles: 300, displayPrice: "$2.99", price: 2.99)

    private func store(
        client: SparkleStoreClient,
        clock: TestClock<Duration> = TestClock(),
        configure: (inout CompanionFeature.State) -> Void = { _ in }
    ) -> TestStoreOf<CompanionFeature> {
        var state = CompanionFeature.State(homeID: HomeID("h-\(UUID().uuidString)"), now: Date(timeIntervalSince1970: 1_800_000_000), region: "TR")
        state.served.sparkles = 10
        state.served.welcomed = true
        state.isLoaded = true
        state.storeOpen = true
        configure(&state)
        state.refresh()
        let store = TestStore(initialState: state) {
            CompanionFeature()
        } withDependencies: {
            $0.sparkleStore = client
            $0.continuousClock = clock
        }
        store.exhaustivity = .off
        return store
    }

    @Test("packs are asked for once and kept")
    func loadedOnce() async {
        let calls = LockIsolated(0)
        var client = SparkleStoreClient()
        client.packs = {
            calls.withValue { $0 += 1 }
            return [Self.pack]
        }
        let store = store(client: client)
        await store.send(.storeAppeared)
        await store.receive(\.packsLoaded)
        #expect(store.state.packs == [Self.pack])
        await store.send(.storeAppeared)
        #expect(calls.value == 1)
    }

    @Test("a store that cannot be asked says so, and can be asked again")
    func unavailable() async {
        let answer = LockIsolated<[SparklePack]?>(nil)
        var client = SparkleStoreClient()
        client.packs = {
            guard let packs = answer.value else { throw AppError.offline }
            return packs
        }
        let store = store(client: client)
        await store.send(.storeAppeared)
        await store.receive(\.packsUnavailable)
        #expect(store.state.packsUnavailable)
        answer.setValue([Self.pack])
        await store.send(.storeAppeared)
        await store.receive(\.packsLoaded)
        #expect(!store.state.packsUnavailable)
        #expect(store.state.packs == [Self.pack])
    }

    @Test("the purchase is sent the house and the user, and what the server credited lands without touching the Lab")
    func bought() async {
        let seen = LockIsolated<[String]>([])
        var client = SparkleStoreClient()
        client.purchase = { id, home, user in
            seen.withValue { $0 = [id, home.rawValue, user ?? "-"] }
            return .added(300)
        }
        let store = store(client: client) { $0.userID = UserID("u-1") }
        let home = store.state.homeID.rawValue
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        #expect(seen.value == [Self.pack.id, home, "u-1"])
        #expect(store.state.landed == 300)
        #expect(store.state.landedTick == 1)
        #expect(store.state.buyingPack == nil)
        #expect(store.state.lab.sparkles == 0)
    }

    @Test("the test store's Sparkles go to the Lab, which is not the server")
    func preview() async {
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .preview(300) }
        let store = store(client: client)
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        #expect(store.state.lab.sparkles == 300)
        #expect(store.state.landed == 300)
    }

    @Test("Ask to Buy waits, and says so")
    func askToBuy() async {
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .pending }
        let store = store(client: client)
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        #expect(store.state.packNote == .init(id: Self.pack.id, kind: .waiting))
        #expect(store.state.landed == nil)
    }

    @Test("backing out of the purchase sheet leaves no trace")
    func cancelled() async {
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .cancelled }
        let store = store(client: client)
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        #expect(store.state.packNote == nil)
        #expect(store.state.buyingPack == nil)
    }

    @Test("each way a purchase fails has its own note", arguments: [
        (SparkleStoreError.notConfirmed as SparkleStoreError?, CompanionFeature.State.PackNote.Kind.retrying),
        (.unverified, .unverified),
        (.refused, .unverified),
        (.unavailable, .failed),
        (nil, .failed),
    ])
    func failed(error: SparkleStoreError?, kind: CompanionFeature.State.PackNote.Kind) async {
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in throw error ?? CancellationError() }
        let store = store(client: client)
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packFailed)
        #expect(store.state.packNote == .init(id: Self.pack.id, kind: kind))
        #expect(store.state.buyingPack == nil)
        #expect(store.state.landed == nil)
    }

    @Test("a real purchase stays in the store while the jar still shows too little")
    func staysUntilTheJarCatchesUp() async {
        let clock = TestClock()
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .added(300) }
        let store = store(client: client, clock: clock) {
            $0.pending = .init(item: .decor(.bow), priceOverride: .sparkles(200))
        }
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        // The answer is in, the live read is not: 10 Sparkles, 200 asked.
        await clock.advance(by: .milliseconds(1300))
        await store.receive(\.storeReturned)
        #expect(store.state.storeOpen)
        #expect(store.state.pending != nil)
    }

    @Test("a push that arrives after the beat has looked still sends the store back")
    func latePush() async {
        let clock = TestClock()
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .added(300) }
        let store = store(client: client, clock: clock) {
            $0.pending = .init(item: .decor(.bow), priceOverride: .sparkles(200))
        }
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        await clock.advance(by: .milliseconds(1300))
        await store.receive(\.storeReturned)
        #expect(store.state.storeOpen)
        // The read that brings the Sparkles comes late.
        var house = CompanionHouse()
        house.sparkles = 310
        house.welcomed = true
        await store.send(.served(CompanionServed(house: house)))
        await clock.advance(by: .milliseconds(600))
        await store.receive(\.storeReturned)
        #expect(!store.state.storeOpen)
        #expect(store.state.pending == nil)
    }

    @Test("a real purchase goes back to the card once the jar shows enough")
    func returnsOnceTheJarHasIt() async {
        let clock = TestClock()
        var client = SparkleStoreClient()
        client.purchase = { _, _, _ in .added(300) }
        let store = store(client: client, clock: clock) {
            $0.served.sparkles = 310
            $0.pending = .init(item: .decor(.bow), priceOverride: .sparkles(200))
        }
        await store.send(.packTapped(Self.pack))
        await store.receive(\.packBought)
        await clock.advance(by: .milliseconds(1300))
        await store.receive(\.storeReturned)
        #expect(!store.state.storeOpen)
        #expect(store.state.pending == nil)
    }

    @Test("purchases that finish elsewhere land in the open store, and only there")
    func arrived() async {
        var client = SparkleStoreClient()
        client.credits = { _, _ in AsyncStream { $0.yield(1000); $0.finish() } }
        let store = store(client: client) { $0.packNote = .init(id: Self.pack.id, kind: .waiting) }
        await store.send(.watchPurchases)
        await store.receive(\.sparklesArrived)
        #expect(store.state.landed == 1000)
        #expect(store.state.packNote == nil)

        await store.send(.storeDismissed)
        await store.send(.sparklesArrived(300))
        #expect(store.state.landed == nil)
    }
}
