import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("OsqueryService Tests")
struct OsqueryServiceTests {

    // MARK: - SQL Validation Tests

    @Suite("SQL Validation")
    struct SQLValidationTests {
        let service = OsqueryService()

        @Test("Accepts valid SELECT query")
        func testValidSelect() throws {
            try service.validateSQL("SELECT * FROM users")
        }

        @Test("Accepts SELECT with WHERE clause")
        func testSelectWithWhere() throws {
            try service.validateSQL("SELECT name FROM users WHERE uid = 501")
        }

        @Test("Accepts SELECT with JOIN")
        func testSelectWithJoin() throws {
            try service.validateSQL("SELECT p.name FROM processes p JOIN users u ON p.uid = u.uid")
        }

        @Test("Accepts PRAGMA query")
        func testPragmaQuery() throws {
            try service.validateSQL("PRAGMA table_info(users)")
        }

        @Test("Accepts EXPLAIN query")
        func testExplainQuery() throws {
            try service.validateSQL("EXPLAIN SELECT * FROM users")
        }

        @Test("Accepts query with comparison operators")
        func testComparisonOperators() throws {
            try service.validateSQL("SELECT * FROM processes WHERE cpu_percent > 50")
            try service.validateSQL("SELECT * FROM users WHERE uid < 1000")
            try service.validateSQL("SELECT * FROM apps WHERE name >= 'A'")
        }

