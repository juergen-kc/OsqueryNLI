import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("QueryResult Tests")
struct QueryResultTests {

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("creates result with provided columns")
        func testInitWithColumns() {
            let columns = [
                QueryResult.ColumnInfo(name: "name"),
                QueryResult.ColumnInfo(name: "pid")
            ]
            let rows: [[String: String]] = [["name": "test", "pid": "123"]]

            let result = QueryResult(sql: "SELECT 1", rows: rows, columns: columns)

            #expect(result.columns.count == 2)
            #expect(result.columns[0].name == "name")
            #expect(result.columns[1].name == "pid")
        }

        @Test("infers columns from first row when not provided")
        func testInferColumns() {
            let rows: [[String: String]] = [["alpha": "1", "beta": "2"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)

            #expect(result.columns.count == 2)
            // Columns should be sorted alphabetically
            #expect(result.columns[0].name == "alpha")
            #expect(result.columns[1].name == "beta")
        }

        @Test("empty columns for empty rows")
        func testEmptyColumnsForEmptyRows() {
            let result = QueryResult(sql: "SELECT 1", rows: [])
            #expect(result.columns.isEmpty)
        }

        @Test("isEmpty returns true for empty rows")
        func testIsEmptyTrue() {
            let result = QueryResult(sql: "SELECT 1", rows: [])
            #expect(result.isEmpty == true)
        }

        @Test("isEmpty returns false for non-empty rows")
        func testIsEmptyFalse() {
            let result = QueryResult(sql: "SELECT 1", rows: [["a": "1"]])
            #expect(result.isEmpty == false)
        }

        @Test("rowCount returns correct count")
        func testRowCount() {
            let rows: [[String: String]] = [["a": "1"], ["a": "2"], ["a": "3"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            #expect(result.rowCount == 3)
        }
    }

    // MARK: - CSV Export Tests

    @Suite("CSV Export")
    struct CSVExportTests {

        @Test("toCSV creates valid CSV")
        func testBasicCSV() {
            let rows: [[String: String]] = [
                ["name": "Alice", "age": "30"],
                ["name": "Bob", "age": "25"]
            ]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let csv = result.toCSV()

            #expect(csv.contains("name"))
            #expect(csv.contains("age"))
            #expect(csv.contains("Alice"))
            #expect(csv.contains("Bob"))
        }

        @Test("toCSV handles empty result")
        func testEmptyCSV() {
            let result = QueryResult(sql: "SELECT 1", rows: [], columns: [])
            let csv = result.toCSV()
            #expect(csv == "")
        }

        @Test("toCSV escapes commas in values")
        func testCSVEscapesCommas() {
            let rows: [[String: String]] = [["value": "hello, world"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let csv = result.toCSV()
            #expect(csv.contains("\"hello, world\""))
        }

        @Test("toCSV escapes quotes in values")
        func testCSVEscapesQuotes() {
            let rows: [[String: String]] = [["value": "say \"hello\""]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let csv = result.toCSV()
            #expect(csv.contains("\"say \"\"hello\"\"\""))
        }

        @Test("toCSV escapes newlines in values")
        func testCSVEscapesNewlines() {
            let rows: [[String: String]] = [["value": "line1\nline2"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let csv = result.toCSV()
            #expect(csv.contains("\"line1\nline2\""))
        }
    }

    // MARK: - JSON Export Tests

    @Suite("JSON Export")
    struct JSONExportTests {

        @Test("toJSON creates valid JSON array")
        func testBasicJSON() throws {
            let rows: [[String: String]] = [["name": "Alice"], ["name": "Bob"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let json = result.toJSON()

            let data = json.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as! [[String: String]]

            #expect(parsed.count == 2)
            #expect(parsed[0]["name"] == "Alice")
            #expect(parsed[1]["name"] == "Bob")
        }

        @Test("toJSON handles empty result")
        func testEmptyJSON() {
            let result = QueryResult(sql: "SELECT 1", rows: [])
            let json = result.toJSON()
            #expect(json == "[\n\n]")
        }

        @Test("toJSON non-pretty printed")
        func testNonPrettyJSON() {
            let rows: [[String: String]] = [["a": "1"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let json = result.toJSON(prettyPrinted: false)
            #expect(!json.contains("\n"))
        }
    }

    // MARK: - Markdown Export Tests

    @Suite("Markdown Export")
    struct MarkdownExportTests {

        @Test("toMarkdown creates table with header")
        func testMarkdownTable() {
            let rows: [[String: String]] = [["name": "Test"]]
            let columns = [QueryResult.ColumnInfo(name: "name")]
            let result = QueryResult(sql: "SELECT name FROM test", rows: rows, columns: columns)
            let md = result.toMarkdown()

            #expect(md.contains("| name |"))
            #expect(md.contains("| --- |"))
            #expect(md.contains("| Test |"))
        }

        @Test("toMarkdown includes SQL")
        func testMarkdownIncludesSQL() {
            let result = QueryResult(sql: "SELECT * FROM users", rows: [["a": "1"]])
            let md = result.toMarkdown()
            #expect(md.contains("SELECT * FROM users"))
        }

        @Test("toMarkdown escapes pipe characters")
        func testMarkdownEscapesPipes() {
            let rows: [[String: String]] = [["value": "a|b|c"]]
            let result = QueryResult(sql: "SELECT 1", rows: rows)
            let md = result.toMarkdown()
            #expect(md.contains("a\\|b\\|c"))
        }

        @Test("toMarkdown handles empty result")
        func testEmptyMarkdown() {
            let result = QueryResult(sql: "SELECT 1", rows: [], columns: [])
            let md = result.toMarkdown()
            #expect(md.contains("*No results*"))
        }
    }

    // MARK: - Text Table Export Tests

    @Suite("Text Table Export")
    struct TextTableExportTests {

        @Test("toTextTable creates aligned columns")
        func testTextTable() {
            let rows: [[String: String]] = [
                ["name": "Alice", "id": "1"],
                ["name": "Bob", "id": "2"]
            ]
            let columns = [
                QueryResult.ColumnInfo(name: "name"),
                QueryResult.ColumnInfo(name: "id")
            ]
            let result = QueryResult(sql: "SELECT 1", rows: rows, columns: columns)
            let table = result.toTextTable()

            #expect(table.contains("name"))
            #expect(table.contains("Alice"))
            #expect(table.contains("-+-"))
        }

        @Test("toTextTable handles empty result")
        func testEmptyTextTable() {
            let result = QueryResult(sql: "SELECT 1", rows: [])
            let table = result.toTextTable()
            #expect(table == "No results")
        }
    }

    // MARK: - Factory Method Tests

    @Suite("Factory Methods")
    struct FactoryMethodTests {

        @Test("from converts Any values to String")
        func testFromOsqueryOutput() {
            let osqueryOutput: [[String: Any]] = [
                ["name": "test", "count": 42, "active": true]
            ]

            let result = QueryResult.from(sql: "SELECT 1", osqueryOutput: osqueryOutput)

            #expect(result.rows[0]["name"] == "test")
            #expect(result.rows[0]["count"] == "42")
            #expect(result.rows[0]["active"] == "true")
        }

        @Test("from preserves token usage")
        func testFromPreservesTokenUsage() {
            let tokenUsage = TokenUsage(inputTokens: 100, outputTokens: 50)
            let result = QueryResult.from(
                sql: "SELECT 1",
                osqueryOutput: [],
                tokenUsage: tokenUsage
            )

            #expect(result.tokenUsage?.inputTokens == 100)
            #expect(result.tokenUsage?.outputTokens == 50)
        }
    }

    // MARK: - XLSX Export Tests

    @Suite("XLSX Export")
    struct XLSXExportTests {

        @Test("toXLSX returns data for valid result")
        func testXLSXExport() {
            let rows: [[String: String]] = [["name": "Test", "value": "123"]]
            let columns = [
                QueryResult.ColumnInfo(name: "name"),
                QueryResult.ColumnInfo(name: "value")
            ]
            let result = QueryResult(sql: "SELECT 1", rows: rows, columns: columns)
            let data = result.toXLSX()

            #expect(data != nil)
            #expect(data!.count > 0)
            // XLSX files start with PK (ZIP signature)
            #expect(data![0] == 0x50)
            #expect(data![1] == 0x4B)
        }

        @Test("toXLSX returns nil for empty columns")
        func testXLSXEmptyColumns() {
            let result = QueryResult(sql: "SELECT 1", rows: [], columns: [])
            let data = result.toXLSX()
            #expect(data == nil)
        }
    }
}
