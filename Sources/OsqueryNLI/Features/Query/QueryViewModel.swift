import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// ViewModel for QueryView - manages query input state and actions
@Observable
@MainActor
final class QueryViewModel {
    // MARK: - State

    var queryText: String = ""
    var showRawData: Bool = false
    var showingTemplates: Bool = false
    var showAutoComplete: Bool = false
    var selectedSuggestionIndex: Int = 0

    // MARK: - Save Feedback

    var showSaveResult: Bool = false
    var saveResultSuccess: Bool = false
    var saveResultMessage: String = ""

    // MARK: - Query Input History

    private static let maxHistorySize = 50
    private static let historyKey = "queryInputHistory"

    /// History of submitted queries (most recent last)
    private var inputHistory: [String] = []

    /// Current position in history (-1 means not browsing history)
    private var historyIndex: Int = -1

    /// Temporary storage for current input when browsing history
    private var savedCurrentInput: String = ""

    // MARK: - Dependencies

    private let appState: AppState

    // MARK: - Initialization

    init(appState: AppState) {
        self.appState = appState
        loadInputHistory()
    }

    private func loadInputHistory() {
        inputHistory = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    private func saveInputHistory() {
        UserDefaults.standard.set(inputHistory, forKey: Self.historyKey)
    }

    // MARK: - Computed Properties

    var isQuerying: Bool { appState.isQuerying }
    var isCheckingOsquery: Bool { appState.isCheckingOsquery }
    var isOsqueryAvailable: Bool { appState.isOsqueryAvailable }
    var currentQuery: String { appState.currentQuery }
    var lastResult: QueryResult? { appState.lastResult }
    var lastError: String? { appState.lastError }
    var queryStage: AppState.QueryStage { appState.queryStage }
    var selectedProvider: LLMProvider { appState.selectedProvider }
    var favorites: [FavoriteQuery] { appState.favorites }

    var canSubmit: Bool {
        !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isQuerying
    }

    var hasResults: Bool {
        lastResult != nil || lastError != nil
    }

    // MARK: - Actions

    func submitQuery() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        // Add to input history (avoid duplicates at the end)
        if inputHistory.last != query {
            inputHistory.append(query)
            // Trim history if too large
            if inputHistory.count > Self.maxHistorySize {
                inputHistory.removeFirst(inputHistory.count - Self.maxHistorySize)
            }
            saveInputHistory()
        }

        // Reset history navigation
        historyIndex = -1
        savedCurrentInput = ""

        Task {
            await appState.runQuery(query)
        }
    }

    func clearAndReset() {
        queryText = ""
        historyIndex = -1
        savedCurrentInput = ""
        appState.lastResult = nil
        appState.lastError = nil
        appState.currentQuery = ""
    }

    // MARK: - Input History Navigation

    /// Navigate to previous query in history (↑ arrow)
    func navigateHistoryUp() {
        guard !inputHistory.isEmpty else { return }

        if historyIndex == -1 {
            // Starting to browse history, save current input
            savedCurrentInput = queryText
            historyIndex = inputHistory.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }

        queryText = inputHistory[historyIndex]
    }

    /// Navigate to next query in history (↓ arrow)
    func navigateHistoryDown() {
        guard historyIndex != -1 else { return }

        if historyIndex < inputHistory.count - 1 {
            historyIndex += 1
            queryText = inputHistory[historyIndex]
        } else {
            // Return to current input
            historyIndex = -1
            queryText = savedCurrentInput
        }
    }

    /// Check if currently browsing history
    var isBrowsingHistory: Bool {
        historyIndex != -1
    }

    /// Exit history browsing and restore current input
    func exitHistoryBrowsing() {
        guard historyIndex != -1 else { return }
        queryText = savedCurrentInput
        historyIndex = -1
        savedCurrentInput = ""
    }

    /// Recent queries for dropdown (most recent first, limited to 10)
    var recentQueries: [String] {
        Array(inputHistory.suffix(10).reversed())
    }

    /// Select a query from the recent queries dropdown
    func selectRecentQuery(_ query: String) {
        queryText = query
        historyIndex = -1
        savedCurrentInput = ""
    }

