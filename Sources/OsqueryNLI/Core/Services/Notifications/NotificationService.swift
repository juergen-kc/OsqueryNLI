import Foundation
import UserNotifications

/// Service for managing macOS notifications
final class NotificationService: NSObject, @unchecked Sendable {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    /// Callback when user taps "View Results" on a notification
    var onViewResults: ((UUID) -> Void)?

    private override init() {
        super.init()
        notificationCenter.delegate = self
        setupNotificationCategories()
    }

    /// Request permission to send notifications
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Check current notification authorization status
    func checkPermission() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    /// Send an alert notification for a scheduled query
    func sendAlertNotification(
        queryName: String,
        message: String,
        queryId: UUID
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Osquery Alert: \(queryName)"
        content.body = message
        content.sound = .default
        content.userInfo = ["queryId": queryId.uuidString]
        content.categoryIdentifier = "SCHEDULED_QUERY_ALERT"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    /// Set up notification action categories
    private func setupNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_RESULTS",
            title: "View Results",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "SCHEDULED_QUERY_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    /// Remove all pending notifications
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Remove all delivered notifications
    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == "VIEW_RESULTS" || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let queryIdString = userInfo["queryId"] as? String,
               let queryId = UUID(uuidString: queryIdString) {
                Task { @MainActor in
                    onViewResults?(queryId)
                }
            }
        }

        completionHandler()
    }
}
