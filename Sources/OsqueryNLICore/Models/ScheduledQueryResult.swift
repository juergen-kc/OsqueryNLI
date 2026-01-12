import Foundation

/// Result of a scheduled query execution
public struct ScheduledQueryResult: Identifiable, Codable, Sendable {
    public let id: UUID
    public let scheduledQueryId: UUID
    public let timestamp: Date
    public let rowCount: Int
    public let resultSummary: String?
    public let alertTriggered: Bool
    public let sql: String?
    public let error: String?

    /// Actual result data (up to maxStoredRows)
    public let resultData: [[String: String]]?

    /// Column names in display order
    public let columns: [String]?

    /// Maximum rows to store per result
    public static let maxStoredRows = 100

    public init(
        id: UUID = UUID(),
        scheduledQueryId: UUID,
        timestamp: Date = Date(),
        rowCount: Int,
        resultSummary: String? = nil,
        alertTriggered: Bool = false,
        sql: String? = nil,
        error: String? = nil,
        resultData: [[String: String]]? = nil,
        columns: [String]? = nil
    ) {
        self.id = id
        self.scheduledQueryId = scheduledQueryId
        self.timestamp = timestamp
        self.rowCount = rowCount
        self.resultSummary = resultSummary
        self.alertTriggered = alertTriggered
        self.sql = sql
        self.error = error
        self.resultData = resultData
        self.columns = columns
    }

    /// Create a result with captured data from query results
    public static func from(
        scheduledQueryId: UUID,
        results: [[String: Any]],
        alertTriggered: Bool,
        sql: String?
    ) -> ScheduledQueryResult {
        // Extract columns from first row
        let columns: [String]? = results.first.map { Array($0.keys).sorted() }

        // Convert results to string values and limit rows
        let limitedResults = results.prefix(maxStoredRows)
        let resultData: [[String: String]] = limitedResults.map { row in
            var stringRow: [String: String] = [:]
            for (key, value) in row {
                stringRow[key] = String(describing: value)
            }
            return stringRow
        }

        // Create summary for display
        let summary = createSummary(from: results)

        return ScheduledQueryResult(
            scheduledQueryId: scheduledQueryId,
            rowCount: results.count,
            resultSummary: summary,
            alertTriggered: alertTriggered,
            sql: sql,
            resultData: resultData.isEmpty ? nil : resultData,
            columns: columns
        )
    }

    /// Create a result summary from query results (first few rows)
    public static func createSummary(from results: [[String: Any]], maxRows: Int = 3) -> String? {
        guard !results.isEmpty else { return nil }

        let preview = results.prefix(maxRows).map { row in
            row.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        }.joined(separator: "\n")

        if results.count > maxRows {
            return preview + "\n... and \(results.count - maxRows) more rows"
        }
        return preview
    }

    /// Check if this result has viewable data
    public var hasData: Bool {
        resultData != nil && !(resultData?.isEmpty ?? true)
    }
}
