import ComposableArchitecture
import Foundation

/// The NestZone Plus paywall, opened on what was reached for.
///
/// A sheet over the app, not RevenueCat's hosted one, so it looks like
/// NestZone. Prices and the free week come from StoreKit through
/// `PurchasesClient`; nothing here is hardcoded. A purchase is settled by the
/// server (`pro:refresh`) before it is finished, and the house's Plus turns on
/// through the live `pro:status`, not through anything this reducer says.
@Reducer
public struct PaywallFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        /// What the person reached for; `nil` for the general paywall (Settings,
        /// or a refusal for something this build has no name for).
        public var feature: ProFeature?
        /// A sheet over what was reached for, or the full-screen one a first
        /// run ends in.
        public var context: Context
        public var houseName: String
        /// The homes the app already has, by id, for the coverage line.
        public var homeNames: [HomeID: String]
        public var packages: [PlusPackage] = []
        public var selectedID: PlusPackage.ID?
        /// What the yearly plan saves against twelve months of the monthly
        /// one, in whole percent, worked out from the two real prices once
        /// they are known. Nil when either is missing or the gap is trivial.
        public var savingsPercent: Int?
        public var isLoading = true
        /// No SDK key, or the offering would not load.
        public var isUnavailable = false
        /// Unavailable because the read failed (network), not because the
        /// store has no plans to show.
        public var isConnectionError = false
        public var isPurchasing = false
        public var isRestoring = false
        /// Each success lands one stamp and one haptic.
        public var stamps = 0
        public var didSucceed = false
        public var message: Message?
        @Shared(.pro) public var status: ProStatus

        public enum Context: Equatable, Sendable { case sheet, onboarding }

        public init(
            feature: ProFeature?,
            context: Context = .sheet,
            houseName: String = "",
            homeNames: [HomeID: String] = [:]
        ) {
            self.feature = feature
            self.context = context
            self.houseName = houseName
            self.homeNames = homeNames
        }

        /// A line under the plans: not an alert, because nothing here is an
        /// error the person did.
        public enum Message: Equatable, Sendable {
            case pending, notYetCredited, nothingToRestore, failed(AppError)
        }

        public var selected: PlusPackage? {
            packages.first { $0.id == selectedID } ?? packages.first
        }

        /// The one plan that costs least per month, from the real prices: the
        /// yearly plan's twelfth against the monthly price. Without prices to
        /// compare it is the yearly plan, so there is always exactly one.
        public var bestValueID: PlusPackage.ID? {
            // One plan is not a comparison.
            guard packages.count > 1 else { return nil }
            let priced = packages.compactMap { package -> (PlusPackage.ID, Decimal)? in
                guard let amount = package.amount else { return nil }
                return (package.id, package.kind == .yearly ? amount / 12 : amount)
            }
            if priced.count == packages.count, let best = priced.min(by: { $0.1 < $1.1 }) { return best.0 }
            return packages.first { $0.kind == .yearly }?.id ?? packages.first?.id
        }

        /// Whether the house is already covered, which turns the sheet from a
        /// sale into a receipt.
        public var isCovered: Bool { status.isLoaded && status.isPro }
    }

    public enum Action: Equatable {
        case task
        case offeringLoaded([PlusPackage])
        /// `connection`: the read itself failed. Otherwise the store answered
        /// with no plans (products not approved yet, no key), which is not
        /// the person's connection.
        case offeringFailed(connection: Bool)
        case packageTapped(PlusPackage.ID)
        case purchaseTapped
        case purchaseFinished(Result<PlusPurchaseOutcome, AppError>)
        case restoreTapped
        case restoreFinished(Result<Bool, AppError>)
        case closeTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismiss
        }
    }

    /// How long the stamp is on screen before the sheet closes itself.
    static let successLinger: Duration = .milliseconds(1600)

    @Dependency(\.purchases) var purchases
    @Dependency(\.pro) var proClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                if StoreDemo.isOn { return .send(.offeringLoaded(StoreDemo.plusPackages)) }
                guard purchases.isAvailable() else {
                    state.isLoading = false
                    state.isUnavailable = true
                    return .none
                }
                state.isLoading = true
                state.isUnavailable = false
                state.isConnectionError = false
                return .run { send in
                    await send(.offeringLoaded(try await purchases.offering()))
                } catch: { error, send in
                    let noPlans = (error as? PurchasesError).map { $0 == .noSuchPackage || $0 == .unavailable } ?? false
                    await send(.offeringFailed(connection: !noPlans))
                }

            case let .offeringLoaded(packages):
                state.isLoading = false
                state.isUnavailable = packages.isEmpty
                state.packages = packages
                state.savingsPercent = Self.savings(in: packages)
                // The yearly plan is the one on offer first.
                state.selectedID = packages.first { $0.kind == .yearly }?.id ?? packages.first?.id
                return .none

            case let .offeringFailed(connection):
                state.isLoading = false
                state.isUnavailable = true
                state.isConnectionError = connection
                return .none

            case let .packageTapped(id):
                state.selectedID = id
                return .none

            case .purchaseTapped:
                // `-storeDemo 1`: a paywall for screenshots buys nothing.
                if StoreDemo.isOn { return .none }
                guard let package = state.selected, !state.isPurchasing, !state.isRestoring,
                      !state.didSucceed else { return .none }
                state.isPurchasing = true
                state.message = nil
                return .run { send in
                    do {
                        let outcome = try await purchases.purchase(package.id) {
                            try await Self.settle(proClient: proClient, clock: clock)
                        }
                        await send(.purchaseFinished(.success(outcome)))
                    } catch PurchasesError.notYetCredited {
                        await send(.purchaseFinished(.success(.notYetCredited)))
                    } catch {
                        await send(.purchaseFinished(.failure(AppError(error))))
                    }
                }

            case .purchaseFinished(.success(.purchased)):
                state.isPurchasing = false
                return succeed(&state)

            case .purchaseFinished(.success(.cancelled)):
                state.isPurchasing = false
                return .none

            case .purchaseFinished(.success(.pending)):
                state.isPurchasing = false
                state.message = .pending
                return .none

            case .purchaseFinished(.success(.notYetCredited)):
                state.isPurchasing = false
                state.message = .notYetCredited
                return .none

            case let .purchaseFinished(.failure(error)):
                state.isPurchasing = false
                if !error.isSilent { state.message = .failed(error) }
                return .none

            case .restoreTapped:
                guard !state.isPurchasing, !state.isRestoring else { return .none }
                state.isRestoring = true
                state.message = nil
                return .run { send in
                    await send(.restoreFinished(Result {
                        try await purchases.restore()
                        if try await proClient.refresh().active { return true }
                        // RevenueCat saw nothing on this phone: ask the App
                        // Store itself, then the server once more.
                        try await purchases.syncAppStore()
                        return try await proClient.refresh().active
                    }.mapError(AppError.init)))
                }

            case .restoreFinished(.success(true)):
                state.isRestoring = false
                return succeed(&state)

            case .restoreFinished(.success(false)):
                state.isRestoring = false
                state.message = .nothingToRestore
                return .none

            case let .restoreFinished(.failure(error)):
                state.isRestoring = false
                if !error.isSilent { state.message = .failed(error) }
                return .none

            case .closeTapped:
                // Closing cancels the effect that is settling a payment, and a
                // payment half settled is the one thing this sheet must not
                // leave behind.
                guard !state.isPurchasing, !state.isRestoring else { return .none }
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }

    /// Money moved: a stamp and a haptic, never confetti.
    private func succeed(_ state: inout State) -> Effect<Action> {
        state.didSucceed = true
        state.stamps += 1
        state.message = nil
        return .run { send in
            try await clock.sleep(for: Self.successLinger)
            await send(.delegate(.dismiss))
        }
    }

    /// The yearly plan against twelve months of the monthly one, in whole
    /// percent rounded down so the claim is never generous. Only from real
    /// prices, and only when it is worth saying (5% or more).
    static func savings(in packages: [PlusPackage]) -> Int? {
        guard let yearly = packages.first(where: { $0.kind == .yearly })?.amount,
              let monthly = packages.first(where: { $0.kind == .monthly })?.amount,
              monthly > 0
        else { return nil }
        let twelve = NSDecimalNumber(decimal: monthly * 12).doubleValue
        let paid = NSDecimalNumber(decimal: yearly).doubleValue
        guard twelve > 0 else { return nil }
        let percent = Int(((1 - paid / twelve) * 100).rounded(.down))
        return percent >= 5 ? percent : nil
    }

    /// Asks the server to look until it sees the subscription, a few times: it
    /// asks RevenueCat, which can be a beat behind the App Store.
    static func settle(proClient: ProClient, clock: any Clock<Duration>) async throws {
        for attempt in 0..<4 {
            if try await proClient.refresh().active { return }
            if attempt < 3 { try await clock.sleep(for: .milliseconds(1500)) }
        }
        throw PurchasesError.notYetCredited
    }
}
