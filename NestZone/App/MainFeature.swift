import ComposableArchitecture
import Foundation

/// The tab container, alive only while a home is open.
///
/// Each tab owns its own state and its own live subscriptions, and they are torn
/// down together when the home changes — which is what replaces the old
/// `.homeDidChange` notification that every view model listened to and answered
/// with a full refetch.
///
/// Five tabs: Today, Lists, Plans, House and Messages. Lists, Plans and House
/// each hold several modules behind a segment switch, so every module has
/// exactly one home on the tab bar and a tap anywhere in the app either
/// switches to it or opens something where the person already is, never both
/// at once. They replaced two tabs pinned to one module each — a tab for the
/// shopping list alone was, a tester said, overkill — and a Household list of
/// everything else.
@Reducer
public struct MainFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var homeID: HomeID
        public var home: Home?
        public var user: User?
        public var selectedTab: Tab = .today

        /// Today's summary, drawn as the root of `today`.
        public var homeTab: HomeFeature.State
        public var today = RouteStack.State()
        public var lists: RouteStack.State
        public var plans: RouteStack.State
        public var house: RouteStack.State
        public var messages: MessagesFeature.State

        /// What is happening now and what is for dinner tonight: the dock over
        /// the tab bar, the dinner sheet every tab shares, and the unread count
        /// on Messages.
        public var now: NowFeature.State

        /// Behind the avatar on every tab rather than a tab of its own: it is
        /// opened once a month, and it was holding a slot that a list used
        /// every day could have.
        ///
        /// Its state lives here, not in the presentation, because `AppFeature`
        /// keeps feeding it — the homes, the push registration — whether or not
        /// the sheet is up.
        public var settings: SettingsFeature.State
        public var isSettingsPresented = false

        /// Choosing what Today shows — from Today's own link, or from Settings.
        @Presents public var customize: CustomizeFeature.State?

        /// Add anything: one field that files a line in the right module,
        /// opened by the dock's "+" on every tab.
        @Presents public var capture: CaptureFeature.State?
        /// What Add anything just wrote, said for a few seconds over the tab
        /// bar with a way to go and look at it.
        public var captured: CaptureOutcome?

        /// The bell in the corner of every tab.
        ///
        /// Here rather than on any one tab because its badge subscription has
        /// to outlive whichever tab happens to be on screen — and because the
        /// row that is tapped in it routes to whatever module owns the thing
        /// that happened, which is knowledge only this reducer has.
        public var inbox: InboxFeature.State

        public init(
            homeID: HomeID,
            home: Home? = nil,
            user: User? = nil,
            segments: [TabGroup: HubModule] = TabSegments.stored
        ) {
            self.homeID = homeID
            self.home = home
            self.user = user
            var homeTab = HomeFeature.State(homeID: homeID, user: user)
            // Read from `home` directly: `memberCount` is a computed property on
            // `self`, which is not fully initialised yet.
            let memberCount = max(home?.members.count ?? 1, 1)
            homeTab.memberCount = memberCount
            self.homeTab = homeTab
            func stack(_ group: TabGroup) -> RouteStack.State {
                RouteStack.State(
                    group: group,
                    selected: segments[group] ?? group.defaultModule
                ) { module in
                    Self.screen(for: module, homeID: homeID, userID: user?.id)
                }
            }
            self.lists = stack(.lists)
            self.plans = stack(.plans)
            self.house = stack(.house)
            self.messages = MessagesFeature.State(homeID: homeID, currentUserID: user?.id)
            var now = NowFeature.State(homeID: homeID, currentUserID: user?.id)
            // From the home the app already has, so a dinner round opened
            // before the members query answers does not match on one vote.
            now.memberCount = memberCount
            self.now = now
            self.settings = SettingsFeature.State(homeID: homeID, home: home, user: user)
            self.inbox = InboxFeature.State(homeID: homeID, currentUserID: user?.id)
        }

        /// How many people have to say yes for a movie-night match.
        var memberCount: Int { max(home?.members.count ?? 1, 1) }

        /// A fresh screen for a module, knowing who is looking.
        static func screen(for module: HubModule, homeID: HomeID, userID: UserID?) -> Route.State {
            switch module {
            case .tasks: .tasks(TasksFeature.State(homeID: homeID, currentUserID: userID))
            case .shopping: .shopping(ShoppingFeature.State(homeID: homeID))
            case .notes: .notes(NotesFeature.State(homeID: homeID, currentUserID: userID))
            case .calendar: .calendar(CalendarFeature.State(homeID: homeID, currentUserID: userID))
            case .recipes: .recipes(RecipesFeature.State(homeID: homeID))
            case .movies: .movies(MoviesFeature.State(homeID: homeID))
            case .finance: .finance(FinanceFeature.State(homeID: homeID, currentUserID: userID))
            case .maintenance: .issues(IssuesFeature.State(homeID: homeID, currentUserID: userID))
            }
        }
    }

    public enum Tab: String, CaseIterable, Hashable, Sendable {
        case today, lists, plans, house, messages

        /// The tab a group of modules lives on.
        init(_ group: TabGroup) {
            switch group {
            case .lists: self = .lists
            case .plans: self = .plans
            case .house: self = .house
            }
        }
    }

    public enum Action {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case today(RouteStack.Action)
        case lists(RouteStack.Action)
        case plans(RouteStack.Action)
        case house(RouteStack.Action)
        case messages(MessagesFeature.Action)
        case now(NowFeature.Action)
        case settings(SettingsFeature.Action)
        case settingsButtonTapped
        case settingsDismissed
        case customize(PresentationAction<CustomizeFeature.Action>)
        /// Settings asked for by a notification row, raised once the panel
        /// that asked has finished going away.
        case presentSettings
        case inbox(InboxFeature.Action)
        case capture(PresentationAction<CaptureFeature.Action>)
        /// The confirmation's "Open".
        case capturedOpenTapped
        case capturedDismissed
    }

    private enum CancelID { case presentSettings, captured }

    /// How long "Added 3 to Shopping" stays up.
    static let capturedLinger: Duration = .seconds(4)

    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.homeTab, action: \.home) { HomeFeature() }
        Scope(state: \.today, action: \.today) { RouteStack() }
        Scope(state: \.lists, action: \.lists) { RouteStack() }
        Scope(state: \.plans, action: \.plans) { RouteStack() }
        Scope(state: \.house, action: \.house) { RouteStack() }
        Scope(state: \.messages, action: \.messages) { MessagesFeature() }
        Scope(state: \.now, action: \.now) { NowFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Scope(state: \.inbox, action: \.inbox) { InboxFeature() }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // Today is a summary; everything on it opens the screen that owns
            // the data — its own tab for a whole module, Today's stack for one
            // particular thing.
            case let .home(.delegate(delegate)):
                switch delegate {
                case .openTasks: return open(.module(.tasks), from: .today, &state)
                case .openShoppingList: return open(.module(.shopping), from: .today, &state)
                case .openNotes: return open(.module(.notes), from: .today, &state)
                case .openCalendar: return open(.module(.calendar), from: .today, &state)
                case .openIssues: return open(.module(.maintenance), from: .today, &state)
                case .openFinance: return open(.module(.finance), from: .today, &state)
                case .openMessages: return open(.messages, from: .today, &state)
                case let .openIssue(issueID): return open(.issue(issueID), from: .today, &state)
                case let .openEvent(occurrence): return open(.occurrence(occurrence), from: .today, &state)
                case let .openEventID(eventID, day): return open(.event(eventID, day), from: .today, &state)
                case .openContributions: return open(.contributions, from: .today, &state)
                case let .openRecipe(recipe): return open(.recipe(recipe), from: .today, &state)
                case .openMovieNight: return open(.movieNight, from: .today, &state)
                case .openStats: return open(.stats, from: .today, &state)
                case .openCustomize:
                    state.customize = CustomizeFeature.State()
                    return .none
                case .addChore:
                    state.presentCapture(kind: .chore)
                    return .none
                case .decideDinner: return .send(.now(.decideDinnerTapped))
                case .acceptDinnerSuggestion: return .send(.now(.dinnerSuggestionAccepted))
                case .makeOccasion: return .send(.now(.makeOccasionTapped))
                // The invite code lives in Settings.
                case .openInvite:
                    state.isSettingsPresented = true
                    return .none
                // `AppFeature`'s to answer.
                case .notificationsEnabled:
                    return .none
                }

            case let .today(.delegate(.open(target))):
                return open(target, from: .today, &state)
            case let .lists(.delegate(.open(target))):
                return open(target, from: .lists, &state)
            case let .plans(.delegate(.open(target))):
                return open(target, from: .plans, &state)
            case let .house(.delegate(.open(target))):
                return open(target, from: .house, &state)

            // The segment each tab was left on is where it opens next launch.
            case let .lists(.segmentPicked(module)),
                 let .plans(.segmentPicked(module)),
                 let .house(.segmentPicked(module)):
                TabSegments.remember(module)
                return .none

            case let .now(.delegate(delegate)):
                switch delegate {
                case let .openEvent(occurrence):
                    return open(.occurrence(occurrence), from: state.selectedTab, &state)
                case .openMovieNight:
                    return open(.movieNight, from: state.selectedTab, &state)
                case .capture:
                    state.presentCapture()
                    return .none
                }

            // Tonight and the clock, handed to the two screens that draw them.
            case .now:
                state.propagateNow()
                return .none

            case .settingsButtonTapped, .presentSettings:
                state.isSettingsPresented = true
                return .none

            case .settingsDismissed:
                state.isSettingsPresented = false
                return .none

            // Opened over Settings, which stays underneath.
            case .settings(.delegate(.customizeTapped)):
                state.customize = CustomizeFeature.State()
                return .none

            case .customize(.presented(.delegate(.finished))):
                state.customize = nil
                return .none

            // Closed by the sheet itself, with what was written — or with
            // nothing, for Cancel. A swipe down never reaches here; the
            // presentation simply clears, which is a cancel too.
            case let .capture(.presented(.delegate(.finished(outcome)))):
                state.capture = nil
                guard let outcome else { return .none }
                state.captured = outcome
                return .run { send in
                    try await clock.sleep(for: Self.capturedLinger)
                    await send(.capturedDismissed)
                }
                .cancellable(id: CancelID.captured, cancelInFlight: true)

            case .capturedOpenTapped:
                guard let outcome = state.captured else { return .none }
                state.captured = nil
                return .merge(
                    .cancel(id: CancelID.captured),
                    open(.module(outcome.kind.module), from: state.selectedTab, &state)
                )

            case .capturedDismissed:
                state.captured = nil
                return .none

            // A row in the notification panel goes to whatever module owns
            // the thing that happened. The panel deliberately does not know
            // where anything lives — it hands over a category, and this is the
            // one place in the app that knows the shape of the whole of it.
            case let .inbox(.delegate(.open(category))):
                return route(&state, to: category)

            case .home, .today, .lists, .plans, .house, .messages,
                 .settings, .inbox, .customize, .capture:
                return .none
            }
        }
        .ifLet(\.$customize, action: \.customize) { CustomizeFeature() }
        .ifLet(\.$capture, action: \.capture) { CaptureFeature() }
    }

    /// Takes the person somewhere a screen asked to go.
    ///
    /// A whole module goes to its tab, switched to its segment and back to the
    /// root, since the list is what was asked for. Anything else opens on the
    /// stack the request came from, where the back button returns to the
    /// screen that asked. Never a tab switch *and* a push.
    private func open(
        _ target: RouteStack.Target,
        from tab: Tab,
        _ state: inout State
    ) -> Effect<Action> {
        let screen: Route.State
        switch target {
        case let .module(module):
            let destination = Tab(module.group)
            state.selectedTab = destination
            state[stack: destination].selected = module
            state[stack: destination].path.removeAll()
            TabSegments.remember(module)
            return .none
        // A tab with no stack to push onto: the screen is the tab.
        case .messages:
            state.selectedTab = .messages
            return .none
        case .decideDinner:
            return .send(.now(.decideDinnerTapped))
        case let .event(eventID, day):
            screen = .calendar(CalendarFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                day: day,
                openingEventID: eventID
            ))
        // Opened *at* the event, not merely on its day: the grid behind it
        // shows the right date and the sheet for the thing that was tapped is
        // already up.
        case let .occurrence(occurrence):
            screen = .calendar(CalendarFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                showing: occurrence
            ))
        case let .issue(issueID):
            screen = .issues(IssuesFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                openingIssueID: issueID
            ))
        case let .recipe(recipe):
            screen = .recipeDetail(RecipeDetailFeature.State(recipe: recipe, homeID: state.homeID))
        // The Done list is bounded on purpose; this is where the rest of it
        // lives. A push because it is a drill-down into the same subject.
        case .taskArchive:
            screen = .taskArchive(TaskArchiveFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            ))
        case .contributions:
            screen = .contributions(ContributionsFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id
            ))
        case .movieNight:
            screen = .movieNight(MovieNightFeature.State(
                homeID: state.homeID,
                memberCount: state.memberCount,
                currentUserID: state.user?.id
            ))
        case .stats:
            screen = .stats(HouseStatsFeature.State(homeID: state.homeID))
        }

        // Chat's stack holds conversations and nothing else, so a request that
        // arrives while it is on screen (a notification row, say) opens on the
        // tab that owns its subject.
        let tab = tab == .messages ? Self.owner(of: target) : tab
        state.selectedTab = tab
        push(screen, onto: tab, isSpecific: target.isSpecific, &state)
        return .none
    }

    /// Where a specific thing is opened when the person is somewhere it cannot
    /// be pushed: the tab whose modules it belongs to.
    private static func owner(of target: RouteStack.Target) -> Tab {
        switch target {
        case let .module(module): Tab(module.group)
        case .taskArchive, .contributions: .lists
        case .event, .occurrence, .recipe, .movieNight, .decideDinner: .plans
        case .issue, .stats: .house
        case .messages: .messages
        }
    }

    /// Pushes a screen, unless that same screen is already on top — or is the
    /// tab's own root with nothing above it.
    ///
    /// So opening the chore split twice leaves one on the stack rather than
    /// two to back out of. Not for a specific thing — an event, a problem, a
    /// recipe — which is a different screen from the module it lives in even
    /// when the case is the same: the calendar at the root of Plans is not
    /// "Friday's dinner", and refusing the push there opened nothing at all.
    /// Those are only skipped when the very same one is already on top.
    private func push(_ screen: Route.State, onto tab: Tab, isSpecific: Bool, _ state: inout State) {
        let stack = state[stack: tab]
        if isSpecific {
            if stack.path.last == screen { return }
        } else if let top = stack.path.last ?? stack.root, top.isSameScreen(as: screen) {
            return
        }
        state[stack: tab].path.append(screen)
    }

    /// Opens whatever owns a category of notification.
    ///
    /// Category rather than the specific document, and honestly so — the screen
    /// is the answer to "where did this happen", and every row can give it. A
    /// row that claimed to open one particular chore and did not would be
    /// worse than one that opens the chore list.
    private func route(
        _ state: inout State,
        to category: ActivityCategory
    ) -> Effect<Action> {
        let from = state.selectedTab
        switch category {
        case .tasks: return open(.module(.tasks), from: from, &state)
        case .shopping: return open(.module(.shopping), from: from, &state)
        case .calendar: return open(.module(.calendar), from: from, &state)
        case .finance: return open(.module(.finance), from: from, &state)
        case .issues: return open(.module(.maintenance), from: from, &state)
        case .movies: return open(.module(.movies), from: from, &state)
        case .notes: return open(.module(.notes), from: from, &state)

        // A meal plan and a recipe are the same shelf seen from two sides, and
        // the shelf is where both notifications lead.
        case .meals, .recipes: return open(.module(.recipes), from: from, &state)

        // The household's votes live in the movie-night game, which is the only
        // screen that presents one.
        case .polls: return open(.movieNight, from: from, &state)

        case .messages:
            state.selectedTab = .messages
            return .none

        // Membership, invites, somebody joining or leaving — all of which are
        // Settings' subject. A sheet, and the panel is a sheet that is only
        // now going away: presenting one while the other is still leaving is
        // dropped by SwiftUI, so this waits for it.
        case .home:
            return .run { send in
                try await clock.sleep(for: RouteStack.unwind)
                await send(.presentSettings)
            }
            .cancellable(id: CancelID.presentSettings, cancelInFlight: true)

        // Unreachable: `.other` is not routable, and the panel refuses to send
        // a delegate for one. Handled rather than defaulted so that adding a
        // category to `ActivityCategory` is a compile error here, which is the
        // only reliable way to be reminded to give it a destination.
        case .other:
            return .none
        }
    }
}

