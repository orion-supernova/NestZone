import ComposableArchitecture
import Foundation
import Synchronization

/// How a place that cannot reach the tab bar asks for the paywall.
///
/// Two things need it from outside any reducer: a gated control in a view, and
/// `ConvexConnection.mapped`, which sees the server refuse a write wherever it
/// came from. Both say what was reached for; `MainView` listens and sends
/// `MainFeature.paywallRequested`, which is the one place that decides where
/// the sheet goes. Screens still do not navigate.
public final class PaywallBroker: Sendable {
    public static let shared = PaywallBroker()

    private let listeners = Mutex<[UUID: AsyncStream<ProFeature?>.Continuation]>([:])

    /// Asks for the paywall. `feature` is what was reached for, or nil when the
    /// server named something this build does not know.
    public func request(_ feature: ProFeature?) {
        let all = listeners.withLock { Array($0.values) }
        for continuation in all { continuation.yield(feature) }
    }

    public func requests() -> AsyncStream<ProFeature?> {
        AsyncStream { continuation in
            let id = UUID()
            listeners.withLock { $0[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.listeners.withLock { $0[id] = nil }
            }
        }
    }
}

/// `PaywallBroker`, as a dependency, so a reducer can ask for the paywall and a
/// test can see that it did.
@DependencyClient
public struct PaywallClient: Sendable {
    public var request: @Sendable (_ feature: ProFeature?) -> Void
    public var requests: @Sendable () -> AsyncStream<ProFeature?> = { .never }
}

extension PaywallClient: DependencyKey {
    public static let liveValue = PaywallClient(
        request: { PaywallBroker.shared.request($0) },
        requests: { PaywallBroker.shared.requests() }
    )
    public static let testValue = PaywallClient()
}

extension DependencyValues {
    public var paywall: PaywallClient {
        get { self[PaywallClient.self] }
        set { self[PaywallClient.self] = newValue }
    }
}
