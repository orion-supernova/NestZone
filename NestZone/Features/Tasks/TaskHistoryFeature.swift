import ComposableArchitecture
import Foundation
import SwiftUI

/// Everything the household has ever finished, and the chores it has put away.
///
/// Two lists on one screen because they are two views of the same subject and
/// the actions on them are what differ. **All** is the record — read from
/// `task_completions`, unaffected by anything that happens to a task row, and
/// exactly what the contribution split is counted from. **Archived** is the
/// chores somebody has taken off the working list, read from `tasks`, and it is
/// the only place in the app where a completion can be destroyed.
///
/// The archive exists as a place rather than as a badge because without one
/// there was no way back. Putting a chore away hid it from the Done list, and
/// restoring it meant finding its badge among every completion the home had
/// recorded — with no route at all for one finished longer ago than the Done
/// window, which could be neither restored nor deleted.
@Reducer
public struct TaskHistoryFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so their own rows can say "You" — and so the delete
        /// warning can say "your credit" rather than naming them at themselves.
        public var currentUserID: UserID?
        /// Which of the two lists is on screen.
        ///
        /// Named `listing` rather than `scope`: a TCA `Store` forwards unknown
        /// members to its state, but `scope` is one of its *own* methods —
        /// `store.scope(state:action:)` — so `$store.scope` binds to that
        /// instead and every use of it fails to infer a generic parameter.
        public var listing: Listing = .all
        public var record: TaskHistory = .empty
        public var archive: TaskHistory = .empty
        public var isLoading = true
        /// Rows whose chore is being put back, so the badge does not flicker
        /// back to "Archived" between the write landing and the next push.
        public var restoring: Set<TaskID> = []
        @Presents public var alert: AlertState<Action.Alert>?

        public init(
            homeID: HomeID,
            currentUserID: UserID? = nil,
            listing: Listing = .all
        ) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.listing = listing
        }

        public enum Listing: String, CaseIterable, Hashable, Sendable {
            /// The record: every chore the household has finished.
            case all
            /// The chores it has put away — and the only route to deleting one.
            case archived

            public var title: LocalizedStringResource {
                switch self {
                case .all: L10n.taskHistoryScopeAll
                case .archived: L10n.taskHistoryScopeArchived
                }
            }

            /// What this list is, said before the rows rather than after them —
            /// the same rule the Tasks screen follows, and for the same reason:
            /// the two lists are bounded differently and promise different
            /// things, so one sentence for both would be true of neither.
            public var note: LocalizedStringResource {
                switch self {
                case .all: L10n.taskHistoryNote
                case .archived: L10n.taskHistoryArchivedNote
                }
            }
        }

        public var shown: TaskHistory {
            switch listing {
            case .all: record
            case .archived: archive
            }
        }

        public var entries: [TaskCompletion] { shown.entries }

        public func isRestoring(_ entry: TaskCompletion) -> Bool {
            restoring.contains(entry.taskID)
        }
    }

    public enum Action: BindableAction {
        case task
        case recordUpdated(TaskHistory)
        case archiveUpdated(TaskHistory)
        case loadFailed(AppError)
        case restoreTapped(TaskID)
        case restoreFailed(TaskID, AppError)
        case deleteTapped(TaskCompletion)
        case deleteFailed(AppError)
        case binding(BindingAction<State>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            /// Confirmed at the dialog that named what it costs.
            case confirmDelete(TaskID)
        }
    }

    private enum CancelID { case record, archive }

    @Dependency(\.tasks) var tasksClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                // Both at once rather than one per scope. They are two small
                // bounded reads, and re-subscribing on every tap of the picker
                // would blank the list while the new one arrived.
                return .merge(
                    .run { send in
                        for try await history in tasksClient.history(homeID) {
                            await send(.recordUpdated(history))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.record, cancelInFlight: true),

                    .run { send in
                        for try await archive in tasksClient.archivedList(homeID) {
                            await send(.archiveUpdated(archive))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.archive, cancelInFlight: true)
                )

            case let .recordUpdated(history):
                state.isLoading = false
                state.record = history
                return .none

            case let .archiveUpdated(archive):
                state.isLoading = false
                state.archive = archive
                // A chore the server no longer reports as archived needs no
                // mask, and keeping one would strand the badge on it.
                state.restoring.formIntersection(Set(archive.entries.map(\.taskID)))
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

            // The one destructive act in the app that moves the contribution
            // split, so it is the one place a dialog earns its keep: it names
            // the chore, it names whose credit goes with it, and it says the
            // split will change. No undo toast — a toast is for a write being
            // held, and this one is meant.
            case let .deleteTapped(entry):
                state.alert = Self.deleteConfirmation(
                    for: entry,
                    isMine: entry.userID != nil && entry.userID == state.currentUserID
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

            case .binding, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// The dialog, said in terms of what it costs rather than "are you sure".
    private static func deleteConfirmation(
        for entry: TaskCompletion,
        isMine: Bool
    ) -> AlertState<Action.Alert> {
        // Built before the alert rather than inside its `message` closure: the
        // sentence depends on who the chore counts for, and three branches read
        // better as a value than as control flow inside a builder.
        let consequence: String = if isMine {
            String(localized: L10n.taskHistoryDeleteMessageMine)
        } else if let name = entry.displayName {
            String(localized: L10n.taskHistoryDeleteMessageOther(name))
        } else {
            String(localized: L10n.taskHistoryDeleteMessageUnattributed)
        }

        return AlertState {
            TextState(String(localized: L10n.taskHistoryDeleteTitle(entry.title)))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDelete(entry.taskID)) {
                TextState(String(localized: L10n.commonDelete))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.commonCancel))
            }
        } message: {
            TextState(consequence)
        }
    }
}