    func retryLastQuery() {
        let query = appState.currentQuery
        guard !query.isEmpty else { return }

        appState.lastError = nil
        Task {
            await appState.runQuery(query)
        }
    }

    func cancelQuery() {
        appState.cancelQuery()
    }

    func refreshOsqueryStatus() {
        appState.refreshOsqueryStatus()
    }

    func selectTemplate(_ query: String) {
        queryText = query
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            submitQuery()
        }
    }

    func selectFavorite(_ favorite: FavoriteQuery) {
        queryText = favorite.query
        submitQuery()
    }

    // MARK: - Favorites

    func toggleFavorite() {
        guard !currentQuery.isEmpty else { return }
        appState.toggleFavorite(currentQuery)
    }

    func isFavorite(_ query: String) -> Bool {
        appState.isFavorite(query)
    }

    // MARK: - Export

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func saveToFile(content: String, defaultName: String, fileType: String) {
        let savePanel = NSSavePanel()

        switch fileType {
        case "json":
            savePanel.allowedContentTypes = [.json]
        case "csv":
            savePanel.allowedContentTypes = [.commaSeparatedText]
        case "md":
            savePanel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        default:
            savePanel.allowedContentTypes = [.plainText]
        }

        savePanel.nameFieldStringValue = defaultName
        savePanel.title = "Export Results"
        savePanel.message = "Choose where to save the query results"

        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    Task { @MainActor in
                        self.showSaveSuccess("Saved to \(url.lastPathComponent)")
                    }
                } catch {
                    Task { @MainActor in
                        self.showSaveError("Failed to save: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    func saveXLSXToFile(data: Data, defaultName: String) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "xlsx") ?? .data]
        savePanel.nameFieldStringValue = defaultName
        savePanel.title = "Export Results"
        savePanel.message = "Choose where to save the Excel file"

        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    Task { @MainActor in
                        self.showSaveSuccess("Saved to \(url.lastPathComponent)")
                    }
                } catch {
                    Task { @MainActor in
                        self.showSaveError("Failed to save: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func showSaveSuccess(_ message: String) {
        saveResultSuccess = true
        saveResultMessage = message
        showSaveResult = true
        dismissSaveResultAfterDelay()
    }

    private func showSaveError(_ message: String) {
        saveResultSuccess = false
        saveResultMessage = message
        showSaveResult = true
        dismissSaveResultAfterDelay()
    }

    private func dismissSaveResultAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation {
                showSaveResult = false
            }
        }
    }

    // MARK: - Stage Helpers

    func stageOrder(_ stage: AppState.QueryStage) -> Int {
        switch stage {
        case .idle: return 0
        case .translating: return 1
        case .executing: return 2
        case .summarizing: return 3
        }
    }

    func stageName(_ stage: AppState.QueryStage) -> String {
        switch stage {
        case .idle: return "Ready"
        case .translating: return "Translate"
        case .executing: return "Execute"
        case .summarizing: return "Summarize"
        }
    }

    // MARK: - Constants

    var exampleQueries: [String] {
        [
            "What is the system uptime?",
            "Show me running processes using the most memory",
            "List all installed apps",
            "What USB devices are connected?"
        ]
    }

    // MARK: - Auto-Complete

    /// Suggestion types for auto-complete
    enum SuggestionType {
        case table
        case template
        case favorite
        case history

        var icon: String {
            switch self {
            case .table: return "tablecells"
            case .template: return "rectangle.stack"
            case .favorite: return "star.fill"
            case .history: return "clock"
            }
        }
    }

    struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        let type: SuggestionType
        let displayText: String
    }

    /// Generate suggestions based on current query text
    var autoCompleteSuggestions: [Suggestion] {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.count >= 2 else { return [] }

        var suggestions: [Suggestion] = []
        let maxSuggestions = 6

        // 1. Match table names
        let tables = appState.enabledTables.filter { $0.lowercased().contains(query) }
        for table in tables.prefix(2) {
            suggestions.append(Suggestion(
                text: "Show data from \(table)",
                type: .table,
                displayText: table
            ))
        }

        // 2. Match favorites
        let matchingFavorites = favorites.filter {
            $0.query.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query)
        }
        for fav in matchingFavorites.prefix(2) {
            suggestions.append(Suggestion(
                text: fav.query,
                type: .favorite,
                displayText: fav.displayName
            ))
        }

        // 3. Match recent queries
        let matchingHistory = inputHistory.reversed().filter {
            $0.lowercased().contains(query) && $0 != queryText
        }
        for histQuery in matchingHistory.prefix(2) {
            // Avoid duplicates with favorites
            if !suggestions.contains(where: { $0.text == histQuery }) {
                suggestions.append(Suggestion(
                    text: histQuery,
                    type: .history,
                    displayText: String(histQuery.prefix(50))
                ))
            }
        }

        // 4. Smart query suggestions based on keywords
        let keywordSuggestions = generateKeywordSuggestions(for: query)
        for suggestion in keywordSuggestions {
            if !suggestions.contains(where: { $0.text == suggestion.text }) {
                suggestions.append(suggestion)
            }
        }

        return Array(suggestions.prefix(maxSuggestions))
    }

    /// Generate suggestions based on common keywords
    private func generateKeywordSuggestions(for query: String) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        let keywordMap: [(keywords: [String], suggestion: String)] = [
            (["process", "running", "cpu", "memory"], "Show me running processes using the most memory"),
            (["network", "connection", "port", "listen"], "What ports are listening on this system?"),
            (["user", "account", "login"], "List all user accounts"),
            (["disk", "storage", "space"], "Show disk usage and available space"),
            (["app", "installed", "application", "software"], "List all installed applications"),
            (["startup", "boot", "launch", "login item"], "What programs start at login?"),
            (["usb", "device", "hardware"], "What USB devices are connected?"),
            (["security", "firewall", "sip"], "Check security status (SIP, Gatekeeper)"),
            (["ai", "llm", "chatgpt", "claude", "gemini"], "What AI tools are installed?"),
            (["browser", "extension", "chrome", "safari"], "List browser extensions"),
            (["uptime", "boot", "restart"], "What is the system uptime?"),
            (["version", "macos", "system"], "What macOS version is this?"),
        ]

        for (keywords, suggestion) in keywordMap {
            if keywords.contains(where: { query.contains($0) }) {
                suggestions.append(Suggestion(
                    text: suggestion,
                    type: .template,
                    displayText: suggestion
                ))
            }
        }

        return suggestions
    }

    /// Select a suggestion
    func selectSuggestion(_ suggestion: Suggestion) {
        queryText = suggestion.text
        showAutoComplete = false
        selectedSuggestionIndex = 0

        // Auto-submit for favorites and history
        if suggestion.type == .favorite || suggestion.type == .history {
            submitQuery()
        }
    }

    /// Navigate suggestions with keyboard
    func navigateSuggestionUp() {
        guard showAutoComplete && !autoCompleteSuggestions.isEmpty else { return }
        if selectedSuggestionIndex > 0 {
            selectedSuggestionIndex -= 1
        }
    }

    func navigateSuggestionDown() {
        guard showAutoComplete && !autoCompleteSuggestions.isEmpty else { return }
        if selectedSuggestionIndex < autoCompleteSuggestions.count - 1 {
            selectedSuggestionIndex += 1
        }
    }

    func selectCurrentSuggestion() {
        guard showAutoComplete && !autoCompleteSuggestions.isEmpty else { return }
        let suggestions = autoCompleteSuggestions
        if selectedSuggestionIndex < suggestions.count {
            selectSuggestion(suggestions[selectedSuggestionIndex])
        }
    }

    /// Update auto-complete visibility based on query text
    func updateAutoComplete() {
        let hasText = queryText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        let hasSuggestions = !autoCompleteSuggestions.isEmpty

        if hasText && hasSuggestions && !isQuerying && !isBrowsingHistory {
            showAutoComplete = true
            selectedSuggestionIndex = 0
        } else {
            showAutoComplete = false
        }
    }

    func dismissAutoComplete() {
        showAutoComplete = false
        selectedSuggestionIndex = 0
    }
}
