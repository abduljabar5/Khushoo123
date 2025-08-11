#!/usr/bin/env swift

import Foundation

print("\n========== CHECKING BLOCKING SETUP ==========\n")

let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

// 1. Check if apps are selected
print("1. CHECKING APP SELECTION:")
if let appSelectionData = groupDefaults?.data(forKey: "DhikrAppSelection") {
    print("   ✅ App selection data exists: \(appSelectionData.count) bytes")
    // Try to see if it's empty
    if appSelectionData.count < 100 {
        print("   ⚠️ App selection data seems very small - might be empty selection")
    }
} else {
    print("   ❌ No app selection data found - NO APPS SELECTED FOR BLOCKING")
}

// 2. Check prayer schedules
print("\n2. CHECKING PRAYER SCHEDULES:")
if let schedules = groupDefaults?.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] {
    print("   ✅ \(schedules.count) prayer schedules saved")
    
    let now = Date()
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    // Check if any schedule should be active now
    var activeSchedule: [String: Any]? = nil
    for schedule in schedules {
        if let timestamp = schedule["date"] as? TimeInterval,
           let duration = schedule["duration"] as? Double,
           let name = schedule["name"] as? String {
            let startDate = Date(timeIntervalSince1970: timestamp)
            let endDate = startDate.addingTimeInterval(duration)
            
            if now >= startDate && now <= endDate {
                activeSchedule = schedule
                print("   🔥 ACTIVE NOW: \(name) - Started \(formatter.string(from: startDate)), ends \(formatter.string(from: endDate))")
            }
        }
    }
    
    if activeSchedule == nil {
        print("   ⚠️ No schedule should be active at current time")
    }
} else {
    print("   ❌ No prayer schedules found")
}

// 3. Check blocking state flags
print("\n3. CHECKING BLOCKING STATE FLAGS:")
let appsActuallyBlocked = groupDefaults?.bool(forKey: "appsActuallyBlocked") ?? false
let blockingStartTime = groupDefaults?.object(forKey: "blockingStartTime") as? TimeInterval
let isEarlyUnlockedActive = groupDefaults?.bool(forKey: "isEarlyUnlockedActive") ?? false

print("   appsActuallyBlocked: \(appsActuallyBlocked)")
if let startTime = blockingStartTime {
    let startDate = Date(timeIntervalSince1970: startTime)
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    print("   blockingStartTime: \(formatter.string(from: startDate))")
} else {
    print("   blockingStartTime: nil")
}
print("   isEarlyUnlockedActive: \(isEarlyUnlockedActive)")

// 4. Check current time vs Maghrib
print("\n4. CURRENT TIME CHECK:")
let now = Date()
let formatter = DateFormatter()
formatter.dateStyle = .medium
formatter.timeStyle = .medium
print("   Current time: \(formatter.string(from: now))")
print("   Maghrib scheduled: Aug 10, 2025 at 8:27 PM - 8:42 PM")

let maghribStart = DateComponents(calendar: .current, year: 2025, month: 8, day: 10, hour: 20, minute: 27).date!
let maghribEnd = DateComponents(calendar: .current, year: 2025, month: 8, day: 10, hour: 20, minute: 42).date!

if now >= maghribStart && now <= maghribEnd {
    print("   ✅ Current time IS within Maghrib prayer window")
    print("   ⚠️ Apps SHOULD be blocked right now!")
} else if now < maghribStart {
    print("   ⏰ Maghrib hasn't started yet")
} else {
    print("   ⏰ Maghrib prayer time has passed")
}

print("\n========== DIAGNOSIS ==========")
print("\nPossible issues:")
print("1. ❌ No apps selected for blocking (check AppPickerView)")
print("2. ❌ DeviceActivityMonitor extension not running")
print("3. ❌ DeviceActivity schedule not properly created")
print("4. ❌ Extension entitlements/capabilities missing")
print("5. ❌ Screen Time permissions not granted properly")

print("\n========== END CHECK ==========\n")