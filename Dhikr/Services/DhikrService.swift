//
//  DhikrService.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import Foundation
import UIKit
import WidgetKit

// MARK: - Notification Names
extension Notification.Name {
    static let dhikrCountUpdated = Notification.Name("dhikrCountUpdated")
}



// MARK: - Dhikr Goals Model
struct DhikrGoals: Codable {
    var subhanAllah: Int = 33
    var alhamdulillah: Int = 33
    var astaghfirullah: Int = 33

    var totalDailyGoal: Int {
        subhanAllah + alhamdulillah + astaghfirullah
    }
}

// MARK: - Dhikr Service
class DhikrService: ObservableObject {
    // MARK: - Properties
    @Published var dhikrCount: DhikrCount {
        didSet {
            saveDhikrCount()
            updateTodayStats()
        }
    }
    
    // MARK: - Performance Optimization: Batched UserDefaults Operations
    private var pendingUpdates: [String: Any] = [:]
    private var updateTimer: Timer?
    
    private func batchUserDefaultsUpdate(key: String, value: Any) {
        pendingUpdates[key] = value
        
        // Debounce updates - write after 0.5 seconds of inactivity
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.flushPendingUpdates()
        }
    }
    
    private func flushPendingUpdates() {
        guard !pendingUpdates.isEmpty else { return }
        
        // Batch write all pending updates
        for (key, value) in pendingUpdates {
            userDefaults.set(value, forKey: key)
        }
        
        pendingUpdates.removeAll()
    }
    
    // Override streak setter to use batched updates
    @Published var streak: Int = 0 {
        didSet {
            // Update highest streak when current streak changes
            if streak > highestStreak {
                highestStreak = streak
                batchUserDefaultsUpdate(key: highestStreakKey, value: highestStreak)
            }
            batchUserDefaultsUpdate(key: streakKey, value: streak)
        }
    }
    @Published var highestStreak: Int = 0
    @Published var goal: DhikrGoals {
        didSet {
            saveGoals()
        }
    }
    
    // MARK: - UserDefaults Keys
    private let dhikrCountKey = "dhikrCount"
    private let streakKey = "streak"
    private let highestStreakKey = "highestStreak"
    private let lastStreakDateKey = "lastStreakDate"
    private let dailyStatsKey = "dailyStats"
    private let goalsKey = "dhikrGoals"
    private let dhikrEntriesKey = "dhikrEntries"

    // MARK: - UserDefaults
    private let userDefaults: UserDefaults

    // MARK: - Performance Settings
    private let maxEntriesInMemory = 10000 // Keep last 10k entries (~3-4 months of heavy use)
    private let entriesBatchSize = 50 // Write to disk every 50 entries
    private var pendingEntries: [DhikrEntry] = []
    private var entriesWriteTimer: Timer?

    // MARK: - Singleton
    static let shared = DhikrService()

    // MARK: - Initialization
    private init() {
        // Use app group UserDefaults, falling back to standard if not available
        self.userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") ?? UserDefaults.standard
        self.dhikrCount = DhikrService.loadDhikrCount(from: userDefaults)
        self.streak = userDefaults.integer(forKey: streakKey)
        self.highestStreak = userDefaults.integer(forKey: highestStreakKey)
        self.goal = DhikrService.loadGoals(from: userDefaults)
        checkStreakOnLaunch()
        startMidnightResetTimer()
    }
    
    // MARK: - Public Methods
    func incrementDhikr(_ type: DhikrType) {
        dhikrCount.increment(type)

        // Record individual entry with timestamp
        recordEntry(type: type, count: 1)

        // Trigger haptic feedback
        triggerHapticFeedback()

        // Post notification for UI updates
        NotificationCenter.default.post(name: .dhikrCountUpdated, object: type)
        updateTodayStats()
        checkStreak()
    }
    
    func setDhikrCount(_ type: DhikrType, count: Int) {
        let currentCount = dhikrCount.count(for: type)
        let difference = count - currentCount

        dhikrCount.setCount(type, count: count)

        // Record the difference as an entry (if increased)
        if difference > 0 {
            recordEntry(type: type, count: difference)
        }

        // Trigger haptic feedback
        triggerHapticFeedback()

        // Post notification for UI updates
        NotificationCenter.default.post(name: .dhikrCountUpdated, object: type)
        updateTodayStats()
        checkStreak()
    }
    
    /// Increment a dhikr type by a specific amount in one update (for batching sources like Zikr ring)
    func incrementDhikr(_ type: DhikrType, by amount: Int) {
        guard amount > 0 else { return }
        // Ensure daily reset behavior remains consistent
        dhikrCount.resetForNewDay()

        switch type {
        case .subhanAllah:
            dhikrCount.subhanAllah += amount
        case .alhamdulillah:
            dhikrCount.alhamdulillah += amount
        case .astaghfirullah:
            dhikrCount.astaghfirullah += amount
        }
        dhikrCount.lastUpdated = Date()

        // Record batch entry with timestamp
        recordEntry(type: type, count: amount)

        // Single haptic and single notification for the batch
        triggerHapticFeedback()
        NotificationCenter.default.post(name: .dhikrCountUpdated, object: type)
        updateTodayStats()
        checkStreak()
    }
    
    func resetDhikr() {
        dhikrCount = DhikrCount()
        saveDhikrCount()
        updateTodayStats()
    }
    
    func getTodayStats() -> DhikrStats {
        return DhikrStats(
            subhanAllah: dhikrCount.subhanAllah,
            alhamdulillah: dhikrCount.alhamdulillah,
            astaghfirullah: dhikrCount.astaghfirullah,
            total: dhikrCount.totalCount,
            streak: streak
        )
    }
    
    func getWeeklyStats() -> [DailyDhikrStats] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = (weekday + 6) % 7
        let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        let statsDict = loadDailyStats()
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: lastSunday) ?? today
            let key = Self.dateKey(for: date)
            if let stat = statsDict[key] {
                return stat
            } else {
                return DailyDhikrStats(date: date, subhanAllah: 0, alhamdulillah: 0, astaghfirullah: 0, total: 0)
            }
        }
    }
    
    func getMotivationalMessage() -> String {
        return dhikrCount.motivationalMessage
    }
    
    // MARK: - Streak Information
    func getHighestStreakInfo() -> (highest: Int, current: Int, isCurrentBest: Bool, achievement: String) {
        let isCurrentBest = streak == highestStreak && streak > 0
        
        let achievement: String
        if highestStreak == 0 {
            achievement = "Start your dhikr journey!"
        } else if isCurrentBest {
            achievement = "🎉 You're at your best streak!"
        } else if streak == 0 {
            achievement = "Keep going to beat your record!"
        } else {
            let difference = highestStreak - streak
            achievement = "\(difference) days to beat your record!"
        }
        
        return (
            highest: highestStreak,
            current: streak,
            isCurrentBest: isCurrentBest,
            achievement: achievement
        )
    }
    
    // MARK: - Private Methods
    private static func loadDhikrCount(from defaults: UserDefaults) -> DhikrCount {
        let dhikrCountKey = "dhikrCount"
        guard let data = defaults.data(forKey: dhikrCountKey),
              let dhikrCount = try? JSONDecoder().decode(DhikrCount.self, from: data) else {
            return DhikrCount()
        }
        return dhikrCount
    }
    
    private func saveDhikrCount() {
        guard let data = try? JSONEncoder().encode(dhikrCount) else { return }
        userDefaults.set(data, forKey: dhikrCountKey)
        WidgetCenter.shared.reloadAllTimelines() // Force widget to refresh
    }
    
    private func updateTodayStats() {
        var statsDict = loadDailyStats()
        let todayKey = Self.dateKey(for: Date())
        let stat = DailyDhikrStats(
            date: Date(),
            subhanAllah: dhikrCount.subhanAllah,
            alhamdulillah: dhikrCount.alhamdulillah,
            astaghfirullah: dhikrCount.astaghfirullah,
            total: dhikrCount.totalCount
        )
        statsDict[todayKey] = stat
        saveDailyStats(statsDict)
    }
    
    private func loadDailyStats() -> [String: DailyDhikrStats] {
        guard let data = userDefaults.data(forKey: dailyStatsKey),
              let dict = try? JSONDecoder().decode([String: DailyDhikrStats].self, from: data) else {
            return [:]
        }
        return dict
    }
    
    private func saveDailyStats(_ dict: [String: DailyDhikrStats]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        userDefaults.set(data, forKey: dailyStatsKey)
    }
    
    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // --- Streak Logic ---
    private func checkStreakOnLaunch() {
        let lastDate = userDefaults.string(forKey: lastStreakDateKey)
        let todayKey = Self.dateKey(for: Date())
        if lastDate != todayKey {
            checkStreak()
        }
    }
    
    private func checkStreak() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let statsDict = loadDailyStats()
        let todayKey = Self.dateKey(for: today)
        let yesterdayKey = Self.dateKey(for: yesterday)
        let lastDate = userDefaults.string(forKey: lastStreakDateKey)
        
        // If today is a new day
        if lastDate != todayKey {
            // Reset daily counts for new day
            dhikrCount = DhikrCount()
            saveDhikrCount()
            
            // If user did any dhikr yesterday, continue streak
            if let yStat = statsDict[yesterdayKey], yStat.total > 0 {
                streak = userDefaults.integer(forKey: streakKey) + 1
            } else {
                streak = 1
            }
            userDefaults.set(streak, forKey: streakKey)
            userDefaults.set(todayKey, forKey: lastStreakDateKey)
            
            // Post notification for UI updates
            NotificationCenter.default.post(name: .dhikrCountUpdated, object: nil)
        }
    }
    
    // MARK: - Widget Support
    func getRecentDhikrTotals(days: Int = 3) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        let statsDict = loadDailyStats()
        var totals: [Int] = []
        
        for i in 0..<days {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let key = Self.dateKey(for: date)
            let total = statsDict[key]?.total ?? 0
            totals.append(total)
        }
        
        return totals.reversed() // Return in chronological order (oldest first)
    }
    
    func getTotalDhikrForWidget() -> Int {
        return dhikrCount.totalCount
    }
    
    func getDailyStreakForWidget() -> Int {
        return streak
    }
    
    // --- Timer for midnight reset ---
    private var midnightTimer: Timer? = nil

    func startMidnightResetTimer() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        let now = Date()

        // Calculate next midnight (00:01 AM)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 0
        components.minute = 1
        components.second = 0

        var nextMidnight = calendar.date(from: components) ?? now

        // If it's already past 00:01 today, schedule for tomorrow
        if nextMidnight <= now {
            nextMidnight = calendar.date(byAdding: .day, value: 1, to: nextMidnight) ?? now
        }

        let interval = nextMidnight.timeIntervalSince(now)

        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performMidnightReset()
            self?.startMidnightResetTimer() // Reschedule for next midnight
        }
    }

    private func performMidnightReset() {
        // Reset dhikr count
        dhikrCount = DhikrCount()
        saveDhikrCount()

        // Check and update streak
        checkStreak()

        // Reload widgets to reflect reset
        WidgetCenter.shared.reloadAllTimelines()

        // Post notification for UI updates
        NotificationCenter.default.post(name: .dhikrCountUpdated, object: nil)

    }
    
    // MARK: - Goals Management
    private func saveGoals() {
        do {
            let data = try JSONEncoder().encode(goal)
            userDefaults.set(data, forKey: goalsKey)
        } catch {
        }
    }
    
    private static func loadGoals(from userDefaults: UserDefaults) -> DhikrGoals {
        guard let data = userDefaults.data(forKey: "dhikrGoals") else {
            return DhikrGoals() // Default goals
        }
        
        do {
            return try JSONDecoder().decode(DhikrGoals.self, from: data)
        } catch {
            return DhikrGoals() // Default goals
        }
    }
    
    // MARK: - History Management
    func getAllDhikrStats() -> [DailyDhikrStats] {
        let statsDict = loadDailyStats()
        let stats = Array(statsDict.values)
        return stats.sorted { $0.date > $1.date } // Most recent first
    }

    func getAllTimeTotal() -> Int {
        let statsDict = loadDailyStats()
        return statsDict.values.reduce(0) { $0 + $1.total }
    }

    // MARK: - Individual Entry Management

    /// Record a dhikr entry with timestamp (batched for performance)
    private func recordEntry(type: DhikrType, count: Int) {
        let entry = DhikrEntry(type: type, timestamp: Date(), count: count)
        pendingEntries.append(entry)

        // Batch write: Only write to disk when we have enough entries or after a delay
        if pendingEntries.count >= entriesBatchSize {
            flushPendingEntries()
        } else {
            // Debounce writes - save after 2 seconds of inactivity
            entriesWriteTimer?.invalidate()
            entriesWriteTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.flushPendingEntries()
            }
        }
    }

    /// Write pending entries to disk
    private func flushPendingEntries() {
        guard !pendingEntries.isEmpty else { return }

        var allEntries = loadAllEntries()
        allEntries.append(contentsOf: pendingEntries)

        // Trim old entries if we exceed the limit (keep most recent)
        if allEntries.count > maxEntriesInMemory {
            allEntries = Array(allEntries.suffix(maxEntriesInMemory))
        }

        saveAllEntries(allEntries)
        pendingEntries.removeAll()

    }

    /// Load all entries from storage
    private func loadAllEntries() -> [DhikrEntry] {
        guard let data = userDefaults.data(forKey: dhikrEntriesKey),
              let entries = try? JSONDecoder().decode([DhikrEntry].self, from: data) else {
            return []
        }
        return entries
    }

    /// Save all entries to storage
    private func saveAllEntries(_ entries: [DhikrEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        userDefaults.set(data, forKey: dhikrEntriesKey)
    }

    /// Get entries for a specific date range
    func getEntries(from startDate: Date, to endDate: Date) -> [DhikrEntry] {
        // Flush any pending entries first
        flushPendingEntries()

        let allEntries = loadAllEntries()
        return allEntries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
    }

    /// Get entries for a specific month
    func getEntriesForMonth(_ date: Date) -> [DhikrEntry] {
        let calendar = Calendar.current
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }
        return getEntries(from: monthStart, to: monthEnd)
    }

    /// Calculate time breakdown from actual entries
    func calculateTimeBreakdown(for entries: [DhikrEntry]) -> (morning: Int, afternoon: Int, evening: Int, night: Int) {
        var breakdown: [TimeOfDay: Int] = [
            .morning: 0,
            .afternoon: 0,
            .evening: 0,
            .night: 0
        ]

        for entry in entries {
            breakdown[entry.timeOfDay, default: 0] += entry.count
        }

        return (
            morning: breakdown[.morning] ?? 0,
            afternoon: breakdown[.afternoon] ?? 0,
            evening: breakdown[.evening] ?? 0,
            night: breakdown[.night] ?? 0
        )
    }

    /// Ensure pending entries are saved when app goes to background
    func savePendingData() {
        flushPendingEntries()
        flushPendingUpdates()
    }
}

// MARK: - Supporting Models
struct DhikrStats {
    let subhanAllah: Int
    let alhamdulillah: Int
    let astaghfirullah: Int
    let total: Int
    let streak: Int
    
    var mostUsedDhikr: DhikrType {
        let counts = [
            (DhikrType.subhanAllah, subhanAllah),
            (DhikrType.alhamdulillah, alhamdulillah),
            (DhikrType.astaghfirullah, astaghfirullah)
        ]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .subhanAllah
    }
}

struct DailyDhikrStats: Codable, Identifiable {
    var id: String { date.ISO8601Format() }
    let date: Date
    let subhanAllah: Int
    let alhamdulillah: Int
    let astaghfirullah: Int
    let total: Int

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
} 