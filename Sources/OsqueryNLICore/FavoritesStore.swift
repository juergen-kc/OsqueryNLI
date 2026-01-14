import Foundation
import OSLog

/// Shared store for favorite queries, accessible by both the main app and MCP server
public final class FavoritesStore: Sendable {
    public static let shared = FavoritesStore()

    private let logger = Logger(subsystem: "com.klaassen.OsqueryNLI", category: "Favorites")

    /// The directory for storing favorites
    private let storeDirectory: URL

    /// The path to the favorites JSON file
    private var favoritesFileURL: URL {
        storeDirectory.appendingPathComponent("favorites.json")
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storeDirectory = appSupport.appendingPathComponent("OsqueryNLI", isDirectory: true)
        // Ensure directory exists with owner-only permissions (0700)
        try? FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    /// Initialize with a custom directory (for testing)
    /// - Parameter directory: Custom directory URL for storing favorites
    public init(directory: URL) {
        self.storeDirectory = directory
        try? FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    // MARK: - Read Operations

    /// Read all favorites from the store
    /// - Returns: Array of favorites, sorted by creation date (newest first)
    public func readFavorites() -> [FavoriteQuery] {
        guard FileManager.default.fileExists(atPath: favoritesFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: favoritesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let favorites = try decoder.decode([FavoriteQuery].self, from: data)
            return favorites.sorted { $0.createdAt > $1.createdAt }
        } catch {
            logger.error("Failed to read favorites: \(error.localizedDescription)")
            return []
        }
    }

    /// Find a favorite by name (case-insensitive partial match)
    /// - Parameter name: The name to search for
    /// - Returns: The first matching favorite, or nil
    public func findFavorite(byName name: String) -> FavoriteQuery? {
        let searchName = name.lowercased()
        return readFavorites().first { favorite in
            favorite.displayName.lowercased().contains(searchName) ||
            (favorite.name?.lowercased().contains(searchName) ?? false)
        }
    }

    /// Find a favorite by ID
    /// - Parameter id: The UUID of the favorite
    /// - Returns: The matching favorite, or nil
    public func findFavorite(byId id: UUID) -> FavoriteQuery? {
        readFavorites().first { $0.id == id }
    }

    /// Check if a query is already in favorites
    /// - Parameter query: The query string to check
    /// - Returns: True if the query exists in favorites
    public func contains(query: String) -> Bool {
        readFavorites().contains { $0.query == query }
    }

    // MARK: - Write Operations

    /// Add a new favorite
    /// - Parameters:
    ///   - query: The query string
    ///   - name: Optional display name
    /// - Returns: The created favorite, or nil if query already exists
    @discardableResult
    public func addFavorite(query: String, name: String? = nil) -> FavoriteQuery? {
        var favorites = readFavorites()

        // Don't add duplicates
        guard !favorites.contains(where: { $0.query == query }) else {
            return nil
        }

        let favorite = FavoriteQuery(query: query, name: name)
        favorites.insert(favorite, at: 0)
        writeFavorites(favorites)
        return favorite
    }

    /// Add or update a favorite
    /// - Parameter favorite: The favorite to save
    public func saveFavorite(_ favorite: FavoriteQuery) {
        var favorites = readFavorites()

        if let index = favorites.firstIndex(where: { $0.id == favorite.id }) {
            favorites[index] = favorite
        } else if !favorites.contains(where: { $0.query == favorite.query }) {
            favorites.insert(favorite, at: 0)
        } else {
            return // Query already exists with different ID
        }

        writeFavorites(favorites)
    }

    /// Remove a favorite by ID
    /// - Parameter id: The UUID of the favorite to remove
    public func removeFavorite(id: UUID) {
        var favorites = readFavorites()
        favorites.removeAll { $0.id == id }
        writeFavorites(favorites)
    }

    /// Update the name of a favorite
    /// - Parameters:
    ///   - id: The UUID of the favorite
    ///   - name: The new name (nil to remove name)
    public func updateFavoriteName(id: UUID, name: String?) {
        var favorites = readFavorites()
        if let index = favorites.firstIndex(where: { $0.id == id }) {
            var updated = favorites[index]
            updated = FavoriteQuery(
                id: updated.id,
                query: updated.query,
                name: name,
                createdAt: updated.createdAt
            )
            favorites[index] = updated
            writeFavorites(favorites)
        }
    }

    /// Clear all favorites
    public func clearFavorites() {
        try? FileManager.default.removeItem(at: favoritesFileURL)
    }

    /// Reorder favorites by moving items
    /// - Parameters:
    ///   - fromOffsets: Source indices
    ///   - toOffset: Destination index
    public func moveFavorites(fromOffsets: IndexSet, toOffset: Int) {
        var favorites = readFavorites()
        // Implement move manually since Array.move(fromOffsets:toOffset:) requires SwiftUI
        let itemsToMove = fromOffsets.map { favorites[$0] }
        for offset in fromOffsets.reversed() {
            favorites.remove(at: offset)
        }
        let insertionIndex = toOffset > fromOffsets.first! ? toOffset - fromOffsets.count : toOffset
        favorites.insert(contentsOf: itemsToMove, at: insertionIndex)
        writeFavorites(favorites)
    }

    /// Replace all favorites (used for bulk updates/sync)
    /// - Parameter favorites: The new favorites array
    public func replaceFavorites(_ favorites: [FavoriteQuery]) {
        writeFavorites(favorites)
    }

    // MARK: - Private

    private func writeFavorites(_ favorites: [FavoriteQuery]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(favorites)
            try data.write(to: favoritesFileURL, options: .atomic)
        } catch {
            logger.error("Failed to write favorites: \(error.localizedDescription)")
        }
    }
}
