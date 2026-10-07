import CryptoKit
import Foundation
import Security

public enum KeychainError: Error { case unexpectedStatus(OSStatus) }

/// Stores the note-encryption key in the Keychain.
///
/// `synchronizable = true` uses iCloud Keychain, so the same key is available on
/// the user's other devices and synced ciphertext can be decrypted there.
public struct KeychainKeyStore {
    private let service: String
    private let account: String
    private let synchronizable: Bool

    public init(service: String = "com.example.accessiblenotes", account: String = "note-key", synchronizable: Bool = true) {
        self.service = service
        self.account = account
        self.synchronizable = synchronizable
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any,
        ]
    }

    /// Returns the existing key, creating and persisting one on first use.
    public func loadOrCreateKey() throws -> SymmetricKey {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }

        let key = NoteCrypto.generateKey()
        var add = baseQuery
        add[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        return key
    }
}
