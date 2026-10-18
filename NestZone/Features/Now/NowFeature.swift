import ComposableArchitecture
import Foundation

/// What the household is doing right now, and what it is eating tonight —
/// for the whole tab bar at once.
///
/// It feeds the dock, the bar that floats above the tabs the way the Music app
/// shows what is playing: an event under way, one about to start, tonight's
/// dinner, an open movie round, or else a way to add something. Tonight used to
/// be a card at the top of Today and nowhere else, so hiding that card in
/// Customize left no way to decide dinner at all; now the decision is one sheet
/// owned here, and Today, Meals and the dock all ask for the same one.
///
/// Alive for as long as the home is open, not for as long as a tab is on
/// screen: the dock is on every tab, so its subscriptions cannot belong to any
/// one of them.
@Reducer
public struct NowFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var currentUserID: UserID?
        /// How many people have to agree for a dinner round to match.
        public var memberCount = 1
        /// Who lives here. Needed to invite the household to an occasion made
        /// out of tonight's dinner — an event written with no attendees is a
        /// party nobody was invited to.
        public var members: IdentifiedArrayOf<User> = []
        /// Planned meals from today onwards, soonest first.
        public var meals: [MealPlan] = []
        /// The next few things in the calendar, soonest first.
        public var upcoming: [EventOccurrence] = []
        /// Movie rounds the household has open.
        public var movieRounds: [Poll] = []
        /// Unread messages, for the badge on the Messages tab.
        public var unreadMessages = 0
        /// The clock the dock reads, moved on by a timer so "in 12 min" and
        /// the switch to the evening happen without anybody touching anything.
        public var now: Date

        @Presents public var dinner: DinnerFeature.State?
        /// The event composer, opened to turn a dinner that has already been
        /// decided into an occasion.
        @Presents public var occasion: EventComposerFeature.State?
        @Presents public var alert: AlertState<Never>?

        public init(homeID: HomeID, currentUserID: UserID? = nil, now: Date = Date()) {
            self.homeID = homeID
            self.currentUserID = currentUserID
            self.now = now
        }

        /// What the household is eating tonight, if anyone has said.
        public var tonight: MealPlan? {
            let today = MealDate.key(now)
            return meals.first { $0.date == today }
        }

        /// An event on today with a menu, when nobody has said what is for
        /// dinner yet.
        ///
        /// The household has already answered "what are we eating" — it just
        /// answered it in the calendar. Offered, never written behind anyone's
        /// back: a menu is strong evidence about dinner, not a decision.
        public var dinnerSuggestion: EventOccurrence? {
            guard tonight == nil else { return nil }
            let today = CalendarDay(now)
            return upcoming.first { occurrence in
                !occurrence.recipeIDs.isEmpty
                    && !occurrence.isMultiDay
                    && CalendarDay(occurrence.start) == today
            }
        }

        /// What the dock shows, by the rules in `DockItem`.
        public var dockItem: DockItem {
            DockItem(
                now: now,
                upcoming: upcoming,
                tonight: tonight,
                suggestion: dinnerSuggestion,
                movieRound: movieRounds.first(where: \.isOpen)
            )
        }
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case mealsUpdated([MealPlan])
        case upcomingUpdated([EventOccurrence])
        case membersUpdated([User])
        case pollsUpdated([Poll])
        case statsUpdated(HomeStats)
        /// The live part of the dock, whatever it is showing.
        case dockTapped
        /// The dock's "+".
        case addTapped
        case decideDinnerTapped
        case dinnerSuggestionAccepted
        case makeOccasionTapped
        case occasionLinked
        case writeFailed(AppError)
        case dinner(PresentationAction<DinnerFeature.Action>)
        case occasion(PresentationAction<EventComposerFeature.Action>)
        case alert(PresentationAction<Never>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            /// "Add anything" — presented over the tab bar by the container.
            case capture
            case openEvent(EventOccurrence)
            case openMovieNight
        }
    }

    private enum CancelID { case meals, events, members, polls, stats, clock }

    /// How often the dock re-reads the clock. Countdowns are drawn by the
    /// system in real time; this only has to catch the moment one item gives
    /// way to the next, and half a minute late is not late.
    static let tickInterval: Duration = .seconds(30)

    @Dependency(\.meals) var mealsClient
    @Dependency(\.events) var eventsClient
    @Dependency(\.homes) var homesClient
    @Dependency(\.polls) var pollsClient
    @Dependency(\.stats) var statsClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date.now) var currentDate

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                state.now = currentDate
                return .merge(
                    .run { send in
                        for try await meals in mealsClient.fromDate(homeID, MealDate.today) {
                            await send(.mealsUpdated(meals))
                        }
                    } catch: { _, _ in
                        // No dinner plan is the normal case; the dock simply
                        // falls through to what comes after it.
                    }
                    .cancellable(id: CancelID.meals, cancelInFlight: true),

                    .run { send in
                        for try await events in eventsClient.upcoming(homeID, 10) {
                            await send(.upcomingUpdated(events))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.events, cancelInFlight: true),

                    .run { send in
                        for try await members in homesClient.members(homeID) {
                            await send(.membersUpdated(members))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.members, cancelInFlight: true),

                    .run { send in
                        for try await polls in pollsClient.byHome(homeID) {
                            await send(.pollsUpdated(polls))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.polls, cancelInFlight: true),

                    // Only for the unread count on the Messages tab. The same
                    // read Today's counters use, so the badge and the counter
                    // can never disagree.
                    .run { send in
                        for try await stats in statsClient.forHome(homeID) {
                            await send(.statsUpdated(stats))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.stats, cancelInFlight: true),

                    .run { send in
                        for await _ in clock.timer(interval: Self.tickInterval) {
                            await send(.tick(currentDate))
                        }
                    }
                    .cancellable(id: CancelID.clock, cancelInFlight: true)
                )

            case let .tick(date):
                state.now = date
                return .none

            // Every push is compared before it is assigned: Convex re-publishes
            // the whole query set on any change, so these land far more often
            // than anything moves, and the dock is on screen everywhere.
            case let .mealsUpdated(meals):
                guard meals != state.meals else { return .none }
                state.meals = meals
                return .none

            case let .upcomingUpdated(events):
                guard events != state.upcoming else { return .none }
                state.upcoming = events
                return .none

            case let .membersUpdated(members):
                let incoming = IdentifiedArray(uniqueElements: members)
                state.memberCount = max(members.count, 1)
                guard incoming != state.members else { return .none }
                state.members = incoming
                return .none

            case let .pollsUpdated(polls):
                // Only movie rounds: dinner votes are the same machinery with a
                // different kind, and the dinner sheet already shows its own.
                let rounds = polls.filter { $0.kind == .movie }
                guard rounds != state.movieRounds else { return .none }
                state.movieRounds = rounds
                return .none

            case let .statsUpdated(stats):
                guard stats.unreadMessages != state.unreadMessages else { return .none }
                state.unreadMessages = stats.unreadMessages
                return .none

            case .dockTapped:
                switch state.dockItem {
                case let .happening(occurrence), let .startingSoon(occurrence):
                    return .send(.delegate(.openEvent(occurrence)))
                case .dinner, .dinnerUndecided:
                    return .send(.decideDinnerTapped)
                case .dinnerSuggestion:
                    return .send(.dinnerSuggestionAccepted)
                case .movieRound:
                    return .send(.delegate(.openMovieNight))
                case .add:
                    return .send(.delegate(.capture))
                }

            case .addTapped:
                return .send(.delegate(.capture))

            // Re-deciding opens on what was already chosen rather than blank.
            case .decideDinnerTapped:
                state.dinner = DinnerFeature.State(
                    homeID: state.homeID,
                    memberCount: state.memberCount,
                    existing: state.tonight
                )
                return .none

            case .dinner(.presented(.delegate(.finished))):
                state.dinner = nil
                return .none

            case .dinnerSuggestionAccepted:
                // The same write the event sheet's "make it dinner" performs,
                // from the other end. One field — `meal_plans.event_id` —
                // because a dinner party is a meal *and* an event, and two
                // copies of the menu is two things that can disagree.
                guard let occurrence = state.dinnerSuggestion else { return .none }
                return .run { [homeID = state.homeID] _ in
                    try await mealsClient.set(DinnerDecision(
                        homeID: homeID,
                        date: MealDate.key(occurrence.start),
                        kind: .cook,
                        recipeID: occurrence.recipeIDs.first,
                        // A menu whose recipes have all been deleted still
                        // names a dinner: the event's own title stands in.
                        title: occurrence.recipeIDs.isEmpty ? occurrence.title : nil,
                        eventID: occurrence.eventID
                    ))
                } catch: { error, send in
                    // Nothing was written, so there is nothing to put back:
                    // the offer is still on screen, and still offering.
                    await send(.writeFailed(AppError(error)))
                }

            // The composer rather than a silent write: an occasion needs a
            // time, and once it is open it may as well carry the budget, the
            // shopping and the guest list too.
            case .makeOccasionTapped:
                guard let plan = state.tonight, plan.event == nil else { return .none }
                let title = plan.headline ?? String(localized: L10n.dinnerOccasionFallbackTitle)
                state.occasion = EventComposerFeature.State(
                    homeID: state.homeID,
                    members: state.members,
                    currentUserID: state.currentUserID,
                    day: CalendarDay(MealDate.date(plan.date) ?? state.now),
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
                    await send(.writeFailed(AppError(error)))
                }

            case .occasionLinked:
                // The meals subscription brings the linked plan back.
                return .none

            case let .writeFailed(error):
                guard !error.isSilent else { return .none }
                state.alert = .failure(error)
                return .none

            case .dinner, .occasion, .alert, .delegate:
                return .none
            }
        }
        .ifLet(\.$dinner, action: \.dinner) { DinnerFeature() }
        .ifLet(\.$occasion, action: \.occasion) { EventComposerFeature() }
        .ifLet(\.$alert, action: \.alert)
    }
}

