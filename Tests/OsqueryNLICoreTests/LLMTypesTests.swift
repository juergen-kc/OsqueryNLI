import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("LLM Types Tests")
struct LLMTypesTests {

    // MARK: - LLMError Tests

    @Suite("LLMError")
    struct LLMErrorTests {

        @Test("error descriptions are meaningful")
        func testErrorDescriptions() {
            #expect(LLMError.notConfigured.errorDescription?.contains("not configured") == true)
            #expect(LLMError.invalidAPIKey.errorDescription?.contains("Invalid API key") == true)
            #expect(LLMError.emptyInput(field: "query").errorDescription?.contains("query") == true)
            #expect(LLMError.timeout.errorDescription?.contains("timed out") == true)
            #expect(LLMError.invalidResponse.errorDescription?.contains("Invalid response") == true)
            #expect(LLMError.cancelled.errorDescription?.contains("cancelled") == true)
        }

        @Test("rateLimited includes retry time when provided")
        func testRateLimitedWithRetryTime() {
            let error = LLMError.rateLimited(retryAfter: 30)
            #expect(error.errorDescription?.contains("30") == true)
        }

        @Test("rateLimited works without retry time")
        func testRateLimitedWithoutRetryTime() {
            let error = LLMError.rateLimited(retryAfter: nil)
            #expect(error.errorDescription?.contains("try again later") == true)
        }

        @Test("cannotTranslate passes through reason")
        func testCannotTranslateReason() {
            let error = LLMError.cannotTranslate(reason: "Custom reason here")
            #expect(error.errorDescription == "Custom reason here")
        }

        @Test("networkError includes underlying error description")
        func testNetworkErrorDescription() {
            let underlying = NSError(domain: "Test", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server down"])
            let error = LLMError.networkError(underlying: underlying)
            #expect(error.errorDescription?.contains("Server down") == true)
        }

        @Test("isRetryable returns true for retryable errors")
        func testIsRetryableTrue() {
            #expect(LLMError.rateLimited(retryAfter: nil).isRetryable == true)
            #expect(LLMError.timeout.isRetryable == true)
            #expect(LLMError.networkError(underlying: NSError(domain: "", code: 0)).isRetryable == true)
        }

        @Test("isRetryable returns false for non-retryable errors")
        func testIsRetryableFalse() {
            #expect(LLMError.notConfigured.isRetryable == false)
            #expect(LLMError.invalidAPIKey.isRetryable == false)
            #expect(LLMError.emptyInput(field: "test").isRetryable == false)
            #expect(LLMError.invalidResponse.isRetryable == false)
            #expect(LLMError.cannotTranslate(reason: "test").isRetryable == false)
            #expect(LLMError.cancelled.isRetryable == false)
        }

        @Test("equatable works for simple cases")
        func testEquatable() {
            #expect(LLMError.notConfigured == LLMError.notConfigured)
            #expect(LLMError.timeout == LLMError.timeout)
            #expect(LLMError.emptyInput(field: "a") == LLMError.emptyInput(field: "a"))
            #expect(LLMError.emptyInput(field: "a") != LLMError.emptyInput(field: "b"))
            #expect(LLMError.rateLimited(retryAfter: 10) == LLMError.rateLimited(retryAfter: 10))
            #expect(LLMError.rateLimited(retryAfter: 10) != LLMError.rateLimited(retryAfter: 20))
        }
    }

    // MARK: - RetryConfiguration Tests

    @Suite("RetryConfiguration")
    struct RetryConfigurationTests {

        @Test("default configuration has sensible values")
        func testDefaultConfiguration() {
            let config = RetryConfiguration.default
            #expect(config.maxRetries == 3)
            #expect(config.baseDelay == 1.0)
            #expect(config.maxDelay == 8.0)
        }

        @Test("delay uses exponential backoff")
        func testExponentialBackoff() {
            let config = RetryConfiguration(maxRetries: 5, baseDelay: 1.0, maxDelay: 100.0)

            #expect(config.delay(for: 0) == 1.0)   // 1 * 2^0 = 1
            #expect(config.delay(for: 1) == 2.0)   // 1 * 2^1 = 2
            #expect(config.delay(for: 2) == 4.0)   // 1 * 2^2 = 4
            #expect(config.delay(for: 3) == 8.0)   // 1 * 2^3 = 8
            #expect(config.delay(for: 4) == 16.0)  // 1 * 2^4 = 16
        }

