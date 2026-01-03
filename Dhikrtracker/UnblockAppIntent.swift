//
//  UnblockAppIntent.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import AppIntents
import WidgetKit
import ManagedSettings
import Foundation

struct UnblockAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Unblock Apps"
    static var description = IntentDescription("Unblocks apps after the 5-minute waiting period.")
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return .result()
        }

        // SECURITY: Check if strict mode is enabled
        let isStrictMode = groupDefaults.bool(forKey: "focusStrictMode")
        if isStrictMode {
            // In strict mode, widgets cannot unblock - user must open app and use voice confirmation
            return .result()
        }

        // 1. Verify Unblock Availability
        let now = Date()
        guard let availableAtTimestamp = groupDefaults.object(forKey: "earlyUnlockAvailableAt") as? TimeInterval else {
            // Not in a blocking session or early unlock not set
            return .result()
        }

        let availableAt = Date(timeIntervalSince1970: availableAtTimestamp)

        if now < availableAt {
            // Still waiting
            return .result()
        }

        // 2. Execute Unblock (Early Unlock Logic)

        // Clear ManagedSettings (requires Family Controls entitlement)
        let store = ManagedSettingsStore()
        store.clearAllSettings()

        // Update App Group state to reflect unblocking
        if let blockingEndTimeTimestamp = groupDefaults.object(forKey: "blockingEndTime") as? TimeInterval {
            // Set early unlock until the scheduled end time
            groupDefaults.set(blockingEndTimeTimestamp, forKey: "earlyUnlockedUntil")
            groupDefaults.set(false, forKey: "appsActuallyBlocked")

            // Clear blocking start time to signal end of active blocking phase
            groupDefaults.removeObject(forKey: "blockingStartTime")

            // Also clear the availability timestamp so the widget resets
            groupDefaults.removeObject(forKey: "earlyUnlockAvailableAt")

        }

        // 3. Refresh Widget
        return .result()
    }
}
