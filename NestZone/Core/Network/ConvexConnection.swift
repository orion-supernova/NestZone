import Foundation
import Combine
import ConvexMobile
import os

/// The app's single connection to Convex.
///
/// Convex is a *reactive* backend: `subscribe` opens a websocket query that
/// pushes a new value every time the underlying data changes. The app was using
/// it as a REST API — a helper called `Convex.once` opened a subscription, took
/// the first value, and immediately tore it down, and every screen re-ran that
/// on appear and again whenever a `homeDidChange` notification fired. That paid
/// the full websocket-query setup cost for each read, showed stale data between
/// refreshes, and meant a change made on one device never reached another.
///
/// Everything here is a live stream. A screen subscribes once, and updates
/// arrive on their own.
/// `@unchecked Sendable`: `ConvexClientWithAuth` predates Swift concurrency and
/// carries no `Sendable` annotation, but it is a thin wrapper over the Rust
/// client, which is built for concurrent use and does its own synchronisation.
/// Nothing mutable is stored here beyond the diagnostics bag, which locks.
public final class ConvexConnection: @unchecked Sendable {
    public static let shared = ConvexConnection()

    /// Deployment origin of the self-hosted backend.
    public static let deploymentURL = "https://nestzone-convex-api.walhallaa.com"

    /// Shared logger, also used by the resource loaders in this module.
    static let log = Logger(subsystem: "com.walhallaa.NestZone", category: "Convex")

    public let authProvider: ConvexAppleAuthProvider
    let client: ConvexClientWithAuth<ConvexAuthTokens>

    private let diagnostics = DiagnosticsBag()

    /// Whether the websocket is up, as the SDK last reported it.
    ///
    /// Shared rather than per-instance so `mapped` — which is static, because it
    /// is called from throwing contexts all over this file — can consult it.
    /// There is one `ConvexConnection` in the process.
    private static let link = ConnectionState()

    /// Whether the app currently has a live connection to the backend.
    public static var isConnected: Bool { link.isConnected }

    private init() {
        let provider = ConvexAppleAuthProvider(deploymentUrl: Self.deploymentURL)
        authProvider = provider
        client = ConvexClientWithAuth(deploymentUrl: Self.deploymentURL, authProvider: provider)

        // Always watched, not just in debug. This used to live in a
        // `startDiagnostics()` that nothing ever called, so the one signal that
        // says whether the phone can reach the backend was both compiled out of
        // release builds and unreachable in debug ones.
        //
        // It is what tells a dropped connection apart from a broken server —
        // see `mapped`.
        let link = Self.link
        diagnostics.store(
            client.watchWebSocketState().sink { state in
                let connected = if case .connected = state { true } else { false }
                link.isConnected = connected
                #if DEBUG
                Self.log.debug("websocket: \(String(describing: state), privacy: .public)")
                #endif
            }
        )
    }

    // MARK: - Reads

    /// How many times a failed subscription is re-opened before the error is
    /// allowed to reach the screen. The budget is refreshed by any delivered
    /// value, so this bounds a *run* of failures, not the lifetime of a stream.
    private static let maxResubscribes = 4

    /// Backoff bounds for a subscription waiting for the network to come back.
    /// It starts quick, because most drops are momentary, and settles into a
    /// slow poll rather than giving up.
    private static let firstOfflineWait: Duration = .milliseconds(500)
    private static let maxOfflineWait: Duration = .seconds(30)

