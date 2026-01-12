import SwiftUI

/// Row view for displaying a scheduled query in a list
struct ScheduledQueryRow: View {
    @Environment(AppState.self) private var appState
    let query: ScheduledQuery
    var onEdit: () -> Void = {}
    var onViewResults: () -> Void = {}
    var onDelete: () -> Void = {}
    @State private var isRunning = false

    var body: some View {
        HStack(spacing: 12) {
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { query.isEnabled },
                set: { newValue in
                    var updated = query
                    updated.isEnabled = newValue
                    appState.updateScheduledQuery(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            // Query info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(query.name)
                        .font(.headline)
                        .lineLimit(1)

                    if query.isSQL {
                        Text("SQL")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if query.alertRule != nil {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Text(query.query)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(query.interval.displayName, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if let lastRun = query.lastRun {
                        Text("Last: \(lastRun.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let count = query.lastResultCount {
                        Text("\(count) rows")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 4) {
                Button {
                    runAndShowResults()
                } label: {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.borderless)
                .help("Run now and view results")
                .disabled(isRunning)

                Button(action: onViewResults) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.borderless)
                .help("View results")

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("Delete")
            }
        }
        .padding(.vertical, 4)
    }

    private func runAndShowResults() {
        isRunning = true
        Task {
            await appState.runScheduledQueryNow(query)
            await MainActor.run {
                isRunning = false
                // Open results view after run completes
                onViewResults()
            }
        }
    }
}
