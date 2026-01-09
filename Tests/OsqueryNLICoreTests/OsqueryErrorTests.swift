import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("OsqueryError Tests")
struct OsqueryErrorTests {

    @Test("notInstalled error has correct description")
    func testNotInstalledError() {
        let error = OsqueryError.notInstalled
        #expect(error.errorDescription?.contains("osqueryi not found") == true)
        #expect(error.errorDescription?.contains("brew install osquery") == true)
    }

    @Test("executionFailed error includes stderr")
    func testExecutionFailedError() {
        let error = OsqueryError.executionFailed(stderr: "table not found")
        #expect(error.errorDescription?.contains("Query failed") == true)
        #expect(error.errorDescription?.contains("table not found") == true)
    }

    @Test("invalidSQL error includes details")
    func testInvalidSQLError() {
        let error = OsqueryError.invalidSQL(details: "missing semicolon")
        #expect(error.errorDescription?.contains("Invalid SQL") == true)
        #expect(error.errorDescription?.contains("missing semicolon") == true)
    }

    @Test("parseError error includes details")
    func testParseErrorError() {
        let error = OsqueryError.parseError(details: "unexpected token")
        #expect(error.errorDescription?.contains("Failed to parse") == true)
        #expect(error.errorDescription?.contains("unexpected token") == true)
    }

    @Test("timeout error has correct description")
    func testTimeoutError() {
        let error = OsqueryError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test("processError includes underlying error")
    func testProcessError() {
        let error = OsqueryError.processError(underlying: "permission denied")
        #expect(error.errorDescription?.contains("Process error") == true)
        #expect(error.errorDescription?.contains("permission denied") == true)
    }

    @Test("OsqueryError conforms to LocalizedError")
    func testConformsToLocalizedError() {
        let error: LocalizedError = OsqueryError.notInstalled
        #expect(error.errorDescription != nil)
    }

    @Test("OsqueryError conforms to Sendable")
    func testConformsToSendable() {
        let error: any Sendable = OsqueryError.timeout
        #expect(error is OsqueryError)
    }
}
