import Foundation
import OsqueryNLICore

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

/// Extension to add input validation and shared utility helpers
extension LLMServiceProtocol {
    /// Validate inputs for translateToSQL
    func validateTranslationInput(query: String, schemaContext: String) throws {
        try LLMInputValidator.validateTranslation(query: query, schemaContext: schemaContext)
    }

    /// Validate inputs for summarizeResults
    func validateSummarizationInput(question: String, sql: String) throws {
        try LLMInputValidator.validateSummarization(question: question, sql: sql)
    }

    /// Clean SQL response by removing markdown code fences and trimming whitespace
    func cleanSQLResponse(_ text: String) -> String {
        LLMResponseCleaner.cleanSQL(text)
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
