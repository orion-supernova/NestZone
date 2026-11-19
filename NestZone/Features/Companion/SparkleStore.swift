import ComposableArchitecture
import Foundation

/// Where Sparkles for the house jar are bought.
///
/// The live one is StoreKit 2 (`SparkleStoreKit`): it lists the six packs at
/// the person's storefront prices, and a Sparkle reaches the jar only once the
/// server has verified the transaction (`jar:topUp`). The test store, kept for
/// Debug builds (`-sparkleStore test`), charges nothing and hands the Sparkles
/// to the Lab's local preview, so the whole path — short of Sparkles, to the
/// store, back to what was being bought — can be tried signed out, on the
/// bench, or with no App Store connection at all.
@DependencyClient
public struct SparkleStoreClient: Sendable {
    /// The packs on sale, priced for this person's storefront, smallest first.
    public var packs: @Sendable () async throws -> [SparklePack]
    /// Buys a pack, through the store's own purchase sheet and nothing of
    /// ours in front of it. The house is who gets the Sparkles (`jar:topUp`
    /// needs it); the user is only for the purchase's account token, and may
    /// be `nil`.
    public var purchase: @Sendable (_ id: SparklePack.ID, _ homeID: HomeID, _ userID: String?) async throws -> PurchaseOutcome
    /// Every purchase that finishes outside a tap on a pack — an Ask to Buy
    /// that was approved, one made on another device, one that was cut off by
    /// a crash — credited to the house, yielding the Sparkles each added.
    /// Goes through what is waiting first, then stays open until it is
    /// cancelled. Run it for as long as somebody is signed in with a home.
    /// Only this user's purchases are credited (their `appAccountToken`); a
    /// buyer who has changed house since buying gets them in the house they
    /// are in now — their money follows them.
    public var credits: @Sendable (_ homeID: HomeID, _ userID: String?) -> AsyncStream<Int> = { _, _ in AsyncStream { $0.finish() } }
}

/// How buying a pack ended.
public enum PurchaseOutcome: Equatable, Sendable {
    /// These Sparkles are in the jar: the server has credited them, and the
    /// live read brings the jar itself.
    case added(Int)
    /// The test store's Sparkles: not money, and the server never hears of
    /// them. They go to the Lab's local preview.
    case preview(Int)
    /// Waiting for a parent's OK (Ask to Buy); the Sparkles land once it comes.
    case pending
    /// The person backed out of the purchase sheet.
    case cancelled
}

extension SparkleStoreClient: DependencyKey {
    public static var liveValue: SparkleStoreClient {
        #if DEBUG || MEASURE
        if StoreDemo.isOn { return .demo }
        #endif
        #if DEBUG
        return isTestStore ? .test : SparkleStoreKit.client
        #else
        SparkleStoreKit.client
        #endif
    }

    /// Whether purchases are fake: Debug builds launched with
    /// `-sparkleStore test`. The test store's packs say so in the shop.
    public static var isTestStore: Bool {
        #if DEBUG
        // The launch argument itself, not the defaults key: a value left in
        // the app's defaults by an old run must not turn a real store fake.
        CommandLine.arguments.firstIndex(of: "-sparkleStore").map {
            CommandLine.arguments.indices.contains($0 + 1) && CommandLine.arguments[$0 + 1] == "test"
        } ?? false
        #else
        false
        #endif
    }

    public static let testValue = SparkleStoreClient()

    #if DEBUG
    /// Lists the six packs unpriced, charges nothing, and hands the Sparkles
    /// over after a moment. Debug builds only: a Release build carries no fake
    /// store.
    static let test = SparkleStoreClient(
        packs: { SparklePack.shelf },
        purchase: { id, _, _ in
            try await Task.sleep(for: .milliseconds(600))
            // `-sparkleOutcome ask` or `fail`, to see the store's other answers.
            switch UserDefaults.standard.string(forKey: "sparkleOutcome") {
            case "ask": return .pending
            case "fail": throw CancellationError()
            default: break
            }
            guard let sparkles = (SparklePack.shelf + SparklePack.retired).first(where: { $0.id == id })?.sparkles else { return .cancelled }
            return .preview(sparkles)
        },
        credits: { _, _ in AsyncStream { $0.finish() } }
    )
    #endif

    #if DEBUG || MEASURE
    /// `-storeDemo 1`: the catalog's shelf priced as a loaded store would,
    /// and a buy that does nothing.
    static let demo = SparkleStoreClient(
        packs: { StoreDemo.sparklePacks },
        purchase: { _, _, _ in .cancelled },
        credits: { _, _ in AsyncStream { $0.finish() } }
    )
    #endif
}

extension DependencyValues {
    public var sparkleStore: SparkleStoreClient {
        get { self[SparkleStoreClient.self] }
        set { self[SparkleStoreClient.self] = newValue }
    }
}