        @Test("delay respects maxDelay cap")
        func testMaxDelayCap() {
            let config = RetryConfiguration(maxRetries: 10, baseDelay: 1.0, maxDelay: 5.0)

            #expect(config.delay(for: 0) == 1.0)
            #expect(config.delay(for: 1) == 2.0)
            #expect(config.delay(for: 2) == 4.0)
            #expect(config.delay(for: 3) == 5.0)  // Capped at maxDelay
            #expect(config.delay(for: 10) == 5.0) // Still capped
        }

        @Test("custom base delay scales properly")
        func testCustomBaseDelay() {
            let config = RetryConfiguration(maxRetries: 3, baseDelay: 0.5, maxDelay: 10.0)

            #expect(config.delay(for: 0) == 0.5)  // 0.5 * 2^0 = 0.5
            #expect(config.delay(for: 1) == 1.0)  // 0.5 * 2^1 = 1.0
            #expect(config.delay(for: 2) == 2.0)  // 0.5 * 2^2 = 2.0
        }
    }

    // MARK: - LLMInputValidator Tests

    @Suite("LLMInputValidator")
    struct LLMInputValidatorTests {

        @Test("validateTranslation accepts valid inputs")
        func testValidTranslationInputs() throws {
            try LLMInputValidator.validateTranslation(
                query: "What processes are running?",
                schemaContext: "processes: name, pid"
            )
        }

        @Test("validateTranslation throws for empty query")
        func testEmptyQuery() {
            #expect(throws: LLMError.self) {
                try LLMInputValidator.validateTranslation(query: "", schemaContext: "schema")
            }
        }

        @Test("validateTranslation throws for whitespace-only query")
        func testWhitespaceQuery() {
            #expect(throws: LLMError.self) {
                try LLMInputValidator.validateTranslation(query: "   \n\t  ", schemaContext: "schema")
            }
        }

