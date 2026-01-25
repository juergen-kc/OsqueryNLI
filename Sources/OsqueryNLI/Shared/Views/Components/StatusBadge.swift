import SwiftUI

/// Badge component for provider labels, status indicators, and tags
struct StatusBadge: View {
    /// Badge style variants
    enum BadgeStyle {
        case pill      // Rounded capsule shape
        case tag       // Rounded rectangle
        case dot       // Circle indicator with text
    }

    let text: String
    let color: Color
    let icon: String?
    let style: BadgeStyle

    init(
        _ text: String,
        color: Color = .secondary,
        icon: String? = nil,
        style: BadgeStyle = .pill
    ) {
        self.text = text
        self.color = color
        self.icon = icon
        self.style = style
    }

    var body: some View {
        switch style {
        case .pill:
            pillBadge
        case .tag:
            tagBadge
        case .dot:
            dotBadge
        }
    }

    // MARK: - Badge Styles

    private var pillBadge: some View {
        HStack(spacing: AppLayout.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: AppLayout.Icon.tiny))
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, AppLayout.Spacing.sm)
        .padding(.vertical, AppLayout.Spacing.xxs)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var tagBadge: some View {
        HStack(spacing: AppLayout.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: AppLayout.Icon.small))
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, AppLayout.Spacing.sm)
        .padding(.vertical, AppLayout.Spacing.xs)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.CornerRadius.sm))
    }

    private var dotBadge: some View {
        HStack(spacing: AppLayout.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: AppLayout.Icon.small))
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Convenience Factory Methods

extension StatusBadge {
    /// Create a status badge with a running/active state
    static func running(_ text: String = "Running") -> StatusBadge {
        StatusBadge(text, color: .green, style: .dot)
    }

    /// Create a status badge with a stopped/inactive state
    static func stopped(_ text: String = "Stopped") -> StatusBadge {
        StatusBadge(text, color: .secondary, style: .dot)
    }

    /// Create a status badge with an error state
    static func error(_ text: String = "Error") -> StatusBadge {
        StatusBadge(text, color: .red, style: .dot)
    }

    /// Create a provider badge (pill style)
    static func provider(_ name: String, icon: String = "cpu") -> StatusBadge {
        StatusBadge(name, color: .secondary, icon: icon, style: .pill)
    }

    /// Create an MCP badge
    static func mcp() -> StatusBadge {
        StatusBadge("MCP", color: .blue, style: .pill)
    }

    /// Create an AI table badge
    static func aiTable() -> StatusBadge {
        StatusBadge("AI", color: .purple, icon: "sparkles", style: .tag)
    }
}

#Preview {
    VStack(spacing: 16) {
        Group {
            Text("Pill Style")
                .font(.headline)
            HStack(spacing: 8) {
                StatusBadge("Claude", color: .orange, icon: "cpu", style: .pill)
                StatusBadge("OpenAI", color: .green, icon: "cpu", style: .pill)
                StatusBadge.mcp()
            }
        }

        Group {
            Text("Tag Style")
                .font(.headline)
            HStack(spacing: 8) {
                StatusBadge("Enabled", color: .green, style: .tag)
                StatusBadge("Disabled", color: .secondary, style: .tag)
                StatusBadge.aiTable()
            }
        }

        Group {
            Text("Dot Style")
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                StatusBadge.running()
                StatusBadge.stopped()
                StatusBadge.error("Connection failed")
            }
        }
    }
    .padding()
}
