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
    private var lastScheduleInvocationAt: Date? = nil
    private var sessionScheduledActivityNames: Set<String> = []
    
    private init() {}
    
    /// Normalize a date to minute precision for consistent activity naming
    private func normalizeTimestamp(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let normalized = calendar.date(from: components) ?? date
        return Int(normalized.timeIntervalSince1970)
    }
    
    /// Schedule app blocking for a specified duration with a 30-second delay
    func scheduleBlocking(for duration: TimeInterval) {
        // Stop any existing monitoring first to ensure a clean state
        stopAllMonitoring()
        
        let activityName = DeviceActivityName("ManualBlocking")
        
        // Start blocking 30 seconds from now
        let startTime = Date().addingTimeInterval(30)
        let endTime = startTime.addingTimeInterval(duration)
        
        // Use full date components to ensure the schedule targets an absolute date, not just a time of day
        var startComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startTime)
        var endComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
        startComponents.calendar = Calendar.current
        endComponents.calendar = Calendar.current

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        
        do {
            try center.startMonitoring(activityName, during: schedule)
            activeActivityNames = [activityName]
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            let startStr = formatter.string(from: startTime)
            let endStr = formatter.string(from: endTime)
            print("📅 [Scheduler] Scheduled manual block: start=\(startStr), end=\(endStr), activity=\(activityName.rawValue)")
        } catch {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            let ts = formatter.string(from: startTime)
            print("❌ [\(ts)] Failed to schedule blocking: \(error.localizedDescription)")
        }
    }
    
    /// Schedule blocking for multiple prayer times (up to 20 schedules)
    func schedulePrayerTimeBlocking(prayerTimes: [PrayerTime], duration: Double, selectedPrayers: Set<String>) {
        // Simplified: always compute next up-to-20 selected future prayers from now and try to schedule them.
        // Avoid relying on saved schedules to decide capacity, since UI may persist previews.
        let now = Date()
        if let last = lastScheduleInvocationAt {
            let delta = now.timeIntervalSince(last)
            if delta < 3 {
                let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .medium
                print("⚠️ [\(fmt.string(from: now))] [Scheduler] Back-to-back scheduling detected (Δ=\(String(format: "%.2f", delta))s). You may be invoking scheduling from multiple places.")
            }
        }
        lastScheduleInvocationAt = now
        // Ensure stable ordering by start date, then keep at most one of each prayer per day
        let sortedFutureSelected = prayerTimes
            .filter { $0.date > now && selectedPrayers.contains($0.name) }
            .sorted(by: { $0.date < $1.date })

        var uniquePerDay: [PrayerTime] = []
        var seenKeys = Set<String>()
        let calendar = Calendar.current
        for pt in sortedFutureSelected {
            let day = calendar.startOfDay(for: pt.date)
            let key = "\(day.timeIntervalSince1970)_\(pt.name)"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                uniquePerDay.append(pt)
            }
        }
        // Check current capacity before scheduling
        let maxSchedules = 20
        let currentActiveCount = activeActivityNames.count
        let availableSlots = max(0, maxSchedules - currentActiveCount)
        
        if availableSlots == 0 {
            print("⚠️ Schedule capacity reached (\(currentActiveCount)/\(maxSchedules)). Clearing old schedules...")
            // Clear some old activities to make room
            performAggressiveCleanup()
        }
        
        let prayersToAdd = Array(uniquePerDay.prefix(min(availableSlots > 0 ? availableSlots : 10, 20)))
        guard !prayersToAdd.isEmpty else {
            print("❌ No capacity to schedule new prayers")
            return
        }
        
        var newActivityNames: [DeviceActivityName] = []
        var scheduledCount = 0
        var failedCount = 0
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        // Plan log: show which activity names we are about to request
        do {
            let planned = prayersToAdd.map { prayer in
                let ts = Int(prayer.date.timeIntervalSince1970)
                return "Prayer_\(prayer.name)_\(ts)"
            }
            print("🗺️ [\(formatter.string(from: now))] [Scheduler] Planning to schedule: \(planned)")
        }

        for prayer in prayersToAdd {
            // Skip past prayers
            if prayer.date <= Date() {
                // Silenced: skip past log
                continue
            }
            
            // Calculate standard duration (no early stop logic)
            let deviceActivityDurationSeconds = duration * 60

            // Use normalized timestamp for consistent activity naming
            let startTime = prayer.date
            let endTime = startTime.addingTimeInterval(deviceActivityDurationSeconds)
            let normalizedTs = normalizeTimestamp(startTime)
            let activityName = DeviceActivityName("Prayer_\(prayer.name)_\(normalizedTs)")
            
            // Use full date components so each prayer schedules on the correct absolute date
            var startComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startTime)
            var endComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
            startComponents.calendar = Calendar.current
            endComponents.calendar = Calendar.current

            let deviceSchedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )

            // Preemptively stop near-duplicate monitors for this prayer within ±5 minutes of the normalized minute
            let offsets = stride(from: -300, through: 300, by: 60)
            let namesToStop = offsets.map { DeviceActivityName("Prayer_\(prayer.name)_\(normalizedTs + $0)") }
            center.stopMonitoring(namesToStop)
            
            do {
                try center.startMonitoring(activityName, during: deviceSchedule)
                newActivityNames.append(activityName)
                scheduledCount += 1
                let startStr = formatter.string(from: startTime)
                let endStr = formatter.string(from: endTime)
                print("📅 [Scheduler] Scheduled \(prayer.name): start=\(startStr), end=\(endStr), activity=\(activityName.rawValue)")
                sessionScheduledActivityNames.insert(activityName.rawValue)
            } catch {
                // If already scheduled, ignore; otherwise log with scheduled start time
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .medium
                let ts = formatter.string(from: startTime)
                failedCount += 1
                let reason: String
                if sessionScheduledActivityNames.contains(activityName.rawValue) {
                    reason = "duplicate activity name already scheduled this session"
                } else {
                    reason = "system refused (limit/rate/duplicate from prior run)"
                }
                print("❌ [\(ts)] [Scheduler] Failed to schedule \(prayer.name): \(error.localizedDescription) | activity=\(activityName.rawValue) | reason=\(reason)")
            }
        }
        
        // Add new activities to tracked list (don't replace, append)
        activeActivityNames.append(contentsOf: newActivityNames)
        
        // Persist the schedules we attempted to schedule, so other components have consistent view
        saveScheduleToUserDefaults(prayersToAdd, duration: duration)

        // Summary log to show how many the OS accepted vs attempted
        let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .medium
        print("🧮 [\(fmt.string(from: Date()))] [Scheduler] Summary: attempted=\(prayersToAdd.count), scheduled=\(scheduledCount), failed=\(failedCount)")

        // Log what is currently monitored according to the monitor extension (ground truth)
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            let activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            let ts = formatter.string(from: Date())
            print("📡 [\(ts)] Currently monitored (from monitor): count=\(activeNames.count)")
            for raw in activeNames {
                let parts = raw.split(separator: "_")
                var startStr = ""
                var endStr = "?"
                var nameStr: String = raw
                if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
                    let startDate = Date(timeIntervalSince1970: startTs)
                    startStr = formatter.string(from: startDate)
                    nameStr = String(parts[1])
                    if let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]],
                       let match = schedules.first(where: { sched in
                           guard let n = sched["name"] as? String, let ts2 = sched["date"] as? TimeInterval else { return false }
                           return n == nameStr && Int(ts2) == Int(startTs)
                       }), let dur = match["duration"] as? Double {
                        let endDate = Date(timeIntervalSince1970: startTs).addingTimeInterval(dur)
                        endStr = formatter.string(from: endDate)
                    }
                }
                print("   • activity=\(raw) | prayer=\(nameStr) | start=\(startStr) | end=\(endStr)")
            }
        }
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
                    let normalizedTs = normalizeTimestamp(Date(timeIntervalSince1970: timestamp))
                    let activityName = DeviceActivityName("Prayer_\(name)_\(normalizedTs)")
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
                // Generate normalized timestamps for possible prayer times
                let possibleTimestamps = [
                    normalizeTimestamp(targetDate),
                    normalizeTimestamp(dayStart),
                    normalizeTimestamp(targetDate.addingTimeInterval(3600)), // +1 hour
                    normalizeTimestamp(targetDate.addingTimeInterval(-3600)) // -1 hour
                ]
                
                for timestamp in Set(possibleTimestamps) { // Use Set to avoid duplicates
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
                let normalizedTs = normalizeTimestamp(Date(timeIntervalSince1970: timestamp))
                let activityName = DeviceActivityName("Prayer_\(name)_\(normalizedTs)")
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
                    let normalizedTs = normalizeTimestamp(Date(timeIntervalSince1970: timestamp))
                    let activityName = DeviceActivityName("Prayer_\(name)_\(normalizedTs)")
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
            
            // Create unique activity name with normalized timestamp
            let normalizedTs = normalizeTimestamp(prayerStartTime)
            let activityName = DeviceActivityName("Prayer_\(prayer.name)_\(normalizedTs)")
            
            // Create schedule
            var startComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerStartTime)
            var endComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: prayerEndTime)
            startComponents.calendar = Calendar.current
            endComponents.calendar = Calendar.current

            let schedule = DeviceActivitySchedule(
                intervalStart: startComponents,
                intervalEnd: endComponents,
                repeats: false
            )
            
            do {
                try center.startMonitoring(activityName, during: schedule)
                newActivityNames.append(activityName)
                successfullyScheduled += 1
                
                // Log only successfully scheduled prayers
                print("✅ \(prayer.name) at \(formatter.string(from: prayerStartTime))")
                
            } catch {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .medium
                let ts = formatter.string(from: prayerStartTime)
                print("❌ [\(ts)] \(prayer.name) failed: \(error.localizedDescription)")
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
            
            let normalizedTs = normalizeTimestamp(prayer.date)
            let schedule: [String: Any] = [
                "name": prayer.name,
                "date": prayer.date.timeIntervalSince1970,
                "duration": deviceActivityDurationSeconds,
                "activityName": "Prayer_\(prayer.name)_\(normalizedTs)"
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