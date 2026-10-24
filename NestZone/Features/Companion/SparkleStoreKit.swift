import ComposableArchitecture
import Foundation
import OSLog
import StoreKit

/// The real Sparkle store, on StoreKit 2.
///
/// Everything here runs off the main thread: StoreKit's calls are async and
/// nothing in this file is actor-isolated, so the reducer only sends and
/// receives. The money rule is `SparkleSettlement`'s — the server first, then
/// `finish` — and this file is the StoreKit around it.
enum SparkleStoreKit {
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "SparkleStore")
    private static let products = SparkleProducts()
    /// Transactions this process is settling, so the purchase that is waiting
    /// on the server and the listener never both credit (and celebrate) one.
    private static let inFlight = SparkleInFlight()

    /// The packs' product ids end in the Sparkle count, so a product that is
    /// not one of ours (there are none) would not be credited.
    private static let prefix = "com.walhallaa.NestZone.sparkles."

    static var client: SparkleStoreClient {
        SparkleStoreClient(
            packs: { try await products.packs() },
            purchase: { id, homeID, userID in
                @Dependency(\.companion) var companion
                let settlement = SparkleSettlement { try await companion.topUp(homeID, $0) }
                return try await purchase(id, userID: userID, settlement: settlement)
            },
            credits: { homeID, userID in
                @Dependency(\.companion) var companion
                let settlement = SparkleSettlement { try await companion.topUp(homeID, $0) }
                return credits(settlement: settlement, token: SparkleAccount.token(for: userID))
            }
        )
    }

    // MARK: Buying

    private static func purchase(_ id: String, userID: String?, settlement: SparkleSettlement) async throws -> PurchaseOutcome {
        guard let product = try? await products.product(id) else { throw SparkleStoreError.unavailable }
        var options: Set<Product.PurchaseOption> = []
        if let token = SparkleAccount.token(for: userID) { options.insert(.appAccountToken(token)) }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch is CancellationError {
            throw CancellationError()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            log.error("purchase of \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            throw SparkleStoreError.unavailable
        }

        switch result {
        case .userCancelled:
            return .cancelled
        case .pending:
            // Ask to Buy: the approval arrives in `Transaction.updates`, which
            // `credits` is listening to.
            return .pending
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                log.error("purchase of \(id, privacy: .public) did not verify; nothing sent, nothing finished")
                throw SparkleStoreError.unverified
            }
            let wrapped = StoreKitSparkleTransaction(transaction: transaction, signedTransaction: verification.jwsRepresentation)
            let outcome: TopUpOutcome
            await inFlight.claim(transaction.id)
            do {
                outcome = try await settlement.settle(wrapped)
                await inFlight.release(transaction.id)
            } catch is CancellationError {
                await inFlight.release(transaction.id)
                throw CancellationError()
            } catch {
                await inFlight.release(transaction.id)
                // Paid and unconfirmed: still unfinished, so `credits` finds it
                // again at the next launch.
                log.error("jar:topUp could not be asked: \(AppError(error).diagnostic, privacy: .public)")
                throw SparkleStoreError.notConfirmed
            }
            return .added(try outcome.sparklesForPurchase(of: id))
        @unknown default:
            throw SparkleStoreError.unavailable
        }
    }

    // MARK: What finishes by itself

    /// What is waiting, then what comes. The listener starts first, in the same
    /// group: a transaction that lands while the sweep is running must not be
    /// missed.
    private static func credits(settlement: SparkleSettlement, token: UUID?) -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await result in Transaction.updates {
                            await credit(result, settlement, token, continuation)
                        }
                    }
                    group.addTask {
                        for await result in Transaction.unfinished {
                            await credit(result, settlement, token, continuation)
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func credit(
        _ result: VerificationResult<Transaction>,
        _ settlement: SparkleSettlement,
        _ token: UUID?,
        _ continuation: AsyncStream<Int>.Continuation
    ) async {
        guard case let .verified(transaction) = result else {
            log.error("a transaction did not verify; left alone")
            return
        }
        guard transaction.productID.hasPrefix(prefix) else { return }
        // Only the signed-in buyer's, left unfinished otherwise so the buyer's
        // own next session finds it. A purchase with no token at all is
        // StoreKit testing in Xcode, and only Debug accepts that.
        guard accepts(transaction.appAccountToken, signedInAs: token) else {
            log.notice("a transaction for someone else was left for its buyer")
            return
        }
        guard await inFlight.claim(transaction.id) else { return }
        defer { Task { await inFlight.release(transaction.id) } }
        let wrapped = StoreKitSparkleTransaction(transaction: transaction, signedTransaction: result.jwsRepresentation)
        do {
            let outcome = try await settlement.settle(wrapped)
            if outcome.status == .credited, outcome.sparkles > 0 { continuation.yield(outcome.sparkles) }
        } catch {
            // No network, most likely. Unfinished, so the next launch asks again.
            log.error("jar:topUp for \(transaction.productID, privacy: .public) will retry: \(AppError(error).diagnostic, privacy: .public)")
        }
    }
}

extension SparkleStoreKit {
    /// Whether a transaction signed with `purchased` belongs to the person
    /// signed in as `token`.
    static func accepts(_ purchased: UUID?, signedInAs token: UUID?) -> Bool {
        if let purchased { return purchased == token }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

/// The transaction ids being settled right now.
private actor SparkleInFlight {
    private var ids: Set<UInt64> = []

    /// `false` when somebody is already on it.
    @discardableResult
    func claim(_ id: UInt64) -> Bool { ids.insert(id).inserted }
    func release(_ id: UInt64) { ids.remove(id) }
}

/// A verified StoreKit transaction, with the signed copy it came in.
private struct StoreKitSparkleTransaction: SparkleTransaction {
    let transaction: Transaction
    let signedTransaction: String

    func finish() async { await transaction.finish() }
}

/// The products, asked for once. Prices are the storefront's and do not move
/// within a launch, so a second visit to the store costs nothing.
private actor SparkleProducts {
    private var loaded: [String: Product] = [:]

    /// Asks again until every pack is there: a partial answer is shown but
    /// never settled on.
    private func load() async throws {
        let ids = SparklePack.shelf.map(\.id)
        guard !ids.allSatisfy({ loaded[$0] != nil }) else { return }
        let found = try await Product.products(for: ids)
        loaded = Dictionary(found.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func product(_ id: String) async throws -> Product? {
        try await load()
        return loaded[id]
    }

    func packs() async throws -> [SparklePack] {
        try await load()
        return loaded.values.compactMap { product in
            let sparkles = SparklePack.sparkles(inProduct: product.id)
            guard sparkles > 0 else { return nil }
            return SparklePack(id: product.id, sparkles: sparkles, displayPrice: product.displayPrice, price: product.price)
        }
        .sorted { $0.sparkles < $1.sparkles }
    }
}
