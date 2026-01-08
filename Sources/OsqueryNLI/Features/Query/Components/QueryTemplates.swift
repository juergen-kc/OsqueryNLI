import SwiftUI

// MARK: - Query Template Model

struct QueryTemplate: Identifiable {
    let id = UUID()
    let title: String
    let query: String
    let description: String
    let icon: String
}

struct QueryCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let templates: [QueryTemplate]
}

// MARK: - Template Data

enum QueryTemplateLibrary {
    static let categories: [QueryCategory] = [
        QueryCategory(
            name: "System Info",
            icon: "desktopcomputer",
            templates: [
                QueryTemplate(
                    title: "System Uptime",
                    query: "What is the system uptime?",
                    description: "How long has the system been running",
                    icon: "clock"
                ),
                QueryTemplate(
                    title: "OS Version",
                    query: "What version of macOS is installed?",
                    description: "Operating system version details",
                    icon: "apple.logo"
                ),
                QueryTemplate(
                    title: "Hardware Info",
                    query: "What are the hardware specifications of this Mac?",
                    description: "CPU, memory, and model information",
                    icon: "cpu"
                ),
                QueryTemplate(
                    title: "Disk Space",
                    query: "How much disk space is available on each volume?",
                    description: "Storage capacity and usage",
                    icon: "internaldrive"
                ),
                QueryTemplate(
                    title: "Kernel Version",
                    query: "What kernel version is running?",
                    description: "Darwin kernel information",
                    icon: "terminal"
                ),
                QueryTemplate(
                    title: "Last Reboot",
                    query: "When was the last system reboot?",
                    description: "System restart timestamp",
                    icon: "arrow.clockwise"
                ),
                QueryTemplate(
                    title: "Hostname",
                    query: "What is the hostname and computer name?",
                    description: "System identity information",
                    icon: "tag"
                ),
                QueryTemplate(
                    title: "Time Zone",
                    query: "What time zone is the system set to?",
                    description: "Current timezone configuration",
                    icon: "globe.americas"
                )
            ]
        ),
        QueryCategory(
            name: "Processes",
            icon: "gearshape.2",
            templates: [
                QueryTemplate(
                    title: "Top Memory Users",
                    query: "Show me the top 10 processes using the most memory",
                    description: "Processes consuming the most RAM",
                    icon: "memorychip"
                ),
                QueryTemplate(
                    title: "Top CPU Users",
                    query: "What processes are using the most CPU right now?",
                    description: "Processes with highest CPU usage",
                    icon: "cpu"
                ),
                QueryTemplate(
                    title: "All Running Processes",
                    query: "List all running processes with their PIDs and users",
                    description: "Complete list of active processes",
                    icon: "list.bullet"
                ),
                QueryTemplate(
                    title: "Find Process",
                    query: "Is there a process named 'Safari' running?",
                    description: "Find specific processes by name",
                    icon: "magnifyingglass"
                ),
                QueryTemplate(
                    title: "Root Processes",
                    query: "What processes are running as root?",
                    description: "Processes with elevated privileges",
                    icon: "person.badge.shield.checkmark"
                ),
                QueryTemplate(
                    title: "Process Tree",
                    query: "Show me the parent-child relationships of running processes",
                    description: "Process hierarchy and parents",
                    icon: "arrow.triangle.branch"
                ),
                QueryTemplate(
                    title: "Long Running",
                    query: "What processes have been running the longest?",
                    description: "Processes by runtime duration",
                    icon: "timer"
                ),
                QueryTemplate(
                    title: "Open Files",
                    query: "What files does the process 'Finder' have open?",
                    description: "Files opened by a process",
                    icon: "doc"
                )
            ]
        ),
        QueryCategory(
            name: "Network",
            icon: "network",
            templates: [
                QueryTemplate(
                    title: "Listening Ports",
                    query: "What ports are listening for connections?",
                    description: "Open network ports and services",
                    icon: "antenna.radiowaves.left.and.right"
                ),
                QueryTemplate(
                    title: "Network Interfaces",
                    query: "Show me all network interfaces and their IP addresses",
                    description: "Network adapter configuration",
                    icon: "wifi"
                ),
                QueryTemplate(
                    title: "DNS Servers",
                    query: "What DNS servers are configured?",
                    description: "DNS resolver configuration",
                    icon: "globe"
                ),
                QueryTemplate(
                    title: "WiFi Network",
                    query: "What WiFi network am I connected to and what's the signal strength?",
                    description: "Current wireless connection details",
                    icon: "wifi"
                ),
                QueryTemplate(
                    title: "Active Connections",
                    query: "Show all active network connections",
                    description: "Current TCP/UDP connections",
                    icon: "point.3.connected.trianglepath.dotted"
                ),
                QueryTemplate(
                    title: "Routing Table",
                    query: "What are the network routes configured?",
                    description: "IP routing configuration",
                    icon: "arrow.triangle.swap"
                ),
                QueryTemplate(
                    title: "ARP Table",
                    query: "Show the ARP cache with MAC addresses",
                    description: "IP to MAC address mappings",
                    icon: "tablecells"
                ),
                QueryTemplate(
                    title: "Hosts File",
                    query: "What entries are in the /etc/hosts file?",
                    description: "Local DNS overrides",
                    icon: "doc.text"
                )
            ]
        ),
        QueryCategory(
            name: "Security",
            icon: "lock.shield",
            templates: [
                QueryTemplate(
                    title: "Disk Encryption",
                    query: "Is FileVault disk encryption enabled?",
                    description: "Check disk encryption status",
                    icon: "lock.fill"
                ),
                QueryTemplate(
                    title: "Firewall Status",
                    query: "Is the macOS firewall enabled and what are the rules?",
                    description: "Firewall configuration",
                    icon: "flame"
                ),
                QueryTemplate(
                    title: "SIP Status",
                    query: "Is System Integrity Protection (SIP) enabled?",
                    description: "macOS security protection status",
                    icon: "checkmark.shield"
                ),
                QueryTemplate(
                    title: "Gatekeeper",
                    query: "What is the Gatekeeper status?",
                    description: "App security settings",
                    icon: "hand.raised"
                ),
                QueryTemplate(
                    title: "Login Items",
                    query: "What apps and services start at login?",
                    description: "Startup applications",
                    icon: "person.badge.key"
                ),
                QueryTemplate(
                    title: "User Accounts",
                    query: "List all user accounts with their details",
                    description: "Local user accounts and info",
                    icon: "person.2"
                ),
                QueryTemplate(
                    title: "Admin Users",
                    query: "Which users have administrator privileges?",
                    description: "Users in admin group",
                    icon: "person.badge.shield.checkmark"
                ),
                QueryTemplate(
                    title: "SSH Keys",
                    query: "What SSH authorized keys are configured?",
                    description: "SSH access configuration",
                    icon: "key"
                ),
                QueryTemplate(
                    title: "Certificates",
                    query: "What certificates are in the system keychain?",
                    description: "Installed security certificates",
                    icon: "signature"
                ),
                QueryTemplate(
                    title: "Kernel Extensions",
                    query: "What kernel extensions are loaded?",
                    description: "Loaded kexts and drivers",
                    icon: "puzzlepiece"
                )
            ]
        ),
        QueryCategory(
            name: "Hardware",
            icon: "cpu",
            templates: [
                QueryTemplate(
                    title: "USB Devices",
                    query: "What USB devices are connected?",
                    description: "Connected USB peripherals",
                    icon: "cable.connector"
                ),
                QueryTemplate(
                    title: "Battery Health",
                    query: "What is the battery health, cycle count, and charge level?",
                    description: "Battery condition and status",
                    icon: "battery.100"
                ),
                QueryTemplate(
                    title: "Displays",
                    query: "What displays are connected and what are their resolutions?",
                    description: "Monitor and display information",
                    icon: "display"
                ),
                QueryTemplate(
                    title: "Bluetooth Devices",
                    query: "What Bluetooth devices are paired or connected?",
                    description: "Paired Bluetooth peripherals",
                    icon: "dot.radiowaves.right"
                ),
                QueryTemplate(
                    title: "Memory Modules",
                    query: "What memory modules are installed and what are their specs?",
                    description: "RAM configuration details",
                    icon: "memorychip"
                ),
                QueryTemplate(
                    title: "CPU Info",
                    query: "What CPU is installed and how many cores does it have?",
                    description: "Processor specifications",
                    icon: "cpu"
                ),
                QueryTemplate(
                    title: "PCI Devices",
                    query: "What PCI devices are installed?",
                    description: "PCI/PCIe hardware",
                    icon: "rectangle.connected.to.line.below"
                ),
                QueryTemplate(
                    title: "Disk Drives",
                    query: "What physical disks are installed and what are their sizes?",
                    description: "Storage device information",
                    icon: "internaldrive"
                )
            ]
        ),
        QueryCategory(
            name: "Software",
            icon: "app.badge",
            templates: [
                QueryTemplate(
                    title: "All Applications",
                    query: "List all installed applications with their versions",
                    description: "Applications in /Applications",
                    icon: "square.grid.2x2"
                ),
                QueryTemplate(
                    title: "Homebrew Packages",
                    query: "What Homebrew packages are installed?",
                    description: "Packages installed via brew",
                    icon: "shippingbox"
                ),
                QueryTemplate(
                    title: "Recently Installed",
                    query: "What applications were recently installed or updated?",
                    description: "Apps by install date",
                    icon: "clock.badge"
                ),
                QueryTemplate(
                    title: "Browser Extensions",
                    query: "What browser extensions are installed in Safari and Chrome?",
                    description: "Browser add-ons and extensions",
                    icon: "puzzlepiece.extension"
                ),
                QueryTemplate(
                    title: "Launch Daemons",
                    query: "What launch daemons are configured?",
                    description: "System-wide background services",
                    icon: "gearshape"
                ),
                QueryTemplate(
                    title: "Launch Agents",
                    query: "What launch agents are configured for the current user?",
                    description: "User-specific background services",
                    icon: "person.crop.circle.badge.clock"
                ),
                QueryTemplate(
                    title: "Python Packages",
                    query: "What Python packages are installed via pip?",
                    description: "Installed pip packages",
                    icon: "chevron.left.forwardslash.chevron.right"
                ),
                QueryTemplate(
                    title: "System Extensions",
                    query: "What system extensions are installed?",
                    description: "Modern macOS system extensions",
                    icon: "puzzlepiece.extension"
                )
            ]
        ),
        QueryCategory(
            name: "Files & Storage",
            icon: "folder",
            templates: [
                QueryTemplate(
                    title: "Downloads Folder",
                    query: "What are the recent files in the Downloads folder?",
                    description: "Recently downloaded files",
                    icon: "arrow.down.circle"
                ),
                QueryTemplate(
                    title: "Large Files",
                    query: "What are the largest files on the system?",
                    description: "Find space-consuming files",
                    icon: "doc.badge.ellipsis"
                ),
                QueryTemplate(
                    title: "Mounted Volumes",
                    query: "What volumes and drives are currently mounted?",
                    description: "Attached storage devices",
                    icon: "externaldrive"
                ),
                QueryTemplate(
                    title: "Shared Folders",
                    query: "What folders are shared on the network?",
                    description: "SMB/AFP shares",
                    icon: "folder.badge.person.crop"
                ),
                QueryTemplate(
                    title: "Cron Jobs",
                    query: "What cron jobs are scheduled?",
                    description: "Scheduled tasks via cron",
                    icon: "calendar.badge.clock"
                ),
                QueryTemplate(
                    title: "Temp Files",
                    query: "What's in the system temp directories?",
                    description: "Temporary file usage",
                    icon: "trash"
                )
            ]
        ),
        QueryCategory(
            name: "Troubleshooting",
            icon: "wrench.and.screwdriver",
            templates: [
                QueryTemplate(
                    title: "Crashes",
                    query: "What applications have crashed recently?",
                    description: "Recent application crashes",
                    icon: "exclamationmark.triangle"
                ),
                QueryTemplate(
                    title: "Disk Errors",
                    query: "Are there any disk SMART errors?",
                    description: "Storage health warnings",
                    icon: "exclamationmark.circle"
                ),
                QueryTemplate(
                    title: "Failed Logins",
                    query: "Have there been any failed login attempts?",
                    description: "Authentication failures",
                    icon: "xmark.shield"
                ),
                QueryTemplate(
                    title: "System Load",
                    query: "What is the current system load average?",
                    description: "CPU load metrics",
                    icon: "chart.line.uptrend.xyaxis"
                ),
                QueryTemplate(
                    title: "Memory Pressure",
                    query: "Is the system under memory pressure?",
                    description: "RAM usage and swap",
                    icon: "gauge.with.dots.needle.67percent"
                ),
                QueryTemplate(
                    title: "Blocked Processes",
                    query: "Are any processes in an uninterruptible state?",
                    description: "Stuck or blocked processes",
                    icon: "hand.raised.slash"
                )
            ]
        ),
        QueryCategory(
            name: "AI Discovery",
            icon: "brain",
            templates: [
                QueryTemplate(
                    title: "Installed AI Tools",
                    query: "What AI tools and applications are installed?",
                    description: "Discover AI IDEs, assistants, and tools",
                    icon: "sparkles"
                ),
                QueryTemplate(
                    title: "Running AI Tools",
                    query: "Which AI tools are currently running?",
                    description: "Active AI applications",
                    icon: "play.circle"
                ),
                QueryTemplate(
                    title: "MCP Servers",
                    query: "What MCP servers are configured?",
                    description: "Model Context Protocol configurations",
                    icon: "server.rack"
                ),
                QueryTemplate(
                    title: "AI Browser Extensions",
                    query: "What AI-related browser extensions are installed?",
                    description: "ChatGPT, Copilot, and other AI extensions",
                    icon: "puzzlepiece.extension"
                ),
                QueryTemplate(
                    title: "Code Assistants",
                    query: "What AI code assistants are configured?",
                    description: "Copilot, Continue, Cody, Tabnine, etc.",
                    icon: "chevron.left.forwardslash.chevron.right"
                ),
                QueryTemplate(
                    title: "AI API Keys",
                    query: "Which AI services have API keys configured?",
                    description: "OpenAI, Anthropic, Google AI, etc.",
                    icon: "key"
                ),
                QueryTemplate(
                    title: "Local AI Servers",
                    query: "Are any local AI servers running?",
                    description: "Ollama, LM Studio, LocalAI status",
                    icon: "desktopcomputer"
                ),
                QueryTemplate(
                    title: "AI Environment Variables",
                    query: "What AI-related environment variables are set?",
                    description: "API keys and AI config in environment",
                    icon: "terminal"
                ),
                QueryTemplate(
                    title: "Full AI Inventory",
                    query: "Give me a complete inventory of all AI tools, services, and configurations on this system",
                    description: "Comprehensive AI footprint analysis",
                    icon: "list.clipboard"
                ),
                QueryTemplate(
                    title: "Downloaded AI Models",
                    query: "What AI models are downloaded locally?",
                    description: "Ollama, LM Studio, HuggingFace models",
                    icon: "cube.box"
                ),
                QueryTemplate(
                    title: "AI Containers",
                    query: "What AI-related containers are running?",
                    description: "Docker/Podman AI workloads",
                    icon: "shippingbox"
                ),
                QueryTemplate(
                    title: "AI SDK Dependencies",
                    query: "What AI libraries are used in my projects?",
                    description: "OpenAI, LangChain, PyTorch in projects",
                    icon: "books.vertical"
                ),
                QueryTemplate(
                    title: "Large Language Models",
                    query: "What LLMs are downloaded and how big are they?",
                    description: "Model sizes and quantization levels",
                    icon: "text.bubble"
                ),
                QueryTemplate(
                    title: "GPU AI Workloads",
                    query: "What AI containers are using the GPU?",
                    description: "GPU-accelerated AI containers",
                    icon: "rectangle.stack.badge.play"
                )
            ]
        )
    ]
}

