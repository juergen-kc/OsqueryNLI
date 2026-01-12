import Foundation

/// Token usage information from LLM API calls
struct TokenUsage: Sendable, Codable {
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    init(inputTokens: Int = 0, outputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    /// Combine two token usages (for aggregating translation + summarization)
    static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens
        )
    }
}

/// Result of translating natural language to SQL
struct TranslationResult: Sendable {
    let sql: String
    let explanation: String?
    let confidence: Double?
    let tokenUsage: TokenUsage?

    init(sql: String, explanation: String? = nil, confidence: Double? = nil, tokenUsage: TokenUsage? = nil) {
        self.sql = sql
        self.explanation = explanation
        self.confidence = confidence
        self.tokenUsage = tokenUsage
    }
}

/// Result of summarizing query results
struct SummaryResult: Sendable {
    let answer: String
    let highlights: [String]?
    let tokenUsage: TokenUsage?

    init(answer: String, highlights: [String]? = nil, tokenUsage: TokenUsage? = nil) {
        self.answer = answer
        self.highlights = highlights
        self.tokenUsage = tokenUsage
    }
}

/// Protocol for all LLM providers
protocol LLMServiceProtocol: Sendable {
    /// The provider type
    var provider: LLMProvider { get }

    /// The current model being used
    var model: String { get }

    /// Whether the service is configured and ready
    var isConfigured: Bool { get }

    /// Translate natural language to osquery SQL
    /// - Parameters:
    ///   - query: Natural language query from user
    ///   - schemaContext: Schema information for available tables
    /// - Returns: Translation result containing SQL
    func translateToSQL(query: String, schemaContext: String) async throws -> TranslationResult

    /// Summarize query results into natural language
    /// - Parameters:
    ///   - question: Original user question
    ///   - sql: SQL that was executed
    ///   - results: Results from osquery
    /// - Returns: Summary result with natural language answer
    func summarizeResults(
        question: String,
        sql: String,
        results: [[String: Any]]
    ) async throws -> SummaryResult

    /// Cancel any ongoing requests
    func cancel()
}

/// Errors specific to LLM operations
enum LLMError: LocalizedError {
    case notConfigured
    case invalidAPIKey
    case emptyInput(field: String)
    case networkError(underlying: Error)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case invalidResponse
    case cannotTranslate(reason: String)
    case cancelled

    var errorDescription: String? {
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
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkError:
            return true
        case .notConfigured, .invalidAPIKey, .emptyInput, .invalidResponse, .cannotTranslate, .cancelled:
            return false
        }
    }
}

/// Configuration for retry behavior
struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval

    static let `default` = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 8.0)

    /// Calculate delay for a given attempt (exponential backoff)
    func delay(for attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
}

/// Helper for executing operations with retry logic
enum RetryHelper {
    /// Execute an async operation with exponential backoff retry
    /// - Parameters:
    ///   - config: Retry configuration
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    static func withRetry<T>(
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

/// Extension to add input validation helpers
extension LLMServiceProtocol {
    /// Validate inputs for translateToSQL
    func validateTranslationInput(query: String, schemaContext: String) throws {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSchema = schemaContext.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            throw LLMError.emptyInput(field: "query")
        }
        if trimmedSchema.isEmpty {
            throw LLMError.emptyInput(field: "schema context")
        }
    }

    /// Validate inputs for summarizeResults
    func validateSummarizationInput(question: String, sql: String) throws {
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

/// Shared prompt templates for all providers
enum LLMPrompts {
    static func translationSystemPrompt() -> String {
        """
        You are an expert osquery SQL translator for macOS systems.
        Translate natural language questions into valid osquery SQL.

        CRITICAL RULES:
        1. Return ONLY raw SQL. No markdown, no explanations, no code fences, no ```sql blocks.
        2. Use ONLY tables and columns EXACTLY as shown in the schema. Never invent columns.
        3. If impossible with available tables: return exactly "ERROR: Cannot answer with available tables."

        QUERY PATTERNS:
        - Status checks ("is X enabled?"): SELECT all relevant columns, don't filter. Let results speak.
        - Process searches: Use LIKE with wildcards on both name AND path columns.
          Example: WHERE name LIKE '%Chrome%' OR path LIKE '%Chrome%'
        - App searches: Search path for '.app' pattern: WHERE path LIKE '%AppName.app%'
        - Large tables (processes, files): Always use LIMIT unless user wants all.
        - Multiple tables: Use semicolon to separate queries. Never UNION different schemas.

        COMMON MISTAKES TO AVOID:
        - Don't use `type` for launchd - use `process_type`
        - Don't use `run_at_startup` - use `run_at_load`
        - Don't filter on boolean values like WHERE enabled = 'true' - values vary ('1', 'on', 'yes', etc.)
        - Don't guess column names - verify against schema first

        EXAMPLES:
        Q: "What's my system uptime?" → SELECT * FROM uptime;
        Q: "Is FileVault enabled?" → SELECT * FROM disk_encryption;
        Q: "Top 5 CPU processes" → SELECT name, pid, cpu_percent FROM processes ORDER BY cpu_percent DESC LIMIT 5;
        Q: "Is Chrome running?" → SELECT name, pid, path FROM processes WHERE name LIKE '%Chrome%' OR path LIKE '%Chrome%';
        Q: "What starts at login?" → SELECT name, program, run_at_load FROM launchd WHERE run_at_load = '1' LIMIT 20;
        """
    }

    static func translationUserPrompt(query: String, schemaContext: String) -> String {
        """
        AVAILABLE TABLES AND COLUMNS:
        \(schemaContext)

        USER QUESTION: "\(query)"

        SQL:
        """
    }

    static func summarizationSystemPrompt() -> String {
        """
        You are a helpful system analyst explaining osquery results to users.

        Guidelines:
        - Be concise but informative (2-4 sentences typically)
        - Answer the user's actual question, don't just describe the data
        - Highlight important findings or anomalies
        - For empty results: explain what that means (e.g., "No matching processes found" or "Feature is not enabled")
        - Use plain language, avoid jargon unless the user used it
        - For counts: state the number clearly
        - For status checks: give a clear yes/no answer with context
        """
    }

    static func summarizationUserPrompt(question: String, sql: String, jsonResults: String) -> String {
        """
        User's question: "\(question)"

        SQL executed:
        \(sql)

        Results:
        \(jsonResults)

        Provide a helpful, concise answer:
        """
    }
}
