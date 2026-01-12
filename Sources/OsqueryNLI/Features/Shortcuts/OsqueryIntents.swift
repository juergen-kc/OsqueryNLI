import AppIntents
import Foundation

// MARK: - Run Natural Language Query Intent

/// Shortcut action to run a natural language query against osquery
struct RunNLQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Natural Language Query"
    static let description = IntentDescription("Ask a question about your Mac in plain English and get results from osquery")

    @Parameter(title: "Question", description: "Ask a question about your Mac (e.g., 'What apps are running?' or 'Show my network connections')")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask osquery: \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Check if LLM is configured
        guard appState.currentLLMService.isConfigured else {
            throw IntentError.notConfigured
        }

        // Get schema context
        let schemaContext = try await appState.osqueryService.getSchema(for: Array(appState.enabledTables))

        // Translate to SQL
        let translation = try await appState.currentLLMService.translateToSQL(
            query: question,
            schemaContext: schemaContext
        )

        // Execute the query
        let results = try await appState.osqueryService.execute(translation.sql)

        // Limit results for Shortcuts (large results can cause issues)
        let maxRows = 500
        if results.count > maxRows {
            throw IntentError.resultTooLarge(results.count)
        }

        // Format result as JSON
        let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        // Log to history (log the natural language question)
        appState.logQueryToHistory(
            query: question,
            rowCount: results.count,
            source: "shortcut"
        )

        return .result(
            value: jsonString,
            dialog: "Found \(results.count) result\(results.count == 1 ? "" : "s") for: \(question)"
        )
    }
}

// MARK: - Run Raw SQL Query Intent

/// Shortcut action to run a raw SQL query against osquery
struct RunSQLQueryIntent: AppIntent {
    static let title: LocalizedStringResource = "Run SQL Query"
    static let description = IntentDescription("Execute a raw osquery SQL query directly")

    @Parameter(title: "SQL Query", description: "The SQL query to execute (e.g., 'SELECT * FROM processes LIMIT 10')")
    var sql: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run SQL: \(\.$sql)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Execute the query
        let results = try await appState.osqueryService.execute(sql)

        // Limit results for Shortcuts (large results can cause issues)
        let maxRows = 500
        if results.count > maxRows {
            throw IntentError.resultTooLarge(results.count)
        }

        // Format result as JSON
        let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        // Log to history
        appState.logQueryToHistory(
            query: sql,
            rowCount: results.count,
            source: "shortcut"
        )

        return .result(
            value: jsonString,
            dialog: "Query returned \(results.count) row\(results.count == 1 ? "" : "s")"
        )
    }
}

// MARK: - Get Query History Intent

/// Shortcut action to get recent query history
struct GetQueryHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Query History"
    static let description = IntentDescription("Get recent queries executed in Osquery NLI")

    @Parameter(title: "Limit", description: "Maximum number of queries to return", default: 10)
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Get last \(\.$limit) queries")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Clamp limit to valid range
        let safeLimit = max(1, min(limit, 100))

        // Get history entries
        let history = Array(appState.queryHistory.prefix(safeLimit))

        // Convert to JSON-friendly format
        let dateFormatter = ISO8601DateFormatter()
        let historyData: [[String: Any]] = history.map { entry in
            var dict: [String: Any] = [
                "timestamp": dateFormatter.string(from: entry.timestamp),
                "source": entry.source.rawValue,
                "query": entry.query
            ]
            if let rowCount = entry.rowCount {
                dict["rowCount"] = rowCount
            }
            return dict
        }

        let jsonData = try JSONSerialization.data(withJSONObject: historyData, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        return .result(
            value: jsonString,
            dialog: "Retrieved \(history.count) recent quer\(history.count == 1 ? "y" : "ies")"
        )
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case appNotRunning
    case notConfigured
    case resultTooLarge(Int)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appNotRunning:
            return "Osquery NLI is not running. Please open the app first."
        case .notConfigured:
            return "No AI provider configured. Please open Osquery NLI and set up an API key in Settings."
        case .resultTooLarge(let count):
            return "Query returned \(count) rows, which is too large for Shortcuts. Try adding a LIMIT clause to your query."
        }
    }
}

// MARK: - App Shortcuts Provider

/// Provides pre-configured shortcuts for discovery in the Shortcuts app
struct OsqueryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunNLQueryIntent(),
            phrases: [
                "Ask \(.applicationName) about my Mac",
                "Query \(.applicationName)",
                "Run a query in \(.applicationName)"
            ],
            shortTitle: "Ask Osquery",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: RunSQLQueryIntent(),
            phrases: [
                "Run SQL in \(.applicationName)",
                "Execute SQL query in \(.applicationName)"
            ],
            shortTitle: "Run SQL",
            systemImageName: "terminal"
        )

        AppShortcut(
            intent: GetQueryHistoryIntent(),
            phrases: [
                "Show \(.applicationName) history",
                "Get query history from \(.applicationName)"
            ],
            shortTitle: "Query History",
            systemImageName: "clock"
        )
    }
}
