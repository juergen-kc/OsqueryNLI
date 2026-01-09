import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("QueryHistoryLogger Tests")
struct QueryHistoryLoggerTests {

    private func createTestLogger(maxEntries: Int = 100) -> (QueryHistoryLogger, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
        let logger = QueryHistoryLogger(directory: tempDir, maxEntries: maxEntries)
        return (logger, tempDir)
    }

    private func cleanup(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test("Logger starts with empty entries")
    func testEmptyInitialState() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        let entries = logger.readEntries()
        #expect(entries.isEmpty)
    }

    @Test("Logger logs a query")
    func testLogQuery() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "SELECT * FROM users", source: .app, rowCount: 5)

        let entries = logger.readEntries()
        #expect(entries.count == 1)
        #expect(entries[0].query == "SELECT * FROM users")
        #expect(entries[0].source == .app)
        #expect(entries[0].rowCount == 5)
    }

    @Test("Logger logs multiple queries in order")
    func testMultipleQueries() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "SELECT 1", source: .app)
        logger.logQuery(query: "SELECT 2", source: .mcp)
        logger.logQuery(query: "SELECT 3", source: .app)

        let entries = logger.readEntries()
        #expect(entries.count == 3)
        #expect(entries[0].query == "SELECT 3")
        #expect(entries[1].query == "SELECT 2")
        #expect(entries[2].query == "SELECT 1")
    }

    @Test("Logger respects maxEntries limit")
    func testMaxEntriesLimit() {
        let (logger, tempDir) = createTestLogger(maxEntries: 5)
        defer { cleanup(tempDir) }

        for i in 1...10 {
            logger.logQuery(query: "SELECT \(i)", source: .app)
        }

        let entries = logger.readEntries()
        #expect(entries.count == 5)
        #expect(entries[0].query == "SELECT 10")
        #expect(entries[4].query == "SELECT 6")
    }

    @Test("Logger filters by source")
    func testFilterBySource() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "App query 1", source: .app)
        logger.logQuery(query: "MCP query 1", source: .mcp)
        logger.logQuery(query: "App query 2", source: .app)
        logger.logQuery(query: "MCP query 2", source: .mcp)

        let appEntries = logger.readEntries(source: .app)
        let mcpEntries = logger.readEntries(source: .mcp)

        #expect(appEntries.count == 2)
        #expect(mcpEntries.count == 2)
        #expect(appEntries.allSatisfy { $0.source == .app })
        #expect(mcpEntries.allSatisfy { $0.source == .mcp })
    }

    @Test("Logger clears all entries")
    func testClearAllEntries() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "SELECT 1", source: .app)
        logger.logQuery(query: "SELECT 2", source: .mcp)

        #expect(logger.readEntries().count == 2)

        logger.clearEntries()

        #expect(logger.readEntries().isEmpty)
    }

    @Test("Logger clears entries by source")
    func testClearEntriesBySource() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "App query", source: .app)
        logger.logQuery(query: "MCP query", source: .mcp)

        logger.clearEntries(source: .mcp)

        let entries = logger.readEntries()
        #expect(entries.count == 1)
        #expect(entries[0].source == .app)
    }

    @Test("Logger removes entry by ID")
    func testRemoveEntryById() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "SELECT 1", source: .app)
        logger.logQuery(query: "SELECT 2", source: .app)
        logger.logQuery(query: "SELECT 3", source: .app)

        let entries = logger.readEntries()
        let idToRemove = entries[1].id

        logger.removeEntry(id: idToRemove)

        let remaining = logger.readEntries()
        #expect(remaining.count == 2)
        #expect(remaining[0].query == "SELECT 3")
        #expect(remaining[1].query == "SELECT 1")
    }

    @Test("Logger returns last entry timestamp")
    func testLastEntryTimestamp() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        #expect(logger.lastEntryTimestamp() == nil)

        let beforeLog = Date().addingTimeInterval(-1)  // 1 second buffer
        logger.logQuery(query: "SELECT 1", source: .app)
        let afterLog = Date().addingTimeInterval(1)  // 1 second buffer

        let timestamp = logger.lastEntryTimestamp()
        #expect(timestamp != nil)
        #expect(timestamp! >= beforeLog)
        #expect(timestamp! <= afterLog)
    }

    @Test("Logger persists across instances")
    func testPersistence() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OsqueryNLITests-\(UUID().uuidString)")
        defer { cleanup(tempDir) }

        let logger1 = QueryHistoryLogger(directory: tempDir)
        logger1.logQuery(query: "Persistent query", source: .app)

        let logger2 = QueryHistoryLogger(directory: tempDir)
        let entries = logger2.readEntries()

        #expect(entries.count == 1)
        #expect(entries[0].query == "Persistent query")
    }

    @Test("Logger handles nil row count")
    func testNilRowCount() {
        let (logger, tempDir) = createTestLogger()
        defer { cleanup(tempDir) }

        logger.logQuery(query: "SELECT 1", source: .app)

        let entries = logger.readEntries()
        #expect(entries[0].rowCount == nil)
    }
}
