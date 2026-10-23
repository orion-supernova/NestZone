import ComposableArchitecture
import Foundation

/// Where Sparkles for the house jar are bought.
///
/// For now a test store: it lists the four packs, charges nothing, and hands
/// the Sparkles over after a moment, so the whole path — short of Sparkles,
/// to the store, back to what was being bought — can be tried on a
/// development build. The real one (StoreKit 2 or RevenueCat, still to be
/// decided) replaces `liveValue` and nothing else: it prices the packs in the
/// person's storefront, and its Sparkles reach the jar only once the server
/// has verified the transaction (`jar:topUp`, Docs/Companion/HANDOFF.md).
@DependencyClient
public struct SparkleStoreClient: Sendable {
    /// The packs on sale, priced for this person's storefront.
    public var packs: @Sendable () async throws -> [SparklePack]
    /// Buys a pack, through the store's own purchase sheet and nothing of
    /// ours in front of it.
    public var purchase: @Sendable (_ id: SparklePack.ID) async throws -> PurchaseOutcome
}

/// How buying a pack ended.
public enum PurchaseOutcome: Equatable, Sendable {
    /// These Sparkles are in the jar.
    case added(Int)
    /// Waiting for a parent's OK (Ask to Buy); the Sparkles land once it comes.
    case pending
    /// The person backed out of the purchase sheet.
    case cancelled
}

extension SparkleStoreClient: DependencyKey {
    public static let liveValue = SparkleStoreClient(
        packs: { SparklePack.shelf },
        purchase: { id in
            try await Task.sleep(for: .milliseconds(600))
            #if DEBUG
            // `-sparkleOutcome ask` or `fail`, to see the store's other answers.
            switch UserDefaults.standard.string(forKey: "sparkleOutcome") {
            case "ask": return .pending
            case "fail": throw CancellationError()
            default: break
            }
            #endif
            guard let sparkles = SparklePack.shelf.first(where: { $0.id == id })?.sparkles else { return .cancelled }
            return .added(sparkles)
        }
    )

    /// Whether purchases are real. The test store's packs say so in the shop.
    public static let isTestStore = true

    public static let testValue = SparkleStoreClient()
}

extension DependencyValues {
    public var sparkleStore: SparkleStoreClient {
        get { self[SparkleStoreClient.self] }
        set { self[SparkleStoreClient.self] = newValue }
    }
}
