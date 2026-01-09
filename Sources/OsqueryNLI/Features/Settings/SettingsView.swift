import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView {
            ProviderSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Provider", systemImage: "cpu")
                }

            TableSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Tables", systemImage: "tablecells")
                }

            AppearanceSettingsView()
                .environment(appState)
                .tabItem {
                    Label("Appearance", systemImage: "textformat.size")
                }

            GeneralSettingsView()
                .environment(appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 500, height: 450)
    }
}

// MARK: - Provider Settings

struct ProviderSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKey: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var connectionResult: String?
    @State private var connectionSuccess: Bool = false
    @State private var keychainError: String?

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section {
                Picker("Provider", selection: $appState.selectedProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: appState.selectedProvider) { _, newValue in
                    apiKey = appState.getAPIKey(for: newValue)
                    appState.selectedModel = newValue.defaultModel
                    connectionResult = nil
                    keychainError = nil
                }

                Picker("Model", selection: $appState.selectedModel) {
                    ForEach(appState.selectedProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            Section("API Key") {
                SecureField(appState.selectedProvider.apiKeyPlaceholder, text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        saveAPIKey(newValue)
                    }

                // Show keychain error if any
                if let error = keychainError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                HStack {
                    Link("Get API Key", destination: appState.selectedProvider.helpURL)
                        .font(.caption)

                    Spacer()

                    Button {
                        testConnection()
                    } label: {
                        if isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(apiKey.isEmpty || isTestingConnection)
                }

                if let result = connectionResult {
                    HStack {
                        Image(systemName: connectionSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(connectionSuccess ? Color.green : Color.red)
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(connectionSuccess ? Color.secondary : Color.red)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Provider Information")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    switch appState.selectedProvider {
                    case .claude:
                        Text("Claude is Anthropic's AI assistant, known for nuanced understanding and detailed explanations.")
                    case .gemini:
                        Text("Gemini is Google's multimodal AI, offering fast responses and broad knowledge.")
                    case .openai:
                        Text("GPT models from OpenAI, widely used and well-documented.")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKey = appState.getAPIKey(for: appState.selectedProvider)
        }
    }

    private func saveAPIKey(_ key: String) {
        keychainError = nil
        do {
            try appState.setAPIKey(key, for: appState.selectedProvider)
        } catch {
            keychainError = error.localizedDescription
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionResult = nil

        Task {
            do {
                let result = try await appState.testConnection()
                connectionResult = result
                connectionSuccess = true
            } catch {
                connectionResult = error.localizedDescription
                connectionSuccess = false
            }
            isTestingConnection = false
        }
    }
}

// MARK: - Table Settings

struct TableSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var availableTables: [String] = []
    @State private var isLoadingTables: Bool = false
    @State private var newTableName: String = ""
    @State private var tableLoadError: String? = nil

    var filteredTables: [String] {
        if searchText.isEmpty {
            return availableTables
        }
        return availableTables.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tables...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.background)

            Divider()

            // Quick selection buttons
            HStack(spacing: 12) {
                Button {
                    appState.selectAllTables(availableTables)
                } label: {
                    Label("Select All", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(availableTables.isEmpty)

                Button {
                    appState.deselectAllTables()
                } label: {
                    Label("Deselect All", systemImage: "circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(appState.enabledTables.isEmpty)

                Button {
                    appState.resetTablesToDefault()
                } label: {
                    Label("Recommended", systemImage: "star.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Text("\(appState.enabledTables.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.background)

            Divider()

            if isLoadingTables {
                Spacer()
                ProgressView("Loading tables...")
                Spacer()
            } else {
                // Warning if tables couldn't be loaded
                if let error = tableLoadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                        Spacer()
                        Button("Retry") {
                            loadTables()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // Table list
                List {
                    Section("Enabled Tables") {
                        ForEach(filteredTables.filter { appState.enabledTables.contains($0) }, id: \.self) { table in
                            tableRow(table, isEnabled: true)
                        }
                    }

                    Section("Available Tables") {
                        ForEach(filteredTables.filter { !appState.enabledTables.contains($0) }, id: \.self) { table in
                            tableRow(table, isEnabled: false)
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Footer actions
            HStack {
                if !availableTables.isEmpty {
                    Text("\(availableTables.count) tables available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    loadTables()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding()
        }
        .onAppear {
            loadTables()
        }
    }

    private func tableRow(_ table: String, isEnabled: Bool) -> some View {
        HStack {
            Text(table)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Button {
                appState.toggleTable(table)
            } label: {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func loadTables() {
        isLoadingTables = true
        tableLoadError = nil
        Task {
            do {
                availableTables = try await appState.osqueryService.getAllTables()
                tableLoadError = nil
            } catch {
                tableLoadError = "Could not load tables from osquery. Using common tables instead."
                availableTables = Array(OsqueryService.commonTables).sorted()
            }
            isLoadingTables = false
        }
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Text Size") {
                Picker("Font Scale", selection: $appState.fontScale) {
                    ForEach(FontScale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
                .pickerStyle(.inline)

                Text(appState.fontScale.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Query Result")
                            .font(.system(size: 13 * appState.fontScale.scaleFactor, weight: .semibold))
                        Text("This is how body text will appear in the app.")
                            .font(.system(size: 13 * appState.fontScale.scaleFactor))
                        Text("Caption text for additional details")
                            .font(.system(size: 10 * appState.fontScale.scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Changes apply immediately to all views.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Note: Some UI elements may require reopening windows to update.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showClearConfirmation: Bool = false
    @State private var showCopiedToast: Bool = false
    @State private var copiedConfigType: String = ""

    /// App version from Info.plist
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("AI Discovery") {
                Toggle("Enable AI Discovery Tables", isOn: $appState.aiDiscoveryEnabled)

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.osqueryService.isAIDiscoveryAvailable ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(appState.osqueryService.isAIDiscoveryAvailable ? "Available" : "Not Available")
                            .foregroundStyle(.secondary)
                    }
                }

                if appState.aiDiscoveryEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tables: ai_tools_installed, ai_mcp_servers, ai_env_vars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Query installed AI tools, MCP configurations, and AI-related environment variables.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("MCP Server") {
                Toggle("Enable MCP Server", isOn: $appState.mcpServerEnabled)

                Toggle("Start automatically with app", isOn: $appState.mcpAutoStart)
                    .disabled(!appState.mcpServerEnabled)

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.mcpServerRunning ? Color.green : (appState.mcpServerError != nil ? Color.red : Color.secondary))
                            .frame(width: 8, height: 8)
                        Text(appState.mcpServerRunning ? "Running" : "Stopped")
                            .foregroundStyle(.secondary)
                    }
                }

                // Show MCP server error if any
                if let error = appState.mcpServerError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                DisclosureGroup("Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Path:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appState.mcpServerPath)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)

                        Divider()

                        Text("Copy config to clipboard:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button("Claude Desktop") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(appState.claudeDesktopConfig(), forType: .string)
                                copiedConfigType = "Claude Desktop"
                                showCopiedToast = true
                            }
                            .buttonStyle(.bordered)

                            Button("Cursor") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(appState.cursorConfig(), forType: .string)
                                copiedConfigType = "Cursor"
                                showCopiedToast = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if showCopiedToast {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(copiedConfigType) config copied!")
                                    .font(.caption)
                            }
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        showCopiedToast = false
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("History") {
                HStack {
                    Text("Recent queries")
                    Spacer()
                    Text("\(appState.queryHistory.count) items")
                        .foregroundStyle(.secondary)
                }

                Button("Clear History", role: .destructive) {
                    showClearConfirmation = true
                }
                .confirmationDialog(
                    "Clear all query history?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear History", role: .destructive) {
                        appState.clearQueryHistory()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("macOS")
                    Spacer()
                    Text(ProcessInfo.processInfo.operatingSystemVersionString)
                        .foregroundStyle(.secondary)
                }

                Link("View on GitHub", destination: URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
    }
}
