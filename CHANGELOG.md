# Changelog

All notable changes to Osquery NLI will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2026-01-12

### Added
- **Recent Exports Quick Access** - Re-export results to recent locations with one click
  - Tracks last 5 export locations (JSON, CSV, Markdown, Excel)
  - "Export Again" section in Export menu shows recent destinations
  - Save dialogs now default to last export directory
  - Supports all export formats with file type icons

- **Undo for Destructive Actions** - 5-second undo window after deletions
  - Toast notification appears when deleting favorites or scheduled queries
  - Click "Undo" to restore deleted items
  - Scheduled query results preserved until undo expires

- **Template Search Ranking** - Search results sorted by relevance
  - Title matches weighted highest (prefix matches prioritized)
  - Query and description matches also contribute to score
  - Multi-term searches boost results matching all terms

- **Favorites Drag Reordering** - Organize favorites via drag and drop
  - Drag handle icon for visual affordance
  - Reorder persisted automatically

## [1.5.1] - 2026-01-12

### Improved
- **Schema Browser Keyboard Navigation** - Full keyboard support for the schema browser
  - Arrow keys to navigate tables and columns
  - Tab/Shift+Tab to switch between panels
  - Return to toggle table enabled state
  - ⌘E to toggle "Enabled only" filter

- **Accessibility** - Comprehensive VoiceOver support
  - Added accessibility labels to all icons and interactive elements
  - Screen reader support for Schema Browser, History, Favorites, Scheduled Queries
  - Proper element grouping for better navigation

- **Code Quality** - Reduced code duplication in LLM services
  - Shared `cleanSQLResponse()` method in protocol extension
  - Shared `HTTPStatusHandler` for HTTP error handling
  - Centralized `AppLogger` for consistent OSLog logging

### Fixed
- **Security Hardening** - File permissions for data directories
  - Data directories now created with 0700 permissions (owner-only access)
  - Applies to query history, scheduled queries, and results storage

## [1.5.0] - 2026-01-12

### Added
- **LLM Retry Logic** - Automatic retry with exponential backoff for rate limits and network errors
  - Retries up to 3 times with 1s, 2s, 4s delays
  - Respects rate limit retry-after headers
  - Works with all providers: Gemini, Claude, and OpenAI

- **Delete Confirmation Dialogs** - Prevent accidental data loss
  - Confirmation required when deleting favorites
  - Confirmation required when deleting scheduled queries (also clears stored results)

### Fixed
- **Scheduled Query Results** - Fixed thread-safety issues in result storage
  - Added proper synchronization with NSLock
  - Directory creation verified before each save
  - Added detailed logging for debugging

- **AppState.shared Safety** - Changed from force-unwrapped to optional
  - Prevents potential crash if accessed before initialization
  - Shortcuts already handle nil case gracefully

## [1.4.2] - 2026-01-12

### Fixed
- **Results Storage Debug** - Added logging to diagnose results not being saved
- **Date Decoding** - Fixed missing ISO8601 date decoding strategy when loading results

## [1.4.1] - 2026-01-12

### Improved
- **Scheduled Query Results** - Now shows actual data, not just metadata
  - View the full data table that triggered an alert
  - Results stored with up to 100 rows per run
  - Tabbed interface: "Latest Results" (data table) and "History" (chart + list)
  - Click any historical run to view its data
  - "Run Now" button shows loading indicator and opens results automatically
- **Notification Click** - Opens results view directly showing the data
- **Better Empty State** - "Run Now" button when no results exist yet

## [1.4.0] - 2026-01-12

### Added
- **Query Scheduling** - Run queries automatically at configurable intervals
  - Schedule queries to run every 5/15/30 minutes, hourly, every 6 hours, or daily
  - Support for both natural language and raw SQL queries
  - View run history with result counts over time
  - Results stored locally with automatic cleanup (max 100 per query)
  - Enable/disable individual schedules or the entire scheduler

- **Notifications & Alerts** - Get notified when query results meet conditions
  - Alert when: any results, no results, more/fewer than N results, or column contains value
  - Optional notification when result count changes
  - macOS native notifications with "View Results" action
  - Notification permission request integrated into UI

- **Scheduled Queries Window** (Cmd+Shift+S) - Manage all scheduled queries
  - Add, edit, and delete scheduled queries
  - View results history with charts
  - Test queries before scheduling
  - Run any scheduled query on-demand

## [1.3.0] - 2026-01-10

