import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("MockOsqueryService Tests")
struct MockOsqueryServiceTests {

    // MARK: - Basic Functionality

    @Test("Mock returns configured results")
    func testReturnsConfiguredResults() async throws {
        let mock = MockOsqueryService()
        mock.executeResults = [
            ["name": "Finder", "pid": 123],
            ["name": "Safari", "pid": 456]
        ]

        let results = try await mock.execute("SELECT * FROM processes")

        #expect(results.count == 2)
        #expect(results[0]["name"] as? String == "Finder")
        #expect(results[1]["pid"] as? Int == 456)
    }

    @Test("Mock tracks executed queries")
    func testTracksExecutedQueries() async throws {
        let mock = MockOsqueryService()
        mock.executeResults = []

        _ = try await mock.execute("SELECT * FROM users")
        _ = try await mock.execute("SELECT * FROM processes")

        #expect(mock.executedQueries.count == 2)
        #expect(mock.executedQueries[0] == "SELECT * FROM users")
        #expect(mock.executedQueries[1] == "SELECT * FROM processes")
    }

    @Test("Mock tracks method call counts")
    func testTracksCallCounts() async throws {
        let mock = MockOsqueryService()
        mock.executeResults = []

        _ = try await mock.execute("SELECT 1")
        _ = try await mock.execute("SELECT 2")
        _ = try await mock.getAllTables()
        _ = await mock.isAvailable()

        #expect(mock.callCounts["execute"] == 2)
        #expect(mock.callCounts["getAllTables"] == 1)
        #expect(mock.callCounts["isAvailable"] == 1)
    }

    // MARK: - Error Simulation

    @Test("Mock throws configured error")
    func testThrowsConfiguredError() async {
        let mock = MockOsqueryService()
        mock.executeError = OsqueryError.notInstalled

        do {
            _ = try await mock.execute("SELECT 1")
            Issue.record("Should have thrown")
        } catch let error as OsqueryError {
            // Use pattern matching since OsqueryError has associated values
            if case .notInstalled = error {
                // Expected
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    @Test("Mock simulates unavailable osquery")
    func testSimulatesUnavailable() async {
        let mock = MockOsqueryService()
        mock.isAvailableResult = false

        let available = await mock.isAvailable()

        #expect(available == false)
    }

    // MARK: - Factory Methods

    @Test("withProcessData factory creates mock with process results")
    func testWithProcessDataFactory() async throws {
        let mock = MockOsqueryService.withProcessData()

        let results = try await mock.execute("SELECT * FROM processes")

        #expect(results.count == 3)
        #expect(results[0]["name"] as? String == "launchd")
        #expect(results[1]["name"] as? String == "Finder")
        #expect(results[2]["name"] as? String == "Safari")
    }

    @Test("withSystemInfo factory creates mock with system info")
    func testWithSystemInfoFactory() async throws {
        let mock = MockOsqueryService.withSystemInfo()

        let results = try await mock.execute("SELECT * FROM system_info")

        #expect(results.count == 1)
        #expect(results[0]["hostname"] as? String == "test-mac")
        #expect(results[0]["cpu_brand"] as? String == "Apple M1")
    }

    @Test("notInstalled factory creates mock that fails")
    func testNotInstalledFactory() async {
        let mock = MockOsqueryService.notInstalled()

        let available = await mock.isAvailable()
        #expect(available == false)

        do {
            _ = try await mock.execute("SELECT 1")
            Issue.record("Should have thrown")
        } catch let error as OsqueryError {
            if case .notInstalled = error {
                // Expected
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    @Test("withExecutionError factory creates mock with execution failure")
    func testWithExecutionErrorFactory() async {
        let mock = MockOsqueryService.withExecutionError("Test error")

        do {
            _ = try await mock.execute("SELECT 1")
            Issue.record("Should have thrown")
        } catch let error as OsqueryError {
            if case .executionFailed(let stderr) = error {
                #expect(stderr == "Test error")
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    @Test("withTimeout factory creates mock that times out")
    func testWithTimeoutFactory() async {
        let mock = MockOsqueryService.withTimeout()

        do {
            _ = try await mock.execute("SELECT 1")
            Issue.record("Should have thrown")
        } catch let error as OsqueryError {
            if case .timeout = error {
                // Expected
            } else {
                Issue.record("Wrong error case: \(error)")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    // MARK: - Schema and Tables

    @Test("Mock returns configured tables")
    func testReturnsConfiguredTables() async throws {
        let mock = MockOsqueryService()
        mock.tables = ["processes", "users", "custom_table"]

        let tables = try await mock.getAllTables()

        #expect(tables.count == 3)
        #expect(tables.contains("custom_table"))
    }

    @Test("Mock returns configured schema")
    func testReturnsConfiguredSchema() async throws {
        let mock = MockOsqueryService()
        mock.schemaResult = "CREATE TABLE test (id INTEGER);"

        let schema = try await mock.getSchema(for: ["test"])

        #expect(schema == "CREATE TABLE test (id INTEGER);")
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func testResetClearsState() async throws {
        let mock = MockOsqueryService()
        mock.executeResults = [["test": 1]]
        mock.executeError = OsqueryError.notInstalled
        mock.isAvailableResult = false
        _ = try? await mock.execute("SELECT 1")

        mock.reset()

        #expect(mock.executedQueries.isEmpty)
        #expect(mock.callCounts.isEmpty)
        #expect(mock.executeResults.isEmpty)
        #expect(mock.executeError == nil)
        #expect(mock.isAvailableResult == true)
    }
}
