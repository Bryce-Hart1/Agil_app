import Foundation
import Security

// Claude  Date 06/18/2026
// Tiny Keychain wrapper for a handful of secret strings. The app stores almost
// everything as plain JSON in Documents (see PersistenceService), which is the
// wrong place for the card-sync secret key — Documents lands in device backups.
// The secret lives here instead so it never leaves the device and isn't sitting
// in a readable file. Generic-password items, scoped by a service string.
//
// Deliberately minimal (get/set/delete a String): we only keep one secret today.
struct KeychainStore {
    static let standard = KeychainStore()

    // Namespacing for our items; matches the app's bundle id.
    private let service = "com.brycehart.gymapp"

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    // Upsert: delete any existing item for this key, then add the new value.
    func set(_ value: String, for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
        var add = baseQuery(key)
        add[kSecValueData as String] = Data(value.utf8)
        // Available after first unlock so a background sync can still read it.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    func get(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    func delete(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}
