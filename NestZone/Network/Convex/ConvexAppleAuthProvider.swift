//
//  ConvexAppleAuthProvider.swift
//  NestZone
//
//  Bridges convex-swift's `AuthProvider` protocol to the backend's Apple-only
//  credentials provider. Replaces the former password provider: NestZone no
//  longer stores or verifies any secret.
//
//  Contract (from the deployed convex/auth.ts + @convex-dev/auth source):
//    action  auth:signIn
//      args  { provider?: String, params?: Any, refreshToken?: String }
//      • Apple sign-in: { provider: "apple",
//                         params: { identityToken: "<JWT from ASAuthorization>",
//                                   name: "<only on first authorization>" } }
//      • token refresh: { refreshToken: "<token>" }
//      ret   { tokens: { token, refreshToken } | null }
//    action  auth:signOut   args {}
//
//  `token` is the short-lived JWT handed to Convex as the id token; `refreshToken`
//  is kept in the Keychain and exchanged for a fresh JWT on relaunch.
//

import Foundation
import ConvexMobile

/// Tokens returned by `auth:signIn`. `T` for the AuthProvider conformance.
struct ConvexAuthTokens: Decodable, Sendable {
    let token: String
    let refreshToken: String
}

enum ConvexAuthError: LocalizedError {
    case noCachedSession
    case noTokens
    case rejectedByServer(String)

    var errorDescription: String? {
        switch self {
        case .noCachedSession:
            return "No saved session to restore."
        case .noTokens:
            return "Sign in failed. Please try again."
        case .rejectedByServer(let message):
            return message
        }
    }

    /// Turn a raw convex-swift / @convex-dev/auth error into something showable.
    static func from(_ error: Error) -> Error {
        let text = String(describing: error)
        if text.contains("Missing Apple identity token") || text.contains("Apple token has no subject") {
            return ConvexAuthError.rejectedByServer("Apple didn't return a valid sign-in token. Please try again.")
        }
        // jose throws these when the signature, audience or expiry doesn't check out.
        if text.contains("JWSSignatureVerificationFailed")
            || text.contains("JWTClaimValidationFailed")
            || text.contains("JWTExpired") {
            return ConvexAuthError.rejectedByServer("That Apple sign-in couldn't be verified. Please try again.")
        }
        return error
    }
}

/// Decoded shape of the `auth:signIn` action result.
private struct SignInActionResult: Decodable {
    let tokens: ConvexAuthTokens?
}

final class ConvexAppleAuthProvider: AuthProvider {
    typealias T = ConvexAuthTokens

    struct PendingCredential {
        let identityToken: String
        let name: String?
    }

    /// Set immediately before `client.login()` for an interactive sign-in.
    /// Consumed on use; when nil, `login()` falls back to the cached session.
    var pending: PendingCredential?

    /// Plain unauthenticated client, used only to invoke the public `auth:*`
    /// actions. The id token itself is owned by the ConvexClientWithAuth.
    private let actionClient: ConvexClient
    private let tokenStore: KeychainTokenStore

    init(deploymentUrl: String, tokenStore: KeychainTokenStore = KeychainTokenStore()) {
        self.actionClient = ConvexClient(deploymentUrl: deploymentUrl)
        self.tokenStore = tokenStore
    }

    // MARK: - AuthProvider

    func login(onIdToken: @Sendable @escaping (String?) -> Void) async throws -> ConvexAuthTokens {
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
            // Refresh token rejected/expired — drop it so we don't loop.
            tokenStore.refreshToken = nil
            throw error
        }
    }

    func extractIdToken(from authResult: ConvexAuthTokens) -> String {
        authResult.token
    }

    func logout() async throws {
        tokenStore.refreshToken = nil
        // Best-effort server-side session invalidation.
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
