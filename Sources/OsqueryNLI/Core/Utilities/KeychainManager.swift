import Foundation
import Security

/// Keychain-specific errors
enum KeychainError: LocalizedError {
    case saveFailed(provider: String, status: OSStatus)
    case deleteFailed(provider: String, status: OSStatus)
    case dataEncodingFailed
    case accessDenied
    case unknown(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let provider, let status):
            return "Failed to save API key for \(provider) (error \(status)). Check Keychain Access permissions."
        case .deleteFailed(let provider, let status):
            return "Failed to delete API key for \(provider) (error \(status))."
        case .dataEncodingFailed:
            return "Failed to encode API key data."
        case .accessDenied:
            return "Keychain access denied. Please check app permissions in System Preferences > Security & Privacy."
        case .unknown(let status):
            return "Keychain error: \(status)"
        }
    }

    static func from(status: OSStatus, provider: String, operation: String) -> KeychainError {
        switch status {
        case errSecAuthFailed, errSecInteractionNotAllowed:
            return .accessDenied
        default:
            if operation == "save" {
                return .saveFailed(provider: provider, status: status)
            } else {
                return .deleteFailed(provider: provider, status: status)
            }
        }
    }
}

/// Manages secure storage of API keys in the macOS Keychain
final class KeychainManager: Sendable {
    static let shared = KeychainManager()

    private let service = "com.osquerynli.apikeys"

    private init() {}

    /// Store an API key for a provider
    /// - Parameters:
    ///   - key: The API key to store
    ///   - provider: The LLM provider
    /// - Throws: KeychainError if storage fails
    func setAPIKey(_ key: String, for provider: LLMProvider) throws {
        let account = provider.rawValue

        // Delete existing key first (ignore errors - key might not exist)
        try? deleteAPIKey(for: provider)

        // Empty key means "remove"
        guard !key.isEmpty else { return }

        guard let data = key.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw KeychainError.from(status: status, provider: provider.displayName, operation: "save")
        }
    }

    /// Retrieve an API key for a provider
    /// - Parameter provider: The LLM provider
    /// - Returns: The stored API key, or nil if not found
    func getAPIKey(for provider: LLMProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key for a provider
    /// - Parameter provider: The LLM provider
    /// - Throws: KeychainError if deletion fails (except for "not found")
    func deleteAPIKey(for provider: LLMProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound is OK - key didn't exist
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.from(status: status, provider: provider.displayName, operation: "delete")
        }
    }

    /// Check if an API key exists for a provider
    /// - Parameter provider: The LLM provider
    /// - Returns: True if a key is stored
    func hasAPIKey(for provider: LLMProvider) -> Bool {
        getAPIKey(for: provider) != nil
    }
}
