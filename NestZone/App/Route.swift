import ComposableArchitecture
import SwiftUI

/// Every screen that can sit on a tab's navigation stack.
///
/// One list for every tab. A module is a segment at the root of its group's
/// tab, but the things inside modules are not: the calendar opened at a bill's
/// event, a problem opened from Today, the chore split — those are pushed
/// wherever the person already is, and a recipe asking for the shopping list
/// has to work the same wherever the recipe happens to be open.
@Reducer
public enum Route {
    case tasks(TasksFeature)
    /// The chores that have aged off the Done list. Pushed from the Tasks
    /// screen, which carries the recent half and nothing else.
    case taskArchive(TaskArchiveFeature)
    case contributions(ContributionsFeature)
    case shopping(ShoppingFeature)
    case notes(NotesFeature)
    case recipes(RecipesFeature)
    /// Reached from tonight's dinner card, which is the one place on Today
    /// that points at a specific recipe.
    case recipeDetail(RecipeDetailFeature)
    case movies(MoviesFeature)
    case movieNight(MovieNightFeature)
    case finance(FinanceFeature)
    case calendar(CalendarFeature)
    case issues(IssuesFeature)
    /// House → At a glance: the counters, for anybody who has not put them on
    /// Today.
    case stats(HouseStatsFeature)
}

extension Route.State: Equatable {}

extension Route.State {
    /// Keeps a long-lived screen in step with the session.
    ///
    /// A segment's screen is built when the home opens, which can be before
    /// the user has arrived; a pushed screen is built on the tap and reads the
    /// session then. Only the first needs this.
    mutating func apply(currentUserID: UserID?) {
        switch self {
        case var .tasks(s): s.currentUserID = currentUserID; self = .tasks(s)
        case var .taskArchive(s): s.currentUserID = currentUserID; self = .taskArchive(s)
        case var .contributions(s): s.currentUserID = currentUserID; self = .contributions(s)
        case var .notes(s): s.currentUserID = currentUserID; self = .notes(s)
        case var .movieNight(s): s.currentUserID = currentUserID; self = .movieNight(s)
        case var .finance(s): s.currentUserID = currentUserID; self = .finance(s)
        case var .calendar(s): s.currentUserID = currentUserID; self = .calendar(s)
        case var .issues(s): s.currentUserID = currentUserID; self = .issues(s)
        case .shopping, .recipes, .recipeDetail, .movies, .stats: break
        }
    }

    /// Hands tonight's dinner to the one screen that draws it.
    mutating func apply(tonight: MealPlan?) {
        guard case var .recipes(s) = self, s.tonight != tonight else { return }
        s.tonight = tonight
        self = .recipes(s)
    }

    /// Whether two destinations are the same screen, ignoring their contents.
    ///
    /// Compared by case name rather than by value: two `ShoppingFeature.State`
    /// built a second apart are not equal — one has rows in it and the other
    /// does not — but they are unmistakably the same screen, and pushing the
    /// second on top of the first is the bug this exists to prevent.
    func isSameScreen(as other: Self) -> Bool {
        String(describing: self).prefix(while: { $0 != "(" })
            == String(describing: other).prefix(while: { $0 != "(" })
    }
}

/// One segment of a grouped tab: a module's root screen.
///
/// Every segment of a tab stays in state while another one is showing, so
/// going from Shopping to Chores and back finds the list where it was left —
/// its filter, its open composer, an undo still counting down. Only its live
/// subscriptions stop, because those belong to the view, which is gone.
@Reducer
public struct Segment: Sendable {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let module: HubModule
        public var screen: Route.State

        public var id: HubModule { module }

        public init(module: HubModule, screen: Route.State) {
            self.module = module
            self.screen = screen
        }
    }

    public enum Action {
        case screen(Route.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.screen, action: \.screen) { Route.body }
    }
}

