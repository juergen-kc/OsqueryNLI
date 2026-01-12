import Foundation

/// A saved favorite query
public struct FavoriteQuery: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var query: String
    public var name: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), query: String, name: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.query = query
        self.name = name
        self.createdAt = createdAt
    }

    /// Display name - uses custom name or truncated query
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        // Truncate long queries
        if query.count > 50 {
            return String(query.prefix(47)) + "..."
        }
        return query
    }
}
