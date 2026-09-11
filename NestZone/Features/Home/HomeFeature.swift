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
        /// The next few things in the calendar, soonest first.
        ///
        /// A short capped agenda, not a window: this tab only ever asks "is
        /// anything coming", and `events:upcoming` answers that with at most a
        /// handful of rows however many years of events the household has.
        public var upcoming: [EventOccurrence] = []
        /// Which of the tab's subscriptions have answered.
        ///
        /// This was one `isLoading` flag for the whole screen, cleared by
        /// whichever query happened to land first. That is wrong in both
        /// directions: the first answer un-redacted tiles whose own data had not
        /// arrived, and — the half that hurt — one slow query held the entire
        /// tab as a skeleton while the sections either side of it were sitting
        /// there ready to draw. Each section waits on its own answer now, so a
        /// screen made of five queries appears in five pieces rather than
        /// waiting for the slowest.
        public var loaded: Loaded = []

        public struct Loaded: OptionSet, Equatable, Sendable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            /// `stats:forHome` — the four counter tiles.
            public static let stats = Loaded(rawValue: 1 << 0)
            /// `tasks:listByHome` — the task list below.
            public static let tasks = Loaded(rawValue: 1 << 1)
            /// `events:upcoming` — the agenda card and the events tile, which is
            /// counted from it rather than from the server's summary.
            public static let upcoming = Loaded(rawValue: 1 << 2)
        }
        /// Who lives here.
        ///
        /// Subscribed to for one reason: turning tonight's dinner into an
        /// occasion opens the event composer here, and an event written with no
        /// attendees is a party nobody was invited to. One small live query for
        /// the household, which is a handful of rows.
        public var members: IdentifiedArrayOf<User> = []
        @Presents public var dinner: DinnerFeature.State?
        /// The event composer, opened from tonight's card to turn a meal that
        /// has already been decided into an occasion.
        @Presents public var occasion: EventComposerFeature.State?
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

        /// Something the household is in the middle of right now.
        ///
        /// The one thing on this tab that is true only for a few hours, which is
        /// why it gets its own badge rather than a number: "3 events" is a
        /// figure, "the party is happening" is a fact.
        public var happeningNow: EventOccurrence? {
            upcoming.first(where: \.isInProgress)
        }

        /// The next thing that has not started yet.
        public var nextEvent: EventOccurrence? {
            upcoming.first { !$0.isInProgress && $0.start > Date() }
        }

        /// What the card shows: whatever is under way, then what is next, up to
        /// three rows. Three because a fourth pushes the tasks below the fold on
        /// a small phone, and this is a summary tab.
        public var upNext: [EventOccurrence] {
            Array(upcoming.prefix(3))
        }

        /// Events in the next seven days. Same rule as the Hub's bill tile: a
        /// tile is worth reading only when its number is asking for something,
        /// and "312 events" asks for nothing.
        public var eventsThisWeek: Int {
            let horizon = Date().addingTimeInterval(7 * 24 * 3600)
            return upcoming.count { $0.start <= horizon }
        }

        /// An event on today with a menu, when nobody has said what is for
        /// dinner yet.
        ///
        /// The reverse of the link the event sheet writes, and the half that was
        /// missing. Planning Saturday's dinner party — menu, shopping, budget —
        /// did nothing for Saturday's tonight card unless somebody remembered to
        /// open the event and press "make it dinner". The household had already
        /// answered "what are we eating"; it just had not answered it *here*.
        ///
        /// Offered, never written behind anyone's back. An event with a menu is
        /// strong evidence about dinner, not a decision — and this tab already
        /// holds today's events, so it costs no subscription to ask.
        public var dinnerSuggestion: EventOccurrence? {
            guard tonight == nil else { return nil }
            let today = CalendarDay.today
            return upcoming.first { occurrence in
                !occurrence.recipeIDs.isEmpty
                    && !occurrence.isMultiDay
                    && CalendarDay(occurrence.start) == today
            }
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
        case upcomingEventsUpdated([EventOccurrence])
        case membersUpdated([User])
        case makeOccasionTapped
        case occasion(PresentationAction<EventComposerFeature.Action>)
        case occasionLinked
        case loadFailed(AppError)
        case taskToggled(TaskID)
        case decideDinnerTapped
        case clearDinnerTapped
        /// Take the event the tonight card is offering as today's dinner.
        case dinnerSuggestionAccepted
        case dinnerSuggestionSaved
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
            /// The calendar lives in the Hub, so the tab container has to both
            /// switch tabs and push — which is why this is a delegate rather
            /// than navigation this screen does itself.
            case openCalendar
            /// House Problems is a Hub module too, so opening it is the same
            /// shape as opening the calendar: a tab switch and a push, which
            /// only the tab container can do.
            case openIssues
            case openEvent(EventOccurrence)
            /// Opening an event the Home tab only knows the *id* of — the
            /// occasion a meal plan points at. The tab never subscribes to the
            /// calendar, so it has the id and the day and nothing else; the
            /// calendar resolves the rest from the window it opens on.
            case openEventID(EventID, CalendarDay)
            /// Permission was just granted here. `AppFeature` answers by asking
            /// iOS for a token and registering it with the backend.
            case notificationsEnabled
        }

        public enum Alert: Equatable {
            case enableNotifications
        }
    }

    private enum CancelID { case stats, tasks, meals, events, members }

    @Dependency(\.stats) var statsClient
    @Dependency(\.tasks) var tasksClient
    @Dependency(\.meals) var mealsClient
    @Dependency(\.events) var eventsClient
    @Dependency(\.homes) var homesClient
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
                        // Only the rows; the Done window that travels with them
                        // is the Tasks screen's business, and this tab shows a
                        // handful of open chores.
                        for try await list in tasksClient.byHome(homeID) {
                            await send(.tasksUpdated(list.tasks))
                        }
                    } catch: { error, send in
                        await send(.loadFailed(AppError(error)))
                    }
                    .cancellable(id: CancelID.tasks, cancelInFlight: true),

                    .run { [homeID = state.homeID] send in
                        for try await events in eventsClient.upcoming(homeID, 10) {
                            await send(.upcomingEventsUpdated(events))
                        }
                    } catch: { _, _ in
                        // An empty calendar is the normal case, and a card that
                        // cannot load is not worth an alert over the whole tab.
                    }
                    .cancellable(id: CancelID.events, cancelInFlight: true),

                    .run { [homeID = state.homeID] send in
                        for try await members in homesClient.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true),

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
                state.loaded.insert(.stats)
                state.stats = stats
                return .none

            case let .mealsUpdated(meals):
                state.meals = meals
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                guard incoming != state.members else { return .none }
                state.members = incoming
                return .none

            // MARK: Making tonight an occasion
            //
            // The path that was missing. The Dinner sheet offers this while a
            // meal is being decided, but a meal already decided had nowhere to
            // go — and "we settled on lasagne, now let us make an evening of it"
            // is the normal way round.
            //
            // The composer rather than a silent write: an occasion needs a time,
            // and once it is open it may as well carry the budget, the shopping
            // and the guest list too.

            case .makeOccasionTapped:
                guard let plan = state.tonight, plan.event == nil else { return .none }
                let title = plan.headline ?? String(localized: L10n.dinnerOccasionFallbackTitle)
                state.occasion = EventComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.user?.id,
                    day: CalendarDay(MealDate.date(plan.date) ?? Date()),
                    seed: EventComposerFeature.State.Seed(
                        kind: .dinnerParty,
                        title: title,
                        startsAt: MealDate.eveningOf(plan.date),
                        recipeIDs: plan.recipe.map { [$0.id] } ?? []
                    )
                )
                return .none

            case let .occasion(.presented(.delegate(.saved(eventID)))):
                state.occasion = nil
                // The link, written second. The event exists now, so the meal
                // plan has something to point at — and the plan keeps every
                // other field it already had, because `meals:set` upserts on
                // the home and the day.
                guard let eventID, let plan = state.tonight else { return .none }
                return .run { [homeID = state.homeID] send in
                    try await mealsClient.set(DinnerDecision(
                        homeID: homeID,
                        date: plan.date,
                        kind: plan.kind,
                        recipeID: plan.recipe?.id,
                        title: plan.recipe == nil ? plan.title : nil,
                        cuisine: plan.cuisine,
                        place: plan.place,
                        eventID: eventID
                    ))
                    await send(.occasionLinked)
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }

            case .occasionLinked:
                // Nothing to write here: the meals subscription brings the
                // linked plan back and the card grows its badge.
                return .none

            case .dinnerSuggestionAccepted:
                // The same write the event sheet's "make it dinner" performs,
                // from the other end. One field — `meal_plans.event_id` —
                // because a dinner party is a meal *and* an event, and two
                // copies of the menu is two things that can disagree.
                guard let occurrence = state.dinnerSuggestion else { return .none }
                return .run { [homeID = state.homeID] send in
                    try await mealsClient.set(DinnerDecision(
                        homeID: homeID,
                        date: MealDate.key(occurrence.start),
                        kind: .cook,
                        recipeID: occurrence.recipeIDs.first,
                        // A menu whose recipes have all been deleted still names
                        // a dinner: the event's own title stands in.
                        title: occurrence.recipeIDs.isEmpty ? occurrence.title : nil,
                        eventID: occurrence.eventID
                    ))
                    await send(.dinnerSuggestionSaved)
                } catch: { error, send in
                    await send(.loadFailed(AppError(error)))
                }

            case .dinnerSuggestionSaved:
                // The meals subscription brings the plan back, which is what
                // swaps the offer for the card.
                return .none

            case let .upcomingEventsUpdated(events):
                // Marked answered before the comparison below, not after. A
                // household with nothing coming up delivers an empty array that
                // matches the initial state, and the early return would leave
                // the agenda skeletoning forever on exactly the screens that had
                // the least to show.
                state.loaded.insert(.upcoming)
                // Compared before assigning, like every other push on this tab:
                // Convex re-publishes the whole query set on any change, so this
                // lands far more often than the calendar actually moves, and an
                // identical array would still invalidate every view reading it.
                guard events != state.upcoming else { return .none }
                state.upcoming = events
                return .none

            case let .tasksUpdated(tasks):
                state.loaded.insert(.tasks)
                state.tasks = IdentifiedArray(uniqueElements: tasks)
                return .none

            case let .loadFailed(error):
                // Everything stops waiting, not just the query that failed:
                // `loadFailed` does not say which one it was, and a section left
                // skeletoning forever is worse than one showing its empty state.
                state.loaded = [.stats, .tasks, .upcoming]
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

            case .dinner, .delegate, .alert, .occasion:
                return .none
            }
        }
        .ifLet(\.$dinner, action: \.dinner) { DinnerFeature() }
        .ifLet(\.$occasion, action: \.occasion) { EventComposerFeature() }
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