    /// A live query. The stream yields the current value immediately and again
    /// on every server-side *change*, and tears the subscription down when the
    /// consuming task is cancelled.
    ///
    /// Change, not push. Convex re-publishes every query in the client's set on
    /// every transition, and the set is modified whenever any screen anywhere
    /// swaps a subscription — so one tap of the Finance month scrubber, which
    /// replaces two queries, made `users:me`, `homes:listMine`, the bills, the
    /// budgets, the members and the Hub's counters all re-deliver the payload
    /// already on screen, three times over. Each of those was a full trip
    /// through the root reducer and an invalidation of every view reading the
    /// result.
    ///
    /// An identical payload carries no information, so it does not leave here.
    /// The comparison is per-subscription, and a fresh subscription starts with
    /// nothing to compare against, so the first value after a month change is
    /// always delivered even if it happens to match the month before it.
    ///
    /// A failure re-opens the query rather than ending the stream. A live
    /// subscription used to die on the first error and never come back: one
    /// handler that overran its second, one socket dropped in a lift, and the
    /// screen was inert until it was navigated away from and re-entered, because
    /// the only thing that ever restarted a subscription was `.task` running
    /// again. Which errors are worth re-opening is `isWorthRetrying`'s call.
    public func subscribe<T: Decodable & Equatable & Sendable>(
        to name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) -> AsyncThrowingStream<T, any Error> {
        // `ConvexEncodable` predates Swift concurrency and carries no `Sendable`
        // conformance, so the argument dictionary cannot cross into the retry
        // task on its own account. Boxing is safe here for the same reason the
        // class above is `@unchecked Sendable`: the arguments are value types
        // built at the call site, never mutated after this point, and only ever
        // handed straight back to the SDK.
        let boxed = ArgumentBox(args)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var attempt = 0
                // Tracked apart from `attempt`, because a stretch with no
                // network must not use up the budget that exists for a query
                // the server keeps rejecting.
                var offlineWait = Self.firstOfflineWait
                // Carried across re-opens: a fresh subscription always replays
                // the current value, and that replay is not news. The
                // duplicate-dropping contract the whole app leans on — an
                // optimistic write is confirmed by a *change*, never corrected
                // by a redelivery — has to hold across a reconnect too, or the
                // reconnect itself would look like a server push.
                var last: T?

                while !Task.isCancelled {
                    do {
                        for try await value in self.attemptSubscription(to: name, args: boxed.args, as: T.self) {
                            // A value proves the query is not broken, so a
                            // long-lived stream gets its full budget back after
                            // every recovery rather than spending it once.
                            attempt = 0
                            offlineWait = Self.firstOfflineWait
                            guard value != last else { continue }
                            last = value
                            continuation.yield(value)
                        }
                        // The publisher completed on its own. Nothing failed,
                        // so there is nothing to retry.
                        return continuation.finish()
                    } catch {
                        let mapped = AppError(error)
                        guard !Task.isCancelled, Self.isWorthRetrying(mapped) else {
                            return continuation.finish(throwing: mapped)
                        }

                        let delay: Duration
                        if mapped == .offline {
                            // Being offline is not a reason to stop. The phone
                            // went into a lift, and it will come out again;
                            // giving up after a few seconds means coming out two
                            // minutes later to a screen that is permanently
                            // dead, with nothing to restart it short of
                            // navigating away and back. So this waits instead of
                            // spending the budget, backing off to a slow poll
                            // rather than a spin. The task dies with the screen,
                            // so waiting forever costs nothing once nobody is
                            // looking.
                            offlineWait = min(offlineWait * 2, Self.maxOfflineWait)
                            delay = Self.jittered(offlineWait)
                        } else {
                            // A server that answers and keeps saying no is a
                            // different thing: four tries and a few seconds,
                            // then let the screen show the error rather than
                            // hammering a query that cannot work.
                            guard attempt < Self.maxResubscribes else {
                                return continuation.finish(throwing: mapped)
                            }
                            attempt += 1
                            delay = Self.jittered(.milliseconds(250 << (attempt - 1)))
                        }

                        Self.log.debug(
                            "\(name, privacy: .public) dropped (\(mapped.diagnostic, privacy: .public)); re-opening in \(delay, privacy: .public)"
                        )
                        try? await Task.sleep(for: delay)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Spreads a retry out over the second half of its backoff window.
    ///
    /// A screen opens several subscriptions at once, so when the backend has a
    /// bad moment they tend to fail together — and without this they would then
    /// retry together, arriving as one burst on exactly the server that has just
    /// shown it cannot take one. Each one waits its own amount, so the load
    /// spreads instead of resonating.
    private static func jittered(_ delay: Duration) -> Duration {
        let ms = Double(delay.components.seconds) * 1000
            + Double(delay.components.attoseconds) / 1e15
        return .milliseconds(Int(ms / 2 + Double.random(in: 0...(ms / 2))))
    }

    /// Whether a failed subscription is worth re-opening.
    ///
    /// A live query dies for two very different reasons. One is the household's
    /// wifi, a dropped socket, or a handler that ran out of its one second under
    /// momentary load — none of which say anything about the query, and all of
    /// which fix themselves. The other is a query that cannot work: a rejected
    /// argument, a payload the client cannot decode, an expired session.
    /// Re-opening the first is the whole point; re-opening the second is a spin
    /// that ends in the same alert.
    private static func isWorthRetrying(_ error: AppError) -> Bool {
        switch error {
        case .offline, .server, .unknown:
            true
        // Deterministic, or somebody else's job: `.notAuthenticated` is the
        // session machinery's to resolve, and a decode failure will fail
        // identically on every attempt.
        case .notAuthenticated, .decoding, .validation, .noHomeSelected, .cancelled:
            false
        }
    }

    /// One attempt at a live query. Ends — for good — on the first failure;
    /// `subscribe` is what decides whether to open another.
    private func attemptSubscription<T: Decodable & Equatable & Sendable>(
        to name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) -> AsyncThrowingStream<T, any Error> {
        AsyncThrowingStream { continuation in
            // `AnyCancellable` is not `Sendable`, and `onTermination` is a
            // `@Sendable` closure. The box hands ownership across that boundary;
            // it is only ever cancelled once, from whichever side finishes first.
            let box = CancellableBox()
            box.cancellable = client
                .subscribe(to: name, with: args, yielding: T.self)
                .removeDuplicates()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            continuation.finish()
                        case let .failure(error):
                            continuation.finish(throwing: Self.mapped(error, at: name))
                        }
                    },
                    receiveValue: { continuation.yield($0) }
                )
            continuation.onTermination = { _ in box.cancel() }
        }
    }

