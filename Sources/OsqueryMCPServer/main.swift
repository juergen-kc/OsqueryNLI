import Foundation
import MCP
import OsqueryNLICore
import GoogleGenerativeAI

// MARK: - Helpers (wrapped to avoid top-level code conflict with @main)
enum MCPHelpers {
    // Ensure stdout is unbuffered for MCP communication
    static func setupUnbufferedOutput() {
        setbuf(stdout, nil)
    }

    // Debug Logging (to stderr, won't interfere with MCP)
    static let debugMode = ProcessInfo.processInfo.environment["OSQUERY_MCP_DEBUG"] != nil

    static func debugLog(_ message: String) {
        guard debugMode else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        fputs("[\(timestamp)] \(message)\n", stderr)
        fflush(stderr)
    }
}

// Convenience aliases
private func setupUnbufferedOutput() { MCPHelpers.setupUnbufferedOutput() }
private var debugMode: Bool { MCPHelpers.debugMode }
private func debugLog(_ message: String) { MCPHelpers.debugLog(message) }

// MARK: - LLM Translation Service

/// Result of natural language query translation and execution
struct NLQueryResult: Sendable {
    let sql: String
    let results: [[String: String]]
    let summary: String?
}

/// Handles natural language to SQL translation using Gemini
private final class LLMTranslator: @unchecked Sendable {
    private let model: GenerativeModel?
    private let osquery: OsqueryService
    private let isConfigured: Bool

    init() {
        self.osquery = OsqueryService()

        // Try to get API key from environment or keychain
        let apiKey = Self.getAPIKey()

        if let apiKey = apiKey, !apiKey.isEmpty {
            self.model = GenerativeModel(
                name: "gemini-2.0-flash-lite",
                apiKey: apiKey,
                generationConfig: GenerationConfig(
                    temperature: 0.1,
                    maxOutputTokens: 1024
                )
            )
            self.isConfigured = true
            debugLog("LLM Translator initialized with Gemini")
        } else {
            self.model = nil
            self.isConfigured = false
            debugLog("LLM Translator not available - no API key found")
        }
    }

    var isAvailable: Bool {
        isConfigured
    }

    private static func getAPIKey() -> String? {
        // 1. Check environment variable
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            debugLog("Using GEMINI_API_KEY from environment")
            return envKey
        }

        // 2. Try to read from macOS Keychain (same format as main app)
        if let keychainKey = readFromKeychain(service: "com.klaassen.OsqueryNLI", account: "gemini") {
            debugLog("Using API key from Keychain")
            return keychainKey
        }

        debugLog("No API key found in environment or keychain")
        return nil
    }

    private static func readFromKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    func translateAndExecute(question: String, summarize: Bool) async throws -> NLQueryResult {
        guard let model = model else {
            throw NSError(domain: "LLMTranslator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "LLM not available. Set GEMINI_API_KEY environment variable or configure API key in OsqueryNLI app."
            ])
        }

        // Get schema context for available tables
        let tables = try await osquery.getAllTables()
        let schemaContext = try await osquery.getSchema(for: Array(tables.prefix(50)))

        // Translate to SQL
        let translationPrompt = """
        You are an expert in osquery SQL.
        Translate the following natural language query into valid osquery SQL.

        Rules:
        1. Return ONLY the SQL query. No markdown, no explanations, no code fences.
        2. Only use tables and columns from the schema below.
        3. Use LIMIT for potentially large result sets.
        4. If you cannot answer with available tables, return: ERROR: Cannot answer with available tables.

        Schema:
        \(schemaContext)

        Question: \(question)
        """

        debugLog("Translating: \(question)")
        let translationResponse = try await model.generateContent(translationPrompt)

        guard let sqlText = translationResponse.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw NSError(domain: "LLMTranslator", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate SQL translation"
            ])
        }

        // Check for error response
        if sqlText.hasPrefix("ERROR:") {
            throw NSError(domain: "LLMTranslator", code: 3, userInfo: [
                NSLocalizedDescriptionKey: sqlText
            ])
        }

        debugLog("Generated SQL: \(sqlText)")

        // Execute the query
        let rawResults = try await osquery.execute(sqlText)
        debugLog("Query returned \(rawResults.count) rows")

        // Convert to Sendable format (stringify all values)
        let results: [[String: String]] = rawResults.map { row in
            row.mapValues { value in
                if let str = value as? String {
                    return str
                } else {
                    return String(describing: value)
                }
            }
        }

        // Optionally summarize results
        var summary: String? = nil
        if summarize && !results.isEmpty {
            let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.sortedKeys])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"

            let summaryPrompt = """
            The user asked: "\(question)"

            SQL executed: \(sqlText)

            Results (JSON):
            \(jsonString.prefix(4000))

            Provide a concise, natural language answer (2-3 sentences) to the user's question based on these results.
            """

            if let summaryResponse = try? await model.generateContent(summaryPrompt),
               let summaryText = summaryResponse.text {
                summary = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return NLQueryResult(sql: sqlText, results: results, summary: summary)
    }
}

