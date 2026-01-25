import SwiftUI

/// Unified button component with consistent styling
///
/// Usage:
/// ```swift
/// ActionButton.primary("Submit", icon: "arrow.up") { submitAction() }
/// ActionButton.secondary("Cancel") { cancelAction() }
/// ActionButton.destructive("Delete", icon: "trash") { deleteAction() }
/// ```
@MainActor
enum ActionButton {
    // MARK: - Primary Button

    /// Create a primary action button (borderedProminent style)
    static func primary(
        _ title: String,
        icon: String? = nil,
        size: ControlSize = .regular,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            buttonContent(title: title, icon: icon, isLoading: isLoading, size: size)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(size)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }

    // MARK: - Secondary Button

    /// Create a secondary action button (bordered style)
    static func secondary(
        _ title: String,
        icon: String? = nil,
        size: ControlSize = .regular,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            buttonContent(title: title, icon: icon, isLoading: isLoading, size: size)
        }
        .buttonStyle(.bordered)
        .controlSize(size)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }

    // MARK: - Destructive Button

    /// Create a destructive action button (bordered with red tint)
    static func destructive(
        _ title: String,
        icon: String? = nil,
        size: ControlSize = .regular,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            buttonContent(title: title, icon: icon, isLoading: false, size: size)
        }
        .buttonStyle(.bordered)
        .controlSize(size)
        .tint(.red)
        .accessibilityLabel(title)
    }

    // MARK: - Icon Only Button

    /// Create an icon-only button
    static func icon(
        _ systemName: String,
        size: CGFloat = AppLayout.Icon.medium,
        color: Color = .secondary,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: - Helper

    @ViewBuilder
    private static func buttonContent(
        title: String,
        icon: String?,
        isLoading: Bool,
        size: ControlSize
    ) -> some View {
        HStack(spacing: AppLayout.Spacing.xs) {
            if isLoading {
                ProgressView()
                    .scaleEffect(progressScale(for: size))
                    .frame(width: iconSize(for: size), height: iconSize(for: size))
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: iconSize(for: size)))
            }
            Text(title)
        }
    }

    private static func iconSize(for size: ControlSize) -> CGFloat {
        switch size {
        case .mini, .small:
            return AppLayout.Icon.small
        case .regular:
            return AppLayout.Icon.medium
        case .large, .extraLarge:
            return AppLayout.Icon.large
        @unknown default:
            return AppLayout.Icon.medium
        }
    }

    private static func progressScale(for size: ControlSize) -> CGFloat {
        switch size {
        case .mini:
            return 0.5
        case .small:
            return 0.6
        case .regular:
            return 0.7
        case .large, .extraLarge:
            return 0.8
        @unknown default:
            return 0.7
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ActionButton.primary("Submit", icon: "arrow.up.circle.fill") { }
        ActionButton.secondary("Cancel", icon: "xmark") { }
        ActionButton.destructive("Delete", icon: "trash") { }
        ActionButton.primary("Loading...", isLoading: true) { }
        ActionButton.icon("gear", help: "Settings") { }
    }
    .padding()
}