/// One tab's navigation: the segments at its root, and what is pushed on them.
///
/// Today draws its own root and has no segments; Lists, Plans and House each
/// hold one segment per module. Either way the stack is the same, and so is
/// the answer to "this screen wants to open that one": the stack does not
/// decide, it asks. Whether the shopping list is a segment to switch to or a
/// screen to push depends on which tab the request came from, which only
/// `MainFeature` knows.
@Reducer
public struct RouteStack: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var segments: IdentifiedArrayOf<Segment.State> = []
        /// The segment on screen. `nil` on a tab that draws its own root.
        public var selected: HubModule?
        public var path = StackState<Route.State>()

        public init() {}

        /// A grouped tab, built with a fresh screen for each of its modules.
        public init(
            group: TabGroup,
            selected: HubModule,
            screen: (HubModule) -> Route.State
        ) {
            segments = IdentifiedArray(uniqueElements: group.modules.map {
                Segment.State(module: $0, screen: screen($0))
            })
            self.selected = group.modules.contains(selected) ? selected : group.defaultModule
        }

        /// The screen at the bottom of the stack, if the tab has one.
        public var root: Route.State? {
            selected.flatMap { segments[id: $0]?.screen }
        }
    }

    /// Somewhere a screen on this stack asked to go.
    public enum Target: Equatable, Sendable {
        /// A whole module: its tab, switched to its segment.
        case module(HubModule)
        /// A specific event: always opened where the person already is.
        case event(EventID, CalendarDay)
        case occurrence(EventOccurrence)
        case issue(IssueID)
        case recipe(Recipe)
        case taskArchive
        case contributions
        case movieNight
        case stats
        /// The Chat tab, which has no stack a screen could be pushed onto.
        case messages
        /// Deciding tonight's dinner: a sheet over the whole tab bar, so the
        /// dock, Today and Meals all open the same one.
        case decideDinner
    }

    public enum Action {
        case segments(IdentifiedActionOf<Segment>)
        /// The segment switch at the top of a grouped tab.
        case segmentPicked(HubModule)
        /// The counters' button beside House's switch.
        case statsTapped
        case path(StackActionOf<Route>)
        /// A hand-off that had to wait for a dismissal to finish. Carries the
        /// top of the stack as it was when the wait began.
        case deferredOpen(Target, expectedTop: StackElementID?)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case open(Target)
        }
    }

    private enum CancelID { case handoff }

    /// Roughly one navigation transition. There is no completion callback for
    /// a dismissal, so whatever follows one has to wait it out.
    static let unwind: Duration = .milliseconds(350)

    @Dependency(\.shopping) var shoppingClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .segments(.element(id: _, action: .screen(action))):
                return relay(action, state: state, from: nil)

            case let .segmentPicked(module):
                guard state.segments[id: module] != nil else { return .none }
                state.selected = module
                return .none

            case .statsTapped:
                return .send(.delegate(.open(.stats)))

            case let .path(.element(id: id, action: action)):
                return relay(action, state: state, from: id)

            // Leaving the shopping list with a swipe still inside its undo
            // window. The screen cannot do this itself: `onDisappear` fires
            // after the pop, so the action arrived at an element that no longer
            // existed and the delete was dropped (with a runtime warning). Here
            // the element is still in the stack — parent reducers run before
            // `forEach` — so the write can be read off it and sent.
            case let .path(.popFrom(id)):
                guard case let .shopping(shopping) = state.path[id: id],
                      let pending = shopping.pendingDeletion else { return .none }
                return .run { _ in
                    try await shoppingClient.remove(pending.id)
                } catch: { _, _ in
                    // The row is already gone from a screen that is going away.
                }

            case let .deferredOpen(target, expectedTop):
                // If the person went somewhere else while the dismissal was
                // playing, leave them there rather than yanking them away.
                guard state.path.ids.last == expectedTop else { return .none }
                return .send(.delegate(.open(target)))

            case .path, .delegate:
                return .none
            }
        }
        .forEach(\.segments, action: \.segments) { Segment() }
        .forEach(\.path, action: \.path)
    }

    /// Turns a screen's own request into a `Target`.
    ///
    /// Screens on this stack name what they want and nothing else — Finance
    /// says which event, Issues says "the parts are shopping" — and none of
    /// them knows where anything else is shown.
    private func relay(
        _ action: Route.Action,
        state: State,
        from id: StackElementID?
    ) -> Effect<Action> {
        switch action {
        case .tasks(.delegate(.openArchive)):
            return .send(.delegate(.open(.taskArchive)))

        case .tasks(.delegate(.openContributions)):
            return .send(.delegate(.open(.contributions)))

        case .movies(.delegate(.openMovieNight)):
            return .send(.delegate(.open(.movieNight)))

        case .recipes(.delegate(.decideDinner)):
            return .send(.delegate(.open(.decideDinner)))

        case let .stats(.delegate(.open(module))):
            return .send(.delegate(.open(.module(module))))

        case .stats(.delegate(.openMessages)):
            return .send(.delegate(.open(.messages)))

        // A recipe asking for the shopping list. The recipe screen presents
        // its detail with `navigationDestination(item:)` *inside* this stack
        // and has just dismissed it, so anything that moves the stack now has
        // to wait: asking SwiftUI to dismiss one destination and push another
        // in a single update left the recipe on screen while the state said
        // "shopping", and a second tap went nowhere at all.
        case .recipes(.delegate(.openShoppingList)):
            let top = state.path.ids.last
            return .run { send in
                try await clock.sleep(for: Self.unwind)
                await send(.deferredOpen(.module(.shopping), expectedTop: top))
            }
            .cancellable(id: CancelID.handoff, cancelInFlight: true)

        // The Issues screen does its own waiting (its detail is presented the
        // same way), and the recipe detail is itself a pushed screen, so
        // neither is mid-dismissal by the time this arrives.
        case .recipeDetail(.delegate(.openShoppingList)),
             .issues(.delegate(.openShoppingList)):
            return .send(.delegate(.open(.module(.shopping))))

        case let .finance(.delegate(.openEvent(eventID, day))),
             let .issues(.delegate(.openEvent(eventID, day))),
             let .recipes(.delegate(.openEvent(eventID, day))):
            return .send(.delegate(.open(.event(eventID, day))))

        case let .finance(.delegate(.openIssue(issueID))):
            return .send(.delegate(.open(.issue(issueID))))

        default:
            return .none
        }
    }
}

/// Draws whichever screen a `Route` holds.
struct RouteView: View {
    let store: StoreOf<Route>

    var body: some View {
        switch store.case {
        case let .tasks(store): TasksView(store: store)
        case let .taskArchive(store): TaskArchiveView(store: store)
        case let .contributions(store): ContributionsView(store: store)
        case let .shopping(store): ShoppingView(store: store)
        case let .notes(store): NotesView(store: store)
        case let .recipes(store): RecipesView(store: store)
        case let .recipeDetail(store): RecipeDetailView(store: store)
        case let .movies(store): MoviesView(store: store)
        case let .movieNight(store): MovieNightView(store: store)
        case let .finance(store): FinanceView(store: store)
        case let .calendar(store): CalendarView(store: store)
        case let .issues(store): IssuesView(store: store)
        case let .stats(store): HouseStatsView(store: store)
        }
    }
}
