import ComposableArchitecture
import Foundation
import Testing

@testable import NestZone

/// The purchase and paywall paths a review of NestZone Plus found holes in:
/// what the transaction listener may finish, when unfinished payments are
/// looked at again, what closes the sheet, how a restore falls back, how the
/// paywall is kept presentable, the gates on writes, and the account deletion.
/// Written to be run in Xcode; not run by the agent that wrote them.
@MainActor
@Suite("NestZone Plus purchases")
struct ProPurchaseTests {

    // MARK: Finishing a transaction

    @Test("A payment the server cannot see is not finished by the listener")
    func listenerKeepsUncreditedTransactionOpen() async {
        let settle = LockIsolated<(@Sendable () async throws -> Void)?>(nil)
        let store = TestStore(initialState: ProStatusFeature.State(homeID: "h1")) {
            ProStatusFeature()
        } withDependencies: {
            $0.pro.status = { _ in .never }
            $0.pro.refresh = { ProRefreshResult(active: false) }
            $0.purchases.customerInfo = { .never }
            $0.purchases.watchTransactions = { handler in
                settle.setValue(handler)
                try? await Task.sleep(for: .seconds(60))
            }
            $0.continuousClock = ImmediateClock()
        }
        store.exhaustivity = .off

        await store.send(.task)
        // Give the listener's effect a turn to hand over its settle closure.
        for _ in 0..<50 where settle.value == nil { await Task.yield() }
        let handler = settle.value
        #expect(handler != nil)
        // Inactive after every look: throws, so the transaction stays open.
        await #expect(throws: PurchasesError.notYetCredited) { try await handler?() }
        await store.skipInFlightEffects()
    }

