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
        .undoToast()
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
                }
                queryToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                queryToDelete = nil
            }
        } message: {
            if let query = queryToDelete {
                Text("Are you sure you want to delete \"\(query.name)\"? Results will be deleted when undo expires.")
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
                .accessibilityLabel("Add new scheduled query")
            }

            // Global settings
            HStack(spacing: 16) {
                @Bindable var state = appState

                Toggle("Enable Scheduler", isOn: $state.schedulerEnabled)
                    .toggleStyle(.switch)
                    .accessibilityLabel(appState.schedulerEnabled ? "Scheduler enabled, toggle to disable" : "Scheduler disabled, toggle to enable")

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
        EmptyStateView(
            icon: "clock.arrow.2.circlepath",
            title: "No Scheduled Queries",
            message: "Schedule queries to run automatically at regular intervals.\nGet notified when specific conditions are met.",
            actionTitle: "Add Your First Schedule",
            action: { showingAddSheet = true }
        )
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
