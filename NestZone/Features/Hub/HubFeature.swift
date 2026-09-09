import ComposableArchitecture
import Foundation
import SwiftUI

/// The "Hub" tab: a grid of the household's modules, and the screens they open.
@Reducer
public struct HubFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        /// Who is looking. The Finance module needs it — a balance is only
        /// meaningful as somebody's.
        public var currentUserID: UserID?
        public var path = StackState<Path.State>()
        /// Live counts for the module tiles, so each card shows something real
        /// rather than a static subtitle.
        public var shoppingCount = 0
        public var recipeCount = 0
        public var movieCount = 0
        /// Bills already due or due within the week. Not "how many bills" —
        /// a tile is worth reading only when its number is asking for
        /// something.
        public var billsDueCount = 0
        /// Events in the next seven days. Same rule as the bills: a calendar
        /// tile showing "312 events" says nothing, and "3 this week" is the
        /// only number anybody acts on.
        public var eventsThisWeekCount = 0
        /// What is still broken. Not "how many problems has this house ever
        /// had" — the same rule the bills and events tiles follow: a tile is
        /// worth reading only when its number is asking for something.
        public var openIssueCount = 0
        /// How many of those are urgent or already past their date. Not shown
        /// as a second number — it decides whether the one number is red.
        public var urgentIssueCount = 0

        /// Which module counts have actually been answered.
        ///
        /// Every count starts at 0, and 0 is a real answer — "nothing on the
        /// list", "no bills due". So an unanswered tile was indistinguishable
        /// from an empty one, and the Hub opened claiming the household had
        /// nothing anywhere, then silently filled in. Worse than a wait,
        /// because it reads as fact rather than as loading.
        ///
        /// The counts arrive from five independent subscriptions, so they land
        /// separately and each tile is told on its own.
        public var loaded: Loaded = []

        public struct Loaded: OptionSet, Equatable, Sendable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let shopping = Loaded(rawValue: 1 << 0)
            public static let recipes = Loaded(rawValue: 1 << 1)
            public static let movies = Loaded(rawValue: 1 << 2)
            public static let billsDue = Loaded(rawValue: 1 << 3)
            public static let events = Loaded(rawValue: 1 << 4)
            public static let issues = Loaded(rawValue: 1 << 5)
        }

        public init(homeID: HomeID, currentUserID: UserID? = nil) {
            self.homeID = homeID
            self.currentUserID = currentUserID
        }
    }

    @Reducer
    public enum Path {
        case shopping(ShoppingFeature)
        case recipes(RecipesFeature)
        case movies(MoviesFeature)
        case finance(FinanceFeature)
        case calendar(CalendarFeature)
        case issues(IssuesFeature)
    }

    public enum Action {
        case task
        case countsUpdated(
            shopping: Int? = nil,
            recipes: Int? = nil,
            movies: Int? = nil,
            billsDue: Int? = nil,
            events: Int? = nil,
            issues: IssueCounts? = nil
        )
        case moduleTapped(HubModule)
        case showShoppingList
        case path(StackActionOf<Path>)

        /// The two numbers the Problems tile needs, together — they come from
        /// one payload and one of them decides how the other is drawn, so
        /// letting them land separately would flash a red count over a house
        /// with nothing urgent in it.
        public struct IssueCounts: Equatable, Sendable {
            public var open: Int
            public var urgent: Int
        }
    }

    private enum CancelID { case shopping, recipes, movies, bills, events, issues, handoff }

    /// Roughly one navigation transition. There is no completion callback for a
    /// `StackState` pop, so the push that follows one has to wait it out.
    private static let unwind: Duration = .milliseconds(350)

    @Dependency(\.shopping) var shoppingClient
    @Dependency(\.recipes) var recipesClient
    @Dependency(\.movies) var moviesClient
    @Dependency(\.finance) var financeClient
    @Dependency(\.events) var eventsClient
    @Dependency(\.issues) var issuesClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let homeID = state.homeID
                return .merge(
                    .run { send in
                        for try await items in shoppingClient.byHome(homeID) {
                            await send(.countsUpdated(
                                shopping: items.filter { !$0.isPurchased }.count
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.shopping, cancelInFlight: true),

                    .run { send in
                        for try await recipes in recipesClient.byHome(homeID) {
                            await send(.countsUpdated(recipes: recipes.count))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.recipes, cancelInFlight: true),

                    .run { send in
                        for try await movies in moviesClient.allMovies(homeID) {
                            await send(.countsUpdated(movies: movies.count))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.movies, cancelInFlight: true),

                    .run { send in
                        for try await bills in financeClient.bills(homeID) {
                            await send(.countsUpdated(
                                billsDue: bills.filter { $0.urgency() <= .dueSoon }.count
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.bills, cancelInFlight: true),

                    // `upcoming` rather than a month range: the tile only ever
                    // asks "is anything coming", and the server caps the answer
                    // at a short agenda — so a household with three years of
                    // events costs the Hub the same as one created yesterday.
                    .run { send in
                        for try await occurrences in eventsClient.upcoming(homeID, 20) {
                            let horizon = Date().addingTimeInterval(7 * 24 * 3600)
                            await send(.countsUpdated(
                                events: occurrences.count { $0.start <= horizon }
                            ))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.events, cancelInFlight: true),

                    // The Problems module's own board, which the tile needs two
                    // numbers out of. Subscribed to here rather than counted
                    // from a list: `issues:byHome` already computes both
                    // server-side for the screen itself, so the Hub reads the
                    // same answer instead of deriving a second one that could
                    // disagree with it.
                    .run { send in
                        for try await board in issuesClient.board(homeID) {
                            await send(.countsUpdated(issues: .init(
                                open: board.summary.open,
                                urgent: board.summary.urgent + board.summary.overdue
                            )))
                        }
                    } catch: { _, _ in }
                        .cancellable(id: CancelID.issues, cancelInFlight: true)
                )

            case let .countsUpdated(shopping, recipes, movies, billsDue, events, issues):
                // Each argument is its own subscription's answer, so each one
                // that arrives settles its own tile and leaves the rest waiting.
                if let shopping {
                    state.shoppingCount = shopping
                    state.loaded.insert(.shopping)
                }
                if let recipes {
                    state.recipeCount = recipes
                    state.loaded.insert(.recipes)
                }
                if let movies {
                    state.movieCount = movies
                    state.loaded.insert(.movies)
                }
                if let billsDue {
                    state.billsDueCount = billsDue
                    state.loaded.insert(.billsDue)
                }
                if let events {
                    state.eventsThisWeekCount = events
                    state.loaded.insert(.events)
                }
                if let issues {
                    state.openIssueCount = issues.open
                    state.urgentIssueCount = issues.urgent
                    state.loaded.insert(.issues)
                }
                return .none

            case let .moduleTapped(module):
                switch module {
                case .shopping:
                    state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                case .recipes:
                    state.path.append(.recipes(RecipesFeature.State(homeID: state.homeID)))
                case .movies:
                    state.path.append(.movies(MoviesFeature.State(homeID: state.homeID)))
                case .finance:
                    state.path.append(.finance(FinanceFeature.State(
                        homeID: state.homeID,
                        currentUserID: state.currentUserID
                    )))
                case .calendar:
                    state.path.append(.calendar(CalendarFeature.State(
                        homeID: state.homeID,
                        currentUserID: state.currentUserID
                    )))
                case .maintenance:
                    state.path.append(.issues(IssuesFeature.State(
                        homeID: state.homeID,
                        currentUserID: state.currentUserID
                    )))
                }
                return .none

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

            // A recipe asking for the shopping list: back out to the Hub, then
            // push the list — rather than stacking one module inside another.
            //
            // Unwind first and push second, never both in one pass. The recipe
            // screen presents its detail with `navigationDestination(item:)`
            // *inside* the stack this `path` drives, so by the time this action
            // arrives one destination is already being dismissed. Popping the
            // recipe screen and pushing the list on top of that asked SwiftUI to
            // unwind two levels and push a third in a single update, which it
            // does not do: it left the recipe on screen while the state said
            // "shopping", the detached views re-ran their `task` into elements
            // that no longer existed, and a second tap went nowhere at all.
            // Unwinding several levels at once is fine; it is the push in the
            // same breath that it cannot reconcile.
            case let .path(.element(id: id, action: .recipes(.delegate(.openShoppingList)))):
                state.path.pop(from: id)
                return .run { send in
                    try await clock.sleep(for: Self.unwind)
                    await send(.showShoppingList)
                }
                .cancellable(id: CancelID.handoff, cancelInFlight: true)

            // Money spent on a party, opened at the party. Finance and the
            // calendar are siblings on this stack and neither knows the other
            // exists — Finance says which event, and the Hub, which put both
            // screens here, is the one place that knows where events are shown.
            //
            // A plain push rather than the pop-and-wait dance above: the
            // calendar goes *on top* of the ledger, so nothing is unwinding
            // while it arrives, and the back button lands where it should.
            case let .path(.element(id: _, action: .finance(.delegate(.openEvent(eventID, day))))),
                 let .path(.element(id: _, action: .issues(.delegate(.openEvent(eventID, day))))):
                state.path.append(.calendar(CalendarFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.currentUserID,
                    day: day,
                    openingEventID: eventID
                )))
                return .none

            // The parts for a repair are ordinary shopping, so "show me the
            // parts" is the shopping list — pushed on top of the problem rather
            // than unwound to, because the household is in the middle of
            // something and the back button should land them back in it.
            case .path(.element(id: _, action: .issues(.delegate(.openShoppingList)))):
                state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                return .none

            case .showShoppingList:
                // If the person went somewhere else while the pop was playing,
                // leave them there rather than yanking them to the list.
                guard state.path.isEmpty else { return .none }
                state.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

/// The tiles on the Hub.
///
/// `notes` used to be listed here as "coming soon" while also being its own tab,
/// so it is not a module — it is one tap away on the tab bar.
public enum HubModule: String, CaseIterable, Identifiable, Sendable {
    // Declaration order is grid order. It used to end with the one module
    // that was not built yet, because a disabled tile in the middle of the
    // grid reads as the household's own list being broken rather than as
    // something still coming. All six are built now, so the order is simply
    // how often a household reaches for them — and House Problems keeps the
    // last slot, because it is the one you hope not to need.
    case shopping, recipes, movies, finance, calendar, maintenance

    public var id: String { rawValue }

    public var title: LocalizedStringResource {
        switch self {
        case .shopping: L10n.managementModuleShoppingTitle
        case .recipes: L10n.managementModuleRecipesTitle
        case .movies: L10n.managementModuleMoviesTitle
        case .maintenance: L10n.managementModuleMaintenanceTitle
        case .finance: L10n.managementModuleFinanceTitle
        case .calendar: L10n.managementModuleCalendarTitle
        }
    }

    public var subtitle: LocalizedStringResource {
        switch self {
        case .shopping: L10n.managementModuleShoppingSubtitle
        case .recipes: L10n.managementModuleRecipesSubtitle
        case .movies: L10n.managementModuleMoviesSubtitle
        case .maintenance: L10n.managementModuleMaintenanceSubtitle
        case .finance: L10n.managementModuleFinanceSubtitle
        case .calendar: L10n.managementModuleCalendarSubtitle
        }
    }

    public var symbol: String {
        switch self {
        case .shopping: "cart.fill"
        case .recipes: "fork.knife"
        case .movies: "film.fill"
        case .maintenance: "wrench.adjustable.fill"
        case .finance: "dollarsign.circle.fill"
        case .calendar: "calendar.badge.clock"
        }
    }

    public var tint: Color {
        switch self {
        case .shopping: Palette.success
        case .recipes: Palette.warning
        case .movies: Palette.violet
        case .maintenance: Palette.cyan
        case .finance: Palette.indigo
        case .calendar: Palette.danger
        }
    }

    /// Every module is built. The flag stays because the grid is where a
    /// future one would arrive, and a tile that reads "coming soon" is a
    /// promise the app should be able to make without a new code path.
    public var isAvailable: Bool { true }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension HubFeature.Path.State: Equatable {}