        @Test("validateTranslation throws for empty schema")
        func testEmptySchema() {
            #expect(throws: LLMError.self) {
                try LLMInputValidator.validateTranslation(query: "query", schemaContext: "")
            }
        }

        @Test("validateTranslation error specifies field name")
        func testTranslationErrorFieldName() {
            do {
                try LLMInputValidator.validateTranslation(query: "", schemaContext: "schema")
                Issue.record("Expected error to be thrown")
            } catch let error as LLMError {
                if case .emptyInput(let field) = error {
                    #expect(field == "query")
                } else {
                    Issue.record("Expected emptyInput error")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("validateSummarization accepts valid inputs")
        func testValidSummarizationInputs() throws {
            try LLMInputValidator.validateSummarization(
                question: "What is the uptime?",
                sql: "SELECT * FROM uptime"
            )
        }

        @Test("validateSummarization throws for empty question")
        func testEmptyQuestion() {
            #expect(throws: LLMError.self) {
                try LLMInputValidator.validateSummarization(question: "", sql: "SELECT 1")
            }
        }

        @Test("validateSummarization throws for empty SQL")
        func testEmptySQL() {
            #expect(throws: LLMError.self) {
                try LLMInputValidator.validateSummarization(question: "test", sql: "")
            }
        }
    }

    // MARK: - LLMResponseCleaner Tests

    @Suite("LLMResponseCleaner")
    struct LLMResponseCleanerTests {

        @Test("cleanSQL removes sql code fence")
        func testRemovesSqlCodeFence() {
            let input = "```sql\nSELECT * FROM users;\n```"
            let result = LLMResponseCleaner.cleanSQL(input)
            #expect(result == "SELECT * FROM users;")
        }

        @Test("cleanSQL removes plain code fence")
        func testRemovesPlainCodeFence() {
            let input = "```\nSELECT * FROM users;\n```"
            let result = LLMResponseCleaner.cleanSQL(input)
            #expect(result == "SELECT * FROM users;")
        }

        @Test("cleanSQL trims whitespace")
        func testTrimsWhitespace() {
            let input = "  \n  SELECT * FROM users;  \n  "
            let result = LLMResponseCleaner.cleanSQL(input)
            #expect(result == "SELECT * FROM users;")
        }

        @Test("cleanSQL handles already clean input")
        func testAlreadyClean() {
            let input = "SELECT * FROM users;"
            let result = LLMResponseCleaner.cleanSQL(input)
            #expect(result == "SELECT * FROM users;")
        }

        @Test("cleanSQL handles multiple code fences")
        func testMultipleCodeFences() {
            let input = "```sql\nSELECT 1;\n```\n```sql\nSELECT 2;\n```"
            let result = LLMResponseCleaner.cleanSQL(input)
            // Both statements should be preserved (order and content)
            #expect(result.contains("SELECT 1;"))
            #expect(result.contains("SELECT 2;"))
            #expect(!result.contains("```"))
        }
    }

    // MARK: - HTTPStatusHandler Tests

    @Suite("HTTPStatusHandler")
    struct HTTPStatusHandlerTests {

        private func createResponse(statusCode: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
            HTTPURLResponse(
                url: URL(string: "https://api.example.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
        }

        @Test("200 does not throw")
        func testSuccess() throws {
            let response = createResponse(statusCode: 200)
            try HTTPStatusHandler.handle(
                statusCode: 200,
                response: response,
                data: Data(),
                serviceName: "Test",
                parseError: { _ in nil }
            )
        }

        @Test("401 throws invalidAPIKey")
        func test401() {
            let response = createResponse(statusCode: 401)
            #expect(throws: LLMError.invalidAPIKey) {
                try HTTPStatusHandler.handle(
                    statusCode: 401,
                    response: response,
                    data: Data(),
                    serviceName: "Test",
                    parseError: { _ in nil }
                )
            }
        }

        @Test("429 throws rateLimited")
        func test429() {
            let response = createResponse(statusCode: 429)
            do {
                try HTTPStatusHandler.handle(
                    statusCode: 429,
                    response: response,
                    data: Data(),
                    serviceName: "Test",
                    parseError: { _ in nil }
                )
                Issue.record("Expected error")
            } catch let error as LLMError {
                if case .rateLimited = error {
                    // Expected
                } else {
                    Issue.record("Expected rateLimited error")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("429 extracts retry-after header")
        func test429WithRetryAfter() {
            let response = createResponse(statusCode: 429, headers: ["retry-after": "60"])
            do {
                try HTTPStatusHandler.handle(
                    statusCode: 429,
                    response: response,
                    data: Data(),
                    serviceName: "Test",
                    parseError: { _ in nil }
                )
                Issue.record("Expected error")
            } catch let error as LLMError {
                if case .rateLimited(let retryAfter) = error {
                    #expect(retryAfter == 60)
                } else {
                    Issue.record("Expected rateLimited error")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("4xx throws cannotTranslate with parsed message")
        func test4xxWithParsedError() {
            let response = createResponse(statusCode: 400)
            do {
                try HTTPStatusHandler.handle(
                    statusCode: 400,
                    response: response,
                    data: Data(),
                    serviceName: "Test",
                    parseError: { _ in "Custom error message" }
                )
                Issue.record("Expected error")
            } catch let error as LLMError {
                if case .cannotTranslate(let reason) = error {
                    #expect(reason == "Custom error message")
                } else {
                    Issue.record("Expected cannotTranslate error")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("5xx throws networkError")
        func test5xx() {
            let response = createResponse(statusCode: 500)
            do {
                try HTTPStatusHandler.handle(
                    statusCode: 500,
                    response: response,
                    data: Data(),
                    serviceName: "TestService",
                    parseError: { _ in nil }
                )
                Issue.record("Expected error")
            } catch let error as LLMError {
                if case .networkError = error {
                    // Expected
                } else {
                    Issue.record("Expected networkError")
                }
            } catch {
                Issue.record("Unexpected error type")
            }
        }

        @Test("unknown status throws invalidResponse")
        func testUnknownStatus() {
            let response = createResponse(statusCode: 999)
            #expect(throws: LLMError.invalidResponse) {
                try HTTPStatusHandler.handle(
                    statusCode: 999,
                    response: response,
                    data: Data(),
                    serviceName: "Test",
                    parseError: { _ in nil }
                )
            }
        }
    }
}
