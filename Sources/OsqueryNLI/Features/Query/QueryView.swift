import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct QueryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: QueryViewModel?
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingKeyboardShortcuts = false

    var body: some View {
        Group {
            if let vm = viewModel {
                contentView(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if viewModel == nil {
                viewModel = QueryViewModel(appState: appState)
            }
            isInputFocused = true
            if !appState.isOsqueryAvailable && !appState.isCheckingOsquery {
                appState.refreshOsqueryStatus()
            }
        }
    }

    @ViewBuilder
    private func contentView(_ vm: QueryViewModel) -> some View {
        if vm.isCheckingOsquery {
            ProgressView("Checking osquery...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !vm.isOsqueryAvailable {
            OsqueryMissingView {
                vm.refreshOsqueryStatus()
            }
        } else {
            mainContentView(vm)
        }
    }

    private func mainContentView(_ vm: QueryViewModel) -> some View {
        VStack(spacing: 0) {
            // Header with provider badge
            headerView(vm)

            Divider()

            // Query input
            queryInputView(vm)
                .padding()

            Divider()

            // Results area
            resultsView(vm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        // Keyboard shortcuts
        .background(
            Group {
                // Cmd+Enter to submit
                Button("") { vm.submitQuery() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .opacity(0)

                // Cmd+K to clear
                Button("") {
                    vm.clearAndReset()
                    isInputFocused = true
                }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0)

                // Escape to cancel query or exit history
                Button("") {
                    if vm.isQuerying {
                        vm.cancelQuery()
                    } else if vm.isBrowsingHistory {
                        vm.exitHistoryBrowsing()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)

                // Cmd+? to show keyboard shortcuts
                Button("") { showingKeyboardShortcuts = true }
                    .keyboardShortcut("/", modifiers: [.command, .shift])
                    .opacity(0)
            }
        )
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .overlay(alignment: .bottom) {
            if vm.showSaveResult {
                saveResultToast(vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showSaveResult)
    }

    private func saveResultToast(_ vm: QueryViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: vm.saveResultSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(vm.saveResultSuccess ? .green : .red)
            Text(vm.saveResultMessage)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    // MARK: - Header

    private func headerView(_ vm: QueryViewModel) -> some View {
        HStack {
            // Back/New Query button when showing results
            if vm.hasResults {
                Button {
                    vm.clearAndReset()
                    isInputFocused = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("New Query")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Start new query (⌘K)")

                // Favorite button for current query
                if !vm.currentQuery.isEmpty {
                    Button {
                        vm.toggleFavorite()
                    } label: {
                        Image(systemName: vm.isFavorite(vm.currentQuery) ? "star.fill" : "star")
                            .foregroundStyle(vm.isFavorite(vm.currentQuery) ? .yellow : .secondary)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(vm.isFavorite(vm.currentQuery) ? "Remove from favorites" : "Add to favorites")
                }
            } else {
                Text("Osquery NLI")
                    .font(.headline)

                // Favorites menu
                if !vm.favorites.isEmpty {
                    Menu {
                        ForEach(vm.favorites) { favorite in
                            Button {
                                vm.selectFavorite(favorite)
                            } label: {
                                Label(favorite.displayName, systemImage: "star.fill")
                            }
                        }
                    } label: {
                        Label("\(vm.favorites.count)", systemImage: "star.fill")
                            .font(.caption)
                    }
                    .menuStyle(.borderedButton)
                    .fixedSize()
                    .help("Favorites")
                }
            }

            Spacer()

            // Provider badge
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.caption)
                Text(vm.selectedProvider.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Query Input

    @ViewBuilder
    private func queryInputView(_ vm: QueryViewModel) -> some View {
        @Bindable var bindableVM = vm

        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Templates button
                Button {
                    vm.showingTemplates = true
                } label: {
                    Image(systemName: "rectangle.stack")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Browse query templates")
                .accessibilityLabel("Browse query templates")

                // Recent queries dropdown
                if !vm.recentQueries.isEmpty {
                    Menu {
                        ForEach(vm.recentQueries, id: \.self) { query in
                            Button {
                                vm.selectRecentQuery(query)
                            } label: {
                                Text(query)
                                    .lineLimit(1)
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                    .help("Recent queries")
                    .accessibilityLabel("Recent queries")
                }

                TextField("Ask about your system...", text: $bindableVM.queryText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1...3)
                    .focused($isInputFocused)
                    .onSubmit {
                        if vm.showAutoComplete {
                            vm.selectCurrentSuggestion()
                        } else {
                            vm.submitQuery()
                        }
                    }
                    .disabled(vm.isQuerying)
                    .onKeyPress(.upArrow) {
                        if vm.showAutoComplete {
                            vm.navigateSuggestionUp()
                        } else {
                            vm.navigateHistoryUp()
                        }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        if vm.showAutoComplete {
                            vm.navigateSuggestionDown()
                        } else {
                            vm.navigateHistoryDown()
                        }
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        if vm.showAutoComplete {
                            vm.dismissAutoComplete()
                            return .handled
                        }
                        return .ignored
                    }
                    .onChange(of: vm.queryText) { _, _ in
                        vm.updateAutoComplete()
                    }

                Button {
                    vm.submitQuery()
                } label: {
                    if vm.isQuerying {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(vm.queryText.isEmpty ? Color.secondary : Color.accentColor)
                .disabled(!vm.canSubmit)
                .help("Submit query (⌘↩)")
                .accessibilityLabel("Submit query")
            }
            .padding(12)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                // Auto-complete dropdown
                if vm.showAutoComplete {
                    AutoCompleteDropdown(
                        suggestions: vm.autoCompleteSuggestions,
                        selectedIndex: vm.selectedSuggestionIndex,
                        onSelect: { suggestion in
                            vm.selectSuggestion(suggestion)
                        }
                    )
                    .offset(y: 50)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.15), value: vm.showAutoComplete)

            // Input hint
            if vm.isBrowsingHistory {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("Browsing history")
                        .font(.caption2)
                    Text("• ↓ for newer • Esc to exit")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: vm.isBrowsingHistory)
        .sheet(isPresented: $bindableVM.showingTemplates) {
            QueryTemplatesView { query in
                vm.selectTemplate(query)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(_ vm: QueryViewModel) -> some View {
        Group {
            if vm.isQuerying {
                loadingView(vm)
            } else if let error = vm.lastError {
                errorView(vm, error: error)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else if let result = vm.lastResult {
                resultContentView(vm, result: result)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                emptyStateView(vm)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.isQuerying)
    }

    private func loadingView(_ vm: QueryViewModel) -> some View {
        VStack(spacing: 20) {
            // Animated stage icon
            AnimatedStageIcon(stage: vm.queryStage)
                .frame(width: 60, height: 60)

            // Show current stage
            Text(vm.queryStage.rawValue.isEmpty ? "Processing query..." : vm.queryStage.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Show stage indicator
            HStack(spacing: 12) {
                stageIndicator(vm, stage: .translating, current: vm.queryStage)
                StageConnector(isActive: vm.stageOrder(vm.queryStage) >= vm.stageOrder(.executing))
                stageIndicator(vm, stage: .executing, current: vm.queryStage)
                StageConnector(isActive: vm.stageOrder(vm.queryStage) >= vm.stageOrder(.summarizing))
                stageIndicator(vm, stage: .summarizing, current: vm.queryStage)
            }
            .padding(.top, 4)

            if !vm.currentQuery.isEmpty {
                Text("\"\(vm.currentQuery)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            // Cancel button
            Button {
                vm.cancelQuery()
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .keyboardShortcut(.escape, modifiers: [])
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stageIndicator(_ vm: QueryViewModel, stage: AppState.QueryStage, current: AppState.QueryStage) -> some View {
        let isActive = current == stage
        let isPast = vm.stageOrder(current) > vm.stageOrder(stage)
        let status = isActive ? "in progress" : (isPast ? "completed" : "pending")

        return HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color.secondary.opacity(0.5)))
                .frame(width: 8, height: 8)
                .scaleEffect(isActive ? 1.0 : 0.9)
                .animation(.easeInOut(duration: 0.3), value: isActive)
            Text(vm.stageName(stage))
                .font(.caption2)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(vm.stageName(stage)) stage, \(status)")
    }

    private func errorView(_ vm: QueryViewModel, error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Error")
                .font(.headline)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Retry and New Query buttons
            HStack(spacing: 12) {
                if !vm.currentQuery.isEmpty {
                    Button {
                        vm.retryLastQuery()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                Button {
                    vm.clearAndReset()
                    isInputFocused = true
                } label: {
                    Label("New Query", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyStateView(_ vm: QueryViewModel) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text("Ask a question about your system")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Quick start templates
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Start")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(vm.exampleQueries, id: \.self) { example in
                        QuickStartButton(text: example) {
                            vm.queryText = example
                            vm.submitQuery()
                        }
                    }
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Templates button
            Button {
                vm.showingTemplates = true
            } label: {
                Label("Browse All Templates", systemImage: "rectangle.stack")
            }
            .buttonStyle(.bordered)

            // Keyboard shortcuts hint
            HStack(spacing: 16) {
                shortcutHint("⌘↩", "Submit")
                shortcutHint("⌘K", "Clear")
                shortcutHint("↑↓", "History")
                shortcutHint("⌘?", "Help")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func resultContentView(_ vm: QueryViewModel, result: QueryResult) -> some View {
        @Bindable var bindableVM = vm

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Summary
                if let summary = result.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Summary", systemImage: "text.quote")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // SQL with syntax highlighting
                CopyableSQLView(sql: result.sql)

                // Results table
                if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("\(result.rowCount) row\(result.rowCount == 1 ? "" : "s")", systemImage: "tablecells")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Export menu with copy and save options
                            Menu {
                                Section("Copy to Clipboard") {
                                    Button {
                                        vm.copyToClipboard(result.toJSON())
                                    } label: {
                                        Label("Copy as JSON", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        vm.copyToClipboard(result.toCSV())
                                    } label: {
                                        Label("Copy as CSV", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        vm.copyToClipboard(result.toMarkdown())
                                    } label: {
                                        Label("Copy as Markdown", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        vm.copyToClipboard(result.toTextTable())
                                    } label: {
                                        Label("Copy as Table", systemImage: "doc.on.doc")
                                    }
                                }

                                Divider()

                                Section("Save to File") {
                                    Button {
                                        vm.saveToFile(content: result.toJSON(), defaultName: "query_results.json", fileType: "json")
                                    } label: {
                                        Label("Save as JSON...", systemImage: "square.and.arrow.down")
                                    }
                                    Button {
                                        vm.saveToFile(content: result.toCSV(), defaultName: "query_results.csv", fileType: "csv")
                                    } label: {
                                        Label("Save as CSV...", systemImage: "square.and.arrow.down")
                                    }
                                    Button {
                                        vm.saveToFile(content: result.toMarkdown(), defaultName: "query_results.md", fileType: "md")
                                    } label: {
                                        Label("Save as Markdown...", systemImage: "square.and.arrow.down")
                                    }
                                    Button {
                                        if let xlsxData = result.toXLSX() {
                                            vm.saveXLSXToFile(data: xlsxData, defaultName: "query_results.xlsx")
                                        }
                                    } label: {
                                        Label("Save as Excel...", systemImage: "square.and.arrow.down")
                                    }
                                }

                                if vm.hasRecentExports {
                                    Divider()

                                    Section("Export Again") {
                                        ForEach(vm.recentExports) { export in
                                            Button {
                                                vm.exportToRecentLocation(export, result: result)
                                            } label: {
                                                Label {
                                                    VStack(alignment: .leading) {
                                                        Text(export.fileName)
                                                        Text(export.directoryPath)
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                } icon: {
                                                    Image(systemName: export.fileType.icon)
                                                }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                            .menuStyle(.borderedButton)
                            .fixedSize()

                            Button {
                                vm.showRawData.toggle()
                            } label: {
                                Image(systemName: vm.showRawData ? "tablecells" : "curlybraces")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(vm.showRawData ? "Show table view" : "Show raw JSON")
                            .accessibilityLabel(vm.showRawData ? "Show table view" : "Show raw JSON")
                        }

                        if vm.showRawData {
                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(result.toJSON())
                                    .font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .frame(maxHeight: 200)
                            .padding(8)
                            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            ResultsTableView(result: result, colorScheme: colorScheme)
                                .frame(minHeight: 100, maxHeight: 400)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack {
                        Image(systemName: "tray")
                        Text("Query returned no results")
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Execution time and token usage
                HStack {
                    Spacer()

                    // Token usage
                    if let tokenUsage = result.tokenUsage {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("\(tokenUsage.totalTokens) tokens")
                                .font(.caption2)
                            Text("(\(tokenUsage.inputTokens) in / \(tokenUsage.outputTokens) out)")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                        }
                        .foregroundStyle(.tertiary)

                        Text("•")
                            .foregroundStyle(.quaternary)
                    }

                    Text("Completed in \(String(format: "%.2f", result.executionTime))s")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Results Table

struct ResultsTableView: View {
    let result: QueryResult
    let colorScheme: ColorScheme
    @Environment(\.fontScale) private var fontScale

    /// Sorting state
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true

    /// Maximum rows to display in the table view for performance
    private static let maxDisplayRows = 1000

    /// Whether results are truncated for display
    private var isTruncated: Bool {
        sortedRows.count > Self.maxDisplayRows
    }

    /// Sorted rows based on current sort column
    private var sortedRows: [[String: String]] {
        guard let column = sortColumn else { return result.rows }

        return result.rows.sorted { row1, row2 in
            let val1 = row1[column] ?? ""
            let val2 = row2[column] ?? ""

            // Try numeric comparison first
            if let num1 = Double(val1), let num2 = Double(val2) {
                return sortAscending ? num1 < num2 : num1 > num2
            }

            // Fall back to string comparison
            return sortAscending
                ? val1.localizedCaseInsensitiveCompare(val2) == .orderedAscending
                : val1.localizedCaseInsensitiveCompare(val2) == .orderedDescending
        }
    }

    /// Rows to display (limited for performance)
    private var displayRows: ArraySlice<[String: String]> {
        sortedRows.prefix(Self.maxDisplayRows)
    }

    /// Base font size for table content (scaled by fontScale)
    private var scaledFontSize: CGFloat {
        10 * fontScale.scaleFactor
    }

    /// Base font size for table headers (scaled by fontScale)
    private var scaledHeaderFontSize: CGFloat {
        10 * fontScale.scaleFactor
    }

    // Calculate column widths based on content (samples first 100 rows for performance)
    private var columnWidths: [String: CGFloat] {
        var widths: [String: CGFloat] = [:]
        let sampleRows = result.rows.prefix(100)
        let charWidth = 7 * fontScale.scaleFactor

        for column in result.columns {
            // Start with header width (estimate scaled char width + padding)
            var maxWidth = CGFloat(column.name.count) * charWidth + 24

            // Check sampled row values
            for row in sampleRows {
                if let value = row[column.name] {
                    let valueWidth = CGFloat(min(value.count, 40)) * charWidth + 24
                    maxWidth = max(maxWidth, valueWidth)
                }
            }

            // Clamp between min and max (scaled)
            let minWidth: CGFloat = 60 * fontScale.scaleFactor
            let maxWidthLimit: CGFloat = 250 * fontScale.scaleFactor
            widths[column.name] = min(max(maxWidth, minWidth), maxWidthLimit)
        }

        return widths
    }

    var body: some View {
        VStack(spacing: 0) {
            if isTruncated {
                truncationWarning
            }

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        // Data rows (limited)
                        ForEach(Array(displayRows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 0) {
                                ForEach(result.columns) { column in
                                    Text(row[column.name] ?? "-")
                                        .font(.system(size: scaledFontSize, design: .monospaced))
                                        .textSelection(.enabled)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .frame(width: columnWidths[column.name] ?? 100, alignment: .leading)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .help(row[column.name] ?? "-") // Show full value on hover
                                }
                            }
                            .background(alternatingRowColor(index: index))
                        }
                    } header: {
                        // Sticky header row with sortable columns
                        HStack(spacing: 0) {
                            ForEach(result.columns) { column in
                                Button {
                                    toggleSort(column.name)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(column.name)
                                            .font(.system(size: scaledHeaderFontSize, weight: .semibold))
                                            .foregroundStyle(.primary)

                                        if sortColumn == column.name {
                                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .frame(width: columnWidths[column.name] ?? 100, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Click to sort by \(column.name)")
                            }
                        }
                        .background(
                            colorScheme == .dark
                                ? Color(nsColor: .controlBackgroundColor)
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .overlay(alignment: .bottom) {
                            Divider()
                        }
                    }
                }
            }
            .background(colorScheme == .dark ? Color(nsColor: .textBackgroundColor) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    private var truncationWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Showing first \(Self.maxDisplayRows) of \(result.rows.count) rows. Export to view all results.")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func alternatingRowColor(index: Int) -> Color {
        if index % 2 == 0 {
            return Color.clear
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.03)
                : Color.black.opacity(0.03)
        }
    }

    private func toggleSort(_ column: String) {
        if sortColumn == column {
            // Toggle direction or clear sort
            if sortAscending {
                sortAscending = false
            } else {
                // Third click clears sorting
                sortColumn = nil
                sortAscending = true
            }
        } else {
            // New column, sort ascending
            sortColumn = column
            sortAscending = true
        }
    }
}

// MARK: - Quick Start Button

private struct QuickStartButton: View {
    let text: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(isHovered ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Keyboard Shortcut Hint

private struct shortcutHint: View {
    let shortcut: String
    let label: String

    init(_ shortcut: String, _ label: String) {
        self.shortcut = shortcut
        self.label = label
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(shortcut)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Auto-Complete Dropdown

private struct AutoCompleteDropdown: View {
    let suggestions: [QueryViewModel.Suggestion]
    let selectedIndex: Int
    let onSelect: (QueryViewModel.Suggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                AutoCompleteSuggestionRow(
                    suggestion: suggestion,
                    isSelected: index == selectedIndex,
                    onSelect: { onSelect(suggestion) }
                )
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AutoCompleteSuggestionRow: View {
    let suggestion: QueryViewModel.Suggestion
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: suggestion.type.icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.displayText)
                        .font(.callout)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if suggestion.type == .table {
                        Text("Table")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Text("↩")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected || isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .table: return .blue
        case .template: return .purple
        case .favorite: return .yellow
        case .history: return .secondary
        }
    }
}

// MARK: - Loading State Components

private struct AnimatedStageIcon: View {
    let stage: AppState.QueryStage
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.accentColor.opacity(0.1))

            // Rotating ring for active state
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 3)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)

            // Stage icon
            Image(systemName: stageIcon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating, value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }

    private var stageIcon: String {
        switch stage {
        case .idle: return "sparkles"
        case .translating: return "text.badge.star"
        case .executing: return "terminal"
        case .summarizing: return "text.quote"
        }
    }
}

private struct StageConnector: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.green : Color.secondary.opacity(0.3))
            .frame(width: 24, height: 2)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}
