import Foundation

/// The last APNs token this device registered with the server, kept across
/// launches.
///
/// Registration is an upsert on the token, so the server can hold a token from
/// an earlier launch that this launch has not heard from iOS about yet. Signing
/// out in that window used to unregister nothing, and the device went on
/// receiving the household's pushes. A token is not a secret (it is only an
/// address, useless without the server's APNs key), so `UserDefaults` is enough.
struct PushTokenMemory: Sendable {
    static let standard = PushTokenMemory(suite: nil)

    private let suite: String?
    private let key = "lastRegisteredPushToken"

    /// `suite` is for tests, which must not touch the app's own defaults.
    init(suite: String?) { self.suite = suite }

    private var defaults: UserDefaults {
        suite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    var remembered: String? { defaults.string(forKey: key) }

    /// The server accepted `token`. If it was holding a different one for this
    /// device (iOS reissued it between launches), that one is stale: it is
    /// unregistered, best effort, and replaced in memory by the new one.
    func registered(_ token: String, unregister: (String) async throws -> Void) async {
        if let old = remembered, old != token {
            // Left in memory if it fails, so sign-out still tries it.
            if (try? await unregister(old)) != nil { defaults.removeObject(forKey: key) }
        }
        defaults.set(token, forKey: key)
    }

    /// Unregisters every token the server may hold for this device: this
    /// launch's, if it has one, and the remembered one, which is the one the
    /// server holds when this launch has none yet. The remembered one is
    /// forgotten only once the server has dropped it.
    func unregisterAtSignOut(
        current: String?,
        unregister: (String) async throws -> Void
    ) async {
        var tokens: [String] = []
        for token in [current, remembered] {
            if let token, !tokens.contains(token) { tokens.append(token) }
        }
        for token in tokens {
            do {
                try await unregister(token)
                if token == remembered { defaults.removeObject(forKey: key) }
            } catch {
                // Signing out must not wait on the network.
            }
        }
    }
}
