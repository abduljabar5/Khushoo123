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

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        
        // One-time event log retained; reduce verbosity elsewhere if needed
        print("🔔 Activity: \(activity.rawValue)")
        
        // Check what's currently blocked before we apply new restrictions
        let currentlyBlockedApps = store.shield.applications?.count ?? 0
        let currentlyBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let currentlyBlockedDomains = store.shield.webDomains?.count ?? 0
        print("🔍 Current ManagedSettings BEFORE: apps=\(currentlyBlockedApps), categories=\(currentlyBlockedCategories), domains=\(currentlyBlockedDomains)")
        
        // Cleaner activities no longer used
        
        // Normal prayer blocking activity
        // Use the static method to avoid triggering UI updates on background thread
        let selection = AppSelectionModel.getCurrentSelection()
        
        print("🎯 App selection to apply: apps=\(selection.applicationTokens.count), categories=\(selection.categoryTokens.count), domains=\(selection.webDomainTokens.count)")
        
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty {
            print("⚠️ No apps selected for blocking - prayer blocking will not work")
            return
        }
        
        // Apply the restrictions
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        
        // Verify what's actually blocked after applying
        let nowBlockedApps = store.shield.applications?.count ?? 0
        let nowBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let nowBlockedDomains = store.shield.webDomains?.count ?? 0
        print("✅ ManagedSettings AFTER applying: apps=\(nowBlockedApps), categories=\(nowBlockedCategories), domains=\(nowBlockedDomains)")
        print("✅ Total restrictions active: \(nowBlockedApps + nowBlockedCategories + nowBlockedDomains) items")

        // Persist a start timestamp for the main app to pick up countdown immediately
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            let nowTs = Date().timeIntervalSince1970
            groupDefaults.set(nowTs, forKey: "blockingStartTime")
            print("⏰ Set blockingStartTime to \(formatter.string(from: now)) (applied at shield time)")
            groupDefaults.set(true, forKey: "appsActuallyBlocked")
            print("🔒 [BlockingMonitor] FINAL: Apps actually blocked = true")
            print("📝 Updated UserDefaults: appsActuallyBlocked=true")
        }
        print("🔔 ===== END INTERVAL STARTED =====\n")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        
        // One-time event log retained; reduce verbosity elsewhere if needed
        print("🔕 Activity: \(activity.rawValue)")
        
        // Check what's currently blocked before we clear
        let currentlyBlockedApps = store.shield.applications?.count ?? 0
        let currentlyBlockedCategories = store.shield.applicationCategories != nil ? 1 : 0
        let currentlyBlockedDomains = store.shield.webDomains?.count ?? 0
        print("🔍 Current ManagedSettings BEFORE clearing: apps=\(currentlyBlockedApps), categories=\(currentlyBlockedCategories), domains=\(currentlyBlockedDomains)")
        
        // Check if strict mode is enabled via App Group UserDefaults
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false
        
        print("⚙️ Strict mode enabled: \(strictMode)")
        
        // Early stop not used
        
        if strictMode {
            // In strict mode, keep restrictions active until voice confirmation
            // Update BlockingStateService to indicate we're waiting for voice confirmation
            groupDefaults?.set(true, forKey: "isWaitingForVoiceConfirmation")
            print("🎙️ Strict mode: Keeping restrictions active, waiting for voice confirmation")
            print("📝 Updated UserDefaults: isWaitingForVoiceConfirmation=true")
            
        } else {
            // In normal mode, clear restrictions immediately
            store.clearAllSettings()
            
            // Verify clearing worked
            let afterClearApps = store.shield.applications?.count ?? 0
            let afterClearCategories = store.shield.applicationCategories != nil ? 1 : 0
            let afterClearDomains = store.shield.webDomains?.count ?? 0
            print("✅ ManagedSettings AFTER clearing: apps=\(afterClearApps), categories=\(afterClearCategories), domains=\(afterClearDomains)")
            
            groupDefaults?.set(false, forKey: "appsActuallyBlocked")
            print("🔓 [BlockingMonitor] FINAL: Apps actually blocked = false (interval end)")
            print("📝 Updated UserDefaults: appsActuallyBlocked=false")
        }
        print("🔕 ===== END INTERVAL ENDED =====\n")
    }
    
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // This is called when usage thresholds are reached
    }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // This is called before blocking starts (warning period)
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // This is called before blocking ends (warning period)
    }
    
    
}
