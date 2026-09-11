import ComposableArchitecture
import Foundation
import SwiftUI

/// The full chore list.
///
/// The app could display tasks and tick them off, but had no way to *create*
/// one: `tasks:create` existed on the backend and nothing in the client ever
/// called it, so any home without tasks imported from PocketBase saw a section
/// that could never fill. This is that missing screen.
@Reducer
public struct TasksFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking, so the delete warning can say "your credit" rather
        /// than naming somebody at themselves.
        public var currentUserID: UserID?
        public var members: IdentifiedArrayOf<User> = []
        public var tasks: IdentifiedArrayOf<HouseTask> = []
        public var isLoading = true
        public var filter: Filter = .open
        /// How long a finished chore stays on the Done list, as the server
        /// reports it. Shown on the screen rather than assumed, so the sentence
        /// under the list cannot drift from the rule that produced the list.
        public var doneWindowDays: Int = 30
        /// Swiped away, but not yet sent to the server. The row is already gone
        /// from `tasks`; if the undo window closes without a tap, this is what
        /// gets deleted for real. One at a time — a second swipe commits the
        /// first, the way a mail client does.
        ///
        /// Only ever an *open* chore. Deleting a finished one destroys the
        /// record of who did it, which is not a thing to offer on a five-second
        /// timer — that one goes through a dialog instead, and once agreed to
        /// it is sent at once.
        public var pendingRemoval: HouseTask?
        /// Rows this screen is pretending are gone while their write is held or
        /// in flight. Every read here is a live subscription, so without the
        /// mask the next push from the server would put the row straight back.
        /// Self-clearing: once the server stops sending a task, it no longer
        /// needs hiding.
        public var hidden: Set<TaskID> = []

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }

        public enum Filter: String, CaseIterable, Hashable, Sendable {
            case open, done, all

            public var title: LocalizedStringResource {
                switch self {
                case .open: L10n.tasksFilterOpen
                case .done: L10n.tasksFilterDone
                case .all: L10n.tasksFilterAll
                }
            }
        }

        public var visible: [HouseTask] {
            tasks
                .filter { !hidden.contains($0.id) }
                .filter { task in
                    switch filter {
                    case .open: !task.isCompleted
                    case .done: task.isCompleted
                    case .all: true
                    }
                }
                // Urgent first, then soonest due, then newest.
                .sorted { lhs, rhs in
                    if lhs.isUrgent != rhs.isUrgent { return lhs.isUrgent }
                    switch (lhs.dueDate, rhs.dueDate) {
                    case let (l?, r?) where l != r: return l < r
                    default: return Timestamp.newestFirst(lhs.created, rhs.created)
                    }
                }
        }

        public func assigneeName(for task: HouseTask) -> String? {
            task.assignedTo.flatMap { members[id: $0]?.displayName }
        }

        /// What this filter is and is not showing, in the filter's own terms.
        ///
        /// One sentence per filter rather than one for the screen, because the
        /// three of them are bounded differently and a line that is true of one
        /// is a lie about another: "the last 30 days" describes the Done list
        /// exactly, and describes All — which carries every open chore as well
        /// — not at all.
        ///
        /// `nil` on To do, which is the case that needs no sentence. Nothing is
        /// held back from it: an open chore stays until somebody does something
        /// about it, so there is no rule to explain and no reassurance to give.
        /// A note there would be answering a question the list does not raise.
        public var scopeNote: LocalizedStringResource? {
            switch filter {
            case .open: nil
            case .done: L10n.tasksDoneWindowNote(doneWindowDays)
            case .all: L10n.tasksAllWindowNote(doneWindowDays)
            }
        }
    }

    @Reducer
    public enum Destination {
        case compose(ComposeTaskFeature)
    }

    public enum Action: BindableAction {
        case task
        case tasksUpdated(TaskList)
        case membersUpdated([User])
        case loadFailed(AppError)
        case composeTapped
        case toggled(TaskID)
        case deleteTapped(TaskID)
        case undoRemovalTapped
        case removalWindowClosed(TaskID)
        case removalCommitFailed(HouseTask, AppError)
        case deleteFinishedFailed(AppError)
        case archiveTapped
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case openArchive
        }
        case toggleFailed(TaskID, wasCompleted: Bool, AppError)
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {
            /// Confirmed at the dialog that named what it costs.
            case confirmDelete(TaskID)
        }
    }

    private enum CancelID { case tasks, members, undo }

    /// How long a swipe stays undoable. Long enough to notice the mistake,
    /// short enough that the row is not still hanging around when you move on —
    /// the same window the shopping list uses.
    private static let undoWindow: Duration = .seconds(5)

    @Dependency(\.tasks) var tasksClient
    @Dependency(\.homes) var homesClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await tasks in tasksClient.byHome(homeID) {
                            await send(.tasksUpdated(tasks))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.tasks, cancelInFlight: true),

                    .run { send in
                        for try await members in homesClient.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true)
                )

            case let .tasksUpdated(list):
                state.isLoading = false
                state.doneWindowDays = list.doneWindowDays
                state.tasks = IdentifiedArray(uniqueElements: list.tasks)
                // A row still on the server stays masked; one the server has
                // stopped sending needs no mask, and keeping it would leak.
                state.hidden.formIntersection(Set(list.tasks.map(\.id)))
                return .none

            case let .membersUpdated(members):
                state.members = IdentifiedArray(uniqueElements: members)
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .composeTapped:
                state.destination = .compose(ComposeTaskFeature.State(
                    homeID: state.homeID,
                    members: state.members
                ))
                return .none

            case let .toggled(id):
                guard let task = state.tasks[id: id] else { return .none }
                let newValue = !task.isCompleted
                // Optimistic, and the failure carries what it takes to undo:
                // a rejected write leaves the server unchanged, so there is no
                // push coming to correct the checkbox.
                state.tasks[id: id]?.isCompleted = newValue
                return .run { send in
                    try await tasksClient.setCompleted(id, newValue)
                } catch: { error, send in
                    await send(.toggleFailed(id, wasCompleted: task.isCompleted, AppError(error)))
                }

            // One verb, two weights, decided by the row rather than by a
            // dialog asking which kind of delete you meant.
            //
            // An open chore has never been done by anybody, so throwing it away
            // costs nothing and gets the undo toast — the write is simply held
            // for a few seconds. A finished one carries the household's record
            // of who did it, so the same swipe stops and says so by name before
            // anything is sent.
            case let .deleteTapped(id):
                guard let task = state.tasks[id: id] else { return .none }
                guard task.isCompleted else { return hold(task, &state) }
                state.alert = TaskDeleteWarning.alert(
                    chore: task.title,
                    creditedTo: task.completedBy.flatMap { state.members[id: $0]?.displayName },
                    isMine: task.completedBy != nil && task.completedBy == state.currentUserID,
                    confirm: Action.Alert.confirmDelete(task.id)
                )
                return .none

            case .undoRemovalTapped:
                guard let task = state.pendingRemoval else { return .none }
                state.pendingRemoval = nil
                state.hidden.remove(task.id)
                // Nothing was ever sent, so putting the row back is the whole
                // restore. The live subscription still holds the task and will
                // agree on its next push.
                state.tasks.append(task)
                return .cancel(id: CancelID.undo)

            case let .removalWindowClosed(id):
                guard let task = state.pendingRemoval, task.id == id else { return .none }
                state.pendingRemoval = nil
                return commit(task)

            case let .removalCommitFailed(task, error):
                // The write was refused, so the server never changed and no push
                // is coming to correct this. The row has to come back by hand.
                state.hidden.remove(task.id)
                state.tasks.append(task)
                return .send(.writeFailed(error))

            // Agreed to at the dialog, so it goes at once — there is nothing
            // left to reconsider, and an undo toast after a confirmation is a
            // second question about a decision already made. The row vanishes
            // when the subscription confirms it, which for a delete the server
            // accepted is the next push.
            case let .alert(.presented(.confirmDelete(id))):
                return .run { send in
                    try await tasksClient.removeFinished(id)
                } catch: { error, send in
                    await send(.deleteFinishedFailed(AppError(error)))
                }

            case let .deleteFinishedFailed(error):
                return .send(.writeFailed(error))

            case .archiveTapped:
                return .send(.delegate(.openArchive))

            case let .toggleFailed(id, wasCompleted, error):
                state.tasks[id: id]?.isCompleted = wasCompleted
                return .send(.writeFailed(error))

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .destination(.presented(.compose(.finished))):
                state.destination = nil
                return .none

            case .binding, .destination, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    /// Drop the row now, hold the write for a few seconds.
    ///
    /// Waiting for the server reads as a swipe that did not take, so the list
    /// changes at once; but nothing is sent until the undo window closes, which
    /// is what lets undo *cancel* the write rather than reverse it. There is no
    /// trash and no restore endpoint to reverse it with.
    private func hold(_ task: HouseTask, _ state: inout State) -> Effect<Action> {
        state.tasks.remove(id: task.id)
        state.hidden.insert(task.id)
        let superseded = state.pendingRemoval
        state.pendingRemoval = task

        return .merge(
            // A second swipe ends the first one's window: that row was offered
            // back and the offer was not taken.
            superseded.map { commit($0) } ?? .none,

            .run { send in
                try await clock.sleep(for: Self.undoWindow)
                await send(.removalWindowClosed(task.id))
            }
            .cancellable(id: CancelID.undo, cancelInFlight: true)
        )
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    ///
    /// Takes the whole task rather than its id so a failure can put the row
    /// back: the screen dropped it optimistically and nothing else remembers it.
    private func commit(_ task: HouseTask) -> Effect<Action> {
        .run { _ in
            try await tasksClient.remove(task.id)
        } catch: { error, send in
            await send(.removalCommitFailed(task, AppError(error)))
        }
    }
}

