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

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let now = Date()

        // Parse prayer name and timestamp from activity name (format: "Prayer_<Name>_<Timestamp>")
        let prayerName = extractPrayerName(from: activity.rawValue)
        let prayerTimestamp = extractPrayerTimestamp(from: activity.rawValue)

        // 1. Get the selection to apply
        // The Scheduler has already verified Premium status and Prayer Selection.
        // We just execute the order.
        let selection = AppSelectionModel.getCurrentSelection()

        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
            return
        }

        // 2. Apply the restrictions
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens


        // 3. Update State for Main App
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

        // Check if strict mode is enabled via App Group UserDefaults
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false

        if strictMode {
            // In strict mode, keep restrictions active until voice confirmation
            groupDefaults?.set(true, forKey: "isWaitingForVoiceConfirmation")
            groupDefaults?.synchronize()
        } else {
            // In normal mode, clear restrictions immediately
            store.clearAllSettings()
            groupDefaults?.set(false, forKey: "appsActuallyBlocked")
            groupDefaults?.removeObject(forKey: "currentPrayerName")
            groupDefaults?.removeObject(forKey: "currentPrayerTime")
            groupDefaults?.removeObject(forKey: "blockingStartTime")
            groupDefaults?.removeObject(forKey: "earlyUnlockAvailableAt")
            groupDefaults?.synchronize()
        }
    }
}
