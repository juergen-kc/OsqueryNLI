# MCP Server API Documentation

Osquery NLI includes a Model Context Protocol (MCP) server that allows AI assistants like Claude Desktop and Cursor to query your system using osquery.

## Overview

The MCP server provides a standardized interface for AI assistants to:
- Execute osquery SQL queries
- Discover available tables
- Get table schemas

## Installation

The MCP server is bundled with Osquery NLI at:
```
/Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer
```

## Configuration

### Claude Desktop

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

### Cursor

Add to Cursor's MCP configuration:

```json
{
  "mcpServers": {
    "osquery": {
      "command": "/Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer"
    }
  }
}
```

### Other MCP Clients

Any MCP-compatible client can use the server by running:
```bash
/Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer
```

The server communicates via stdin/stdout using JSON-RPC 2.0.

## Available Tools

### query

Execute an osquery SQL query and return results.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `sql` | string | Yes | The SQL query to execute |

**Example Request:**

```json
{
  "method": "tools/call",
  "params": {
    "name": "query",
    "arguments": {
      "sql": "SELECT name, pid FROM processes LIMIT 5"
    }
  }
}
```

**Example Response:**

```json
{
  "content": [
    {
      "type": "text",
      "text": "[{\"name\":\"kernel_task\",\"pid\":\"0\"},{\"name\":\"launchd\",\"pid\":\"1\"}...]"
    }
  ]
}
```

**Notes:**
- Results are returned as JSON array
- Large result sets may be truncated
- Only SELECT, PRAGMA, and EXPLAIN queries are allowed

---

### tables

List all available osquery tables.

**Parameters:** None

**Example Request:**

```json
{
  "method": "tools/call",
  "params": {
    "name": "tables",
    "arguments": {}
  }
}
```

**Example Response:**

```json
{
  "content": [
    {
      "type": "text",
      "text": "processes\nusers\ngroups\nlistening_ports\n..."
    }
  ]
}
```

**Notes:**
- Returns newline-separated list of table names
- Includes both standard osquery tables and AI Discovery tables
- AI Discovery tables are prefixed with `ai_`

---

### schema

Get the schema (columns) for a specific table.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `table` | string | Yes | The table name |

**Example Request:**

```json
{
  "method": "tools/call",
  "params": {
    "name": "schema",
    "arguments": {
      "table": "processes"
    }
  }
}
```

**Example Response:**

```json
{
  "content": [
    {
      "type": "text",
      "text": "pid (BIGINT)\nname (TEXT)\npath (TEXT)\ncmdline (TEXT)\nstate (TEXT)\ncwd (TEXT)\nroot (TEXT)\nuid (BIGINT)\ngid (BIGINT)\neuid (BIGINT)\negid (BIGINT)\nsuid (BIGINT)\nsgid (BIGINT)\non_disk (INTEGER)\nwired_size (BIGINT)\nresident_size (BIGINT)\ntotal_size (BIGINT)\nuser_time (BIGINT)\nsystem_time (BIGINT)\ndisk_bytes_read (BIGINT)\ndisk_bytes_written (BIGINT)\nstart_time (BIGINT)\nparent (BIGINT)\npgroup (BIGINT)\nthreads (INTEGER)\nnice (INTEGER)\nis_elevated_token (INTEGER)\nelapsed_time (BIGINT)\nhandle_count (BIGINT)\npercent_processor_time (BIGINT)\nupid (BIGINT)\nuppid (BIGINT)\ncpu_type (INTEGER)\ncpu_subtype (INTEGER)"
    }
  ]
}
```

**Notes:**
- Returns column names with their types
- Format: `column_name (TYPE)`
- One column per line

---

## AI Discovery Tables

The MCP server includes access to 10 AI Discovery tables:

| Table | Description |
|-------|-------------|
| `ai_tools_installed` | Installed AI applications |
| `ai_mcp_servers` | MCP server configurations |
| `ai_env_vars` | AI-related environment variables |
| `ai_browser_extensions` | AI browser extensions |
| `ai_code_assistants` | Code assistant configurations |
| `ai_api_keys` | Configured API keys (presence only) |
| `ai_local_servers` | Local AI servers (Ollama, etc.) |
| `ai_models_downloaded` | Downloaded AI models |
| `ai_containers` | AI-related Docker containers |
| `ai_sdk_dependencies` | AI SDK dependencies in projects |

### Example Queries for AI Discovery

