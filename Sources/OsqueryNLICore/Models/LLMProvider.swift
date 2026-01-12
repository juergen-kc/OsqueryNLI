import Foundation

/// Supported LLM providers
public enum LLMProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case claude = "claude"
    case gemini = "gemini"
    case openai = "openai"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .gemini: return "Gemini (Google)"
        case .openai: return "GPT (OpenAI)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .gemini: return "gemini-2.0-flash-lite"
        case .openai: return "gpt-4o-mini"
        }
    }

    public var availableModels: [String] {
        switch self {
        case .claude: return ["claude-sonnet-4-20250514", "claude-3-5-haiku-20241022"]
        case .gemini: return ["gemini-2.0-flash-lite", "gemini-1.5-pro"]
        case .openai: return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        }
    }

    public var apiKeyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .gemini: return "AIza..."
        case .openai: return "sk-..."
        }
    }

    public var helpURL: URL {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        }
    }
}

/// Configuration for LLM provider
public struct LLMConfiguration: Codable, Equatable, Sendable {
    public var provider: LLMProvider
    public var model: String

    public init(provider: LLMProvider, model: String) {
        self.provider = provider
        self.model = model
    }

    public static var `default`: LLMConfiguration {
        LLMConfiguration(provider: .gemini, model: LLMProvider.gemini.defaultModel)
    }
}
