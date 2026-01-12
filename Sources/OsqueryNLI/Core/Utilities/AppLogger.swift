import Foundation
import OSLog

/// Centralized logging for OsqueryNLI using OSLog
/// Use these loggers instead of print() for proper log management
enum AppLogger {
    /// Logger for scheduled query operations
    static let scheduler = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "Scheduler")

    /// Logger for notification operations
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "Notifications")

    /// Logger for app state and persistence
    static let appState = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "AppState")

    /// Logger for query history operations
    static let history = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "History")

    /// Logger for LLM service operations
    static let llm = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "LLM")

    /// Logger for osquery operations
    static let osquery = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.klaassen.OsqueryNLI", category: "Osquery")
}
