//
//  DeviceActivityMonitorExtension.swift
//  PrayerBlockerMonitor
//
//  Created by Performance Optimization
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation
import UserNotifications
import UIKit
import os.log

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    // MARK: - Logging

    /// Log to App Group UserDefaults for debugging (extensions can't use print to console reliably)
    private func log(_ message: String, activity: String? = nil) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())

        let activityPart = activity.map { " [\($0)]" } ?? ""
        let logEntry = "[\(timestamp)]\(activityPart) \(message)"

        // Also log via OSLog for system console
        os_log("%{public}@", log: .default, type: .info, logEntry)

        // Persist to UserDefaults for main app to read
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }

        var logs = groupDefaults.stringArray(forKey: "monitorExtensionLogs") ?? []
        logs.append(logEntry)

        // Keep only last 100 entries
        if logs.count > 100 {
            logs = Array(logs.suffix(100))
        }

        groupDefaults.set(logs, forKey: "monitorExtensionLogs")
        groupDefaults.synchronize()
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let now = Date()
        log("🟢 intervalDidStart called", activity: activity.rawValue)

        // Parse prayer name and timestamp from activity name (format: "Prayer_<Name>_<Timestamp>")
        let prayerName = extractPrayerName(from: activity.rawValue)
        let prayerTimestamp = extractPrayerTimestamp(from: activity.rawValue)

        // 1. Get the selection to apply
        // The Scheduler has already verified Premium status and Prayer Selection.
        // We just execute the order.
        let selection = AppSelectionModel.getCurrentSelection()

        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        let webCount = selection.webDomainTokens.count
        log("📱 App selection: \(appCount) apps, \(catCount) categories, \(webCount) web domains", activity: activity.rawValue)

        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
            log("⚠️ No apps selected - skipping shield application", activity: activity.rawValue)
            return
        }

        // 2. Apply the restrictions
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        log("✅ Shield restrictions applied successfully", activity: activity.rawValue)

        // 3. Apply Haya Mode (adult content filter) if enabled
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let hayaModeEnabled = groupDefaults?.bool(forKey: "focusHayaMode") ?? false
        if hayaModeEnabled {
            store.webContent.blockedByFilter = .auto()
            log("🛡️ Haya Mode: Adult content filter applied", activity: activity.rawValue)
        }

        // 4. Update State for Main App
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(now.timeIntervalSince1970, forKey: "blockingStartTime")
            groupDefaults.set(true, forKey: "appsActuallyBlocked")
            groupDefaults.set(prayerName, forKey: "currentPrayerName")

            // Set actual prayer time for accurate countdown calculations
            // The timestamp in the activity name is the blocking start time (prayer time - buffer)
            // We need to calculate the actual prayer time by adding the buffer back
            if let blockingStartTs = prayerTimestamp {
                let bufferMinutes = groupDefaults.double(forKey: "focusPrePrayerBuffer")
                let prayerTime = blockingStartTs + (bufferMinutes * 60)
                groupDefaults.set(prayerTime, forKey: "currentPrayerTime")

                // Also set early unlock availability (5 min after prayer time)
                let earlyUnlockTime = prayerTime + (5 * 60)
                groupDefaults.set(earlyUnlockTime, forKey: "earlyUnlockAvailableAt")
            }

            // Force a ping to the main app
            let nonce = Int(now.timeIntervalSince1970 * 1000)
            groupDefaults.set(nonce, forKey: "currentlyMonitoredNonce")
            groupDefaults.synchronize()

            log("📝 State saved - prayer: \(prayerName), appsBlocked: true", activity: activity.rawValue)
        }
    }

    private func extractPrayerName(from activityName: String) -> String {
        // Format: "Prayer_<Name>_<Timestamp>"
        let parts = activityName.split(separator: "_")
        if parts.count >= 2 {
            return String(parts[1])
        }
        return "Prayer"
    }

    private func extractPrayerTimestamp(from activityName: String) -> TimeInterval? {
        // Format: "Prayer_<Name>_<Timestamp>"
        let parts = activityName.split(separator: "_")
        if parts.count >= 3, let timestamp = TimeInterval(parts[2]) {
            return timestamp
        }
        return nil
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        log("🔴 intervalDidEnd called", activity: activity.rawValue)

        // Check if strict mode is enabled via App Group UserDefaults
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false

        if strictMode {
            // In strict mode, keep restrictions active until voice confirmation
            log("🔒 Strict mode enabled - waiting for voice confirmation", activity: activity.rawValue)
            groupDefaults?.set(true, forKey: "isWaitingForVoiceConfirmation")
            groupDefaults?.synchronize()
        } else {
            // In normal mode, clear restrictions immediately
            log("🔓 Normal mode - clearing all restrictions", activity: activity.rawValue)

            // Check if Haya Mode is enabled - if so, preserve the web content filter
            let hayaModeEnabled = groupDefaults?.bool(forKey: "focusHayaMode") ?? false

            // Clear app shields
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil

            // Only clear web content filter if Haya Mode is OFF
            if !hayaModeEnabled {
                store.webContent.blockedByFilter = nil
            } else {
                log("🛡️ Haya Mode active - preserving adult content filter", activity: activity.rawValue)
            }

            groupDefaults?.set(false, forKey: "appsActuallyBlocked")
            groupDefaults?.removeObject(forKey: "currentPrayerName")
            groupDefaults?.removeObject(forKey: "currentPrayerTime")
            groupDefaults?.removeObject(forKey: "blockingStartTime")
            groupDefaults?.removeObject(forKey: "earlyUnlockAvailableAt")
            groupDefaults?.synchronize()
            log("✅ All restrictions cleared", activity: activity.rawValue)
        }
    }

    // MARK: - Additional Lifecycle Methods

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        log("⏰ intervalWillStartWarning - activity about to start", activity: activity.rawValue)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        log("⏰ intervalWillEndWarning - activity about to end", activity: activity.rawValue)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("📊 eventDidReachThreshold: \(event.rawValue)", activity: activity.rawValue)
    }
}
