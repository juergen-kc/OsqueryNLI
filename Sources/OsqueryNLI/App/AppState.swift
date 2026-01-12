import Foundation
import SwiftUI

/// Main application state using @Observable (macOS 14+)
@Observable
@MainActor
final class AppState {
    /// Shared instance for use by App Intents (Shortcuts)
    /// Note: This is optional because it won't be set until the app initializes.
    /// App Intents should check for nil and throw an appropriate error.
    nonisolated(unsafe) static var shared: AppState?

    // MARK: - Settings

    var selectedProvider: LLMProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        }
    }

    var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "selectedModel")
        }
    }

    var enabledTables: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(Array(enabledTables)) {
                UserDefaults.standard.set(data, forKey: "enabledTables")
            }
        }
    }

    var aiDiscoveryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(aiDiscoveryEnabled, forKey: "aiDiscoveryEnabled")
            osqueryService.aiDiscoveryEnabled = aiDiscoveryEnabled
            // Auto-add/remove AI tables when toggling AI Discovery
            if aiDiscoveryEnabled {
                addAITablesToEnabled()
            }
        }
    }

    // MARK: - UI Settings

    var fontScale: FontScale {
        didSet {
            UserDefaults.standard.set(fontScale.rawValue, forKey: "fontScale")
        }
    }

    // MARK: - Scheduled Queries

    var scheduledQueries: [ScheduledQuery] = [] {
        didSet {
            saveScheduledQueries()
        }
    }

    var schedulerEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(schedulerEnabled, forKey: "schedulerEnabled")
            if schedulerEnabled {
                schedulerService?.start()
            } else {
                schedulerService?.stop()
            }
        }
    }

    var notificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    private var schedulerService: SchedulerService?

    /// Add AI Discovery tables to enabledTables if not already present
    private func addAITablesToEnabled() {
        let aiTables = Set(OsqueryService.aiDiscoveryTables)
        let missing = aiTables.subtracting(enabledTables)
        if !missing.isEmpty {
            enabledTables = enabledTables.union(aiTables)
        }
    }

    // MARK: - Query State

    enum QueryStage: String {
        case idle = ""
        case translating = "Translating to SQL..."
        case executing = "Executing query..."
        case summarizing = "Generating summary..."
    }

    var isQuerying: Bool = false
    var queryStage: QueryStage = .idle
    var currentQuery: String = ""
    var lastResult: QueryResult?
    var lastError: String?
    var queryHistory: [QueryHistoryEntry] = []
    private var currentQueryTask: Task<Void, Never>?

    // MARK: - Query Cache

    /// Cache entry with result and timestamp
    private struct CacheEntry {
        let result: QueryResult
        let timestamp: Date
        let provider: LLMProvider
        let model: String
        let tables: Set<String>
    }

    /// Cache for query results (keyed by normalized query string)
    private var queryCache: [String: CacheEntry] = [:]

    /// Cache expiry time in seconds (5 minutes)
    private let cacheExpirySeconds: TimeInterval = 300

    /// Whether to use cache (can be disabled in settings)
    var queryCacheEnabled: Bool = true

    // MARK: - Cache Methods

    /// Normalize query string for use as cache key
    private func normalizedCacheKey(for query: String) -> String {
        query.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Get cached result if valid (not expired, same provider/tables)
    private func getCachedResult(for key: String) -> QueryResult? {
        guard let entry = queryCache[key] else { return nil }

        // Check expiry
        let age = Date().timeIntervalSince(entry.timestamp)
        guard age < cacheExpirySeconds else {
            queryCache.removeValue(forKey: key)
            return nil
        }

        // Check if provider, model, or tables changed
        guard entry.provider == selectedProvider,
              entry.model == selectedModel,
              entry.tables == enabledTables else {
            queryCache.removeValue(forKey: key)
            return nil
        }

        return entry.result
    }

    /// Store result in cache
    private func cacheResult(_ result: QueryResult, for key: String) {
        let entry = CacheEntry(
            result: result,
            timestamp: Date(),
            provider: selectedProvider,
            model: selectedModel,
            tables: enabledTables
        )
        queryCache[key] = entry

        // Clean up old entries (keep max 50)
        if queryCache.count > 50 {
            let sortedKeys = queryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sortedKeys.prefix(queryCache.count - 50) {
                queryCache.removeValue(forKey: key)
            }
        }
    }

    /// Clear the query cache
    func clearCache() {
        queryCache.removeAll()
    }

    // MARK: - Favorites

    var favorites: [FavoriteQuery] = []

    // MARK: - Osquery Status

    var isOsqueryAvailable: Bool = false
    var isCheckingOsquery: Bool = false

    // MARK: - MCP Server State

    var mcpServerEnabled: Bool {
        didSet {
            UserDefaults.standard.set(mcpServerEnabled, forKey: "mcpServerEnabled")
            if mcpServerEnabled {
                startMCPServer()
            } else {
                stopMCPServer()
            }
        }
    }

    var mcpAutoStart: Bool {
        didSet {
            UserDefaults.standard.set(mcpAutoStart, forKey: "mcpAutoStart")
        }
    }

    var mcpServerRunning: Bool = false
    var mcpServerError: String?
    private var mcpServerProcess: Process?

    // MARK: - Services

    let osqueryService: OsqueryService
    private let llmFactory: LLMServiceFactory

    // MARK: - Initialization

    init() {
        // Load settings from UserDefaults
        let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider") ?? LLMProvider.gemini.rawValue
        let provider = LLMProvider(rawValue: providerRaw) ?? .gemini
        self.selectedProvider = provider

        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel")
            ?? provider.defaultModel

        // Load enabled tables
        if let data = UserDefaults.standard.data(forKey: "enabledTables"),
           let tables = try? JSONDecoder().decode([String].self, from: data) {
            self.enabledTables = Set(tables)
        } else {
            self.enabledTables = Set(OsqueryService.defaultEnabledTables)
        }

        // Load query history from shared file
        self.queryHistory = QueryHistoryLogger.shared.readEntries()

        // Load favorites
        if let data = UserDefaults.standard.data(forKey: "favorites"),
           let savedFavorites = try? JSONDecoder().decode([FavoriteQuery].self, from: data) {
            self.favorites = savedFavorites
        }

        // Load MCP settings
        self.mcpServerEnabled = UserDefaults.standard.bool(forKey: "mcpServerEnabled")
        self.mcpAutoStart = UserDefaults.standard.bool(forKey: "mcpAutoStart")

        // Load AI Discovery setting (default to true)
        let aiEnabled = UserDefaults.standard.object(forKey: "aiDiscoveryEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "aiDiscoveryEnabled")
        self.aiDiscoveryEnabled = aiEnabled

        // Load UI settings
        let fontScaleRaw = UserDefaults.standard.string(forKey: "fontScale") ?? FontScale.regular.rawValue
        self.fontScale = FontScale(rawValue: fontScaleRaw) ?? .regular

        // Initialize services
        self.osqueryService = OsqueryService()
        self.osqueryService.aiDiscoveryEnabled = aiEnabled
        self.llmFactory = LLMServiceFactory.shared

        // Auto-add AI tables if AI Discovery is enabled
        // (didSet doesn't fire during init, so we call explicitly)
        if aiEnabled {
            addAITablesToEnabled()
        }

        // Auto-start MCP server if enabled
        if mcpAutoStart && mcpServerEnabled {
            startMCPServer()
        }

        // Load scheduled queries and notification settings
        self.scheduledQueries = loadScheduledQueries()
        self.schedulerEnabled = UserDefaults.standard.bool(forKey: "schedulerEnabled")
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")

        // Initialize scheduler service
        self.schedulerService = SchedulerService(appState: self)
        if schedulerEnabled {
            schedulerService?.start()
        }

        // Set up notification action handler
        NotificationService.shared.onViewResults = { [weak self] queryId in
            self?.handleNotificationViewResults(queryId: queryId)
        }

        // Set shared instance for App Intents (Shortcuts)
        AppState.shared = self
    }

    // MARK: - LLM Configuration

    var currentLLMService: any LLMServiceProtocol {
        llmFactory.service(for: selectedProvider, model: selectedModel)
    }

    var isLLMConfigured: Bool {
        llmFactory.isConfigured(selectedProvider)
    }

    func getAPIKey(for provider: LLMProvider) -> String {
        llmFactory.getAPIKey(for: provider)
    }

    func setAPIKey(_ key: String, for provider: LLMProvider) throws {
        try llmFactory.updateAPIKey(key, for: provider)
    }

    func testConnection() async throws -> String {
        try await llmFactory.testConnection(for: selectedProvider)
    }

    // MARK: - Query Execution

    func runQuery(_ naturalLanguage: String, forceRefresh: Bool = false) async {
        guard !naturalLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard isLLMConfigured else {
            lastError = "Please configure your \(selectedProvider.displayName) API key in Settings."
            return
        }

        // Check cache first (unless force refresh)
        let cacheKey = normalizedCacheKey(for: naturalLanguage)
        if !forceRefresh && queryCacheEnabled, let cached = getCachedResult(for: cacheKey) {
            currentQuery = naturalLanguage
            lastResult = cached
            lastError = nil
            return
        }

        // Cancel any existing query
        currentQueryTask?.cancel()

        isQuerying = true
        queryStage = .translating
        lastError = nil
        lastResult = nil
        currentQuery = naturalLanguage

        let startTime = Date()

        // Store the task so it can be cancelled
        currentQueryTask = Task {
            do {
                // Check for cancellation
                try Task.checkCancellation()

                // 1. Get schema for enabled tables
                let schema = try await osqueryService.getSchema(for: Array(enabledTables))

                if schema.isEmpty {
                    throw OsqueryError.executionFailed(stderr: "No schema available. Please enable some tables in Settings.")
                }

                try Task.checkCancellation()

                // 2. Translate to SQL
                await MainActor.run { queryStage = .translating }
                let translation = try await currentLLMService.translateToSQL(
                    query: naturalLanguage,
                    schemaContext: schema
                )

                try Task.checkCancellation()

                // 3. Execute SQL queries
                await MainActor.run { queryStage = .executing }
                let queries = translation.sql
                    .components(separatedBy: ";")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                var allResults: [[String: Any]] = []

                for sql in queries {
                    try Task.checkCancellation()
                    let results = try await osqueryService.execute(sql)
                    allResults.append(contentsOf: results)
                }

                try Task.checkCancellation()

                // 4. Summarize results
                await MainActor.run { queryStage = .summarizing }
                let summary = try await currentLLMService.summarizeResults(
                    question: naturalLanguage,
                    sql: translation.sql,
                    results: allResults
                )

                let executionTime = Date().timeIntervalSince(startTime)

                // Aggregate token usage from translation and summarization
                var totalTokenUsage: TokenUsage?
                if let translationUsage = translation.tokenUsage {
                    if let summaryUsage = summary.tokenUsage {
                        totalTokenUsage = translationUsage + summaryUsage
                    } else {
                        totalTokenUsage = translationUsage
                    }
                } else if let summaryUsage = summary.tokenUsage {
                    totalTokenUsage = summaryUsage
                }

                // 5. Create result
                await MainActor.run {
                    let result = QueryResult.from(
                        sql: translation.sql,
                        osqueryOutput: allResults,
                        executionTime: executionTime,
                        summary: summary.answer,
                        tokenUsage: totalTokenUsage
                    )
                    lastResult = result

                    // Cache the result
                    cacheResult(result, for: cacheKey)
                }

                // 6. Add to query history
                await MainActor.run {
                    addToQueryHistory(naturalLanguage)
                }

            } catch is CancellationError {
                await MainActor.run {
                    lastError = "Query cancelled."
                }
            } catch let error as LLMError {
                await MainActor.run {
                    lastError = error.localizedDescription
                }
            } catch let error as OsqueryError {
                await MainActor.run {
                    lastError = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    lastError = "Unexpected error: \(error.localizedDescription)"
                }
            }

            await MainActor.run {
                queryStage = .idle
                isQuerying = false
            }
        }

        await currentQueryTask?.value
    }

    /// Cancel the current query
    func cancelQuery() {
        currentQueryTask?.cancel()
        currentLLMService.cancel()
        queryStage = .idle
        isQuerying = false
        lastError = "Query cancelled."
    }

    // MARK: - Query History

    private func addToQueryHistory(_ query: String) {
        // Log to shared file
        QueryHistoryLogger.shared.logQuery(query: query, source: .app)

        // Refresh local history
        refreshQueryHistory()
    }

    /// Log a query to history (public method for Shortcuts integration)
    /// - Parameters:
    ///   - query: The SQL query or natural language question
    ///   - rowCount: Optional number of results returned
    ///   - source: Source identifier ("app", "mcp", or "shortcut")
    func logQueryToHistory(query: String, rowCount: Int?, source: String) {
        // Map "shortcut" to .app since it comes from our app's Shortcuts
        let querySource: QuerySource = source == "mcp" ? .mcp : .app
        QueryHistoryLogger.shared.logQuery(query: query, source: querySource, rowCount: rowCount)
        refreshQueryHistory()
    }

    func refreshQueryHistory() {
        queryHistory = QueryHistoryLogger.shared.readEntries()
    }

    func clearQueryHistory() {
        QueryHistoryLogger.shared.clearEntries()
        queryHistory.removeAll()
    }

    func clearQueryHistory(source: QuerySource) {
        QueryHistoryLogger.shared.clearEntries(source: source)
        refreshQueryHistory()
    }

    func removeHistoryEntry(_ entry: QueryHistoryEntry) {
        QueryHistoryLogger.shared.removeEntry(id: entry.id)
        refreshQueryHistory()
    }

    // MARK: - Favorites Management

    func addToFavorites(_ query: String, name: String? = nil) {
        // Don't add duplicates
        guard !favorites.contains(where: { $0.query == query }) else { return }

        let favorite = FavoriteQuery(query: query, name: name)
        favorites.insert(favorite, at: 0)
        saveFavorites()
    }

    func removeFromFavorites(_ favorite: FavoriteQuery) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    func updateFavorite(_ favorite: FavoriteQuery, name: String) {
        if let index = favorites.firstIndex(where: { $0.id == favorite.id }) {
            favorites[index].name = name
            saveFavorites()
        }
    }

    func isFavorite(_ query: String) -> Bool {
        favorites.contains { $0.query == query }
    }

    func toggleFavorite(_ query: String) {
        if let existing = favorites.first(where: { $0.query == query }) {
            removeFromFavorites(existing)
        } else {
            addToFavorites(query)
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "favorites")
        }
    }

    // MARK: - Table Management

    func toggleTable(_ table: String) {
        if enabledTables.contains(table) {
            enabledTables.remove(table)
        } else {
            enabledTables.insert(table)
        }
    }

    func resetTablesToDefault() {
        enabledTables = Set(OsqueryService.defaultEnabledTables)
    }

    func selectAllTables(_ tables: [String]) {
        enabledTables = Set(tables)
    }

    func deselectAllTables() {
        enabledTables = []
    }

    // MARK: - Osquery Availability

    func checkOsqueryAvailability() async {
        isCheckingOsquery = true
        isOsqueryAvailable = await osqueryService.isAvailable()
        isCheckingOsquery = false
    }

    func refreshOsqueryStatus() {
        Task {
            await checkOsqueryAvailability()
        }
    }

    // MARK: - MCP Server Management

    /// Path to the MCP server executable
    var mcpServerPath: String {
        // 1. Check in app bundle Resources (for distributed app)
        if let bundlePath = Bundle.main.path(forResource: "OsqueryMCPServer", ofType: nil) {
            return bundlePath
        }

        // 2. Check in app bundle Resources directly (alternative location)
        let resourcesPath = Bundle.main.bundlePath + "/Contents/Resources/OsqueryMCPServer"
        if FileManager.default.fileExists(atPath: resourcesPath) {
            return resourcesPath
        }

        // 3. Check sibling to executable (for development with swift run)
        let siblingPath = Bundle.main.bundlePath
            .components(separatedBy: "/")
            .dropLast()
            .joined(separator: "/") + "/OsqueryMCPServer"
        if FileManager.default.fileExists(atPath: siblingPath) {
            return siblingPath
        }

        // 4. Check .build/release directory (for development)
        let cwd = FileManager.default.currentDirectoryPath
        let releasePath = cwd + "/.build/release/OsqueryMCPServer"
        if FileManager.default.fileExists(atPath: releasePath) {
            return releasePath
        }

        // 5. Check .build/debug directory (for development)
        let debugPath = cwd + "/.build/debug/OsqueryMCPServer"
        if FileManager.default.fileExists(atPath: debugPath) {
            return debugPath
        }

        // 6. Default fallback
        return "/usr/local/bin/OsqueryMCPServer"
    }

    func startMCPServer() {
        guard !mcpServerRunning else { return }

        mcpServerError = nil

        // Check if the server executable exists
        guard FileManager.default.fileExists(atPath: mcpServerPath) else {
            mcpServerError = "MCP server not found at: \(mcpServerPath)"
            mcpServerRunning = false
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mcpServerPath)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            mcpServerProcess = process
            mcpServerRunning = true
        } catch {
            mcpServerError = "Failed to start MCP server: \(error.localizedDescription)"
            mcpServerRunning = false
        }
    }

    func stopMCPServer() {
        guard let process = mcpServerProcess, process.isRunning else {
            mcpServerRunning = false
            return
        }

        process.terminate()
        mcpServerProcess = nil
        mcpServerRunning = false
    }

    /// Generate configuration for Claude Desktop
    func claudeDesktopConfig() -> String {
        """
        {
          "mcpServers": {
            "osquery": {
              "command": "\(mcpServerPath)",
              "args": []
            }
          }
        }
        """
    }

    /// Generate configuration for Cursor
    func cursorConfig() -> String {
        """
        {
          "mcpServers": {
            "osquery": {
              "command": "\(mcpServerPath)"
            }
          }
        }
        """
    }

    // MARK: - Scheduled Queries Management

    private var scheduledQueriesFileURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dataDir = appSupport.appendingPathComponent("OsqueryNLI")
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
        return dataDir.appendingPathComponent("scheduled_queries.json")
    }

    private func loadScheduledQueries() -> [ScheduledQuery] {
        guard FileManager.default.fileExists(atPath: scheduledQueriesFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: scheduledQueriesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ScheduledQuery].self, from: data)
        } catch {
            print("Failed to load scheduled queries: \(error)")
            return []
        }
    }

    private func saveScheduledQueries() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(scheduledQueries)
            try data.write(to: scheduledQueriesFileURL, options: .atomic)
        } catch {
            print("Failed to save scheduled queries: \(error)")
        }
    }

    func addScheduledQuery(_ query: ScheduledQuery) {
        scheduledQueries.append(query)
    }

    func removeScheduledQuery(_ query: ScheduledQuery) {
        scheduledQueries.removeAll { $0.id == query.id }
        ScheduledQueryResultStore.shared.clearResults(for: query.id)
    }

    func updateScheduledQuery(_ query: ScheduledQuery) {
        if let index = scheduledQueries.firstIndex(where: { $0.id == query.id }) {
            scheduledQueries[index] = query
        }
    }

    func runScheduledQueryNow(_ query: ScheduledQuery) async {
        await schedulerService?.runNow(query)
    }

    // MARK: - Notifications

    func enableNotifications() async -> Bool {
        let granted = await NotificationService.shared.requestPermission()
        if granted {
            notificationsEnabled = true
        }
        return granted
    }

    func checkNotificationPermission() async -> Bool {
        let status = await NotificationService.shared.checkPermission()
        return status == .authorized
    }

    private func handleNotificationViewResults(queryId: UUID) {
        // Find the scheduled query and show its results
        // This will be implemented with the UI
        if let query = scheduledQueries.first(where: { $0.id == queryId }) {
            // Post notification that UI can observe
            NotificationCenter.default.post(
                name: .showScheduledQueryResults,
                object: nil,
                userInfo: ["queryId": queryId, "queryName": query.name]
            )
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showScheduledQueryResults = Notification.Name("showScheduledQueryResults")
}
