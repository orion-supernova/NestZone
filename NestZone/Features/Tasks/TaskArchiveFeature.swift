import ComposableArchitecture
import Foundation
import SwiftUI

/// The chores that have left the Done list.
///
/// The complement of that list, not a superset of it — everything finished
/// longer ago than the window, and nothing that is still on the working view.
/// The first version of this screen returned every completion the household had
/// ever recorded, which meant a chore finished yesterday sat in Done and in
/// here at the same time. That is not an archive; it is a second copy of the
/// same list, and having two of them was what made the whole arrangement
/// impossible to describe.
///
/// There is no archiving *verb* anywhere in the app, and that is the other half
/// of the simplification. A chore is here because it got old, which is the only
/// way anything gets here: no flag to set, no sweep to run, nothing to restore
/// and no state that can disagree with the list it produced.
@Reducer
public struct TaskArchiveFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so their own rows can say "You" — and so the delete
        /// warning can say "your credit" rather than naming them at themselves.
        public var currentUserID: UserID?
        public var archive: TaskArchive = .empty
        public var isLoading = true
        /// Rows being put back, so the swipe does not re-offer "Put back" in
        /// the gap between the write landing and the next push.
        public var restoring: Set<TaskID> = []
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        public var entries: [TaskCompletion] { archive.entries }

        public func canRestore(_ entry: TaskCompletion) -> Bool {
            entry.canRestore && !restoring.contains(entry.taskID)
        }
    }

    public enum Action {
        case task
        case archiveUpdated(TaskArchive)
        case loadFailed(AppError)
        case restoreTapped(TaskID)
        case restoreFailed(TaskID, AppError)
        case deleteTapped(TaskCompletion)
        case deleteFailed(AppError)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            /// Confirmed at the dialog that named what it costs.
            case confirmDelete(TaskID)
        }
    }

    private enum CancelID { case archive }

    @Dependency(\.tasks) var tasksClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .run { send in
                    for try await archive in tasksClient.archive(homeID) {
                        await send(.archiveUpdated(archive))
                    }
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }
                .cancellable(id: CancelID.archive, cancelInFlight: true)

            case let .archiveUpdated(archive):
                state.isLoading = false
                state.archive = archive
                // A chore the server no longer offers to restore needs no mask,
                // and keeping one would strand the swipe on it.
                state.restoring.formIntersection(
                    Set(archive.entries.filter(\.canRestore).map(\.taskID))
                )
                return .none

            // Back onto the Done list. Nothing about the record changes, in
            // either direction — which is why this one needs no dialog and the
            // delete beside it does.
            case let .restoreTapped(taskID):
                guard !state.restoring.contains(taskID) else { return .none }
                state.restoring.insert(taskID)
                return .run { send in
                    try await tasksClient.setArchived(taskID, false)
                } catch: { error, send in
                    await send(.restoreFailed(taskID, AppError(error)))
                }

            case let .restoreFailed(taskID, error):
                // The write was refused, so the server never changed and no push
                // is coming to correct the mask.
                state.restoring.remove(taskID)
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            // The one act in the app that moves the contribution split on
            // purpose, so it is the one place a dialog earns its keep: it names
            // the chore, names whose credit goes with it, and says the split
            // will change. No undo toast — a toast is for a write being held
            // back, and this one has already been agreed to.
            case let .deleteTapped(entry):
                state.alert = TaskDeleteWarning.alert(
                    chore: entry.title,
                    creditedTo: entry.displayName,
                    isMine: entry.userID != nil && entry.userID == state.currentUserID,
                    confirm: Action.Alert.confirmDelete(entry.taskID)
                )
                return .none

            case let .alert(.presented(.confirmDelete(taskID))):
                return .run { send in
                    try await tasksClient.removeFinished(taskID)
                } catch: { error, send in
                    await send(.deleteFailed(AppError(error)))
                }

            case let .deleteFailed(error):
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
