# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Osquery NLI is a macOS menu bar app that translates natural language queries into osquery SQL using AI (Gemini, Claude, or OpenAI).

## Build Commands

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift run OsqueryNLI           # Build and run
swift test                     # Run all tests
./scripts/build-release.sh     # Full release (sign, notarize, DMG)
./scripts/build-release.sh --skip-notarize  # Release without notarization
```

## Architecture

### Swift Package Targets
- **OsqueryNLI**: Main SwiftUI menu bar app
- **OsqueryNLICore**: Shared library (OsqueryService, ProcessRunner, data models)
- **OsqueryMCPServer**: MCP server for AI assistant integration (Claude Desktop, Cursor)

### Source Layout (Sources/)
```
OsqueryNLI/
├── App/           # App entry point, AppState, main window
├── Core/          # LLMService, OsqueryService wrappers
├── Features/      # UI features (Query, Settings, History, Favorites,
│                  # Templates, Export, Scheduled, Alerts)
└── Shared/        # Reusable UI components

OsqueryNLICore/    # Shared logic, no UI dependencies
└── Models/        # QueryResult, QueryHistoryEntry, FavoriteQuery, etc.

OsqueryMCPServer/  # Standalone MCP server executable
```

### Key Patterns
- **Feature-based organization**: Each feature (History, Favorites, Templates, etc.) is self-contained in Features/
- **Core separation**: OsqueryNLICore has no SwiftUI dependencies, enabling reuse by MCP server
- **Async/await**: All osquery and LLM operations are async
- **SwiftUI @AppStorage**: User settings persisted via @AppStorage

### AI Discovery Extension
A Go-based osquery extension (`Resources/ai_tables.ext`) adds 10 virtual tables for querying AI tools/configs. Built separately from `../osquery-ai-tables`:
```bash
cd ../osquery-ai-tables && go build -o ai_tables.ext . && cp ai_tables.ext ../Resources/
```

## Testing

Tests are in `Tests/OsqueryNLICoreTests/` using Swift Testing framework:
```bash
swift test                           # Run all tests
swift test --filter QueryResultTests # Run specific test suite
```

## Key Files
- `Package.swift` - SPM manifest (dependencies, targets)
- `Distribution/Info.plist` - App version (single source of truth)
- `Distribution/Entitlements.plist` - App security entitlements
- `docs/USER_GUIDE.md` - User documentation
- `docs/MCP_API.md` - MCP server API documentation
