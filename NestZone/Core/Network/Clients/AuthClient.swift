import ComposableArchitecture
import Foundation

/// Sign-in, sign-out, and the signed-in profile.
@DependencyClient
public struct AuthClient: Sendable {
    /// Live auth state. Yields on every transition, including the silent
    /// restore at launch.
    public var authState: @Sendable () -> AsyncStream<AuthStatus> = { .never }
    /// The signed-in user's own profile, kept current by `users:me`.
    public var currentUser: @Sendable () -> AsyncThrowingStream<User?, any Error> = { .never }
    /// Exchanges an Apple credential for a Convex session.
    ///
    /// The credential comes from SwiftUI's own `SignInWithAppleButton`, so the
    /// app no longer keeps an `ASAuthorizationController` delegate alive by hand
    /// behind a transparent tap target. There is no sign-up: Apple reports
    /// whether this is a first authorization and the backend creates the account
    /// keyed on Apple's stable `sub`.
    public var signInWithApple: @Sendable (AppleCredential) async throws -> Void
    public var signOut: @Sendable () async -> Void
    /// Restores a cached session. Returns whether one was found.
    public var restoreSession: @Sendable () async -> Bool = { false }
    public var updateDisplayName: @Sendable (String) async throws -> Void
}

/// What SwiftUI's `SignInWithAppleButton` hands back, reduced to the two things
/// the backend needs.
public struct AppleCredential: Equatable, Sendable {
    public let identityToken: String
    /// Apple supplies this ONLY on a user's very first authorization; every
    /// later sign-in omits it, which is why the app also offers an editable
    /// display name in Settings.
    public let displayName: String?

    public init(identityToken: String, displayName: String?) {
        self.identityToken = identityToken
        self.displayName = displayName
    }
}

public enum AuthStatus: Equatable, Sendable {
    case unknown
    case authenticated
    case unauthenticated
}

extension AuthClient: DependencyKey {
    public static let liveValue: AuthClient = {
        let connection = ConvexConnection.shared

        return AuthClient(
            authState: {
                AsyncStream { continuation in
                    let box = CancellableBoxPublic()
                    box.cancellable = connection.client.authState.sink { state in
                        let status: AuthStatus = switch state {
                        case .authenticated: .authenticated
                        case .unauthenticated: .unauthenticated
                        // `.loading` is transient — it fires during every
                        // sign-in attempt. Reporting it would tear down and
                        // rebuild the auth screen mid-typing.
                        case .loading: .unknown
                        }
                        continuation.yield(status)
                    }
                    continuation.onTermination = { _ in box.cancel() }
                }
            },
            currentUser: {
                connection.subscribe(to: "users:me", as: User?.self)
            },
            signInWithApple: { credential in
                connection.authProvider.pending = .init(
                    identityToken: credential.identityToken,
                    name: credential.displayName
                )
                if case let .failure(error) = await connection.client.login() {
                    connection.authProvider.pending = nil
                    throw ConvexAuthError.mapped(error)
                }
            },
            signOut: {
                await connection.client.logout()
            },
            restoreSession: {
                if case .success = await connection.client.loginFromCache() { return true }
                return false
            },
            updateDisplayName: { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw AppError.validation(String(
                        localized: "validation.nameEmpty",
                        defaultValue: "Enter a name."
                    ))
                }
                // Returns the patched document, so it cannot use the SDK's
                // no-result overload.
                try await connection.mutate("users:updateProfile", args: ["name": trimmed])
            }
        )
    }()

    public static let testValue = AuthClient()
}

extension DependencyValues {
    public var auth: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
