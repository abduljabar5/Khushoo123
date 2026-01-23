//
//  UnblockAppIntent.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import AppIntents
import WidgetKit
import Foundation

struct UnblockAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Unblock Apps"
    static var description = IntentDescription("Opens the app to unlock after the 5-minute waiting period.")

    init() {}

    func perform() async throws -> some IntentResult {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return .result()
        }

        // SECURITY: Check if strict mode is enabled
        let isStrictMode = groupDefaults.bool(forKey: "focusStrictMode")
        if isStrictMode {
            // In strict mode, user must open app and use voice confirmation
            return .result()
        }

        // Check if early unlock is available
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

        // Signal to main app that user wants to unlock
        // Note: Widget extensions cannot clear ManagedSettings; must be done from main app
        groupDefaults.set(true, forKey: "userRequestedEarlyUnlock")
        groupDefaults.set(now.timeIntervalSince1970, forKey: "earlyUnlockRequestTime")
        groupDefaults.synchronize()

        // Refresh widget to show updated state
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
