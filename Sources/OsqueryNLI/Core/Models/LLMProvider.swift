import Foundation

/// Supported LLM providers
enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case claude = "claude"
    case gemini = "gemini"
    case openai = "openai"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .gemini: return "Gemini (Google)"
        case .openai: return "GPT (OpenAI)"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .gemini: return "gemini-2.0-flash-lite"
        case .openai: return "gpt-4o-mini"
        }
    }

    var availableModels: [String] {
        switch self {
        case .claude: return ["claude-sonnet-4-20250514", "claude-3-5-haiku-20241022"]
        case .gemini: return ["gemini-2.0-flash-lite", "gemini-1.5-pro"]
        case .openai: return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo"]
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .claude: return "sk-ant-..."
        case .gemini: return "AIza..."
        case .openai: return "sk-..."
        }
    }

    var helpURL: URL {
        switch self {
        case .claude: return URL(string: "https://console.anthropic.com/")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        }
    }
}

/// Configuration for LLM provider
struct LLMConfiguration: Codable, Equatable {
    var provider: LLMProvider
    var model: String

    static var `default`: LLMConfiguration {
        LLMConfiguration(provider: .gemini, model: LLMProvider.gemini.defaultModel)
    }
}
