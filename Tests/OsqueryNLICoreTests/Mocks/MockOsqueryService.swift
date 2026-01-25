import Foundation
import OsqueryNLICore

/// Mock implementation of OsqueryServiceProtocol for testing
public final class MockOsqueryService: OsqueryServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Whether the mock osquery is "available"
    public var isAvailableResult: Bool = true

    /// Tables to return from getAllTables()
    public var tables: [String] = ["processes", "users", "system_info", "uptime"]

    /// Schema to return from getSchema()
    public var schemaResult: String = """
        CREATE TABLE processes (
            `pid` INTEGER,
            `name` TEXT,
            `path` TEXT,
            `cmdline` TEXT
        );
        """

    /// Results to return from execute()
    public var executeResults: [[String: Any]] = []

    /// Error to throw from execute() if set
    public var executeError: Error?

    /// Delay to simulate before returning results (in seconds)
    public var simulatedDelay: TimeInterval = 0

    // MARK: - Call Tracking

    /// Tracks all SQL queries executed
    public private(set) var executedQueries: [String] = []

    /// Tracks how many times each method was called
    public private(set) var callCounts: [String: Int] = [:]

    // MARK: - OsqueryServiceProtocol

    public func execute(_ sql: String) async throws -> [[String: Any]] {
        trackCall("execute")
        executedQueries.append(sql)

        if simulatedDelay > 0 {
            try await Task.sleep(for: .seconds(simulatedDelay))
        }

        if let error = executeError {
            throw error
        }

        return executeResults
    }

    public func getAllTables() async throws -> [String] {
        trackCall("getAllTables")

        if simulatedDelay > 0 {
            try await Task.sleep(for: .seconds(simulatedDelay))
        }

        return tables
    }

    public func getSchema(for tables: [String]) async throws -> String {
        trackCall("getSchema")

        if simulatedDelay > 0 {
            try await Task.sleep(for: .seconds(simulatedDelay))
        }

        return schemaResult
    }

    public func isAvailable() async -> Bool {
        trackCall("isAvailable")
        return isAvailableResult
    }

    // MARK: - Helpers

    private func trackCall(_ method: String) {
        callCounts[method, default: 0] += 1
    }

    /// Reset all tracking and configuration
    public func reset() {
        executedQueries = []
        callCounts = [:]
        executeResults = []
        executeError = nil
        simulatedDelay = 0
        isAvailableResult = true
    }

    /// Configure mock to return specific results for a query pattern
    public func whenExecuting(containing pattern: String, return results: [[String: Any]]) {
        // Simple pattern matching - could be extended
        executeResults = results
    }
}

// MARK: - Convenience Factory Methods

extension MockOsqueryService {
    /// Create a mock that returns process data
    public static func withProcessData() -> MockOsqueryService {
        let mock = MockOsqueryService()
        mock.executeResults = [
            ["pid": 1, "name": "launchd", "path": "/sbin/launchd", "cmdline": "/sbin/launchd"],
            ["pid": 123, "name": "Finder", "path": "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder", "cmdline": ""],
            ["pid": 456, "name": "Safari", "path": "/Applications/Safari.app/Contents/MacOS/Safari", "cmdline": ""]
        ]
        return mock
    }

    /// Create a mock that returns system info
    public static func withSystemInfo() -> MockOsqueryService {
        let mock = MockOsqueryService()
        mock.executeResults = [
            ["hostname": "test-mac", "cpu_brand": "Apple M1", "physical_memory": "16000000000"]
        ]
        return mock
    }

    /// Create a mock that simulates osquery not being installed
    public static func notInstalled() -> MockOsqueryService {
        let mock = MockOsqueryService()
        mock.isAvailableResult = false
        mock.executeError = OsqueryError.notInstalled
        return mock
    }

    /// Create a mock that simulates execution failure
    public static func withExecutionError(_ message: String) -> MockOsqueryService {
        let mock = MockOsqueryService()
        mock.executeError = OsqueryError.executionFailed(stderr: message)
        return mock
    }

    /// Create a mock that simulates timeout
    public static func withTimeout() -> MockOsqueryService {
        let mock = MockOsqueryService()
        mock.executeError = OsqueryError.timeout
        return mock
    }
}