    /// One value from a live query, then unsubscribe.
    ///
    /// Only for genuinely one-shot reads — resolving an invite code, say. If a
    /// screen displays the result, subscribe instead so it stays current.
    public func first<T: Decodable & Equatable & Sendable>(
        _ name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        for try await value in subscribe(to: name, args: args, as: T.self) {
            return value
        }
        throw AppError.server("\(name) produced no value")
    }

    // MARK: - Writes

    /// Runs a mutation whose result we don't need.
    ///
    /// Not `client.mutation(name:with:)` — the SDK's no-result overload is
    /// implemented as `let _: String? = try await mutation(...)`, so it tries to
    /// decode the response as a string. Every mutation that returns a document
    /// or `{ ok: true }` therefore failed with "The data couldn't be read
    /// because it isn't in the correct format", which is what used to break home
    /// creation and every update and delete in the app. `Discarded` accepts any
    /// JSON shape and keeps none of it.
    public func mutate(_ name: String, args: [String: ConvexEncodable?]? = nil) async throws {
        do {
            let _: Discarded? = try await client.mutation(name, with: args)
        } catch {
            throw Self.mapped(error, at: name)
        }
    }

    /// Runs a mutation and decodes its result.
    public func mutate<T: Decodable & Sendable>(
        _ name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        do {
            return try await client.mutation(name, with: args)
        } catch {
            throw Self.mapped(error, at: name)
        }
    }

    /// Runs a Convex action — the only calls allowed to reach third-party APIs,
    /// because that is where the secrets live.
    public func act<T: Decodable & Sendable>(
        _ name: String,
        args: [String: ConvexEncodable?]? = nil,
        as type: T.Type = T.self
    ) async throws -> T {
        do {
            return try await client.action(name, with: args)
        } catch {
            throw Self.mapped(error, at: name)
        }
    }

    // MARK: - Files

