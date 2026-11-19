import ComposableArchitecture
import ConvexMobile
import Foundation
import Testing

@testable import NestZone

/// NestZone Plus: the refusal's mapping, the paywall's purchase and restore,
/// and where `MainFeature` sends a free house. Written to be run in Xcode; not
/// run by the agent that wrote them.
@MainActor
@Suite("NestZone Plus")
struct ProTests {

    // MARK: The server's refusal

    @Test("PRO_REQUIRED becomes a refusal naming its feature")
    func mapsRefusal() {
        let data = #"{"code":"PRO_REQUIRED","feature":"calendar"}"#
        let error = ConvexConnection.mapped(ClientError.ConvexError(data: data), at: "events:create")
        #expect(error == .proRequired(.calendar))
        // The paywall answers it; no alert goes over the top.
        #expect(error.isSilent)
    }

    @Test("A feature this build has no name for is a refusal without one")
    func unknownFeature() {
        let data = #"{"code":"PRO_REQUIRED","feature":"somethingNew"}"#
        let error = ConvexConnection.mapped(ClientError.ConvexError(data: data), at: "x:y")
        #expect(error == .proRequired(nil))
    }

    @Test("Any other ConvexError stays a server error")
    func otherErrors() {
        let error = ConvexConnection.mapped(ClientError.ConvexError(data: #"{"code":"NOPE"}"#), at: "x:y")
        #expect(error == .server(#"{"code":"NOPE"}"#))
    }

    @Test("Every server feature name is one the app knows")
    func registry() {
        for name in ["calendar", "finance", "shoppingCategories", "customMovieLists",
                     "archiveNow", "eventFromElsewhere", "expenseFromElsewhere"] {
            #expect(ProFeature(serverName: name) != nil)
        }
        #expect(ProFeature.allCases.count == 7)
    }

    @Test("The end date is checked on the phone as well as on the server")
    func expiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let past = ProStatus(
            ProStatusPayload(pro: true, expiresAt: (1_000_000 - 60) * 1000), now: now
        )
        #expect(!past.isPro)
        let future = ProStatus(
            ProStatusPayload(pro: true, expiresAt: (1_000_000 + 60) * 1000), now: now
        )
        #expect(future.isPro)
        let lifetime = ProStatus(ProStatusPayload(pro: true, expiresAt: nil), now: now)
        #expect(lifetime.isPro)
    }

    // MARK: The paywall

    private static let yearly = PlusPackage(
        id: "$rc_annual", kind: .yearly, price: "$19.99", pricePerMonth: "$1.67", trialDays: 7
    )
    private static let monthly = PlusPackage(id: "$rc_monthly", kind: .monthly, price: "$2.99")

    @Test("The yearly plan is picked first, and a purchase stamps once")
    func purchase() async {
        let bought = LockIsolated<[String]>([])
        let packages = [Self.yearly, Self.monthly]
        let store = TestStore(initialState: PaywallFeature.State(feature: .finance, houseName: "Home")) {
            PaywallFeature()
        } withDependencies: {
            $0.purchases.isAvailable = { true }
            $0.purchases.offering = { packages }
            $0.purchases.purchase = { id, settle in
                bought.withValue { $0.append(id) }
                try await settle()
                return .purchased
            }
            $0.pro.refresh = { ProRefreshResult(active: true) }
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.task)
        await store.receive(\.offeringLoaded) {
            $0.isLoading = false
            $0.packages = packages
            $0.selectedID = "$rc_annual"
        }
        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseFinished) {
            $0.isPurchasing = false
            $0.didSucceed = true
            $0.stamps = 1
        }
        await store.receive(\.delegate.dismiss)
        #expect(bought.value == ["$rc_annual"])
    }

