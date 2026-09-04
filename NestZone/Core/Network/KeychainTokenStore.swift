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
        get { read() }
        nonmutating set { newValue.map(write) ?? delete() }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else { return nil }
        return token
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
