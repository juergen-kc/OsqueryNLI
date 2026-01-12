import Foundation

/// Represents the result of executing an osquery SQL query
public struct QueryResult: Identifiable, Sendable {
    public let id: UUID
    public let sql: String
    public let rows: [[String: String]]
    public let columns: [ColumnInfo]
    public let executionTime: TimeInterval
    public let summary: String?
    public let timestamp: Date
    public let tokenUsage: TokenUsage?

    public var isEmpty: Bool { rows.isEmpty }
    public var rowCount: Int { rows.count }

    public struct ColumnInfo: Identifiable, Sendable, Hashable {
        public let id: UUID
        public let name: String
        public let type: ColumnType

        public init(id: UUID = UUID(), name: String, type: ColumnType = .string) {
            self.id = id
            self.name = name
            self.type = type
        }
    }

    public enum ColumnType: Sendable {
        case string
        case number
        case boolean
        case unknown
    }

    public init(
        id: UUID = UUID(),
        sql: String,
        rows: [[String: String]],
        columns: [ColumnInfo]? = nil,
        executionTime: TimeInterval = 0,
        summary: String? = nil,
        timestamp: Date = Date(),
        tokenUsage: TokenUsage? = nil
    ) {
        self.id = id
        self.sql = sql
        self.rows = rows
        self.executionTime = executionTime
        self.summary = summary
        self.timestamp = timestamp
        self.tokenUsage = tokenUsage

        // Infer columns from first row if not provided
        if let columns {
            self.columns = columns
        } else if let firstRow = rows.first {
            self.columns = firstRow.keys.sorted().map { ColumnInfo(name: $0) }
        } else {
            self.columns = []
        }
    }
}

// MARK: - Export Support

extension QueryResult {
    /// Export to CSV format
    public func toCSV() -> String {
        guard !columns.isEmpty else { return "" }

        var csv = columns.map(\.name).joined(separator: ",") + "\n"

        for row in rows {
            let values = columns.map { col in
                let value = row[col.name] ?? ""
                // Escape quotes and wrap in quotes if contains comma or quotes
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return value
            }
            csv += values.joined(separator: ",") + "\n"
        }

        return csv
    }

    /// Export to JSON format
    public func toJSON(prettyPrinted: Bool = true) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : .sortedKeys

        // Convert [[String: String]] to [[String: Any]] for JSONSerialization
        let jsonObject: [[String: Any]] = rows.map { $0 }

        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: options),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return jsonString
    }

    /// Export as formatted text table
    public func toTextTable() -> String {
        guard !columns.isEmpty, !rows.isEmpty else { return "No results" }

        // Calculate column widths
        var widths: [String: Int] = [:]
        for col in columns {
            widths[col.name] = col.name.count
        }
        for row in rows {
            for col in columns {
                let value = row[col.name] ?? ""
                widths[col.name] = max(widths[col.name] ?? 0, value.count)
            }
        }

        // Build table
        var output = ""

        // Header
        let header = columns.map { col in
            col.name.padding(toLength: widths[col.name] ?? col.name.count, withPad: " ", startingAt: 0)
        }.joined(separator: " | ")
        output += header + "\n"

        // Separator
        let separator = columns.map { col in
            String(repeating: "-", count: widths[col.name] ?? col.name.count)
        }.joined(separator: "-+-")
        output += separator + "\n"

        // Rows
        for row in rows {
            let rowStr = columns.map { col in
                let value = row[col.name] ?? ""
                return value.padding(toLength: widths[col.name] ?? value.count, withPad: " ", startingAt: 0)
            }.joined(separator: " | ")
            output += rowStr + "\n"
        }

        return output
    }

    /// Export as Markdown table
    public func toMarkdown() -> String {
        guard !columns.isEmpty else { return "*No results*" }

        var md = ""

        // Optional: Add metadata header
        md += "# Query Results\n\n"
        md += "**SQL:**\n```sql\n\(sql)\n```\n\n"
        if let summary = summary {
            md += "**Summary:** \(summary)\n\n"
        }
        md += "**Rows:** \(rowCount) | **Executed:** \(ISO8601DateFormatter().string(from: timestamp))\n\n"

        // Table header
        md += "| " + columns.map(\.name).joined(separator: " | ") + " |\n"

        // Alignment row
        md += "| " + columns.map { _ in "---" }.joined(separator: " | ") + " |\n"

        // Data rows
        for row in rows {
            let values = columns.map { col in
                let value = row[col.name] ?? ""
                // Escape pipe characters in values
                return value.replacingOccurrences(of: "|", with: "\\|")
            }
            md += "| " + values.joined(separator: " | ") + " |\n"
        }

        return md
    }
}

// MARK: - Builder for creating from osquery output

extension QueryResult {
    /// Create QueryResult from osquery JSON output
    public static func from(
        sql: String,
        osqueryOutput: [[String: Any]],
        executionTime: TimeInterval = 0,
        summary: String? = nil,
        tokenUsage: TokenUsage? = nil
    ) -> QueryResult {
        // Convert Any values to String
        let stringRows: [[String: String]] = osqueryOutput.map { row in
            var stringRow: [String: String] = [:]
            for (key, value) in row {
                stringRow[key] = String(describing: value)
            }
            return stringRow
        }

        return QueryResult(
            sql: sql,
            rows: stringRows,
            executionTime: executionTime,
            summary: summary,
            tokenUsage: tokenUsage
        )
    }
}
