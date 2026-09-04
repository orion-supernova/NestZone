import Foundation
import ConvexMobile

/// Bridges convex-swift's `AuthProvider` to the backend's Apple-only credentials
/// provider. NestZone stores and verifies no secret of its own.
///
/// Contract (from the deployed `convex/auth.ts` + `@convex-dev/auth`):
///
///     action auth:signIn
///       args { provider?: String, params?: Any, refreshToken?: String }
///       • Apple:   { provider: "apple",
///                    params: { identityToken: "<JWT from ASAuthorization>",
///                              name: "<only on first authorization>" } }
///       • refresh: { refreshToken: "<token>" }
///       ret  { tokens: { token, refreshToken } | null }
///     action auth:signOut  args {}
///
/// `token` is the short-lived JWT handed to Convex as the id token;
/// `refreshToken` goes to the Keychain and buys a fresh JWT on relaunch.
public final class ConvexAppleAuthProvider: AuthProvider, @unchecked Sendable {
    public typealias T = ConvexAuthTokens

    public struct PendingCredential: Sendable {
        public let identityToken: String
        public let name: String?

        public init(identityToken: String, name: String?) {
            self.identityToken = identityToken
            self.name = name
        }
    }

    /// Set immediately before `client.login()` for an interactive sign-in, and
    /// consumed on use. When nil, `login()` falls back to the cached session.
    ///
    /// Guarded by a lock: the SDK may call `login` off the main actor.
    public var pending: PendingCredential? {
        get { lock.withLock { _pending } }
        set { lock.withLock { _pending = newValue } }
    }

    private var _pending: PendingCredential?
    private let lock = NSLock()

    /// Plain unauthenticated client, used only to invoke the public `auth:*`
    /// actions. The id token itself is owned by the `ConvexClientWithAuth`.
    private let actionClient: ConvexClient
    private let tokenStore: KeychainTokenStore

    /// Serialises refresh-token exchanges.
    ///
    /// Convex Auth **rotates** the refresh token: every successful exchange
    /// consumes the stored one and returns a replacement. Two concurrent
    /// restores would therefore both present the same token, the second would be
    /// rejected as already-used, and the session would be destroyed — which is
    /// exactly what a fast relaunch or a second window used to do.
    private let refreshGate = AsyncSemaphore()

    public init(deploymentUrl: String) {
        actionClient = ConvexClient(deploymentUrl: deploymentUrl)
        tokenStore = KeychainTokenStore()
    }

    // MARK: - AuthProvider

    public func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> ConvexAuthTokens {
        guard let credential = pending else {
            // No interactive request in flight → try a silent restore instead.
            return try await loginFromCache(onIdToken: onIdToken)
        }
        pending = nil

        var params: [String: ConvexEncodable?] = ["identityToken": credential.identityToken]
        if let name = credential.name { params["name"] = name }

        let result: SignInActionResult = try await actionClient.action(
            "auth:signIn",
            with: ["provider": "apple", "params": params]
        )
        return try persist(result, onIdToken: onIdToken)
    }

    /// Silent restore: exchange the cached refresh token for a fresh JWT.
    ///
    /// The stored token is cleared **only** when the server explicitly rejects
    /// it. A network failure leaves it in place: the difference between "this
    /// session is over" and "we could not reach the server just now" is the
    /// difference between signing someone out and asking again in a moment.
    public func loginFromCache(
        onIdToken: @Sendable @escaping (String?) -> Void
    ) async throws -> ConvexAuthTokens {
        await refreshGate.wait()

        guard let refresh = tokenStore.refreshToken else {
            await refreshGate.signal()
            throw ConvexAuthError.noCachedSession
        }

        let result: SignInActionResult
        do {
            result = try await actionClient.action(
                "auth:signIn",
                with: ["refreshToken": refresh]
            )
        } catch {
            await refreshGate.signal()
            // Could not complete the exchange. The token may or may not have
            // been consumed server-side, but discarding it here guarantees a
            // sign-out, whereas keeping it only risks one wasted retry.
            throw ConvexAuthError.unreachable
        }

        do {
            let tokens = try persist(result, onIdToken: onIdToken)
            await refreshGate.signal()
            return tokens
        } catch {
            // The server answered and said no. Drop it so we don't loop.
            tokenStore.refreshToken = nil
            await refreshGate.signal()
            throw error
        }
    }

    /// Whether a silent restore is even worth attempting.
    public var hasStoredSession: Bool { tokenStore.refreshToken != nil }

    public func extractIdToken(from authResult: ConvexAuthTokens) -> String {
        authResult.token
    }

    public func logout() async throws {
        tokenStore.refreshToken = nil
        // Best-effort server-side session invalidation; a failure here must not
        // keep the user signed in locally.
        try? await actionClient.action("auth:signOut")
    }

    private func persist(
        _ result: SignInActionResult,
        onIdToken: @Sendable @escaping (String?) -> Void
    ) throws -> ConvexAuthTokens {
        guard let tokens = result.tokens else { throw ConvexAuthError.noTokens }
        tokenStore.refreshToken = tokens.refreshToken
        onIdToken(tokens.token)
        return tokens
    }
}

/// Tokens returned by `auth:signIn`.
public struct ConvexAuthTokens: Decodable, Sendable {
    public let token: String
    public let refreshToken: String
}

private struct SignInActionResult: Decodable {
    let tokens: ConvexAuthTokens?
}

public enum ConvexAuthError: LocalizedError, Sendable {
    case noCachedSession
    /// The exchange could not be completed — offline, or the backend was
    /// restarting. Distinct from rejection, because it must not sign anyone out.
    case unreachable
    case noTokens
    case rejectedByServer(String)

    public var errorDescription: String? {
        switch self {
        case .noCachedSession:
            String(localized: "auth.noCachedSession", defaultValue: "No saved session to restore.")
        case .unreachable:
            String(localized: "error.offline", defaultValue: "You're offline. We'll retry when you're back.")
        case .noTokens:
            String(localized: "auth.noTokens", defaultValue: "Sign in failed. Please try again.")
        case let .rejectedByServer(message):
            message
        }
    }

    /// Turns a raw convex-swift / `@convex-dev/auth` error into something a
    /// person can act on. These arrive as opaque strings, so matching on the
    /// text is the only handle we have.
    public static func mapped(_ error: any Error) -> AppError {
        if let authError = error as? ConvexAuthError {
            return .server(authError.errorDescription ?? "")
        }
        let text = String(describing: error)
        if text.contains("Missing Apple identity token") || text.contains("Apple token has no subject") {
            return .server(String(
                localized: "auth.appleTokenInvalid",
                defaultValue: "Apple didn't return a valid sign-in token. Please try again."
            ))
        }
        // `jose` throws these when signature, audience or expiry don't check out.
        if text.contains("JWSSignatureVerificationFailed")
            || text.contains("JWTClaimValidationFailed")
            || text.contains("JWTExpired") {
            return .server(String(
                localized: "auth.appleTokenUnverified",
                defaultValue: "That Apple sign-in couldn't be verified. Please try again."
            ))
        }
        return AppError(error)
    }
}


/// Minimal async semaphore, so one refresh happens at a time.
///
/// `DispatchSemaphore` would block a cooperative thread, which is exactly what
/// Swift concurrency forbids.
actor AsyncSemaphore {
    private var isTaken = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard isTaken else {
            isTaken = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        guard let next = waiters.first else {
            isTaken = false
            return
        }
        waiters.removeFirst()
        next.resume()
    }
}
