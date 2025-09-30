//
//  PrayerNotificationService.swift
//  Dhikr
//
//  Created for Prayer Time App Blocking
//

import Foundation
import UserNotifications
import UIKit

class PrayerNotificationService: ObservableObject {
    static let shared = PrayerNotificationService()

    @Published var hasNotificationPermission = false
    @Published var isRequestingPermission = false

    private let notificationCenter = UNUserNotificationCenter.current()
    private let prePrayerIdentifierPrefix = "prayer_reminder_"

    private init() {
        checkPermissionStatus()
    }

    // MARK: - Permission Management

    func checkPermissionStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasNotificationPermission = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestNotificationPermission() async -> Bool {
        guard !isRequestingPermission else { return hasNotificationPermission }

        await MainActor.run {
            isRequestingPermission = true
        }

        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await MainActor.run {
                self.hasNotificationPermission = granted
                self.isRequestingPermission = false
            }

            if granted {
                print("✅ [Notifications] Permission granted")
            } else {
                print("❌ [Notifications] Permission denied")
            }

            return granted
        } catch {
            print("❌ [Notifications] Permission request failed: \(error)")
            await MainActor.run {
                self.isRequestingPermission = false
            }
            return false
        }
    }

    // MARK: - Notification Scheduling

    func schedulePrePrayerNotifications(
        prayerTimes: [PrayerTime],
        selectedPrayers: Set<String>,
        isEnabled: Bool,
        minutesBefore: Int = 5
    ) {
        guard isEnabled && hasNotificationPermission else {
            print("📱 [Notifications] Skipping - notifications disabled or no permission")
            return
        }

        // Clear existing pre-prayer notifications
        clearPrePrayerNotifications()

        let now = Date()
        let futurePrayers = prayerTimes.filter { prayer in
            prayer.date > now && selectedPrayers.contains(prayer.name)
        }

        guard !futurePrayers.isEmpty else {
            print("📱 [Notifications] No future prayers to schedule notifications for")
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var scheduledCount = 0

        for prayer in futurePrayers {
            let reminderTime = prayer.date.addingTimeInterval(-TimeInterval(minutesBefore * 60))

            // Skip if reminder time is in the past
            guard reminderTime > now else { continue }

            let identifier = "\(prePrayerIdentifierPrefix)\(prayer.name)_\(Int(prayer.date.timeIntervalSince1970))"

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Prayer Time Approaching"
            content.body = "\(prayer.name) prayer starts in \(minutesBefore) minutes. Your apps will be blocked soon."
            content.sound = .default
            content.badge = 1

            // Create trigger
            let triggerComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminderTime
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: triggerComponents,
                repeats: false
            )

            // Create request
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            // Schedule notification
            notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ [Notifications] Failed to schedule \(prayer.name) reminder: \(error)")
                } else {
                    print("📅 [Notifications] Scheduled \(prayer.name) reminder for \(formatter.string(from: reminderTime))")
                }
            }

            scheduledCount += 1

            // Limit to prevent too many notifications
            if scheduledCount >= 20 {
                break
            }
        }

        print("📱 [Notifications] Scheduled \(scheduledCount) pre-prayer reminders")
    }

    func clearPrePrayerNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let prePrayerRequests = requests.filter {
                $0.identifier.hasPrefix(self?.prePrayerIdentifierPrefix ?? "")
            }

            let identifiersToRemove = prePrayerRequests.map { $0.identifier }

            if !identifiersToRemove.isEmpty {
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("🗑️ [Notifications] Cleared \(identifiersToRemove.count) pending pre-prayer notifications")
            }
        }
    }

    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("🗑️ [Notifications] Cleared all pending notifications")
    }

    // MARK: - Helper Methods

    func getPendingNotificationCount() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        let prePrayerCount = requests.filter {
            $0.identifier.hasPrefix(prePrayerIdentifierPrefix)
        }.count
        return prePrayerCount
    }

    func getNotificationStatus() async -> String {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Icon for Prayer Names

    private func iconForPrayer(_ prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "🌅"
        case "Dhuhr": return "☀️"
        case "Asr": return "🌤️"
        case "Maghrib": return "🌅"
        case "Isha": return "🌙"
        default: return "🕌"
        }
    }
}