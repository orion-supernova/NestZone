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

    private init() {
        let provider = ConvexAppleAuthProvider(deploymentUrl: Self.deploymentURL)
        authProvider = provider
        client = ConvexClientWithAuth(deploymentUrl: Self.deploymentURL, authProvider: provider)
    }

    /// Mirrors websocket state into the log. Only worth running in debug builds;
    /// in release it is a no-op so we are not logging on every reconnect.
    public func startDiagnostics() {
        #if DEBUG
        diagnostics.store(
            client.watchWebSocketState().sink { state in
                Self.log.debug("websocket: \(String(describing: state), privacy: .public)")
            }
        )
        #endif
    }

    // MARK: - Reads

    /// A live query. The stream yields the current value immediately and again
    /// on every server-side change, and tears the subscription down when the
    /// consuming task is cancelled.
    public func subscribe<T: Decodable & Sendable>(
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
    public func first<T: Decodable & Sendable>(
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
            // A rejected argument list arrives this way too, and is almost
            // always a client/server name mismatch rather than an outage.
            case let .ServerError(msg): .server(msg)
            case let .ConvexError(data): .server(data)
            case let .InternalError(msg): .server(msg)
            }
        } else {
            mapped = AppError(error)
        }
        log.error("\(name, privacy: .public) failed: \(mapped.diagnostic, privacy: .public)")
        return mapped
    }
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
