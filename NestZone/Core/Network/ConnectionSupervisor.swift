import Combine
import ConvexMobile
import Network
import UIKit
import os

/// Keeps the app's connection to Convex alive across everything a phone does
/// to it: backgrounding, sleep, a Wi-Fi to cellular handover, a lift.
///
/// The SDK's Rust client reconnects its websocket by itself, and that is not
/// enough. A socket that died while the app was suspended is half-open (the
/// phone sees no reset), so the client can wait on it for a long time; the JWT
/// it authenticated with has expired meanwhile; and the one call that could
/// repair the token (`AuthTokenProvider.fetchToken(forceRefresh:)`) goes over a
/// second socket that went stale in the same nap. The result was a bell that
/// drew its skeleton forever, healed only by killing the app.
///
/// So this owns the client and can replace it. A replacement is a new
/// `ConvexClientWithAuth` that has already exchanged the refresh token for a
/// fresh JWT; only when that worked is it swapped in, and every live
/// `subscribe` is told to re-attach to it (`observe`). A failed replacement
/// changes nothing, and is tried again later with backoff.
///
/// What starts one:
/// - the app returns after more than `awayLimit` in the background;
/// - the network path comes back, or changes interface;
/// - the websocket has been "connecting" for `connectingLimit`;
/// - a read has had no first answer for `ConvexConnection.stallLimit`.
///
/// What it never does: sign anybody out, run while the app is not active, run
/// without a signed-in session, or run more often than the backoff allows. At
/// rest it holds a path monitor and two notification observers, and no timers.
final class ConnectionSupervisor: @unchecked Sendable {
    typealias Client = ConvexClientWithAuth<ConvexAuthTokens>

    /// How long the app may be away before its socket is not trusted.
    private static let awayLimit: TimeInterval = 20
    /// How long the websocket may report "connecting" while the network is up.
    private static let connectingLimit: Duration = .seconds(15)
    private static let firstBackoff = 2
    private static let maxBackoff = 60

    private static func appIsActive() -> Bool {
        guard Thread.isMainThread else { return true }
        return MainActor.assumeIsolated { UIApplication.shared.applicationState != .background }
    }

    private static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Reconnect")

    /// The session's state, as the current client last reported it. Forwarded
    /// rather than read off the client, because the client is replaced and a
    /// subscriber must not have to notice.
    let authState = CurrentValueSubject<AuthState<ConvexAuthTokens>, Never>(.unauthenticated)

    private let provider: ConvexAppleAuthProvider
    private let deploymentURL: String
    private let onConnectionChange: @Sendable (Bool) -> Void

    private let lock = NSLock()
    private var current: Client
    private var epoch = 0
    private var observers: [UUID: @Sendable () -> Void] = [:]
    private var wiring: [AnyCancellable] = []

    private var canRebuild: @Sendable () -> Bool = { true }
    private var pending: Task<Void, Never>?
    private var isRebuilding = false
    private var settleWaiters: [CheckedContinuation<Void, Never>] = []
    private var backoffStep = 0
    private var lastRebuildEnded: ContinuousClock.Instant?
    /// Set when a read delivers, cleared by a rebuild: a stall that follows a
    /// delivery is a new problem, one that follows a rebuild is the same one.
    private var delivered = false

    private var isActive = ConnectionSupervisor.appIsActive()
    private var leftAt: Date?
    private var isConnected = false
    private var connectingTimer: Task<Void, Never>?

    /// Bumped whenever the session is anything but authenticated, so a
    /// replacement that started before a sign-out can tell it happened.
    private let signOutLock = NSLock()
    private var signOuts = 0

    private let monitor = NWPathMonitor()
    private var pathSatisfied = true
    private var pathSignature: String?

    init(
        provider: ConvexAppleAuthProvider,
        deploymentURL: String,
        onConnectionChange: @escaping @Sendable (Bool) -> Void
    ) {
        self.provider = provider
        self.deploymentURL = deploymentURL
        self.onConnectionChange = onConnectionChange
        current = Client(deploymentUrl: deploymentURL, authProvider: provider)
    }

    /// Starts watching. Separate from `init` so the closure can refer to the
    /// connection that owns this.
    func start(canRebuild: @escaping @Sendable () -> Bool) {
        lock.withLock {
            self.canRebuild = canRebuild
            wiring = wire(current, dropReplay: false)
        }

        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.didLeave()
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.willReturn()
        }

