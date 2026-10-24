import CryptoKit
import Foundation

/// One store transaction, as far as the jar cares: what the server needs to
/// verify it and the one thing to do once the server has it.
///
/// A protocol, not StoreKit's own types, so that the rule below — the server
/// first, then `finish` — can be tested without a store.
protocol SparkleTransaction: Sendable {
    /// `VerificationResult<Transaction>.jwsRepresentation`: Apple's signed
    /// copy, which is all the server trusts.
    var signedTransaction: String { get }
    func finish() async
}

/// Credits transactions to the jar, in the one order that cannot lose money:
/// the server is asked first, and a transaction is finished only after the
/// server has it. An unfinished transaction comes back from StoreKit at the
/// next launch, so a crash or a dead network in between costs a delay and not
/// the Sparkles; finishing first would cost them.
struct SparkleSettlement: Sendable {
    /// `jar:topUp`. Throws when the server could not be asked.
    var topUp: @Sendable (_ signedTransaction: String) async throws -> TopUpOutcome

    /// Asks the server, then finishes if the answer is final. `credited` and
    /// `already` are the jar having it; `revoked` is a refunded purchase, which
    /// there is nothing left to wait for. `invalid` and anything this build
    /// does not know are not finished: the transaction stays where the next
    /// launch will look at it again.
    @discardableResult
    func settle(_ transaction: some SparkleTransaction) async throws -> TopUpOutcome {
        let outcome = try await topUp(transaction.signedTransaction)
        switch outcome.status {
        case .credited, .already, .revoked: await transaction.finish()
        case .invalid, .unknown: break
        }
        return outcome
    }
}

/// How a purchase failed, in the words the shop has for each.
public enum SparkleStoreError: Error, Equatable, Sendable {
    /// The store has no such product (not set up yet, or no connection to it).
    case unavailable
    /// The store's receipt did not verify, so nothing was sent and nothing was
    /// finished.
    case unverified
    /// Paid, and the server could not be asked. Left unfinished: it is credited
    /// the next time the app opens.
    case notConfirmed
    /// The server looked and would not credit it.
    case refused
}

/// A stable identity for the purchase, from the user.
///
/// StoreKit can sign a UUID into every transaction (`appAccountToken`), which
/// lets the server tie a receipt to a person later, for refunds or disputes.
/// The server's ids are not UUIDs, so this is derived: SHA-256 of
/// `nestzone.user:<id>`, folded into a version 5 UUID. The same user always
/// gets the same token, on every phone, and nothing has to be stored.
enum SparkleAccount {
    static func token(for userID: String?) -> UUID? {
        guard let userID, !userID.isEmpty else { return nil }
        var bytes = Array(SHA256.hash(data: Data("nestzone.user:\(userID)".utf8)).prefix(16))
        bytes[6] = bytes[6] & 0x0F | 0x50
        bytes[8] = bytes[8] & 0x3F | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension TopUpOutcome {
    /// The Sparkles a purchase the person just made brought, or why it
    /// brought none. `already` with nothing added was credited by something
    /// else (the listener, another phone), so it is not a success the shop
    /// may celebrate; the pack's own count stands in only for a `credited`
    /// answer that left the number out.
    func sparklesForPurchase(of productID: String) throws -> Int {
        switch status {
        case .credited: return sparkles > 0 ? sparkles : SparklePack.sparkles(inProduct: productID)
        case .already where sparkles > 0: return sparkles
        case .already, .invalid, .revoked: throw SparkleStoreError.refused
        case .unknown: throw SparkleStoreError.notConfirmed
        }
    }
}
