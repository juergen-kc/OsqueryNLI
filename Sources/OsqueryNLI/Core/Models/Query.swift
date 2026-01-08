import Foundation

/// Represents a user query with its metadata
/// Note: Will use SwiftData @Model when building as Xcode project
struct Query: Identifiable, Codable, Hashable {
    let id: UUID
    var naturalLanguage: String
    var sql: String?
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]

    init(
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
struct QueryRequest: Sendable {
    let id: UUID
    let naturalLanguage: String
    let timestamp: Date

    init(naturalLanguage: String) {
        self.id = UUID()
        self.naturalLanguage = naturalLanguage
        self.timestamp = Date()
    }
}
