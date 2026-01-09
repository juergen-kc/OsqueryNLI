# Changelog

All notable changes to Osquery NLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2025-01-09

### Added
- CHANGELOG.md with detailed release notes
- Keyboard shortcuts section in README

### Changed
- Updated README with version history and export formats

## [1.0.4] - 2025-01-09

### Added
- Query history refresh button in History view
- Unit tests for QueryHistoryEntry and QueryHistoryLogger (17 tests)
- Accessibility labels on all icon-only buttons
- Keyboard shortcut hints in empty state view
- History browsing indicator with escape key support
- Animated transitions between query states
- Hover effects on quick start buttons
- Save feedback toast for file exports

### Changed
- Improved empty state illustrations with hierarchical SF Symbols
- Better color contrast for stage indicators
- Cache now invalidates when model changes (not just provider)
- Result table limits display to 1000 rows for performance

### Fixed
- MCP server process management and error handling
- Table loading error now shows warning with retry button

## [1.0.3] - 2025-01-08

### Added
- Homebrew formula for easy installation (`brew install --cask osquery-nli`)
- Auto-update checker integration with Homebrew
- Input history navigation with arrow keys
- Window position persistence across launches

### Changed
- Improved window management and focus handling

## [1.0.2] - 2025-01-08

### Fixed
- SHA256 checksum for Homebrew cask

## [1.0.1] - 2025-01-08

### Added
- GitHub Sponsors funding configuration

## [1.0.0] - 2025-01-08

### Added
- Natural language query interface for osquery
- Support for multiple AI providers:
  - Google Gemini (default)
  - Anthropic Claude
  - OpenAI GPT
- AI Discovery extension with 7 custom tables:
  - `ai_tools_installed` - Installed AI applications
  - `ai_mcp_servers` - MCP server configurations
  - `ai_env_vars` - AI-related environment variables
  - `ai_browser_extensions` - AI browser extensions
  - `ai_code_assistants` - Code assistant configurations
  - `ai_api_keys` - Configured API keys (presence only)
  - `ai_local_servers` - Local AI servers
- Query templates library with 50+ pre-built queries
- Query history with App/MCP source filtering
- Favorites system for saving frequent queries
- Export results to JSON, CSV, Markdown, and Excel (XLSX)
- Built-in MCP server for Claude Desktop and Cursor integration
- Query result caching with smart invalidation
- Secure API key storage in macOS Keychain
- Menu bar app with popover quick query
- Full window mode for detailed results
- Code-signed and notarized for macOS distribution

### Technical
- Swift 6.0 with SwiftUI
- macOS 14.0+ (Sonoma) required
- osquery integration via osqueryi CLI
- AI Discovery extension written in Go

[1.0.5]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/juergen-kc/OsqueryNLI/releases/tag/v1.0.0