private let sharedTranslator = LLMTranslator()

// MARK: - Example Queries for Tables

private let tableExamples: [String: [(description: String, sql: String)]] = [
    "processes": [
        ("Top 10 processes by CPU", "SELECT name, pid, cpu_percent FROM processes ORDER BY cpu_percent DESC LIMIT 10"),
        ("Top 10 processes by memory", "SELECT name, pid, resident_size/1024/1024 AS memory_mb FROM processes ORDER BY resident_size DESC LIMIT 10"),
        ("Find process by name", "SELECT * FROM processes WHERE name LIKE '%Safari%'"),
        ("Processes with open network connections", "SELECT DISTINCT p.name, p.pid FROM processes p JOIN process_open_sockets s ON p.pid = s.pid")
    ],
    "listening_ports": [
        ("All listening ports", "SELECT port, protocol, address, pid FROM listening_ports"),
        ("Listening ports with process info", "SELECT l.port, l.protocol, p.name, p.pid FROM listening_ports l JOIN processes p ON l.pid = p.pid"),
        ("Find specific port", "SELECT * FROM listening_ports WHERE port = 8080")
    ],
    "users": [
        ("All users", "SELECT username, uid, gid, directory, shell FROM users"),
        ("Admin users", "SELECT u.username FROM users u JOIN user_groups ug ON u.uid = ug.uid WHERE ug.gid = 80"),
        ("Users with login shells", "SELECT username, shell FROM users WHERE shell NOT LIKE '%nologin%' AND shell NOT LIKE '%false%'")
    ],
    "apps": [
        ("All installed apps", "SELECT name, bundle_version, last_opened_time FROM apps ORDER BY name"),
        ("Recently installed apps", "SELECT name, bundle_version FROM apps ORDER BY last_opened_time DESC LIMIT 20"),
        ("Find app by name", "SELECT * FROM apps WHERE name LIKE '%Chrome%'")
    ],
    "homebrew_packages": [
        ("All Homebrew packages", "SELECT name, version FROM homebrew_packages ORDER BY name"),
        ("Find package", "SELECT * FROM homebrew_packages WHERE name LIKE '%node%'")
    ],
    "system_info": [
        ("Basic system info", "SELECT hostname, computer_name, cpu_brand, physical_memory/1024/1024/1024 AS ram_gb FROM system_info"),
        ("Hardware overview", "SELECT * FROM system_info")
    ],
    "os_version": [
        ("macOS version", "SELECT name, version, build, platform FROM os_version")
    ],
    "uptime": [
        ("System uptime", "SELECT days, hours, minutes FROM uptime")
    ],
    "interface_addresses": [
        ("Network interfaces", "SELECT interface, address, type FROM interface_addresses WHERE address != ''"),
        ("IPv4 addresses only", "SELECT interface, address FROM interface_addresses WHERE type = 'ipv4' AND address NOT LIKE '127%'")
    ],
    "disk_encryption": [
        ("FileVault status", "SELECT name, encrypted, type FROM disk_encryption")
    ],
    "sip_config": [
        ("SIP status", "SELECT config_flag, enabled FROM sip_config")
    ],
    "launchd": [
        ("All launch agents/daemons", "SELECT name, path, program, run_at_load FROM launchd"),
        ("Enabled startup items", "SELECT name, path FROM launchd WHERE run_at_load = 1")
    ],
    "ai_tools_installed": [
        ("All AI tools", "SELECT name, category, path, running FROM ai_tools_installed"),
        ("Running AI tools", "SELECT name, category FROM ai_tools_installed WHERE running = 1")
    ],
    "ai_mcp_servers": [
        ("MCP server configs", "SELECT name, server_type, source_app FROM ai_mcp_servers")
    ],
    "ai_local_servers": [
        ("Local AI servers", "SELECT name, status, port, model_loaded FROM ai_local_servers")
    ],
    "ai_models_downloaded": [
        ("Downloaded models", "SELECT name, provider, size_human FROM ai_models_downloaded")
    ]
]

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
            version: "1.4.0"
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
                ),
                Tool(
                    name: "osquery_ask",
                    description: "Ask a question about the system in natural language. Automatically translates to SQL, executes, and optionally summarizes results. Requires GEMINI_API_KEY environment variable or API key configured in OsqueryNLI app.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "question": [
                                "type": "string",
                                "description": "Natural language question about the system (e.g., 'What is the system uptime?', 'Show running processes using most memory')"
                            ],
                            "summarize": [
                                "type": "boolean",
                                "description": "Whether to include a natural language summary of the results (default: true)"
                            ]
                        ],
                        "required": ["question"]
                    ]
                ),
                Tool(
                    name: "osquery_history",
                    description: "Get recent query history from OsqueryNLI. Shows queries executed from both the app and MCP server.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "limit": [
                                "type": "integer",
                                "description": "Maximum number of entries to return (default: 20, max: 100)"
                            ],
                            "source": [
                                "type": "string",
                                "enum": ["app", "mcp", "all"],
                                "description": "Filter by query source: 'app' (GUI), 'mcp' (this server), or 'all' (default)"
                            ]
                        ]
                    ]
                ),
                Tool(
                    name: "osquery_examples",
                    description: "Get example queries for specific osquery tables. Useful for learning how to query a table effectively.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "table": [
                                "type": "string",
                                "description": "Table name to get examples for (e.g., 'processes', 'users', 'apps')"
                            ]
                        ],
                        "required": ["table"]
                    ]
                ),
                Tool(
                    name: "osquery_favorites",
                    description: "List all saved favorite queries from OsqueryNLI. Favorites can be SQL or natural language queries.",
                    inputSchema: [
                        "type": "object",
                        "properties": [:]
                    ]
                ),
                Tool(
                    name: "osquery_run_favorite",
                    description: "Run a saved favorite query by name. Searches favorites by name (case-insensitive partial match).",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "Name of the favorite to run (partial match supported)"
                            ]
                        ],
                        "required": ["name"]
                    ]
                ),
                Tool(
                    name: "osquery_system_info",
                    description: "Get comprehensive system information including OS version, uptime, hostname, CPU, and memory.",
                    inputSchema: [
                        "type": "object",
                        "properties": [:]
                    ]
                ),
                Tool(
                    name: "osquery_check_process",
                    description: "Check if a specific process or application is running. Returns boolean result with process details if found.",
                    inputSchema: [
                        "type": "object",
                        "properties": [
                            "name": [
                                "type": "string",
                                "description": "Process or application name to check (e.g., 'Safari', 'Chrome', 'python')"
                            ]
                        ],
                        "required": ["name"]
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

            case "osquery_ask":
                guard let question = params.arguments?["question"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'question' parameter")], isError: true)
                }

                let summarize = params.arguments?["summarize"]?.boolValue ?? true

                // Check if LLM is available
                guard sharedTranslator.isAvailable else {
                    return CallTool.Result(content: [.text("""
                        Error: Natural language queries require an API key.

                        Options:
                        1. Set GEMINI_API_KEY environment variable in your MCP client config
                        2. Configure a Gemini API key in the OsqueryNLI app (Settings → Provider)

                        Get a free API key at: https://makersuite.google.com/app/apikey
                        """)], isError: true)
                }

                debugLog("Processing natural language query: \(question)")
                let startTime = Date()

                do {
                    let result = try await sharedTranslator.translateAndExecute(question: question, summarize: summarize)
                    let elapsed = Date().timeIntervalSince(startTime)

                    var response = ""

                    // Add summary if available
                    if let summary = result.summary {
                        response += "**Answer:** \(summary)\n\n"
                    }

                    // Add SQL used
                    response += "**SQL:** `\(result.sql)`\n\n"

                    // Add results
                    response += "**Results:** \(result.results.count) row(s) in \(String(format: "%.2f", elapsed))s\n\n"

                    if !result.results.isEmpty {
                        let jsonData = try JSONSerialization.data(withJSONObject: result.results, options: [.prettyPrinted, .sortedKeys])
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        response += "```json\n\(jsonString)\n```"
                    }

                    // Log to shared history
                    QueryHistoryLogger.shared.logQuery(
                        query: question,
                        source: .mcp,
                        rowCount: result.results.count
                    )

                    return CallTool.Result(content: [.text(response)])
                } catch {
                    debugLog("Natural language query failed: \(error.localizedDescription)")
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_history":
                let limit = min(params.arguments?["limit"]?.intValue ?? 20, 100)
                let sourceFilter = params.arguments?["source"]?.stringValue ?? "all"

                let entries: [QueryHistoryEntry]
                switch sourceFilter {
                case "app":
                    entries = Array(QueryHistoryLogger.shared.readEntries(source: .app).prefix(limit))
                case "mcp":
                    entries = Array(QueryHistoryLogger.shared.readEntries(source: .mcp).prefix(limit))
                default:
                    entries = Array(QueryHistoryLogger.shared.readEntries().prefix(limit))
                }

                if entries.isEmpty {
                    return CallTool.Result(content: [.text("No query history found.")])
                }

                let dateFormatter = ISO8601DateFormatter()
                var response = "**Query History** (\(entries.count) entries)\n\n"

                for (index, entry) in entries.enumerated() {
                    let timestamp = dateFormatter.string(from: entry.timestamp)
                    let rowInfo = entry.rowCount.map { " → \($0) rows" } ?? ""
                    response += "\(index + 1). [\(entry.source.rawValue)] \(timestamp)\(rowInfo)\n"
                    response += "   ```sql\n   \(entry.query)\n   ```\n\n"
                }

                return CallTool.Result(content: [.text(response)])

            case "osquery_examples":
                guard let tableName = params.arguments?["table"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'table' parameter")], isError: true)
                }

                let lowercased = tableName.lowercased()

                if let examples = tableExamples[lowercased] {
                    var response = "**Example queries for `\(lowercased)`:**\n\n"

                    for (index, example) in examples.enumerated() {
                        response += "\(index + 1). **\(example.description)**\n"
                        response += "```sql\n\(example.sql)\n```\n\n"
                    }

                    response += "Use `osquery_execute` to run any of these queries."
                    return CallTool.Result(content: [.text(response)])
                } else {
                    // No specific examples, provide generic help
                    var response = "No specific examples for `\(lowercased)`. "

                    // Suggest getting schema
                    response += "Try these:\n\n"
                    response += "1. **Get schema**: Use `osquery_schema` with tables: [\"\(lowercased)\"]\n"
                    response += "2. **Basic query**: `SELECT * FROM \(lowercased) LIMIT 10`\n"

                    // List available example tables
                    let availableTables = tableExamples.keys.sorted()
                    response += "\n**Tables with examples:** \(availableTables.joined(separator: ", "))"

                    return CallTool.Result(content: [.text(response)])
                }

            case "osquery_favorites":
                let favorites = FavoritesStore.shared.readFavorites()

                if favorites.isEmpty {
                    return CallTool.Result(content: [.text("No saved favorites found. Add favorites in the OsqueryNLI app.")])
                }

                var response = "**Saved Favorites** (\(favorites.count) total)\n\n"

                let dateFormatter = ISO8601DateFormatter()
                for (index, favorite) in favorites.enumerated() {
                    let created = dateFormatter.string(from: favorite.createdAt)
                    response += "\(index + 1). **\(favorite.displayName)**\n"
                    response += "   Query: `\(favorite.query.prefix(100))\(favorite.query.count > 100 ? "..." : "")`\n"
                    response += "   Created: \(created)\n\n"
                }

                response += "Use `osquery_run_favorite` with a name to execute a favorite."
                return CallTool.Result(content: [.text(response)])

            case "osquery_run_favorite":
                guard let name = params.arguments?["name"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'name' parameter")], isError: true)
                }

                guard let favorite = FavoritesStore.shared.findFavorite(byName: name) else {
                    let favorites = FavoritesStore.shared.readFavorites()
                    if favorites.isEmpty {
                        return CallTool.Result(content: [.text("Error: No favorites found. Add favorites in the OsqueryNLI app.")], isError: true)
                    }
                    let names = favorites.map { $0.displayName }.joined(separator: ", ")
                    return CallTool.Result(content: [.text("Error: No favorite matching '\(name)'. Available: \(names)")], isError: true)
                }

                let query = favorite.query

                // Check if it looks like SQL
                let isSQL = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .hasPrefix("SELECT") ||
                    query.uppercased().hasPrefix("PRAGMA")

                debugLog("Running favorite '\(favorite.displayName)': \(query)")

                do {
                    var results: [[String: Any]]

                    if isSQL {
                        // Direct SQL execution
                        results = try await osquery.execute(query)
                    } else {
                        // Natural language - needs LLM translation
                        guard sharedTranslator.isAvailable else {
                            return CallTool.Result(content: [.text("""
                                Error: This favorite contains a natural language query which requires an API key.
                                Set GEMINI_API_KEY environment variable or configure in OsqueryNLI app.
                                """)], isError: true)
                        }

                        let nlResult = try await sharedTranslator.translateAndExecute(question: query, summarize: false)
                        results = nlResult.results.map { row in
                            row.mapValues { $0 as Any }
                        }
                    }

                    var response = "**Ran favorite: \(favorite.displayName)**\n\n"
                    response += "Query: `\(query)`\n"
                    response += "Results: \(results.count) row(s)\n\n"

                    if !results.isEmpty {
                        let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
                        response += "```json\n\(jsonString)\n```"
                    }

                    // Log to history
                    QueryHistoryLogger.shared.logQuery(
                        query: query,
                        source: .mcp,
                        rowCount: results.count
                    )

                    return CallTool.Result(content: [.text(response)])
                } catch {
                    return CallTool.Result(content: [.text("Error running favorite: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_system_info":
                do {
                    var systemInfo: [String: Any] = [:]

                    // Get OS version
                    if let osResults = try? await osquery.execute("SELECT * FROM os_version"),
                       let os = osResults.first {
                        systemInfo["os_name"] = os["name"] ?? "Unknown"
                        systemInfo["os_version"] = os["version"] ?? "Unknown"
                        systemInfo["os_build"] = os["build"] ?? "Unknown"
                        systemInfo["os_platform"] = os["platform"] ?? "Unknown"
                    }

                    // Get uptime
                    if let uptimeResults = try? await osquery.execute("SELECT * FROM uptime"),
                       let uptime = uptimeResults.first {
                        let days = uptime["days"] ?? "0"
                        let hours = uptime["hours"] ?? "0"
                        let minutes = uptime["minutes"] ?? "0"
                        systemInfo["uptime"] = "\(days)d \(hours)h \(minutes)m"
                        systemInfo["uptime_days"] = days
                        systemInfo["uptime_hours"] = hours
                        systemInfo["uptime_minutes"] = minutes
                    }

                    // Get system info (hostname, hardware)
                    if let hostResults = try? await osquery.execute("SELECT hostname, computer_name, cpu_brand, physical_memory, hardware_model FROM system_info"),
                       let host = hostResults.first {
                        systemInfo["hostname"] = host["hostname"] ?? "Unknown"
                        systemInfo["computer_name"] = host["computer_name"] ?? "Unknown"
                        systemInfo["cpu"] = host["cpu_brand"] ?? "Unknown"
                        systemInfo["hardware_model"] = host["hardware_model"] ?? "Unknown"

                        if let memBytesStr = host["physical_memory"] as? String,
                           let bytes = Int64(memBytesStr) {
                            let gb = Double(bytes) / 1_073_741_824
                            systemInfo["memory_gb"] = String(format: "%.1f", gb)
                            systemInfo["memory_bytes"] = bytes
                        }
                    }

                    // Format response
                    var response = "**System Information**\n\n"
                    response += "| Property | Value |\n"
                    response += "|----------|-------|\n"

                    let orderedKeys = ["computer_name", "hostname", "os_name", "os_version", "os_build", "uptime", "cpu", "memory_gb", "hardware_model"]
                    for key in orderedKeys {
                        if let value = systemInfo[key] {
                            let displayKey = key.replacingOccurrences(of: "_", with: " ").capitalized
                            response += "| \(displayKey) | \(value) |\n"
                        }
                    }

                    response += "\n```json\n"
                    let jsonData = try JSONSerialization.data(withJSONObject: systemInfo, options: [.prettyPrinted, .sortedKeys])
                    let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    response += jsonString
                    response += "\n```"

                    return CallTool.Result(content: [.text(response)])
                } catch {
                    return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
                }

            case "osquery_check_process":
                guard let processName = params.arguments?["name"]?.stringValue else {
                    return CallTool.Result(content: [.text("Error: Missing 'name' parameter")], isError: true)
                }

                // Escape single quotes for SQL safety
                let safeName = processName.replacingOccurrences(of: "'", with: "''")

                do {
                    let sql = "SELECT name, pid, path, cmdline, state FROM processes WHERE name LIKE '%\(safeName)%' OR path LIKE '%\(safeName)%' LIMIT 10"
                    let results = try await osquery.execute(sql)

                    let isRunning = !results.isEmpty

                    var response: String

                    if isRunning {
                        response = "**✅ Process Found**\n\n"
                        response += "'\(processName)' is running (\(results.count) match\(results.count == 1 ? "" : "es")):\n\n"

                        for proc in results {
                            let name = proc["name"] as? String ?? "Unknown"
                            let pid = proc["pid"] as? String ?? "?"
                            let path = proc["path"] as? String ?? ""
                            response += "- **\(name)** (PID: \(pid))\n"
                            if !path.isEmpty {
                                response += "  Path: `\(path)`\n"
                            }
                        }

                        response += "\n```json\n"
                        let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                        response += String(data: jsonData, encoding: .utf8) ?? "[]"
                        response += "\n```"
                    } else {
                        response = "**❌ Process Not Found**\n\n"
                        response += "'\(processName)' is not currently running."
                    }

                    return CallTool.Result(content: [.text(response)])
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
