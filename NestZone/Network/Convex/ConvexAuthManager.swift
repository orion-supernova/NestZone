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

    func signIn(email: String, password: String) async throws {
        provider.pending = .init(email: Self.normalize(email), password: password, name: nil, flow: .signIn)
        if case .failure(let error) = await client.login() {
            provider.pending = nil
            throw ConvexAuthError.from(error)
        }
    }

    func signUp(email: String, password: String, name: String) async throws {
        Convex.log.log("signUp start: \(Self.normalize(email), privacy: .public)")
        provider.pending = .init(email: Self.normalize(email), password: password, name: name, flow: .signUp)
        let result = await client.login()
        if case .failure(let error) = result {
            provider.pending = nil
            Convex.log.error("signUp login() failed: \(String(describing: error), privacy: .public)")
            throw ConvexAuthError.from(error)
        }
        Convex.log.log("signUp login() succeeded")
    }

    /// Canonicalize the email so sign-up and sign-in always hit the same auth account,
    /// and so migrated (lowercase) profiles link correctly. @convex-dev/auth matches the
    /// account by exact `providerAccountId` (the email), so client-side normalization is
    /// what keeps "Foo@X.com ", "foo@x.com" from creating divergent accounts.
    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
