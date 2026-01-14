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

// MARK: - Get System Info Intent

/// Shortcut action to get key system information
struct GetSystemInfoIntent: AppIntent {
    static let title: LocalizedStringResource = "Get System Info"
    static let description = IntentDescription("Get key information about your Mac including uptime, OS version, and hostname")

    static var parameterSummary: some ParameterSummary {
        Summary("Get system information")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Query multiple system tables
        var systemInfo: [String: Any] = [:]

        // Get OS version
        if let osResults = try? await appState.osqueryService.execute("SELECT * FROM os_version"),
           let os = osResults.first {
            systemInfo["os_name"] = os["name"] ?? "Unknown"
            systemInfo["os_version"] = os["version"] ?? "Unknown"
            systemInfo["os_build"] = os["build"] ?? "Unknown"
        }

        // Get uptime
        if let uptimeResults = try? await appState.osqueryService.execute("SELECT * FROM uptime"),
           let uptime = uptimeResults.first {
            let days = uptime["days"] ?? "0"
            let hours = uptime["hours"] ?? "0"
            let minutes = uptime["minutes"] ?? "0"
            systemInfo["uptime"] = "\(days)d \(hours)h \(minutes)m"
        }

        // Get hostname
        if let hostResults = try? await appState.osqueryService.execute("SELECT hostname, computer_name FROM system_info"),
           let host = hostResults.first {
            systemInfo["hostname"] = host["hostname"] ?? "Unknown"
            systemInfo["computer_name"] = host["computer_name"] ?? "Unknown"
        }

        // Get hardware info
        if let hwResults = try? await appState.osqueryService.execute("SELECT cpu_brand, physical_memory FROM system_info"),
           let hw = hwResults.first {
            systemInfo["cpu"] = hw["cpu_brand"] ?? "Unknown"
            if let memBytesStr = hw["physical_memory"] as? String,
               let bytes = Int64(memBytesStr) {
                let gb = Double(bytes) / 1_073_741_824
                systemInfo["memory_gb"] = String(format: "%.1f GB", gb)
            }
        }

        let jsonData = try JSONSerialization.data(withJSONObject: systemInfo, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let summary = "\(systemInfo["os_name"] ?? "macOS") \(systemInfo["os_version"] ?? "") - Up \(systemInfo["uptime"] ?? "unknown")"

        return .result(
            value: jsonString,
            dialog: IntentDialog(stringLiteral: summary)
        )
    }
}

// MARK: - Run Favorite Query Intent

/// Shortcut action to run a saved favorite query by name
struct RunFavoriteIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Favorite Query"
    static let description = IntentDescription("Run one of your saved favorite queries by name")

    @Parameter(title: "Favorite Name", description: "The name of the favorite query to run")
    var favoriteName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Run favorite: \(\.$favoriteName)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Find the favorite by name (case-insensitive)
        let searchName = favoriteName.lowercased()
        guard let favorite = appState.favorites.first(where: {
            $0.displayName.lowercased().contains(searchName) ||
            ($0.name?.lowercased().contains(searchName) ?? false)
        }) else {
            throw IntentError.favoriteNotFound(favoriteName)
        }

        let query = favorite.query

        // Check if it looks like SQL or natural language
        let isSQL = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .hasPrefix("SELECT") ||
            query.uppercased().hasPrefix("PRAGMA")

        var results: [[String: Any]]

        if isSQL {
            // Run as SQL
            results = try await appState.osqueryService.execute(query)
        } else {
            // Translate and run
            guard appState.currentLLMService.isConfigured else {
                throw IntentError.notConfigured
            }

            let schemaContext = try await appState.osqueryService.getSchema(for: Array(appState.enabledTables))
            let translation = try await appState.currentLLMService.translateToSQL(
                query: query,
                schemaContext: schemaContext
            )
            results = try await appState.osqueryService.execute(translation.sql)
        }

        // Limit results
        let maxRows = 500
        if results.count > maxRows {
            throw IntentError.resultTooLarge(results.count)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        // Log to history
        appState.logQueryToHistory(
            query: query,
            rowCount: results.count,
            source: "shortcut"
        )

        return .result(
            value: jsonString,
            dialog: "Ran '\(favorite.displayName)' - \(results.count) result\(results.count == 1 ? "" : "s")"
        )
    }
}

