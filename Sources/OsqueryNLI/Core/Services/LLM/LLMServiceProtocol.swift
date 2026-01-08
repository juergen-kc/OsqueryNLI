import Foundation

/// Result of translating natural language to SQL
struct TranslationResult: Sendable {
    let sql: String
    let explanation: String?
    let confidence: Double?

    init(sql: String, explanation: String? = nil, confidence: Double? = nil) {
        self.sql = sql
        self.explanation = explanation
        self.confidence = confidence
    }
}

/// Result of summarizing query results
struct SummaryResult: Sendable {
    let answer: String
    let highlights: [String]?

    init(answer: String, highlights: [String]? = nil) {
        self.answer = answer
        self.highlights = highlights
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
        You are an expert in osquery SQL.
        Your task is to translate natural language queries into valid osquery SQL statements.

        Rules:
        1. Return ONLY the SQL query. No markdown, no explanations, no code fences.
        2. The query must be valid SQLite syntax as used by osquery.
        3. CRITICAL: Only use tables AND columns that are EXACTLY listed in the provided schema context. Do not invent or guess column names.
        4. If the query cannot be answered with the given tables, return exactly: ERROR: Cannot answer with available tables.
        5. If you need to query multiple tables that cannot be joined, return multiple SQL statements separated by a semicolon (;).
        6. Do NOT use UNION for tables with different schemas.
        7. IMPORTANT: Do NOT assume or guess column values. For yes/no questions (like "is X enabled?"), query ALL relevant columns without WHERE filters on status values. The summarizer will interpret the results. Column values vary (e.g., "on"/"off", "1"/"0", "enabled"/"disabled", "true"/"false").
        8. Prefer broader queries (SELECT * or SELECT relevant_columns FROM table) over narrow filtered queries when checking status or existence.
        9. Use LIMIT for potentially large result sets (processes, files, etc.) unless the user asks for all results.
        10. For PROCESS searches: Use LIKE patterns with wildcards, not exact matches. Process names on macOS often differ from app names. Example: To find Safari, use `WHERE name LIKE '%Safari%' OR path LIKE '%Safari%'`. Also search the path column since many macOS apps have unique executable names.
        11. For APPLICATION searches: Check both the `processes` table (for running apps) and search by path containing the app name (e.g., `path LIKE '%AppName.app%'`).
        12. IMPORTANT: Column names vary between tables! Check the EXACT schema provided. Examples: `launchd` uses `process_type` (NOT `type`), `run_at_load` (NOT `run_at_startup`). Always verify column names against the schema before using them.
        """
    }

    static func translationUserPrompt(query: String, schemaContext: String) -> String {
        """
        Schema context (available tables):
        \(schemaContext)

        Natural language query: "\(query)"
        """
    }

    static func summarizationSystemPrompt() -> String {
        """
        You are an expert system analyst.
        Provide concise, natural language answers based on osquery results.
        Do not just dump the data back. Interpret it meaningfully.
        If the result is empty, explain what that might mean.
        """
    }

    static func summarizationUserPrompt(question: String, sql: String, jsonResults: String) -> String {
        """
        The user asked: "\(question)"

        We ran the following osquery SQL:
        \(sql)

        Results (JSON):
        \(jsonResults)

        Provide a concise, natural language answer to the user's question based on these results.
        """
    }
}
