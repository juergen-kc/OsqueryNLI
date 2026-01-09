import Foundation

/// Utility for logging query history to a shared file accessible by both the main app and MCP server
public final class QueryHistoryLogger: Sendable {
    public static let shared = QueryHistoryLogger()

    /// Maximum number of entries to keep in history
    public let maxEntries: Int

    /// The directory for storing history files
    private let historyDirectory: URL

    /// The path to the history JSON file
    private var historyFileURL: URL {
        historyDirectory.appendingPathComponent("query_history.json")
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.historyDirectory = appSupport.appendingPathComponent("OsqueryNLI", isDirectory: true)
        self.maxEntries = 100
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    }

    /// Initialize with a custom directory (for testing)
    /// - Parameters:
    ///   - directory: Custom directory URL for storing history
    ///   - maxEntries: Maximum number of entries to keep (default 100)
    public init(directory: URL, maxEntries: Int = 100) {
        self.historyDirectory = directory
        self.maxEntries = maxEntries
        try? FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    }

    /// Log a query execution
    /// - Parameters:
    ///   - query: The SQL query that was executed
    ///   - source: Where the query originated from (app or mcp)
    ///   - rowCount: Optional number of rows returned
    public func logQuery(query: String, source: QuerySource, rowCount: Int? = nil) {
        let entry = QueryHistoryEntry(
            query: query,
            source: source,
            rowCount: rowCount
        )

        var entries = readEntries()
        entries.insert(entry, at: 0)

        // Keep only the most recent entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        writeEntries(entries)
    }

    /// Read all history entries from the file
    /// - Returns: Array of history entries, sorted by timestamp (most recent first)
    public func readEntries() -> [QueryHistoryEntry] {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let entries = try decoder.decode([QueryHistoryEntry].self, from: data)
            return entries.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to read history entries: \(error)")
            return []
        }
    }

    /// Read entries filtered by source
    /// - Parameter source: Filter by app or mcp source
    /// - Returns: Filtered array of history entries
    public func readEntries(source: QuerySource) -> [QueryHistoryEntry] {
        readEntries().filter { $0.source == source }
    }

    /// Clear all history entries
    public func clearEntries() {
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    /// Clear entries from a specific source
    /// - Parameter source: The source to clear (app or mcp)
    public func clearEntries(source: QuerySource) {
        var entries = readEntries()
        entries.removeAll { $0.source == source }
        writeEntries(entries)
    }

    /// Remove a specific entry by ID
    /// - Parameter id: The UUID of the entry to remove
    public func removeEntry(id: UUID) {
        var entries = readEntries()
        entries.removeAll { $0.id == id }
        writeEntries(entries)
    }

    /// Get the timestamp of the most recent entry
    /// - Returns: The timestamp or nil if no entries exist
    public func lastEntryTimestamp() -> Date? {
        readEntries().first?.timestamp
    }

    // MARK: - Private

    private func writeEntries(_ entries: [QueryHistoryEntry]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to write history entries: \(error)")
        }
    }
}
