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
    private let maxSchedules = 20 // Apple's DeviceActivity limit
    private let rollingWindowDays = 4 // Maintain 4 days of schedules to maximize 20 schedule limit (5 prayers × 4 days)
    private let updateIntervalDays = 0.25 // Update every 6 hours

    private init() {
    }
    
    /// Normalize a date to minute precision for consistent activity naming
    private func normalizeTimestamp(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let normalized = calendar.date(from: components) ?? date
        return Int(normalized.timeIntervalSince1970)
    }

    // MARK: - Rolling Window Management

    /// Schedule rolling 24-hour window of prayer times from storage
    /// - Parameters:
    ///   - storage: Prayer time storage
    ///   - duration: Blocking duration in minutes
    ///   - selectedPrayers: Set of selected prayer names
    ///   - prePrayerBuffer: Optional buffer time in minutes to start blocking BEFORE prayer time (default: 0)
    /// - Returns: true if scheduling was successful, false otherwise
    @discardableResult
    func scheduleRollingWindow(from storage: PrayerTimeStorage, duration: Double, selectedPrayers: Set<String>, prePrayerBuffer: Double = 0) -> Bool {
        print("🔄 [PrayerBlocking] Starting rolling window schedule (24h)")

        // Pre-check: Verify apps are selected before doing any work
        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty

        guard hasAppsSelected else {
            print("⚠️ [PrayerBlocking] No apps selected - skipping rolling window schedule")
            return false
        }

        guard !selectedPrayers.isEmpty else {
            print("⚠️ [PrayerBlocking] No prayers selected - skipping rolling window schedule")
            return false
        }

        let calendar = Calendar.current
        // IMPORTANT: Capture timestamp ONCE and use it throughout to avoid race conditions
        let scheduleTime = Date()
        let startOfToday = calendar.startOfDay(for: scheduleTime)
        let bufferSeconds = prePrayerBuffer * 60

        // Calculate end of rolling window (1 day from today)
        guard let endOfWindow = calendar.date(byAdding: .day, value: rollingWindowDays, to: startOfToday) else {
            print("❌ [PrayerBlocking] Failed to calculate window end date")
            return false
        }

        // Filter prayer times within rolling window
        let prayerTimesInWindow = storage.prayerTimes.filter { storedTime in
            storedTime.date >= startOfToday && storedTime.date < endOfWindow
        }


        // Convert to PrayerTime objects
        var prayerTimes: [PrayerTime] = []
        for storedTime in prayerTimesInWindow {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

            let prayers = [
                ("Fajr", storedTime.fajr),
                ("Dhuhr", storedTime.dhuhr),
                ("Asr", storedTime.asr),
                ("Maghrib", storedTime.maghrib),
                ("Isha", storedTime.isha)
            ]

            for (name, timeString) in prayers {
                // Skip if not selected
                guard selectedPrayers.contains(name) else { continue }

                // Parse time string
                let cleanTimeString = timeString.components(separatedBy: " ").first ?? timeString
                guard let time = timeFormatter.date(from: cleanTimeString) else { continue }

                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                if let prayerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                  minute: timeComponents.minute ?? 0,
                                                  second: 0,
                                                  of: storedTime.date) {
                    // Only add prayers where blocking hasn't started yet
                    // Blocking starts at prayerDate - buffer
                    let blockingStartTime = prayerDate.addingTimeInterval(-bufferSeconds)
                    if blockingStartTime > scheduleTime {
                        prayerTimes.append(PrayerTime(name: name, date: prayerDate))
                    }
                }
            }
        }

        // Sort by date and take only what fits in 20 schedule limit
        let sortedPrayers = prayerTimes.sorted { $0.date < $1.date }
        let prayersToSchedule = Array(sortedPrayers.prefix(maxSchedules))

        guard !prayersToSchedule.isEmpty else {
            print("⚠️ [PrayerBlocking] No future prayers to schedule")
            return false
        }

        print("📅 [PrayerBlocking] Scheduling \(prayersToSchedule.count) prayers (max \(maxSchedules))")

        // Stop all existing schedules first
        stopAllMonitoring()

        // Schedule the prayers with buffer time, passing the captured timestamp
        let success = schedulePrayerTimeBlocking(prayerTimes: prayersToSchedule, duration: duration, selectedPrayers: selectedPrayers, prePrayerBuffer: prePrayerBuffer, scheduleTime: scheduleTime)

        // Save last update time
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(Date().timeIntervalSince1970, forKey: "lastRollingWindowUpdate")
            groupDefaults.synchronize()
        }

        return success
    }

    /// Check if rolling window needs update (every 6 hours)
    func needsRollingWindowUpdate() -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
              let lastUpdateTs = groupDefaults.object(forKey: "lastRollingWindowUpdate") as? TimeInterval else {
            return true
        }

        let lastUpdate = Date(timeIntervalSince1970: lastUpdateTs)
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600.0

        let needsUpdate = hoursSinceUpdate >= (updateIntervalDays * 24)

        if needsUpdate {
        } else {
        }

        return needsUpdate
    }

    /// Update rolling window (remove old schedules, add new ones)
    func updateRollingWindow(from storage: PrayerTimeStorage, duration: Double, selectedPrayers: Set<String>) {

        let calendar = Calendar.current
        let now = Date()

        // Count prayers before update
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let existingSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] {

            let oldCount = existingSchedules.count
            let passedCount = existingSchedules.filter { schedule in
                guard let timestamp = schedule["date"] as? TimeInterval,
                      let duration = schedule["duration"] as? Double else { return false }
                let endTime = Date(timeIntervalSince1970: timestamp).addingTimeInterval(duration)
                return endTime < now
            }.count

        }

        // Reschedule with new rolling window
        scheduleRollingWindow(from: storage, duration: duration, selectedPrayers: selectedPrayers)

        // Count prayers after update
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let newSchedules = groupDefaults.object(forKey: prayerScheduleKey) as? [[String: Any]] {
        }
    }

    // MARK: - Manual Blocking

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
        } catch {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            let ts = formatter.string(from: startTime)
        }
    }
    
    /// Schedule blocking for multiple prayer times (up to 20 schedules)
    /// - Parameters:
    ///   - prayerTimes: Array of prayer times to schedule
    ///   - duration: Blocking duration in minutes
    ///   - selectedPrayers: Set of selected prayer names
    ///   - prePrayerBuffer: Buffer time in minutes to start blocking BEFORE prayer time (default: 0)
    ///   - scheduleTime: The timestamp to use for all comparisons (for consistency)
    /// - Returns: true if at least one prayer was successfully scheduled
    @discardableResult
    func schedulePrayerTimeBlocking(prayerTimes: [PrayerTime], duration: Double, selectedPrayers: Set<String>, prePrayerBuffer: Double = 0, scheduleTime: Date? = nil) -> Bool {
        // Simplified: always compute next up-to-20 selected future prayers from now and try to schedule them.
        // Avoid relying on saved schedules to decide capacity, since UI may persist previews.
        // Use provided scheduleTime or capture now - but use consistently throughout
        let now = scheduleTime ?? Date()

        // CRITICAL: Check if apps are selected before scheduling
        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty

        if !hasAppsSelected {
            stopAllMonitoring()
            return false
        }

        // Note: Premium check is handled by the caller (UI layer).
        // If this method is called, we trust that premium status has already been verified.

        if let last = lastScheduleInvocationAt {
            let delta = now.timeIntervalSince(last)
            if delta < 3 {
                let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .medium
            }
        }
        lastScheduleInvocationAt = now
        // Calculate buffer in seconds upfront for filtering
        let bufferSeconds = prePrayerBuffer * 60

        // Ensure stable ordering by start date, then keep at most one of each prayer per day
        // Filter by blocking start time (prayer date - buffer), not prayer date
        let sortedFutureSelected = prayerTimes
            .filter { prayer in
                let blockingStartTime = prayer.date.addingTimeInterval(-bufferSeconds)
                return blockingStartTime > now && selectedPrayers.contains(prayer.name)
            }
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
        var currentActiveCount = activeActivityNames.count
        var availableSlots = max(0, maxSchedules - currentActiveCount)

        if availableSlots == 0 {
            // Clear some old activities to make room
            performAggressiveCleanup()
            // Recalculate available slots after cleanup
            currentActiveCount = activeActivityNames.count
            availableSlots = max(0, maxSchedules - currentActiveCount)
        }

        let prayersToAdd = Array(uniquePerDay.prefix(min(availableSlots > 0 ? availableSlots : maxSchedules, maxSchedules)))
        guard !prayersToAdd.isEmpty else {
            print("❌ No capacity to schedule new prayers")
            return false
        }

        var newActivityNames: [DeviceActivityName] = []
        var scheduledCount = 0
        var failedCount = 0
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        // bufferSeconds already calculated above

        // Plan log: show which activity names we are about to request
        do {
            let planned = prayersToAdd.map { prayer in
                let ts = Int(prayer.date.timeIntervalSince1970)
                return "Prayer_\(prayer.name)_\(ts)"
            }
        }

        for prayer in prayersToAdd {
            // Skip past prayers (accounting for buffer) - use consistent timestamp
            let effectiveStartTime = prayer.date.addingTimeInterval(-bufferSeconds)
            if effectiveStartTime <= now {
                // Silenced: skip past log
                continue
            }

            // Calculate duration in seconds - duration is measured FROM PRAYER TIME
            let deviceActivityDurationSeconds = duration * 60

            // Apply buffer: start blocking BEFORE the actual prayer time
            // Duration is measured from prayer time, not blocking start
            // Example: If Dhuhr is 12:30 PM, buffer is 10 min, duration is 15 min:
            //   - Blocking starts at 12:20 PM (10 min before prayer)
            //   - Blocking ends at 12:45 PM (15 min after prayer)
            //   - Total blocked time = buffer + duration = 25 min
            let startTime = prayer.date.addingTimeInterval(-bufferSeconds)
            let endTime = prayer.date.addingTimeInterval(deviceActivityDurationSeconds)
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
            }
        }
        
        // Add new activities to tracked list (don't replace, append)
        activeActivityNames.append(contentsOf: newActivityNames)
        
        // Persist the schedules we attempted to schedule, so other components have consistent view
        saveScheduleToUserDefaults(prayersToAdd, duration: duration)

        // Summary log to show how many the OS accepted vs attempted
        let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .medium

        // Log what is currently monitored according to the monitor extension (ground truth)
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            let activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            let ts = formatter.string(from: Date())
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
            }
        }

        // Return true if at least one prayer was successfully scheduled
        return scheduledCount > 0
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
    func stopAllMonitoring() {
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
        let selectedFajr = groupDefaults?.object(forKey: "focusSelectedFajr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedFajr") as? Bool ?? false
        let selectedDhuhr = groupDefaults?.object(forKey: "focusSelectedDhuhr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedDhuhr") as? Bool ?? false
        let selectedAsr = groupDefaults?.object(forKey: "focusSelectedAsr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedAsr") as? Bool ?? false
        let selectedMaghrib = groupDefaults?.object(forKey: "focusSelectedMaghrib") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedMaghrib") as? Bool ?? false
        let selectedIsha = groupDefaults?.object(forKey: "focusSelectedIsha") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedIsha") as? Bool ?? false
        
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
    
    private var lastRescheduleTime: Date = Date.distantPast
    private let rescheduleDebounceInterval: TimeInterval = 1.0
    
    /// Force complete clear and reschedule all prayers with current settings
    /// - Parameters:
    ///   - prayerTimes: Array of prayer times to schedule
    ///   - duration: Blocking duration in minutes
    ///   - selectedPrayers: Set of selected prayer names
    ///   - prePrayerBuffer: Buffer time in minutes to start blocking BEFORE prayer time (default: 0)
    func forceCompleteReschedule(prayerTimes: [PrayerTime], duration: Double, selectedPrayers: Set<String>, prePrayerBuffer: Double = 0) {
        // IMPORTANT: Capture timestamp ONCE and use it throughout to avoid race conditions
        let scheduleTime = Date()

        // Debounce to prevent duplicate scheduling within 1 second
        if scheduleTime.timeIntervalSince(lastRescheduleTime) < rescheduleDebounceInterval {
            return
        }

        lastRescheduleTime = scheduleTime

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

        // Brief pause to allow activities to stop (reduced from 2 seconds)
        Thread.sleep(forTimeInterval: 0.1)

        // Calculate buffer in seconds
        let bufferSeconds = prePrayerBuffer * 60

        // Now schedule fresh with current settings - use captured scheduleTime for consistency
        let futurePrayers = prayerTimes.filter { $0.date.addingTimeInterval(-bufferSeconds) > scheduleTime }
        let prayersToSchedule = Array(futurePrayers.filter { selectedPrayers.contains($0.name) }.prefix(20))

        guard !prayersToSchedule.isEmpty else {
            return
        }

        var successfullyScheduled = 0
        var newActivityNames: [DeviceActivityName] = []

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        // Schedule prayers serially to avoid thread-safety issues with DeviceActivityCenter
        for prayer in prayersToSchedule {
            // Skip past prayers (accounting for buffer) - use captured scheduleTime for consistency
            let effectiveStartTime = prayer.date.addingTimeInterval(-bufferSeconds)
            if effectiveStartTime <= scheduleTime {
                continue
            }

            // Calculate duration in seconds - duration is measured FROM PRAYER TIME
            let deviceActivityDurationSeconds = duration * 60
            // Apply buffer: start blocking BEFORE the actual prayer time
            // Duration is measured from prayer time, not blocking start
            let prayerStartTime = prayer.date.addingTimeInterval(-bufferSeconds)
            let prayerEndTime = prayer.date.addingTimeInterval(deviceActivityDurationSeconds)

            // Create unique activity name with normalized timestamp
            let normalizedTs = self.normalizeTimestamp(prayerStartTime)
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
                try self.center.startMonitoring(activityName, during: schedule)
                newActivityNames.append(activityName)
                successfullyScheduled += 1
            } catch {
                let ts = formatter.string(from: prayerStartTime)
                print("⚠️ [PrayerBlocking] Failed to schedule \(prayer.name) at \(ts): \(error)")
            }
        }

        // Update tracked activities
        activeActivityNames = newActivityNames
        
        // Summary log to match the format from regular scheduling
        let attemptedCount = prayersToSchedule.count
        let failedCount = attemptedCount - successfullyScheduled
        
        // Save the new schedule to UserDefaults for future cleanup
        saveScheduleToUserDefaults(prayersToSchedule, duration: duration)
    }
    
    /// Save prayer schedule to UserDefaults for cleanup tracking
    private func saveScheduleToUserDefaults(_ prayerTimes: [PrayerTime], duration: Double) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { 
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
        groupDefaults.synchronize() // Force immediate write to disk
    }
    
    /// Reset the initial scheduling flag (for debugging or complete reset)
    func resetSchedulingFlag() {
        UserDefaults.standard.removeObject(forKey: "hasScheduledInitialBlocking")
    }
    
    // Early stop validation removed; durations are used as-is
    
} 