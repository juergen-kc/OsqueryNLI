import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(.bar)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Query Input
                    ShortcutSection(title: "Query Input", icon: "text.cursor") {
                        ShortcutRow(keys: ["⌘", "↩"], description: "Submit query")
                        ShortcutRow(keys: ["⌘", "K"], description: "Clear and start new query")
                        ShortcutRow(keys: ["↑"], description: "Previous query from history")
                        ShortcutRow(keys: ["↓"], description: "Next query from history")
                        ShortcutRow(keys: ["Esc"], description: "Cancel query or exit history")
                    }

                    // Navigation
                    ShortcutSection(title: "Navigation", icon: "arrow.triangle.branch") {
                        ShortcutRow(keys: ["⌘", "N"], description: "New query window")
                        ShortcutRow(keys: ["⌘", "H"], description: "Open history")
                        ShortcutRow(keys: ["⌘", ","], description: "Open settings")
                        ShortcutRow(keys: ["⌘", "?"], description: "Show this help")
                    }

                    // Results
                    ShortcutSection(title: "Results", icon: "tablecells") {
                        ShortcutRow(keys: ["Click header"], description: "Sort by column")
                        ShortcutRow(keys: ["Click again"], description: "Reverse sort")
                        ShortcutRow(keys: ["Click third"], description: "Clear sort")
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Tips", systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)

                        TipRow(icon: "clock.arrow.circlepath", text: "Use the clock icon to access recent queries")
                        TipRow(icon: "rectangle.stack", text: "Browse templates for common query patterns")
                        TipRow(icon: "star.fill", text: "Star queries to add them to favorites")
                        TipRow(icon: "square.and.arrow.up", text: "Export results to JSON, CSV, Markdown, or Excel")
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Shortcut Section

private struct ShortcutSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                content
            }
        }
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let keys: [String]
    let description: String

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { key in
                    KeyCap(key: key)
                }
            }
            .frame(width: 100, alignment: .leading)

            Text(description)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Key Cap

private struct KeyCap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}

// MARK: - Tip Row

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
