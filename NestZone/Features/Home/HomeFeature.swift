import ComposableArchitecture
import Foundation

/// The Home tab: who you are, how the household is doing, what needs doing.
@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var user: User?
        public var stats: HomeStats = .empty
        public var tasks: IdentifiedArrayOf<HouseTask> = []
        public var isLoading = true
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, user: User? = nil) {
            self.homeID = homeID
            self.user = user
        }

        /// Newest first, capped — the Home tab is a summary, not the task list.
        public var recentTasks: ArraySlice<HouseTask> {
            tasks
                .sorted { Timestamp.newestFirst($0.created, $1.created) }
                .prefix(5)
        }
    }

    public enum Action: Equatable {
        case task
        case statsUpdated(HomeStats)
        case tasksUpdated([HouseTask])
        case loadFailed(AppError)
        case taskToggled(TaskID)
        case toggleFailed(AppError)
        /// Bubbled to the tab container, which owns navigation.
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        public enum Delegate: Equatable {
            case openShoppingList
            case openNotes
            case openMessages
            case openMovieNight
            case openTasks
        }

        public enum Alert: Equatable {}
    }

    private enum CancelID { case stats, tasks }

    @Dependency(\.stats) var statsClient
    @Dependency(\.tasks) var tasksClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // Two live subscriptions, opened once. The old screen instead
                // re-fetched four collections on every appearance and on every
                // `homeDidChange` notification, with a hardcoded 100 ms sleep in
                // front "to prevent request conflicts".
                return .merge(
                    .run { [homeID = state.homeID] send in
                        for try await stats in statsClient.forHome(homeID) {
                            await send(.statsUpdated(stats))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.stats, cancelInFlight: true),

                    .run { [homeID = state.homeID] send in
                        for try await tasks in tasksClient.byHome(homeID) {
                            await send(.tasksUpdated(tasks))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.tasks, cancelInFlight: true)
                )

            case let .statsUpdated(stats):
                state.isLoading = false
                state.stats = stats
                return .none

            case let .tasksUpdated(tasks):
                state.isLoading = false
                state.tasks = IdentifiedArray(uniqueElements: tasks)
                return .none

            case let .loadFailed(error):
                state.isLoading = false
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case let .taskToggled(id):
                guard let task = state.tasks[id: id] else { return .none }
                let newValue = !task.isCompleted
                // Optimistic: the checkbox answers the tap immediately, and the
                // live subscription confirms or corrects it a moment later.
                state.tasks[id: id]?.isCompleted = newValue
                return .run { send in
                    try await tasksClient.setCompleted(id, newValue)
                } catch: { error, send in
                    await send(.toggleFailed(AppError(error)))
                }

            case let .toggleFailed(error):
                // No manual rollback needed: the server's next push carries the
                // true value, and it is already on its way.
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
