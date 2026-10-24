import Foundation
import Security

/// Secure storage for the Convex Auth refresh token.
///
/// The short-lived JWT lives only in memory, held by `ConvexClientWithAuth`; the
/// long-lived refresh token is persisted here so the app can silently
/// re-authenticate on relaunch. (PocketBase kept this in `UserDefaults`.)
struct KeychainTokenStore: Sendable {
    private let service = "com.nestzone.convexauth"
    private let account = "refreshToken"

    var refreshToken: String? {
        get {
            if case let .present(token) = lookup() { return token }
            return nil
        }
        nonmutating set { newValue.map(write) ?? delete() }
    }

    /// What the Keychain answered, which is not always "a token or none".
    /// A read can fail for a reason that says nothing about the session: the
    /// device has not been unlocked since it started, or the Keychain is busy.
    /// `refreshToken` folds that into nil, which is right for a caller that
    /// only wants a token to use; a caller about to decide that the session is
    /// over must ask this instead.
    enum Lookup: Equatable {
        case present(String)
        /// The Keychain answered and there is nothing stored.
        case absent
        /// The Keychain could not be read just now.
        case unreadable
    }

    func lookup() -> Lookup {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let token = String(data: data, encoding: .utf8)
            else { return .absent }
            return .present(token)
        case errSecItemNotFound:
            return .absent
        default:
            return .unreadable
        }
    }

    /// The launch's one question, asked off the main thread. A Keychain read
    /// is an IPC to `securityd`, and `beginOptimisticLaunch` has to answer inside
    /// a reducer. `LaunchWarmup` asks here while the store is still being built
    /// (about 140 ms), so the reducer finds the answer waiting; if it is
    /// somehow not there yet, it reads for itself, which is where it started.
    private static let primed = PrimedLookup()

    static func primeLaunchLookup() {
        Task.detached(priority: .userInitiated) {
            primed.set(KeychainTokenStore().lookup())
        }
    }

    /// The primed answer, or a fresh read if it has not landed. Only for the
    /// launch decision: a restore always reads the Keychain itself.
    static func launchLookup() -> Lookup {
        primed.value ?? KeychainTokenStore().lookup()
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func write(_ value: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(
            baseQuery() as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var insert = baseQuery()
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}

private final class PrimedLookup: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: KeychainTokenStore.Lookup?
    var value: KeychainTokenStore.Lookup? { lock.withLock { _value } }
    func set(_ value: KeychainTokenStore.Lookup) { lock.withLock { _value = value } }
}
