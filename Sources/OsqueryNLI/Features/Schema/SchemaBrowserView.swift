import SwiftUI

/// Schema Browser - Visual browser for osquery tables and columns
struct SchemaBrowserView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.fontScale) private var fontScale

    @State private var searchText: String = ""
    @State private var selectedTable: String?
    @State private var columnInfos: [ColumnInfoItem] = []
    @State private var isLoadingColumns: Bool = false
    @State private var allTables: [String] = []
    @State private var isLoadingTables: Bool = true
    @State private var showEnabledOnly: Bool = false

    /// Represents a column in a table
    struct ColumnInfoItem: Identifiable {
        let id = UUID()
        let name: String
        let type: String
    }

    var body: some View {
        HSplitView {
            // Left panel - Table list
            tableListPanel
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)

            // Right panel - Column details
            columnDetailsPanel
                .frame(minWidth: 300)
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadTables()
        }
    }

    // MARK: - Table List Panel

    private var tableListPanel: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tables...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.background)

            Divider()

            // Filter toggle
            HStack {
                Toggle("Enabled only", isOn: $showEnabledOnly)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Text("\(filteredTables.count) tables")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.background.opacity(0.5))

            Divider()

            // Table list
            if isLoadingTables {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading tables...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTables, id: \.self) { table in
                            TableRowView(
                                table: table,
                                isSelected: selectedTable == table,
                                isEnabled: appState.enabledTables.contains(table),
                                isAITable: OsqueryService.aiDiscoveryTables.contains(table)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectTable(table)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(.background)
    }

    // MARK: - Column Details Panel

    private var columnDetailsPanel: some View {
        VStack(spacing: 0) {
            if let table = selectedTable {
                // Table header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(table)
                                .font(.headline)

                            if OsqueryService.aiDiscoveryTables.contains(table) {
                                Text("AI")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.purple.opacity(0.2))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }

                            if appState.enabledTables.contains(table) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }

                        Text("\(columnInfos.count) columns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Toggle enabled button
                    Button(action: {
                        appState.toggleTable(table)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: appState.enabledTables.contains(table) ? "checkmark.circle.fill" : "circle")
                            Text(appState.enabledTables.contains(table) ? "Enabled" : "Enable")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    // Copy schema button
                    Button(action: {
                        copySchemaToClipboard(table: table)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("Copy schema to clipboard")
                }
                .padding()
                .background(.background)

                Divider()

                // Column list
                if isLoadingColumns {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Loading columns...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else if columnInfos.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "tablecells")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No columns found")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    // Column list using ScrollView + LazyVStack for compatibility
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Header row
                            HStack {
                                Text("Column Name")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 150, alignment: .leading)
                                Spacer()
                                Text("Type")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor))

                            Divider()

                            ForEach(columnInfos) { column in
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: iconForType(column.type))
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text(column.name)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    .frame(minWidth: 150, alignment: .leading)

                                    Spacer()

                                    Text(column.type)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 100, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)

                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            } else {
                // No table selected
                VStack(spacing: 12) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a table")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Choose a table from the list to view its columns")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Helpers

    private var filteredTables: [String] {
        var tables = allTables

        if showEnabledOnly {
            tables = tables.filter { appState.enabledTables.contains($0) }
        }

        if !searchText.isEmpty {
            tables = tables.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }

        return tables
    }

    private func loadTables() async {
        isLoadingTables = true
        do {
            allTables = try await appState.osqueryService.getAllTables()
        } catch {
            allTables = Array(OsqueryService.commonTables).sorted()
        }
        isLoadingTables = false
    }

    private func selectTable(_ table: String) {
        selectedTable = table
        loadColumns(for: table)
    }

    private func loadColumns(for table: String) {
        isLoadingColumns = true
        columnInfos = []

        Task {
            // First check if it's an AI table with hardcoded schema
            if let schema = OsqueryService.aiTableSchemas[table] {
                columnInfos = parseSchemaToColumns(schema)
                isLoadingColumns = false
                return
            }

            // Otherwise fetch from osquery
            do {
                let schema = try await appState.osqueryService.getSchema(for: [table])
                columnInfos = parseSchemaToColumns(schema)
            } catch {
                columnInfos = []
            }
            isLoadingColumns = false
        }
    }

    private func parseSchemaToColumns(_ schema: String) -> [ColumnInfoItem] {
        // Parse CREATE TABLE format to extract columns
        var columns: [ColumnInfoItem] = []

        // osquery schema format: CREATE TABLE name(`col1` TYPE, `col2` TYPE, ...);
        // Also handle multi-line format: col_name TYPE,

        // Pattern for backtick-quoted columns (osquery native format)
        // Matches: `column_name` TYPE
        let backtickPattern = #"`(\w+)`\s+(TEXT|INTEGER|BIGINT|REAL|BLOB|DOUBLE|UNSIGNED BIGINT|DATETIME)"#

        if let regex = try? NSRegularExpression(pattern: backtickPattern, options: .caseInsensitive) {
            let range = NSRange(schema.startIndex..., in: schema)
            let matches = regex.matches(in: schema, options: [], range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: schema),
                   let typeRange = Range(match.range(at: 2), in: schema) {
                    let name = String(schema[nameRange])
                    let type = String(schema[typeRange]).uppercased()
                    columns.append(ColumnInfoItem(name: name, type: type))
                }
            }
        }

        // If no backtick matches found, try multi-line format (for AI tables)
        if columns.isEmpty {
            let multilinePattern = #"^\s*(\w+)\s+(TEXT|INTEGER|BIGINT|REAL|BLOB|DOUBLE|UNSIGNED BIGINT|DATETIME)"#

            for line in schema.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if let regex = try? NSRegularExpression(pattern: multilinePattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                    if let nameRange = Range(match.range(at: 1), in: trimmed),
                       let typeRange = Range(match.range(at: 2), in: trimmed) {
                        let name = String(trimmed[nameRange])
                        let type = String(trimmed[typeRange]).uppercased()
                        columns.append(ColumnInfoItem(name: name, type: type))
                    }
                }
            }
        }

        return columns
    }

    private func iconForType(_ type: String) -> String {
        switch type.uppercased() {
        case "TEXT":
            return "textformat"
        case "INTEGER", "BIGINT", "UNSIGNED BIGINT":
            return "number"
        case "REAL", "DOUBLE":
            return "function"
        case "DATETIME":
            return "calendar"
        case "BLOB":
            return "doc"
        default:
            return "questionmark.circle"
        }
    }

    private func copySchemaToClipboard(table: String) {
        Task {
            var schema = ""
            if let aiSchema = OsqueryService.aiTableSchemas[table] {
                schema = aiSchema
            } else {
                schema = (try? await appState.osqueryService.getSchema(for: [table])) ?? ""
            }

            if !schema.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(schema, forType: .string)
            }
        }
    }
}

// MARK: - Table Row View

private struct TableRowView: View {
    let table: String
    let isSelected: Bool
    let isEnabled: Bool
    let isAITable: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: isAITable ? "cpu" : "tablecells")
                .foregroundStyle(isAITable ? .purple : .secondary)
                .frame(width: 20)

            // Table name
            Text(table)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // Enabled indicator
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
}
