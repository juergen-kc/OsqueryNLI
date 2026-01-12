import SwiftUI
import OsqueryNLICore

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case app = "App"
    case mcp = "MCP"
}

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) var openWindow
    @Environment(\.fontScale) private var fontScale
    @State private var searchText: String = ""
    @State private var selectedEntry: QueryHistoryEntry?
    @State private var historyFilter: HistoryFilter = .all

    var filteredEntries: [QueryHistoryEntry] {
        var entries = appState.queryHistory

        // Apply source filter
        switch historyFilter {
        case .all:
            break
        case .app:
            entries = entries.filter { $0.source == .app }
        case .mcp:
            entries = entries.filter { $0.source == .mcp }
        }

        // Apply search filter
        if !searchText.isEmpty {
            entries = entries.filter {
                $0.query.localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar with filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Picker("", selection: $historyFilter) {
                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)

                Button {
                    appState.refreshQueryHistory()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh history")
                .accessibilityLabel("Refresh history")
            }
            .padding(12)
            .background(.background)

            Divider()

            if appState.queryHistory.isEmpty {
                emptyStateView
            } else if filteredEntries.isEmpty {
                noResultsView
            } else {
                historyList
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            appState.refreshQueryHistory()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 48 * fontScale.scaleFactor))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("No History Yet")
                .font(.system(size: 13 * fontScale.scaleFactor, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Your queries will appear here")
                .font(.system(size: 10 * fontScale.scaleFactor))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No query history yet. Your queries will appear here.")
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32 * fontScale.scaleFactor))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("No Results")
                .font(.system(size: 13 * fontScale.scaleFactor, weight: .semibold))
                .foregroundStyle(.secondary)

            if !searchText.isEmpty {
                Text("No queries match \"\(searchText)\"")
                    .font(.system(size: 10 * fontScale.scaleFactor))
                    .foregroundStyle(.tertiary)
            } else {
                Text("No \(historyFilter.rawValue.lowercased()) queries found")
                    .font(.system(size: 10 * fontScale.scaleFactor))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(noResultsAccessibilityLabel)
    }

    private var noResultsAccessibilityLabel: String {
        if !searchText.isEmpty {
            return "No queries match \"\(searchText)\""
        } else {
            return "No \(historyFilter.rawValue.lowercased()) queries found"
        }
    }

    private var historyList: some View {
        List(selection: $selectedEntry) {
            ForEach(filteredEntries) { entry in
                HistoryRowView(
                    entry: entry,
                    fontScale: fontScale,
                    onRun: { runQuery(entry.query) },
                    onCopy: { copyQuery(entry.query) },
                    onDelete: { deleteEntry(entry) }
                )
                .tag(entry)
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: QueryHistoryEntry.self) { selection in
            if let entry = selection.first {
                Button("Run Query") {
                    runQuery(entry.query)
                }
                Button("Copy") {
                    copyQuery(entry.query)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    deleteEntry(entry)
                }
            }
        }
    }

    private func runQuery(_ query: String) {
        Task {
            openWindow(id: "query")
            try? await Task.sleep(for: .milliseconds(100))
            await appState.runQuery(query)
        }
    }

    private func copyQuery(_ query: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(query, forType: .string)
    }

    private func deleteEntry(_ entry: QueryHistoryEntry) {
        withAnimation {
            appState.removeHistoryEntry(entry)
        }
    }
}

// MARK: - History Row

struct HistoryRowView: View {
    let entry: QueryHistoryEntry
    let fontScale: FontScale
    let onRun: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered: Bool = false

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.source == .mcp ? "server.rack" : "text.bubble")
                .foregroundStyle(entry.source == .mcp ? .blue : .secondary)
                .accessibilityLabel(entry.source == .mcp ? "MCP query" : "App query")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.query)
                        .lineLimit(2)
                        .font(.system(size: 13 * fontScale.scaleFactor))

                    if entry.source == .mcp {
                        Text("MCP")
                            .font(.system(size: 9 * fontScale.scaleFactor, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(timeAgo)
                        .font(.system(size: 10 * fontScale.scaleFactor))
                        .foregroundStyle(.tertiary)

                    if let rowCount = entry.rowCount {
                        Text("\(rowCount) rows")
                            .font(.system(size: 10 * fontScale.scaleFactor))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button {
                        onRun()
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                    .help("Run query")
                    .accessibilityLabel("Run query")

                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Copy query")
                    .accessibilityLabel("Copy query")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .help("Delete from history")
                    .accessibilityLabel("Delete from history")
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
