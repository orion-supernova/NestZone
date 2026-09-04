import ComposableArchitecture
import Foundation

/// The root. Owns the two gates every launch passes through — are you signed in,
/// and which home are you in — and the session data every tab reads.
///
/// The old root was a `Group` in `NestZoneApp` switching on
/// `authManager.currentUser == nil`, with home loading kicked off from
/// `TabBarScreen.task` and the result held in a singleton. Auth, homes and tabs
/// are one state machine here.
@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var status: AuthStatus = .unknown
        public var currentUser: User?
        /// True until the cached-session restore finishes, so the auth screen
        /// never flashes on a signed-in launch.
        public var isRestoringSession = true

        public var auth = AuthFeature.State()
        public var homeGate = HomeManagementFeature.State()
        public var main: MainFeature.State?

        @Shared(.theme) public var theme: AppTheme
        @Shared(.language) public var language: AppLanguage

        public init() {}

        /// The home currently open, if any.
        public var selectedHome: Home? {
            guard let id = homeGate.$selectedHomeIDRaw.homeID else { return nil }
            return homeGate.homes[id: id]
        }

        public var screen: Screen {
            if isRestoringSession || status == .unknown { return .launching }
            if status == .unauthenticated { return .signedOut }
            // Stay on the launch screen until the home list has actually
            // arrived. Otherwise every launch flashes the "Let's get started"
            // picker for as long as the round trip takes, because an empty list
            // and "no home yet" are indistinguishable.
            if homeGate.isLoading { return .launching }
            return selectedHome == nil ? .choosingHome : .main
        }

        public enum Screen: Equatable {
            case launching, signedOut, choosingHome, main
        }
    }

    public enum Action {
        case task
        case authStatusChanged(AuthStatus)
        case currentUserChanged(User?)
        case sessionRestoreFinished
        case languageChanged(AppLanguage)
        case auth(AuthFeature.Action)
        case homeGate(HomeManagementFeature.Action)
        case main(MainFeature.Action)
    }

    private enum CancelID { case authState, currentUser }

    @Dependency(\.auth) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) { AuthFeature() }
        Scope(state: \.homeGate, action: \.homeGate) { HomeManagementFeature() }

        Reduce { state, action in
            switch action {
            case .task:
                L10n.apply(state.language)
                return .merge(
                    .run { send in
                        for await status in authClient.authState() {
                            await send(.authStatusChanged(status))
                        }
                    }
                    .cancellable(id: CancelID.authState),

                    .run { send in
                        // Silent restore from the Keychain refresh token.
                        // Whatever the outcome, the launch gate opens.
                        _ = await authClient.restoreSession()
                        await send(.sessionRestoreFinished)
                    }
                )

            case let .authStatusChanged(status):
                // `.unknown` is transient — it fires during every sign-in
                // attempt. Acting on it would tear down the auth screen and wipe
                // whatever the user was in the middle of.
                guard status != .unknown else { return .none }

                let wasAuthenticated = state.status == .authenticated
                state.status = status

                switch status {
                case .authenticated where !wasAuthenticated:
                    return .merge(
                        .run { send in
                            for try await user in authClient.currentUser() {
                                await send(.currentUserChanged(user))
                            }
                        } catch: { _, send in
                            await send(.currentUserChanged(nil))
                        }
                        .cancellable(id: CancelID.currentUser, cancelInFlight: true),

                        // Start loading homes as soon as we are signed in, not
                        // when the picker happens to mount — the picker is what
                        // we are trying to avoid showing.
                        .send(.homeGate(.task))
                    )

                case .unauthenticated:
                    state.currentUser = nil
                    state.main = nil
                    state.homeGate = HomeManagementFeature.State()
                    return .cancel(id: CancelID.currentUser)

                default:
                    return .none
                }

            case let .currentUserChanged(user):
                state.currentUser = user
                state.main?.user = user
                state.main?.propagateSession()
                return .none

            case .sessionRestoreFinished:
                state.isRestoringSession = false
                return .none

            case let .languageChanged(language):
                L10n.apply(language)
                return .none

            // Keep the tab container in step with the open home. Building it
            // here rather than in the view means tab state survives a redraw
            // and dies with the home it belonged to.
            case .homeGate:
                return syncMain(&state)

            case .main(.settings(.delegate(.switchHomeRequested))):
                state.homeGate.$selectedHomeIDRaw.homeID = nil
                state.main = nil
                return .none

            case let .main(.settings(.delegate(.languageChanged(language)))):
                return .send(.languageChanged(language))

            case .auth, .main:
                return .none
            }
        }
        .ifLet(\.main, action: \.main) { MainFeature() }
    }

    /// Creates, updates or tears down the tab container to match the open home.
    private func syncMain(_ state: inout State) -> Effect<Action> {
        // Read before mutating: `selectedHome` reads `state` while the
        // assignments below need exclusive access to it.
        let selected = state.selectedHome
        let user = state.currentUser
        guard let home = selected else {
            state.main = nil
            return .none
        }
        if state.main?.homeID != home.id {
            state.main = MainFeature.State(homeID: home.id, home: home, user: user)
        } else {
            state.main?.home = home
            state.main?.user = user
            state.main?.propagateSession()
        }
        return .none
    }
}