### Added
- **Menu Bar Quick Actions** - Right-click the menu bar icon to access:
  - **Favorites submenu** - Run your favorite queries directly (⌘1-9 shortcuts)
  - **Recent Queries submenu** - Quick access to last 8 queries
  - Click any item to open query window and execute immediately

### Improved
- **Better LLM Prompts** - Significantly improved SQL translation accuracy:
  - Added concrete examples for common query patterns
  - Clearer guidance for process and app searches
  - Explicit warnings about common column name mistakes
  - More structured prompt format for consistent results
  - Better summarization with clearer yes/no answers

## [1.2.2] - 2026-01-09

### Fixed
- **Shortcuts**: Added 500 row limit to prevent large results causing issues
- **Shortcuts**: Clamped history limit parameter to valid range (1-100)
- **Shortcuts**: Fixed inefficient date formatter creation in history loop
- **Crash detection**: Fixed table name extraction for consecutive uppercase (e.g., USBDevices → usb_devices)

## [1.2.1] - 2026-01-09

### Fixed
- **Crash handling**: osquery crashes (e.g., buggy tables like `connected_displays`) now show a user-friendly error message instead of raw stack traces
- Detects crash signatures and identifies the problematic table when possible

## [1.2.0] - 2026-01-09

### Added
- **macOS Shortcuts Integration** - Automate queries with the Shortcuts app
  - "Run Natural Language Query" - Ask questions in plain English
  - "Run SQL Query" - Execute raw osquery SQL directly
  - "Get Query History" - Retrieve recent queries
  - Siri integration with voice phrases like "Ask Osquery NLI about my Mac"
  - Pre-configured shortcuts appear automatically in Shortcuts app

## [1.1.1] - 2025-01-09

### Fixed
- **Schema Browser**: Fixed column parsing for osquery tables (schema uses backtick-quoted column names)

## [1.1.0] - 2025-01-09

### Added
- **Schema Browser** (⌘B) - Visual browser for osquery tables and columns
  - Search and filter tables by name
  - Toggle "Enabled only" to see active tables
  - View column names and types for any table
  - Enable/disable tables directly from browser
  - Copy schema to clipboard
  - AI Discovery tables highlighted with purple badge
- **Token Usage Display** - Shows API token consumption after each query
  - Total tokens (input + output breakdown)
  - Displayed next to execution time in results
  - Works with all providers: Gemini, Claude, and OpenAI

## [1.0.9] - 2025-01-09

### Fixed
- **Critical bug**: Menu bar icon not appearing on launch (guard statement in updateMenuBarIcon was returning early on first call)

## [1.0.8] - 2025-01-09

### Added
- **Keyboard shortcuts overlay** (⌘?) - Quick reference for all shortcuts with tips
- **Query auto-complete** - Smart suggestions from tables, favorites, history, and keywords
- **Animated loading states** - Stage-specific icons with rotating ring animation
- **Menu bar status indicator** - Animated color cycling when query is running

### Changed
- Loading view now shows progress connectors between stages
- Improved keyboard navigation in auto-complete (↑/↓/Enter/Esc)
- Menu bar tooltip shows current status

## [1.0.7] - 2025-01-09

### Added
- **MCP Server v1.3.0** with 3 new tools:
  - `osquery_ask` - Natural language queries (translates to SQL, executes, summarizes)
  - `osquery_history` - View query history from app and MCP with filtering
  - `osquery_examples` - Get example queries for 16 common tables
- Example queries for processes, users, apps, network, security, and AI tables
- Unit tests expanded from 17 to 84 tests

### Changed
- MCP server now has 8 tools total for comprehensive osquery interaction

## [1.0.6] - 2025-01-09

### Added
- **Font size preference** - Choose Small, Regular, or Large text in Settings → Appearance
- **Column sorting** - Click column headers in results table to sort (ascending → descending → clear)
- **Recent queries dropdown** - Clock icon shows last 10 queries for quick access
- Dynamic version display from Info.plist (no more hardcoded versions)

### Changed
- Settings window reorganized with new Appearance tab
- Results table columns now scale with font size preference

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

[1.5.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.4.2...v1.5.0
[1.4.2]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.9...v1.1.0
[1.0.9]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.8...v1.0.9
[1.0.8]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.7...v1.0.8
[1.0.7]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.6...v1.0.7
[1.0.6]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/juergen-kc/OsqueryNLI/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/juergen-kc/OsqueryNLI/releases/tag/v1.0.0
