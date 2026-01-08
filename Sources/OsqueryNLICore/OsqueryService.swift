import Foundation

/// Service for executing osquery commands
/// Note: @unchecked Sendable is safe here because:
/// - `processRunner` is an actor (inherently Sendable)
/// - `osqueryPath` is immutable (let String, which is Sendable)
public final class OsqueryService: OsqueryServiceProtocol, @unchecked Sendable {
    private let processRunner = ProcessRunner()
    private let osqueryPath: String

    /// Path to osqueryd socket for connecting to daemon with extensions
    private static let daemonSocketPath = "/var/osquery/osquery.em"

    /// Whether AI Discovery extension is enabled
    public var aiDiscoveryEnabled: Bool = true

    /// Common paths where osqueryi might be installed
    public static let commonPaths = [
        "/opt/homebrew/bin/osqueryi",  // Apple Silicon Homebrew
        "/usr/local/bin/osqueryi",      // Intel Homebrew
        "/usr/bin/osqueryi"             // System install
    ]

    public init() {
        // Find osqueryi path
        if let path = Self.commonPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            self.osqueryPath = path
        } else {
            // Fallback to PATH lookup
            self.osqueryPath = "osqueryi"
        }

        // Clean up any stale socket files from previous runs
        Self.cleanupStaleSockets()
    }

    /// Clean up stale osquery socket files from /tmp
    private static func cleanupStaleSockets() {
        let fileManager = FileManager.default
        let tmpDir = "/tmp"

        guard let contents = try? fileManager.contentsOfDirectory(atPath: tmpDir) else { return }

        for file in contents where file.hasPrefix("osquery_nli_") && file.hasSuffix(".sock") {
            let path = (tmpDir as NSString).appendingPathComponent(file)
            // Remove socket files older than 1 hour (stale)
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let modDate = attrs[.modificationDate] as? Date,
               Date().timeIntervalSince(modDate) > 3600 {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }

    /// Initialize with a specific osqueryi path
    public init(osqueryPath: String) {
        self.osqueryPath = osqueryPath
    }

    /// Check if osqueryd daemon is running (socket exists)
    private var isDaemonRunning: Bool {
        FileManager.default.fileExists(atPath: Self.daemonSocketPath)
    }

    /// Path to bundled AI tables extension
    public var bundledExtensionPath: String? {
        // Check in app bundle Resources
        if let resourceURL = Bundle.main.resourceURL {
            let extensionPath = resourceURL.appendingPathComponent("ai_tables.ext").path
            if FileManager.default.fileExists(atPath: extensionPath) {
                return extensionPath
            }
        }

        // Check in app bundle directly (for development)
        let bundlePath = Bundle.main.bundlePath
        let devPath = (bundlePath as NSString).deletingLastPathComponent + "/OsqueryNLI_OsqueryNLI.bundle/ai_tables.ext"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }

        // Check in Resources folder relative to executable (for swift run)
        let execPath = Bundle.main.executablePath ?? ""
        let execDir = (execPath as NSString).deletingLastPathComponent
        let siblingPath = (execDir as NSString).appendingPathComponent("OsqueryNLI_OsqueryNLI.bundle/ai_tables.ext")
        if FileManager.default.fileExists(atPath: siblingPath) {
            return siblingPath
        }

        return nil
    }

    /// Check if AI Discovery extension is available
    public var isAIDiscoveryAvailable: Bool {
        bundledExtensionPath != nil || isDaemonRunning
    }

    /// Check if extension tables are currently loadable
    private var canLoadExtensionTables: Bool {
        isDaemonRunning || (aiDiscoveryEnabled && bundledExtensionPath != nil)
    }

    /// Whether we need to force arm64 architecture (when loading arm64-only extension)
    private var needsArm64: Bool {
        // Force arm64 when loading bundled extension (which is arm64-only)
        // This ensures compatibility on Macs where osqueryi might default to x86_64
        aiDiscoveryEnabled && bundledExtensionPath != nil
    }

    /// Build arguments for osqueryi, optionally connecting to daemon or loading extension
    private func buildArguments(for query: String, jsonOutput: Bool = true) -> [String] {
        var args: [String] = []

        // Priority: 1) Load bundled extension if AI Discovery enabled (daemon may not have it)
        //           2) Connect to daemon if running (for non-AI queries when extension not needed)
        // Note: We always use bundled extension when AI Discovery is enabled because the
        // system daemon typically doesn't have our AI tables extension loaded.
        if aiDiscoveryEnabled, let extensionPath = bundledExtensionPath {
            // Load bundled extension directly with isolated socket
            // Use UUID for unique socket per query to avoid conflicts
            let socketPath = "/tmp/osquery_nli_\(UUID().uuidString).sock"
            args.append(contentsOf: [
                "--extensions_socket", socketPath,
                "--extension", extensionPath,
                "--extensions_require=ai_tables",
                "--extensions_timeout=10",
                "--disable_database"
            ])
        } else if isDaemonRunning {
            args.append(contentsOf: ["--connect", Self.daemonSocketPath])
        }

        if jsonOutput {
            args.append("--json")
        }

        args.append(query)
        return args
    }

    /// Run osqueryi, forcing arm64 architecture when loading extension
    private func runOsquery(arguments: [String], timeout: TimeInterval) async throws -> ProcessRunner.ProcessResult {
        if needsArm64 {
            // Use arch -arm64 to force arm64 when loading arm64-only extension
            var archArgs = ["-arm64", osqueryPath]
            archArgs.append(contentsOf: arguments)
            return try await processRunner.run(
                executable: "/usr/bin/arch",
                arguments: archArgs,
                timeout: timeout
            )
        } else {
            return try await processRunner.run(
                executable: osqueryPath,
                arguments: arguments,
                timeout: timeout
            )
        }
    }

    public func execute(_ sql: String) async throws -> [[String: Any]] {
        // Validate SQL to prevent potential injection attacks
        try validateSQL(sql)

        let result = try await runOsquery(
            arguments: buildArguments(for: sql, jsonOutput: true),
            timeout: 30.0
        )

        let stdout = result.stdoutString ?? ""
        let stderr = result.stderrString ?? ""

        // Check for errors
        if result.exitCode != 0 {
            let errorMsg = stderr.isEmpty ? stdout : stderr
            throw OsqueryError.executionFailed(stderr: errorMsg.isEmpty ? "Exit code \(result.exitCode)" : errorMsg)
        }

        // Parse JSON output
        guard !result.stdout.isEmpty else {
            return []
        }

        // Try to find JSON array in output (sometimes there's extra text/warnings)
        var jsonData = result.stdout

        // If stdout contains non-JSON prefix, try to extract JSON array
        if stdout.contains("[") {
            if let startIndex = stdout.firstIndex(of: "["),
               let endIndex = stdout.lastIndex(of: "]") {
                let jsonSubstring = String(stdout[startIndex...endIndex])
                if let extractedData = jsonSubstring.data(using: .utf8) {
                    jsonData = extractedData
                }
            }
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                // Show what we got for debugging
                let preview = String(stdout.prefix(200))
                throw OsqueryError.parseError(details: "Expected JSON array. Got: \(preview)")
            }
            return json
        } catch let error as OsqueryError {
            throw error
        } catch {
            let preview = String(stdout.prefix(200))
            throw OsqueryError.parseError(details: "\(error.localizedDescription)\nOutput: \(preview)")
        }
    }

    public func getAllTables() async throws -> [String] {
        let result = try await runOsquery(
            arguments: buildArguments(for: ".tables", jsonOutput: false),
            timeout: 10.0
        )

        guard let output = result.stdoutString else {
            return []
        }

        // Parse output format: "  => table1\n  => table2"
        var tables = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("=>") }
            .map { $0.replacingOccurrences(of: "=>", with: "").trimmingCharacters(in: .whitespaces) }

        // If extension tables are available, add them
        // (.tables doesn't list extension tables)
        if canLoadExtensionTables {
            // Add known AI Discovery tables (avoiding duplicates)
            let existingTables = Set(tables)
            for aiTable in Self.aiDiscoveryTables {
                if !existingTables.contains(aiTable) {
                    tables.append(aiTable)
                }
            }
        }

        // Return unique sorted tables
        return Array(Set(tables)).sorted()
    }

    /// Fetch tables provided by extensions (not shown by .tables)
    private func getExtensionTables() async throws -> [String] {
        // Query osquery_registry for extension-provided tables (owner_uuid != 0 means extension table)
        let result = try await processRunner.run(
            executable: osqueryPath,
            arguments: buildArguments(for: "SELECT name FROM osquery_registry WHERE registry = 'table' AND owner_uuid != '0';", jsonOutput: true),
            timeout: 10.0
        )

        guard let output = result.stdoutString, !output.isEmpty else {
            return []
        }

        // Parse JSON response
        if let startIndex = output.firstIndex(of: "["),
           let endIndex = output.lastIndex(of: "]") {
            let jsonSubstring = String(output[startIndex...endIndex])
            if let jsonData = jsonSubstring.data(using: .utf8),
               let tables = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                return tables.compactMap { $0["name"] as? String }
            }
        }

        return []
    }

    public func getSchema(for tables: [String]) async throws -> String {
        guard !tables.isEmpty else { return "" }

        let tableSet = Set(tables)
        let aiTableSet = Set(Self.aiDiscoveryTables)
        let requestedAITables = tables.filter { aiTableSet.contains($0) }

        var schemaOutput = ""

        // Get ALL native table schemas in one call, then filter
        let args = buildArguments(for: ".schema", jsonOutput: false)
        let result = try? await runOsquery(arguments: args, timeout: 15.0)

        if let allSchemas = result?.stdoutString {
            // Parse and filter to only requested tables
            // Schema format: CREATE TABLE tablename(...);
            let lines = allSchemas.components(separatedBy: "\n")
            var currentSchema = ""

            for line in lines {
                if line.hasPrefix("CREATE TABLE ") || line.hasPrefix("CREATE VIRTUAL TABLE ") {
                    // Save previous schema if it was for a requested table
                    if !currentSchema.isEmpty {
                        schemaOutput += currentSchema + "\n"
                    }
                    // Extract table name and check if requested
                    let tableName = extractTableName(from: line)
                    if tableSet.contains(tableName) {
                        currentSchema = line
                    } else {
                        currentSchema = ""
                    }
                } else if !currentSchema.isEmpty {
                    // Continue building current schema
                    currentSchema += "\n" + line
                }
            }
            // Don't forget the last schema
            if !currentSchema.isEmpty {
                schemaOutput += currentSchema + "\n"
            }
        }

        // Add AI table schemas (hardcoded since they're our extension)
        if !requestedAITables.isEmpty && canLoadExtensionTables {
            for table in requestedAITables {
                if let aiSchema = Self.aiTableSchemas[table] {
                    schemaOutput += aiSchema + "\n"
                }
            }
        }

        return schemaOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract table name from CREATE TABLE statement
    private func extractTableName(from createStatement: String) -> String {
        // Format: CREATE TABLE tablename(...) or CREATE VIRTUAL TABLE tablename USING...
        let pattern = "CREATE (?:VIRTUAL )?TABLE ([a-zA-Z_][a-zA-Z0-9_]*)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: createStatement, options: [], range: NSRange(createStatement.startIndex..., in: createStatement)),
           let range = Range(match.range(at: 1), in: createStatement) {
            return String(createStatement[range])
        }
        return ""
    }

    /// Get schema for a table using PRAGMA table_info (works for extension tables)
    private func getSchemaViaPragma(_ table: String) async throws -> String {
        let result = try await runOsquery(
            arguments: buildArguments(for: "PRAGMA table_info(\(table));", jsonOutput: true),
            timeout: 10.0
        )

        guard let output = result.stdoutString, !output.isEmpty else {
            return ""
        }

        // Parse JSON response
        if let startIndex = output.firstIndex(of: "["),
           let endIndex = output.lastIndex(of: "]") {
            let jsonSubstring = String(output[startIndex...endIndex])
            if let jsonData = jsonSubstring.data(using: .utf8),
               let columns = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                // Build CREATE TABLE statement
                let columnDefs = columns.compactMap { col -> String? in
                    guard let name = col["name"] as? String,
                          let type = col["type"] as? String else { return nil }
                    return "  \(name) \(type)"
                }
                if !columnDefs.isEmpty {
                    return "CREATE TABLE \(table) (\n\(columnDefs.joined(separator: ",\n"))\n);"
                }
            }
        }

        return ""
    }

    public func isAvailable() async -> Bool {
        do {
            let result = try await processRunner.run(
                executable: osqueryPath,
                arguments: ["--version"],
                timeout: 5.0
            )
            return result.exitCode == 0
        } catch {
            return false
        }
    }

    // MARK: - SQL Validation

    /// Validates SQL query to ensure it's safe to execute
    /// Osquery only supports SELECT queries, but we validate to prevent:
    /// - Shell escape attempts
    /// - Excessively long queries
    /// - Suspicious patterns
    private func validateSQL(_ sql: String) throws {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for empty query
        guard !trimmed.isEmpty else {
            throw OsqueryError.executionFailed(stderr: "Empty query")
        }

        // Check query length (prevent DoS)
        guard trimmed.count <= 10_000 else {
            throw OsqueryError.executionFailed(stderr: "Query too long (max 10,000 characters)")
        }

        // Osquery only supports SELECT - validate this
        let upperSQL = trimmed.uppercased()
        let allowedPrefixes = ["SELECT", "PRAGMA", "EXPLAIN"]
        let hasAllowedPrefix = allowedPrefixes.contains { upperSQL.hasPrefix($0) }

        guard hasAllowedPrefix else {
            throw OsqueryError.executionFailed(stderr: "Only SELECT queries are allowed")
        }

        // Check for shell escape attempts (semicolons followed by commands, etc.)
        // Note: Multiple SELECT statements separated by ; are valid in osquery
        let dangerousPatterns = [
            "$(", "`",           // Command substitution
            "&&", "||",         // Shell operators
            "|",                // Pipe
            ">", "<",           // Redirects
            "\n", "\r",         // Newlines (could be used for injection)
            "\\x", "\\u"        // Escape sequences
        ]

        for pattern in dangerousPatterns {
            if trimmed.contains(pattern) {
                throw OsqueryError.executionFailed(stderr: "Query contains disallowed characters")
            }
        }
    }
}

