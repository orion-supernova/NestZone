//
//  ConvexAuthManager.swift
//  NestZone
//
//  Drop-in replacement for PocketBaseAuthManager. Exposes the same surface the app
//  depends on — `currentUser` (reactive, from `users:me`) and `isAuthenticated` —
//  so NestZoneApp and the auth view models change only by type name.
//
//  Auth state is driven by ConvexClientWithAuth.authState; the JWT/refresh-token
//  plumbing lives in ConvexPasswordAuthProvider.
//

import Foundation
import Combine
import ConvexMobile

@MainActor
final class ConvexAuthManager: ObservableObject {
    /// Current profile, or nil when signed out. Mirrors PocketBaseAuthManager.currentUser.
    @Published var currentUser: NZUser?
    @Published var isAuthenticated = false
    /// True while restoring a cached session at launch (avoids an auth-screen flash).
    @Published var isBootstrapping = true

    private let client = Convex.client
    private let provider = Convex.authProvider
    private var bag = Set<AnyCancellable>()
    private var meSubscription: AnyCancellable?
    private var appleCoordinator: AppleSignInCoordinator?

    init() {
        Convex.startDiagnostics()
        Convex.log.log("ConvexAuthManager init")
        // React to auth-state changes: (re)bind the live profile when authenticated,
        // clear it when not. NOTE: we deliberately do NOT touch `isBootstrapping` here.
        // `.loading` is transient (it fires during every sign-in attempt); flipping the
        // root view on it would recreate AuthenticationScreen and wipe the user's typed
        // email/password. `isBootstrapping` is owned solely by the initial cache restore.
        client.authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                Convex.log.log("authState: \(String(describing: state), privacy: .public)")
                switch state {
                case .authenticated:
                    self.isAuthenticated = true
                    self.bindCurrentUser()
                case .unauthenticated:
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.meSubscription = nil
                case .loading:
                    break   // transient — keep the current screen mounted
                }
            }
            .store(in: &bag)

        // Try to silently restore a previous session from the cached refresh token.
        // Whatever the outcome, the launch gate is resolved once this completes.
        Task {
            _ = await client.loginFromCache()
            self.isBootstrapping = false
        }
    }

    /// Subscribe to the signed-in user's profile; pushes updates reactively.
    private func bindCurrentUser() {
        meSubscription = client
            .subscribe(to: "users:me", yielding: NZUser?.self)
            .handleEvents(receiveCompletion: { c in
                if case .failure(let e) = c {
                    Convex.log.error("users:me error: \(String(describing: e), privacy: .public)")
                }
            })
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in self?.currentUser = user }
    }

    // MARK: - Actions

    /// The only way in: native Sign in with Apple. There is no sign-up flow —
    /// Apple tells us whether this is a first authorization, and the backend
    /// creates the account on demand keyed on Apple's stable `sub`.
    func signInWithApple() async throws {
        let coordinator = AppleSignInCoordinator()
        // Held for the duration: ASAuthorizationController keeps only a weak
        // delegate, so a local-only reference would be deallocated mid-flow.
        appleCoordinator = coordinator
        defer { appleCoordinator = nil }

        let credential = try await coordinator.signIn()
        Convex.log.log("Apple sign-in: got identity token, exchanging with Convex")

        provider.pending = .init(
            identityToken: credential.identityToken,
            name: credential.displayName
        )
        if case .failure(let error) = await client.login() {
            provider.pending = nil
            Convex.log.error("Apple sign-in exchange failed: \(String(describing: error), privacy: .public)")
            throw ConvexAuthError.from(error)
        }
        Convex.log.log("Apple sign-in succeeded")
    }

    /// Updates the signed-in user's display name.
    ///
    /// No manual refresh afterwards: `currentUser` is bound to a live `users:me`
    /// subscription, so the new name arrives on its own.
    ///
    /// This matters more than it looks. Apple only supplies a name on the very
    /// FIRST authorization for an app; every later sign-in omits it. Anyone who
    /// had already authorized NestZone therefore ends up with no name and,
    /// without this, no way to set one.
    func updateDisplayName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // users:updateProfile returns the patched document, so it has to go
        // through Convex.run rather than the SDK's no-result overload.
        try await Convex.run("users:updateProfile", args: ["name": trimmed])
    }

    func signOut() async {
        await client.logout()
    }

    /// Synchronous logout shim for call sites that used PocketBaseAuthManager.logout().
    func logout() {
        Task { await signOut() }
    }

    /// Compatibility no-op: PocketBase needed an explicit token refresh on foreground.
    /// Convex's client refreshes the JWT automatically via the auth provider, so there's
    /// nothing to do here — kept so existing call sites compile unchanged.
    func refreshAuth() async throws {}
}