    @Test("PaywallFeature.settle waits for the server and gives up with notYetCredited")
    func settleThrowsWhenInactive() async {
        let calls = LockIsolated(0)
        let proClient = ProClient(
            status: { _ in .never },
            refresh: { calls.withValue { $0 += 1 }; return ProRefreshResult(active: false) }
        )
        await #expect(throws: PurchasesError.notYetCredited) {
            try await PaywallFeature.settle(proClient: proClient, clock: ImmediateClock())
        }
        #expect(calls.value == 4)
    }

    // MARK: Looking again

    @Test("Unfinished Plus payments are looked at again on a status change, an entitlement change and foreground")
    func recheckTriggers() async {
        let looks = LockIsolated(0)
        let store = TestStore(initialState: ProStatusFeature.State(homeID: "h1")) {
            ProStatusFeature()
        } withDependencies: {
            $0.purchases.settleUnfinished = { _ in looks.withValue { $0 += 1 } }
            $0.pro.refresh = { ProRefreshResult(active: false) }
        }
        store.exhaustivity = .off

        await store.send(.statusUpdated(ProStatusPayload(pro: false)))
        await store.receive(\.recheckUnfinished)
        await store.send(.entitlementMoved)
        await store.receive(\.recheckUnfinished)
        await store.send(.becameActive)
        await store.finish()
        #expect(looks.value >= 3)
    }

    // MARK: Closing the paywall

    @Test("The paywall cannot be closed while a purchase or a restore is settling")
    func closeIgnoredWhileBusy() async {
        var state = PaywallFeature.State(feature: nil)
        state.isPurchasing = true
        let store = TestStore(initialState: state) { PaywallFeature() }
        await store.send(.closeTapped)

        var restoring = PaywallFeature.State(feature: nil)
        restoring.isRestoring = true
        let second = TestStore(initialState: restoring) { PaywallFeature() }
        await second.send(.closeTapped)

        let idle = TestStore(initialState: PaywallFeature.State(feature: nil)) { PaywallFeature() }
        await idle.send(.closeTapped)
        await idle.receive(\.delegate.dismiss)
    }

    // MARK: Restore

    @Test("A restore that finds nothing asks the App Store itself, then the server again")
    func restoreFallsBackToAppStoreSync() async {
        let synced = LockIsolated(0)
        let refreshes = LockIsolated(0)
        let store = TestStore(initialState: PaywallFeature.State(feature: nil)) {
            PaywallFeature()
        } withDependencies: {
            $0.purchases.restore = {}
            $0.purchases.syncAppStore = { synced.withValue { $0 += 1 } }
            // Inactive until the App Store has been asked.
            $0.pro.refresh = {
                refreshes.withValue { $0 += 1 }
                return ProRefreshResult(active: synced.value > 0)
            }
            $0.continuousClock = ImmediateClock()
        }
        await store.send(.restoreTapped) { $0.isRestoring = true }
        await store.receive(\.restoreFinished) {
            $0.isRestoring = false
            $0.didSucceed = true
            $0.stamps = 1
        }
        await store.receive(\.delegate.dismiss)
        #expect(synced.value == 1)
        #expect(refreshes.value == 2)
    }

    // MARK: RevenueCat identity

    @Test("A failed logIn is tried again, and the user is only marked once it lands")
    func logInRetries() async {
        let attempts = LockIsolated(0)
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.purchases.logIn = { _ in
                let n = attempts.withValue { $0 += 1; return $0 }
                if n == 1 { throw PurchasesError.unavailable }
            }
            $0.pro.refresh = { ProRefreshResult(active: false) }
        }
        store.exhaustivity = .off

        await store.send(.currentUserChanged(User(id: "u1", name: "Ada")))
        #expect(store.state.proCheckedFor == nil)
        await clock.advance(by: .seconds(2))
        await store.receive(\.purchasesLoggedIn)
        #expect(store.state.proCheckedFor == "u1")
        #expect(attempts.value == 2)
    }

    // MARK: The paywall is always presentable

    @Test("A request nothing draws is dropped, so the next one is not swallowed")
    func undrawnPaywallIsDropped() async {
        let clock = TestClock()
        let store = TestStore(initialState: MainFeature.State(homeID: "h1")) {
            MainFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        store.exhaustivity = .off

        await store.send(.paywallRequested(.calendar))
        #expect(store.state.paywall?.feature == .calendar)
        await clock.advance(by: MainFeature.paywallShowDeadline)
        await store.receive(\.paywallNeverShown)
        #expect(store.state.paywall == nil)

        // And one that is drawn (its first task ran) is kept.
        await store.send(.paywallRequested(.finance))
        await store.send(.paywall(.presented(.task)))
        await clock.advance(by: MainFeature.paywallShowDeadline)
        #expect(store.state.paywall?.feature == .finance)
    }

    // MARK: Gates on writes

    @Test("Every write in the Plus sheets asks the paywall for a free house")
    func writesAreGated() {
        #expect(ExpenseComposerFeature.writes(.submitTapped))
        #expect(BillComposerFeature.writes(.submitTapped))
        #expect(PayBillFeature.writes(.payTapped))
        #expect(BudgetEditorFeature.writes(.submitTapped))
        #expect(SettleUpFeature.writes(.recordTapped))
        #expect(EventComposerFeature.writes(.submitTapped))
        #expect(EventComposerFeature.writes(.scopeDialog(.presented(.saveAll))))
        #expect(EventDetailFeature.writes(.rsvpTapped(.going)))
        #expect(EventDetailFeature.writes(.addItemTapped))
        #expect(EventDetailFeature.writes(.stockUpTapped))
        #expect(EventDetailFeature.writes(.addExpenseTapped))
        #expect(EventDetailFeature.writes(.editTapped))
        // A delete is a correction, and the server allows it.
        #expect(!EventDetailFeature.writes(.deleteTapped))
        #expect(!ExpenseComposerFeature.writes(.deleteTapped))
    }

    @Test("A free house's save in a Plus composer is the paywall")
    func freeSaveAsksPaywall() async {
        @Shared(.pro) var pro: ProStatus
        $pro.withLock { $0.isPro = false }
        defer { $pro.withLock { $0 = .unknown } }
        let asked = LockIsolated<[ProFeature?]>([])
        let state = SettleUpFeature.State(
            homeID: "h1", currentUserID: "u1", currency: "USD",
            members: [], balances: [], transfers: []
        )
        let store = TestStore(initialState: state) {
            SettleUpFeature()
        } withDependencies: {
            $0.paywall.request = { feature in asked.withValue { $0.append(feature) } }
        }
        store.exhaustivity = .off
        await store.send(.recordTapped)
        #expect(asked.value == [.finance])
    }

    // MARK: Account deletion

    @Test("Account deletion cannot be started twice before Apple answers")
    func deletionGuardsDoubleTap() async {
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        }
        await store.send(.deleteAccountConfirmed) { $0.isAuthorizingDelete = true }
        // A second tap on Delete, while Apple's sheet is up, opens nothing.
        await store.send(.deleteAccountTapped)
        await store.send(.deleteAccountAuthorizationFailed(.cancelled)) { $0.isAuthorizingDelete = false }
    }

    @Test("A deletion that finds the session already gone ends as a sign-out")
    func deletionWithSessionGone() async {
        let store = TestStore(initialState: SettingsFeature.State(homeID: "h1")) {
            SettingsFeature()
        } withDependencies: {
            $0.auth.deleteAccount = { _ in throw AppError.notAuthenticated }
        }
        await store.send(.deleteAccountAuthorized(code: nil)) { $0.isDeletingAccount = true }
        await store.receive(\.deleteAccountFinished) { $0.isDeletingAccount = false }
        await store.receive(\.delegate.signedOut)

        #expect(AppError.server("Uncaught Error: Not authenticated").meansSessionIsGone)
        #expect(!AppError.offline.meansSessionIsGone)
    }
}
