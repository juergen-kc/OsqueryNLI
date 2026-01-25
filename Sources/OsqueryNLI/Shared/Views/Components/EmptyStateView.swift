import SwiftUI

/// Standardized empty state view for lists and content areas
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppLayout.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: AppLayout.Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppLayout.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var description = title
        if let message = message {
            description += ". \(message)"
        }
        if let actionTitle = actionTitle {
            description += ". \(actionTitle) button available."
        }
        return description
    }
}

// MARK: - Convenience Factory Methods

extension EmptyStateView {
    /// Empty state for history view
    static var noHistory: EmptyStateView {
        EmptyStateView(
            icon: "clock.badge.questionmark",
            title: "No History Yet",
            message: "Your queries will appear here"
        )
    }

    /// Empty state for favorites view
    static var noFavorites: EmptyStateView {
        EmptyStateView(
            icon: "star.slash",
            title: "No Favorites",
            message: "Star queries to save them here"
        )
    }

    /// Empty state for search results
    static func noSearchResults(query: String) -> EmptyStateView {
        EmptyStateView(
            icon: "doc.text.magnifyingglass",
            title: "No Results",
            message: "No items match \"\(query)\""
        )
    }

    /// Empty state for query results
    static var noQueryResults: EmptyStateView {
        EmptyStateView(
            icon: "tray",
            title: "No Results",
            message: "Query returned no data"
        )
    }

    /// Empty state for initial query view
    static func queryPrompt(onBrowseTemplates: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "bubble.left.and.text.bubble.right",
            title: "Ask a question about your system",
            message: "Type a natural language query or browse templates",
            actionTitle: "Browse Templates",
            action: onBrowseTemplates
        )
    }
}

#Preview {
    VStack {
        EmptyStateView.noHistory
            .frame(height: 200)

        Divider()

        EmptyStateView.noSearchResults(query: "test")
            .frame(height: 200)

        Divider()

        EmptyStateView.queryPrompt { }
            .frame(height: 250)
    }
    .padding()
}
