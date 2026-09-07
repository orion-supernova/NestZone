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

        /// Whether the household has already been asked about notifications.
        /// Persisted, so the soft ask happens once per install rather than on
        /// every visit to this tab.
        @Shared(.hasAskedForNotifications) public var hasAskedForNotifications: Bool

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
        case toggleFailed(TaskID, wasCompleted: Bool, AppError)
        /// The tab has settled and nobody has been asked about notifications
        /// yet. Raised by an effect rather than from `.task` directly so the
        /// prompt lands on a drawn screen, not a blank one.
        case notificationPromptReady
        case notificationAuthorizationAnswered(Bool)
        /// Bubbled to the tab container, which owns navigation.
        case delegate(Delegate)
        case alert(PresentationAction<Alert>)

        public enum Delegate: Equatable {
            case openShoppingList
            case openNotes
            case openMessages
            case openMovieNight
            case openTasks
            /// Raised by the chart button in the Tasks header. The tab holds no
            /// contribution state of its own — the screen behind this subscribes
            /// when it opens, so the Home tab pays for no query it cannot show.
            case openContributions
            case openRecipe(Recipe)
            /// Permission was just granted here. `AppFeature` answers by asking
            /// iOS for a token and registering it with the backend.
            case notificationsEnabled
        }

        public enum Alert: Equatable {
            case enableNotifications
        }
    }

    private enum CancelID { case stats, tasks, meals }

    @Dependency(\.stats) var statsClient
    @Dependency(\.tasks) var tasksClient
    @Dependency(\.meals) var mealsClient
    @Dependency(\.push) var push
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // Three live subscriptions, opened once. The old screen instead
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
                    .cancellable(id: CancelID.tasks, cancelInFlight: true),

                    // The one place a newcomer is asked about notifications.
                    // Everyone lands here — creating a home and joining one both
                    // end on this tab — and it is the first screen where the
                    // ask means something, because there is finally a household
                    // to be notified about.
                    .run { [asked = state.hasAskedForNotifications] send in
                        guard !asked else { return }
                        // A permission sheet over a tab that has not finished
                        // drawing reads as an ambush.
                        try? await clock.sleep(for: .seconds(1.5))
                        guard await push.authorizationStatus() == .notDetermined
                        else { return }
                        await send(.notificationPromptReady)
                    }
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
                // live subscription confirms it a moment later. Confirms only —
                // the failure carries the value to put back, because nothing
                // else will.
                state.tasks[id: id]?.isCompleted = newValue
                return .run { send in
                    try await tasksClient.setCompleted(id, newValue)
                } catch: { error, send in
                    await send(.toggleFailed(id, wasCompleted: task.isCompleted, AppError(error)))
                }

            case .notificationPromptReady:
                // Marked as asked the moment the alert goes up, not when it is
                // answered: dismissing it is an answer too, and iOS only ever
                // shows its own prompt once.
                state.$hasAskedForNotifications.withLock { $0 = true }
                state.alert = .enableNotifications
                return .none

            case .alert(.presented(.enableNotifications)):
                return .run { send in
                    await send(.notificationAuthorizationAnswered(
                        push.requestAuthorization()
                    ))
                }

            case let .notificationAuthorizationAnswered(granted):
                guard granted else { return .none }
                return .send(.delegate(.notificationsEnabled))

            case let .toggleFailed(id, wasCompleted, error):
                // The write never happened, so the server has nothing to push
                // and no correction is on its way. The checkbox goes back here
                // or it stays wrong until something unrelated reloads the list.
                state.tasks[id: id]?.isCompleted = wasCompleted
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

extension AlertState where Action == HomeFeature.Action.Alert {
    /// The soft ask that stands in front of the system prompt.
    ///
    /// iOS shows its own prompt exactly once per install and a "Don't Allow"
    /// is only reversible in Settings.app, so the reason comes first and the
    /// real prompt only follows a yes.
    static var enableNotifications: Self {
        AlertState {
            TextState(String(localized: L10n.notificationsPromptTitle))
        } actions: {
            ButtonState(action: .enableNotifications) {
                TextState(String(localized: L10n.notificationsPromptAllow))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: L10n.notificationsPromptNotNow))
            }
        } message: {
            TextState(String(localized: L10n.notificationsPromptMessage))
        }
    }
}
