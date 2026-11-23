import ComposableArchitecture
import Foundation

/// One problem as a screen of its own, for a problem opened from somewhere that
/// is not the Problems board — Today's alarm, a repair's row in Money.
///
/// Only the detail, pushed on the stack that asked: Back lands where the person
/// was, not on a board they never opened. The detail is built from the board's
/// row, so the board is read until the problem turns up in it.
@Reducer
public struct IssuePageFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        public var issueID: IssueID
        public var detail: IssueDetailFeature.State?
        public var members: IdentifiedArrayOf<User> = []
        /// The board answered and the problem was not on it: closed long ago
        /// and reachable from Money only because money was spent on it.
        public var isGone = false
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID?, issueID: IssueID) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.issueID = issueID
        }
    }

    public enum Action {
        case task
        case boardUpdated([HouseIssue])
        case membersUpdated([User])
        case loadFailed(AppError)
        case deleteFailed(AppError)
        case detail(IssueDetailFeature.Action)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)

        public enum Alert: Equatable {}

        public enum Delegate: Equatable {
            case openEvent(EventID, CalendarDay)
            case openShoppingList
        }
    }

    private enum CancelID { case board, members }

    @Dependency(\.issues) var issuesClient
    @Dependency(\.homes) var homes
    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await board in issuesClient.board(homeID) {
                            await send(.boardUpdated(board.issues))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.board, cancelInFlight: true),
                    .run { send in
                        for try await members in homes.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                    .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            case let .boardUpdated(issues):
                // Built once, from the first row that carries the problem; the
                // detail keeps itself live from there.
                guard state.detail == nil else { return .none }
                guard let issue = issues.first(where: { $0.id == state.issueID }) else {
                    state.isGone = true
                    return .none
                }
                state.isGone = false
                state.detail = IssueDetailFeature.State(
                    issue: issue,
                    homeID: state.homeID,
                    currentUserID: state.currentUserID,
                    members: state.members
                )
                return .none

            case let .membersUpdated(users):
                let incoming = IdentifiedArray(uniqueElements: users)
                guard incoming != state.members else { return .none }
                state.members = incoming
                state.detail?.members = incoming
                return .none

            case let .loadFailed(error):
                guard state.detail == nil else { return .none }
                state.isGone = true
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .deleteFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // The detail has already confirmed. Written here, since there is no
            // board with an undo window under this page to hand it to.
            case let .detail(.delegate(.deleteRequested(id))):
                return .run { send in
                    try await issuesClient.remove(id)
                    await dismiss()
                } catch: { error, send in
                    await send(.deleteFailed(AppError(error)))
                }

            case let .detail(.delegate(.openEvent(eventID, day))):
                return .send(.delegate(.openEvent(eventID, day)))

            case .detail(.delegate(.openShoppingList)):
                return .send(.delegate(.openShoppingList))

            case .detail, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.detail, action: \.detail) { IssueDetailFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}
