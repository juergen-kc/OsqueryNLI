import SwiftUI

/// Sheet for adding or editing a scheduled query
struct AddScheduledQuerySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Existing query to edit, or nil for new query
    var existingQuery: ScheduledQuery?

    @State private var name: String = ""
    @State private var query: String = ""
    @State private var isSQL: Bool = false
    @State private var interval: ScheduleInterval = .hourly
    @State private var enableAlert: Bool = false
    @State private var alertCondition: AlertCondition = .anyResults
    @State private var notifyOnMatch: Bool = true
    @State private var notifyOnChange: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var testError: String?

    private var isEditing: Bool { existingQuery != nil }
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(existingQuery: ScheduledQuery? = nil) {
        self.existingQuery = existingQuery
        if let existing = existingQuery {
            _name = State(initialValue: existing.name)
            _query = State(initialValue: existing.query)
            _isSQL = State(initialValue: existing.isSQL)
            _interval = State(initialValue: existing.interval)
            if let alert = existing.alertRule {
                _enableAlert = State(initialValue: true)
                _alertCondition = State(initialValue: alert.condition)
                _notifyOnMatch = State(initialValue: alert.notifyOnMatch)
                _notifyOnChange = State(initialValue: alert.notifyOnChange)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Scheduled Query" : "Add Scheduled Query")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Query section
                    GroupBox("Query") {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Name", text: $name, prompt: Text("e.g., High CPU Processes"))
                                .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(isSQL ? "SQL Query" : "Natural Language Question")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextEditor(text: $query)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 60, maxHeight: 120)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            Toggle("Raw SQL (instead of natural language)", isOn: $isSQL)
                                .toggleStyle(.checkbox)
                        }
                        .padding(8)
                    }

                    // Schedule section
                    GroupBox("Schedule") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Run", selection: $interval) {
                                ForEach(ScheduleInterval.allCases, id: \.self) { interval in
                                    Text(interval.displayName).tag(interval)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("Query will run in the background at the specified interval.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                    }

                    // Alert section
                    GroupBox("Alert") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable alert notifications", isOn: $enableAlert)
                                .toggleStyle(.checkbox)

                            if enableAlert {
                                AlertConditionPicker(condition: $alertCondition)

                                Divider()

                                Toggle("Notify when condition is met", isOn: $notifyOnMatch)
                                    .toggleStyle(.checkbox)

                                Toggle("Notify when result count changes", isOn: $notifyOnChange)
                                    .toggleStyle(.checkbox)

                                if !appState.notificationsEnabled {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Notifications not enabled")
                                            .font(.caption)
                                        Button("Enable") {
                                            Task {
                                                await appState.enableNotifications()
                                            }
                                        }
                                        .buttonStyle(.link)
                                    }
                                }
                            }
                        }
                        .padding(8)
                    }

                    // Test section
                    GroupBox("Test") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Test Query") {
                                    testQuery()
                                }
                                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                                if isTesting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }

                            if let result = testResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            if let error = testError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(isEditing ? "Save" : "Add") {
                    saveQuery()
                }
                .keyboardShortcut(.return)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func testQuery() {
        isTesting = true
        testResult = nil
        testError = nil

        Task {
            do {
                if isSQL {
                    let results = try await appState.osqueryService.execute(query)
                    await MainActor.run {
                        testResult = "Success: \(results.count) row\(results.count == 1 ? "" : "s") returned"
                        isTesting = false
                    }
                } else {
                    let schema = try await appState.osqueryService.getSchema(for: Array(appState.enabledTables))
                    let translation = try await appState.currentLLMService.translateToSQL(
                        query: query,
                        schemaContext: schema
                    )
                    let results = try await appState.osqueryService.execute(translation.sql)
                    await MainActor.run {
                        testResult = "Success: Translated to SQL and returned \(results.count) row\(results.count == 1 ? "" : "s")"
                        isTesting = false
                    }
                }
            } catch {
                await MainActor.run {
                    testError = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }

    private func saveQuery() {
        let alertRule: AlertRule?
        if enableAlert {
            alertRule = AlertRule(
                condition: alertCondition,
                notifyOnMatch: notifyOnMatch,
                notifyOnChange: notifyOnChange
            )
        } else {
            alertRule = nil
        }

        if let existing = existingQuery {
            // Update existing
            var updated = existing
            updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.isSQL = isSQL
            updated.interval = interval
            updated.alertRule = alertRule
            appState.updateScheduledQuery(updated)
        } else {
            // Create new
            let newQuery = ScheduledQuery(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                isSQL: isSQL,
                interval: interval,
                alertRule: alertRule
            )
            appState.addScheduledQuery(newQuery)
        }

        dismiss()
    }
}