extension MainFeature.State {
    /// The stack behind a tab. Chat keeps its own and is never asked for one.
    subscript(stack tab: MainFeature.Tab) -> RouteStack.State {
        get {
            switch tab {
            case .today, .messages: today
            case .lists: lists
            case .plans: plans
            case .house: house
            }
        }
        set {
            switch tab {
            case .today, .messages: today = newValue
            case .lists: lists = newValue
            case .plans: plans = newValue
            case .house: house = newValue
            }
        }
    }

    /// Opens Add anything, knowing who lives here so a name typed in it can
    /// be matched to somebody. `kind` fixes the chip, for a way in that
    /// already said what it was adding.
    mutating func presentCapture(kind: CaptureKind? = nil) {
        capture = CaptureFeature.State(
            homeID: homeID,
            currentUserID: user?.id,
            // Today subscribes to the same list; whichever answered first.
            members: now.members.isEmpty ? homeTab.members : now.members,
            kind: kind
        )
    }

    /// Hands what `now` knows to the screens that draw it: Today, and the
    /// Tonight card at the top of Meals.
    mutating func propagateNow() {
        let tonight = now.tonight
        if homeTab.tonight != tonight { homeTab.tonight = tonight }
        let suggestion = now.dinnerSuggestion
        if homeTab.dinnerSuggestion != suggestion { homeTab.dinnerSuggestion = suggestion }
        let roundOpen = now.movieRounds.contains(where: \.isOpen)
        if homeTab.movieRoundIsOpen != roundOpen { homeTab.movieRoundIsOpen = roundOpen }
        if homeTab.now != now.now { homeTab.now = now.now }
        plans.segments[id: .recipes]?.screen.apply(tonight: tonight)
    }

