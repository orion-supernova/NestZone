import ComposableArchitecture
import Foundation

/// What a NestZone Plus package looks like on the paywall, with RevenueCat
/// taken out of it so reducers and tests never import the SDK.
public struct PlusPackage: Equatable, Identifiable, Sendable {
    public enum Kind: Equatable, Sendable { case yearly, monthly }

    /// RevenueCat's package identifier.
    public var id: String
    public var kind: Kind
    /// The price, localised by StoreKit. Never composed here.
    public var price: String
    /// What a month costs on the yearly plan, localised, when it has one.
    public var pricePerMonth: String?
    /// Days of free trial this person gets, from the introductory offer, when
    /// they are eligible for it.
    public var trialDays: Int?
    /// The price as a number, for the one sum the paywall does: what the
    /// yearly plan saves against twelve months of the monthly one. Never drawn
    /// as text; `price` is what a person reads.
    public var amount: Decimal?

    public init(
        id: String,
        kind: Kind,
        price: String,
        pricePerMonth: String? = nil,
        trialDays: Int? = nil,
        amount: Decimal? = nil
    ) {
        self.id = id
        self.kind = kind
        self.price = price
        self.pricePerMonth = pricePerMonth
        self.trialDays = trialDays
        self.amount = amount
    }
}

public enum PlusPurchaseOutcome: Equatable, Sendable {
    case purchased
    case cancelled
    /// Ask to Buy, or a payment that has not cleared. The transaction arrives
    /// later through the Plus listener.
    case pending
    /// Paid, and the server has not seen it yet. Left unfinished, so the
    /// listener settles it when it does.
    case notYetCredited
}

/// What RevenueCat knows about the `pro` entitlement on this phone. Only a
/// nudge to ask the server again; the server's answer is the one the app uses.
public struct PlusEntitlement: Equatable, Sendable {
    public var isActive: Bool
    public var expiresAt: Date?
}

public enum PurchasesError: Error, Equatable, Sendable {
    /// No SDK key in this build.
    case unavailable
    case noSuchPackage
    case unverified
    /// The payment went through but the server has not seen it yet. The
    /// transaction is left unfinished, so the listener tries again.
    case notYetCredited
}

/// The App Store, through RevenueCat.
///
/// RevenueCat runs with `purchasesAreCompletedBy: .myApp`: Sparkles are
/// consumables that must be finished only after the server credits them, so the
/// app owns finishing transactions. A Plus purchase is made with StoreKit,
/// reported to RevenueCat with `recordPurchase`, settled by asking the server
/// (`pro:refresh`), and only then finished. Each listener leaves the other's
/// product ids alone (`com.walhallaa.NestZone.plus.` and `.sparkles.`).
@DependencyClient
public struct PurchasesClient: Sendable {
    /// Whether this build has an SDK key. Without one the paywall says so.
    public var isAvailable: @Sendable () -> Bool = { false }
    /// Starts the SDK. Safe to call again.
    public var configure: @Sendable (_ appUserID: String?) -> Void
    /// Ties purchases to the Convex user id. Throws when RevenueCat could not
    /// be reached, so the caller can try again: a purchase made while still
    /// anonymous is recorded against an id nobody else will ever see.
    public var logIn: @Sendable (_ appUserID: String) async throws -> Void
    /// Identity changes (this and `logIn`) run one after the other, in the
    /// order they were asked for.
    public var logOut: @Sendable () async -> Void
    public var offering: @Sendable () async throws -> [PlusPackage]
    /// Buys a package. `settle` is the server being asked; the transaction is
    /// finished only after it returns.
    public var purchase: @Sendable (
        _ packageID: String,
        _ settle: @escaping @Sendable () async throws -> Void
    ) async throws -> PlusPurchaseOutcome
    public var restore: @Sendable () async throws -> Void
    /// Asks the App Store itself for the person's transactions (`AppStore.sync`)
    /// and tells RevenueCat. For a restore that found nothing the first time.
    public var syncAppStore: @Sendable () async throws -> Void
    /// Plus transactions that finish outside a tap: renewals, Ask to Buy, an
    /// interrupted purchase. Runs until cancelled.
    public var watchTransactions: @Sendable (
        _ settle: @escaping @Sendable () async throws -> Void
    ) async -> Void
    /// Looks once through the Plus transactions the app has not finished and
    /// settles each. Run when something that could have changed the answer
    /// did (the server's status, RevenueCat's entitlement, the app coming
    /// back), not only at launch.
    public var settleUnfinished: @Sendable (
        _ settle: @escaping @Sendable () async throws -> Void
    ) async -> Void
    public var customerInfo: @Sendable () -> AsyncStream<PlusEntitlement> = { .never }
}

extension DependencyValues {
    public var purchases: PurchasesClient {
        get { self[PurchasesClient.self] }
        set { self[PurchasesClient.self] = newValue }
    }
}
