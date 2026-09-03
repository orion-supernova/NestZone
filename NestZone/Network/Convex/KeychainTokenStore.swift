//
//  KeychainTokenStore.swift
//  NestZone
//
//  Secure storage for the Convex Auth refresh token. The short-lived JWT lives
//  only in memory (held by ConvexClientWithAuth); the long-lived refresh token is
//  persisted here so the app can silently re-authenticate on relaunch.
//
//  This replaces PocketBase's UserDefaults token storage with the Keychain.
//

import Foundation
import Security

struct KeychainTokenStore {
    private let service = "com.nestzone.convexauth"
    private let account = "refreshToken"

    /// The cached Convex Auth refresh token, or nil if not signed in.
    var refreshToken: String? {
        get { read() }
        nonmutating set {
            if let value = newValue { write(value) } else { delete() }
        }
    }

    // MARK: - Keychain primitives

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
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private func write(_ value: String) {
        let data = Data(value.utf8)
        // Try update first; insert if missing.
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery() as CFDictionary, attrs as CFDictionary)
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
