import SwiftUI

/// A toast view that shows an undo action with a countdown
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)

            Text(message)
                .font(.callout)

            Spacer()

            Button("Undo") {
                onUndo()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(message). Tap Undo to restore.")
    }
}

/// View modifier to add undo toast support
struct UndoToastModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let action = appState.pendingUndo {
                    UndoToast(
                        message: action.message,
                        onUndo: { appState.performUndo() },
                        onDismiss: { appState.dismissUndo() }
                    )
                    .animation(.spring(duration: 0.3), value: appState.pendingUndo != nil)
                }
            }
    }
}

extension View {
    /// Adds an undo toast overlay that shows when there's a pending undo action
    func undoToast() -> some View {
        modifier(UndoToastModifier())
    }
}
