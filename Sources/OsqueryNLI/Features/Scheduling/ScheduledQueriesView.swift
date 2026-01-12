import SwiftUI

/// Main view for managing scheduled queries
struct ScheduledQueriesView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAddSheet = false
    @State private var editingQuery: ScheduledQuery?
    @State private var viewingResultsQuery: ScheduledQuery?
    @State private var queryToDelete: ScheduledQuery?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            if appState.scheduledQueries.isEmpty {
                emptyState
            } else {
                queryList
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .sheet(isPresented: $showingAddSheet) {
            AddScheduledQuerySheet()
                .environment(appState)
        }
        .sheet(item: $editingQuery) { query in
            AddScheduledQuerySheet(existingQuery: query)
                .environment(appState)
        }
        .sheet(item: $viewingResultsQuery) { query in
            ScheduledQueryResultsView(query: query)
                .environment(appState)
        }
        .confirmationDialog(
            "Delete Scheduled Query?",
            isPresented: Binding(
                get: { queryToDelete != nil },
                set: { if !$0 { queryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let query = queryToDelete {
                    appState.removeScheduledQuery(query)
                    // Also clear results for this query
                    ScheduledQueryResultStore.shared.clearResults(for: query.id)
                }
                queryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                queryToDelete = nil
            }
        } message: {
            if let query = queryToDelete {
                Text("Are you sure you want to delete \"\(query.name)\"? This will also delete all stored results for this query.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Scheduled Queries")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Schedule", systemImage: "plus")
                }
            }

            // Global settings
            HStack(spacing: 16) {
                @Bindable var state = appState

                Toggle("Enable Scheduler", isOn: $state.schedulerEnabled)
                    .toggleStyle(.switch)

                Divider()
                    .frame(height: 20)

                HStack(spacing: 4) {
                    Image(systemName: appState.notificationsEnabled ? "bell.fill" : "bell.slash")
                        .foregroundColor(appState.notificationsEnabled ? .green : .secondary)

                    if appState.notificationsEnabled {
                        Text("Notifications enabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Enable Notifications") {
                            Task {
                                await appState.enableNotifications()
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.link)
                    }
                }

                Spacer()

                Text("\(appState.scheduledQueries.count) scheduled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock.arrow.2.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Scheduled Queries")
                .font(.headline)

            Text("Schedule queries to run automatically at regular intervals.\nGet notified when specific conditions are met.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Your First Schedule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var queryList: some View {
        List {
            ForEach(appState.scheduledQueries) { query in
                ScheduledQueryRow(
                    query: query,
                    onEdit: { editingQuery = query },
                    onViewResults: { viewingResultsQuery = query },
                    onDelete: { queryToDelete = query }
                )
            }
            .onDelete(perform: deleteQueries)
        }
        .listStyle(.plain)
    }

    private func deleteQueries(at offsets: IndexSet) {
        // For swipe-to-delete, only allow single deletion with confirmation
        if let index = offsets.first {
            queryToDelete = appState.scheduledQueries[index]
        }
    }
}

// Make ScheduledQuery hashable for sheet presentation
extension ScheduledQuery: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
