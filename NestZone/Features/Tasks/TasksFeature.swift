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
        public var members: IdentifiedArrayOf<User> = []
        public var tasks: IdentifiedArrayOf<HouseTask> = []
        public var isLoading = true
        public var filter: Filter = .open
        /// Swiped away, but not yet sent to the server. The row is already gone
        /// from `tasks`; if the undo window closes without a tap, this is what
        /// gets deleted for real. One at a time — a second swipe commits the
        /// first, the way a mail client does.
        public var pendingDeletion: HouseTask?
        /// Rows this screen is pretending are gone while their write is held or
        /// in flight. Every read here is a live subscription, so without the
        /// mask the next push from the server would put the row straight back.
        /// Self-clearing: once the server stops sending a task, it no longer
        /// needs hiding.
        public var hidden: Set<TaskID> = []

        @Presents public var destination: Destination.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID) { self.homeID = homeID }

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
    }

    @Reducer
    public enum Destination {
        case compose(ComposeTaskFeature)
    }

    public enum Action: BindableAction {
        case task
        case tasksUpdated([HouseTask])
        case membersUpdated([User])
        case loadFailed(AppError)
        case composeTapped
        case toggled(TaskID)
        case deleteTapped(TaskID)
        case undoDeleteTapped
        case deleteWindowClosed(TaskID)
        case deleteCommitFailed(HouseTask, AppError)
        case toggleFailed(TaskID, wasCompleted: Bool, AppError)
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
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

            case let .tasksUpdated(tasks):
                state.isLoading = false
                state.tasks = IdentifiedArray(uniqueElements: tasks)
                // A row still on the server stays masked; one the server has
                // stopped sending needs no mask, and keeping it would leak.
                state.hidden.formIntersection(Set(tasks.map(\.id)))
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

            case let .deleteTapped(id):
                guard let task = state.tasks[id: id] else { return .none }
                // The row goes now — waiting for the server reads as a swipe
                // that did not take — but the write is held back until the undo
                // window closes, so undo cancels it rather than reversing it.
                // There is no trash and no restore endpoint to reverse it with.
                state.tasks.remove(id: id)
                state.hidden.insert(id)
                let superseded = state.pendingDeletion
                state.pendingDeletion = task

                return .merge(
                    // A second swipe ends the first one's window: that task was
                    // offered back and the offer was not taken.
                    superseded.map { commit($0) } ?? .none,

                    .run { send in
                        try await clock.sleep(for: Self.undoWindow)
                        await send(.deleteWindowClosed(task.id))
                    }
                    .cancellable(id: CancelID.undo, cancelInFlight: true)
                )

            case .undoDeleteTapped:
                guard let task = state.pendingDeletion else { return .none }
                state.pendingDeletion = nil
                state.hidden.remove(task.id)
                // Nothing was ever sent, so putting the row back is the whole
                // restore. The live subscription still holds the task and will
                // agree on its next push.
                state.tasks.append(task)
                return .cancel(id: CancelID.undo)

            case let .deleteWindowClosed(id):
                guard let task = state.pendingDeletion, task.id == id else { return .none }
                state.pendingDeletion = nil
                return commit(task)

            case let .deleteCommitFailed(task, error):
                // The write was refused, so the server never changed and no push
                // is coming to correct this. The row has to come back by hand.
                state.hidden.remove(task.id)
                state.tasks.append(task)
                return .send(.writeFailed(error))

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

            case .binding, .destination, .alert:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$alert, action: \.alert)
    }

    /// The write the swipe was always going to make, once nobody has undone it.
    ///
    /// Takes the whole task rather than its id so a failure can put the row
    /// back: the screen dropped it optimistically and nothing else remembers it.
    private func commit(_ task: HouseTask) -> Effect<Action> {
        .run { _ in
            try await tasksClient.remove(task.id)
        } catch: { error, send in
            await send(.deleteCommitFailed(task, AppError(error)))
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
