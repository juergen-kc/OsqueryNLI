import Foundation

/// Represents a user query with its metadata
public struct Query: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var naturalLanguage: String
    public var sql: String?
    public var timestamp: Date
    public var isFavorite: Bool
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        naturalLanguage: String,
        sql: String? = nil,
        timestamp: Date = Date(),
        isFavorite: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.naturalLanguage = naturalLanguage
        self.sql = sql
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.tags = tags
    }
}

/// Non-persisted query for in-flight operations
public struct QueryRequest: Sendable {
    public let id: UUID
    public let naturalLanguage: String
    public let timestamp: Date

    public init(naturalLanguage: String) {
        self.id = UUID()
        self.naturalLanguage = naturalLanguage
        self.timestamp = Date()
    }
}
