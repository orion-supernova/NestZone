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
        #if DEBUG || MEASURE
        /// `-openTab lists` (or plans, house, messages) opens on that tab, to
        /// watch a tab on a simulator nobody touches.
        public var selectedTab: Tab = UserDefaults.standard.string(forKey: "openTab")
            .flatMap(Tab.init(rawValue:)) ?? .today
        #else
        public var selectedTab: Tab = .today
        #endif

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

        /// The companion on Today. Here rather than inside Today because it
        /// grows from things other screens do — a chore ticked on the Tasks
        /// list counts as much as one ticked on Today — and this is where the
        /// household's finished chores are handed to it.
        public var companion: CompanionFeature.State

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
        /// Naming yourself, from Today's reminder (Settings has its own).
        @Presents public var editName: EditNameFeature.State?

        /// Add anything: one field that files a line in the right module,
        /// opened by the dock's "+" on every tab.
        @Presents public var capture: CaptureFeature.State?
        /// What Add anything just wrote, said for a few seconds over the tab
        /// bar with a way to go and look at it.
        public var captured: CaptureOutcome?
        /// The dock's menu switched it off: a few seconds of "turn it back on
        /// in Edit Today", because the bar and its menu are gone.
        public var dockOffNotice = false

        /// The bell in the corner of every tab.
        ///
        /// Here rather than on any one tab because its badge subscription has
        /// to outlive whichever tab happens to be on screen — and because the
        /// row that is tapped in it routes to whatever module owns the thing
        /// that happened, which is knowledge only this reducer has.
        public var inbox: InboxFeature.State

        /// Whether this house has NestZone Plus: one subscription to
        /// `pro:status` for the life of the tab bar, written to the shared
        /// `.pro` key every gate reads.
        public var pro: ProStatusFeature.State
        /// What this person has reported and blocked, for the life of the tab
        /// bar: the faces and photos they hid, and the people they blocked.
        public var moderation: ModerationSessionFeature.State
        /// `pro:status` has answered once for this house.
        var heardPro = false

        /// House events copied into this person's own calendars, for the life of
        /// the tab bar: it follows the house whether or not the Calendar screen
        /// is open.
        public var mirror: CalendarMirrorFeature.State
        /// The person's own calendars shared with this house, for the same life.
        public var share: CalendarShareFeature.State
        /// Housemates' calendars copied into this person's own calendar app.
        public var sharedCopy: SharedCopyFeature.State

        /// The paywall, opened on whatever was reached for. Presented by
        /// whichever sheet is on top, or the tab bar when none is
        /// (`PaywallHost`).
        @Presents public var paywall: PaywallFeature.State?

        /// Where a first run is, once the person has a home: waiting for
        /// `pro:status` to say whether to offer Plus, then the paywall, then
        /// the first shopping item. Nil for everybody else.
        var firstRun: FirstRunStep?
        /// "Let's add your first shopping item", the last step of a first run.
        @Presents public var firstWin: FirstWinFeature.State?
        /// Settings' "Take the tour", over the Settings sheet.
        @Presents public var tour: OnboardingFeature.State?

        enum FirstRunStep: Equatable { case awaitingPlus, paywall }

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
            var companion = CompanionFeature.State(homeID: homeID)
            companion.memberCount = memberCount
            if CompanionFlag.isEnabled { companion.userID = user?.id }
            self.companion = companion
            self.settings = SettingsFeature.State(homeID: homeID, home: home, user: user)
            self.inbox = InboxFeature.State(homeID: homeID, currentUserID: user?.id)
            self.pro = ProStatusFeature.State(homeID: homeID)
            self.moderation = ModerationSessionFeature.State(homeID: homeID, userID: user?.id)
            self.mirror = CalendarMirrorFeature.State(homeID: homeID, userID: user?.id)
            self.share = CalendarShareFeature.State(homeID: homeID, userID: user?.id)
            self.sharedCopy = SharedCopyFeature.State(homeID: homeID)
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
        case companion(CompanionFeature.Action)
        case settings(SettingsFeature.Action)
        case settingsButtonTapped
        case settingsDismissed
        case customize(PresentationAction<CustomizeFeature.Action>)
        case editName(PresentationAction<EditNameFeature.Action>)
        /// Settings asked for by a notification row, raised once the panel
        /// that asked has finished going away.
        case presentSettings
        case inbox(InboxFeature.Action)
        case capture(PresentationAction<CaptureFeature.Action>)
        /// The confirmation's "Open".
        case capturedOpenTapped
        case capturedDismissed
        /// The dock-off note's "Edit Today" (it opens Customize), or its timer.
        case dockNoticeEditTapped
        case dockNoticeDismissed
        case proStatus(ProStatusFeature.Action)
        case moderation(ModerationSessionFeature.Action)
        case mirror(CalendarMirrorFeature.Action)
        case share(CalendarShareFeature.Action)
        case sharedCopy(SharedCopyFeature.Action)
        case paywall(PresentationAction<PaywallFeature.Action>)
        /// A gated control, or the server, asked for the paywall.
        case paywallRequested(ProFeature?)
        /// The person has a home they just made or joined from the tour: the
        /// rest of the first run (Plus, then the first win) starts here.
        case firstRunBegan
        /// An invite link wants the screen: close everything, then answer
        /// `invitePresentationsClosed`.
        case closeForInvite
        case invitePresentationsClosed
        /// `pro:status` did not answer in time: the offer is skipped, never
        /// guessed.
        case firstRunPlusTimedOut
        /// The paywall is closed and has left: the first win may open.
        case firstWinReady
        case firstWin(PresentationAction<FirstWinFeature.Action>)
        case tour(PresentationAction<OnboardingFeature.Action>)
        /// The paywall was asked for and nothing drew it. State that cannot be
        /// seen is dropped rather than left to swallow the next request.
        case paywallNeverShown
        /// The person tapped a notification: close what is in the way, then
        /// open what it was about.
        case pushTapped(PushTap)
        case pushRouted(PushTap)
        /// A recipe a notification named, found in the house's list (nil when
        /// it is not there).
        case pushRecipeFound(Recipe?)
    }

    private enum CancelID { case presentSettings, captured, dockNotice, paywallShown, firstRunPlus, firstWin }

    /// How long "Added 3 to Shopping" stays up.
    static let capturedLinger: Duration = .seconds(4)
    /// How long the dock-off note stays up: a sentence to read, not a toast to race.
    static let dockNoticeLinger: Duration = .seconds(5)
    /// How long the paywall has to appear before the request is dropped.
    static let paywallShowDeadline: Duration = .seconds(2)
    /// How long a first run waits for `pro:status` before it skips the offer.
    static let firstRunPlusDeadline: Duration = .seconds(6)
    /// A sheet presented in the action that dismisses another is dropped, so
    /// the first win waits for the paywall to have gone.
    static let firstWinDelay: Duration = .milliseconds(650)

    @Dependency(\.continuousClock) var clock
    @Dependency(\.recipes) var recipesClient
    @Dependency(\.presentationCloser) var presentationCloser

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.homeTab, action: \.home) { HomeFeature() }
        Scope(state: \.today, action: \.today) { RouteStack() }
        Scope(state: \.lists, action: \.lists) { RouteStack() }
        Scope(state: \.plans, action: \.plans) { RouteStack() }
        Scope(state: \.house, action: \.house) { RouteStack() }
        Scope(state: \.messages, action: \.messages) { MessagesFeature() }
        Scope(state: \.now, action: \.now) { NowFeature() }
        // Debug builds host Nestie so the Lab can run it against a pretend
        // house; a Release build has the feature and nothing else.
        #if DEBUG
        Scope(state: \.companion, action: \.companion) { CompanionHost() }
        #else
        Scope(state: \.companion, action: \.companion) { CompanionFeature() }
        #endif
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }
        Scope(state: \.inbox, action: \.inbox) { InboxFeature() }
        Scope(state: \.pro, action: \.proStatus) { ProStatusFeature() }
        Scope(state: \.moderation, action: \.moderation) { ModerationSessionFeature() }
        Scope(state: \.mirror, action: \.mirror) { CalendarMirrorFeature() }
        Scope(state: \.share, action: \.share) { CalendarShareFeature() }
        Scope(state: \.sharedCopy, action: \.sharedCopy) { SharedCopyFeature() }

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
                    state.customize = CustomizeFeature.State(homeID: state.homeID)
                    return .none
                case .openEditName:
                    state.editName = EditNameFeature.State(name: state.user?.name ?? "")
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
                    // The invite sheet goes over Settings once it is up: a
                    // sheet asked for in the frame that presents its host is
                    // dropped.
                    return .run { send in
                        try await clock.sleep(for: .milliseconds(450))
                        await send(.settings(.inviteTapped))
                    }
                // `AppFeature`'s to answer.
                case .notificationsEnabled:
                    return .none
                }

            // The companion grows from every finished chore in the house, and
            // "together" needs to know how many people live here.
            case .home(.tasksUpdated):
                guard CompanionFlag.isEnabled else { return .none }
                return .send(.companion(.completionsUpdated(state.homeTab.completions)))
            case .home(.membersUpdated):
                state.companion.memberCount = max(state.homeTab.members.count, 1)
                if CompanionFlag.isEnabled { state.companion.refresh() }
                return .none
            // A birthday in the calendar puts the party hat out for the day.
            case let .home(.upcomingEventsUpdated(events)):
                guard CompanionFlag.isEnabled else { return .none }
                let birthdays = events.filter { $0.kind == .birthday }.flatMap { $0.days() }
                return .send(.companion(.birthdaysUpdated(Set(birthdays))))

            case let .today(.delegate(.open(target))):
                return open(target, from: .today, &state)
            case let .lists(.delegate(.open(target))):
                return open(target, from: .lists, &state)
            case let .plans(.delegate(.open(target))):
                return open(target, from: .plans, &state)
            case let .house(.delegate(.open(target))):
                return open(target, from: .house, &state)

            // The Calendar settings page pushed from the Calendar screen asks
            // what Settings' own copy of the page asks.
            case .today(.delegate(.calendarSettingsChanged)), .lists(.delegate(.calendarSettingsChanged)),
                 .plans(.delegate(.calendarSettingsChanged)), .house(.delegate(.calendarSettingsChanged)):
                return .merge(
                    .send(.mirror(.settingsChanged)),
                    .send(.share(.settingsChanged)),
                    .send(.sharedCopy(.settingsChanged))
                )
            case .today(.delegate(.calendarSyncRequested)), .lists(.delegate(.calendarSyncRequested)),
                 .plans(.delegate(.calendarSyncRequested)), .house(.delegate(.calendarSyncRequested)):
                return .merge(
                    .send(.mirror(.syncNow)),
                    .send(.share(.syncNow)),
                    .send(.sharedCopy(.syncNow))
                )

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
                case let .openModule(module):
                    return open(.module(module), from: state.selectedTab, &state)
                case .editToday:
                    state.customize = CustomizeFeature.State(homeID: state.homeID)
                    return .none
                case .dockTurnedOff:
                    state.dockOffNotice = true
                    return .run { send in
                        try await clock.sleep(for: Self.dockNoticeLinger)
                        await send(.dockNoticeDismissed)
                    }
                    .cancellable(id: CancelID.dockNotice, cancelInFlight: true)
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

            // Where house events are copied to changed.
            case .settings(.delegate(.calendarSettingsChanged)):
                return .merge(
                    .send(.mirror(.settingsChanged)),
                    .send(.share(.settingsChanged)),
                    .send(.sharedCopy(.settingsChanged))
                )

            // "Sync now": every pass that moves calendars, once, together.
            case .settings(.delegate(.calendarSyncRequested)):
                return .merge(
                    .send(.mirror(.syncNow)),
                    .send(.share(.syncNow)),
                    .send(.sharedCopy(.syncNow))
                )

            // Opened over Settings, which stays underneath.
            case .settings(.delegate(.customizeTapped)):
                state.customize = CustomizeFeature.State(homeID: state.homeID)
                return .none

            #if DEBUG
            // The Lab is watched against the card, so it opens on Today with
            // Settings out of the way. A sheet presented in the action that
            // dismisses another is dropped, hence the beat before it.
            case .settings(.delegate(.nestieLabRequested)):
                state.isSettingsPresented = false
                state.selectedTab = .today
                return .run { send in
                    try await clock.sleep(for: .milliseconds(450))
                    await send(.companion(.labTapped))
                }
            #endif

            case .editName(.presented(.finished)):
                state.editName = nil
                return .none

            case .customize(.presented(.delegate(.finished))):
                state.customize = nil
                // The dock setting may have just changed, and only `now`
                // actions hand the dock's item down to Today.
                state.propagateNow()
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

            case .dockNoticeEditTapped:
                state.dockOffNotice = false
                state.customize = CustomizeFeature.State(homeID: state.homeID)
                return .cancel(id: CancelID.dockNotice)

            case .dockNoticeDismissed:
                state.dockOffNotice = false
                return .none

            // A row in the notification panel goes to whatever module owns
            // the thing that happened. The panel deliberately does not know
            // where anything lives — it hands over a category, and this is the
            // one place in the app that knows the shape of the whole of it.
            case let .inbox(.delegate(.open(category))):
                return route(&state, to: category)

            // A tapped notification. Whatever is covering the tabs goes first
            // (a sheet presented while another is leaving is dropped), then the
            // same routes the bell's rows use, or the one thing it names.
            case let .pushTapped(tap):
                // Anything presented anywhere, however deep (read before the
                // state below is cleared, while the sheets are still up).
                var (covered, closing) = closeEverything(&state)
                guard covered else { return .send(.pushRouted(tap)) }
                // State first (so each feature's own presentation is already
                // cleared), then whatever is still up goes from the root, in
                // one dismissal that unwinds every level. A person typing in
                // a composer loses the draft, as with the bell's cross-links.
                return .merge(closing + [
                    .run { send in
                        await presentationCloser.dismissAll()
                        // A beat more for nested chains still leaving.
                        try await clock.sleep(for: .milliseconds(450))
                        await send(.pushRouted(tap))
                    }
                    .cancellable(id: PushTapCancel.routing, cancelInFlight: true)
                ])

            // An invite link arrived with something open: the same closing,
            // then the root shows its card.
            case .closeForInvite:
                let (covered, closing) = closeEverything(&state)
                guard covered else { return .send(.invitePresentationsClosed) }
                return .merge(closing + [
                    .run { send in
                        await presentationCloser.dismissAll()
                        try await clock.sleep(for: .milliseconds(450))
                        await send(.invitePresentationsClosed)
                    }
                    .cancellable(id: PushTapCancel.routing, cancelInFlight: true)
                ])

            case .invitePresentationsClosed:
                return .none

            case let .pushRouted(tap):
                // A ceremony held for the tap may play once the destination
                // has had a moment.
                return .merge(
                    routePush(&state, tap),
                    .run { send in
                        try await clock.sleep(for: .seconds(1))
                        await send(.companion(.navigationSettled))
                    }
                )

            case let .pushRecipeFound(recipe):
                if let recipe { return open(.recipe(recipe), from: state.selectedTab, &state) }
                return open(.module(.recipes), from: state.selectedTab, &state)

            // The first answer for a house without Plus opens its tabs on the
            // modules it can use. Handled on the status itself rather than on
            // the delegate that follows it, so the screens see the answer and
            // the move in one update and never build the module they leave.
            // Only what is on screen moves: the segment each tab was left on
            // (`TabSegments`) is not touched, so it is where the tab opens
            // again once there is Plus.
            case .proStatus(.statusUpdated):
                // A first run was waiting on this answer.
                let firstRun = advanceFirstRun(&state)
                guard !state.heardPro else { return firstRun }
                state.heardPro = true
                if !state.pro.status.isPro {
                    if state.plans.selected == .calendar { state.plans.selected = .recipes }
                    // Money and Problems are both Plus: a free house opens
                    // House on Notes, the one segment it can use.
                    if state.house.selected == .finance || state.house.selected == .maintenance {
                        state.house.selected = .notes
                    }
                }
                return firstRun

            case let .paywallRequested(feature):
                return presentPaywall(&state, feature: feature, context: .sheet)

            case .paywall(.presented(.task)):
                return .cancel(id: CancelID.paywallShown)

            case .paywallNeverShown:
                state.paywall = nil
                return afterPaywall(&state)

            case .paywall(.presented(.delegate(.dismiss))):
                state.paywall = nil
                return .merge(.cancel(id: CancelID.paywallShown), afterPaywall(&state))

            // Swiped away or closed by the system: the same end.
            case .paywall(.dismiss):
                return .merge(.cancel(id: CancelID.paywallShown), afterPaywall(&state))

            // The first run, step by step. Plus is offered only to a house
            // that is known not to have it.
            case .firstRunBegan:
                state.firstRun = .awaitingPlus
                state.homeTab.holdsNotificationAsk = true
                let next = advanceFirstRun(&state)
                guard state.firstRun == .awaitingPlus else { return next }
                return .merge(next, .run { send in
                    try await clock.sleep(for: Self.firstRunPlusDeadline)
                    await send(.firstRunPlusTimedOut)
                }
                .cancellable(id: CancelID.firstRunPlus, cancelInFlight: true))

            case .firstRunPlusTimedOut:
                guard state.firstRun == .awaitingPlus else { return .none }
                state.firstRun = nil
                return startFirstWin()

            case .firstWinReady:
                guard state.firstWin == nil, state.paywall == nil else {
                    return .send(.home(.releaseNotificationAsk))
                }
                state.firstWin = FirstWinFeature.State(homeID: state.homeID)
                return .none

            case .firstWin(.presented(.delegate(.finished))), .firstWin(.dismiss):
                state.firstWin = nil
                return .send(.home(.releaseNotificationAsk))

            case .firstWin(.presented(.delegate(.openShopping))):
                state.firstWin = nil
                return .merge(
                    .send(.home(.releaseNotificationAsk)),
                    open(.module(.shopping), from: state.selectedTab, &state)
                )

            case .settings(.delegate(.tourRequested)):
                state.tour = OnboardingFeature.State(mode: .replay)
                return .none

            case .tour(.presented(.delegate(.finished))):
                state.tour = nil
                return .none

            // Plus turned on or off. Today and the dock start or stop their
            // calendar and bills reads.
            case let .proStatus(.delegate(.changed(isPro, _))):
                return .merge(
                    .send(.home(.proChanged(isPro))),
                    .send(.now(.proChanged(isPro))),
                    // Copying into the person's calendars is Plus: it starts
                    // with it and stops creating and updating without it.
                    .send(.mirror(.settingsChanged)),
                    // Sharing is Plus too: it starts and stops with it.
                    .send(.share(.settingsChanged)),
                    .send(.sharedCopy(.settingsChanged))
                )

            case .home, .today, .lists, .plans, .house, .messages,
                 .settings, .inbox, .customize, .editName, .capture, .companion,
                 .proStatus, .moderation, .mirror, .share, .sharedCopy, .paywall,
                 .firstWin, .tour:
                return .none
            }
        }
        .ifLet(\.$paywall, action: \.paywall) { PaywallFeature() }
        .ifLet(\.$customize, action: \.customize) { CustomizeFeature() }
        .ifLet(\.$editName, action: \.editName) { EditNameFeature() }
        .ifLet(\.$capture, action: \.capture) { CaptureFeature() }
        // The session arrives a moment after the tabs on an optimistic launch.
        // A pass that ran before it knew who "mine" is would have decided on
        // nothing; this runs it again with the person.
        .onChange(of: { $0.mirror.userID }) { _, _ in
            Reduce { _, _ in .send(.mirror(.settingsChanged)) }
        }

        // Kept out of the chain above, which the compiler cannot type-check
        // a modifier longer.
        EmptyReducer()
            .ifLet(\.$firstWin, action: \.firstWin) { FirstWinFeature() }
            .ifLet(\.$tour, action: \.tour) { OnboardingFeature() }
    }

    /// Closes every presentation over the tabs, as a notification tap does.
    /// `covered` says whether anything was up.
    private func closeEverything(_ state: inout State) -> (covered: Bool, closing: [Effect<Action>]) {
        var covered = MainActor.assumeIsolated { presentationCloser.isPresenting() }
        var closing: [Effect<Action>] = []
        if state.companion.isCovering { covered = true }
        // Nestie's card, store and ceremony: the ceremony's moment is
        // kept, not ended.
        state.companion.closeForNavigation()
        if state.inbox.isOpen { covered = true; closing.append(.send(.inbox(.closeTapped))) }
        if state.isSettingsPresented { covered = true; state.isSettingsPresented = false }
        if state.customize != nil { covered = true; state.customize = nil }
        if state.editName != nil { covered = true; state.editName = nil }
        // Add anything closes the way Cancel does, by clearing.
        if state.capture != nil { covered = true; state.capture = nil }
        if state.paywall != nil {
            covered = true
            state.paywall = nil
            closing.append(.cancel(id: CancelID.paywallShown))
        }
        if state.now.dinner != nil { covered = true; state.now.dinner = nil }
        if state.now.occasion != nil { covered = true; state.now.occasion = nil }
        return (covered, closing)
    }

    /// Opens the paywall over whatever is on top (`PaywallHost`).
    private func presentPaywall(
        _ state: inout State,
        feature: ProFeature?,
        context: PaywallFeature.State.Context
    ) -> Effect<Action> {
        guard state.paywall == nil else { return .none }
        state.paywall = PaywallFeature.State(
            feature: feature,
            context: context,
            houseName: state.home?.name ?? "",
            homeNames: Dictionary(
                state.settings.homes.map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
        )
        // Whichever host is on top presents it, which takes a frame
        // or two; its first `.task` is the proof it was drawn.
        return .run { send in
            try await clock.sleep(for: Self.paywallShowDeadline)
            await send(.paywallNeverShown)
        }
        .cancellable(id: CancelID.paywallShown, cancelInFlight: true)
    }

    /// The first run's next step once `pro:status` has answered: the paywall
    /// for a house without Plus, straight to the first win for one that has
    /// it. Never offers Plus on a guess, and never twice.
    private func advanceFirstRun(_ state: inout State) -> Effect<Action> {
        guard state.firstRun == .awaitingPlus, state.pro.status.isLoaded else { return .none }
        if state.pro.status.isPro {
            state.firstRun = nil
            return .merge(.cancel(id: CancelID.firstRunPlus), startFirstWin())
        }
        state.firstRun = .paywall
        return .merge(
            .cancel(id: CancelID.firstRunPlus),
            presentPaywall(&state, feature: nil, context: .onboarding)
        )
    }

    /// The paywall of a first run has closed, bought or not: on to the first win.
    private func afterPaywall(_ state: inout State) -> Effect<Action> {
        guard state.firstRun == .paywall else { return .none }
        state.firstRun = nil
        return startFirstWin()
    }

    private func startFirstWin() -> Effect<Action> {
        .run { send in
            try await clock.sleep(for: Self.firstWinDelay)
            await send(.firstWinReady)
        }
        .cancellable(id: CancelID.firstWin, cancelInFlight: true)
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
        // The calendar is Plus: a specific event for a house without it is
        // the paywall, not a screen it cannot use. (The module itself opens
        // on its own locked or read-only screen.)
        case .event, .occurrence:
            if !state.pro.status.isPro { return .send(.paywallRequested(.calendar)) }
            return openEvent(target, &state, from: tab)
        // Problems are Plus too: a specific one for a house without it is the
        // paywall. (The module opens on its own locked or read-only screen.)
        case let .issue(issueID):
            if !state.pro.status.isPro { return .send(.paywallRequested(.issues)) }
            screen = .issueDetail(IssuePageFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                issueID: issueID
            ))
        case let .recipe(recipe, duplicates):
            screen = .recipeDetail(RecipeDetailFeature.State(
                recipe: recipe,
                homeID: state.homeID,
                duplicateIDs: duplicates
            ))
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
        case .calendarSettings:
            screen = .calendarSettings(CalendarSettingsFeature.State(
                homeID: state.homeID,
                members: Array(state.settings.members)
            ))
        }

        let tab = tab == .messages ? Self.owner(of: target) : tab
        state.selectedTab = tab
        push(screen, onto: tab, isSpecific: target.isSpecific, &state)
        return .none
    }

    /// An event or an occurrence, for a house that has Plus.
    private func openEvent(
        _ target: RouteStack.Target,
        _ state: inout State,
        from tab: Tab
    ) -> Effect<Action> {
        let screen: Route.State
        switch target {
        case let .event(eventID, day):
            screen = .eventDetail(EventPageFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                day: day,
                openingEventID: eventID
            ))
        // The event itself, as a page on this stack: Back is the screen that
        // asked, not a month of a calendar nobody opened.
        case let .occurrence(occurrence):
            screen = .eventDetail(EventPageFeature.State(
                homeID: state.homeID,
                currentUserID: state.user?.id,
                occurrence: occurrence
            ))
        default:
            return .none
        }
        let tab = tab == .messages ? Self.owner(of: target) : tab
        state.selectedTab = tab
        push(screen, onto: tab, isSpecific: true, &state)
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
        case .calendarSettings: .plans
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

    /// Opens what a tapped notification was about: the one thing when it names
    /// one, else the screen that owns its category, as the bell does.
    private func routePush(_ state: inout State, _ tap: PushTap) -> Effect<Action> {
        let from = state.selectedTab
        switch tap.link {
        case let .event(eventID, startMs?):
            let day = CalendarDay(Date(timeIntervalSince1970: Double(startMs) / 1000))
            return open(.event(eventID, day), from: from, &state)
        // An event with no occurrence named cannot be found in a day's window,
        // so it opens the calendar rather than a page that says "gone".
        case .event, .none:
            return route(&state, to: tap.category)
        case let .issue(issueID):
            return open(.issue(issueID), from: from, &state)
        case let .conversation(id):
            state.selectedTab = .messages
            return .send(.messages(.openRequested(id)))
        case let .recipe(id):
            let homeID = state.homeID
            // The first non-empty list (a list that has not filled yet is
            // not an answer), for at most three seconds.
            return .run { send in
                let found: Recipe? = await withTaskGroup(of: Recipe?.self) { group in
                    group.addTask {
                        do {
                            for try await recipes in recipesClient.byHome(homeID) where !recipes.isEmpty {
                                return recipes.first { $0.id == id }
                            }
                        } catch {}
                        return nil
                    }
                    group.addTask {
                        try? await clock.sleep(for: .seconds(3))
                        return nil
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                await send(.pushRecipeFound(found))
            }
            .cancellable(id: PushTapCancel.routing, cancelInFlight: true)
        }
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

        // Nestie lives on Today, as the card. The tab, back to its root: the
        // vote or the ceremony it announces is the card's to show.
        case .companion:
            state.selectedTab = .today
            state[stack: .today].path.removeAll()
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
        let dock = now.dockItem
        if homeTab.dock != dock { homeTab.dock = dock }
        if companion.now != now.now {
            companion.now = now.now
            if CompanionFlag.isEnabled { companion.refresh() }
        }
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
        if CompanionFlag.isEnabled { companion.userID = userID }
        settings.home = home
        inbox.currentUserID = user?.id
        moderation.userID = userID
        mirror.userID = userID
        share.userID = userID
        // The full-screen avatar viewer reads who this is from the directory
        // (it has no store), so an optimistic launch, which learns the user a
        // moment after the tabs, has to tell it too or it offers to report
        // the person's own face.
        let homeID = self.homeID
        Task { @MainActor in
            ModerationDirectory.shared.setSession(userID: userID, homeID: homeID)
        }
    }
}

extension RouteStack.Target {
    /// Whether this names one particular thing rather than a screen about a
    /// whole subject.
    var isSpecific: Bool {
        switch self {
        case .event, .occurrence, .issue, .recipe: true
        case .module, .taskArchive, .contributions, .movieNight, .stats, .messages, .decideDinner, .calendarSettings: false
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
