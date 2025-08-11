#!/usr/bin/env swift

import Foundation

// Test script to verify prayer scheduling logic flow

print("\n========== PRAYER SCHEDULING TEST ==========\n")

// Simulate app launch
print("1. App Launch: DhikrApp.onAppear()")
print("   - Calls: prayerTimeViewModel.start()")

// Simulate PrayerTimeViewModel.start()
print("\n2. PrayerTimeViewModel.start()")
print("   - Checks location authorization")
print("   - If authorized: requests location")
print("   - If not determined: requests permission")
print("   - If denied: shows error")

// Simulate location received
print("\n3. Location received callback")
print("   - Calls: fetchAllRequiredPrayerTimes(location)")

// Simulate fetchAllRequiredPrayerTimes
print("\n4. fetchAllRequiredPrayerTimes()")
print("   - Fetches prayer times for 5 days")
print("   - Stores in prayerTimes array")
print("   - Calls: schedulePrayerBlocking() in background task")

// Simulate schedulePrayerBlocking
print("\n5. schedulePrayerBlocking()")
print("   Step 1: Request Screen Time authorization")
print("   Step 2: Get user settings")
print("      - Selected prayers from UserDefaults")
print("      - Blocking duration from UserDefaults")
print("   Step 3: Filter future prayers (max 20)")
print("   Step 4: Save schedule to UserDefaults")
print("   Step 5: Call DeviceActivityService.schedulePrayerTimeBlocking()")

// Simulate DeviceActivityService
print("\n6. DeviceActivityService.schedulePrayerTimeBlocking()")
print("   - Cleans up past prayers")
print("   - Checks if already have 20 scheduled")
print("   - For each prayer:")
print("     • Creates DeviceActivitySchedule")
print("     • Calls center.startMonitoring()")
print("     • Tracks in activeActivityNames")

// Check current settings
print("\n========== CHECKING CURRENT SETTINGS ==========\n")

let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

// Check selected prayers
let selectedFajr = groupDefaults?.object(forKey: "focusSelectedFajr") as? Bool ?? true
let selectedDhuhr = groupDefaults?.object(forKey: "focusSelectedDhuhr") as? Bool ?? true
let selectedAsr = groupDefaults?.object(forKey: "focusSelectedAsr") as? Bool ?? true
let selectedMaghrib = groupDefaults?.object(forKey: "focusSelectedMaghrib") as? Bool ?? true
let selectedIsha = groupDefaults?.object(forKey: "focusSelectedIsha") as? Bool ?? true

print("Selected Prayers:")
print("  Fajr: \(selectedFajr)")
print("  Dhuhr: \(selectedDhuhr)")
print("  Asr: \(selectedAsr)")
print("  Maghrib: \(selectedMaghrib)")
print("  Isha: \(selectedIsha)")

// Check blocking duration
let duration = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
print("\nBlocking Duration: \(duration) minutes")

// Check saved schedules
if let schedules = groupDefaults?.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] {
    print("\nSaved Prayer Schedules: \(schedules.count)")
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    
    for schedule in schedules.prefix(5) {
        if let name = schedule["name"] as? String,
           let timestamp = schedule["date"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            print("  - \(name) at \(formatter.string(from: date))")
        }
    }
} else {
    print("\nNo saved prayer schedules found")
}

// Check cached prayer times
if let cachedArray = groupDefaults?.object(forKey: "PrayerTimesCacheArray") as? [[String: Any]] {
    print("\nCached Prayer Times: \(cachedArray.count)")
} else {
    print("\nNo cached prayer times found")
}

print("\n========== POTENTIAL ISSUES TO CHECK ==========\n")
print("1. Location permissions not granted")
print("2. Screen Time authorization not granted")
print("3. No prayers selected in settings")
print("4. Prayer times not fetched from API")
print("5. DeviceActivity scheduling failures")
print("6. App Groups not configured correctly")

print("\n========== END TEST ==========\n")