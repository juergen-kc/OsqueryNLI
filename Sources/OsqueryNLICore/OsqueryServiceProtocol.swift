import Foundation

/// Protocol for osquery operations
public protocol OsqueryServiceProtocol: Sendable {
    /// Execute an osquery SQL statement
    /// - Parameter sql: SQL query to execute
    /// - Returns: Array of result rows as dictionaries
    func execute(_ sql: String) async throws -> [[String: Any]]

    /// Get all available tables
    /// - Returns: List of table names
    func getAllTables() async throws -> [String]

    /// Get schema for specific tables
    /// - Parameter tables: Table names to get schema for
    /// - Returns: Schema description string
    func getSchema(for tables: [String]) async throws -> String

    /// Check if osqueryi is available on the system
    /// - Returns: True if osqueryi is found and accessible
    func isAvailable() async -> Bool
}

/// Errors specific to osquery operations
public enum OsqueryError: LocalizedError, Sendable {
    case notInstalled
    case executionFailed(stderr: String)
    case invalidSQL(details: String)
    case parseError(details: String)
    case timeout
    case processError(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "osqueryi not found. Please install osquery (e.g., brew install osquery)."
        case .executionFailed(let stderr):
            return "Query failed: \(stderr)"
        case .invalidSQL(let details):
            return "Invalid SQL: \(details)"
        case .parseError(let details):
            return "Failed to parse osquery output: \(details)"
        case .timeout:
            return "Query timed out."
        case .processError(let error):
            return "Process error: \(error)"
        }
    }
}