// MARK: - Templates View

struct QueryTemplatesView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: QueryCategory?

    private var filteredCategories: [QueryCategory] {
        if searchText.isEmpty {
            return QueryTemplateLibrary.categories
        }

        return QueryTemplateLibrary.categories.compactMap { category in
            let filteredTemplates = category.templates.filter { template in
                template.title.localizedCaseInsensitiveContains(searchText) ||
                template.query.localizedCaseInsensitiveContains(searchText) ||
                template.description.localizedCaseInsensitiveContains(searchText)
            }

            if filteredTemplates.isEmpty {
                return nil
            }

            return QueryCategory(
                name: category.name,
                icon: category.icon,
                templates: filteredTemplates
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Query Templates")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Categories and Templates
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredCategories) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            // Category header
                            Label(category.name, systemImage: category.icon)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            // Templates grid
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ], spacing: 10) {
                                ForEach(category.templates) { template in
                                    TemplateCard(template: template) {
                                        onSelect(template.query)
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(width: 500, height: 450)
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: QueryTemplate
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(template.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                }

                Text(template.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Compact Templates Button (for empty state)

struct TemplatesButton: View {
    let onSelect: (String) -> Void
    @State private var showingTemplates = false

    var body: some View {
        Button {
            showingTemplates = true
        } label: {
            Label("Browse Templates", systemImage: "rectangle.stack")
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showingTemplates) {
            QueryTemplatesView(onSelect: onSelect)
        }
    }
}
