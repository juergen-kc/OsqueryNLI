import Foundation

/// LLM service implementation for Anthropic Claude
/// Note: @unchecked Sendable is safe because mutable `_currentTask` is protected by `lock`
/// and all other properties are immutable.
final class ClaudeService: LLMServiceProtocol, @unchecked Sendable {
    let provider: LLMProvider = .claude
    let model: String

    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let timeout: TimeInterval = 30.0
    private let lock = NSLock()
    private var _currentTask: Task<String, Error>?

    private var currentTask: Task<String, Error>? {
        get { lock.withLock { _currentTask } }
        set { lock.withLock { _currentTask = newValue } }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    init(apiKey: String, model: String = LLMProvider.claude.defaultModel) {
        self.apiKey = apiKey
        self.model = model
    }

    func translateToSQL(query: String, schemaContext: String) async throws -> TranslationResult {
        guard isConfigured else {
            throw LLMError.notConfigured
        }

        // Validate inputs
        try validateTranslationInput(query: query, schemaContext: schemaContext)

        let response = try await sendMessage(
            system: LLMPrompts.translationSystemPrompt(),
            user: LLMPrompts.translationUserPrompt(query: query, schemaContext: schemaContext)
        )

        let sql = cleanSQLResponse(response)

        if sql.uppercased().hasPrefix("ERROR:") {
            throw LLMError.cannotTranslate(reason: sql)
        }

        return TranslationResult(sql: sql)
    }

    func summarizeResults(
        question: String,
        sql: String,
        results: [[String: Any]]
    ) async throws -> SummaryResult {
        guard isConfigured else {
            throw LLMError.notConfigured
        }

        // Validate inputs
        try validateSummarizationInput(question: question, sql: sql)

        let jsonData = try JSONSerialization.data(withJSONObject: results, options: .prettyPrinted)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

        let response = try await sendMessage(
            system: LLMPrompts.summarizationSystemPrompt(),
            user: LLMPrompts.summarizationUserPrompt(question: question, sql: sql, jsonResults: jsonString)
        )

        return SummaryResult(answer: response.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Private API

    private func sendMessage(system: String, user: String) async throws -> String {
        // Cancel any existing task
        currentTask?.cancel()

        let task = Task<String, Error> {
            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.timeoutInterval = timeout

            let body: [String: Any] = [
                "model": model,
                "max_tokens": 2048,
                "system": system,
                "messages": [
                    ["role": "user", "content": user]
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch let error as URLError where error.code == .timedOut {
                throw LLMError.timeout
            } catch let error as URLError where error.code == .cancelled {
                throw LLMError.cancelled
            } catch {
                throw LLMError.networkError(underlying: error)
            }

            // Check for cancellation
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                throw LLMError.invalidAPIKey
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                    .flatMap { Double($0) }
                throw LLMError.rateLimited(retryAfter: retryAfter)
            case 400...499:
                let errorMessage = try? parseErrorMessage(from: data)
                throw LLMError.cannotTranslate(reason: errorMessage ?? "Client error: \(httpResponse.statusCode)")
            case 500...599:
                throw LLMError.networkError(underlying: NSError(
                    domain: "ClaudeService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]
                ))
            default:
                throw LLMError.invalidResponse
            }

            return try parseContentResponse(from: data)
        }

        currentTask = task

        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch is CancellationError {
            currentTask = nil
            throw LLMError.cancelled
        } catch {
            currentTask = nil
            throw error
        }
    }

    private func parseContentResponse(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text
    }

    private func parseErrorMessage(from data: Data) throws -> String? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func cleanSQLResponse(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```sql", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
