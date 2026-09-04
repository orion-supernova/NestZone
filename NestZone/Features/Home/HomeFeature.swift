import ComposableArchitecture
import Foundation

/// The Home tab: who you are, how the household is doing, what needs doing.
@Reducer
public struct HomeFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var user: User?
        /// How many people have to agree for a dinner round to match.
        public var memberCount = 1
        public var stats: HomeStats = .empty
        public var tasks: IdentifiedArrayOf<HouseTask> = []
        /// Planned meals from today onwards, soonest first.
        public var meals: [MealPlan] = []
        public var isLoading = true
        @Presents public var dinner: DinnerFeature.State?
        @Presents public var alert: AlertState<Action.Alert>?

        public init(homeID: HomeID, user: User? = nil) {
            self.homeID = homeID
            self.user = user
        }

        /// What the household is eating tonight, if anyone has said.
        public var tonight: MealPlan? {
            meals.first { $0.date == MealDate.today }
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
        case mealsUpdated([MealPlan])
        case loadFailed(AppError)
        case taskToggled(TaskID)
        case decideDinnerTapped
        case clearDinnerTapped
        case dinner(PresentationAction<DinnerFeature.Action>)
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
            case openRecipe(Recipe)
        }

        public enum Alert: Equatable {}
    }

    private enum CancelID { case stats, tasks, meals }

    @Dependency(\.stats) var statsClient
    @Dependency(\.tasks) var tasksClient
    @Dependency(\.meals) var mealsClient

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
                        for try await meals in mealsClient.fromDate(homeID, MealDate.today) {
                            await send(.mealsUpdated(meals))
                        }
                    } catch: { _, _ in
                        // No dinner plan is the normal case, and a card that
                        // cannot load is not worth an alert over the whole tab.
                    }
                    .cancellable(id: CancelID.meals, cancelInFlight: true),

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

            case let .mealsUpdated(meals):
                state.meals = meals
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

            // Re-deciding opens on what was already chosen rather than blank.
            case .decideDinnerTapped:
                state.dinner = DinnerFeature.State(
                    homeID: state.homeID,
                    memberCount: state.memberCount,
                    existing: state.tonight
                )
                return .none

            case .clearDinnerTapped:
                return .run { [homeID = state.homeID] _ in
                    try await mealsClient.clear(homeID, MealDate.today)
                } catch: { _, _ in
                    // The live subscription is the source of truth; a failed
                    // clear simply leaves the card where it was.
                }

            case .dinner(.presented(.delegate(.finished))):
                state.dinner = nil
                return .none

            case .dinner, .delegate, .alert:
                return .none
            }
        }
        .ifLet(\.$dinner, action: \.dinner) { DinnerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}
