import ComposableArchitecture
import Foundation
import OSLog
import RevenueCat
import StoreKit

/// The RevenueCat public SDK key, from `Info.plist` (`RevenueCatAPIKey`, fed by
/// the `REVENUECAT_API_KEY` build setting). Public by design. Empty until the
/// owner fills it in, and then purchases are simply unavailable.
enum RevenueCatConfig {
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool { !apiKey.isEmpty && !apiKey.hasPrefix("$(") }

    static let productPrefix = "com.walhallaa.NestZone.plus."
    static let entitlement = "pro"
}

extension PurchasesClient: DependencyKey {
    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Purchases")

    public static let liveValue = PurchasesClient(
        isAvailable: { RevenueCatConfig.isConfigured },
        configure: { appUserID in
            guard RevenueCatConfig.isConfigured, !Purchases.isConfigured else { return }
            Purchases.configure(
                with: Configuration.Builder(withAPIKey: RevenueCatConfig.apiKey)
                    .with(appUserID: appUserID)
                    .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
                    .build()
            )
        },
        logIn: { appUserID in
            do {
                try await identity.logIn(appUserID)
            } catch {
                log.error("logIn failed: \(String(describing: error), privacy: .public)")
                throw error
            }
        },
        logOut: {
            await identity.logOut()
        },
        offering: {
            guard Purchases.isConfigured else { throw PurchasesError.unavailable }
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { throw PurchasesError.noSuchPackage }
            var packages: [PlusPackage] = []
            for package in [current.annual, current.monthly].compactMap({ $0 }) {
                let product = package.storeProduct
                var trialDays: Int?
                if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial,
                   await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .eligible {
                    trialDays = intro.subscriptionPeriod.approximateDays
                }
                packages.append(PlusPackage(
                    id: package.identifier,
                    kind: package.packageType == .annual ? .yearly : .monthly,
                    price: product.localizedPriceString,
                    pricePerMonth: package.packageType == .annual ? product.localizedPricePerMonth : nil,
                    trialDays: trialDays,
                    amount: product.price
                ))
            }
            return packages
        },
        purchase: { packageID, settle in
            guard Purchases.isConfigured else { throw PurchasesError.unavailable }
            // Never on an anonymous id: the purchase would be recorded against
            // somebody nobody can find.
            try await identity.ready()
            let offerings = try await Purchases.shared.offerings()
            guard let package = offerings.current?.availablePackages.first(where: { $0.identifier == packageID }),
                  let product = package.storeProduct.sk2Product
            else { throw PurchasesError.noSuchPackage }

            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else { throw PurchasesError.unverified }
                // So RevenueCat sees it; the app finishes it, below.
                _ = try? await Purchases.shared.recordPurchase(result)
                try await settle()
                await transaction.finish()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .cancelled
            }
        },
        restore: {
            guard Purchases.isConfigured else { throw PurchasesError.unavailable }
            try await identity.ready()
            _ = try await Purchases.shared.restorePurchases()
        },
        syncAppStore: {
            guard Purchases.isConfigured else { throw PurchasesError.unavailable }
            try await identity.ready()
            try await AppStore.sync()
            _ = try? await Purchases.shared.syncPurchases()
        },
        watchTransactions: { settle in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await result in StoreKit.Transaction.updates { await handle(result, settle) }
                }
                group.addTask {
                    for await result in StoreKit.Transaction.unfinished { await handle(result, settle) }
                }
            }
        },
        settleUnfinished: { settle in
            for await result in StoreKit.Transaction.unfinished { await handle(result, settle) }
        },
        customerInfo: {
            AsyncStream { continuation in
                guard Purchases.isConfigured else { return continuation.finish() }
                let task = Task {
                    for await info in Purchases.shared.customerInfoStream {
                        let entitlement = info.entitlements[RevenueCatConfig.entitlement]
                        continuation.yield(PlusEntitlement(
                            isActive: entitlement?.isActive ?? false,
                            expiresAt: entitlement?.expirationDate
                        ))
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    public static let testValue = PurchasesClient()

    /// One transaction that came in without a tap: Plus ones are settled and
    /// finished here, anything else is not this listener's and is left alone.
    private static func handle(
        _ result: StoreKit.VerificationResult<StoreKit.Transaction>,
        _ settle: @Sendable () async throws -> Void
    ) async {
        guard case let .verified(transaction) = result,
              transaction.productID.hasPrefix(RevenueCatConfig.productPrefix) else { return }
        if Purchases.isConfigured { _ = try? await Purchases.shared.syncPurchases() }
        do {
            try await settle()
            await transaction.finish()
        } catch {
            // Left unfinished: the next check (a status change, the app coming
            // back, the next launch) finds it again.
            log.error("plus transaction will retry: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Who RevenueCat is, changed one request at a time.
///
/// Sign-out runs detached from the sign-in that follows it, and two identity
/// changes in flight at once can land in either order and leave the SDK on the
/// wrong person. Each request is chained behind the one before it, and what was
/// last asked for is remembered so a purchase can make sure it was met.
private actor PurchasesIdentity {
    private var tail: Task<Void, Never>?
    /// The person the app wants purchases tied to; nil after a sign-out.
    private var wanted: String?
    private var current: String?

    func logIn(_ appUserID: String) async throws {
        wanted = appUserID
        try await serial { try await self.apply(appUserID) }
    }

    func logOut() async {
        wanted = nil
        try? await serial { try await self.applyLogOut() }
    }

    /// Throws unless purchases are tied to the person the app asked for. A
    /// failed `logIn` is tried again here, on the tap that needs it.
    func ready() async throws {
        guard let wanted else { return }
        try await serial { try await self.apply(wanted) }
    }

    private func apply(_ appUserID: String) async throws {
        // Answered by a later request, or already so.
        guard wanted == appUserID, current != appUserID else { return }
        // No key in this build: nothing to tie. A key and an SDK that has not
        // started yet (it is configured off the launch path) is a retry.
        guard RevenueCatConfig.isConfigured else { return }
        guard Purchases.isConfigured else { throw PurchasesError.unavailable }
        _ = try await Purchases.shared.logIn(appUserID)
        current = appUserID
    }

    private func applyLogOut() async throws {
        current = nil
        guard Purchases.isConfigured, !Purchases.shared.isAnonymous else { return }
        _ = try await Purchases.shared.logOut()
    }

    private func serial(_ work: @escaping @Sendable () async throws -> Void) async throws {
        let previous = tail
        let task = Task<Void, Error> {
            await previous?.value
            try await work()
        }
        tail = Task { _ = await task.result }
        try await task.value
    }
}

private let identity = PurchasesIdentity()

extension RevenueCat.SubscriptionPeriod {
    /// A rough length, for "1 week free". Months and years are only ever
    /// shown as days when they are not a whole week, which a trial never is.
    var approximateDays: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }
}
