//
//  BackgroundRefreshService.swift
//  Dhikr
//
//  Prayer Time Background Refresh Service
//

import Foundation
import UIKit
import CoreLocation
import BackgroundTasks
import FirebaseMessaging
import FirebaseFunctions

@MainActor
class BackgroundRefreshService: NSObject, ObservableObject {
    static let shared = BackgroundRefreshService()

    private let prayerTimeService = PrayerTimeService()
    private let backgroundTaskIdentifier = "fm.mrc.Dhikr.prayerTimeRefresh"

    @Published var lastRefreshDate: Date?
    @Published var nextScheduledRefresh: Date?

    private override init() {
        super.init()
        registerBackgroundTasks()
    }

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }

    }

    // MARK: - Schedule Background Refresh

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)

        // Schedule for 6 hours from now (matching FCM interval)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
            nextScheduledRefresh = request.earliestBeginDate
        } catch {
        }
    }

    // MARK: - Handle Background Refresh

    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {

        // Schedule next refresh
        scheduleBackgroundRefresh()

        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        do {
            // Perform refresh
            let success = await performPrayerTimeRefresh(reason: "Background Task")
            task.setTaskCompleted(success: success)

            if success {
                lastRefreshDate = Date()
            } else {
            }
        }
    }

    // MARK: - Perform Rolling Window Refresh (NO prayer time fetching)

    func performPrayerTimeRefresh(reason: String) async -> Bool {

        // Load existing storage
        guard let storage = prayerTimeService.loadStorage() else {
            return false
        }

        // Check if storage is expired or invalid
        if storage.shouldRefresh {
            return false
        }

        // Storage is valid - update rolling window only
        return await updateRollingWindowIfNeeded(storage: storage)
    }

    // MARK: - Update Rolling Window

    private func updateRollingWindowIfNeeded(storage: PrayerTimeStorage) async -> Bool {

        guard DeviceActivityService.shared.needsRollingWindowUpdate() else {
            return true
        }


        // Get current settings
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let duration = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? 15.0

        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }

        // Update rolling window
        DeviceActivityService.shared.updateRollingWindow(
            from: storage,
            duration: duration,
            selectedPrayers: selectedPrayers
        )

        // Update prayer notifications if enabled
        await updatePrayerNotifications(storage: storage, selectedPrayers: selectedPrayers)

        return true
    }

    // MARK: - Update Prayer Notifications

    private func updatePrayerNotifications(storage: PrayerTimeStorage, selectedPrayers: Set<String>) async {
        // Check if prayer reminders are enabled
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let prayerRemindersEnabled = groupDefaults?.bool(forKey: "prayerRemindersEnabled") ?? UserDefaults.standard.bool(forKey: "prayerRemindersEnabled")

        guard prayerRemindersEnabled else {
            return
        }


        // Build prayer times from storage for next 4 days
        let calendar = Calendar.current
        let now = Date()
        var prayerTimes: [PrayerTime] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Helper to create PrayerTime
        func createPrayerTime(name: String, timeString: String, date: Date) -> PrayerTime? {
            let cleanTimeString = timeString.components(separatedBy: " ")[0]
            guard let time = formatter.date(from: cleanTimeString) else { return nil }

            var components = calendar.dateComponents([.hour, .minute], from: time)
            components.year = calendar.component(.year, from: date)
            components.month = calendar.component(.month, from: date)
            components.day = calendar.component(.day, from: date)

            guard let prayerDate = calendar.date(from: components) else { return nil }
            return PrayerTime(name: name, date: prayerDate)
        }

        // Get prayer times from storage for next 4 days
        for dayOffset in 0..<4 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: targetDate)

            // Find the stored prayer time for this date
            guard let storedPrayer = storage.prayerTimes.first(where: {
                calendar.isDate($0.date, inSameDayAs: startOfDay)
            }) else { continue }

            // Add all 5 prayers for this day
            if let fajr = createPrayerTime(name: "Fajr", timeString: storedPrayer.fajr, date: targetDate) {
                prayerTimes.append(fajr)
            }
            if let dhuhr = createPrayerTime(name: "Dhuhr", timeString: storedPrayer.dhuhr, date: targetDate) {
                prayerTimes.append(dhuhr)
            }
            if let asr = createPrayerTime(name: "Asr", timeString: storedPrayer.asr, date: targetDate) {
                prayerTimes.append(asr)
            }
            if let maghrib = createPrayerTime(name: "Maghrib", timeString: storedPrayer.maghrib, date: targetDate) {
                prayerTimes.append(maghrib)
            }
            if let isha = createPrayerTime(name: "Isha", timeString: storedPrayer.isha, date: targetDate) {
                prayerTimes.append(isha)
            }
        }

        // Schedule notifications only for selected prayers
        PrayerNotificationService.shared.schedulePrePrayerNotifications(
            prayerTimes: prayerTimes,
            selectedPrayers: selectedPrayers,
            isEnabled: true,
            minutesBefore: 5
        )

    }

    // MARK: - Manual Refresh (called from UI or FCM)

    func triggerManualRefresh(reason: String = "Manual") async {
        let success = await performPrayerTimeRefresh(reason: reason)

        if success {
            lastRefreshDate = Date()
        } else {
        }
    }
}

// MARK: - Firebase Cloud Messaging Extension

extension BackgroundRefreshService: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

        // Store FCM token for local use
        if let token = fcmToken, let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(token, forKey: "fcmToken")
            groupDefaults.synchronize()

            // Save to Firestore for Cloud Functions to use
            Task {
                await self.saveFCMTokenToFirestore(token: token)
            }
        }
    }

    /// Save FCM token to Firestore for Cloud Functions
    private func saveFCMTokenToFirestore(token: String) async {

        let functions = Functions.functions()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let userId = AuthenticationService.shared.currentUser?.id

        do {
            let result = try await functions.httpsCallable("saveFCMToken").call([
                "token": token,
                "userId": userId ?? "",
                "appVersion": appVersion ?? "unknown"
            ])

            if let data = result.data as? [String: Any], let success = data["success"] as? Bool, success {
            } else {
            }
        } catch {
        }
    }
}

// MARK: - Silent Notification Handler

extension BackgroundRefreshService {

    func handleSilentNotification(userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {

        // Check if it's a prayer time refresh notification
        if let refreshType = userInfo["refreshType"] as? String, refreshType == "prayerTimeUpdate" {

            let success = await performPrayerTimeRefresh(reason: "Silent Notification")

            return success ? .newData : .failed
        }

        return .noData
    }
}
