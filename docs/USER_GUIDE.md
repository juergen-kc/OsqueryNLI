# Osquery NLI User Guide

This guide covers all features of Osquery NLI, a natural language interface for querying your Mac using osquery.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Making Queries](#making-queries)
3. [Query Templates](#query-templates)
4. [Schema Browser](#schema-browser)
5. [Query History](#query-history)
6. [Favorites](#favorites)
7. [Scheduled Queries](#scheduled-queries)
8. [Notifications & Alerts](#notifications--alerts)
9. [Exporting Results](#exporting-results)
10. [AI Discovery Tables](#ai-discovery-tables)
11. [Settings](#settings)
12. [Keyboard Shortcuts](#keyboard-shortcuts)
13. [MCP Server Integration](#mcp-server-integration)
14. [Troubleshooting](#troubleshooting)

---

## Getting Started

### First Launch

1. Click the Osquery NLI icon in your menu bar (magnifying glass icon)
2. The app will check for osquery installation
3. Go to **Settings > Provider** to configure your AI provider

### Configuring an AI Provider

Osquery NLI supports three AI providers:

| Provider | Model | Best For |
|----------|-------|----------|
| **Google Gemini** | gemini-2.0-flash | Fast responses, good accuracy |
| **Anthropic Claude** | claude-sonnet-4-20250514 | Complex queries, detailed explanations |
| **OpenAI GPT** | gpt-4o | Broad knowledge, flexible |

To configure:
1. Open Settings (gear icon or `Cmd+,`)
2. Select the **Provider** tab
3. Choose your provider
4. Enter your API key
5. Click **Save**

**Getting API Keys:**
- Gemini: [Google AI Studio](https://makersuite.google.com/app/apikey)
- Claude: [Anthropic Console](https://console.anthropic.com/)
- OpenAI: [OpenAI Platform](https://platform.openai.com/api-keys)

---

## Making Queries

### Natural Language Queries

Type your question in plain English:

```
What processes are using the most memory?
Show me all listening network ports
Is FileVault enabled?
What apps start at login?
```

Press `Cmd+Return` or click **Ask** to submit.

### SQL Queries

You can also enter raw osquery SQL:

```sql
SELECT name, resident_size FROM processes ORDER BY resident_size DESC LIMIT 10;
```

The app auto-detects SQL queries (starting with SELECT, PRAGMA, or EXPLAIN).

### Understanding Results

Results are displayed in a table format with:
- **Column headers** - Click to sort
- **Row count** - Shown in the status bar
- **SQL query** - The generated SQL is shown for transparency

Large result sets are truncated to 1,000 rows for performance.

### Query Actions

After getting results, you can:
- **Copy** - Copy results to clipboard
- **Export** - Save to JSON, CSV, Markdown, or Excel
- **Add to Favorites** - Save for quick access later
- **Schedule** - Run automatically at intervals

---

## Query Templates

Templates provide pre-built queries organized by category.

### Accessing Templates

1. Click **Templates** in the toolbar
2. Or press `Cmd+T`

### Categories

| Category | Examples |
|----------|----------|
| **System Info** | OS version, uptime, hardware info |
| **Processes** | Running processes, CPU usage, memory |
| **Network** | Listening ports, connections, interfaces |
| **Security** | FileVault status, SIP, firewall |
| **Hardware** | USB devices, battery, disk info |
| **Software** | Installed apps, browser extensions |
| **Files & Storage** | Disk usage, mounted volumes |
| **Troubleshooting** | Crashes, logs, diagnostics |
| **AI Discovery** | AI tools, MCP servers, models |

### Using Templates

1. Browse or search templates
2. Click a template to select it
3. Click **Use Template** or double-click to run immediately

### Search Ranking

When searching, templates are ranked by relevance:
- Title matches rank highest
- Query content matches rank medium
- Description matches rank lower
- Templates matching all search terms get a bonus

---

## Schema Browser

Browse all available osquery tables and their columns.

### Accessing the Schema Browser

1. Click **Schema** in the toolbar
2. Or press `Cmd+B`

### Features

- **Search** - Filter tables by name
- **Table details** - Click a table to see its columns
- **Column info** - Shows column name and data type
- **Example queries** - Some tables include example SQL

### Navigation

- `↑/↓` - Navigate tables
- `Return` - View table details
- `Esc` - Close details / exit browser
- Type to search

---

## Query History

All queries are automatically saved to history.

### Accessing History

1. Click **History** in the toolbar
2. Or press `Cmd+H`
3. Or press `↑` in an empty query field

### Features

- **Search** - Filter history by query text
- **Timestamps** - See when each query was run
- **Result count** - See how many results were returned
- **Re-run** - Click any history item to run it again

### History Navigation

In the query input field:
- `↑` - Previous query from history
- `↓` - Next query from history
- `Esc` - Exit history navigation

### Clearing History

1. Open History view
2. Click **Clear History**
3. Confirm deletion

---

## Favorites

Save frequently used queries for quick access.

### Adding Favorites

1. Run a query
2. Click the **star icon** or **Add to Favorites**
3. Optionally rename the favorite

### Using Favorites

1. Click **Favorites** in the toolbar
2. Click any favorite to run it
3. Or use the favorites section in the main view

### Managing Favorites

- **Rename** - Click the edit icon
- **Reorder** - Drag and drop using the handle (≡)
- **Delete** - Click the trash icon (with 5-second undo)

### Undo Deletion

When you delete a favorite:
1. A toast appears at the bottom
2. Click **Undo** within 5 seconds to restore
3. Or click **X** to dismiss immediately

---

## Scheduled Queries

Run queries automatically at configurable intervals.

### Creating a Scheduled Query

1. Click **Schedules** in the toolbar
2. Click **Add Schedule**
3. Configure:
   - **Name** - Descriptive name
   - **Query** - Natural language or SQL
   - **Interval** - How often to run
   - **Alert** - Optional notification conditions

### Intervals

| Interval | Use Case |
|----------|----------|
| Every 5 minutes | Real-time monitoring |
| Every 15 minutes | Frequent checks |
| Every 30 minutes | Regular monitoring |
| Hourly | Standard monitoring |
| Every 6 hours | Periodic checks |
| Daily | Daily reports |

### Managing Scheduled Queries

- **Enable/Disable** - Toggle the switch
- **Edit** - Click to modify settings
- **View Results** - See historical results and trends
- **Delete** - Remove with 5-second undo

### Viewing Results History

Each scheduled query tracks:
- Timestamp of each run
- Number of results
- Whether alerts triggered
- Trend chart over time

---

## Notifications & Alerts

Get notified when query results meet specific conditions.

### Enabling Notifications

1. Go to **Settings > General**
2. Enable **Notifications**
3. Grant permission when prompted

### Alert Conditions

When creating a scheduled query, you can set alerts:

| Condition | Triggers When |
|-----------|---------------|
| Any results | Query returns 1+ rows |
| No results | Query returns 0 rows |
| More than N | Results exceed threshold |
| Fewer than N | Results below threshold |
| Exactly N | Results equal threshold |
| Contains value | Column contains specific text |

### Example Use Cases

1. **Security Monitoring**
   - Query: "Show new listening ports"
   - Alert: Any results
   - Interval: Every 15 minutes

2. **Resource Monitoring**
   - Query: "Processes using more than 1GB memory"
   - Alert: More than 3 results
   - Interval: Every 5 minutes

3. **Compliance Check**
   - Query: "Is FileVault enabled?"
   - Alert: No results (disabled)
   - Interval: Daily

### Notification Actions

When a notification appears:
- **View Results** - Opens the app with results
- **Dismiss** - Closes the notification

---

## Exporting Results

Export query results in multiple formats.

### Export Formats

| Format | Extension | Best For |
|--------|-----------|----------|
| JSON | .json | Programming, APIs |
| CSV | .csv | Spreadsheets, data analysis |
| Markdown | .md | Documentation, reports |
| Excel | .xlsx | Business reporting |

### Exporting

1. Run a query
2. Click **Export** in the results toolbar
3. Choose format
4. Select save location

### Quick Re-Export

Recent exports are remembered:
1. Click **Export**
2. See **Export Again** section
3. Click a recent location to save there instantly

Up to 5 recent exports are tracked per format.

---

## AI Discovery Tables

Special tables for discovering AI tools and configurations on your system.

### Enabling AI Discovery

1. Go to **Settings > General**
2. Ensure **Enable AI Discovery Tables** is on
3. Status should show "Available"

### Available Tables

#### ai_tools_installed
Discovers installed AI applications.
```
What AI tools are installed on my Mac?
```

#### ai_mcp_servers
Lists MCP server configurations.
```
Show all configured MCP servers
```

#### ai_env_vars
Finds AI-related environment variables.
```
What AI API keys are configured in my environment?
```

#### ai_browser_extensions
Discovers AI browser extensions.
```
What AI extensions are in my browsers?
```

#### ai_code_assistants
Finds code assistant configurations.
```
Which code assistants are configured?
```

#### ai_api_keys
Checks for configured API keys (presence only).
```
Which AI services have API keys configured?
```

#### ai_local_servers
Detects local AI servers.
```
Are any local AI servers running?
```

#### ai_models_downloaded
Discovers downloaded AI models.
```
What AI models have I downloaded?
```

#### ai_containers
Detects AI-related Docker containers.
```
Show AI containers running in Docker
```

#### ai_sdk_dependencies
Finds AI SDK dependencies in projects.
```
What AI SDKs are used in my projects?
```

---

## Settings

Access settings via the gear icon or `Cmd+,`.

### General Tab

- **Launch at Login** - Start app when you log in
- **Enable AI Discovery Tables** - Use custom AI tables
- **Enable MCP Server** - Allow AI assistants to query
- **Notifications** - Enable system notifications

### Provider Tab

- **Provider Selection** - Gemini, Claude, or OpenAI
- **API Key** - Your provider's API key
- **Model Selection** - Choose specific model variant

### Tables Tab

Customize which osquery tables are available:

- **Search** - Find specific tables
- **Enable/Disable** - Toggle individual tables
- **Recommended** - Reset to curated defaults
- **Enable All** - Enable every table (slower queries)

Fewer enabled tables = faster, more accurate AI responses.

---

## Keyboard Shortcuts

### Global

| Shortcut | Action |
|----------|--------|
| `Cmd+,` | Open Settings |
| `Cmd+Q` | Quit app |

### Query Input

| Shortcut | Action |
|----------|--------|
| `Cmd+Return` | Submit query |
| `Cmd+K` | Clear and start new |
| `↑` | Previous history item |
| `↓` | Next history item |
| `Esc` | Cancel query / Exit history |

### Navigation

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | Open Templates |
| `Cmd+H` | Open History |
| `Cmd+B` | Open Schema Browser |
| `Cmd+F` | Open Favorites |

### Results

| Shortcut | Action |
|----------|--------|
| `Cmd+C` | Copy results |
| `Cmd+S` | Export results |
| `Cmd+D` | Add to favorites |

---

## MCP Server Integration

The built-in MCP server allows AI assistants to query your system.

### Enabling the MCP Server

1. Go to **Settings > General**
2. Enable **MCP Server**
3. Copy the configuration for your assistant

### Claude Desktop Setup

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "osquery": {
      "command": "/Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer"
    }
  }
}
```

### Cursor Setup

Add to Cursor's MCP settings:

```json
{
  "mcpServers": {
    "osquery": {
      "command": "/Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer"
    }
  }
}
```

### Available MCP Tools

The MCP server provides:
- **query** - Execute osquery SQL queries
- **tables** - List available tables
- **schema** - Get table schema

---

## Troubleshooting

### "osquery not found"

Install osquery:
```bash
brew install osquery
```

Verify installation:
```bash
which osqueryi
```

### "Cannot answer with available tables"

The AI couldn't find a suitable table. Try:
1. Go to **Settings > Tables**
2. Click **Recommended** to enable common tables
3. Or enable specific tables for your query

### AI Discovery tables not working

1. Go to **Settings > General**
2. Ensure "Enable AI Discovery Tables" is on
3. Check status shows "Available"
4. Go to **Settings > Tables** and click **Recommended**

### Extension conflicts

If you see "Registry item conflicts" errors:

```bash
# Update daemon's extension
sudo cp /Applications/OsqueryNLI.app/Contents/Resources/ai_tables.ext /var/osquery/extensions/

# Restart osqueryd
sudo pkill osqueryd
```

### Queries timing out

Extension queries need time to register. The app automatically uses `--extensions_timeout=10` but complex queries may need more time.

### Notifications not appearing

1. Check **System Settings > Notifications > Osquery NLI**
2. Ensure notifications are allowed
3. Check Do Not Disturb is off

### API key errors

- Verify your API key is correct
- Check your provider account has available credits
- Try regenerating the API key

### High memory usage

- Reduce enabled tables in Settings
- Avoid `SELECT *` on large tables
- Use LIMIT clauses in queries

---

## Getting Help

- **GitHub Issues**: [Report bugs or request features](https://github.com/juergen-kc/OsqueryNLI/issues)
- **README**: [Quick start guide](https://github.com/juergen-kc/OsqueryNLI#readme)
- **osquery Docs**: [Official osquery documentation](https://osquery.readthedocs.io/)
