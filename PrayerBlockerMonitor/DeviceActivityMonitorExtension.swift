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

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        let ts = formatter.string(from: now)
        
        // One-time event log retained; reduce verbosity elsewhere if needed
        print("🔔 [\(ts)] Activity started: \(activity.rawValue)")
        
        // Parse activity name (format: "Prayer_<Name>_<UnixTimestamp>") to log the actual scheduled block
        let parts = activity.rawValue.split(separator: "_")
        var prayerName: String? = nil
        if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
            let startDate = Date(timeIntervalSince1970: startTs)
            let startStr = formatter.string(from: startDate)
            let nameStr = String(parts[1])
            prayerName = nameStr
            var endStr = "?"
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
               let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]],
               let match = schedules.first(where: { sched in
                   guard let n = sched["name"] as? String, let ts2 = sched["date"] as? TimeInterval else { return false }
                   return n == nameStr && Int(ts2) == Int(startTs)
               }), let dur = match["duration"] as? Double {
                let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                endStr = formatter.string(from: endDate)
            }
            print("🗓️ [\(ts)] Scheduled block started → prayer=\(nameStr), start=\(startStr), end=\(endStr)")
        } else {
            print("🗓️ [\(ts)] Scheduled block started → activity=\(activity.rawValue)")
        }
        
        // Check if this prayer is actually selected for blocking
        // Skip this check for ManualBlocking (test blocking)
        if let prayerName = prayerName, activity.rawValue != "ManualBlocking" {
            let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
            let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? true
            let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? true
            let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? true
            let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? true
            let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? true
            
            var isPrayerSelected = false
            switch prayerName {
            case "Fajr":
                isPrayerSelected = selectedFajr
            case "Dhuhr":
                isPrayerSelected = selectedDhuhr
            case "Asr":
                isPrayerSelected = selectedAsr
            case "Maghrib":
                isPrayerSelected = selectedMaghrib
            case "Isha":
                isPrayerSelected = selectedIsha
            default:
                isPrayerSelected = false
            }
            
            if !isPrayerSelected {
                print("⏭️ [\(ts)] Prayer \(prayerName) is not selected for blocking, skipping restrictions")
                // Update the monitoring list but don't apply restrictions
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    var activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []
                    if activeNames.count > 30 {
                        activeNames = Array(activeNames.suffix(25))
                    }
                    if !activeNames.contains(activity.rawValue) {
                        activeNames.append(activity.rawValue)
                        groupDefaults.set(activeNames, forKey: "currentlyMonitoredActivityNames")
                    }
                }
                return
            }
            
            print("✅ [\(ts)] Prayer \(prayerName) is selected for blocking, applying restrictions")
        }
        
        // Check what's currently blocked before we apply new restrictions
        let currentlyBlockedApps = store.shield.applications?.count ?? 0
        let currentlyBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let currentlyBlockedDomains = store.shield.webDomains?.count ?? 0
        print("🔍 [\(ts)] Current ManagedSettings BEFORE: apps=\(currentlyBlockedApps), categories=\(currentlyBlockedCategories), domains=\(currentlyBlockedDomains)")
        
        // Cleaner activities no longer used
        
        // Normal prayer blocking activity
        // Use the static method to avoid triggering UI updates on background thread
        let selection = AppSelectionModel.getCurrentSelection()
        
        print("🎯 [\(ts)] Selection to apply (from app settings): apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count), domains=\(selection.webDomainTokens.count)")
        // Log what is ACTUALLY going to be blocked by enumerating tokens we apply
        if !selection.applicationTokens.isEmpty {
            let appTokens = selection.applicationTokens.map { String(describing: $0) }
            print("   ↳ apps tokens: \(appTokens)")
        }
        if !selection.categoryTokens.isEmpty {
            let catTokens = selection.categoryTokens.map { String(describing: $0) }
            print("   ↳ categories tokens: \(catTokens)")
        }
        if !selection.webDomainTokens.isEmpty {
            let domainTokens = selection.webDomainTokens.map { String(describing: $0) }
            print("   ↳ web domains: \(domainTokens)")
        }
        
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
            print("⚠️ [\(ts)] No apps selected for blocking - prayer blocking will not work")
            
            // Send notification to user about missing app selection
            let content = UNMutableNotificationContent()
            content.title = "Dhikr - Setup Required"
            content.body = "No apps selected for blocking. Please select apps in Focus Settings to enable prayer time blocking."
            content.sound = .default
            content.categoryIdentifier = "DHIKR_SETUP"
            
            let request = UNNotificationRequest(
                identifier: "no-apps-selected-\(activity.rawValue)",
                content: content,
                trigger: nil // Deliver immediately
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ [\(ts)] Failed to send notification: \(error.localizedDescription)")
                } else {
                    print("📬 [\(ts)] Notification sent: No apps selected")
                }
            }
            
            // Also set a flag in UserDefaults for the main app to detect
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(true, forKey: "noAppsSelectedWarning")
                groupDefaults.set(Date().timeIntervalSince1970, forKey: "noAppsSelectedWarningTime")
            }
            
            return
        }
        
        // Clear any previous warning since apps are now selected
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: "noAppsSelectedWarning")
            groupDefaults.removeObject(forKey: "noAppsSelectedWarningTime")
        }
        
        // Apply the restrictions
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        
        // Verify what's actually blocked after applying
        let nowBlockedApps = store.shield.applications?.count ?? 0
        let nowBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let nowBlockedDomains = store.shield.webDomains?.count ?? 0
        print("✅ [\(ts)] ManagedSettings AFTER applying: apps=\(nowBlockedApps), categories=\(nowBlockedCategories), domains=\(nowBlockedDomains)")
        print("✅ [\(ts)] Total restrictions active: \(nowBlockedApps + nowBlockedCategories + nowBlockedDomains) items")
        // Log the ACTUAL tokens now present in ManagedSettings (ground truth)
        if let appliedApps = store.shield.applications, !appliedApps.isEmpty {
            let tokens = appliedApps.map { String(describing: $0) }
            print("   ↳ applied app tokens: \(tokens)")
        }
        if case let .specific(categoryTokens, _)? = store.shield.applicationCategories, !categoryTokens.isEmpty {
            let tokens = categoryTokens.map { String(describing: $0) }
            print("   ↳ applied category tokens: \(tokens)")
        }
        if let appliedDomains = store.shield.webDomains, !appliedDomains.isEmpty {
            let tokens = appliedDomains.map { String(describing: $0) }
            print("   ↳ applied web domains: \(tokens)")
        }

        // Persist a start timestamp for the main app to pick up countdown immediately
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            let nowTs = Date().timeIntervalSince1970
            groupDefaults.set(nowTs, forKey: "blockingStartTime")
            print("⏰ [\(ts)] Set blockingStartTime to \(formatter.string(from: now)) (applied at shield time)")
            groupDefaults.set(true, forKey: "appsActuallyBlocked")
            print("🔒 [\(ts)] [BlockingMonitor] FINAL: Apps actually blocked = true")
            print("📝 [\(ts)] Updated UserDefaults: appsActuallyBlocked=true")

            // Track currently monitored activities for logging only (limit array size to prevent memory issues)
            var activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []
            
            // Keep only last 30 activities to prevent unbounded growth
            if activeNames.count > 30 {
                activeNames = Array(activeNames.suffix(25))
            }
            
            if !activeNames.contains(activity.rawValue) {
                activeNames.append(activity.rawValue)
                groupDefaults.set(activeNames, forKey: "currentlyMonitoredActivityNames")
            }

            // Resolve and log what's currently being monitored (grounded by monitor events)
            let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] ?? []
            print("📡 [\(ts)] Currently monitored activities (count=\(activeNames.count)):")
            for raw in activeNames {
                let parts = raw.split(separator: "_")
                var startStr = ""
                var endStr = "?"
                var nameStr = raw
                if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
                    let startDate = Date(timeIntervalSince1970: startTs)
                    startStr = formatter.string(from: startDate)
                    nameStr = String(parts[1])
                    if let match = schedules.first(where: { sched in
                        guard let n = sched["name"] as? String, let ts = sched["date"] as? TimeInterval else { return false }
                        return n == nameStr && Int(ts) == Int(startTs)
                    }), let dur = match["duration"] as? Double {
                        let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                        endStr = formatter.string(from: endDate)
                    }
                }
                print("   • activity=\(raw) | prayer=\(nameStr) | start=\(startStr) | end=\(endStr)")
            }
            // Force a ping the main app logger by updating a flag it watches (toggle a nonce)
            let nonce = Int(Date().timeIntervalSince1970 * 1000)
            groupDefaults.set(nonce, forKey: "currentlyMonitoredNonce")
        }
        print("🔔 [\(ts)] ===== END INTERVAL STARTED =====\n")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        
        // One-time event log retained; reduce verbosity elsewhere if needed
        let ts = formatter.string(from: now)
        print("🔕 [\(ts)] Activity ended: \(activity.rawValue)")
        
        // Check what's currently blocked before we clear
        let currentlyBlockedApps = store.shield.applications?.count ?? 0
        let currentlyBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let currentlyBlockedDomains = store.shield.webDomains?.count ?? 0
        print("🔍 [\(ts)] Current ManagedSettings BEFORE clearing: apps=\(currentlyBlockedApps), categories=\(currentlyBlockedCategories), domains=\(currentlyBlockedDomains)")
        
        // Check if strict mode is enabled via App Group UserDefaults
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false
        
        print("⚙️ [\(ts)] Strict mode enabled: \(strictMode)")
        
        // Early stop not used
        
        if strictMode {
            // In strict mode, keep restrictions active until voice confirmation
            // Update BlockingStateService to indicate we're waiting for voice confirmation
            groupDefaults?.set(true, forKey: "isWaitingForVoiceConfirmation")
            print("🎙️ [\(ts)] Strict mode: Keeping restrictions active, waiting for voice confirmation")
            print("📝 [\(ts)] Updated UserDefaults: isWaitingForVoiceConfirmation=true")
            
        } else {
            // In normal mode, clear restrictions immediately
            store.clearAllSettings()
            
            // Verify clearing worked
            let afterClearApps = store.shield.applications?.count ?? 0
            let afterClearCategories = store.shield.applicationCategories != nil ? 1 : 0
            let afterClearDomains = store.shield.webDomains?.count ?? 0
            print("✅ [\(ts)] ManagedSettings AFTER clearing: apps=\(afterClearApps), categories=\(afterClearCategories), domains=\(afterClearDomains)")
            
            groupDefaults?.set(false, forKey: "appsActuallyBlocked")
            print("🔓 [\(ts)] [BlockingMonitor] FINAL: Apps actually blocked = false (interval end)")
            print("📝 [\(ts)] Updated UserDefaults: appsActuallyBlocked=false")
        }

        // Update and log currently monitored activities (remove this one)
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            var activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []
            activeNames.removeAll { $0 == activity.rawValue }
            
            // Clean up old entries that may have been missed
            let now = Date()
            activeNames = activeNames.filter { raw in
                let parts = raw.split(separator: "_")
                guard parts.count >= 3, let startTs = TimeInterval(parts.last!) else {
                    return true // Keep non-prayer activities
                }
                // Remove activities older than 24 hours
                let activityDate = Date(timeIntervalSince1970: startTs)
                return now.timeIntervalSince(activityDate) < 86400 // 24 hours
            }
            
            groupDefaults.set(activeNames, forKey: "currentlyMonitoredActivityNames")

            let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] ?? []
            print("📡 [\(ts)] Currently monitored activities after end (count=\(activeNames.count)):")
            for raw in activeNames {
                let parts = raw.split(separator: "_")
                var startStr = ""
                var endStr = "?"
                var nameStr = raw
                if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
                    let startDate = Date(timeIntervalSince1970: startTs)
                    startStr = formatter.string(from: startDate)
                    nameStr = String(parts[1])
                    if let match = schedules.first(where: { sched in
                        guard let n = sched["name"] as? String, let ts = sched["date"] as? TimeInterval else { return false }
                        return n == nameStr && Int(ts) == Int(startTs)
                    }), let dur = match["duration"] as? Double {
                        let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                        endStr = formatter.string(from: endDate)
                    }
                }
                print("   • activity=\(raw) | prayer=\(nameStr) | start=\(startStr) | end=\(endStr)")
            }
        }
        print("🔕 [\(ts)] ===== END INTERVAL ENDED =====\n")
    }
    
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // This is called when usage thresholds are reached
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        // This is called shortly before blocking starts (warning period). Log what is scheduled.
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        let ts = formatter.string(from: now)

        // Parse activity name for prayer and scheduled start
        var plannedStartStr = "?"
        var prayerNameStr: String = activity.rawValue
        let parts = activity.rawValue.split(separator: "_")
        if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
            let startDate = Date(timeIntervalSince1970: startTs)
            plannedStartStr = formatter.string(from: startDate)
            prayerNameStr = String(parts[1])
        }
        
        // Try to resolve scheduled end from PrayerTimeSchedules (duration)
        var plannedEndStr = "?"
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]],
           parts.count >= 3, let startTs = TimeInterval(parts.last!) {
            if let match = schedules.first(where: { sched in
                guard let n = sched["name"] as? String, let ts2 = sched["date"] as? TimeInterval else { return false }
                return n == String(parts[1]) && Int(ts2) == Int(startTs)
            }), let dur = match["duration"] as? Double {
                let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                plannedEndStr = formatter.string(from: endDate)
            }
        }

        print("⏳ [\(ts)] Upcoming block (warning): activity=\(activity.rawValue) | prayer=\(prayerNameStr) | start=\(plannedStartStr) | end=\(plannedEndStr)")

        // Show what is scheduled to be blocked (selection snapshot now)
        let selection = AppSelectionModel.getCurrentSelection()
        print("🎯 [\(ts)] Scheduled selection: apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count), domains=\(selection.webDomainTokens.count)")
        if !selection.applicationTokens.isEmpty {
            let appTokens = selection.applicationTokens.map { String(describing: $0) }
            print("   ↳ apps tokens: \(appTokens)")
        }
        if !selection.categoryTokens.isEmpty {
            let catTokens = selection.categoryTokens.map { String(describing: $0) }
            print("   ↳ categories tokens: \(catTokens)")
        }
        if !selection.webDomainTokens.isEmpty {
            let domainTokens = selection.webDomainTokens.map { String(describing: $0) }
            print("   ↳ web domains: \(domainTokens)")
        }
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        // This is called shortly before blocking ends (warning period). Log what is still applied.
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        let ts = formatter.string(from: now)

        // Parse for planned end
        var plannedEndStr = "?"
        var prayerNameStr: String = activity.rawValue
        let parts = activity.rawValue.split(separator: "_")
        if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
            prayerNameStr = String(parts[1])
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
               let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]],
               let match = schedules.first(where: { sched in
                   guard let n = sched["name"] as? String, let ts2 = sched["date"] as? TimeInterval else { return false }
                   return n == String(parts[1]) && Int(ts2) == Int(startTs)
               }), let dur = match["duration"] as? Double {
                let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                plannedEndStr = formatter.string(from: endDate)
            }
        }

        // What is still applied right now
        let appliedApps = store.shield.applications?.count ?? 0
        let appliedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let appliedDomains = store.shield.webDomains?.count ?? 0
        print("⌛ [\(ts)] Block ending soon: prayer=\(prayerNameStr) | plannedEnd=\(plannedEndStr) | currently applied items=\(appliedApps + appliedCategories + appliedDomains)")
    }
    
    
}