// MARK: - List Favorites Intent

/// Shortcut action to list all saved favorite queries
struct ListFavoritesIntent: AppIntent {
    static let title: LocalizedStringResource = "List Favorite Queries"
    static let description = IntentDescription("Get a list of all your saved favorite queries")

    static var parameterSummary: some ParameterSummary {
        Summary("List all favorites")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        let favorites = appState.favorites

        if favorites.isEmpty {
            return .result(
                value: "[]",
                dialog: "You don't have any saved favorites yet. Add queries to favorites in the Osquery NLI app."
            )
        }

        let dateFormatter = ISO8601DateFormatter()
        let favoritesData: [[String: String]] = favorites.map { fav in
            [
                "name": fav.displayName,
                "query": fav.query,
                "created": dateFormatter.string(from: fav.createdAt)
            ]
        }

        let jsonData = try JSONSerialization.data(withJSONObject: favoritesData, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        return .result(
            value: jsonString,
            dialog: "You have \(favorites.count) saved favorite\(favorites.count == 1 ? "" : "s")"
        )
    }
}

// MARK: - Check Process Intent

/// Shortcut action to check if a specific process is running
struct CheckProcessIntent: AppIntent {
    static let title: LocalizedStringResource = "Check If Process Running"
    static let description = IntentDescription("Check if a specific application or process is running on your Mac")

    @Parameter(title: "Process Name", description: "The name of the process to check (e.g., 'Safari' or 'Chrome')")
    var processName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Check if \(\.$processName) is running")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        guard let appState = AppState.shared else {
            throw IntentError.appNotRunning
        }

        // Escape single quotes in process name for SQL safety
        let safeName = processName.replacingOccurrences(of: "'", with: "''")

        let sql = "SELECT name, pid, path FROM processes WHERE name LIKE '%\(safeName)%' OR path LIKE '%\(safeName)%' LIMIT 10"
        let results = try await appState.osqueryService.execute(sql)

        let isRunning = !results.isEmpty

        if isRunning {
            let processInfo = results.map { proc in
                "\(proc["name"] ?? "Unknown") (PID: \(proc["pid"] ?? "?"))"
            }.joined(separator: ", ")

            return .result(
                value: true,
                dialog: "Yes, found: \(processInfo)"
            )
        } else {
            return .result(
                value: false,
                dialog: "No, '\(processName)' is not running"
            )
        }
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case appNotRunning
    case notConfigured
    case resultTooLarge(Int)
    case favoriteNotFound(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appNotRunning:
            return "Osquery NLI is not running. Please open the app first."
        case .notConfigured:
            return "No AI provider configured. Please open Osquery NLI and set up an API key in Settings."
        case .resultTooLarge(let count):
            return "Query returned \(count) rows, which is too large for Shortcuts. Try adding a LIMIT clause to your query."
        case .favoriteNotFound(let name):
            return "No favorite found matching '\(name)'. Use 'List Favorite Queries' to see available favorites."
        }
    }
}

// MARK: - App Shortcuts Provider

/// Provides pre-configured shortcuts for discovery in the Shortcuts app
struct OsqueryShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
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
            intent: GetSystemInfoIntent(),
            phrases: [
                "Get system info from \(.applicationName)",
                "Show my Mac info with \(.applicationName)",
                "What's my Mac uptime"
            ],
            shortTitle: "System Info",
            systemImageName: "desktopcomputer"
        )
        AppShortcut(
            intent: CheckProcessIntent(),
            phrases: [
                "Is \(.applicationName) process running",
                "Check if app is running with \(.applicationName)"
            ],
            shortTitle: "Check Process",
            systemImageName: "gearshape.2"
        )
        AppShortcut(
            intent: RunFavoriteIntent(),
            phrases: [
                "Run favorite in \(.applicationName)",
                "Execute saved query in \(.applicationName)"
            ],
            shortTitle: "Run Favorite",
            systemImageName: "star"
        )
        AppShortcut(
            intent: ListFavoritesIntent(),
            phrases: [
                "List \(.applicationName) favorites",
                "Show saved queries in \(.applicationName)"
            ],
            shortTitle: "List Favorites",
            systemImageName: "list.star"
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