    @Test("A payment the server cannot see yet is left for the listener")
    func notYetCredited() async {
        var state = PaywallFeature.State(feature: nil)
        state.packages = [Self.monthly]
        state.selectedID = Self.monthly.id
        let store = TestStore(initialState: state) { PaywallFeature() } withDependencies: {
            $0.purchases.purchase = { _, _ in throw PurchasesError.notYetCredited }
        }
        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseFinished) {
            $0.isPurchasing = false
            $0.message = .notYetCredited
        }
    }

    @Test("Cancelling the App Store sheet says nothing")
    func cancelled() async {
        var state = PaywallFeature.State(feature: nil)
        state.packages = [Self.monthly]
        state.selectedID = Self.monthly.id
        let store = TestStore(initialState: state) { PaywallFeature() } withDependencies: {
            $0.purchases.purchase = { _, _ in .cancelled }
        }
        await store.send(.purchaseTapped) { $0.isPurchasing = true }
        await store.receive(\.purchaseFinished) { $0.isPurchasing = false }
    }

    @Test("Restoring with a subscription stamps; without one says so")
    func restore() async {
        let active = LockIsolated(true)
        let store = TestStore(initialState: PaywallFeature.State(feature: nil)) { PaywallFeature() } withDependencies: {
            $0.purchases.restore = {}
            $0.pro.refresh = { ProRefreshResult(active: active.value) }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreFinished) {
            $0.isRestoring = false
            $0.didSucceed = true
            $0.stamps = 1
        }
        await store.receive(\.delegate.dismiss)

        active.setValue(false)
        var again = PaywallFeature.State(feature: nil)
        again.didSucceed = false
        let second = TestStore(initialState: again) { PaywallFeature() } withDependencies: {
            $0.purchases.restore = {}
            $0.pro.refresh = { ProRefreshResult(active: false) }
        }
        await second.send(.restoreTapped) { $0.isRestoring = true }
        await second.receive(\.restoreFinished) {
            $0.isRestoring = false
            $0.message = .nothingToRestore
        }
    }

    @Test("A store with no key says plans are unavailable")
    func unavailable() async {
        let store = TestStore(initialState: PaywallFeature.State(feature: .calendar)) { PaywallFeature() } withDependencies: {
            $0.purchases.isAvailable = { false }
        }
        await store.send(.task) {
            $0.isLoading = false
            $0.isUnavailable = true
        }
    }

    // MARK: Where a free house is sent

    @Test("A specific event for a free house is the paywall, not the calendar")
    func eventRoutesToPaywall() async {
        @Shared(.pro) var pro: ProStatus
        $pro.withLock { $0.isPro = false }
        let store = TestStore(initialState: MainFeature.State(homeID: "h1")) { MainFeature() }
        store.exhaustivity = .off

        await store.send(.today(.delegate(.open(.event("e1", CalendarDay(Date()))))))
        await store.receive(\.paywallRequested)
        #expect(store.state.paywall?.feature == .calendar)
        #expect(store.state.today.path.isEmpty)
    }

    @Test("A whole module still opens on its own tab, where its locked screen is")
    func moduleStaysOnItsTab() async {
        @Shared(.pro) var pro: ProStatus
        $pro.withLock { $0.isPro = false }
        let store = TestStore(initialState: MainFeature.State(homeID: "h1")) { MainFeature() }
        store.exhaustivity = .off

        await store.send(.today(.delegate(.open(.module(.finance)))))
        #expect(store.state.selectedTab == .house)
        #expect(store.state.house.selected == .finance)
        #expect(store.state.paywall == nil)
    }

    @Test("A free house's tabs open on what it can use")
    func freeHouseDefaults() async {
        let store = TestStore(initialState: MainFeature.State(
            homeID: "h1", segments: [.plans: .calendar, .house: .finance]
        )) { MainFeature() }
        store.exhaustivity = .off

        await store.send(.proStatus(.delegate(.changed(isPro: false, firstAnswer: true))))
        #expect(store.state.plans.selected == .recipes)
        #expect(store.state.house.selected == .maintenance)
    }

    @Test("Add anything will not file a line as an event for a free house")
    func captureLocksEvent() async {
        @Shared(.pro) var pro: ProStatus
        $pro.withLock { $0.isPro = false }
        let asked = LockIsolated<[ProFeature?]>([])
        let store = TestStore(
            initialState: CaptureFeature.State(homeID: "h1", currentUserID: nil, members: [])
        ) { CaptureFeature() } withDependencies: {
            $0.paywall.request = { feature in asked.withValue { $0.append(feature) } }
        }
        store.exhaustivity = .off
        await store.send(.kindTapped(.event))
        #expect(store.state.kind != .event)
        #expect(asked.value == [.eventFromElsewhere])
    }
}
