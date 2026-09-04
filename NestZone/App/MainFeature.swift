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

        public init(homeID: HomeID, home: Home? = nil, user: User? = nil) {
            self.homeID = homeID
            self.home = home
            self.user = user
            self.homeTab = HomeFeature.State(homeID: homeID, user: user)
            self.hub = HubFeature.State(homeID: homeID)
            self.notes = NotesFeature.State(homeID: homeID, currentUserID: user?.id)
            self.messages = MessagesFeature.State(homeID: homeID, currentUserID: user?.id)
            self.settings = SettingsFeature.State(homeID: homeID, home: home, user: user)
        }

        /// How many people have to say yes for a movie-night match.
        var memberCount: Int { max(home?.members.count ?? 1, 1) }
    }

    @Reducer
    public enum HomePath {
        case tasks(TasksFeature)
        case movieNight(MovieNightFeature)
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
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.homeTab, action: \.home) { HomeFeature() }
        Scope(state: \.hub, action: \.hub) { HubFeature() }
        Scope(state: \.notes, action: \.notes) { NotesFeature() }
        Scope(state: \.messages, action: \.messages) { MessagesFeature() }
        Scope(state: \.settings, action: \.settings) { SettingsFeature() }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            // The Home tab is a summary; its tiles are shortcuts into the tab or
            // screen that actually owns the data.
            case .home(.delegate(.openShoppingList)):
                state.selectedTab = .hub
                state.hub.path.append(.shopping(ShoppingFeature.State(homeID: state.homeID)))
                return .none

            case .home(.delegate(.openNotes)):
                state.selectedTab = .notes
                return .none

            case .home(.delegate(.openTasks)):
                state.homePath.append(.tasks(TasksFeature.State(homeID: state.homeID)))
                return .none

            case .home(.delegate(.openMovieNight)):
                state.homePath.append(.movieNight(MovieNightFeature.State(
                    homeID: state.homeID,
                    memberCount: state.memberCount,
                    currentUserID: state.user?.id
                )))
                return .none

            // `openMessages` is answered by nobody while the Messages tab is
            // hidden — selecting a tab the bar does not show would leave the
            // TabView on a blank selection. Restore the case alongside the tab.
            case .homePath, .home, .hub, .notes, .messages, .settings:
                return .none
            }
        }
        .forEach(\.homePath, action: \.homePath)
    }
}

extension MainFeature.State {
    /// Keeps the per-tab copies of the session in step.
    public mutating func propagateSession() {
        homeTab.user = user
        notes.currentUserID = user?.id
        messages.currentUserID = user?.id
        settings.user = user
        settings.home = home
    }
}

// Navigation state is `Equatable` so parent states compare cleanly;
// declared here rather than via the deprecated `@Reducer(state:)` argument.
extension MainFeature.HomePath.State: Equatable {}
