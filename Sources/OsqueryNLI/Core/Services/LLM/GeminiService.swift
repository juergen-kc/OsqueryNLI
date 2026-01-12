import Foundation
@preconcurrency import GoogleGenerativeAI

/// LLM service implementation for Google Gemini
/// Note: @unchecked Sendable is safe because:
/// - `generativeModel` is only set during init (effectively immutable)
/// - `_currentTask` is protected by `lock`
/// - Google's GenerativeModel is documented as thread-safe internally
final class GeminiService: LLMServiceProtocol, @unchecked Sendable {
    let provider: LLMProvider = .gemini
    let model: String

    // Set only during init, never mutated afterwards
    private var generativeModel: GenerativeModel?
    private let apiKey: String
    private let timeout: TimeInterval = 30.0
    private let lock = NSLock()
    private var _currentTask: Task<String, Error>?

    private var currentTask: Task<String, Error>? {
        get { lock.withLock { _currentTask } }
        set { lock.withLock { _currentTask = newValue } }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty && generativeModel != nil
    }

    init(apiKey: String, model: String = LLMProvider.gemini.defaultModel) {
        self.apiKey = apiKey
        self.model = model

        if !apiKey.isEmpty {
            self.generativeModel = GenerativeModel(name: model, apiKey: apiKey)
        }
    }

    func translateToSQL(query: String, schemaContext: String) async throws -> TranslationResult {
        guard let model = generativeModel else {
            throw LLMError.notConfigured
        }

        // Validate inputs
        try validateTranslationInput(query: query, schemaContext: schemaContext)

        let prompt = """
        \(LLMPrompts.translationSystemPrompt())

        \(LLMPrompts.translationUserPrompt(query: query, schemaContext: schemaContext))
        """

        let (text, tokenUsage) = try await RetryHelper.withRetry {
            try await sendRequest(model: model, prompt: prompt)
        }

        let sql = cleanSQLResponse(text)

        if sql.uppercased().hasPrefix("ERROR:") {
            throw LLMError.cannotTranslate(reason: sql)
        }

        return TranslationResult(sql: sql, tokenUsage: tokenUsage)
    }

    func summarizeResults(
        question: String,
        sql: String,
        results: [[String: Any]]
    ) async throws -> SummaryResult {
        guard let model = generativeModel else {
            throw LLMError.notConfigured
        }

        // Validate inputs
        try validateSummarizationInput(question: question, sql: sql)

        let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        let prompt = """
        \(LLMPrompts.summarizationSystemPrompt())

        \(LLMPrompts.summarizationUserPrompt(question: question, sql: sql, jsonResults: jsonString))
        """

        let (text, tokenUsage) = try await RetryHelper.withRetry {
            try await sendRequest(model: model, prompt: prompt)
        }

        return SummaryResult(answer: text.trimmingCharacters(in: .whitespacesAndNewlines), tokenUsage: tokenUsage)
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Private Helpers

    /// Response from Gemini including text and token usage
    private struct GeminiResponse: Sendable {
        let text: String
        let tokenUsage: TokenUsage?
    }

    private func sendRequest(model: GenerativeModel, prompt: String) async throws -> (String, TokenUsage?) {
        // Cancel any existing task
        currentTask?.cancel()

        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)

        // Use nonisolated(unsafe) to allow capturing the non-Sendable GenerativeModel
        // This is safe because we're the only accessor and the model is thread-safe internally
        nonisolated(unsafe) let unsafeModel = model
        let promptCopy = prompt

        let task = Task<GeminiResponse, Error> {
            do {
                let response = try await unsafeModel.generateContent(promptCopy)

                guard let text = response.text else {
                    throw LLMError.invalidResponse
                }

                // Extract token usage from usage metadata
                var tokenUsage: TokenUsage?
                if let usage = response.usageMetadata {
                    tokenUsage = TokenUsage(
                        inputTokens: usage.promptTokenCount,
                        outputTokens: usage.candidatesTokenCount
                    )
                }

                return GeminiResponse(text: text, tokenUsage: tokenUsage)
            } catch is CancellationError {
                throw LLMError.cancelled
            } catch let error as GenerateContentError {
                switch error {
                case .promptBlocked:
                    throw LLMError.cannotTranslate(reason: "Request blocked by content filter")
                case .responseStoppedEarly:
                    throw LLMError.invalidResponse
                default:
                    throw LLMError.networkError(underlying: error)
                }
            } catch {
                throw LLMError.networkError(underlying: error)
            }
        }

        // Store task for cancellation (we need to convert the type)
        let stringTask = Task<String, Error> {
            let result = try await task.value
            return result.text
        }
        currentTask = stringTask

        // Set up timeout cancellation
        Task {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            if !task.isCancelled {
                task.cancel()
            }
        }

        do {
            let result = try await task.value
            currentTask = nil
            return (result.text, result.tokenUsage)
        } catch is CancellationError {
            currentTask = nil
            throw LLMError.timeout
        } catch {
            currentTask = nil
            throw error
        }
    }
    // Note: cleanSQLResponse is now provided by LLMServiceProtocol extension
}