@Reducer
public struct ComposeTaskFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var members: IdentifiedArrayOf<User>
        public var title = ""
        public var details = ""
        public var priority: HouseTask.Priority = .medium
        public var kind: HouseTask.Kind = .general
        public var assignee: UserID?
        public var hasDueDate = false
        public var dueDate = Date().addingTimeInterval(86_400)
        public var isSubmitting = false
        public var inlineError: String?

        public init(homeID: HomeID, members: IdentifiedArrayOf<User>) {
            self.homeID = homeID
            self.members = members
        }

        public var canSubmit: Bool {
            !isSubmitting && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public enum Action: Equatable, BindableAction {
        case submitTapped
        case failed(AppError)
        case finished
        case binding(BindingAction<State>)
    }

    @Dependency(\.tasks) var tasks

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .submitTapped:
                guard state.canSubmit else { return .none }
                state.isSubmitting = true
                state.inlineError = nil
                let new = NewTask(
                    title: state.title,
                    details: state.details.isEmpty ? nil : state.details,
                    homeID: state.homeID,
                    priority: state.priority,
                    kind: state.kind,
                    assignedTo: state.assignee,
                    dueDate: state.hasDueDate ? state.dueDate : nil
                )
                return .run { send in
                    try await tasks.create(new)
                    await send(.finished)
                } catch: { error, send in
                    await send(.failed(AppError(error)))
                }

            case let .failed(error):
                state.isSubmitting = false
                state.inlineError = error.errorDescription
                return .none

            case .finished, .binding:
                return .none
            }
        }
    }
}

extension HouseTask.Priority {
    public var title: LocalizedStringResource {
        switch self {
        case .low: L10n.tasksPriorityLow
        case .medium: L10n.tasksPriorityMedium
        case .high: L10n.tasksPriorityHigh
        }
    }

    public var tint: Color {
        switch self {
        case .low: Palette.success
        case .medium: Palette.warning
        case .high: Palette.danger
        }
    }
}

extension HouseTask.Kind {
    public var title: LocalizedStringResource {
        switch self {
        case .cleaning: L10n.tasksKindCleaning
        case .shopping: L10n.tasksKindShopping
        case .maintenance: L10n.tasksKindMaintenance
        case .general: L10n.tasksKindGeneral
        }
    }

    public var symbol: String {
        switch self {
        case .cleaning: "bubbles.and.sparkles.fill"
        case .shopping: "cart.fill"
        case .maintenance: "wrench.adjustable.fill"
        case .general: "checklist"
        }
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension TasksFeature.Destination.State: Equatable {}
