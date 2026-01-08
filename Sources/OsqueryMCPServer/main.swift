import Foundation
import MCP
import OsqueryNLICore

// MARK: - Ensure stdout is unbuffered for MCP communication
private func setupUnbufferedOutput() {
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

// MARK: - Table Categories for Smart Suggestions

private let tableCategories: [String: [String]] = [
    "system": ["system_info", "os_version", "kernel_info", "uptime", "time", "hostname"],
    "hardware": ["cpu_info", "memory_info", "usb_devices", "pci_devices", "battery", "disk_info", "block_devices"],
    "processes": ["processes", "process_open_files", "process_open_sockets", "process_envs", "process_memory_map"],
    "network": ["interface_details", "interface_addresses", "listening_ports", "routes", "arp_cache", "dns_resolvers", "etc_hosts", "wifi_status", "wifi_networks"],
    "users": ["users", "groups", "logged_in_users", "user_groups", "last"],
    "security": ["sip_config", "gatekeeper", "disk_encryption", "certificates", "keychain_items", "authorization_mechanisms", "alf", "alf_exceptions"],
    "software": ["apps", "homebrew_packages", "python_packages", "npm_packages", "browser_plugins", "safari_extensions", "chrome_extensions"],
    "startup": ["launchd", "startup_items", "crontab", "login_items"],
    "files": ["file", "hash", "extended_attributes", "mdfind", "mdls"],
    "logs": ["asl", "unified_log", "crashes", "system_profiler"],
    "ai_discovery": ["ai_tools_installed", "ai_mcp_servers", "ai_env_vars", "ai_browser_extensions", "ai_code_assistants", "ai_api_keys", "ai_local_servers", "ai_models_downloaded", "ai_containers", "ai_sdk_dependencies"]
]

private let keywordToCategories: [String: [String]] = [
    "cpu": ["hardware", "processes"],
    "memory": ["hardware", "processes"],
    "ram": ["hardware"],
    "disk": ["hardware", "files"],
    "storage": ["hardware", "files"],
    "network": ["network"],
    "wifi": ["network"],
    "internet": ["network"],
    "port": ["network", "processes"],
    "process": ["processes"],
    "running": ["processes"],
    "user": ["users", "security"],
    "login": ["users", "startup", "security"],
    "security": ["security"],
    "firewall": ["security"],
    "encryption": ["security"],
    "password": ["security", "users"],
    "app": ["software"],
    "install": ["software"],
    "package": ["software"],
    "brew": ["software"],
    "startup": ["startup"],
    "boot": ["startup", "system"],
    "launch": ["startup"],
    "file": ["files"],
    "crash": ["logs"],
    "log": ["logs"],
    "error": ["logs"],
    "ai": ["ai_discovery"],
    "llm": ["ai_discovery"],
    "model": ["ai_discovery"],
    "mcp": ["ai_discovery"],
    "openai": ["ai_discovery"],
    "claude": ["ai_discovery"],
    "ollama": ["ai_discovery"],
    "docker": ["ai_discovery"],
    "container": ["ai_discovery"]
]

// MARK: - Prompt Templates

private let promptTemplates: [(name: String, description: String, template: String)] = [
    (
        name: "security_audit",
        description: "Comprehensive security posture assessment",
        template: """
        Perform a security audit of this macOS system. Check:
        1. System Integrity Protection status (sip_config)
        2. Gatekeeper settings (gatekeeper)
        3. FileVault disk encryption (disk_encryption)
        4. Firewall status (alf, alf_exceptions)
        5. Admin users and sudo access (users, user_groups)
        6. SSH authorized keys (authorized_keys)
        7. Startup items that could be persistence mechanisms (launchd, startup_items, crontab)
        8. Kernel extensions loaded (kernel_extensions)

        Highlight any security concerns or misconfigurations.
        """
    ),
    (
        name: "performance_analysis",
        description: "System performance and resource usage analysis",
        template: """
        Analyze system performance:
        1. Current uptime and load (uptime, load_average)
        2. Top processes by CPU usage (processes ordered by cpu_percent)
        3. Top processes by memory usage (processes ordered by resident_size)
        4. Disk usage and mount points (mounts, disk_info)
        5. Memory pressure (memory_info)
        6. Running services count (processes)

        Identify any resource bottlenecks or concerning patterns.
        """
    ),
    (
        name: "software_inventory",
        description: "Complete software and package inventory",
        template: """
        Create a comprehensive software inventory:
        1. Installed applications with versions (apps)
        2. Homebrew packages (homebrew_packages)
        3. Python packages (python_packages)
        4. Browser extensions for all browsers (browser_plugins, safari_extensions, chrome_extensions)
        5. Running applications (running_apps)
        6. Recently installed software (apps sorted by install date)

        Note any outdated versions or potentially unwanted software.
        """
    ),
    (
        name: "network_analysis",
        description: "Network configuration and connections analysis",
        template: """
        Analyze network configuration and activity:
        1. Network interfaces and IP addresses (interface_details, interface_addresses)
        2. Listening ports and services (listening_ports with process info)
        3. Active network connections (process_open_sockets)
        4. DNS configuration (dns_resolvers, etc_hosts)
        5. Routing table (routes)
        6. WiFi status and saved networks (wifi_status, wifi_networks)
        7. ARP cache for local network devices (arp_cache)

        Identify any unexpected listeners or connections.
        """
    ),
    (
        name: "ai_discovery",
        description: "Discover AI tools, models, and configurations",
        template: """
        Discover all AI-related software and configurations:
        1. Installed AI tools and IDEs (ai_tools_installed)
        2. Running local AI servers like Ollama (ai_local_servers)
        3. Downloaded AI models (ai_models_downloaded)
        4. MCP server configurations (ai_mcp_servers)
        5. AI browser extensions (ai_browser_extensions)
        6. Code assistants like Copilot (ai_code_assistants)
        7. AI API keys configured (ai_api_keys)
        8. AI-related environment variables (ai_env_vars)
        9. AI containers running (ai_containers)
        10. AI SDKs in projects (ai_sdk_dependencies)

        Provide a complete picture of the AI ecosystem on this machine.
        """
    ),
    (
        name: "troubleshooting",
        description: "General system troubleshooting",
        template: """
        Gather diagnostic information for troubleshooting:
        1. System info and OS version (system_info, os_version)
        2. Recent crashes (crashes)
        3. System uptime (uptime)
        4. Disk space availability (mounts)
        5. Memory usage (memory_info)
        6. Failed services or launch agents (launchd with status)
        7. Recent system logs if available (unified_log)

        Identify any obvious issues or errors.
        """
    )
]

// MARK: - Helper Functions

private func suggestTablesFor(query: String) -> [String] {
    let lowercased = query.lowercased()
    var suggestedCategories = Set<String>()

    // Find matching keywords
    for (keyword, categories) in keywordToCategories {
        if lowercased.contains(keyword) {
            suggestedCategories.formUnion(categories)
        }
    }

    // Default to system if no matches
    if suggestedCategories.isEmpty {
        suggestedCategories.insert("system")
    }

    // Collect tables from matched categories
    var tables = Set<String>()
    for category in suggestedCategories {
        if let categoryTables = tableCategories[category] {
            tables.formUnion(categoryTables)
        }
    }

    return Array(tables).sorted()
}

private func getRelatedTables(for tableName: String) -> [String] {
    var related = Set<String>()

    // Find which categories this table belongs to
    for (_, tables) in tableCategories {
        if tables.contains(tableName) {
            // Add other tables from same category
            related.formUnion(tables)
        }
    }

    related.remove(tableName)
    return Array(related).sorted().prefix(5).map { $0 }
}

// MARK: - MCP Server Entry Point

@main
struct OsqueryMCPServer {
    static func main() async throws {
        setupUnbufferedOutput()

        let server = Server(
            name: "osquery",
            version: "1.1.0"
        )

        // MARK: - Register Tools

        await server.withMethodHandler(ListTools.self) { _ in
            return ListTools.Result(tools: [
                Tool(
                    name: "osquery_execute",
                    description: "Execute an osquery SQL query. Returns results with schema context and related table suggestions.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "sql": [
                                "type": "string",
                                "description": "The osquery SQL query to execute"
                            ],
                            "include_schema": [
                                "type": "boolean",
                                "description": "Include column type information in response (default: true)"
                            ]
                        ],
                        "required": ["sql"]
                    ]
                ),
                Tool(
                    name: "osquery_tables",
                    description: "List all available osquery tables, optionally filtered by name or category",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "filter": [
                                "type": "string",
                                "description": "Filter string to match table names"
                            ],
                            "category": [
                                "type": "string",
                                "description": "Filter by category: system, hardware, processes, network, users, security, software, startup, files, logs, ai_discovery"
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
                ),
                Tool(
                    name: "osquery_suggest",
                    description: "Given a natural language question or topic, suggest relevant osquery tables to query",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "question": [
                                "type": "string",
                                "description": "Natural language question or topic (e.g., 'network connections', 'installed software', 'AI tools')"
                            ]
                        ],
                        "required": ["question"]
                    ]
                ),
                Tool(
                    name: "osquery_explain",
                    description: "Explain a query plan without executing it - useful for understanding complex queries",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "sql": [
                                "type": "string",
                                "description": "The osquery SQL query to explain"
                            ]
                        ],
                        "required": ["sql"]
                    ]
                )
            ])
        }

        // MARK: - Register Resources

        await server.withMethodHandler(ListResources.self) { _ in
            return ListResources.Result(resources: [
                Resource(
                    name: "System Information",
                    uri: "osquery://system/info",
                    description: "Basic system information including OS version, hardware specs, and uptime",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "AI Inventory",
                    uri: "osquery://ai/inventory",
                    description: "Summary of AI tools, models, and configurations on this system",
                    mimeType: "application/json"
                ),
                Resource(
                    name: "Table Catalog",
                    uri: "osquery://tables/catalog",
                    description: "Categorized list of all available osquery tables with descriptions",
                    mimeType: "application/json"
                )
            ])
        }

        await server.withMethodHandler(ReadResource.self) { params in
            let osquery = OsqueryService()

            switch params.uri {
            case "osquery://system/info":
                do {
                    let systemInfo = try await osquery.execute("SELECT * FROM system_info")
                    let osVersion = try await osquery.execute("SELECT * FROM os_version")
                    let uptime = try await osquery.execute("SELECT * FROM uptime")
                    let cpuInfo = try await osquery.execute("SELECT * FROM cpu_info LIMIT 1")

                    let combined: [String: Any] = [
                        "system": systemInfo.first ?? [:],
                        "os": osVersion.first ?? [:],
                        "uptime": uptime.first ?? [:],
                        "cpu": cpuInfo.first ?? [:]
                    ]

                    let jsonData = try JSONSerialization.data(withJSONObject: combined, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

                    return ReadResource.Result(contents: [
                        .text(jsonString, uri: params.uri, mimeType: "application/json")
                    ])
                } catch {
                    return ReadResource.Result(contents: [
                        .text("Error: \(error.localizedDescription)", uri: params.uri, mimeType: "text/plain")
                    ])
                }

            case "osquery://ai/inventory":
                do {
                    var inventory: [String: Any] = [:]

                    // Try each AI table, handling missing tables gracefully
                    let aiQueries: [(key: String, query: String)] = [
                        ("tools_installed", "SELECT name, category, running FROM ai_tools_installed"),
                        ("local_servers", "SELECT name, status, port FROM ai_local_servers"),
                        ("models_downloaded", "SELECT name, provider, size_human FROM ai_models_downloaded"),
                        ("mcp_servers", "SELECT name, server_type, source_app FROM ai_mcp_servers"),
                        ("code_assistants", "SELECT name, editor, status FROM ai_code_assistants"),
                        ("api_keys", "SELECT service, source, key_present FROM ai_api_keys"),
                        ("containers", "SELECT container_name, image, status, category FROM ai_containers")
                    ]

                    for (key, query) in aiQueries {
                        if let results = try? await osquery.execute(query), !results.isEmpty {
                            inventory[key] = results
                        }
                    }

                    if inventory.isEmpty {
                        inventory["status"] = "No AI tools or configurations detected"
                    }

                    let jsonData = try JSONSerialization.data(withJSONObject: inventory, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

                    return ReadResource.Result(contents: [
                        .text(jsonString, uri: params.uri, mimeType: "application/json")
                    ])
                } catch {
                    return ReadResource.Result(contents: [
                        .text("Error: \(error.localizedDescription)", uri: params.uri, mimeType: "text/plain")
                    ])
                }

            case "osquery://tables/catalog":
                var catalog: [[String: Any]] = []
                for (category, tables) in tableCategories.sorted(by: { $0.key < $1.key }) {
                    catalog.append([
                        "category": category,
                        "tables": tables
                    ])
                }

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                    return ReadResource.Result(contents: [
                        .text(jsonString, uri: params.uri, mimeType: "application/json")
                    ])
                } catch {
                    return ReadResource.Result(contents: [
                        .text("[]", uri: params.uri, mimeType: "application/json")
                    ])
                }

            default:
                return ReadResource.Result(contents: [
                    .text("Unknown resource: \(params.uri)", uri: params.uri, mimeType: "text/plain")
                ])
            }
        }

        // MARK: - Register Prompts

        await server.withMethodHandler(ListPrompts.self) { _ in
            return ListPrompts.Result(prompts: promptTemplates.map { template in
                Prompt(
                    name: template.name,
                    description: template.description,
                    arguments: []
                )
            })
        }

        await server.withMethodHandler(GetPrompt.self) { params in
            guard let template = promptTemplates.first(where: { $0.name == params.name }) else {
                return GetPrompt.Result(
                    description: "Unknown prompt",
                    messages: [.user(.text(text: "Unknown prompt: \(params.name)"))]
                )
            }

            return GetPrompt.Result(
                description: template.description,
                messages: [.user(.text(text: template.template))]
            )
        }

        // MARK: - Handle Tool Calls

        await server.withMethodHandler(CallTool.self) { params in
            debugLog("CallTool received: \(params.name)")
            let osquery = OsqueryService()
            debugLog("OsqueryService created, AI Discovery enabled: \(osquery.aiDiscoveryEnabled)")
            debugLog("Bundled extension path: \(osquery.bundledExtensionPath ?? "nil")")

            switch params.name {
            case "osquery_execute":
                guard let sql = params.arguments?["sql"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'sql' parameter")], isError: true)
                }

                let includeSchema = params.arguments?["include_schema"]?.boolValue ?? true

                debugLog("Executing query: \(sql)")
                let startTime = Date()

                do {
                    let results = try await osquery.execute(sql)
                    let elapsed = Date().timeIntervalSince(startTime)
                    debugLog("Query completed in \(String(format: "%.2f", elapsed))s, \(results.count) rows")

                    var response = "Query returned \(results.count) row(s)"
                    response += " in \(String(format: "%.2f", elapsed))s\n"

                    // Extract table name for context using simple string parsing
                    let tableName: String? = {
                        let uppercased = sql.uppercased()
                        guard let fromRange = uppercased.range(of: "FROM ") ?? uppercased.range(of: "FROM\t") else {
                            return nil
                        }
                        let afterFrom = sql[fromRange.upperBound...]
                        let trimmed = afterFrom.trimmingCharacters(in: .whitespaces)
                        // Extract table name (alphanumeric and underscore)
                        var name = ""
                        for char in trimmed {
                            if char.isLetter || char.isNumber || char == "_" {
                                name.append(char)
                            } else {
                                break
                            }
                        }
                        return name.isEmpty ? nil : name
                    }()

                    if let tableName = tableName {

                        // Add schema context if requested
                        if includeSchema {
                            if let schema = try? await osquery.getSchema(for: [tableName]), !schema.isEmpty {
                                response += "\nTable schema:\n\(schema)\n"
                            }
                        }

                        // Suggest related tables
                        let related = getRelatedTables(for: tableName)
                        if !related.isEmpty {
                            response += "\nRelated tables: \(related.joined(separator: ", "))\n"
                        }
                    }

                    let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                    response += "\nResults:\n\(jsonString)"

                    // Log to shared history
                    QueryHistoryLogger.shared.logQuery(
                        query: sql,
                        source: .mcp,
                        rowCount: results.count
                    )

                    return CallTool.Result(content: [.text(response)])
                } catch {
                    let elapsed = Date().timeIntervalSince(startTime)
                    debugLog("Query failed after \(String(format: "%.2f", elapsed))s: \(error.localizedDescription)")
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_tables":
                let filter = params.arguments?["filter"]?.stringValue
                let category = params.arguments?["category"]?.stringValue

                do {
                    var tables = try await osquery.getAllTables()

                    // Filter by category first
                    if let category = category, let categoryTables = tableCategories[category.lowercased()] {
                        tables = tables.filter { categoryTables.contains($0) }
                    }

                    // Then filter by name
                    if let filter = filter, !filter.isEmpty {
                        tables = tables.filter { $0.localizedCaseInsensitiveContains(filter) }
                    }

                    var response = "Found \(tables.count) table(s)"
                    if let category = category {
                        response += " in category '\(category)'"
                    }
                    response += ":\n\n\(tables.joined(separator: "\n"))"

                    // Add category legend if no category filter
                    if category == nil {
                        response += "\n\nCategories available: \(tableCategories.keys.sorted().joined(separator: ", "))"
                    }

                    return CallTool.Result(content: [.text(response)])
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

            case "osquery_suggest":
                guard let question = params.arguments?["question"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'question' parameter")], isError: true)
                }

                let suggestedTables = suggestTablesFor(query: question)

                var response = "For '\(question)', I suggest these tables:\n\n"
                for table in suggestedTables {
                    response += "• \(table)\n"
                }

                response += "\nUse osquery_schema to see column definitions, or osquery_execute to query them."

                return CallTool.Result(content: [.text(response)])

            case "osquery_explain":
                guard let sql = params.arguments?["sql"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'sql' parameter")], isError: true)
                }

                do {
                    let results = try await osquery.execute("EXPLAIN QUERY PLAN \(sql)")
                    let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

                    return CallTool.Result(content: [.text("Query plan:\n\n\(jsonString)")])
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

        // Wait for the server to complete
        await server.waitUntilCompleted()
    }
}