// MARK: - Convenience Methods

extension OsqueryService {
    /// AI Discovery extension tables (hardcoded since .tables doesn't list extension tables)
    public static let aiDiscoveryTables = [
        "ai_tools_installed",
        "ai_mcp_servers",
        "ai_env_vars",
        "ai_browser_extensions",
        "ai_code_assistants",
        "ai_api_keys",
        "ai_local_servers"
    ]

    /// Hardcoded schemas for AI Discovery tables (faster than PRAGMA queries)
    public static let aiTableSchemas: [String: String] = [
        "ai_tools_installed": """
            CREATE TABLE ai_tools_installed (
              name TEXT,
              category TEXT,
              path TEXT,
              version TEXT,
              installed TEXT,
              running TEXT,
              config_path TEXT
            );
            """,
        "ai_mcp_servers": """
            CREATE TABLE ai_mcp_servers (
              name TEXT,
              config_file TEXT,
              server_type TEXT,
              command TEXT,
              args TEXT,
              url TEXT,
              has_env_vars TEXT,
              has_api_key TEXT,
              source_app TEXT
            );
            """,
        "ai_env_vars": """
            CREATE TABLE ai_env_vars (
              variable_name TEXT,
              source TEXT,
              source_file TEXT,
              is_set TEXT,
              value_preview TEXT,
              category TEXT
            );
            """,
        "ai_browser_extensions": """
            CREATE TABLE ai_browser_extensions (
              name TEXT,
              browser TEXT,
              extension_id TEXT,
              version TEXT,
              enabled TEXT,
              ai_related TEXT,
              path TEXT
            );
            """,
        "ai_code_assistants": """
            CREATE TABLE ai_code_assistants (
              name TEXT,
              tool TEXT,
              config_type TEXT,
              config_path TEXT,
              enabled TEXT,
              details TEXT
            );
            """,
        "ai_api_keys": """
            CREATE TABLE ai_api_keys (
              service TEXT,
              source TEXT,
              env_var_name TEXT,
              key_present TEXT,
              key_prefix TEXT,
              key_length TEXT
            );
            """,
        "ai_local_servers": """
            CREATE TABLE ai_local_servers (
              name TEXT,
              service_type TEXT,
              pid TEXT,
              port TEXT,
              status TEXT,
              endpoint TEXT,
              model_loaded TEXT,
              version TEXT
            );
            """
    ]

