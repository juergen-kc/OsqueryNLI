import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct QueryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: QueryViewModel?
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

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

                // Escape to cancel
                Button("") {
                    if vm.isQuerying {
                        vm.cancelQuery()
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
            }
        )
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

            TextField("Ask about your system...", text: $bindableVM.queryText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...3)
                .focused($isInputFocused)
                .onSubmit {
                    vm.submitQuery()
                }
                .disabled(vm.isQuerying)
                .onKeyPress(.upArrow) {
                    vm.navigateHistoryUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    vm.navigateHistoryDown()
                    return .handled
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
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .sheet(isPresented: $bindableVM.showingTemplates) {
            QueryTemplatesView { query in
                vm.selectTemplate(query)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(_ vm: QueryViewModel) -> some View {
        if vm.isQuerying {
            loadingView(vm)
        } else if let error = vm.lastError {
            errorView(vm, error: error)
        } else if let result = vm.lastResult {
            resultContentView(vm, result: result)
        } else {
            emptyStateView(vm)
        }
    }

    private func loadingView(_ vm: QueryViewModel) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            // Show current stage
            Text(vm.queryStage.rawValue.isEmpty ? "Processing query..." : vm.queryStage.rawValue)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: vm.queryStage)

            // Show stage indicator
            HStack(spacing: 8) {
                stageIndicator(vm, stage: .translating, current: vm.queryStage)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                stageIndicator(vm, stage: .executing, current: vm.queryStage)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                stageIndicator(vm, stage: .summarizing, current: vm.queryStage)
            }
            .padding(.top, 8)

            if !vm.currentQuery.isEmpty {
                Text("\"\(vm.currentQuery)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            // Cancel button
            Button {
                vm.cancelQuery()
            } label: {
                Label("Cancel (Esc)", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 8)
            .help("Cancel query (Esc)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func stageIndicator(_ vm: QueryViewModel, stage: AppState.QueryStage, current: AppState.QueryStage) -> some View {
        let isActive = current == stage
        let isPast = vm.stageOrder(current) > vm.stageOrder(stage)

        return HStack(spacing: 4) {
            Circle()
                .fill(isActive ? Color.accentColor : (isPast ? Color.green : Color.secondary.opacity(0.3)))
                .frame(width: 8, height: 8)
            Text(vm.stageName(stage))
                .font(.caption2)
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
        }
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
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

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
                        Button {
                            vm.queryText = example
                            vm.submitQuery()
                        } label: {
                            Text(example)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.quaternary.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
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
            Text("⌘↩ Submit • ⌘K Clear • ↑↓ History")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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

                // Execution time
                HStack {
                    Spacer()
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

    // Calculate column widths based on content
    private var columnWidths: [String: CGFloat] {
        var widths: [String: CGFloat] = [:]

        for column in result.columns {
            // Start with header width (estimate 8pt per character + padding)
            var maxWidth = CGFloat(column.name.count) * 8 + 24

            // Check all row values
            for row in result.rows {
                if let value = row[column.name] {
                    let valueWidth = CGFloat(min(value.count, 40)) * 7 + 24
                    maxWidth = max(maxWidth, valueWidth)
                }
            }

            // Clamp between min and max
            widths[column.name] = min(max(maxWidth, 60), 250)
        }

        return widths
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Data rows
                    ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            ForEach(result.columns) { column in
                                Text(row[column.name] ?? "-")
                                    .font(.system(.caption, design: .monospaced))
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
                    // Sticky header row
                    HStack(spacing: 0) {
                        ForEach(result.columns) { column in
                            Text(column.name)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: columnWidths[column.name] ?? 100, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
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

    private func alternatingRowColor(index: Int) -> Color {
        if index % 2 == 0 {
            return Color.clear
        } else {
            return colorScheme == .dark
                ? Color.white.opacity(0.03)
                : Color.black.opacity(0.03)
        }
    }
}
