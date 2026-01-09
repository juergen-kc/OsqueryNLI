import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("QueryHistoryEntry Tests")
struct QueryHistoryEntryTests {

    @Test("Entry initializes with correct values")
    func testInitialization() {
        let entry = QueryHistoryEntry(
            query: "SELECT * FROM users",
            source: .app,
            rowCount: 10
        )

        #expect(entry.query == "SELECT * FROM users")
        #expect(entry.source == .app)
        #expect(entry.rowCount == 10)
    }

    @Test("Entry initializes with MCP source")
    func testMCPSource() {
        let entry = QueryHistoryEntry(
            query: "SELECT name FROM processes",
            source: .mcp
        )

        #expect(entry.source == .mcp)
        #expect(entry.rowCount == nil)
    }

    @Test("Entry encodes and decodes correctly")
    func testCodableRoundtrip() throws {
        let original = QueryHistoryEntry(
            query: "SELECT * FROM apps LIMIT 5",
            source: .app,
            rowCount: 5
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(QueryHistoryEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.query == original.query)
        #expect(decoded.source == original.source)
        #expect(decoded.rowCount == original.rowCount)
        #expect(abs(decoded.timestamp.timeIntervalSince(original.timestamp)) < 1)
    }

    @Test("Entry array encodes and decodes correctly")
    func testArrayCodable() throws {
        let entries = [
            QueryHistoryEntry(query: "SELECT 1", source: .app),
            QueryHistoryEntry(query: "SELECT 2", source: .mcp, rowCount: 1),
            QueryHistoryEntry(query: "SELECT 3", source: .app, rowCount: 100),
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([QueryHistoryEntry].self, from: data)

        #expect(decoded.count == 3)
        #expect(decoded[0].query == "SELECT 1")
        #expect(decoded[1].source == .mcp)
        #expect(decoded[2].rowCount == 100)
    }

    @Test("QuerySource raw values are correct")
    func testQuerySourceRawValues() {
        #expect(QuerySource.app.rawValue == "app")
        #expect(QuerySource.mcp.rawValue == "mcp")
    }

    @Test("Entry conforms to Hashable")
    func testHashable() {
        let entry1 = QueryHistoryEntry(query: "SELECT 1", source: .app)
        let entry2 = QueryHistoryEntry(query: "SELECT 2", source: .mcp)

        var set = Set<QueryHistoryEntry>()
        set.insert(entry1)
        set.insert(entry2)
        set.insert(entry1)

        #expect(set.count == 2)
    }
}