/// The one thing the dock shows.
///
/// In order: something happening now, something starting within three hours,
/// tonight's dinner in the evening, an open movie round — and otherwise the way
/// to add something. Never empty, because the bar is on screen everywhere and
/// an empty bar is a bar that says nothing.
public enum DockItem: Equatable, Sendable {
    case happening(EventOccurrence)
    case startingSoon(EventOccurrence)
    case dinner(MealPlan)
    case dinnerSuggestion(EventOccurrence)
    case dinnerUndecided
    case movieRound(Poll)
    case add

    /// How far ahead an event starts claiming the dock.
    static let soonWindow: TimeInterval = 3 * 3600
    /// When dinner becomes the evening's question, and when it stops being one.
    static let eveningStarts = 16
    static let eveningEnds = 22

    public init(
        now: Date,
        upcoming: [EventOccurrence],
        tonight: MealPlan?,
        suggestion: EventOccurrence?,
        movieRound: Poll?,
        calendar: Calendar = .current
    ) {
        // All-day and multi-day events stay out: a birthday is "today" from
        // midnight to midnight, and would hold the dock all day against the
        // dinner it is probably about.
        let timed = upcoming.filter { !$0.isAllDay && !$0.isMultiDay }
        if let current = timed.first(where: { $0.start <= now && now < $0.end }) {
            self = .happening(current)
            return
        }
        if let next = timed.first(where: { $0.start > now && $0.start.timeIntervalSince(now) <= Self.soonWindow }) {
            self = .startingSoon(next)
            return
        }
        let hour = calendar.component(.hour, from: now)
        if (Self.eveningStarts..<Self.eveningEnds).contains(hour) {
            if let tonight {
                self = .dinner(tonight)
            } else if let suggestion {
                self = .dinnerSuggestion(suggestion)
            } else {
                self = .dinnerUndecided
            }
            return
        }
        if let movieRound {
            self = .movieRound(movieRound)
            return
        }
        self = .add
    }
}
