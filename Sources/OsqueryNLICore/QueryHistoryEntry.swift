import Foundation

/// Source of a query execution
public enum QuerySource: String, Codable, Sendable {
    case app = "app"    // Query from the main OsqueryNLI app
    case mcp = "mcp"    // Query from MCP server (IDE integration)
}

/// A single query history entry
public struct QueryHistoryEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let query: String           // SQL query or natural language
    public let timestamp: Date
    public let source: QuerySource
    public let rowCount: Int?          // Optional result count

    public init(
        id: UUID = UUID(),
        query: String,
        timestamp: Date = Date(),
        source: QuerySource,
        rowCount: Int? = nil
    ) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.source = source
        self.rowCount = rowCount
    }
}
