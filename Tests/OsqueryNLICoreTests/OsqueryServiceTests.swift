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

    // MARK: - Advanced SQL Validation Tests

    @Suite("Advanced SQL Validation")
    struct AdvancedSQLValidationTests {
        let service = OsqueryService()

        @Test("Accepts COUNT aggregate")
        func testCountAggregate() throws {
            try service.validateSQL("SELECT COUNT(*) FROM processes")
        }

        @Test("Accepts GROUP BY")
        func testGroupBy() throws {
            try service.validateSQL("SELECT uid, COUNT(*) FROM processes GROUP BY uid")
        }

        @Test("Accepts ORDER BY")
        func testOrderBy() throws {
            try service.validateSQL("SELECT * FROM processes ORDER BY pid DESC")
        }

        @Test("Accepts LIMIT")
        func testLimit() throws {
            try service.validateSQL("SELECT * FROM processes LIMIT 10")
        }

        @Test("Accepts LIMIT with OFFSET")
        func testLimitOffset() throws {
            try service.validateSQL("SELECT * FROM processes LIMIT 10 OFFSET 5")
        }

        @Test("Accepts subquery")
        func testSubquery() throws {
            try service.validateSQL("SELECT * FROM processes WHERE uid IN (SELECT uid FROM users)")
        }

        @Test("Accepts UNION")
        func testUnion() throws {
            try service.validateSQL("SELECT name FROM processes UNION SELECT name FROM listening_ports")
        }

        @Test("Accepts LIKE operator")
        func testLikeOperator() throws {
            try service.validateSQL("SELECT * FROM processes WHERE name LIKE '%chrome%'")
        }

        @Test("Accepts IN clause")
        func testInClause() throws {
            try service.validateSQL("SELECT * FROM users WHERE uid IN (0, 501, 502)")
        }

        @Test("Accepts BETWEEN")
        func testBetween() throws {
            try service.validateSQL("SELECT * FROM processes WHERE pid BETWEEN 1 AND 1000")
        }

        @Test("Accepts IS NULL")
        func testIsNull() throws {
            try service.validateSQL("SELECT * FROM processes WHERE parent IS NULL")
        }

        @Test("Accepts IS NOT NULL")
        func testIsNotNull() throws {
            try service.validateSQL("SELECT * FROM users WHERE shell IS NOT NULL")
        }

        @Test("Accepts multiple JOINs")
        func testMultipleJoins() throws {
            // Single line to avoid newline rejection
            try service.validateSQL("SELECT p.name, u.username FROM processes p JOIN users u ON p.uid = u.uid JOIN groups g ON u.gid = g.gid")
        }

        @Test("Accepts LEFT JOIN")
        func testLeftJoin() throws {
            try service.validateSQL("SELECT * FROM users u LEFT JOIN processes p ON u.uid = p.uid")
        }

        @Test("Accepts DISTINCT")
        func testDistinct() throws {
            try service.validateSQL("SELECT DISTINCT uid FROM processes")
        }

        @Test("Accepts aliased columns")
        func testAliasedColumns() throws {
            try service.validateSQL("SELECT name AS process_name, pid AS process_id FROM processes")
        }

        @Test("Rejects ALTER TABLE")
        func testRejectAlter() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("ALTER TABLE users ADD COLUMN test TEXT")
            }
        }

        @Test("Rejects CREATE TABLE")
        func testRejectCreate() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("CREATE TABLE test (id INT)")
            }
        }

        @Test("Rejects TRUNCATE")
        func testRejectTruncate() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("TRUNCATE TABLE users")
            }
        }

        @Test("Allows semicolon (valid in osquery)")
        func testAllowsSemicolon() throws {
            // Note: osquery allows multiple statements separated by ;
            try service.validateSQL("SELECT * FROM users; SELECT * FROM processes")
        }

        @Test("Allows comment with -- (valid SQL)")
        func testAllowsDashComment() throws {
            // SQL comments are valid
            try service.validateSQL("SELECT * FROM users -- comment")
        }

        @Test("Allows single quotes in strings")
        func testSingleQuotesInStrings() throws {
            try service.validateSQL("SELECT * FROM users WHERE name = 'O''Brien'")
        }

        @Test("Accepts CASE WHEN on single line")
        func testCaseWhen() throws {
            // Multiline is rejected (newlines), but single line works
            try service.validateSQL("SELECT name, CASE WHEN uid = 0 THEN 'root' ELSE 'user' END as type FROM users")
        }

        @Test("Accepts COALESCE")
        func testCoalesce() throws {
            try service.validateSQL("SELECT COALESCE(shell, '/bin/false') FROM users")
        }

        @Test("Rejects multiline query (newlines)")
        func testRejectsMultiline() {
            #expect(throws: OsqueryError.self) {
                try service.validateSQL("SELECT *\nFROM users")
            }
        }
    }

    // MARK: - Error Message Tests

    @Suite("Error Messages")
    struct ErrorMessageTests {
        let service = OsqueryService()

        @Test("Empty query error is descriptive")
        func testEmptyQueryError() {
            do {
                try service.validateSQL("")
                Issue.record("Should have thrown")
            } catch let error as OsqueryError {
                let message = error.localizedDescription
                #expect(message.contains("empty") || message.contains("Empty"))
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }

        @Test("INSERT rejection throws OsqueryError")
        func testInsertErrorMessage() {
            do {
                try service.validateSQL("INSERT INTO users VALUES (1)")
                Issue.record("Should have thrown")
            } catch let error as OsqueryError {
                // Error message varies - just verify it threw an OsqueryError
                let message = error.localizedDescription
                #expect(!message.isEmpty)
            } catch {
                Issue.record("Wrong error type: \(error)")
            }
        }
    }
}
