import ComposableArchitecture
import Foundation

/// Whether the open house has NestZone Plus: the one subscription to
/// `pro:status`, kept for as long as the tab bar is.
///
/// It writes the answer to the shared `.pro` key, where every gate reads it
/// (`.proLocked`, the locked modules, the reducers that refuse), and tells
/// `MainFeature` when Plus turned on or off so the screens that start and stop
/// reads for it (Today, the dock) can. Nothing else writes the key.
@Reducer
public struct ProStatusFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        @Shared(.pro) public var status: ProStatus

        public init(homeID: HomeID) {
            self.homeID = homeID
        }
    }

    public enum Action: Equatable {
        case task
        case statusUpdated(ProStatusPayload)
        /// The end date passed while the app was open.
        case expiryReached
        /// RevenueCat says the entitlement moved: ask the server to look.
        case entitlementMoved
        /// Look through Plus transactions the app has not finished: one that
        /// was not credited yet when it arrived is tried again whenever
        /// something that could have changed that does.
        case recheckUnfinished
        /// The app came back to the foreground.
        case becameActive
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// What the gates now read. `wasLoaded` is false for the first
            /// answer, which is also where a free house's tabs pick their
            /// opening segment.
            case changed(isPro: Bool, firstAnswer: Bool)
        }
    }

    private enum CancelID { case status, expiry, listener, customerInfo, unfinished }

    @Dependency(\.pro) var proClient
    @Dependency(\.purchases) var purchases
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                // Another house's answer is not this house's.
                if state.status.isLoaded { state.$status.withLock { $0 = .unknown } }
                return .merge(
                    .run { send in
                        for try await payload in proClient.status(homeID) {
                            await send(.statusUpdated(payload))
                        }
                    } catch: { _, _ in
                        // Nothing to say: the gates stay as they were, and the
                        // server refuses what it must either way.
                    }
                    .cancellable(id: CancelID.status, cancelInFlight: true),

                    // Plus transactions that finish outside a tap: renewals,
                    // Ask to Buy, an interrupted purchase.
                    .run { _ in
                        await purchases.watchTransactions { [proClient, clock] in
                            try await PaywallFeature.settle(proClient: proClient, clock: clock)
                        }
                    }
                    .cancellable(id: CancelID.listener, cancelInFlight: true),

                    .run { send in
                        var first = true
                        for await _ in purchases.customerInfo() {
                            // The first value is the state of the world, not news.
                            if first { first = false; continue }
                            await send(.entitlementMoved)
                        }
                    }
                    .cancellable(id: CancelID.customerInfo, cancelInFlight: true)
                )

            case let .statusUpdated(payload):
                var next = ProStatus(payload, now: now)
                // `-forceFreeHouse 1` (Debug/MEASURE): locks for screenshots.
                if StoreDemo.forcesFreeHouse { next.isPro = false; next.enforced = true }
                let wasLoaded = state.status.isLoaded
                let was = state.status.isPro
                guard next != state.status else { return .none }
                state.$status.withLock { $0 = next }
                // The server's view moved, which is what a payment waiting to
                // be credited was waiting for.
                var effects: [Effect<Action>] = [.send(.recheckUnfinished)]
                if !wasLoaded || was != next.isPro {
                    effects.append(.send(.delegate(.changed(isPro: next.isPro, firstAnswer: !wasLoaded))))
                }
                // The live query can lag by hours: the app watches the end
                // date itself and lets go the moment it passes.
                if next.isPro, let end = next.expiresAt, end > now {
                    effects.append(
                        .run { send in
                            try await clock.sleep(for: .seconds(end.timeIntervalSince(now)))
                            await send(.expiryReached)
                        }
                        .cancellable(id: CancelID.expiry, cancelInFlight: true)
                    )
                } else {
                    effects.append(.cancel(id: CancelID.expiry))
                }
                return .merge(effects)

            case .expiryReached:
                guard state.status.isPro, let end = state.status.expiresAt, end <= now else { return .none }
                state.$status.withLock { $0.isPro = false }
                return .send(.delegate(.changed(isPro: false, firstAnswer: false)))

            case .entitlementMoved:
                return .merge(
                    .run { _ in _ = try? await proClient.refresh() },
                    .send(.recheckUnfinished)
                )

            case .recheckUnfinished, .becameActive:
                return .run { [proClient, clock] _ in
                    await purchases.settleUnfinished {
                        try await PaywallFeature.settle(proClient: proClient, clock: clock)
                    }
                }
                .cancellable(id: CancelID.unfinished, cancelInFlight: true)

            case .delegate:
                return .none
            }
        }
    }
}
