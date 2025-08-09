//
//  DeviceActivityService.swift
//  Dhikr
//
//  Created by Performance Optimization
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

@available(iOS 15.0, *)
class DeviceActivityService: ObservableObject {
    static let shared = DeviceActivityService()
    
    private let center = DeviceActivityCenter()
    private let prayerScheduleKey = "PrayerTimeSchedules"
    private var activeActivityNames: [DeviceActivityName] = []
    
    private init() {}
    
    /// Schedule app blocking for a specified duration with a 30-second delay
    func scheduleBlocking(for duration: TimeInterval) {
        // Stop any existing monitoring first to ensure a clean state
        stopAllMonitoring()
        
        let activityName = DeviceActivityName("ManualBlocking")
        
        // Start blocking 30 seconds from now
        let startTime = Date().addingTimeInterval(30)
        let endTime = startTime.addingTimeInterval(duration)
        
        let schedule = DeviceActivitySchedule(
            intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: startTime),
            intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: endTime),
            repeats: false
        )
        
        do {
            try center.startMonitoring(activityName, during: schedule)
            activeActivityNames = [activityName]
        } catch {
            print("❌ Failed to schedule blocking: \(error.localizedDescription)")
        }
    }
    
    /// Schedule blocking for multiple prayer times (up to 20 schedules)
    func schedulePrayerTimeBlocking(prayerTimes: [PrayerTime], duration: Double, selectedPrayers: Set<String>) {
        // Silenced: verbose scheduler debug
        // Check and clean up past prayers
        let (removedCount, currentFutureCount) = cleanupPassedPrayersOnly()
        // Silenced: counts
        
        // Check if we already have 20 future prayers
        if currentFutureCount >= 20 {
            return
        }
        
        let slotsAvailable = 20 - currentFutureCount
        // Silenced: slots available log
        
        // Filter to future prayers that we need to add
        let now = Date()
        let futurePrayers = prayerTimes.filter { $0.date > now }
        let prayersToAdd = Array(futurePrayers.filter { selectedPrayers.contains($0.name) }.prefix(slotsAvailable))
        // Silenced: counts
        
        guard !prayersToAdd.isEmpty else { return }
        
        var successfullyScheduled = 0
        var newActivityNames: [DeviceActivityName] = []
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        for prayer in prayersToAdd {
            // Skip past prayers
            let now = Date()
            if prayer.date <= now {
                // Silenced: skip past log
                continue
            }
            
            // Calculate standard duration (no early stop logic)
            let deviceActivityDurationSeconds = duration * 60
            
            let startTime = prayer.date
            
            // Schedule a single activity for the full duration
            let endTime = startTime.addingTimeInterval(deviceActivityDurationSeconds)
            let activityName = DeviceActivityName("Prayer_\(prayer.name)_\(Int(startTime.timeIntervalSince1970))")
            
            let deviceSchedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: startTime),
                intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: endTime),
                repeats: false
            )
            
            do {
                try center.startMonitoring(activityName, during: deviceSchedule)
                newActivityNames.append(activityName)
                successfullyScheduled += 1
                // Optional: success log
            } catch {
                print("❌ [Scheduler] Failed to schedule \(prayer.name): \(error.localizedDescription)")
            }
        }
        
        // Add new activities to tracked list (don't replace, append)
        activeActivityNames.append(contentsOf: newActivityNames)
        // Silenced: counts
    }
    
    /// Stop current blocking session
    func stopBlocking() {
        stopAllMonitoring()
        
        // Clear schedule info
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: prayerScheduleKey)
        }
    }
    
    /// Stop all active monitoring sessions
    private func stopAllMonitoring() {
        // Create a comprehensive list of activities to stop
        var allActivitiesToStop: Set<DeviceActivityName> = []
        
        // Add all tracked activities
        if !activeActivityNames.isEmpty {
            allActivitiesToStop.formUnion(activeActivityNames)
        }
        
        // Add activities from saved schedules
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let existingSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] {
            
            for schedule in existingSchedules {
                if let name = schedule["name"] as? String,
                   let timestamp = schedule["date"] as? TimeInterval {
                    let activityName = DeviceActivityName("Prayer_\(name)_\(Int(timestamp))")
                    allActivitiesToStop.insert(activityName)
                }
            }
        }
        
        // Add common activity patterns
        allActivitiesToStop.insert(DeviceActivityName("ManualBlocking"))
        allActivitiesToStop.insert(DeviceActivityName("PrayerTimeBlocking"))
        
        // No cleaner activities used
        
        // Generate potential activity names for recent and upcoming prayers
        let now = Date()
        let calendar = Calendar.current
        
        // Check past 2 days and next 5 days
        for dayOffset in -2...5 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            for prayerName in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] {
                // Try multiple timestamp formats
                let dayStart = calendar.startOfDay(for: targetDate)
                let possibleTimestamps = [
                    Int(targetDate.timeIntervalSince1970),
                    Int(dayStart.timeIntervalSince1970),
                    Int(targetDate.timeIntervalSince1970) - Int(targetDate.timeIntervalSince1970.truncatingRemainder(dividingBy: 60))
                ]
                
                for timestamp in possibleTimestamps {
                    allActivitiesToStop.insert(DeviceActivityName("Prayer_\(prayerName)_\(timestamp)"))
                }
            }
        }
        
        // Stop all activities at once
        if !allActivitiesToStop.isEmpty {
            let activitiesArray = Array(allActivitiesToStop)
            center.stopMonitoring(activitiesArray)
        }
        
        // Clear tracked activities
        activeActivityNames.removeAll()
        
        // Clear saved schedules
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: prayerScheduleKey)
        }
    }
    
    
    /// Get current user settings for comparison
    private func getCurrentSettings() -> (selectedPrayers: Set<String>, duration: Double) {
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        
        // Get selected prayers
        let selectedFajr = groupDefaults?.object(forKey: "focusSelectedFajr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedFajr") as? Bool ?? true
        let selectedDhuhr = groupDefaults?.object(forKey: "focusSelectedDhuhr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedDhuhr") as? Bool ?? true
        let selectedAsr = groupDefaults?.object(forKey: "focusSelectedAsr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedAsr") as? Bool ?? true
        let selectedMaghrib = groupDefaults?.object(forKey: "focusSelectedMaghrib") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedMaghrib") as? Bool ?? true
        let selectedIsha = groupDefaults?.object(forKey: "focusSelectedIsha") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedIsha") as? Bool ?? true
        
        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }
        
        // Get duration
        let duration = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? UserDefaults.standard.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
        
        return (selectedPrayers, duration)
    }
    
    /// Clean up passed prayers to make room for new ones
    private func cleanupPassedPrayers() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
              let existingSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] else {
            return
        }
        
        let now = Date()
        var passedCount = 0
        var keptCount = 0
        
        // Keep only future prayers
        let cleanedSchedules = existingSchedules.compactMap { schedule -> [String: Any]? in
            guard let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double else { return nil }
            
            let prayerDate = Date(timeIntervalSince1970: timestamp)
            let prayerEndTime = prayerDate.addingTimeInterval(duration)
            
            if prayerEndTime > now {
                keptCount += 1
                return schedule
            } else {
                passedCount += 1
                return nil
            }
        }
        
        // Only update if we removed some prayers
        if passedCount > 0 {
            groupDefaults.set(cleanedSchedules, forKey: prayerScheduleKey)
        }
    }
    
    /// Clean up only passed prayers and return counts
    private func cleanupPassedPrayersOnly() -> (removedCount: Int, futureCount: Int) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
              let existingSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] else {
            // Silenced
            return (0, 0)
        }
        
        let now = Date()
        var passedCount = 0
        var futureCount = 0
        var passedActivityNames: [DeviceActivityName] = []
        
        let cleanedSchedules = existingSchedules.compactMap { schedule -> [String: Any]? in
            guard let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double,
                  let name = schedule["name"] as? String else { return nil }
            
            let prayerDate = Date(timeIntervalSince1970: timestamp)
            let prayerEndTime = prayerDate.addingTimeInterval(duration)
            
            if prayerEndTime > now {
                futureCount += 1
                // Silenced
                return schedule
            } else {
                passedCount += 1
                let activityName = DeviceActivityName("Prayer_\(name)_\(Int(timestamp))")
                passedActivityNames.append(activityName)
                // Silenced
                return nil
            }
        }
        
        // Stop only the passed prayer activities
        if !passedActivityNames.isEmpty {
            center.stopMonitoring(passedActivityNames)
        }
        
        // Update schedules if we removed some prayers
        if passedCount > 0 {
            groupDefaults.set(cleanedSchedules, forKey: prayerScheduleKey)
            // Silenced
        }
        
        return (passedCount, futureCount)
    }
    
    /// Perform aggressive cleanup to stop ALL possible prayer activities
    private func performAggressiveCleanup() -> Int {
        
        var activitiesToStop: [DeviceActivityName] = []
        
        // Stop all tracked activities
        activitiesToStop.append(contentsOf: activeActivityNames)
        
        // Stop common activity patterns
        activitiesToStop.append(DeviceActivityName("PrayerTimeBlocking"))
        activitiesToStop.append(DeviceActivityName("ManualBlocking"))
        
        // Try to stop activities from saved schedules (if any remain)
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let existingSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] {
            
            for schedule in existingSchedules {
                if let name = schedule["name"] as? String,
                   let timestamp = schedule["date"] as? TimeInterval {
                    let activityName = DeviceActivityName("Prayer_\(name)_\(Int(timestamp))")
                    activitiesToStop.append(activityName)
                }
            }
        }
        
        // Generate potential activity names for the next few days
        let now = Date()
        let calendar = Calendar.current
        
        for dayOffset in 0..<7 { // Try next 7 days
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            for prayerName in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] {
                // Try different timestamp formats
                let timestamp1 = Int(targetDate.timeIntervalSince1970)
                let timestamp2 = Int(targetDate.timeIntervalSince1970) + dayOffset * 86400
                
                activitiesToStop.append(DeviceActivityName("Prayer_\(prayerName)_\(timestamp1)"))
                activitiesToStop.append(DeviceActivityName("Prayer_\(prayerName)_\(timestamp2)"))
            }
        }
        
        // Remove duplicates
        let uniqueActivities = Array(Set(activitiesToStop))
        
        if !uniqueActivities.isEmpty {
            center.stopMonitoring(uniqueActivities)
        }
        
        // Clear tracked activities
        activeActivityNames.removeAll()
        
        return uniqueActivities.count
    }
    
    /// Force complete clear and reschedule all prayers with current settings
    func forceCompleteReschedule(prayerTimes: [PrayerTime], duration: Double, selectedPrayers: Set<String>) {
        
        // Stop ALL existing monitoring
        stopAllMonitoring()
        
        
        // Clear all saved schedules
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: prayerScheduleKey)
        }
        
        // Aggressive cleanup
        performAggressiveCleanup()
        
        // Clear any active blocking state
        let store = ManagedSettingsStore()
        store.clearAllSettings()
        
        // Wait for activities to fully stop
        Thread.sleep(forTimeInterval: 2.0)
        
        // Now schedule fresh with current settings
        let now = Date()
        let futurePrayers = prayerTimes.filter { $0.date > now }
        let prayersToSchedule = Array(futurePrayers.filter { selectedPrayers.contains($0.name) }.prefix(20))
        
        guard !prayersToSchedule.isEmpty else {
            return
        }
        
        var successfullyScheduled = 0
        var newActivityNames: [DeviceActivityName] = []
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        for prayer in prayersToSchedule {
            // Skip past prayers
            let now = Date()
            if prayer.date <= now {
                continue
            }
            
            // Calculate standard duration (no early stop logic)
            let deviceActivityDurationSeconds = duration * 60
            let prayerStartTime = prayer.date
            let prayerEndTime = prayerStartTime.addingTimeInterval(deviceActivityDurationSeconds)
            
            // Create unique activity name
            let timestamp = Int(prayerStartTime.timeIntervalSince1970)
            let activityName = DeviceActivityName("Prayer_\(prayer.name)_\(timestamp)")
            
            // Create schedule
            let schedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents([.hour, .minute, .second], from: prayerStartTime),
                intervalEnd: Calendar.current.dateComponents([.hour, .minute, .second], from: prayerEndTime),
                repeats: false
            )
            
            do {
                try center.startMonitoring(activityName, during: schedule)
                newActivityNames.append(activityName)
                successfullyScheduled += 1
                
                // Log only successfully scheduled prayers
                print("✅ \(prayer.name) at \(formatter.string(from: prayerStartTime))")
                
            } catch {
                print("❌ \(prayer.name) failed: \(error.localizedDescription)")
            }
        }
        
        // Update tracked activities
        activeActivityNames = newActivityNames
        
        // Save the new schedule to UserDefaults for future cleanup
        saveScheduleToUserDefaults(prayersToSchedule, duration: duration)
    }
    
    /// Save prayer schedule to UserDefaults for cleanup tracking
    private func saveScheduleToUserDefaults(_ prayerTimes: [PrayerTime], duration: Double) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { 
            print("❌ Failed to access group defaults for saving schedule")
            return 
        }
        
        let schedules = prayerTimes.map { prayer -> [String: Any] in
            let deviceActivityDurationSeconds = duration * 60
            
            let schedule: [String: Any] = [
                "name": prayer.name,
                "date": prayer.date.timeIntervalSince1970,
                "duration": deviceActivityDurationSeconds,
                "activityName": "Prayer_\(prayer.name)_\(Int(prayer.date.timeIntervalSince1970))"
            ]
            
            return schedule
        }
        
        groupDefaults.set(schedules, forKey: prayerScheduleKey)
        // Silenced
    }
    
    /// Reset the initial scheduling flag (for debugging or complete reset)
    func resetSchedulingFlag() {
        UserDefaults.standard.removeObject(forKey: "hasScheduledInitialBlocking")
    }
    
    // Early stop validation removed; durations are used as-is
    
} 