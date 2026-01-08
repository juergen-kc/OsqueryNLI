import Foundation
import MCP
import OsqueryNLICore

// MARK: - Ensure stdout is unbuffered for MCP communication
private func setupUnbufferedOutput() {
    // Disable buffering on stdout for immediate message delivery
    setbuf(stdout, nil)
}

// MARK: - Debug Logging (to stderr, won't interfere with MCP)
private let debugMode = ProcessInfo.processInfo.environment["OSQUERY_MCP_DEBUG"] != nil

private func debugLog(_ message: String) {
    guard debugMode else { return }
    let timestamp = ISO8601DateFormatter().string(from: Date())
    fputs("[\(timestamp)] \(message)\n", stderr)
    fflush(stderr)
}

// MARK: - MCP Server Entry Point

@main
struct OsqueryMCPServer {
    static func main() async throws {
        // Ensure output is unbuffered for reliable MCP communication
        setupUnbufferedOutput()

        let server = Server(
            name: "osquery",
            version: "1.0.0"
        )

        // Register tools
        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                Tool(
                    name: "osquery_execute",
                    description: "Execute an osquery SQL query and return results as JSON",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "sql": [
                                "type": "string",
                                "description": "The osquery SQL query to execute"
                            ]
                        ],
                        "required": ["sql"]
                    ]
                ),
                Tool(
                    name: "osquery_tables",
                    description: "List all available osquery tables, optionally filtered by name",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "filter": [
                                "type": "string",
                                "description": "Optional filter string to match table names"
                            ]
                        ]
                    ]
                ),
                Tool(
                    name: "osquery_schema",
                    description: "Get the schema (column definitions) for specific osquery tables",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "tables": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "List of table names to get schema for"
                            ]
                        ],
                        "required": ["tables"]
                    ]
                )
            ])
        }

        // Handle tool calls
        await server.withMethodHandler(CallTool.self) { params in
            let osquery = OsqueryService()

            switch params.name {
            case "osquery_execute":
                guard let sql = params.arguments?["sql"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'sql' parameter")], isError: true)
                }

                debugLog("Executing query: \(sql)")
                let startTime = Date()

                do {
                    let results = try await osquery.execute(sql)
                    let elapsed = Date().timeIntervalSince(startTime)
                    debugLog("Query completed in \(String(format: "%.2f", elapsed))s, \(results.count) rows")

                    let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                    // Log to shared history
                    QueryHistoryLogger.shared.logQuery(
                        query: sql,
                        source: .mcp,
                        rowCount: results.count
                    )

                    return CallTool.Result(content: [
                        .text("Query returned \(results.count) row(s):\n\n\(jsonString)")
                    ])
                } catch {
                    let elapsed = Date().timeIntervalSince(startTime)
                    debugLog("Query failed after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_tables":
                let filter = params.arguments?["filter"]?.stringValue

                do {
                    var tables = try await osquery.getAllTables()

                    if let filter = filter, !filter.isEmpty {
                        tables = tables.filter { $0.localizedCaseInsensitiveContains(filter) }
                    }

                    return CallTool.Result(content: [
                        .text("Found \(tables.count) table(s):\n\n\(tables.joined(separator: "\n"))")
                    ])
                } catch {
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_schema":
                guard let tablesValue = params.arguments?["tables"],
                      case .array(let tablesArray) = tablesValue else {
                    return CallTool.Result(content: [.text("Error: Missing or invalid 'tables' parameter")], isError: true)
                }

                let tables = tablesArray.compactMap { $0.stringValue }

                guard !tables.isEmpty else {
                    return CallTool.Result(content: [.text("Error: No valid table names provided")], isError: true)
                }

                do {
                    let schema = try await osquery.getSchema(for: tables)
                    return CallTool.Result(content: [.text(schema.isEmpty ? "No schema found for specified tables" : schema)])
                } catch {
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            default:
                return CallTool.Result(content: [.text("Unknown tool: \(params.name)")], isError: true)
            }
        }

        // Start the server with stdio transport
        let transport = StdioTransport()
        try await server.start(transport: transport)

        // Wait for the server to complete (keeps running until stdin closes)
        await server.waitUntilCompleted()
    }
}
