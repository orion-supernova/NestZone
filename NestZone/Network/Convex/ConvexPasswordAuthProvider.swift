//
//  ConvexPasswordAuthProvider.swift
//  NestZone
//
//  Bridges the convex-swift `AuthProvider` protocol (designed for OAuth providers
//  like Auth0/Clerk that hand back an id token) to the backend's @convex-dev/auth
//  **Password** provider, which has no official native-Swift client.
//
//  Verified contract (from the deployed convex/auth.ts + @convex-dev/auth source):
//    action  auth:signIn
//      args  { provider?: string, params?: any, refreshToken?: string }
//      • password sign-in: { provider: "password",
//                            params: { email, password, flow: "signIn"|"signUp", name? } }
//      • token refresh:    { refreshToken: "<token>" }
//      ret   { tokens: { token: string, refreshToken: string } | null }
//    action  auth:signOut   args {}
//
//  `token` is the short-lived JWT we feed Convex as the id token; `refreshToken`
//  is persisted in the Keychain and exchanged for a fresh JWT on relaunch.
//

import Foundation
import ConvexMobile

/// Tokens returned by `auth:signIn`. `T` for the AuthProvider conformance.
struct ConvexAuthTokens: Decodable, Sendable {
    let token: String
    let refreshToken: String
}

enum ConvexAuthError: LocalizedError {
    case noPendingCredentials
    case noCachedSession
    case noTokens
    case accountNotFound
    case wrongPassword
    case accountAlreadyExists
    case weakPassword
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noPendingCredentials: return "No sign-in credentials were provided."
        case .noCachedSession:      return "No saved session to restore."
        case .noTokens:             return "Authentication failed."
        case .accountNotFound:      return "No password is set for this email yet. If you've used NestZone before, tap “Sign Up” and use the same email to set a new password — your home and data will be restored."
        case .wrongPassword:        return "Wrong email or password."
        case .accountAlreadyExists: return "An account with this email already exists. Tap “Login” instead."
        case .weakPassword:         return "Password must be at least 8 characters."
        case .server(let message):  return message
        }
    }

    /// Translate a raw convex-swift / @convex-dev/auth error into a user-facing one.
    static func from(_ error: Error) -> Error {
        let text = String(describing: error)
        if text.contains("InvalidAccountId") { return ConvexAuthError.accountNotFound }
        if text.contains("InvalidSecret")    { return ConvexAuthError.wrongPassword }
        if text.contains("already exists") || text.contains("Account already exists") {
            return ConvexAuthError.accountAlreadyExists
        }
        return error
    }
}

/// Decoded shape of the `auth:signIn` action result.
private struct SignInActionResult: Decodable {
    let tokens: ConvexAuthTokens?
}

final class ConvexPasswordAuthProvider: AuthProvider {
    typealias T = ConvexAuthTokens

    enum Flow: String { case signIn, signUp }

    struct PendingCredentials {
        let email: String
        let password: String
        let name: String?
        let flow: Flow
    }

    /// Set immediately before calling `client.login()` for an interactive sign-in/up.
    /// Consumed (cleared) on use. When nil, `login()` falls back to a cached session.
    var pending: PendingCredentials?

    /// A plain, unauthenticated client used solely to invoke the public `auth:*`
    /// actions. (The id token itself is owned by the ConvexClientWithAuth.)
    private let actionClient: ConvexClient
    private let tokenStore: KeychainTokenStore

    init(deploymentUrl: String, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.actionClient = ConvexClient(deploymentUrl: deploymentUrl)
        self.tokenStore = tokenStore
    }

    // MARK: - AuthProvider

    /// Interactive sign-in / sign-up using `pending` credentials.
    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> ConvexAuthTokens {
        guard let creds = pending else {
            // No interactive request in flight → attempt a silent restore instead.
            return try await loginFromCache(onIdToken: onIdToken)
        }
        pending = nil

        var params: [String: ConvexEncodable?] = [
            "email": creds.email,
            "password": creds.password,
            "flow": creds.flow.rawValue,
        ]
        if let name = creds.name { params["name"] = name }

        let result: SignInActionResult = try await actionClient.action(
            "auth:signIn",
            with: ["provider": "password", "params": params]
        )
        return try persist(result, onIdToken: onIdToken)
    }

    /// Silent restore: exchange the cached refresh token for a fresh JWT.
    func loginFromCache(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> ConvexAuthTokens {
        guard let refresh = tokenStore.refreshToken else {
            throw ConvexAuthError.noCachedSession
        }
        let result: SignInActionResult = try await actionClient.action(
            "auth:signIn",
            with: ["refreshToken": refresh]
        )
        do {
            return try persist(result, onIdToken: onIdToken)
        } catch {
            // Refresh token was rejected/expired — drop it so we don't loop.
            tokenStore.refreshToken = nil
            throw error
        }
    }

    func extractIdToken(from authResult: ConvexAuthTokens) -> String {
        authResult.token
    }

    func logout() async throws {
        tokenStore.refreshToken = nil
        // Best-effort server-side session invalidation; safe to ignore failures.
        do { try await actionClient.action("auth:signOut") } catch { }
    }

    // MARK: - Helpers

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
