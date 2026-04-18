import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Permission Request
    func requestPermission() async -> Bool {
        log("🔔 Requesting notification permission...")
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            log(granted ? "✅ Notification permission granted" : "❌ Notification permission denied")
            return granted
        } catch {
            log("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - Schedule Daily Reading Goal Notification
    func scheduleDailyReadingGoalNotification(goalMinutes: Int) async {
        log("🔔 Scheduling daily reading goal notification for \(goalMinutes) minutes")
        
        let center = UNUserNotificationCenter.current()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Daily Reading Reminder"
        content.body = "Time for your daily reading! Your goal is \(goalMinutes) minutes today."
        content.sound = .default
        content.badge = 1
        
        // Create trigger for 9:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "daily_reading_goal",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await center.add(request)
            log("✅ Daily reading goal notification scheduled for 9:00 AM")
        } catch {
            log("❌ Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Cancel Daily Reading Goal Notification
    func cancelDailyReadingGoalNotification() {
        log("🔔 Canceling daily reading goal notification")
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reading_goal"])
        log("✅ Daily reading goal notification canceled")
    }
    
    // MARK: - Update Notification Based on Settings
    func updateDailyReadingGoalNotification(enabled: Bool, goalMinutes: Int) async {
        if enabled {
            let permissionGranted = await requestPermission()
            if permissionGranted {
                await scheduleDailyReadingGoalNotification(goalMinutes: goalMinutes)
            }
        } else {
            cancelDailyReadingGoalNotification()
        }
    }
    
    // MARK: - Clear Notification Badge and Delivered Notifications
    func clearNotificationBadgeAndDelivered() {
        log("🔔 Clearing notification badge and delivered notifications")
        let center = UNUserNotificationCenter.current()
        
        // Clear the app icon badge count
        center.setBadgeCount(0) { error in
            if let error = error {
                log("❌ Failed to clear badge count: \(error.localizedDescription)")
            } else {
                log("✅ Badge count cleared successfully")
            }
        }
        
        // Remove all delivered notifications from notification center
        center.removeAllDeliveredNotifications()
        log("✅ All delivered notifications removed")
    }

    // MARK: - Setup Notifications on App Launch
    func setupNotificationsOnLaunch() {
        let goalNotificationsEnabled = UserDefaults.standard.bool(forKey: "goal_notifications")
        let dailyReadingGoal = UserDefaults.standard.integer(forKey: "daily_reading_goal")
        let goal = dailyReadingGoal == 0 ? 10 : dailyReadingGoal // Default to 10 if not set
        
        if goalNotificationsEnabled {
            Task {
                await scheduleDailyReadingGoalNotification(goalMinutes: goal)
            }
        }
    }
}
