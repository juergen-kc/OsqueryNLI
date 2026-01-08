import SwiftUI
import AppKit

/// Compact query view for menu bar popover
struct PopoverQueryView: View {
    @Environment(AppState.self) private var appState
    @State private var queryText: String = ""
    @FocusState private var isInputFocused: Bool

    /// Callback when user wants to open full window
    var onOpenFullWindow: (() -> Void)?

    /// Callback to close the popover
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Query input
            queryInputView
                .padding(12)

            Divider()

            // Results area (compact)
            resultsView
                .frame(maxHeight: 300)

            Divider()

            // Footer with actions
            footerView
        }
        .frame(width: 380)
        .background(.background)
        .onAppear {
            isInputFocused = true
            if !appState.isOsqueryAvailable && !appState.isCheckingOsquery {
                appState.refreshOsqueryStatus()
            }
        }
        // Keyboard shortcuts
        .background(
            Group {
                // Cmd+Enter to submit
                Button("") { submitQuery() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .opacity(0)

                // Escape to close or cancel
                Button("") {
                    if appState.isQuerying {
                        appState.cancelQuery()
                    } else {
                        onClose?()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
            }
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Quick Query")
                .font(.headline)

            Spacer()

            // Provider badge
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption2)
                Text(appState.selectedProvider.displayName)
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Query Input

    private var queryInputView: some View {
        HStack(spacing: 8) {
            TextField("Ask about your system...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isInputFocused)
                .onSubmit {
                    submitQuery()
                }
                .disabled(appState.isQuerying)

            Button {
                submitQuery()
            } label: {
                if appState.isQuerying {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(queryText.isEmpty ? Color.secondary : Color.accentColor)
            .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isQuerying)
            .help("Submit (⌘↩)")
        }
        .padding(10)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsView: some View {
        if appState.isQuerying {
            loadingView
        } else if let error = appState.lastError {
            errorView(error)
        } else if let result = appState.lastResult {
            resultView(result)
        } else {
            emptyStateView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text(appState.queryStage.rawValue.isEmpty ? "Processing..." : appState.queryStage.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                appState.cancelQuery()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 8) {
                if !appState.currentQuery.isEmpty {
                    Button("Retry") {
                        let query = appState.currentQuery
                        appState.lastError = nil
                        Task {
                            await appState.runQuery(query)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button("New Query") {
                    appState.lastError = nil
                    appState.currentQuery = ""
                    queryText = ""
                    isInputFocused = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }

    private func resultView(_ result: QueryResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Summary
                if let summary = result.summary {
                    Text(summary)
                        .font(.callout)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // SQL query (collapsible)
                DisclosureGroup {
                    Text(result.sql)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } label: {
                    HStack {
                        Text("SQL Query")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(result.rowCount) rows")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Row count
                HStack {
                    Text("Results: \(result.rowCount) rows")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        onOpenFullWindow?()
                    } label: {
                        Label("View Details", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(12)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title)
                .foregroundStyle(.tertiary)

            Text("Ask a question about your system")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("⌘↩ to submit • Esc to close")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button {
                onOpenFullWindow?()
            } label: {
                Label("Open Window", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button {
                openHistory()
            } label: {
                Label("History", systemImage: "clock")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                openSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func submitQuery() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        Task {
            await appState.runQuery(query)
        }
    }

    private func openHistory() {
        onClose?()
        // Post notification to open history
        NotificationCenter.default.post(name: .openHistory, object: nil)
    }

    private func openSettings() {
        onClose?()
        // Post notification to open settings
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let openHistory = Notification.Name("openHistory")
    static let openSettings = Notification.Name("openSettings")
    static let openFullQueryWindow = Notification.Name("openFullQueryWindow")
}
