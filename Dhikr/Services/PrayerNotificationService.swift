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
    private let prayerReminderIdentifierPrefix = "prayer_time_reminder_"

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
            // Request time-sensitive authorization for prayer reminders
            var options: UNAuthorizationOptions = [.alert, .sound, .badge]
            if #available(iOS 15.0, *) {
                options.insert(.timeSensitive)
            }
            let granted = try await notificationCenter.requestAuthorization(
                options: options
            )

            await MainActor.run {
                self.hasNotificationPermission = granted
                self.isNotificationPermissionDenied = !granted
                self.isRequestingPermission = false
            }

            // Track notification enabled
            if granted {
                AnalyticsService.shared.trackNotificationEnabled()
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

        // Get location for notification
        let cityName = getSavedCityName()

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

            // Format prayer time
            let timeString = formatPrayerTime(prayer.date)
            let emoji = iconForPrayer(prayer.name)

            // Create notification content
            let content = UNMutableNotificationContent()

            // Title format: "Fajr at 5:30 AM (Minneapolis)" or without city if not available
            if !cityName.isEmpty {
                content.title = "\(prayer.name) at \(timeString) (\(cityName)) \(emoji)"
            } else {
                content.title = "\(prayer.name) at \(timeString) \(emoji)"
            }

            // Body: Focus mode warning with timing
            if bufferMinutes > 0 {
                let totalMinutes = Int(bufferMinutes) + minutesBefore
                content.body = "Focus mode starts in \(minutesBefore) min. Prepare for prayer in \(totalMinutes) min."
            } else {
                content.body = "Focus mode starting in \(minutesBefore) min. Prepare your heart for prayer."
            }
            content.sound = .default
            content.badge = 1

            // Set time-sensitive interruption level (iOS 15+)
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

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

    // MARK: - Individual Prayer Reminders

    /// Schedule a reminder notification for a specific prayer
    /// - Parameters:
    ///   - prayerName: Name of the prayer (e.g., "Fajr", "Dhuhr")
    ///   - prayerTime: The time of the prayer
    ///   - minutesBefore: How many minutes before the prayer to send the reminder (default: 0 = at prayer time)
    func schedulePrayerReminder(
        prayerName: String,
        prayerTime: Date,
        minutesBefore: Int = 0
    ) {
        guard hasNotificationPermission else {
            print("⚠️ [PrayerReminder] No notification permission")
            return
        }

        let now = Date()
        let reminderTime = prayerTime.addingTimeInterval(-TimeInterval(minutesBefore * 60))

        // Skip if reminder time is in the past
        guard reminderTime > now else {
            print("⚠️ [PrayerReminder] Reminder time is in the past for \(prayerName)")
            return
        }

        // Create unique identifier based on prayer name and date
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: prayerTime)
        let identifier = "\(prayerReminderIdentifierPrefix)\(prayerName)_\(dayComponents.year ?? 0)_\(dayComponents.month ?? 0)_\(dayComponents.day ?? 0)"

        // Get location and format time
        let cityName = getSavedCityName()
        let timeString = formatPrayerTime(prayerTime)
        let emoji = iconForPrayer(prayerName)
        let quote = getQuoteForPrayer(prayerName)

        // Create notification content with rich formatting like Muslim Pro
        let content = UNMutableNotificationContent()

        // Title format: "Fajr at 5:30 AM (Minneapolis)" or "Fajr at 5:30 AM" if no city
        if !cityName.isEmpty {
            content.title = "\(prayerName) at \(timeString) (\(cityName))"
        } else {
            content.title = "\(prayerName) at \(timeString)"
        }

        // Body: Hadith quote with emoji
        content.body = "\(quote) \(emoji)"
        content.sound = .default
        content.categoryIdentifier = "PRAYER_REMINDER"

        // Set time-sensitive interruption level (iOS 15+)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Create trigger
        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
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
                print("❌ [PrayerReminder] Failed to schedule \(prayerName): \(error)")
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                print("✅ [PrayerReminder] Scheduled \(prayerName) notification for \(formatter.string(from: prayerTime))")
            }
        }
    }

    /// Cancel reminder for a specific prayer
    func cancelPrayerReminder(prayerName: String, prayerTime: Date) {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: prayerTime)
        let identifier = "\(prayerReminderIdentifierPrefix)\(prayerName)_\(dayComponents.year ?? 0)_\(dayComponents.month ?? 0)_\(dayComponents.day ?? 0)"

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🔕 [PrayerReminder] Cancelled reminder for \(prayerName)")
    }

    /// Schedule reminders for all prayers with reminders enabled
    func scheduleAllPrayerReminders(prayers: [(name: String, time: Date, hasReminder: Bool)], minutesBefore: Int = 0) {
        guard hasNotificationPermission else {
            print("⚠️ [PrayerReminder] No notification permission - requesting...")
            return
        }

        // Clear existing prayer time reminders first
        clearPrayerTimeReminders()

        let now = Date()
        var scheduledCount = 0

        for prayer in prayers {
            guard prayer.hasReminder else { continue }
            guard prayer.time > now else { continue }

            schedulePrayerReminder(
                prayerName: prayer.name,
                prayerTime: prayer.time,
                minutesBefore: minutesBefore
            )
            scheduledCount += 1
        }

        print("📅 [PrayerReminder] Scheduled \(scheduledCount) prayer reminders")
    }

    /// Clear all prayer time reminders (not focus mode reminders)
    func clearPrayerTimeReminders() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let prayerReminderRequests = requests.filter {
                $0.identifier.hasPrefix(self?.prayerReminderIdentifierPrefix ?? "")
            }

            let identifiersToRemove = prayerReminderRequests.map { $0.identifier }

            if !identifiersToRemove.isEmpty {
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                print("🧹 [PrayerReminder] Cleared \(identifiersToRemove.count) prayer reminders")
            }
        }
    }

    // MARK: - Multi-Day Prayer Reminder Scheduling

    /// Schedule prayer reminders for the next 7 days using stored prayer times
    /// This should be called on app launch, app becoming active, and from background refresh
    func scheduleWeeklyPrayerReminders() {
        guard hasNotificationPermission else {
            print("⚠️ [PrayerReminder] No notification permission for weekly scheduling")
            return
        }

        // Check if reminders are enabled
        let prayerRemindersEnabled = UserDefaults.standard.bool(forKey: "prayerRemindersEnabled")
        guard prayerRemindersEnabled else {
            print("📅 [PrayerReminder] Prayer reminders disabled - skipping weekly schedule")
            return
        }

        // Load stored prayer times
        let prayerTimeService = PrayerTimeService()
        guard let storage = prayerTimeService.loadStorage(), !storage.prayerTimes.isEmpty else {
            print("⚠️ [PrayerReminder] No stored prayer times for weekly scheduling")
            return
        }

        // Clear existing reminders first
        clearPrayerTimeReminders()

        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        var scheduledCount = 0
        let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

        // Schedule for next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: targetDate)

            // Find stored prayer time for this date
            guard let storedPrayer = storage.prayerTimes.first(where: {
                calendar.isDate($0.date, inSameDayAs: startOfDay)
            }) else { continue }

            // Get reminder settings for each prayer
            for prayerName in prayerNames {
                // Check if this prayer has reminder enabled
                let hasReminder = UserDefaults.standard.bool(forKey: "reminder_\(prayerName)")
                guard hasReminder else { continue }

                // Get prayer time string
                let timeString: String
                switch prayerName {
                case "Fajr": timeString = storedPrayer.fajr
                case "Dhuhr": timeString = storedPrayer.dhuhr
                case "Asr": timeString = storedPrayer.asr
                case "Maghrib": timeString = storedPrayer.maghrib
                case "Isha": timeString = storedPrayer.isha
                default: continue
                }

                // Parse time and create full date
                let cleanTimeString = timeString.components(separatedBy: " ")[0]
                guard let time = formatter.date(from: cleanTimeString) else { continue }

                var components = calendar.dateComponents([.hour, .minute], from: time)
                components.year = calendar.component(.year, from: targetDate)
                components.month = calendar.component(.month, from: targetDate)
                components.day = calendar.component(.day, from: targetDate)

                guard let prayerDate = calendar.date(from: components) else { continue }

                // Skip if in the past
                guard prayerDate > now else { continue }

                // Schedule the notification
                schedulePrayerReminder(prayerName: prayerName, prayerTime: prayerDate, minutesBefore: 0)
                scheduledCount += 1

                // iOS limit is 64 pending notifications - stay well under
                if scheduledCount >= 50 {
                    print("📅 [PrayerReminder] Reached scheduling limit of 50")
                    return
                }
            }
        }

        print("📅 [PrayerReminder] Scheduled \(scheduledCount) prayer reminders for next 7 days")
    }

    // MARK: - Icon for Prayer Names

    private func iconForPrayer(_ prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "🌅"
        case "Dhuhr": return "☀️"
        case "Asr": return "🌤️"
        case "Maghrib": return "🌇"
        case "Isha": return "🌙"
        default: return "🕌"
        }
    }

    // MARK: - Hadith & Islamic Quotes for Each Prayer

    private func getQuoteForPrayer(_ prayerName: String) -> String {
        let fajrQuotes = [
            "\"Whoever prays Fajr is under Allah's protection.\" (Muslim)",
            "\"The two Rak'ahs of Fajr are better than the world and all it contains.\" (Muslim)",
            "\"Whoever prays the two cool prayers (Fajr & Asr) will enter Paradise.\" (Bukhari)",
            "\"Angels take turns among you by night and by day.\" (Bukhari)",
            "\"The most burdensome prayers for the hypocrites are Isha and Fajr.\" (Bukhari)"
        ]

        let dhuhrQuotes = [
            "\"The best of deeds is prayer at its proper time.\" (Bukhari)",
            "\"Between a man and disbelief is abandoning prayer.\" (Muslim)",
            "\"Prayer is the pillar of the religion.\" (Tirmidhi)",
            "\"The first matter to be judged on the Day of Resurrection will be prayer.\" (Nasa'i)",
            "\"Pray as you have seen me praying.\" (Bukhari)"
        ]

        let asrQuotes = [
            "\"Whoever misses Asr prayer, it is as if he lost his family and property.\" (Bukhari)",
            "\"Whoever prays the two cool prayers (Fajr & Asr) will enter Paradise.\" (Bukhari)",
            "\"Guard strictly the prayers, especially the middle prayer.\" (Quran 2:238)",
            "\"The angels of night and day meet at Asr prayer.\" (Bukhari)",
            "\"Do not miss Asr prayer intentionally.\" (Bukhari)"
        ]

        let maghribQuotes = [
            "\"Pray Maghrib when the sun sets.\" (Bukhari)",
            "\"Hasten to break your fast and delay your Suhur.\" (Tirmidhi)",
            "\"The supplication at the time of breaking fast is not rejected.\" (Ibn Majah)",
            "\"Whoever feeds a fasting person will have a reward like his.\" (Tirmidhi)",
            "\"Between each Adhan and Iqamah there is a prayer.\" (Bukhari)"
        ]

        let ishaQuotes = [
            "\"Those who go to the masjid at night will have perfect light on the Day of Judgement.\" (Tabarani)",
            "\"Whoever prays Isha in congregation, it is as if he prayed half the night.\" (Muslim)",
            "\"The best prayer after the obligatory is the night prayer.\" (Muslim)",
            "\"Our Lord descends every night to the lowest heaven.\" (Bukhari)",
            "\"End your day strong; pray & track for consistency.\" 🌙"
        ]

        let quotes: [String]
        switch prayerName {
        case "Fajr": quotes = fajrQuotes
        case "Dhuhr": quotes = dhuhrQuotes
        case "Asr": quotes = asrQuotes
        case "Maghrib": quotes = maghribQuotes
        case "Isha": quotes = ishaQuotes
        default: quotes = dhuhrQuotes
        }

        return quotes.randomElement() ?? quotes[0]
    }

    // MARK: - Location Helper

    private func getSavedCityName() -> String {
        if let city = UserDefaults.standard.string(forKey: "savedCity"), !city.isEmpty {
            return city
        }
        return ""
    }

    // MARK: - Time Formatting

    private func formatPrayerTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}