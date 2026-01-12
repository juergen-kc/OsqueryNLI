import Foundation

/// Token usage information from LLM API calls
public struct TokenUsage: Sendable, Codable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public var totalTokens: Int { inputTokens + outputTokens }

    public init(inputTokens: Int = 0, outputTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    /// Combine two token usages (for aggregating translation + summarization)
    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens
        )
    }
}
