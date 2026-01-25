import Foundation

/// Shared constants used across OsqueryNLI targets
public enum AppConstants {
    /// Keychain service identifier for storing API keys
    public static let keychainService = "com.osquerynli.apikeys"
}

/// UserDefaults keys for app settings persistence
public enum UserDefaultsKeys {
    // MARK: - LLM Settings
    public static let selectedProvider = "selectedProvider"
    public static let selectedModel = "selectedModel"

    // MARK: - Table Settings
    public static let enabledTables = "enabledTables"
    public static let aiDiscoveryEnabled = "aiDiscoveryEnabled"

    // MARK: - UI Settings
    public static let fontScale = "fontScale"

    // MARK: - Scheduler Settings
    public static let schedulerEnabled = "schedulerEnabled"
    public static let notificationsEnabled = "notificationsEnabled"

    // MARK: - MCP Server Settings
    public static let mcpServerEnabled = "mcpServerEnabled"
    public static let mcpAutoStart = "mcpAutoStart"

    // MARK: - Data Storage
    public static let favorites = "favorites"
    public static let recentExports = "recentExports"
}