    /// Get common tables that are useful for most queries
    public static let commonTables: Set<String> = [
        // System info
        "uptime",
        "osquery_info",
        "system_info",
        "os_version",
        "kernel_info",
        // Users & groups
        "users",
        "groups",
        "logged_in_users",
        // Processes
        "processes",
        "process_open_files",
        // Network
        "listening_ports",
        "interface_details",
        "routes",
        "dns_resolvers",
        "etc_hosts",
        "arp_cache",
        "wifi_status",
        // Hardware
        "usb_devices",
        "battery",
        "cpu_info",
        "memory_info",
        // Storage
        "mounts",
        "disk_encryption",
        // Software & apps
        "apps",
        "homebrew_packages",
        // Startup & services
        "launchd",
        "startup_items",
        // Security
        "sip_config",
        "gatekeeper",
        "certificates",
        "keychain_items",
        "ssh_keys",
        "authorization_mechanisms",
        // Files
        "file",
        "hash",
        "extended_attributes",
        // AI Discovery (extension tables)
        "ai_tools_installed",
        "ai_mcp_servers",
        "ai_env_vars",
        "ai_browser_extensions",
        "ai_code_assistants",
        "ai_api_keys",
        "ai_local_servers"
    ]

    /// Default enabled tables for new installations - comprehensive set for common queries
    public static let defaultEnabledTables: [String] = [
        // Essentials
        "uptime",
        "osquery_info",
        "system_info",
        "os_version",
        // Users
        "users",
        "logged_in_users",
        // Processes
        "processes",
        // Network
        "listening_ports",
        "interface_details",
        "wifi_status",
        // Hardware
        "battery",
        // Storage
        "mounts",
        "disk_encryption",
        // Software
        "apps",
        "homebrew_packages",
        // Startup & services - critical for "what starts at login" queries
        "launchd",
        "startup_items",
        // Security
        "sip_config",
        "gatekeeper",
        // AI Discovery (extension tables)
        "ai_tools_installed",
        "ai_mcp_servers",
        "ai_env_vars",
        "ai_browser_extensions",
        "ai_code_assistants",
        "ai_api_keys",
        "ai_local_servers"
    ]
}
