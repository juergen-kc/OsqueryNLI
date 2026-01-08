import SwiftUI
import AppKit

/// View shown when osquery is not installed
struct OsqueryMissingView: View {
    @StateObject private var installer = OsqueryInstaller.shared
    @State private var installSuccess = false
    @State private var isChecking = false
    @State private var copiedCommand = false

    var onInstalled: (() -> Void)

    private let brewCommand = "brew install osquery"

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            // Title
            Text("osquery Not Found")
                .font(.title2.bold())

            // Description
            Text("osquery is required to query your system.\nIt's a free, open-source tool for system analytics.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            if installSuccess {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("osquery installed successfully!")
                        .font(.headline)
                    Button("Continue") {
                        onInstalled()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                // Installation options
                VStack(spacing: 20) {
                    // Option 1: Copy command for Terminal
                    VStack(spacing: 8) {
                        Text("Option 1: Install via Terminal")
                            .font(.headline)

                        HStack {
                            Text(brewCommand)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.black.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Button {
                                copyCommand()
                            } label: {
                                Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                        }

                        Text(copiedCommand ? "Copied! Paste in Terminal and enter your password." : "Copy and paste into Terminal.app")
                            .font(.caption)
                            .foregroundStyle(copiedCommand ? .green : .secondary)

                        Button("Open Terminal") {
                            openTerminal()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    // Option 2: Download manually
                    VStack(spacing: 8) {
                        Text("Option 2: Download Installer")
                            .font(.headline)

                        Button {
                            installer.openDownloadPage()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.circle")
                                Text("Download from osquery.io")
                            }
                            .frame(width: 220)
                        }
                        .buttonStyle(.bordered)

                        Text("Download and run the .pkg installer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()

            // Refresh button
            Button {
                checkAgain()
            } label: {
                HStack {
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(isChecking ? "Checking..." : "Check Again")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isChecking)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(brewCommand, forType: .string)
        copiedCommand = true

        // Reset after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            copiedCommand = false
        }
    }

    private func openTerminal() {
        if let url = URL(string: "x-apple.terminal:") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open Terminal.app directly
            let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open(terminalURL)
        }
    }

    private func checkAgain() {
        isChecking = true
        Task {
            let available = await installer.isOsqueryInstalled()
            isChecking = false
            if available {
                installSuccess = true
                // Give user a moment to see success, then callback
                try? await Task.sleep(for: .seconds(1))
                onInstalled()
            }
        }
    }
}