    /// Posts bytes to a one-shot upload URL and hands back the storage id.
    ///
    /// The bytes never pass through a mutation. `signedBy` names a mutation
    /// that returns a signed URL, the phone posts straight to it, and only the
    /// id it answers with goes into the document that records it — a
    /// five-megapixel photo does not belong in a transaction.
    ///
    /// One implementation for both of the app's uploads. House-problem photos
    /// and profile photos had the same twenty lines each, which is one place
    /// for the status check to be forgotten and two places to fix it.
    public func upload(
        _ data: Data,
        contentType: String = "image/jpeg",
        signedBy mutation: String
    ) async throws -> String {
        let destination = try await mutate(mutation, args: [:], as: String.self)
        guard let url = URL(string: destination) else {
            throw AppError.server("The upload address made no sense")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Convex stores whatever content type it is told, and that is what
        // comes back on the way in — so this has to be the truth about the
        // bytes, which both callers guarantee by re-encoding as JPEG first.
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (body, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AppError.server("The upload failed (\(code))")
        }
        return try JSONDecoder().decode(UploadedFile.self, from: body).storageId
    }

    /// What a Convex upload URL answers with.
    private struct UploadedFile: Decodable {
        let storageId: String
    }

    /// Decodes successfully from any JSON value, retaining nothing.
    struct Discarded: Decodable {
        init(from decoder: any Decoder) throws {}
    }

    /// Turns a convex-swift `ClientError` into an `AppError` that still carries
    /// the server's message.
    ///
    /// Without this every backend failure — a rejected argument, a thrown
    /// `Error` in a handler, a validator mismatch — arrived as
    /// `AppError.unknown` with an opaque description, so the UI said
    /// "Something went wrong" and the log said nothing useful. The message is
    /// logged in full and kept on the error; `AppError` still decides what the
    /// *user* sees.
    static func mapped(_ error: any Error, at name: String) -> AppError {
        let mapped: AppError
        if let clientError = error as? ClientError {
            mapped = switch clientError {
            // The server ran and said no: a thrown handler error, a rejected
            // argument list, a query that overran its second. All of these mean
            // the request reached the backend, so none of them are an outage.
            case let .ServerError(msg): .server(msg)
            case let .ConvexError(data): .server(data)
            // Everything the transport itself can go wrong with. `ClientError`
            // has no offline case — the three above are all of it — so a phone
            // in a lift produced `.server` and the app told the household
            // "something went wrong on our end", which is both untrue and
            // useless advice. The websocket's own state is the honest
            // discriminator, and far steadier than matching on message text.
            case let .InternalError(msg):
                link.isConnected ? .server(msg) : .offline
            }
        } else {
            mapped = AppError(error)
        }
        log.error("\(name, privacy: .public) failed: \(mapped.diagnostic, privacy: .public)")
        return mapped
    }
}

/// Carries a query's arguments across a task boundary.
///
/// `ConvexEncodable` has no `Sendable` conformance to inherit — it is older than
/// Swift concurrency — so a dictionary of them cannot be captured by the retry
/// task in `subscribe` without one. Nothing reads the arguments but the SDK, and
/// nothing writes them after the call site builds them.
private final class ArgumentBox: @unchecked Sendable {
    let args: [String: ConvexEncodable?]?
    init(_ args: [String: ConvexEncodable?]?) { self.args = args }
}

/// Carries a Combine `AnyCancellable` across a `@Sendable` boundary.
private final class CancellableBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancellable: AnyCancellable?

    var cancellable: AnyCancellable? {
        get { lock.withLock { _cancellable } }
        set { lock.withLock { _cancellable = newValue } }
    }

    func cancel() {
        lock.withLock {
            _cancellable?.cancel()
            _cancellable = nil
        }
    }
}

/// The websocket's last reported state.
///
/// `WebSocketState` is only `.connected` or `.connecting`; the SDK reconnects on
/// its own and never reports a terminal "offline". So "connecting" is what being
/// offline looks like from here, and it is the difference between telling
/// somebody the server is broken and telling them to check their signal.
private final class ConnectionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _isConnected = false

    var isConnected: Bool {
        get { lock.withLock { _isConnected } }
        set { lock.withLock { _isConnected = newValue } }
    }
}

/// Holds Combine cancellables for the process lifetime.
private final class DiagnosticsBag: @unchecked Sendable {
    private let lock = NSLock()
    private var bag: [AnyCancellable] = []

    func store(_ cancellable: AnyCancellable) {
        lock.withLock { bag.append(cancellable) }
    }
}

// MARK: - Typed ids on the wire

extension ConvexID: ConvexEncodable {
    public func convexEncode() throws -> String { try rawValue.convexEncode() }
}

/// Same job as `CancellableBox`, visible to the dependency clients in this module.
final class CancellableBoxPublic: @unchecked Sendable {
    private let lock = NSLock()
    private var _cancellable: AnyCancellable?

    var cancellable: AnyCancellable? {
        get { lock.withLock { _cancellable } }
        set { lock.withLock { _cancellable = newValue } }
    }

    func cancel() {
        lock.withLock {
            _cancellable?.cancel()
            _cancellable = nil
        }
    }
}
