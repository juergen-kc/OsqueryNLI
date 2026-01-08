import Foundation

/// A saved favorite query
struct FavoriteQuery: Identifiable, Codable, Equatable {
    let id: UUID
    var query: String
    var name: String?
    let createdAt: Date

    init(query: String, name: String? = nil) {
        self.id = UUID()
        self.query = query
        self.name = name
        self.createdAt = Date()
    }

    /// Display name - uses custom name or truncated query
    var displayName: String {
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
