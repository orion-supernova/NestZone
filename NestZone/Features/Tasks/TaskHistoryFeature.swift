import ComposableArchitecture
import Foundation
import SwiftUI

/// Everything the household has ever finished.
///
/// The other half of bounding the Done list. That list carries the last
/// `doneWindowDays` of finished chores so it stays a working list rather than
/// an archive; this is where the rest of them are, and where anything put away
/// by hand still shows up.
///
/// It reads `task_completions`, not `tasks` — the household's record of the
/// work rather than the rows describing it. That is what makes the promise the
/// Tasks screen prints under its list true: tidying the task list cannot change
/// what is here, and what is here is exactly what the contribution split is
/// counted from.
@Reducer
public struct TaskHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so their own rows can say "You".
        public var currentUserID: UserID?
        public var history: TaskHistory = .empty
        public var isLoading = true
        /// Rows whose chore is being put back, so the badge does not flicker
        /// back to "Archived" between the write landing and the next push.
        public var restoring: Set<TaskID> = []
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        public var entries: [TaskCompletion] { history.entries }

        public func isRestoring(_ entry: TaskCompletion) -> Bool {
            restoring.contains(entry.taskID)
        }
    }

    public enum Action {
        case task
        case historyUpdated(TaskHistory)
        case loadFailed(AppError)
        case restoreTapped(TaskID)
        case restoreFailed(TaskID, AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case history }

    @Dependency(\.tasks) var tasksClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .run { send in
                    for try await history in tasksClient.history(homeID) {
                        await send(.historyUpdated(history))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.history, cancelInFlight: true)

            case let .historyUpdated(history):
                state.isLoading = false
                state.history = history
                // A row the server no longer reports as archived needs no mask,
                // and keeping one would strand the badge on it.
                state.restoring.formIntersection(
                    Set(history.entries.filter(\.isArchived).map(\.taskID))
                )
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .restoreTapped(taskID):
                guard !state.restoring.contains(taskID) else { return .none }
                // Optimistic, and the failure carries the id it needs to undo:
                // a rejected write leaves the server unchanged, so no push is
                // coming to correct the badge.
                state.restoring.insert(taskID)
                return .run { send in
                    try await tasksClient.setArchived(taskID, false)
                } catch: { error, send in
                    await send(.restoreFailed(taskID, AppError(error)))
                }

            case let .restoreFailed(taskID, error):
                state.restoring.remove(taskID)
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
