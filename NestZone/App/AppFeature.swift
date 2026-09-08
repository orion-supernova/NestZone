import ComposableArchitecture
import Foundation
import UIKit

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
        /// This device's standing with APNs and with the server, held here
        /// because this is the only reducer that lives for the whole session.
        /// iOS delivers a token once per launch, long before there is a
        /// Settings screen to put it in, so the arrival of a token and the
        /// display of one cannot be the same event.
        public var pushRegistration: PushRegistration = .none

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
            guard selectedHome != nil else { return .choosingHome }
            // The tab container is built by `syncMain`, in response to a
            // `homeGate` action. Seeded from the cache the selection is already
            // valid before any such action has run, so for a beat on launch
            // there is a home to open and nothing yet to open it with — and
            // `.main` with no store renders a blank screen, which is worse than
            // the launch screen it replaced.
            return main == nil ? .launching : .main
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
        case deviceRegistered(String)
        case deviceRegistrationFailed(String)
        case appEnteredForeground
        case retryRestoreTapped
        case auth(AuthFeature.Action)
        case homeGate(HomeManagementFeature.Action)
        case main(MainFeature.Action)
    }

    private enum CancelID {
        case authState, currentUser, deviceToken, deviceRegistration, foreground
    }

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
                    },

                    // Lives as long as the app does, deliberately unscoped to
                    // auth: it has to be listening before the first sign-in and
                    // still be there after the last one.
                    .run { send in
                        let foregrounds = NotificationCenter.default.notifications(
                            named: UIApplication.willEnterForegroundNotification
                        )
                        for await _ in foregrounds {
                            await send(.appEnteredForeground)
                        }
                    }
                    .cancellable(id: CancelID.foreground)
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
                    // The token belongs to the device and outlives the session,
                    // but this standing does not: it was registered against the
                    // user who just left. The broker replays the token to the
                    // listener that the next sign-in starts, which registers it
                    // afresh against whoever that is.
                    state.pushRegistration = .none
                    // Drop the cached home list before rebuilding the gate, or
                    // the fresh state seeds itself straight back out of it.
                    //
                    // Only for a session that had actually started:
                    // `.unauthenticated` is also the auth stream's opening value
                    // on every launch, before the cached session is restored,
                    // and clearing there would throw the cache away on each
                    // launch — which is the one thing it exists to prevent.
                    //
                    // Cleared at all because it is one household's data: a
                    // session that has ended must not leave its home names on
                    // the device for whoever signs in next.
                    if wasAuthenticated {
                        state.homeGate.$cachedHomes.withLock { $0 = [] }
                    }
                    state.homeGate = HomeManagementFeature.State()
                    return .merge(
                        .cancel(id: CancelID.currentUser),
                        .cancel(id: CancelID.deviceToken),
                        // Including a registration still backing off. It would
                        // authorise as nobody, and the token belongs to whoever
                        // signs in next.
                        .cancel(id: CancelID.deviceRegistration)
                    )

                default:
                    return .none
                }

            case let .currentUserChanged(user):
                // `users:me` is a live query, and Convex re-publishes every
                // live query in the app whenever the query set changes — so
                // this fires several times over on any screen that swaps a
                // subscription, with the same user each time. Propagating it
                // walks the tab container and every open chat, and writes into
                // state SwiftUI is observing, so an unchanged user is work the
                // whole app pays for and nobody sees.
                guard user != state.currentUser || state.main?.user != user else {
                    return .none
                }
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
                // Already confirmed against the server, and iOS handed back the
                // same token — which is what the foreground retry and every new
                // stream subscriber replay. Registering again would be a write
                // per app resume for nothing.
                guard state.pushRegistration != .registered(token: token) else {
                    return .none
                }
                state.pushRegistration = .pending(token: token)
                return .merge(
                    syncMain(&state),
                    .run { send in
                        // Retried, because giving up here costs the whole
                        // session's notifications and nothing tries again until
                        // the next launch. It is one mutation fired once, into
                        // whatever the network happens to be doing a second
                        // after sign-in — which on a cold backend is the moment
                        // every subscription in the app is contending for it.
                        //
                        // Safe to repeat: `push:registerDevice` upserts on the
                        // token, so a second attempt that follows a first one
                        // that actually landed patches the same row rather than
                        // adding another. Not something to do with mutations in
                        // general — a retried expense is a second expense — but
                        // this one is idempotent by construction.
                        var attempt = 1
                        while true {
                            do {
                                try await devices.register(token, APNSEnvironment.current)
                                return await send(.deviceRegistered(token))
                            } catch is CancellationError {
                                return
                            } catch {
                                guard attempt <= 4 else {
                                    return await send(.deviceRegistrationFailed(token))
                                }
                                try? await clock.sleep(for: .seconds(attempt))
                                attempt += 1
                            }
                        }
                    }
                    .cancellable(id: CancelID.deviceRegistration, cancelInFlight: true)
                )

            // Both outcomes name the token they are about: a newer one can have
            // arrived while the retries were sleeping, and the answer to an
            // older attempt must not overwrite where the newer one stands.
            case let .deviceRegistered(token):
                guard state.pushRegistration.token == token else { return .none }
                state.pushRegistration = .registered(token: token)
                return syncMain(&state)

            case let .deviceRegistrationFailed(token):
                // Out of retries. Said out loud rather than logged: the device
                // gets no pushes, the Settings row now reports exactly that,
                // and returning to the foreground tries again.
                guard state.pushRegistration.token == token else { return .none }
                state.pushRegistration = .failed(token: token)
                return syncMain(&state)

            // Registration used to end here for the whole session — five
            // attempts over about ten seconds, and a network blip during
            // sign-in cost every notification until the app was force-quit.
            // Coming back to the foreground is the cheapest honest retry: it
            // costs nothing while things are working, because the listener only
            // restarts when this device is not actually registered.
            case .appEnteredForeground:
                guard state.status == .authenticated,
                      !state.pushRegistration.isRegistered
                else { return .none }
                return listenForDeviceToken(onlyIfAlreadyAuthorized: true)

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

    /// Creates, updates or tears down the tab container to match the open home.
    private func syncMain(_ state: inout State) -> Effect<Action> {
        // Read before mutating: `selectedHome` reads `state` while the
        // assignments below need exclusive access to it.
        let selected = state.selectedHome
        let user = state.currentUser
        let homes = state.homeGate.homes
        let pushRegistration = state.pushRegistration
        guard let home = selected else {
            if state.main != nil { state.main = nil }
            return .none
        }
        if state.main?.homeID != home.id {
            state.main = MainFeature.State(homeID: home.id, home: home, user: user)
        } else if state.main?.home != home || state.main?.user != user {
            // Only when something actually moved. `homes:listMine` re-publishes
            // on every query-set change, not only when a home does, and
            // propagating walks the tabs and every open chat.
            state.main?.home = home
            state.main?.user = user
            state.main?.propagateSession()
        }
        // Settings offers the whole list — switch, join, leave — off this one
        // subscription rather than opening a second one of its own.
        if state.main?.settings.homes != homes {
            state.main?.settings.applyHomes(homes)
        }
        // The token almost always arrives before this container exists — it is
        // asked for at sign-in, while the home list is still in flight — and a
        // home switch builds a fresh one that has never seen it. Every change
        // to the standing comes back through here, so this one line is the only
        // thing keeping the Settings screen and sign-out in step with the truth.
        if state.main?.settings.pushRegistration != pushRegistration {
            state.main?.settings.pushRegistration = pushRegistration
        }
        return .none
    }
}
