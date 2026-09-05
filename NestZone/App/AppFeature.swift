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
        /// A stored session exists but could not be exchanged. The user is not
        /// signed out — the network is just unavailable.
        public var restoreFailedOffline = false

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
            if status == .unauthenticated {
                return restoreFailedOffline ? .offline : .signedOut
            }
            // Stay on the launch screen until the home list has actually
            // arrived. Otherwise every launch flashes the "Let's get started"
            // picker for as long as the round trip takes, because an empty list
            // and "no home yet" are indistinguishable.
            if homeGate.isLoading { return .launching }
            return selectedHome == nil ? .choosingHome : .main
        }

        public enum Screen: Equatable {
            case launching, signedOut, offline, choosingHome, main
        }
    }

    public enum Action {
        case task
        case authStatusChanged(AuthStatus)
        case currentUserChanged(User?)
        case sessionRestoreFinished(RestoreOutcome)
        case languageChanged(AppLanguage)
        case deviceTokenReceived(String)
        case deviceRegistrationFailed
        case retryRestoreTapped
        case auth(AuthFeature.Action)
        case homeGate(HomeManagementFeature.Action)
        case main(MainFeature.Action)
    }

    private enum CancelID { case authState, currentUser, deviceToken }

    @Dependency(\.auth) var authClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.push) var push
    @Dependency(\.devices) var devices

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
                        //
                        // Retried, because Convex Auth rotates the token on
                        // every exchange: a restore that fails mid-flight can
                        // leave a perfectly good session stranded, and giving up
                        // on the first try signs the user out for what is often
                        // a two-second network blip.
                        var outcome = await authClient.restoreSession()
                        var attempt = 1
                        while outcome == .transientFailure, attempt <= 3 {
                            try? await clock.sleep(for: .seconds(attempt))
                            outcome = await authClient.restoreSession()
                            attempt += 1
                        }
                        await send(.sessionRestoreFinished(outcome))
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
                        .send(.homeGate(.task)),

                        // Only ask iOS for a token if the user has already
                        // agreed to notifications. Registering does not prompt,
                        // but there is no point holding a token we cannot use.
                        listenForDeviceToken(onlyIfAlreadyAuthorized: true)
                    )

                case .unauthenticated:
                    state.currentUser = nil
                    state.main = nil
                    state.homeGate = HomeManagementFeature.State()
                    return .merge(
                        .cancel(id: CancelID.currentUser),
                        .cancel(id: CancelID.deviceToken)
                    )

                default:
                    return .none
                }

            case let .currentUserChanged(user):
                state.currentUser = user
                state.main?.user = user
                state.main?.propagateSession()
                return .none

            case let .sessionRestoreFinished(outcome):
                state.isRestoringSession = false
                // Distinguish "signed out" from "could not reach the server".
                // Only the first should show the sign-in screen.
                state.restoreFailedOffline = outcome == .transientFailure
                return .none

            case let .languageChanged(language):
                L10n.apply(language)
                return .none

            case let .deviceTokenReceived(token):
                state.main?.settings.pushToken = token
                return .run { send in
                    try await devices.register(token, APNSEnvironment.current)
                } catch: { _, send in
                    // A device that cannot register simply gets no pushes.
                    await send(.deviceRegistrationFailed)
                }

            case .deviceRegistrationFailed:
                return .none

            case .retryRestoreTapped:
                state.isRestoringSession = true
                state.restoreFailedOffline = false
                return .run { send in
                    await send(.sessionRestoreFinished(authClient.restoreSession()))
                }

            // Keep the tab container in step with the open home. Building it
            // here rather than in the view means tab state survives a redraw
            // and dies with the home it belonged to.
            case .homeGate:
                return syncMain(&state)

            // Switching from the Settings sheet. The old path cleared the
            // selection and let the full-screen gate take over, which the gate
            // undoes the moment its subscription yields a single home — so a
            // user with one home saw the picker flash and come straight back.
            case let .main(.settings(.delegate(.homeSwitched(id)))):
                state.homeGate.$selectedHomeIDRaw.homeID = id
                return syncMain(&state)

            case let .main(.settings(.delegate(.languageChanged(language)))):
                return .send(.languageChanged(language))

            // Permission was just granted — in Settings, or by the prompt the
            // Home tab puts in front of a newcomer. Start listening for the
            // token now rather than waiting for the next launch.
            case .main(.settings(.delegate(.notificationsEnabled))),
                 .main(.home(.delegate(.notificationsEnabled))):
                return listenForDeviceToken()

            case .auth, .main:
                return .none
            }
        }
        .ifLet(\.main, action: \.main) { MainFeature() }
    }

    /// Asks iOS for an APNs token and forwards every token it hands back.
    ///
    /// Long-lived: iOS can reissue a token at any point in a session, and the
    /// backend has to hear about the new one or the device goes quiet.
    private func listenForDeviceToken(
        onlyIfAlreadyAuthorized: Bool = false
    ) -> Effect<Action> {
        .run { send in
            if onlyIfAlreadyAuthorized {
                guard await push.authorizationStatus() != .notDetermined else { return }
            }
            await push.registerForRemoteNotifications()
            for await token in push.deviceTokens() {
                await send(.deviceTokenReceived(token))
            }
        }
        .cancellable(id: CancelID.deviceToken, cancelInFlight: true)
    }

    /// The device token, held so a later sign-out can unregister it.
    /// Creates, updates or tears down the tab container to match the open home.
    private func syncMain(_ state: inout State) -> Effect<Action> {
        // Read before mutating: `selectedHome` reads `state` while the
        // assignments below need exclusive access to it.
        let selected = state.selectedHome
        let user = state.currentUser
        let homes = state.homeGate.homes
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
        // Settings offers the whole list — switch, join, leave — off this one
        // subscription rather than opening a second one of its own.
        state.main?.settings.applyHomes(homes)
        return .none
    }
}
