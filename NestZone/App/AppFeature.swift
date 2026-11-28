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
        /// The tabs are up from the cached home while the stored session is
        /// still being restored in the background. Set only at launch, and only
        /// when there is both a stored session and a home to draw; ends when
        /// the restore answers. `ConvexConnection`'s gate is what keeps the
        /// reads and writes the tabs start in the meantime from going out
        /// without a session.
        public var isProvisional = false
        /// Houses the last live list lacked that this phone still holds things
        /// for. A house is let go only when two lists in a row lack it.
        var missingHomes: Set<HomeID> = []
        /// The launch has started its one restore. `.task` runs again when the
        /// language changes (the root view is re-identified), and a second
        /// restore beside the first is two exchanges of a token that rotates.
        public var restoreStarted = false
        /// The user RevenueCat was tied to this launch, so `pro:refresh` runs
        /// once per launch and sign-in, not once per profile edit. Set only
        /// once `logIn` has succeeded: until then it is tried again.
        public var proCheckedFor: UserID?
        /// This device's standing with APNs and with the server, held here
        /// because this is the only reducer that lives for the whole session.
        /// iOS delivers a token once per launch, long before there is a
        /// Settings screen to put it in, so the arrival of a token and the
        /// display of one cannot be the same event.
        public var pushRegistration: PushRegistration = .none
        /// A tapped notification waiting for the tabs. A tap that launched the
        /// app arrives before the session is restored; it is delivered once
        /// `main` exists, and on to the house it names.
        var pendingTap: PushTap?

        public var auth = AuthFeature.State()
        public var homeGate = HomeManagementFeature.State()
        public var main: MainFeature.State?
        /// The tour of a person's first launch with no home, shown instead of
        /// the bare create-or-join screen. Nil for everybody else, and for a
        /// replay (that one is `MainFeature`'s, over Settings).
        public var onboarding: OnboardingFeature.State?
        /// The person made or joined a home from the tour and the tabs have
        /// not been told yet: the rest of the first run (Plus, the first
        /// shopping item) starts when they exist.
        var firstRunHandoff = false
        public var nameAsk = NameAskFeature.State()
        /// "Later" on the name question, for this launch only: it asks again
        /// next launch until there is a name.
        var nameAskDeferred = false

        /// The tour has been through once on this device (set when a home is
        /// made or joined from it, or silently for somebody who already has
        /// one), so it never shows twice.
        @Shared(.hasCompletedOnboarding) public var hasCompletedOnboarding: Bool
        @Shared(.theme) public var theme: AppTheme
        @Shared(.language) public var language: AppLanguage
        /// Reset when a session ends: it is one house's standing.
        @Shared(.pro) public var pro: ProStatus
        @Shared(.blockedPeople) public var blockedPeople: [BlockedPerson]

        public init() {}

        /// The home currently open, if any.
        public var selectedHome: Home? {
            guard let id = homeGate.$selectedHomeIDRaw.homeID else { return nil }
            return homeGate.homes[id: id]
        }

        public var screen: Screen {
            // The home was read off the device's own cache, so it is on screen
            // before anything has asked the server. Waiting for `main` is the
            // same wait as below: it is built in the same reducer pass.
            if isProvisional { return main == nil ? .launching : .main }
            if isRestoringSession || status == .unknown { return .launching }
            if status == .unauthenticated {
                return restoreFailedOffline ? .offline : .signedOut
            }
            // Ahead of the house, so a new person is asked before they create
            // or join one and a nameless one before the tabs. Only once
            // `users:me` has answered (`currentUser` is set by nothing else)
            // and never on the provisional launch above, so a person who has a
            // name never sees it flash.
            if asksForName { return .askingName }
            // Then the tour, for a first launch with no home.
            if onboarding != nil { return .onboarding }
            // Stay on the launch screen until the home list has actually
            // arrived. Otherwise every launch flashes the "Let's get started"
            // picker for as long as the round trip takes, because an empty list
            // and "no home yet" are indistinguishable.
            if homeGate.isLoading { return .launching }
            // A home was just made from the tour and has not reached the list
            // yet: not the picker for a beat.
            if firstRunHandoff, selectedHome == nil { return .launching }
            guard selectedHome != nil else { return .choosingHome }
            // The tab container is built by `syncMain`, in response to a
            // `homeGate` action. Seeded from the cache the selection is already
            // valid before any such action has run, so for a beat on launch
            // there is a home to open and nothing yet to open it with — and
            // `.main` with no store renders a blank screen, which is worse than
            // the launch screen it replaced.
            return main == nil ? .launching : .main
        }

        /// The server's answer is that this account has no name, and the
        /// person has not put the question off. Screenshot runs never ask.
        public var asksForName: Bool {
            guard let currentUser, !currentUser.hasName, !nameAskDeferred else { return false }
            return !StoreDemo.isOn && StoreDemo.persona == nil
        }

        public enum Screen: Equatable {
            case launching, signedOut, offline, askingName, onboarding, choosingHome, main
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
        /// The person tapped a notification.
        case pushTapped(PushTap)
        case pushHomeDeadline
        /// Houses this phone holds calendar things for that the live list lacks.
        case homesMissing(Set<HomeID>)
        /// RevenueCat now knows who this is.
        case purchasesLoggedIn(UserID)
        case retryRestoreTapped
        /// A sign-out confirmed during the restore has waited as long as it may.
        case provisionalSignOutExpired
        case auth(AuthFeature.Action)
        case homeGate(HomeManagementFeature.Action)
        case main(MainFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case nameAsk(NameAskFeature.Action)
        /// The write failed: the name comes off again and the question says why.
        case nameSaveFailed(String, AppError)
    }

    private enum CancelID {
        case authState, currentUser, deviceToken, deviceRegistration, foreground, restore, signOutWait, purchasesIdentity, pushTaps
    }

    @Dependency(\.auth) var authClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.push) var push
    @Dependency(\.devices) var devices
    @Dependency(\.purchases) var purchases
    @Dependency(\.pro) var proClient
    @Dependency(\.calendarMirror) var calendarMirror
    @Dependency(\.sharedCopy) var sharedCopy
    @Dependency(\.deviceCalendar) var deviceCalendar

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) { AuthFeature() }
        Scope(state: \.homeGate, action: \.homeGate) { HomeManagementFeature() }
        Scope(state: \.nameAsk, action: \.nameAsk) { NameAskFeature() }

        Reduce { state, action in
            switch action {
            case .task:
                L10n.apply(state.language)
                // Draw the tabs from the cached home now, and restore the
                // session behind them. Only on the first `.task` (a language
                // change re-runs it), and only with both a stored session and a
                // home to show: anything else is the launch screen until the
                // restore answers, as it always was. Asking closes the
                // connection's gate, which has to happen before the tabs exist.
                let firstRun = !state.restoreStarted
                state.restoreStarted = true
                // The SDK starts anonymous and is tied to the person when the
                // session answers (`currentUserChanged`). Configured in an
                // effect, off the main actor: it is not needed by the first
                // frame, and `logIn` waits for it by retrying.
                let configure: Effect<Action> = firstRun
                    ? .run { _ in purchases.configure(nil) }
                    : .none
                if firstRun, state.isRestoringSession, state.selectedHome != nil,
                   authClient.beginOptimisticLaunch() {
                    state.isProvisional = true
                    _ = syncMainState(&state)
                }
                return .merge(
                    configure,
                    // Taps, for the life of the app. Started once: the stream
                    // hands each tap to one listener, and a second would take
                    // some of them.
                    firstRun ? .run { send in
                        for await tap in push.taps() { await send(.pushTapped(tap)) }
                    }
                    .cancellable(id: CancelID.pushTaps) : .none,
                    .run { send in
                        for await status in authClient.authState() {
                            await send(.authStatusChanged(status))
                        }
                    }
                    .cancellable(id: CancelID.authState),

                    firstRun ? .run { [optimistic = state.isProvisional] send in
                        // Silent restore from the Keychain refresh token.
                        //
                        // Retried, because Convex Auth rotates the token on
                        // every exchange: a restore that fails mid-flight can
                        // leave a perfectly good session stranded, and giving up
                        // on the first try signs the user out for what is often
                        // a two-second network blip.
                        //
                        // One at a time, always: this loop is the only caller,
                        // and each attempt waits for the one before it (and the
                        // provider's own semaphore backs that up). An optimistic
                        // launch does not give up after three. Its tabs are
                        // already on screen, so a phone without a network keeps
                        // what it has and tries again every few seconds, rather
                        // than being sent to a retry screen over a household it
                        // can already show.
                        var outcome = await authClient.restoreSession()
                        var attempt = 1
                        while outcome == .transientFailure, optimistic || attempt <= 3 {
                            do {
                                try await clock.sleep(for: .seconds(min(attempt, 10)))
                            } catch {
                                // Cancelled without an answer: nothing may be
                                // left waiting on a session that is not coming.
                                authClient.endOptimisticLaunch()
                                return
                            }
                            outcome = await authClient.restoreSession()
                            attempt += 1
                        }
                        await send(.sessionRestoreFinished(outcome))
                    }
                    .cancellable(id: CancelID.restore) : .none,

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

                // The SDK says `.unauthenticated` when it opens and again when
                // a restore fails, and neither is the end of a session that is
                // still being restored: the restore's own answer
                // (`sessionRestoreFinished`) is what decides, and acting on
                // this would tear down the tabs the launch just drew.
                if status == .unauthenticated, state.isProvisional { return .none }

                let wasAuthenticated = state.status == .authenticated
                state.status = status
                // The handover from the cached tabs to the real session. Both
                // flags go in the same pass: `screen` reads them together, and
                // clearing only `isProvisional` would show the launch screen
                // for a pass, which rebuilds the tab container.
                let wasProvisional = state.isProvisional
                if status == .authenticated, wasProvisional {
                    state.isProvisional = false
                    state.isRestoringSession = false
                    state.main?.settings.isAwaitingSession = false
                }

                switch status {
                case .authenticated where !wasAuthenticated:
                    let parkedSignOut = wasProvisional && state.main?.settings.isSigningOut == true
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
                        listenForDeviceToken(onlyIfAlreadyAuthorized: true),

                        // A sign-out was parked on this restore (see
                        // `provisionalSignOutExpired`) and goes now, with the
                        // push token if one has arrived.
                        parkedSignOut ? .send(.main(.settings(.sessionReady))) : .none
                    )

                case .unauthenticated:
                    // Only for a session that had actually started:
                    // `.unauthenticated` is also the auth stream's opening value
                    // on every launch, before the cached session is restored,
                    // and clearing there would throw the cache away on each
                    // launch — which is the one thing it exists to prevent.
                    return endSession(&state, clearCache: wasAuthenticated)

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
                // Purchases belong to the person, and the server is asked to
                // look at their subscription once per launch and sign-in.
                guard let user, state.proCheckedFor != user.id else { return .none }
                // Not marked as done here: a `logIn` that fails is tried again,
                // and a purchase made on the anonymous id is one nobody sees.
                return .run { send in
                    var wait = 2
                    while true {
                        do {
                            try await purchases.logIn(user.id.rawValue)
                            break
                        } catch is CancellationError {
                            return
                        } catch {
                            guard (try? await clock.sleep(for: .seconds(wait))) != nil else { return }
                            wait = min(wait * 2, 60)
                        }
                    }
                    await send(.purchasesLoggedIn(user.id))
                    _ = try? await proClient.refresh()
                }
                .cancellable(id: CancelID.purchasesIdentity, cancelInFlight: true)

            case let .purchasesLoggedIn(id):
                // Only if this is still who is signed in.
                if state.currentUser?.id == id { state.proCheckedFor = id }
                return .none

            case let .sessionRestoreFinished(outcome):
                state.isRestoringSession = false
                if state.isProvisional {
                    switch outcome {
                    case .restored:
                        // `.authenticated` is what ends the provisional state,
                        // and starts the reads; it is on its way.
                        return .none
                    case .noSession:
                        // The server refused the stored session. Exactly the
                        // sign-in screen a launch without the cache would have
                        // got, and the household it was drawing goes with it:
                        // it belonged to a session that no longer exists.
                        state.isProvisional = false
                        state.status = .unauthenticated
                        return endSession(&state, clearCache: true)
                    case .transientFailure:
                        state.isProvisional = false
                        state.status = .unauthenticated
                        state.restoreFailedOffline = true
                        return .merge(
                            endSession(&state, clearCache: false),
                            .run { _ in authClient.endOptimisticLaunch() }
                        )
                    }
                }
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
                // A Plus payment that was not credited yet is looked at again.
                let recheck: Effect<Action> = state.main == nil
                    ? .none
                    : .merge(
                        .send(.main(.proStatus(.becameActive))),
                        // The copies' window slides forward and catches up.
                        .send(.main(.mirror(.becameActive))),
                        .send(.main(.share(.becameActive))),
                        .send(.main(.sharedCopy(.becameActive)))
                    )
                guard state.status == .authenticated,
                      !state.pushRegistration.isRegistered
                else { return recheck }
                return .merge(recheck, listenForDeviceToken(onlyIfAlreadyAuthorized: true))

            case let .pushTapped(tap):
                state.pendingTap = tap
                return deliverPendingTap(&state, settle: false)

            // The house a tap names never turned up in the list: route it by
            // category in the open one.
            case .pushHomeDeadline:
                state.pendingTap?.home = nil
                return deliverPendingTap(&state, settle: false)

            case .retryRestoreTapped:
                state.isRestoringSession = true
                state.restoreFailedOffline = false
                return .run { send in
                    await send(.sessionRestoreFinished(authClient.restoreSession()))
                }

            // Keep the tab container in step with the open home. Building it
            // here rather than in the view means tab state survives a redraw
            // and dies with the home it belonged to.
            case let .homeGate(.homesUpdated(live)):
                updateOnboarding(&state, live: live)
                // A house that is no longer in the list was left, or the person
                // was removed from it: what this phone holds for it (copies in
                // the calendars, pins, what was shared) goes with it.
                // Not while the list may be the cache's or a launch's guess, and
                // never because the list is empty: that is the least trustworthy
                // answer there is.
                guard !state.isProvisional, !live.isEmpty else { return syncMain(&state) }
                return .merge(syncMain(&state), findMissingHomes(keeping: Set(live.map(\.id))))

            case let .homesMissing(missing):
                let confirmed = missing.intersection(state.missingHomes)
                state.missingHomes = missing
                guard !confirmed.isEmpty else { return .none }
                state.missingHomes.subtract(confirmed)
                return forgetHomes(confirmed)

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

            // Signing out while the launch is still restoring. Settings parks
            // the sign-out on a spinner, and it goes when the restore ends:
            // success sends it on (above), a refusal ends the session and with
            // it the tabs. If the restore is still going after ten seconds (a
            // phone with no signal can retry for as long as it likes), the
            // person is not held any longer.
            case .main(.settings(.alert(.presented(.confirmSignOut)))),
                 .main(.settings(.signOutConfirmed)):
                guard state.isProvisional else { return .none }
                return .run { send in
                    try await clock.sleep(for: .seconds(10))
                    await send(.provisionalSignOutExpired)
                }
                .cancellable(id: CancelID.signOutWait, cancelInFlight: true)

            case .provisionalSignOutExpired:
                guard state.isProvisional, state.main?.settings.isSigningOut == true
                else { return .none }
                // Signed in, as far as anything else is concerned, so that the
                // sign-out below is the end of a session and clears the cache
                // like any other. The restore stops; it was not going to
                // answer. Rejecting the gate first lets the sign-out's own
                // unregister fail at once instead of waiting out the write
                // limit for a session that is not coming.
                state.isProvisional = false
                state.isRestoringSession = false
                state.status = .authenticated
                state.main?.settings.isAwaitingSession = false
                return .merge(
                    .cancel(id: CancelID.restore),
                    .run { send in
                        authClient.endOptimisticLaunch()
                        await send(.main(.settings(.sessionReady)))
                    }
                )

            // The sign-out ran to its end. Ending the session here, and not
            // waiting for the SDK to say so, is what makes sign-out
            // deterministic: the SDK's `.unauthenticated` is ignored while a
            // launch is still provisional, and may not be re-sent at all.
            case .main(.settings(.delegate(.signedOut))):
                state.isProvisional = false
                state.isRestoringSession = false
                state.status = .unauthenticated
                return .merge(
                    .cancel(id: CancelID.restore),
                    .cancel(id: CancelID.signOutWait),
                    endSession(&state, clearCache: true)
                )

            // Optimistic: the name goes onto the signed-in user at once, which
            // is what moves the screen on, and the live `users:me` only
            // confirms it. A failed write changed nothing on the server, so no
            // push is coming to correct it: the failure takes the name back
            // itself.
            case let .nameAsk(.delegate(.save(name))):
                guard state.currentUser != nil else { return .none }
                state.currentUser?.name = name
                let user = state.currentUser
                state.main?.user = user
                state.main?.propagateSession()
                return .run { _ in
                    try await authClient.updateDisplayName(name)
                } catch: { error, send in
                    await send(.nameSaveFailed(name, AppError(error)))
                }

            case let .nameSaveFailed(name, error):
                if state.currentUser?.name == name {
                    state.currentUser?.name = nil
                    let user = state.currentUser
                    state.main?.user = user
                    state.main?.propagateSession()
                }
                state.nameAsk.inlineError = error.errorDescription
                return .none

            case .nameAsk(.delegate(.later)):
                state.nameAskDeferred = true
                return .none

            // A home was made or joined from the tour. Nothing is navigated
            // from here: the tabs are built from the live home list as ever,
            // and told once they exist (`syncMain`).
            case .onboarding(.delegate(.homeReady)):
                state.$hasCompletedOnboarding.withLock { $0 = true }
                state.onboarding = nil
                state.firstRunHandoff = true
                return syncMain(&state)

            case .onboarding(.delegate(.finished)):
                state.onboarding = nil
                return .none

            case .auth, .main, .nameAsk, .onboarding:
                return .none
            }
        }
        .ifLet(\.main, action: \.main) { MainFeature() }
        .ifLet(\.onboarding, action: \.onboarding) { OnboardingFeature() }
    }

    /// Everything a session leaving takes with it: the tabs, the signed-in user,
    /// the household's cache and faces, and the effects that served them.
    private func endSession(_ state: inout State, clearCache: Bool) -> Effect<Action> {
        state.currentUser = nil
        state.nameAsk = NameAskFeature.State()
        state.nameAskDeferred = false
        state.main = nil
        state.onboarding = nil
        state.firstRunHandoff = false
        state.proCheckedFor = nil
        state.pendingTap = nil
        state.missingHomes = []
        state.$pro.withLock { $0 = .unknown }
        // Who a person blocked is theirs, not the phone's.
        state.$blockedPeople.withLock { $0 = [] }
        // The token belongs to the device and outlives the session,
        // but this standing does not: it was registered against the
        // user who just left. The broker replays the token to the
        // listener that the next sign-in starts, which registers it
        // afresh against whoever that is.
        state.pushRegistration = .none
        // Drop the cached home list before rebuilding the gate, or
        // the fresh state seeds itself straight back out of it.
        //
        // Cleared at all because it is one household's data: a
        // session that has ended must not leave its home names on
        // the device for whoever signs in next.
        if clearCache {
            state.homeGate.$cachedHomes.withLock { $0 = [] }
        }
        state.homeGate = HomeManagementFeature.State()
        // The calendar settings are per device but the person who chose them is
        // gone: a second account on this phone starts from nothing, and the
        // copies the first one's houses put in the calendars come out. Only
        // when the session truly ended, on the same terms as the cache above.
        var calendarCleanup: Effect<Action> = .none
        if clearCache {
            @Shared(.calendarCopyMode) var copyMode
            @Shared(.calendarCopyTargetsRaw) var copyTargets
            @Shared(.calendarComposerTargetsRaw) var composerTargets
            @Shared(.calendarCopyReminders) var copyReminders
            @Shared(.calendarLastSynced) var lastSynced
            @Shared(.calendarPeopleRaw) var people
            @Shared(.calendarShareChoicesRaw) var shareChoices
            @Shared(.calendarCopyChoicesRaw) var copyChoices
            $copyChoices.withLock { $0 = "" }
            $copyMode.withLock { $0 = .off }
            $copyTargets.withLock { $0 = "" }
            $composerTargets.withLock { $0 = "" }
            $copyReminders.withLock { $0 = false }
            $lastSynced.withLock { $0 = 0 }
            $people.withLock { $0 = "" }
            $shareChoices.withLock { $0 = "" }
            calendarCleanup = .run { [calendarMirror, sharedCopy, deviceCalendar] _ in
                _ = await calendarMirror.removeAll(deviceCalendar, nil, true)
                _ = await sharedCopy.removeAll(deviceCalendar, nil)
            }
        }
        return .merge(
            calendarCleanup,
            .cancel(id: CancelID.currentUser),
            .cancel(id: CancelID.deviceToken),
            // Including a registration still backing off. It would
            // authorise as nobody, and the token belongs to whoever
            // signs in next.
            .cancel(id: CancelID.deviceRegistration),
            .cancel(id: CancelID.purchasesIdentity),
            // A tap waiting on a house, or on its way to the tabs, belonged to
            // the session that just ended.
            .cancel(id: PushTapCancel.delivery),
            .cancel(id: PushTapCancel.routing),
            .cancel(id: PushTapCancel.deadline),
            // On the same terms as the cached home list above: a
            // household's faces are a household's data, and the
            // directory outlives every screen that filled it. An
            // effect rather than a line in the reducer because it
            // is the main actor's state, not this one's.
            .run { _ in await AvatarDirectory.shared.clear() },
            // And what they reported: faces and photos hidden for them.
            .run { _ in await ModerationDirectory.shared.clear() },
            // Purchases are the person's, not the phone's.
            .run { _ in await purchases.logOut() }
        )
    }

    /// Takes what this phone keeps for houses the person is no longer in: the
    /// copies in their calendars, the events pinned from the composer, and the
    /// choice to share calendars with it (the server deletes what was shared
    /// when somebody leaves; the phone must simply stop sending).
    private func findMissingHomes(keeping live: Set<HomeID>) -> Effect<Action> {
        .run { [calendarMirror, sharedCopy] send in
            @Shared(.calendarShareChoicesRaw) var shareChoices
            @Shared(.calendarCopyChoicesRaw) var copyChoices
            var held = await calendarMirror.knownHomes()
            held.formUnion(await sharedCopy.knownHomes())
            for key in CalendarCopyChoices.decode(copyChoices).houses.keys { held.insert(HomeID(key)) }
            for key in CalendarShareChoices.decode(shareChoices).houses.keys { held.insert(HomeID(key)) }
            await send(.homesMissing(held.subtracting(live)))
        }
    }

    private func forgetHomes(_ homes: Set<HomeID>) -> Effect<Action> {
        .run { [calendarMirror, sharedCopy, deviceCalendar] _ in
            @Shared(.calendarShareChoicesRaw) var shareChoices
            @Shared(.calendarCopyChoicesRaw) var copyChoices
            $shareChoices.withLock { raw in
                var choices = CalendarShareChoices.decode(raw)
                for home in homes { choices.houses[home.rawValue] = nil }
                raw = choices.raw
            }
            $copyChoices.withLock { raw in
                var choices = CalendarCopyChoices.decode(raw)
                for home in homes { choices.houses[home.rawValue] = nil }
                raw = choices.raw
            }
            for home in homes {
                _ = await calendarMirror.removeAll(deviceCalendar, home, true)
                _ = await sharedCopy.removeAll(deviceCalendar, home)
            }
        }
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

    /// `syncMainState`, and then any tapped notification that was waiting for
    /// the tabs this just built.
    private func syncMain(_ state: inout State) -> Effect<Action> {
        syncMainState(&state)
        return .merge(deliverFirstRun(&state), deliverPendingTap(&state, settle: true))
    }

    /// Decides, from the live home list, whether this is a first run: no home
    /// and the tour never seen starts it; a home (an existing person, a new
    /// phone) marks it seen without ever showing it, and ends one that was
    /// waiting if the home came from somewhere else. A tour with a sheet open
    /// is left to finish; the sheet's own `finished` is what moves it on.
    private func updateOnboarding(_ state: inout State, live: [Home]) {
        // Screenshot runs never see it, as they never see the name question.
        guard !StoreDemo.isOn, StoreDemo.persona == nil else { return }
        if !live.isEmpty {
            guard state.onboarding?.destination == nil, !state.firstRunHandoff else { return }
            if !state.hasCompletedOnboarding { state.$hasCompletedOnboarding.withLock { $0 = true } }
            state.onboarding = nil
            return
        }
        guard !state.hasCompletedOnboarding, state.onboarding == nil, !state.firstRunHandoff,
              !state.isProvisional, state.status == .authenticated
        else { return }
        state.onboarding = OnboardingFeature.State(mode: .firstRun)
    }

    /// Tells the tabs that a first run just got its home, once they exist.
    private func deliverFirstRun(_ state: inout State) -> Effect<Action> {
        guard state.firstRunHandoff, state.onboarding == nil,
              let main = state.main, main.homeID == state.selectedHome?.id
        else { return .none }
        state.firstRunHandoff = false
        return .send(.main(.firstRunBegan))
    }

    /// Hands a waiting tap to the tabs, switching to the house it names first
    /// when the person belongs to it (an unknown house is ignored and the tap
    /// routes by category in the open one). `settle` waits out the tabs'
    /// first frames, which drop a sheet or push asked for mid-build.
    private func deliverPendingTap(_ state: inout State, settle: Bool) -> Effect<Action> {
        guard let tap = state.pendingTap, let main = state.main else { return .none }
        var settle = settle || state.isProvisional
        if let home = tap.home, home != main.homeID {
            if state.homeGate.homes[id: home] != nil {
                state.homeGate.$selectedHomeIDRaw.homeID = home
                syncMainState(&state)
                settle = true
            } else if state.isProvisional || state.homeGate.isLoading {
                // The list is the cache's, or has not answered: the house may
                // simply not be in it yet. Held (the answer comes back through
                // `syncMain`) for a few seconds, then routed where we are.
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.pushHomeDeadline)
                }
                .cancellable(id: PushTapCancel.deadline, cancelInFlight: true)
            }
            // Otherwise the list answered and the person is not in that house.
        }
        state.pendingTap = nil
        return .merge(
            .cancel(id: PushTapCancel.deadline),
            .run { [settle] send in
                if settle { try? await clock.sleep(for: .milliseconds(350)) }
                await send(.main(.pushTapped(tap)))
            }
            .cancellable(id: PushTapCancel.delivery, cancelInFlight: true)
        )
    }

    /// Creates, updates or tears down the tab container to match the open home.
    @discardableResult
    private func syncMainState(_ state: inout State) -> Effect<Action> {
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
        // A tab container built while the session is still being restored
        // tells Settings to hold a sign-out until it has answered.
        let provisional = state.isProvisional
        if state.main?.settings.isAwaitingSession != provisional {
            state.main?.settings.isAwaitingSession = provisional
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
