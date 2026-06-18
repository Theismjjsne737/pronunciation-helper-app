import Foundation
import Security

/// Thin wrapper around the iOS Keychain for secure API key storage.
enum KeychainService {

    private static let service = "com.lingolab.coach"

    enum Key: String {
        case anthropicAPIKey = "anthropic_api_key"
        case appleUserID     = "apple_user_id"
        case appleFullName   = "apple_full_name"
    }

    // MARK: - Read

    static func read(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    // MARK: - Write

    @discardableResult
    static func write(_ value: String, for key: Key) -> Bool {
        let data = Data(value.utf8)
        // Try update first
        let updateQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Insert
            var addQuery = updateQuery
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience

    static var anthropicAPIKey: String? {
        get { read(.anthropicAPIKey) }
        set {
            if let v = newValue, !v.isEmpty { write(v, for: .anthropicAPIKey) }
            else { delete(.anthropicAPIKey) }
        }
    }
}
