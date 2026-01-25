import Foundation

/// Errors specific to LLM operations
public enum LLMError: LocalizedError, Equatable {
    case notConfigured
    case invalidAPIKey
    case emptyInput(field: String)
    case networkError(underlying: Error)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case invalidResponse
    case cannotTranslate(reason: String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM provider is not configured. Please set your API key in Settings."
        case .invalidAPIKey:
            return "Invalid API key. Please check your API key in Settings."
        case .emptyInput(let field):
            return "Cannot process request: \(field) is empty."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retry):
            if let retry {
                return "Rate limited. Please retry after \(Int(retry)) seconds."
            }
            return "Rate limited. Please try again later."
        case .timeout:
            return "Request timed out. Please try again."
        case .invalidResponse:
            return "Invalid response from LLM provider."
        case .cannotTranslate(let reason):
            return reason
        case .cancelled:
            return "Request was cancelled."
        }
    }

    /// Whether this error is retryable
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkError:
            return true
        case .notConfigured, .invalidAPIKey, .emptyInput, .invalidResponse, .cannotTranslate, .cancelled:
            return false
        }
    }

    // Equatable conformance (ignoring underlying error details for networkError)
    public static func == (lhs: LLMError, rhs: LLMError) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.invalidAPIKey, .invalidAPIKey),
             (.timeout, .timeout),
             (.invalidResponse, .invalidResponse),
             (.cancelled, .cancelled):
            return true
        case (.emptyInput(let l), .emptyInput(let r)):
            return l == r
        case (.rateLimited(let l), .rateLimited(let r)):
            return l == r
        case (.cannotTranslate(let l), .cannotTranslate(let r)):
            return l == r
        case (.networkError, .networkError):
            return true // Compare by case only, not underlying error
        default:
            return false
        }
    }
}

/// Configuration for retry behavior
public struct RetryConfiguration: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval

    public static let `default` = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 8.0)

    public init(maxRetries: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Calculate delay for a given attempt (exponential backoff)
    public func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
}

/// Helper for executing operations with retry logic
public enum RetryHelper {
    /// Execute an async operation with exponential backoff retry
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    public static func withRetry<T>(
        config: RetryConfiguration = .default,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...config.maxRetries {
            do {
                // Check for cancellation before each attempt
                try Task.checkCancellation()

                return try await operation()
            } catch let error as LLMError {
                lastError = error

                // Don't retry non-retryable errors
                guard error.isRetryable else {
                    throw error
                }

                // Don't retry if we've exhausted attempts
                guard attempt < config.maxRetries else {
                    throw error
                }

                // Calculate delay, respecting rate limit retry-after if available
                var delay = config.delay(for: attempt)
                if case .rateLimited(let retryAfter) = error, let retryAfter {
                    delay = max(delay, retryAfter)
                }

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch is CancellationError {
                throw LLMError.cancelled
            } catch {
                // For non-LLMError errors (shouldn't happen, but be safe)
                lastError = error
                throw error
            }
        }

        // Should never reach here, but just in case
        throw lastError ?? LLMError.invalidResponse
    }
}

/// Helper for handling common HTTP response status codes from LLM APIs
public enum HTTPStatusHandler {
    /// Handle HTTP status code and throw appropriate LLMError if needed
    /// - Parameters:
    ///   - statusCode: HTTP status code from response
    ///   - response: The HTTP response for extracting headers
    ///   - data: Response data for parsing error messages
    ///   - serviceName: Name of the service for error messages
    ///   - parseError: Closure to parse provider-specific error message from data
    /// - Throws: LLMError for non-200 status codes
    public static func handle(
        statusCode: Int,
        response: HTTPURLResponse,
        data: Data,
        serviceName: String,
        parseError: (Data) -> String?
    ) throws {
        switch statusCode {
        case 200:
            return // Success, no error
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "retry-after")
                .flatMap { Double($0) }
            throw LLMError.rateLimited(retryAfter: retryAfter)
        case 400...499:
            let errorMessage = parseError(data)
            throw LLMError.cannotTranslate(reason: errorMessage ?? "Client error: \(statusCode)")
        case 500...599:
            throw LLMError.networkError(underlying: NSError(
                domain: serviceName,
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error: \(statusCode)"]
            ))
        default:
            throw LLMError.invalidResponse
        }
    }
}

/// Utilities for cleaning LLM responses
public enum LLMResponseCleaner {
    /// Clean SQL response by removing markdown code fences and trimming whitespace
    /// This is shared across all LLM services since models often wrap SQL in markdown
    public static func cleanSQL(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```sql", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Input validation for LLM operations
public enum LLMInputValidator {
    /// Validate inputs for translation (query and schema)
    /// - Throws: LLMError.emptyInput if validation fails
    public static func validateTranslation(query: String, schemaContext: String) throws {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSchema = schemaContext.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            throw LLMError.emptyInput(field: "query")
        }
        if trimmedSchema.isEmpty {
            throw LLMError.emptyInput(field: "schema context")
        }
    }

    /// Validate inputs for summarization (question and SQL)
    /// - Throws: LLMError.emptyInput if validation fails
    public static func validateSummarization(question: String, sql: String) throws {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuestion.isEmpty {
            throw LLMError.emptyInput(field: "question")
        }
        if trimmedSQL.isEmpty {
            throw LLMError.emptyInput(field: "SQL")
        }
    }
}
