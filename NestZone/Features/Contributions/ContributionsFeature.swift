import ComposableArchitecture
import Foundation
import SwiftUI

/// The full breakdown of who does the housework.
///
/// Reached from the Home tab's split card. The tab itself carries only the
/// summary — one bar and the top few names — because it is a summary; this is
/// where the ring, the leaderboard and the daily rhythm live.
@Reducer
public struct ContributionsFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so their own row can say "You".
        public var currentUserID: UserID?
        public var window: ContributionWindow
        public var data: HomeContributions = .empty
        public var isLoading = true
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            homeID: HomeID,
            currentUserID: UserID? = nil,
            window: ContributionWindow = .month
        ) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.window = window
        }

        /// Fewest completions the split has to rest on before the app is willing
        /// to characterise it. Below this the ratio is noise: one chore in a
        /// two-person home reads as 100/0 and would otherwise accuse somebody.
        static let verdictMinimumSample = 5

        /// How the split reads in words. `nil` in a one-person home, where the
        /// answer is not interesting, and while the sample is still too small to
        /// mean anything.
        public var verdict: Verdict? {
            guard data.attributed >= Self.verdictMinimumSample else { return nil }
            return data.balance.map(Verdict.init(balance:))
        }

        public enum Verdict: Equatable, Sendable {
            case even, tilted, lopsided

            init(balance: Double) {
                switch balance {
                case 0.8...: self = .even
                case 0.5..<0.8: self = .tilted
                default: self = .lopsided
                }
            }

            public var title: LocalizedStringResource {
                switch self {
                case .even: L10n.contributionsBalanceEvenTitle
                case .tilted: L10n.contributionsBalanceTiltedTitle
                case .lopsided: L10n.contributionsBalanceLopsidedTitle
                }
            }

            public var message: LocalizedStringResource {
                switch self {
                case .even: L10n.contributionsBalanceEvenMessage
                case .tilted: L10n.contributionsBalanceTiltedMessage
                case .lopsided: L10n.contributionsBalanceLopsidedMessage
                }
            }

            public var symbol: String {
                switch self {
                case .even: "equal.circle.fill"
                case .tilted: "chart.bar.fill"
                case .lopsided: "exclamationmark.circle.fill"
                }
            }

            public var tint: Color {
                switch self {
                case .even: Palette.success
                case .tilted: Palette.warning
                case .lopsided: Palette.danger
                }
            }
        }
    }

    public enum Action: Equatable, BindableAction {
        case task
        case contributionsUpdated(HomeContributions)
        case loadFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case contributions }

    @Dependency(\.stats) var statsClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                return subscribe(state.homeID, state.window)

            // Changing the window changes the query's arguments, which means a
            // different subscription. `cancelInFlight` on a shared id retires
            // the old one, so the two never race to set `data`.
            case .binding(\.window):
                state.isLoading = true
                return subscribe(state.homeID, state.window)

            case let .contributionsUpdated(data):
                state.isLoading = false
                state.data = data
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .binding, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func subscribe(
        _ homeID: HomeID,
        _ window: ContributionWindow
    ) -> Effect<Action> {
        .run { send in
            for try await data in statsClient.contributions(homeID, window) {
                await send(.contributionsUpdated(data))
            }
        } catch: { error, send in
            await send(.loadFailed(AppError(error)))
        }
        .cancellable(id: CancelID.contributions, cancelInFlight: true)
    }
}
