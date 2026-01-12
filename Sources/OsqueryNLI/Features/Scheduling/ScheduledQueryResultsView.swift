import SwiftUI
import Charts

/// View showing results history for a scheduled query
struct ScheduledQueryResultsView: View {
    let query: ScheduledQuery
    @State private var results: [ScheduledQueryResult] = []
    @State private var selectedTab = 0
    @State private var selectedResult: ScheduledQueryResult?
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            if results.isEmpty {
                emptyState
            } else {
                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Latest Results").tag(0)
                    Text("History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on tab
                if selectedTab == 0 {
                    latestResultsTab
                } else {
                    historyTab
                }
            }
        }
        .frame(width: 700, height: 550)
        .onAppear {
            loadResults()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(query.name)
                    .font(.headline)
                Text(query.query)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            Button("Run Now") {
                Task {
                    await appState.runScheduledQueryNow(query)
                    // Reload results after a short delay
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    loadResults()
                }
            }
            .help("Execute this query immediately")

            Button("Done") { dismiss() }
                .keyboardShortcut(.escape)
                .help("Close this window (Esc)")
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("No Results Yet")
                .font(.headline)
            Text("Click \"Run Now\" to execute this query and see results.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Run Now") {
                Task {
                    await appState.runScheduledQueryNow(query)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    loadResults()
                }
            }
            .buttonStyle(.borderedProminent)
            .help("Execute this scheduled query now")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No results yet for this scheduled query")
    }

    // MARK: - Latest Results Tab

    private var latestResultsTab: some View {
        VStack(spacing: 0) {
            if let latest = selectedResult ?? results.first {
                // Result metadata
                resultMetadataBar(latest)

                Divider()

                // Data table
                if let data = latest.resultData, let columns = latest.columns, !data.isEmpty {
                    resultDataTable(data: data, columns: columns)
                } else if latest.error != nil {
                    errorView(latest)
                } else {
                    noDataView
                }
            }
        }
    }

    private func resultMetadataBar(_ result: ScheduledQueryResult) -> some View {
        HStack(spacing: 16) {
            Label(result.timestamp.formatted(.dateTime.month().day().hour().minute()), systemImage: "clock")
                .font(.caption)

            Text("\(result.rowCount) row\(result.rowCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)

            if result.alertTriggered {
                Label("Alert triggered", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .accessibilityLabel("Alert was triggered for this result")
            }

            Spacer()

            if result.rowCount > ScheduledQueryResult.maxStoredRows {
                Text("Showing first \(ScheduledQueryResult.maxStoredRows) rows")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func resultDataTable(data: [[String: String]], columns: [String]) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(columns, id: \.self) { column in
                        Text(column)
                            .font(.caption.bold())
                            .frame(minWidth: 100, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }

                Divider()

                // Data rows
                ForEach(Array(data.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            Text(row[column] ?? "")
                                .font(.system(.caption, design: .monospaced))
                                .frame(minWidth: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                    }
                    .background(index % 2 == 0 ? Color.clear : Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
            }
        }
    }

    private func errorView(_ result: ScheduledQueryResult) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
                .accessibilityHidden(true)
            Text("Query Failed")
                .font(.headline)
            if let error = result.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Query failed: \(result.error ?? "Unknown error")")
    }

    private var noDataView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("No Data")
                .font(.headline)
            Text("This run returned no rows.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No data returned from this query run")
    }

    // MARK: - History Tab

    private var historyTab: some View {
        VStack(spacing: 0) {
            // Chart
            chartSection
                .frame(height: 150)
                .padding()

            Divider()

            // Results list
            resultsListSection
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Result Count Over Time")
                .font(.caption)
                .foregroundColor(.secondary)

            Chart(results) { result in
                LineMark(
                    x: .value("Time", result.timestamp),
                    y: .value("Rows", result.rowCount)
                )
                .foregroundStyle(result.alertTriggered ? Color.orange : Color.blue)

                PointMark(
                    x: .value("Time", result.timestamp),
                    y: .value("Rows", result.rowCount)
                )
                .foregroundStyle(result.alertTriggered ? Color.orange : Color.blue)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .accessibilityLabel("Chart showing result counts over time")
            .accessibilityHint("Shows \(results.count) data points")
        }
    }

    private var resultsListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Run History")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear History") {
                    ScheduledQueryResultStore.shared.clearResults(for: query.id)
                    results = []
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(results) { result in
                        historyRow(result)
                    }
                }
            }
        }
    }

    private func historyRow(_ result: ScheduledQueryResult) -> some View {
        Button {
            selectedResult = result
            selectedTab = 0 // Switch to Latest Results tab
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.timestamp.formatted(.dateTime.month().day().hour().minute().second()))
                        .font(.caption)

                    if let error = result.error {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    } else if let summary = result.resultSummary {
                        Text(summary)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if result.alertTriggered {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityHidden(true)
                }

                if result.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                } else {
                    Text("\(result.rowCount) row\(result.rowCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(selectedResult?.id == result.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(historyRowAccessibilityLabel(result))
            .accessibilityHint("Double tap to view details")
        }
        .buttonStyle(.plain)
    }

    private func historyRowAccessibilityLabel(_ result: ScheduledQueryResult) -> String {
        var parts: [String] = []
        parts.append(result.timestamp.formatted(.dateTime.month().day().hour().minute()))
        if result.alertTriggered {
            parts.append("alert triggered")
        }
        if result.error != nil {
            parts.append("failed")
        } else {
            parts.append("\(result.rowCount) row\(result.rowCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    private func loadResults() {
        results = ScheduledQueryResultStore.shared.getResults(for: query.id, limit: 50)
        // Auto-select the latest result
        if selectedResult == nil {
            selectedResult = results.first
        }
    }
}
