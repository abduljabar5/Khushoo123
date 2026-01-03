import Foundation
import Combine
import ManagedSettings
import DeviceActivity
import UIKit

@MainActor
class BlockingStateService: ObservableObject {
    static let shared = BlockingStateService()
    
    @Published var isCurrentlyBlocking = false
    @Published var currentPrayerName = "" {
        didSet {
            // Persist current prayer name (skip during initialization)
            if !isInitializing, let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(currentPrayerName, forKey: "currentPrayerName")
            }
        }
    }
    @Published var blockingEndTime: Date? {
        didSet {
            // Persist blocking end time (skip during initialization)
            if !isInitializing, let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                if let endTime = blockingEndTime {
                    groupDefaults.set(endTime.timeIntervalSince1970, forKey: "blockingEndTime")
                } else {
                    groupDefaults.removeObject(forKey: "blockingEndTime")
                }
            }
        }
    }
    @Published var timeRemaining: TimeInterval = 0
    @Published var isWaitingForVoiceConfirmation = false {
        didSet {
            // Persist voice confirmation state to UserDefaults (skip during initialization)
            if !isInitializing, let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(isWaitingForVoiceConfirmation, forKey: "isWaitingForVoiceConfirmation")
            }
        }
    }
    
    // Track start time of current blocking interval for early unlock countdown (strict mode off)
    @Published var blockingStartTime: Date?
    // Mirror of strict mode for UI
    @Published var isStrictModeEnabled: Bool = false
    // Whether we're within an active scheduled window (independent of early unlock)
    @Published var isInActiveScheduleWindow: Bool = false
    // If user has unlocked early, this is the end time of the current interval
    @Published var currentEarlyUnlockedUntil: Date?
    // Whether early unlock is currently active (within the active interval)
    @Published var isEarlyUnlockedActive: Bool = false
    // Mirror of extension signal that shields are actually applied
    @Published var appsActuallyBlocked: Bool = false
    // Early-unlock availability moment (5 minutes after prayer start)
    @Published var earlyUnlockAvailableAt: Date?
    
    /// Whether strict mode can be toggled safely (not during active blocking)
    var canToggleStrictMode: Bool {
        return !isCurrentlyBlocking && !appsActuallyBlocked && !isWaitingForVoiceConfirmation
    }
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isInitializing = true
    private var lastMonitoredActivitiesSignature = ""
    
    private init() {
        // Load persisted state
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            isWaitingForVoiceConfirmation = groupDefaults.bool(forKey: "isWaitingForVoiceConfirmation")
            currentPrayerName = groupDefaults.string(forKey: "currentPrayerName") ?? ""
            
            if let endTimeTimestamp = groupDefaults.object(forKey: "blockingEndTime") as? TimeInterval {
                blockingEndTime = Date(timeIntervalSince1970: endTimeTimestamp)
            }
            if let startTimeTimestamp = groupDefaults.object(forKey: "blockingStartTime") as? TimeInterval {
                blockingStartTime = Date(timeIntervalSince1970: startTimeTimestamp)
            } else if let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] {
                let now = Date()
                for schedule in schedules {
                    if let ts = schedule["date"] as? TimeInterval,
                       let duration = schedule["duration"] as? Double {
                        let start = Date(timeIntervalSince1970: ts)
                        let end = start.addingTimeInterval(duration)
                        if now >= start && now <= end {
                            blockingStartTime = start
                            groupDefaults.set(ts, forKey: "blockingStartTime")
                            break
                        }
                    }
                }
            }
            
            // Load strict mode setting
            let strictModeStandard = UserDefaults.standard.bool(forKey: "focusStrictMode")
            let strictModeGroup = groupDefaults.bool(forKey: "focusStrictMode")
            isStrictModeEnabled = strictModeStandard || strictModeGroup

            // Restore persisted early-unlock target if present
            if let availTs = groupDefaults.object(forKey: "earlyUnlockAvailableAt") as? TimeInterval {
                earlyUnlockAvailableAt = Date(timeIntervalSince1970: availTs)
            }
            // Debug: initialization state (silenced to reduce console noise)
        }
        
        // Mark initialization as complete
        isInitializing = false
        
        startMonitoring()
    }
    
    private func startMonitoring() {
        // Initial check
        checkBlockingStatus()

        // Poll at 15-second interval to reduce CPU usage while maintaining responsiveness
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkBlockingStatus()
            }
        }

        // Also observe a nonce the monitor updates to immediately mirror monitored list without waiting 5s
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: UserDefaults(suiteName: "group.fm.mrc.Dhikr"), queue: .main) { [weak self] _ in
            self?.checkBlockingStatus()
        }
    }
    
    /// Validate and recover from state mismatches between extension and main app
    private func validateAndRecoverBlockingState() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let appsBlocked = groupDefaults.bool(forKey: "appsActuallyBlocked")
        let store = ManagedSettingsStore()
        
        // Check if ManagedSettings has any restrictions applied
        let hasRestrictions = (store.shield.applications?.count ?? 0) > 0 ||
                            store.shield.applicationCategories != nil ||
                            (store.shield.webDomains?.count ?? 0) > 0
        
        // Detect state mismatch
        if appsBlocked != hasRestrictions {
            print("⚠️ State mismatch detected: appsActuallyBlocked=\(appsBlocked), hasRestrictions=\(hasRestrictions)")
            
            // Trust the ManagedSettings state as ground truth
            if hasRestrictions {
                groupDefaults.set(true, forKey: "appsActuallyBlocked")
                appsActuallyBlocked = true
                print("🔧 Recovery: Set appsActuallyBlocked=true based on active restrictions")
            } else {
                groupDefaults.set(false, forKey: "appsActuallyBlocked")
                appsActuallyBlocked = false
                // Clear any lingering blocking state
                groupDefaults.removeObject(forKey: "blockingStartTime")
                groupDefaults.removeObject(forKey: "earlyUnlockAvailableAt")
                blockingStartTime = nil
                earlyUnlockAvailableAt = nil
                print("🔧 Recovery: Cleared blocking state - no active restrictions found")
            }
        }
    }
    
    func checkBlockingStatus() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            updateBlockingState(isBlocking: false, prayerName: "", endTime: nil)
            return
        }
        
        // Validate state before proceeding
        validateAndRecoverBlockingState()
        
        let prayerSchedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] ?? []

        // Mirror and log the activities that the monitor extension says are CURRENTLY being monitored
        // so logs are visible from the main app console as well.
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        let nowDate = Date()
        let tsNow = formatter.string(from: nowDate)
        var activeNames = groupDefaults.stringArray(forKey: "currentlyMonitoredActivityNames") ?? []

        // Prune stale entries whose planned end has passed by more than 2 minutes
        var pruned: [String] = []
        var removedCount = 0
        for raw in activeNames {
            let parts = raw.split(separator: "_")
            guard parts.count >= 3, let startTs = TimeInterval(parts.last!) else {
                pruned.append(raw)
                continue
            }
            let nameStr = String(parts[1])
            // Try to find matching schedule within ±5 minutes of the activity name timestamp
            var plannedEndTs: TimeInterval? = nil
            if let match = prayerSchedules.first(where: { sched in
                guard let n = sched["name"] as? String, let ts = sched["date"] as? TimeInterval else { return false }
                return n == nameStr && abs(ts - startTs) <= 300
            }), let dur = match["duration"] as? Double, let schedStart = match["date"] as? TimeInterval {
                plannedEndTs = schedStart + dur
            } else {
                // Fallback to configured duration using the activity name timestamp
                let durMin = groupDefaults.object(forKey: "focusBlockingDuration") as? Double ?? UserDefaults.standard.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
                plannedEndTs = startTs + durMin * 60.0
            }
            if let endTs = plannedEndTs {
                if nowDate.timeIntervalSince1970 > endTs + 120 { // 2-minute grace
                    removedCount += 1
                    continue // drop stale
                }
            }
            pruned.append(raw)
        }
        if removedCount > 0 {
            groupDefaults.set(pruned, forKey: "currentlyMonitoredActivityNames")
        }

        // Log the current (pruned) monitored list with tolerant end-time resolution
        var lines: [String] = []
        lines.append("count=\(pruned.count)")
        for raw in pruned {
            let parts = raw.split(separator: "_")
            var startStr = ""
            var endStr = "?"
            var nameStr: String = raw
            if parts.count >= 3, let startTs = TimeInterval(parts.last!) {
                let startDate = Date(timeIntervalSince1970: startTs)
                startStr = formatter.string(from: startDate)
                nameStr = String(parts[1])
                if let match = prayerSchedules.first(where: { sched in
                    guard let n = sched["name"] as? String, let ts = sched["date"] as? TimeInterval else { return false }
                    return n == nameStr && abs(ts - startTs) <= 300
                }), let dur = match["duration"] as? Double, let schedStart = match["date"] as? TimeInterval {
                    let endDate = Date(timeIntervalSince1970: schedStart).addingTimeInterval(dur)
                    endStr = formatter.string(from: endDate)
                } else {
                    let durMin = groupDefaults.object(forKey: "focusBlockingDuration") as? Double ?? UserDefaults.standard.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
                    let endDate = Date(timeIntervalSince1970: startTs + durMin * 60.0)
                    endStr = formatter.string(from: endDate)
                }
            }
            lines.append(" • activity=\(raw) | prayer=\(nameStr) | start=\(startStr) | end=\(endStr)")
        }
        let signature = lines.joined(separator: "\n")
        print("📡 [\(tsNow)] Currently monitored (from monitor):\n\(signature)")

        // If we have no prayer schedules, we cannot compute active windows; bail after logging
        guard !prayerSchedules.isEmpty else {
            updateBlockingState(isBlocking: false, prayerName: "", endTime: nil)
            return
        }

        
        let now = Date()
        // Read strict mode from both sources to ensure consistency
        let strictModeStandard = UserDefaults.standard.bool(forKey: "focusStrictMode")
        let strictModeGroup = groupDefaults.bool(forKey: "focusStrictMode")
        let strictMode = strictModeStandard || strictModeGroup // Use OR to be safe
        isStrictModeEnabled = strictMode
        appsActuallyBlocked = groupDefaults.bool(forKey: "appsActuallyBlocked")

        // If extension says apps are actually blocked and we don't have a start time yet, set it now
        if appsActuallyBlocked && blockingStartTime == nil {
            blockingStartTime = now
            groupDefaults.set(now.timeIntervalSince1970, forKey: "blockingStartTime")
        }
        // Note: we compute earlyUnlockAvailableAt after we discover activeStart/nextStart below
        
        // Ensure both UserDefaults are in sync (but guard against unsafe enable during active blocking/unlock/voice)
        if strictModeStandard != strictModeGroup {
            let safeStrict = strictModeStandard
            groupDefaults.set(safeStrict, forKey: "focusStrictMode")
            groupDefaults.synchronize()
        }

        // If countdown has already reached zero, freeze it for this interval so it
        // doesn't remap to the next prayer on relaunch. We only clear this when
        // the interval ends or when apps are no longer blocked.
        if let target = earlyUnlockAvailableAt, now >= target {
            // Lock state: keep earlyUnlockAvailableAt as-is; do not recompute mapping
        } else {
            // We will update earlyUnlockAvailableAt below as needed
        }

        // Debug: high-level heartbeat only (commented out verbose schedule logs)
        // let earlyUnlockTs = groupDefaults.object(forKey: "earlyUnlockedUntil") as? TimeInterval
        // print("🔍 [EarlyUnlockDebug] check — now=\(now), strict=\(strictMode), schedules=\(prayerSchedules.count), start=\(String(describing: blockingStartTime)), end=\(String(describing: blockingEndTime)), earlyUnlockedUntil=\(String(describing: earlyUnlockTs)), appsBlocked=\(appsActuallyBlocked)")
        
        // Discover the active schedule window (if any) and track next upcoming start
        var activeStart: Date?
        var activeEnd: Date?
        var activeName: String?
        var nextStart: Date?
        for schedule in prayerSchedules {
            guard let name = schedule["name"] as? String,
                  let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double else { continue }
            let start = Date(timeIntervalSince1970: timestamp)
            let end = start.addingTimeInterval(duration)
            if now >= start && now <= end {
                activeStart = start
                activeEnd = end
                activeName = name
                break
            } else if start > now {
                if nextStart == nil || start < nextStart! { nextStart = start }
            }
        }

        // Lock early unlock to the original prayer that triggered this blocking session
        // Only set it once when apps first become blocked, and persist the prayer name
        if appsActuallyBlocked && earlyUnlockAvailableAt == nil {
            if let blkStart = blockingStartTime {
                // Find the prayer that best matches when blocking started
                let mappedPrayer = prayerSchedules
                    .compactMap { schedule -> (name: String, start: Date, duration: Double)? in
                        guard let name = schedule["name"] as? String,
                              let ts = schedule["date"] as? TimeInterval,
                              let duration = schedule["duration"] as? Double else { return nil }
                        return (name, Date(timeIntervalSince1970: ts), duration)
                    }
                    .filter { prayer in
                        // Prayer must have started before or at blocking time
                        // and blocking must be within the prayer window
                        let prayerEnd = prayer.start.addingTimeInterval(prayer.duration)
                        return prayer.start <= blkStart && blkStart <= prayerEnd
                    }
                    .min(by: { abs($0.start.timeIntervalSince(blkStart)) < abs($1.start.timeIntervalSince(blkStart)) })
                
                if let prayer = mappedPrayer {
                    let target = prayer.start.addingTimeInterval(5 * 60)
                    earlyUnlockAvailableAt = target
                    if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                        groupDefaults.set(target.timeIntervalSince1970, forKey: "earlyUnlockAvailableAt")
                        groupDefaults.set(prayer.name, forKey: "earlyUnlockPrayerName")
                        groupDefaults.set(prayer.start.timeIntervalSince1970, forKey: "earlyUnlockPrayerStart")
                    }
                } else if let activeStart = activeStart, let activeName = activeName {
                    // Fallback: use the currently active prayer window
                    let target = activeStart.addingTimeInterval(5 * 60)
                    earlyUnlockAvailableAt = target
                    if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                        groupDefaults.set(target.timeIntervalSince1970, forKey: "earlyUnlockAvailableAt")
                        groupDefaults.set(activeName, forKey: "earlyUnlockPrayerName")
                        groupDefaults.set(activeStart.timeIntervalSince1970, forKey: "earlyUnlockPrayerStart")
                    }
                }
            }
        }

        // If user has performed an early unlock, validate it matches the current prayer window
        if let earlyUnlockedUntilTs = groupDefaults.object(forKey: "earlyUnlockedUntil") as? TimeInterval {
            let earlyUnlockedUntil = Date(timeIntervalSince1970: earlyUnlockedUntilTs)
            currentEarlyUnlockedUntil = earlyUnlockedUntil
            
            // Validate early unlock with saved prayer information
            let savedPrayerName = groupDefaults.string(forKey: "earlyUnlockPrayerName")
            let savedPrayerStartTs = groupDefaults.object(forKey: "earlyUnlockPrayerStart") as? TimeInterval
            
            if let aStart = activeStart, let aEnd = activeEnd, let aName = activeName {
                // Check if early unlock matches current active window
                let matchesPrayer: Bool
                if let savedName = savedPrayerName, let savedStartTs = savedPrayerStartTs {
                    // Both values exist, check if they match current window
                    matchesPrayer = (savedName == aName) && (abs(aStart.timeIntervalSince1970 - savedStartTs) < 60)
                } else {
                    // Legacy early unlock without saved prayer info - allow it for backward compatibility
                    matchesPrayer = true
                }
                
                if matchesPrayer && earlyUnlockedUntil >= aStart && earlyUnlockedUntil <= aEnd {
                    if now < earlyUnlockedUntil {
                        isInActiveScheduleWindow = true
                        isEarlyUnlockedActive = true
                        // Do NOT force strict mode off; UI disables toggle separately
                        // Not blocking during early unlock
                        updateBlockingState(isBlocking: false, prayerName: aName, endTime: aEnd)
                        return
                    }
                } else {
                    // Early unlock doesn't match current interval; clear it
                    groupDefaults.removeObject(forKey: "earlyUnlockedUntil")
                    groupDefaults.removeObject(forKey: "earlyUnlockPrayerName")
                    groupDefaults.removeObject(forKey: "earlyUnlockPrayerStart")
                    currentEarlyUnlockedUntil = nil
                    isEarlyUnlockedActive = false
                    // Silenced: mismatched early unlock log
                }
            } else {
                // No active window; if early unlock time passed, clear it
                if now >= earlyUnlockedUntil {
                    groupDefaults.removeObject(forKey: "earlyUnlockedUntil")
                    groupDefaults.removeObject(forKey: "earlyUnlockPrayerName")
                    groupDefaults.removeObject(forKey: "earlyUnlockPrayerStart")
                    currentEarlyUnlockedUntil = nil
                    isEarlyUnlockedActive = false
                    // Silenced: expired early unlock log
                }
            }
        } else {
            currentEarlyUnlockedUntil = nil
            isEarlyUnlockedActive = false
        }

        // If we already have a known active interval, keep it active until its end
        if let end = blockingEndTime, Date() <= end {
            // Ensure we keep reporting as blocking until end (unless strict mode requires confirmation)
            // If strict mode ON while actively blocked, do not allow early-unlock banner; state remains blocking
            updateBlockingState(isBlocking: true, prayerName: currentPrayerName, endTime: end)
            return
        }
        
        
        // Check if DeviceActivityMonitor set the voice confirmation flag
        let waitingForVoiceFromMonitor = groupDefaults.bool(forKey: "isWaitingForVoiceConfirmation")
        
        // Find if we're currently in a blocking period
        for (_, schedule) in prayerSchedules.enumerated() {
            guard let name = schedule["name"] as? String,
                  let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double else { 
                continue 
            }
            
            // Early stop fields removed; use duration as the end time
            
            let prayerStartTime = Date(timeIntervalSince1970: timestamp)
            let effectiveEndTime = prayerStartTime.addingTimeInterval(duration)
            
            // Check if we're currently in the blocking period (using effective end time)
            if now >= prayerStartTime && now <= effectiveEndTime {
                isInActiveScheduleWindow = true
                // If we’re in an active window but not in an early unlock path, ensure flag is false
                if currentEarlyUnlockedUntil == nil || now >= (currentEarlyUnlockedUntil ?? now) {
                    isEarlyUnlockedActive = false
                }
                // Set start time if entering a new blocking window
                if blockingStartTime == nil || currentPrayerName != name {
                    blockingStartTime = prayerStartTime
                    // Persist start time for continuity
                    groupDefaults.set(prayerStartTime.timeIntervalSince1970, forKey: "blockingStartTime")
                    // Debug log removed
                }
                // Set early-unlock availability to 5 minutes after prayer start
                let avail = prayerStartTime.addingTimeInterval(5 * 60)
                earlyUnlockAvailableAt = avail
                groupDefaults.set(avail.timeIntervalSince1970, forKey: "earlyUnlockAvailableAt")
                updateBlockingState(isBlocking: true, prayerName: name, endTime: effectiveEndTime)
                return
            }
            
            // Early stopping logic removed
            
            // In strict mode, if prayer time just ended (using effective end time), wait for voice confirmation
            if strictMode && now > effectiveEndTime && now <= effectiveEndTime.addingTimeInterval(300) { // 5 minute grace period
                // Always wait for voice confirmation in strict mode, regardless of monitor flag
                isWaitingForVoiceConfirmation = true
                updateBlockingState(isBlocking: true, prayerName: name, endTime: effectiveEndTime)
                return
            }
        }
        
        // Not currently blocking
        // Only clear voice confirmation if we're not in strict mode or grace period expired
        if isWaitingForVoiceConfirmation && !strictMode {
            isWaitingForVoiceConfirmation = false
        }
        
        // If we're waiting for voice confirmation in strict mode, keep the blocking state active
        if strictMode && isWaitingForVoiceConfirmation {
            // Keep the current prayer name and show as still blocking for UI purposes
            return
        }
        
        isInActiveScheduleWindow = false
        isEarlyUnlockedActive = false
        updateBlockingState(isBlocking: false, prayerName: "", endTime: nil)
        blockingStartTime = nil
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: "blockingStartTime")
            // Clear early unlock tracking when no longer blocking
            groupDefaults.removeObject(forKey: "earlyUnlockAvailableAt")
            groupDefaults.removeObject(forKey: "earlyUnlockPrayerName")
            groupDefaults.removeObject(forKey: "earlyUnlockPrayerStart")
        }
        earlyUnlockAvailableAt = nil
    }
    
    private func updateBlockingState(isBlocking: Bool, prayerName: String, endTime: Date?) {
        let wasBlocking = isCurrentlyBlocking
        let wasWaiting = isWaitingForVoiceConfirmation
        
        isCurrentlyBlocking = isBlocking
        currentPrayerName = prayerName
        blockingEndTime = endTime
        
        if let endTime = endTime {
            timeRemaining = max(0, endTime.timeIntervalSince(Date()))
        } else {
            timeRemaining = 0
            // Don't automatically clear isWaitingForVoiceConfirmation here
            // It should only be cleared when clearBlocking() is called
        }
        // Silenced: state-change debug log
    }
    
    func clearBlocking() {
        // Mark prayers as completed when user confirms with Wallahi
        markPrayersAsCompleted()

        // Clear the actual ManagedSettings restrictions
        let store = ManagedSettingsStore()
        store.clearAllSettings()

        // Clear the voice confirmation flag in UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(false, forKey: "isWaitingForVoiceConfirmation")
            groupDefaults.removeObject(forKey: "earlyUnlockedUntil")
            groupDefaults.set(false, forKey: "appsActuallyBlocked")
            // Clear early unlock prayer tracking
            groupDefaults.removeObject(forKey: "earlyUnlockAvailableAt")
            groupDefaults.removeObject(forKey: "earlyUnlockPrayerName")
            groupDefaults.removeObject(forKey: "earlyUnlockPrayerStart")
        }

        // Update local state
        isWaitingForVoiceConfirmation = false
        isEarlyUnlockedActive = false
        appsActuallyBlocked = false
        earlyUnlockAvailableAt = nil
        updateBlockingState(isBlocking: false, prayerName: "", endTime: nil)
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.removeObject(forKey: "blockingStartTime")
        }
    }

    private func markPrayersAsCompleted() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }

        let now = Date()
        let today = dateKey(for: now)
        // Use App Group defaults for completed prayers so Widget can see/modify them
        let completedKey = "completed_\(today)"
        var completed = groupDefaults.array(forKey: completedKey) as? [String] ?? []

        // In strict mode, if blocking has been active for multiple prayer times,
        // mark all prayers between blockingStartTime and now as completed
        if isStrictModeEnabled, let blockingStart = blockingStartTime {
            if let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] {
                let prayersToMark = findPrayersInTimeRange(schedules: schedules, from: blockingStart, to: now)

                for prayerName in prayersToMark {
                    if !completed.contains(prayerName) && prayerName != "Sunrise" {
                        completed.append(prayerName)
                        print("🕌 Marking \(prayerName) as completed (strict mode bulk completion)")
                    }
                }
            }
        } else {
            // Regular mode: only mark the current prayer as completed
            if !currentPrayerName.isEmpty && currentPrayerName != "Sunrise" && !completed.contains(currentPrayerName) {
                completed.append(currentPrayerName)
                print("🕌 Marking \(currentPrayerName) as completed (Wallahi confirmation)")
            }
        }

        // Save the updated completed prayers to App Group
        groupDefaults.set(completed, forKey: completedKey)

        // Post notification to update UI if PrayerTimeViewModel is active
        NotificationCenter.default.post(name: NSNotification.Name("PrayersCompletedUpdated"), object: nil)
    }

    private func findPrayersInTimeRange(schedules: [[String: Any]], from startTime: Date, to endTime: Date) -> [String] {
        var prayersInRange: [String] = []

        for schedule in schedules {
            guard let name = schedule["name"] as? String,
                  let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double else { continue }

            let prayerStart = Date(timeIntervalSince1970: timestamp)
            let prayerEnd = prayerStart.addingTimeInterval(duration)

            // Include prayers that overlap with the blocking period
            if prayerStart <= endTime && prayerEnd >= startTime {
                prayersInRange.append(name)
            }
        }

        return prayersInRange
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Force immediate check of blocking status (useful when app becomes active or goes to background)
    func forceCheck() {
        checkBlockingStatus()
        
        // Background task scheduling for early stop removed
    }
    
    /// Returns time remaining (in seconds) until early unlock becomes available.
    /// This counts down to 5 minutes after the prayer start time, regardless of when shields applied.
    func timeUntilEarlyUnlock() -> TimeInterval {
        let target = earlyUnlockAvailableAt ?? (blockingStartTime?.addingTimeInterval(5 * 60))
        guard let availableAt = target else { return 0 }
        return max(0, availableAt.timeIntervalSince(Date()))
    }
    
    /// Perform early unlock for the current interval (strict mode must be off)
    func earlyUnlockCurrentInterval() {
        guard !isStrictModeEnabled else { return }
        guard let endTime = blockingEndTime else { return }

        // Mark current prayer as completed when user early unlocks
        markCurrentPrayerAsCompleted()

        // Clear ManagedSettings to unblock immediately
        let store = ManagedSettingsStore()
        store.clearAllSettings()

        // Mark early-unlocked window until the scheduled end and immediately hide banners
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(endTime.timeIntervalSince1970, forKey: "earlyUnlockedUntil")
            groupDefaults.set(false, forKey: "appsActuallyBlocked")
            groupDefaults.removeObject(forKey: "blockingStartTime")

            // Keep the prayer tracking info for validation
            // Don't remove earlyUnlockPrayerName and earlyUnlockPrayerStart
            // They will be cleared when the interval ends or a new prayer starts

            currentEarlyUnlockedUntil = endTime
            isEarlyUnlockedActive = true
            appsActuallyBlocked = false
        }

        // Update local state
        updateBlockingState(isBlocking: false, prayerName: "", endTime: nil)
    }

    private func markCurrentPrayerAsCompleted() {
        guard !currentPrayerName.isEmpty && currentPrayerName != "Sunrise" else { return }

        let today = dateKey(for: Date())
        let completedKey = "completed_\(today)"
        
        // Use App Group defaults
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        var completed = groupDefaults.array(forKey: completedKey) as? [String] ?? []

        if !completed.contains(currentPrayerName) {
            completed.append(currentPrayerName)
            groupDefaults.set(completed, forKey: completedKey)
            print("🕌 Marking \(currentPrayerName) as completed (early unlock)")

            // Post notification to update UI
            NotificationCenter.default.post(name: NSNotification.Name("PrayersCompletedUpdated"), object: nil)
        }
    }
    // Early stop background task helpers removed
    
    deinit {
        timer?.invalidate()
    }
}

// Extension moved to PrayerHelpers.swift to avoid duplication 