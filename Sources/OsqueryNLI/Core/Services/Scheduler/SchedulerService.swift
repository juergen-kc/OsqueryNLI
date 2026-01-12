import Foundation

/// Service that runs scheduled queries at configured intervals
@MainActor
final class SchedulerService {
    private var timer: Timer?
    private weak var appState: AppState?
    private var isRunning = false

    /// Check interval in seconds (check every minute which queries are due)
    private let checkInterval: TimeInterval = 60

    init(appState: AppState) {
        self.appState = appState
    }

    /// Start the scheduler
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Run immediately on start
        Task {
            await checkAndRunDueQueries()
        }

        // Schedule periodic checks
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndRunDueQueries()
            }
        }
    }

    /// Stop the scheduler
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Check which queries are due and run them
    private func checkAndRunDueQueries() async {
        guard let appState = appState else { return }

        let now = Date()
        for index in appState.scheduledQueries.indices {
            let query = appState.scheduledQueries[index]
            if query.shouldRun(at: now) {
                await runScheduledQuery(at: index)
            }
        }
    }

    /// Run a specific scheduled query
    private func runScheduledQuery(at index: Int) async {
        guard let appState = appState,
              index < appState.scheduledQueries.count else { return }

        let query = appState.scheduledQueries[index]
        let previousResultCount = query.lastResultCount

        do {
            let (results, sql) = try await executeQuery(query)

            // Update the scheduled query with last run info
            appState.scheduledQueries[index].lastRun = Date()
            appState.scheduledQueries[index].lastResultCount = results.count

            // Check alert conditions
            var alertTriggered = false
            if let alertRule = query.alertRule {
                alertTriggered = alertRule.shouldAlert(
                    results: results,
                    previousResultCount: previousResultCount
                )

                if alertTriggered {
                    // Update last triggered
                    appState.scheduledQueries[index].alertRule?.lastTriggered = Date()

                    // Send notification
                    sendAlertNotification(
                        for: query,
                        resultCount: results.count,
                        condition: alertRule.condition
                    )
                }
            }

            // Store the result with actual data
            let storedResult = ScheduledQueryResult.from(
                scheduledQueryId: query.id,
                results: results,
                alertTriggered: alertTriggered,
                sql: sql
            )
            ScheduledQueryResultStore.shared.saveResult(storedResult)

        } catch {
            // Store error result (don't alert on errors)
            let errorResult = ScheduledQueryResult(
                scheduledQueryId: query.id,
                rowCount: 0,
                alertTriggered: false,
                error: error.localizedDescription
            )
            ScheduledQueryResultStore.shared.saveResult(errorResult)

            // Update last run even on error
            appState.scheduledQueries[index].lastRun = Date()
        }
    }

    /// Execute the query (either SQL or natural language)
    private func executeQuery(_ query: ScheduledQuery) async throws -> ([[String: Any]], String) {
        guard let appState = appState else {
            throw SchedulerError.appStateUnavailable
        }

        if query.isSQL {
            // Direct SQL execution
            let results = try await appState.osqueryService.execute(query.query)
            return (results, query.query)
        } else {
            // Natural language translation + execution
            let schema = try await appState.osqueryService.getSchema(for: Array(appState.enabledTables))

            guard !schema.isEmpty else {
                throw SchedulerError.noSchemaAvailable
            }

            let translation = try await appState.currentLLMService.translateToSQL(
                query: query.query,
                schemaContext: schema
            )

            // Execute the translated SQL
            let queries = translation.sql
                .components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var allResults: [[String: Any]] = []
            for sql in queries {
                let results = try await appState.osqueryService.execute(sql)
                allResults.append(contentsOf: results)
            }

            return (allResults, translation.sql)
        }
    }

    /// Send a notification for a triggered alert
    private func sendAlertNotification(
        for query: ScheduledQuery,
        resultCount: Int,
        condition: AlertCondition
    ) {
        guard let appState = appState, appState.notificationsEnabled else { return }

        let message: String
        switch condition {
        case .anyResults:
            message = "Found \(resultCount) result\(resultCount == 1 ? "" : "s")"
        case .noResults:
            message = "Query returned no results"
        case .rowCountGreaterThan(let n):
            message = "Found \(resultCount) results (threshold: >\(n))"
        case .rowCountLessThan(let n):
            message = "Found \(resultCount) results (threshold: <\(n))"
        case .rowCountEquals(let n):
            message = "Found exactly \(n) result\(n == 1 ? "" : "s")"
        case .rowCountNotEquals:
            message = "Result count changed to \(resultCount)"
        case .containsValue(let column, let value):
            message = "Found \(resultCount) result\(resultCount == 1 ? "" : "s") where \(column) contains '\(value)'"
        }

        NotificationService.shared.sendAlertNotification(
            queryName: query.name,
            message: message,
            queryId: query.id
        )
    }

    /// Manually run a scheduled query (for testing or on-demand)
    func runNow(_ query: ScheduledQuery) async {
        guard let appState = appState,
              let index = appState.scheduledQueries.firstIndex(where: { $0.id == query.id }) else {
            return
        }
        await runScheduledQuery(at: index)
    }
}

/// Errors specific to the scheduler
enum SchedulerError: LocalizedError {
    case appStateUnavailable
    case noSchemaAvailable
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .appStateUnavailable:
            return "App state is not available"
        case .noSchemaAvailable:
            return "No schema available. Please enable some tables in Settings."
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        }
    }
}
