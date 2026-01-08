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

    // MARK: - Dependencies

    private let appState: AppState

    // MARK: - Initialization

    init(appState: AppState) {
        self.appState = appState
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

        Task {
            await appState.runQuery(query)
        }
    }

    func clearAndReset() {
        queryText = ""
        appState.lastResult = nil
        appState.lastError = nil
        appState.currentQuery = ""
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

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save file: \(error)")
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

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                } catch {
                    print("Failed to save XLSX file: \(error)")
                }
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
}