        monitor.pathUpdateHandler = { [weak self] path in self?.pathChanged(path) }
        monitor.start(queue: DispatchQueue(label: "com.walhallaa.NestZone.path", qos: .utility))
    }

    // MARK: - The client

    var client: Client { lock.withLock { current } }

    /// The current client, and a callback for the moment it is replaced, taken
    /// together so a replacement cannot slip between the two. The callback runs
    /// off the lock, once.
    func observe(onReplaced: @escaping @Sendable () -> Void) -> (client: Client, token: UUID) {
        lock.withLock {
            let token = UUID()
            observers[token] = onReplaced
            return (current, token)
        }
    }

    func stopObserving(_ token: UUID) {
        lock.withLock { _ = observers.removeValue(forKey: token) }
    }

    /// Something was read: the connection works.
    func noteDelivery() {
        lock.withLock { delivered = true }
    }

    /// A read has had no answer for too long. One of many that may say so at
    /// once; they coalesce into a single replacement.
    func noteStall(_ name: String) {
        let ready = lock.withLock { isActive && pathSatisfied }
        guard ready else { return }
        Self.log.notice("\(name, privacy: .public) has no answer; reconnecting")
        reconnect("stalled read", backedOff: true)
    }

    /// Returns once a replacement in progress has ended, so a write is not
    /// sent down a client that is about to be dropped.
    func settled() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let wait = lock.withLock { () -> Bool in
                guard isRebuilding else { return false }
                settleWaiters.append(continuation)
                return true
            }
            if !wait { continuation.resume() }
        }
    }

    // MARK: - What starts a replacement

    private func didLeave() {
        lock.withLock {
            isActive = false
            leftAt = Date()
            // Nothing is worth doing while suspended, and a timer left running
            // would fire into a socket the system is about to take.
            connectingTimer?.cancel()
            connectingTimer = nil
            // A rebuild that has begun is left to finish: it may have sent a
            // refresh-token exchange, and that must land. One still waiting its
            // turn is dropped.
            if !isRebuilding {
                pending?.cancel()
                pending = nil
            }
        }
    }

    private func willReturn() {
        let away = lock.withLock { () -> TimeInterval in
            isActive = true
            defer { leftAt = nil }
            return leftAt.map { Date().timeIntervalSince($0) } ?? 0
        }
        if away > Self.awayLimit {
            Self.log.notice("back after \(Int(away), privacy: .public)s; reconnecting")
            reconnect("foreground", backedOff: false)
        } else {
            // A short nap leaves the socket alone unless it is not up.
            armConnectingTimer()
        }
    }

    private func pathChanged(_ path: NWPath) {
        let satisfied = path.status == .satisfied
        let signature = [
            NWInterface.InterfaceType.wifi, .cellular, .wiredEthernet,
        ].filter { path.usesInterfaceType($0) }.map { "\($0)" }.joined(separator: "+")

        let (changed, active) = lock.withLock { () -> (Bool, Bool) in
            let first = pathSignature == nil
            let wasSatisfied = pathSatisfied
            let previous = pathSignature
            pathSatisfied = satisfied
            pathSignature = signature
            // The first answer is just the starting point.
            let changed = !first && satisfied && (!wasSatisfied || previous != signature)
            return (changed, isActive)
        }
        guard changed, active else { return }
        Self.log.notice("network is back or changed (\(signature, privacy: .public)); reconnecting")
        // A moment for the new route to settle: the path is announced before
        // DNS and the radio are ready to carry a TLS handshake.
        reconnect("network", backedOff: false, delay: .seconds(1))
    }

    /// Called with every websocket state the current client reports.
    private func socketStateChanged(connected: Bool) {
        lock.withLock { isConnected = connected }
        onConnectionChange(connected)
        if connected {
            lock.withLock {
                connectingTimer?.cancel()
                connectingTimer = nil
            }
        } else {
            armConnectingTimer()
        }
    }

    /// A socket that stays "connecting" on a network that is up is a stuck one.
    private func armConnectingTimer() {
        lock.withLock {
            guard connectingTimer == nil, isActive, !isConnected else { return }
            connectingTimer = Task { [weak self] in
                do { try await Task.sleep(for: Self.connectingLimit) } catch { return }
                self?.connectingExpired()
            }
        }
    }

    private func connectingExpired() {
        let stuck = lock.withLock { () -> Bool in
            connectingTimer = nil
            return isActive && pathSatisfied && !isConnected
        }
        guard stuck else { return }
        Self.log.notice("websocket stuck connecting; reconnecting")
        reconnect("stuck connecting", backedOff: true)
    }

    // MARK: - The replacement

    /// Asks for a replacement. Many asks in a moment are one: if one is already
    /// scheduled or running, this does nothing.
    private func reconnect(_ reason: String, backedOff: Bool, delay: Duration = .zero) {
        lock.withLock {
            guard pending == nil, !isRebuilding, isActive else { return }
            if delivered { backoffStep = 0 }

            var wait = delay
            // Never twice in two seconds, whatever asked.
            if let last = lastRebuildEnded {
                let spacing = Duration.seconds(backedOff ? Self.backoff(backoffStep) : 2)
                let remaining = spacing - last.duration(to: .now)
                if remaining > wait { wait = remaining }
            }
            pending = Task { [weak self] in
                if wait > .zero {
                    do { try await Task.sleep(for: wait) } catch { return }
                }
                await self?.rebuild(reason)
            }
        }
    }

    /// 2, 4, 8 ... 60 seconds, then jittered a little so several phones that
    /// lost the same server do not come back in step.
    private static func backoff(_ step: Int) -> Int {
        min(firstBackoff << min(step, 6), maxBackoff)
    }

    private func rebuild(_ reason: String) async {
        let proceed = lock.withLock { () -> Bool in
            guard isActive else { pending = nil; return false }
            if case .authenticated = authState.value, canRebuild() {
                isRebuilding = true
                return true
            }
            // Signed out, signing in, or the launch is still restoring: that
            // machinery owns the connection right now.
            pending = nil
            return false
        }
        guard proceed else { return }

        let generation = signOutLock.withLock { signOuts }
        // The stale action socket goes first: an exchange, if one is needed,
        // is the first thing to use it, and it must not be the one that hangs.
        provider.resetTransport()
        // A session whose JWT is still good is carried over as it is: no
        // exchange, so nothing rotates and nothing can be lost.
        provider.reuseNextLogin()
        let fresh = Client(deploymentUrl: deploymentURL, authProvider: provider)
        let outcome = await fresh.loginFromCache()

        var retryIn: Int?
        switch outcome {
        case .success:
            let replaced = lock.withLock { () -> [@Sendable () -> Void]? in
                // Signed out (or out and in again) while this was under way:
                // the fresh client belongs to a session that is over.
                guard signOutLock.withLock({ signOuts }) == generation,
                      case .authenticated = authState.value else { return nil }
                current = fresh
                epoch += 1
                delivered = false
                wiring = wire(fresh, dropReplay: true)
                return Array(observers.values)
            }
            if let replaced {
                Self.log.notice("reconnected (\(reason, privacy: .public)); re-attaching \(replaced.count, privacy: .public) reads")
                // The new socket's state is not replayed: until it says so,
                // it is not known to be up.
                socketStateChanged(connected: false)
                for notify in replaced { notify() }
            } else {
                Self.log.notice("reconnect discarded: signed out meanwhile")
                provider.discardLastWritten()
            }
        case let .failure(error):
            Self.log.error("reconnect failed (\(reason, privacy: .public)): \(String(describing: error), privacy: .public)")
            let (step, worthRetrying) = lock.withLock { () -> (Int, Bool) in
                backoffStep += 1
                return (backoffStep, pathSatisfied && isActive)
            }
            // A session that is really gone is the restore's to announce, not a
            // reason to keep knocking.
            if worthRetrying, provider.storedSession != .absent { retryIn = Self.backoff(step) }
        }

        let waiters = lock.withLock { () -> [CheckedContinuation<Void, Never>] in
            isRebuilding = false
            pending = nil
            lastRebuildEnded = .now
            defer { settleWaiters = [] }
            return settleWaiters
        }
        for waiter in waiters { waiter.resume() }

        if let retryIn {
            let jitter = Int.random(in: 0...max(1, retryIn / 4))
            reconnect("retry", backedOff: false, delay: .seconds(retryIn + jitter))
        }
    }

    private func noteSignedOut() {
        signOutLock.withLock { signOuts += 1 }
    }

    /// Lock held by the caller. Replaces what listens to the previous client.
    private func wire(_ client: Client, dropReplay: Bool) -> [AnyCancellable] {
        let sockets = client.watchWebSocketState().sink { [weak self] state in
            let connected = if case .connected = state { true } else { false }
            self?.socketStateChanged(connected: connected)
        }
        let auth = client.authState
        let forwarded = (dropReplay ? auth.dropFirst().eraseToAnyPublisher() : auth)
            .sink { [authState, weak self] state in
                if case .authenticated = state {} else { self?.noteSignedOut() }
                authState.send(state)
            }
        return [sockets, forwarded]
    }
}
