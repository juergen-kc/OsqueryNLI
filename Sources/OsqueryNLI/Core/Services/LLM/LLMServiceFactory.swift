import Foundation

/// Factory for creating and managing LLM service instances
@MainActor
final class LLMServiceFactory: ObservableObject {
    static let shared = LLMServiceFactory()

    private var services: [LLMProvider: any LLMServiceProtocol] = [:]
    private let keychainManager: KeychainManager

    private init(keychainManager: KeychainManager = .shared) {
        self.keychainManager = keychainManager
    }

    /// Get or create a service for the specified provider
    /// - Parameters:
    ///   - provider: The LLM provider
    ///   - model: Optional model override (uses provider default if nil)
    /// - Returns: An LLM service instance
    func service(for provider: LLMProvider, model: String? = nil) -> any LLMServiceProtocol {
        let modelToUse = model ?? provider.defaultModel
        let hasKeyInKeychain = keychainManager.hasAPIKey(for: provider)

        // Check if we have a cached service with the right model AND configuration state
        if let existing = services[provider], existing.model == modelToUse {
            // If keychain has a key but cached service is not configured,
            // invalidate cache and recreate (key was added after service was created)
            if hasKeyInKeychain && !existing.isConfigured {
                services[provider] = nil
            } else {
                return existing
            }
        }

        // Create new service
        let apiKey = keychainManager.getAPIKey(for: provider) ?? ""
        let service = createService(provider: provider, apiKey: apiKey, model: modelToUse)

        services[provider] = service
        return service
    }

    /// Update the API key for a provider and invalidate cached service
    /// - Parameters:
    ///   - key: The new API key
    ///   - provider: The LLM provider
    /// - Throws: KeychainError if the key cannot be saved
    func updateAPIKey(_ key: String, for provider: LLMProvider) throws {
        try keychainManager.setAPIKey(key, for: provider)
        services[provider] = nil // Force recreation with new key
    }

    /// Check if a provider is configured (has an API key)
    /// - Parameter provider: The LLM provider
    /// - Returns: True if the provider has a stored API key
    func isConfigured(_ provider: LLMProvider) -> Bool {
        keychainManager.hasAPIKey(for: provider)
    }

    /// Get the API key for a provider (for display in settings)
    /// - Parameter provider: The LLM provider
    /// - Returns: The stored API key, or empty string
    func getAPIKey(for provider: LLMProvider) -> String {
        keychainManager.getAPIKey(for: provider) ?? ""
    }

    /// Invalidate all cached services (useful when settings change)
    func invalidateAll() {
        services.removeAll()
    }

    // MARK: - Private

    private func createService(
        provider: LLMProvider,
        apiKey: String,
        model: String
    ) -> any LLMServiceProtocol {
        switch provider {
        case .claude:
            return ClaudeService(apiKey: apiKey, model: model)
        case .gemini:
            return GeminiService(apiKey: apiKey, model: model)
        case .openai:
            return OpenAIService(apiKey: apiKey, model: model)
        }
    }
}

// MARK: - Test Connection

extension LLMServiceFactory {
    /// Test if the current configuration can connect to the provider
    /// - Parameter provider: The provider to test
    /// - Returns: Success message or throws an error
    func testConnection(for provider: LLMProvider) async throws -> String {
        let service = self.service(for: provider)

        guard service.isConfigured else {
            throw LLMError.notConfigured
        }

        // Simple test: try to translate a basic query
        let result = try await service.translateToSQL(
            query: "What is the system uptime?",
            schemaContext: "CREATE TABLE uptime (days INTEGER, hours INTEGER, minutes INTEGER, seconds INTEGER, total_seconds BIGINT);"
        )

        if result.sql.isEmpty {
            throw LLMError.invalidResponse
        }

        return "Successfully connected to \(provider.displayName)"
    }
}
