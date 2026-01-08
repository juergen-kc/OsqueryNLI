import Foundation
import AppKit

/// Handles osquery installation and availability checks
@MainActor
final class OsqueryInstaller: ObservableObject {
    static let shared = OsqueryInstaller()

    @Published var isChecking: Bool = false
    @Published var isInstalling: Bool = false
    @Published var installationError: String?

    /// Check if osquery is installed
    func isOsqueryInstalled() async -> Bool {
        let paths = [
            "/opt/homebrew/bin/osqueryi",
            "/usr/local/bin/osqueryi",
            "/usr/bin/osqueryi"
        ]

        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // Also check PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["osqueryi"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Check if Homebrew is installed
    func isHomebrewInstalled() -> Bool {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// Get the Homebrew executable path
    private func homebrewPath() -> String? {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Install osquery via Homebrew
    func installViaHomebrew() async -> Bool {
        guard let brewPath = homebrewPath() else {
            installationError = "Homebrew not found"
            return false
        }

        isInstalling = true
        installationError = nil

        defer { isInstalling = false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "osquery"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return true
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                installationError = "Installation failed: \(output)"
                return false
            }
        } catch {
            installationError = "Failed to run Homebrew: \(error.localizedDescription)"
            return false
        }
    }

    /// Open the osquery download page
    func openDownloadPage() {
        if let url = URL(string: "https://osquery.io/downloads") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open Homebrew installation page
    func openHomebrewInstallPage() {
        if let url = URL(string: "https://brew.sh") {
            NSWorkspace.shared.open(url)
        }
    }
}
