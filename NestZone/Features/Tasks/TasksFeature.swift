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
        case writeFailed(AppError)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case alert(PresentationAction<Alert>)

        public enum Alert: Equatable {}
    }

    private enum CancelID { case tasks, members }

    @Dependency(\.tasks) var tasksClient
    @Dependency(\.homes) var homesClient

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
                state.tasks[id: id]?.isCompleted = newValue
                return .run { send in
                    try await tasksClient.setCompleted(id, newValue)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

            case let .deleteTapped(id):
                return .run { send in
                    try await tasksClient.remove(id)
                } catch: { error, send in
                    await send(.writeFailed(AppError(error)))
                }

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