```sql
-- Find installed AI tools
SELECT name, path, running FROM ai_tools_installed;

-- List MCP server configurations
SELECT name, command, source_app FROM ai_mcp_servers;

-- Check for configured API keys
SELECT service, source, key_present FROM ai_api_keys;

-- Find running local AI servers
SELECT name, port, status, model_loaded FROM ai_local_servers;

-- Discover downloaded models
SELECT name, source, size, format FROM ai_models_downloaded;
```

---

## Error Handling

### Query Errors

Invalid SQL or execution errors return:

```json
{
  "content": [
    {
      "type": "text",
      "text": "Error: near \"INVALID\": syntax error"
    }
  ],
  "isError": true
}
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `osquery not found` | osqueryi not installed | Install via `brew install osquery` |
| `table not found` | Invalid table name | Use `tables` tool to list valid tables |
| `syntax error` | Invalid SQL | Check SQL syntax |
| `timeout` | Query took too long | Add LIMIT clause or simplify query |

---

## Security Considerations

### Query Validation

The MCP server validates all queries:
- Only SELECT, PRAGMA, and EXPLAIN are allowed
- INSERT, UPDATE, DELETE, DROP are rejected
- Shell injection attempts are blocked
- Maximum query length enforced

### Data Access

The server can access:
- System information (processes, users, network)
- File metadata (not contents)
- Application configurations
- AI tool presence (not credentials)

The server cannot:
- Modify system state
- Read file contents
- Access actual API key values
- Execute arbitrary commands

---

## Protocol Details

### Transport

- **Protocol**: JSON-RPC 2.0
- **Transport**: stdio (stdin/stdout)
- **Encoding**: UTF-8

### MCP Version

The server implements MCP protocol version `2024-11-05`.

### Initialization

The server responds to the standard MCP `initialize` handshake:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {
      "name": "claude-desktop",
      "version": "1.0.0"
    }
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {}
    },
    "serverInfo": {
      "name": "osquery-mcp",
      "version": "1.0.0"
    }
  }
}
```

### Tool Listing

Request available tools:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "tools": [
      {
        "name": "query",
        "description": "Execute an osquery SQL query",
        "inputSchema": {
          "type": "object",
          "properties": {
            "sql": {
              "type": "string",
              "description": "The SQL query to execute"
            }
          },
          "required": ["sql"]
        }
      },
      {
        "name": "tables",
        "description": "List available osquery tables",
        "inputSchema": {
          "type": "object",
          "properties": {}
        }
      },
      {
        "name": "schema",
        "description": "Get schema for a table",
        "inputSchema": {
          "type": "object",
          "properties": {
            "table": {
              "type": "string",
              "description": "The table name"
            }
          },
          "required": ["table"]
        }
      }
    ]
  }
}
```

---

## Debugging

### Enable Debug Logging

Set the environment variable:

```bash
OSQUERY_MCP_DEBUG=1 /Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer
```

This outputs debug information to stderr.

### Testing Manually

Test the server from command line:

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | /Applications/OsqueryNLI.app/Contents/Resources/OsqueryMCPServer
```

### Common Issues

1. **Server doesn't start**
   - Check osquery is installed: `which osqueryi`
   - Verify executable permissions

2. **AI Discovery tables missing**
   - Enable in Osquery NLI settings first
   - Tables require the extension to be loaded

3. **Queries timeout**
   - Some tables are slow (file scanning)
   - Add LIMIT to queries
   - Avoid `SELECT *` on large tables

---

## Examples

### System Information

```sql
-- Get OS version
SELECT * FROM os_version;

-- Check uptime
SELECT days, hours, minutes FROM uptime;

-- List logged-in users
SELECT user, host, time FROM logged_in_users;
```

### Security Monitoring

```sql
-- Find listening ports
SELECT pid, port, protocol, address FROM listening_ports;

-- Check startup items
SELECT name, path, type FROM startup_items;

-- FileVault status
SELECT * FROM disk_encryption;
```

### Process Analysis

```sql
-- Top memory consumers
SELECT name, pid, resident_size
FROM processes
ORDER BY resident_size DESC
LIMIT 10;

-- Find processes by name
SELECT name, pid, path, cmdline
FROM processes
WHERE name LIKE '%chrome%';
```

### AI Environment

```sql
-- All AI tools
SELECT name, category, running FROM ai_tools_installed;

-- MCP servers for Claude
SELECT name, command
FROM ai_mcp_servers
WHERE source_app = 'claude';

-- Local models available
SELECT name, source, size
FROM ai_models_downloaded;
```