        @Test("Rejects empty query")
        func testEmptyQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("")
            }
        }

        @Test("Rejects whitespace-only query")
        func testWhitespaceQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("   \t\n   ")
            }
        }

        @Test("Rejects query exceeding max length")
        func testTooLongQuery() {
            let longQuery = "SELECT * FROM users WHERE name = '" + String(repeating: "a", count: 10_001) + "'"
            #expect(throws: OsqueryError.self) {
                try service.validateSQL(longQuery)
            }
        }

        @Test("Rejects INSERT query")
        func testInsertQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("INSERT INTO users VALUES (1, 'test')")
            }
        }

        @Test("Rejects UPDATE query")
        func testUpdateQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("UPDATE users SET name = 'test'")
            }
        }

        @Test("Rejects DELETE query")
        func testDeleteQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("DELETE FROM users")
            }
        }

        @Test("Rejects DROP query")
        func testDropQuery() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("DROP TABLE users")
            }
        }

        @Test("Rejects command substitution with $()")
        func testCommandSubstitutionDollar() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT * FROM users WHERE name = '$(whoami)'")
            }
        }

        @Test("Rejects command substitution with backticks")
        func testCommandSubstitutionBackticks() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT * FROM users WHERE name = '`whoami`'")
            }
        }

        @Test("Rejects shell AND operator")
        func testShellAndOperator() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT 1 && rm -rf /")
            }
        }

        @Test("Rejects shell OR operator")
        func testShellOrOperator() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT 1 || echo hacked")
            }
        }

        @Test("Rejects pipe operator")
        func testPipeOperator() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT * FROM users | cat /etc/passwd")
            }
        }

        @Test("Rejects newline injection")
        func testNewlineInjection() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT 1\nDROP TABLE users")
            }
        }

        @Test("Rejects hex escape sequences")
        func testHexEscape() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT * FROM users WHERE name = '\\x41'")
            }
        }

        @Test("Rejects unicode escape sequences")
        func testUnicodeEscape() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT * FROM users WHERE name = '\\u0041'")
            }
        }

        @Test("Accepts query at max length boundary")
        func testMaxLengthBoundary() throws {
            let query = "SELECT * FROM users WHERE name = '" + String(repeating: "a", count: 9950) + "'"
            try service.validateSQL(query)
        }

        @Test("Case insensitive SELECT detection")
        func testCaseInsensitiveSelect() throws {
            try service.validateSQL("select * from users")
            try service.validateSQL("SELECT * FROM users")
            try service.validateSQL("Select * From Users")
        }
    }

    // MARK: - Table Name Extraction Tests

    @Suite("Table Name Extraction")
    struct TableNameExtractionTests {
        let service = OsqueryService()

        @Test("Extracts from simple CREATE TABLE")
        func testSimpleCreateTable() {
            let sql = "CREATE TABLE users (id INTEGER, name TEXT)"
            let name = service.extractTableName(from: sql)
            #expect(name == "users")
        }

        @Test("Extracts from CREATE VIRTUAL TABLE")
        func testCreateVirtualTable() {
            let sql = "CREATE VIRTUAL TABLE processes USING osquery"
            let name = service.extractTableName(from: sql)
            #expect(name == "processes")
        }

        @Test("Handles lowercase CREATE TABLE")
        func testLowercaseCreateTable() {
            let sql = "create table system_info (key text, value text)"
            let name = service.extractTableName(from: sql)
            #expect(name == "system_info")
        }

        @Test("Handles table names with underscores")
        func testTableNameWithUnderscores() {
            let sql = "CREATE TABLE ai_tools_installed (name TEXT)"
            let name = service.extractTableName(from: sql)
            #expect(name == "ai_tools_installed")
        }

        @Test("Handles table names with numbers")
        func testTableNameWithNumbers() {
            let sql = "CREATE TABLE log2023 (entry TEXT)"
            let name = service.extractTableName(from: sql)
            #expect(name == "log2023")
        }

        @Test("Returns empty for invalid input")
        func testInvalidInput() {
            let name = service.extractTableName(from: "SELECT * FROM users")
            #expect(name == "")
        }

        @Test("Returns empty for empty string")
        func testEmptyString() {
            let name = service.extractTableName(from: "")
            #expect(name == "")
        }
    }

    // MARK: - Static Properties Tests

    @Suite("Static Properties")
    struct StaticPropertiesTests {

        @Test("aiDiscoveryTables contains expected tables")
        func testAIDiscoveryTables() {
            let tables = OsqueryService.aiDiscoveryTables

            #expect(tables.contains("ai_tools_installed"))
            #expect(tables.contains("ai_mcp_servers"))
            #expect(tables.contains("ai_env_vars"))
            #expect(tables.contains("ai_browser_extensions"))
            #expect(tables.contains("ai_code_assistants"))
            #expect(tables.contains("ai_api_keys"))
            #expect(tables.contains("ai_local_servers"))
            #expect(tables.contains("ai_models_downloaded"))
            #expect(tables.contains("ai_containers"))
            #expect(tables.contains("ai_sdk_dependencies"))
            #expect(tables.count == 10)
        }

        @Test("aiTableSchemas has schema for each AI table")
        func testAITableSchemasComplete() {
            for table in OsqueryService.aiDiscoveryTables {
                #expect(OsqueryService.aiTableSchemas[table] != nil, "Missing schema for \(table)")
            }
        }

        @Test("aiTableSchemas contain CREATE TABLE statements")
        func testAITableSchemasFormat() {
            for (table, schema) in OsqueryService.aiTableSchemas {
                #expect(schema.contains("CREATE TABLE \(table)"), "Schema for \(table) should start with CREATE TABLE")
            }
        }

        @Test("commonTables is not empty")
        func testCommonTablesNotEmpty() {
            #expect(!OsqueryService.commonTables.isEmpty)
        }

        @Test("commonTables includes AI Discovery tables")
        func testCommonTablesIncludesAI() {
            for table in OsqueryService.aiDiscoveryTables {
                #expect(OsqueryService.commonTables.contains(table), "commonTables should include \(table)")
            }
        }

        @Test("commonTables includes essential system tables")
        func testCommonTablesEssentials() {
            let essentials = ["processes", "users", "system_info", "os_version", "uptime"]
            for table in essentials {
                #expect(OsqueryService.commonTables.contains(table), "commonTables should include \(table)")
            }
        }

        @Test("defaultEnabledTables is subset of commonTables")
        func testDefaultEnabledIsSubset() {
            for table in OsqueryService.defaultEnabledTables {
                #expect(OsqueryService.commonTables.contains(table), "\(table) in defaultEnabled but not in commonTables")
            }
        }

        @Test("commonPaths contains expected locations")
        func testCommonPaths() {
            let paths = OsqueryService.commonPaths

            #expect(paths.contains("/opt/homebrew/bin/osqueryi"))
            #expect(paths.contains("/usr/local/bin/osqueryi"))
            #expect(paths.count >= 2)
        }
    }

    // MARK: - Initialization Tests

    @Suite("Initialization")
    struct InitializationTests {

        @Test("Default init succeeds")
        func testDefaultInit() {
            let service = OsqueryService()
            #expect(service != nil)
        }

        @Test("Init with custom path")
        func testCustomPathInit() {
            let service = OsqueryService(osqueryPath: "/custom/path/osqueryi")
            #expect(service != nil)
        }

        @Test("aiDiscoveryEnabled defaults to true")
        func testAIDiscoveryEnabledDefault() {
            let service = OsqueryService()
            #expect(service.aiDiscoveryEnabled == true)
        }

        @Test("aiDiscoveryEnabled can be changed")
        func testAIDiscoveryEnabledChange() {
            let service = OsqueryService()
            service.aiDiscoveryEnabled = false
            #expect(service.aiDiscoveryEnabled == false)
        }
    }
}
