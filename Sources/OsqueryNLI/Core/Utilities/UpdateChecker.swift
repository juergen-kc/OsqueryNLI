import Foundation
import AppKit

/// Checks GitHub releases for app updates
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let githubRepo = "juergen-kc/OsqueryNLI"
    private let lastCheckKey = "lastUpdateCheck"
    private let skipVersionKey = "skipUpdateVersion"
    private let checkInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {}

    /// Check for updates (respects 24-hour cooldown)
    func checkForUpdatesIfNeeded() {
        // Check cooldown
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date().timeIntervalSince1970
        guard now - lastCheck > checkInterval else { return }

        Task {
            await checkForUpdates(silent: true)
        }
    }

    /// Force check for updates (ignores cooldown)
    func checkForUpdatesNow() {
        Task {
            await checkForUpdates(silent: false)
        }
    }

    private func checkForUpdates(silent: Bool) async {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

        guard let latestVersion = await fetchLatestVersion() else {
            if !silent {
                showNoUpdateAlert()
            }
            return
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        if isVersion(latestVersion, newerThan: currentVersion) {
            // Check if user chose to skip this version
            let skippedVersion = UserDefaults.standard.string(forKey: skipVersionKey)
            if silent && skippedVersion == latestVersion {
                return
            }
            showUpdateAlert(currentVersion: currentVersion, latestVersion: latestVersion)
        } else if !silent {
            showNoUpdateAlert()
        }
    }

    private func fetchLatestVersion() async -> String? {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                return nil
            }

            // Remove 'v' prefix if present (e.g., "v1.0.1" -> "1.0.1")
            return tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        } catch {
            return nil
        }
    }

    private func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let v1Parts = v1.split(separator: ".").compactMap { Int($0) }
        let v2Parts = v2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1Parts.count, v2Parts.count) {
            let p1 = i < v1Parts.count ? v1Parts[i] : 0
            let p2 = i < v2Parts.count ? v2Parts[i] : 0

            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }

    private func showUpdateAlert(currentVersion: String, latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of Osquery NLI is available.\n\nCurrent: v\(currentVersion)\nLatest: v\(latestVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Download
            if let url = URL(string: "https://github.com/\(githubRepo)/releases/latest") {
                NSWorkspace.shared.open(url)
            }
        case .alertThirdButtonReturn:
            // Skip this version
            UserDefaults.standard.set(latestVersion, forKey: skipVersionKey)
        default:
            break
        }
    }

    private func showNoUpdateAlert() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        let alert = NSAlert()
        alert.messageText = "No Updates Available"
        alert.informativeText = "You're running the latest version (v\(currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
