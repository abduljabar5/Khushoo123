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
    @Published var isNotificationPermissionDenied = false

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
                self?.isNotificationPermissionDenied = settings.authorizationStatus == .denied
            }
        }
    }

    /// Re-check permission status - call this when app becomes active or view appears
    func refreshPermissionStatus() {
        checkPermissionStatus()
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
                self.isNotificationPermissionDenied = !granted
                self.isRequestingPermission = false
            }

            return granted
        } catch {
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
        // Always clear existing notifications first (even if disabled)
        clearPrePrayerNotifications()

        guard isEnabled && hasNotificationPermission else {
            return
        }

        // Read the pre-prayer buffer from settings
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let bufferMinutes = groupDefaults?.double(forKey: "focusPrePrayerBuffer") ?? 0

        let now = Date()
        let futurePrayers = prayerTimes.filter { prayer in
            prayer.date > now && selectedPrayers.contains(prayer.name)
        }

        guard !futurePrayers.isEmpty else {
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var scheduledCount = 0

        for prayer in futurePrayers {
            // Notification should fire before BLOCKING starts (not prayer time)
            // Blocking starts at: prayer.date - bufferMinutes
            // Notification fires at: blocking start - minutesBefore
            // = prayer.date - bufferMinutes - minutesBefore
            let blockingStartTime = prayer.date.addingTimeInterval(-bufferMinutes * 60)
            let reminderTime = blockingStartTime.addingTimeInterval(-TimeInterval(minutesBefore * 60))

            // Skip if reminder time is in the past
            guard reminderTime > now else { continue }

            let identifier = "\(prePrayerIdentifierPrefix)\(prayer.name)_\(Int(prayer.date.timeIntervalSince1970))"

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Focus Mode Starting Soon"
            if bufferMinutes > 0 {
                // With buffer: blocking starts before prayer
                content.body = "\(prayer.name) prayer in \(Int(bufferMinutes) + minutesBefore) min. Focus mode starts in \(minutesBefore) min."
            } else {
                // No buffer: blocking starts at prayer time
                content.body = "\(prayer.name) prayer starts in \(minutesBefore) minutes. Your apps will be blocked soon."
            }
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
                } else {
                }
            }

            scheduledCount += 1

            // Limit to prevent too many notifications
            if scheduledCount >= 20 {
                break
            }
        }

    }

    func clearPrePrayerNotifications() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let prePrayerRequests = requests.filter {
                $0.identifier.hasPrefix(self?.prePrayerIdentifierPrefix ?? "")
            }

            let identifiersToRemove = prePrayerRequests.map { $0.identifier }

            if !identifiersToRemove.isEmpty {
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            }
        }
    }

    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
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