    /// Keeps the per-tab copies of the session in step.
    public mutating func propagateSession() {
        homeTab.user = user
        homeTab.memberCount = memberCount
        let userID = user?.id
        for stack in [\Self.lists, \.plans, \.house] as [WritableKeyPath<Self, RouteStack.State>] {
            for id in self[keyPath: stack].segments.ids {
                self[keyPath: stack].segments[id: id]?.screen.apply(currentUserID: userID)
            }
        }
        // Not a bare assignment: a chat already pushed onto the Messages stack
        // holds its own copy of the session, and needs the new one too.
        messages.apply(currentUserID: user?.id, homeName: home?.name)
        now.currentUserID = userID
        if now.members.isEmpty { now.memberCount = memberCount }
        settings.user = user
        settings.home = home
        inbox.currentUserID = user?.id
    }
}

extension RouteStack.Target {
    /// Whether this names one particular thing rather than a screen about a
    /// whole subject.
    var isSpecific: Bool {
        switch self {
        case .event, .occurrence, .issue, .recipe: true
        case .module, .taskArchive, .contributions, .movieNight, .stats, .messages, .decideDinner: false
        }
    }
}

extension CaptureKind {
    /// The module a line of this kind was written to.
    var module: HubModule {
        switch self {
        case .shopping: .shopping
        case .chore: .tasks
        case .note: .notes
        case .problem: .maintenance
        case .event: .calendar
        case .expense: .finance
        }
    }
}
