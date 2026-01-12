import Foundation

/// Persistent storage for scheduled query results
/// Note: @unchecked Sendable is safe because all mutable state is protected by `lock`
final class ScheduledQueryResultStore: @unchecked Sendable {
    static let shared = ScheduledQueryResultStore()

    private let dataDirectory: URL
    private let maxResultsPerQuery = 100
    private let lock = NSLock()

    private var resultsFileURL: URL {
        dataDirectory.appendingPathComponent("scheduled_results.json")
    }

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        dataDirectory = appSupport.appendingPathComponent("OsqueryNLI")

        // Create directory synchronously on init
        ensureDirectoryExists()
    }

    /// Ensure the data directory exists
    private func ensureDirectoryExists() {
        do {
            if !FileManager.default.fileExists(atPath: dataDirectory.path) {
                try FileManager.default.createDirectory(
                    at: dataDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("[ScheduledQueryResultStore] Created data directory: \(dataDirectory.path)")
            }
        } catch {
            print("[ScheduledQueryResultStore] Failed to create directory: \(error)")
        }
    }

    /// Save a new result
    func saveResult(_ result: ScheduledQueryResult) {
        lock.withLock {
            print("[ScheduledQueryResultStore] saveResult called for query \(result.scheduledQueryId), rows: \(result.rowCount)")

            // Ensure directory exists before saving
            ensureDirectoryExists()

            var allResults = loadAllResultsUnsafe()
            allResults.append(result)

            // Trim results per query to max limit
            allResults = trimResults(allResults)

            saveAllResultsUnsafe(allResults)
        }
    }

    /// Get results for a specific query
    func getResults(for queryId: UUID, limit: Int = 20) -> [ScheduledQueryResult] {
        lock.withLock {
            let allResults = loadAllResultsUnsafe()
            print("[ScheduledQueryResultStore] getResults for \(queryId): found \(allResults.count) total results")
            let filtered = allResults.filter { $0.scheduledQueryId == queryId }
            print("[ScheduledQueryResultStore] getResults for \(queryId): \(filtered.count) matching results")
            return filtered
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
                .map { $0 }
        }
    }

    /// Get most recent result for a query
    func getLatestResult(for queryId: UUID) -> ScheduledQueryResult? {
        getResults(for: queryId, limit: 1).first
    }

    /// Clear all results for a query
    func clearResults(for queryId: UUID) {
        lock.withLock {
            var allResults = loadAllResultsUnsafe()
            allResults.removeAll { $0.scheduledQueryId == queryId }
            saveAllResultsUnsafe(allResults)
        }
    }

    /// Clear all results
    func clearAllResults() {
        lock.withLock {
            saveAllResultsUnsafe([])
        }
    }

    // MARK: - Private (must be called with lock held)

    private func loadAllResultsUnsafe() -> [ScheduledQueryResult] {
        let path = resultsFileURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            print("[ScheduledQueryResultStore] No results file exists at \(path)")
            return []
        }

        do {
            let data = try Data(contentsOf: resultsFileURL)
            print("[ScheduledQueryResultStore] Loaded \(data.count) bytes from \(path)")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let results = try decoder.decode([ScheduledQueryResult].self, from: data)
            print("[ScheduledQueryResultStore] Decoded \(results.count) results")
            return results
        } catch {
            print("[ScheduledQueryResultStore] Failed to load scheduled results: \(error)")
            return []
        }
    }

    private func saveAllResultsUnsafe(_ results: [ScheduledQueryResult]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(results)
            print("[ScheduledQueryResultStore] Encoding \(results.count) results (\(data.count) bytes)")
            try data.write(to: resultsFileURL, options: .atomic)
            print("[ScheduledQueryResultStore] Saved to \(resultsFileURL.path)")

            // Verify the write
            if FileManager.default.fileExists(atPath: resultsFileURL.path) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: resultsFileURL.path)
                let size = attrs?[.size] as? Int ?? 0
                print("[ScheduledQueryResultStore] Verified file exists, size: \(size) bytes")
            } else {
                print("[ScheduledQueryResultStore] WARNING: File does not exist after save!")
            }
        } catch {
            print("[ScheduledQueryResultStore] Failed to save scheduled results: \(error)")
        }
    }

    private func trimResults(_ results: [ScheduledQueryResult]) -> [ScheduledQueryResult] {
        // Group by query ID
        var grouped: [UUID: [ScheduledQueryResult]] = [:]
        for result in results {
            grouped[result.scheduledQueryId, default: []].append(result)
        }

        // Keep only the most recent maxResultsPerQuery for each query
        var trimmed: [ScheduledQueryResult] = []
        for (_, queryResults) in grouped {
            let sorted = queryResults.sorted { $0.timestamp > $1.timestamp }
            trimmed.append(contentsOf: sorted.prefix(maxResultsPerQuery))
        }

        return trimmed
    }
}
