import ComposableArchitecture
import Foundation

/// The tab container, alive only while a home is open.
///
/// Each tab owns its own state and its own live subscriptions, and they are torn
/// down together when the home changes — which is what replaces the old
/// `.homeDidChange` notification that every view model listened to and answered
/// with a full refetch.
@Reducer
public struct MainFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var home: Home?
        public var user: User?
        public var selectedTab: Tab = .home

        /// Pushed on top of the Home tab.
        public var homePath = StackState<HomePath.State>()

        public var homeTab: HomeFeature.State
        public var hub: HubFeature.State
        public var notes: NotesFeature.State
        public var messages: MessagesFeature.State
        public var settings: SettingsFeature.State

        /// The bell in the corner.
        ///
        /// Here rather than on the Home tab, though that is where the button
        /// is drawn, because its badge subscription has to outlive whichever
        /// tab happens to be on screen — and because the row that is tapped in
        /// it routes to whatever module owns the thing that happened, which is
        /// knowledge only this reducer has.
        public var inbox: InboxFeature.State

        public init(homeID: HomeID, home: Home? = nil, user: User? = nil) {
            self.homeID = homeID
            self.home = home
            self.user = user
            var homeTab = HomeFeature.State(homeID: homeID, user: user)
            // Read from `home` directly: `memberCount` is a computed property on
            // `self`, which is not fully initialised yet.
            homeTab.memberCount = max(home?.members.count ?? 1, 1)
            self.homeTab = homeTab
            self.hub = HubFeature.State(homeID: homeID, currentUserID: user?.id)
            self.notes = NotesFeature.State(homeID: homeID, currentUserID: user?.id)
            self.messages = MessagesFeature.State(homeID: homeID, currentUserID: user?.id)
            self.settings = SettingsFeature.State(homeID: homeID, home: home, user: user)
            self.inbox = InboxFeature.State(homeID: homeID, currentUserID: user?.id)
        }

        /// How many people have to say yes for a movie-night match.
        var memberCount: Int { max(home?.members.count ?? 1, 1) }
    }

    @Reducer
    public enum HomePath {
        case tasks(TasksFeature)
        /// The chores that have aged off the Done list. Pushed from the Tasks
        /// screen, which carries the recent half and nothing else.
        case taskArchive(TaskArchiveFeature)
        case contributions(ContributionsFeature)
        case movieNight(MovieNightFeature)
        /// Reached from tonight's dinner card, which is the one place on the
        /// Home tab that points at a specific recipe.
        case recipeDetail(RecipeDetailFeature)
    }

    public enum Tab: String, CaseIterable, Hashable, Sendable {
        case home, hub, notes, messages, settings

        public var symbol: String {
            switch self {
            case .home: "house.fill"
            case .hub: "square.grid.2x2.fill"
            case .notes: "note.text"
            case .messages: "bubble.left.and.bubble.right.fill"
            case .settings: "gearshape.fill"
            }
        }

        public var title: LocalizedStringResource {
            switch self {
            case .home: L10n.tabBarHome
            case .hub: L10n.tabBarHub
            case .notes: L10n.tabBarNotes
            case .messages: L10n.tabBarMessages
            case .settings: L10n.tabBarSettings
            }
        }
    }

    public enum Action {
        case tabSelected(Tab)
        case homePath(StackActionOf<HomePath>)
        case home(HomeFeature.Action)
        case hub(HubFeature.Action)
        case notes(NotesFeature.Action)
        case messages(MessagesFeature.Action)
        case settings(SettingsFeature.Action)
        case inbox(InboxFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.homeTab, action: \.home) { HomeFeature() }
        Scope(state: \.hub, action: \.hub) { HubFeature() }
        Scope(state: \.notes, action: \.notes) { NotesFeature() }
        Scope(state: \.messages, action: \.messages) { MessagesFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Scope(state: \.inbox, action: \.inbox) { InboxFeature() }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // The Home tab is a summary; its tiles are shortcuts into the tab or
            // screen that actually owns the data.
            case .home(.delegate(.openShoppingList)),
                 .homePath(.element(id: _, action: .recipeDetail(.delegate(.openShoppingList)))):
                state.selectedTab = .hub
                state.hub.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                return .none

            // The calendar is a Hub module, so opening it from the Home tab is
            // both a tab switch and a push — the same shape as the shopping list
            // above, and the reason both are delegates rather than navigation
            // the Home tab does itself.
            case .home(.delegate(.openCalendar)):
                state.selectedTab = .hub
                state.hub.path.append(.calendar(CalendarFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id
                )))
                return .none

            case let .home(.delegate(.openEvent(occurrence))):
                state.selectedTab = .hub
                // Opened *at* the event, not merely on its day: the grid behind
                // it shows the right date and the sheet for the thing that was
                // tapped is already up.
                state.hub.path.append(.calendar(CalendarFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id,
                    showing: occurrence
                )))
                return .none

            case .home(.delegate(.openIssues)):
                state.selectedTab = .hub
                state.hub.path.append(.issues(IssuesFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id
                )))
                return .none

            case let .home(.delegate(.openEventID(eventID, day))):
                state.selectedTab = .hub
                state.hub.path.append(.calendar(CalendarFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id,
                    day: day,
                    openingEventID: eventID
                )))
                return .none

            case .home(.delegate(.openNotes)):
                state.selectedTab = .notes
                return .none

            case .home(.delegate(.openMessages)):
                state.selectedTab = .messages
                return .none

            case .home(.delegate(.openTasks)):
                state.homePath.append(.tasks(TasksFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id
                )))
                return .none

            // The Done list is bounded on purpose; this is where the rest of
            // it lives. A push rather than a sheet because it is a drill-down
            // into the same subject, and somebody reading their household's
            // year of chores wants to come back to where they were.
            case .homePath(.element(id: _, action: .tasks(.delegate(.openArchive)))):
                state.homePath.append(.taskArchive(TaskArchiveFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id
                )))
                return .none

            case .home(.delegate(.openContributions)):
                state.homePath.append(.contributions(ContributionsFeature.State(
                    homeID: state.homeID,
                    currentUserID: state.user?.id
                )))
                return .none

            case let .home(.delegate(.openRecipe(recipe))):
                state.homePath.append(
                    .recipeDetail(RecipeDetailFeature.State(recipe: recipe, homeID: state.homeID))
                )
                return .none

            case .home(.delegate(.openMovieNight)):
                state.homePath.append(.movieNight(MovieNightFeature.State(
                    homeID: state.homeID,
                    memberCount: state.memberCount,
                    currentUserID: state.user?.id
                )))
                return .none

            // A row in the notification panel goes to whatever module owns
            // the thing that happened. The panel deliberately does not know
            // where anything lives — it hands over a category, and this is the
            // one place in the app that knows the shape of the whole of it.
            case let .inbox(.delegate(.open(category))):
                return route(&state, to: category)

            case .homePath, .home, .hub, .notes, .messages, .settings, .inbox:
                return .none
            }
        }
        .forEach(\.homePath, action: \.homePath)
    }

    /// Opens whatever owns a category of notification.
    ///
    /// The same map `push` routes a tapped banner by, which is why both sides
    /// speak in categories: a notification that opened one place from the lock
    /// screen and another from the panel would be two behaviours for one tap.
    ///
    /// Category rather than the specific document, and honestly so — the screen
    /// is the answer to "where did this happen", and every row can give it. A
    /// row that claimed to open one particular chore and did not would be
    /// worse than one that opens the chore list.
    private func route(
        _ state: inout State,
        to category: ActivityCategory
    ) -> Effect<Action> {
        switch category {
        case .tasks:
            pushHome(&state, .tasks(TasksFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            )))

        case .shopping:
            pushHub(&state, .shopping(ShoppingFeature.State(homeID: state.homeID)))

        case .calendar:
            pushHub(&state, .calendar(CalendarFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            )))

        case .finance:
            pushHub(&state, .finance(FinanceFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            )))

        case .issues:
            pushHub(&state, .issues(IssuesFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            )))

        case .movies:
            pushHub(&state, .movies(MoviesFeature.State(homeID: state.homeID)))

        // A meal plan and a recipe are the same shelf seen from two sides, and
        // the shelf is where both notifications lead.
        case .meals, .recipes:
            pushHub(&state, .recipes(RecipesFeature.State(homeID: state.homeID)))

        // The household's votes live in the movie-night game, which is the only
        // screen that presents one.
        case .polls:
            pushHome(&state, .movieNight(MovieNightFeature.State(
                homeID: state.homeID,
                memberCount: state.memberCount,
                currentUserID: state.user?.id
            )))

        case .notes:
            state.selectedTab = .notes

        case .messages:
            state.selectedTab = .messages

        // Membership, invites, somebody joining or leaving — all of which are
        // Settings' subject.
        case .home:
            state.selectedTab = .settings

        // Unreachable: `.other` is not routable, and the panel refuses to send
        // a delegate for one. Handled rather than defaulted so that adding a
        // category to `ActivityCategory` is a compile error here, which is the
        // only reliable way to be reminded to give it a destination.
        case .other:
            break
        }
        return .none
    }

    /// Pushes onto the Hub's stack, switching to it first.
    ///
    /// Skips the push when that screen is already on top, so tapping two
    /// notifications about the shopping in a row leaves one shopping list on
    /// the stack rather than two to back out of.
    private func pushHub(_ state: inout State, _ destination: HubFeature.Path.State) {
        state.selectedTab = .hub
        guard !isSameCase(state.hub.path.last, destination) else { return }
        state.hub.path.append(destination)
    }

    private func pushHome(_ state: inout State, _ destination: HomePath.State) {
        state.selectedTab = .home
        guard !isSameCase(state.homePath.last, destination) else { return }
        state.homePath.append(destination)
    }

    /// Whether two destinations are the same screen, ignoring their contents.
    ///
    /// Compared by case name rather than by value: two `ShoppingFeature.State`
    /// built a second apart are not equal — one has rows in it and the other
    /// does not — but they are unmistakably the same screen, and pushing the
    /// second on top of the first is the bug this exists to prevent.
    private func isSameCase<T>(_ lhs: T?, _ rhs: T) -> Bool {
        guard let lhs else { return false }
        return String(describing: lhs).prefix(while: { $0 != "(" })
            == String(describing: rhs).prefix(while: { $0 != "(" })
    }
}

extension MainFeature.State {
    /// Keeps the per-tab copies of the session in step.
    public mutating func propagateSession() {
        homeTab.user = user
        homeTab.memberCount = memberCount
        notes.currentUserID = user?.id
        hub.currentUserID = user?.id
        // Not a bare assignment: a chat already pushed onto the Messages stack
        // holds its own copy of the session, and needs the new one too.
        messages.apply(currentUserID: user?.id, homeName: home?.name)
        settings.user = user
        settings.home = home
        inbox.currentUserID = user?.id
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MainFeature.HomePath.State: Equatable {}
