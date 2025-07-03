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

// MARK: - Dhikr Service
class DhikrService: ObservableObject {
    // MARK: - Properties
    @Published var dhikrCount: DhikrCount {
        didSet {
            saveDhikrCount()
            updateTodayStats()
        }
    }
    @Published var streak: Int = 0
    
    // MARK: - UserDefaults Keys
    private let dhikrCountKey = "dhikrCount"
    private let streakKey = "streak"
    private let lastStreakDateKey = "lastStreakDate"
    private let dailyStatsKey = "dailyStats"
    
    // MARK: - UserDefaults
    private let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")!
    
    // MARK: - Singleton
    static let shared = DhikrService()
    
    // MARK: - Initialization
    private init() {
        self.dhikrCount = DhikrService.loadDhikrCount(from: userDefaults)
        self.streak = userDefaults.integer(forKey: streakKey)
        checkStreakOnLaunch()
    }
    
    // MARK: - Public Methods
    func incrementDhikr(_ type: DhikrType) {
        dhikrCount.increment(type)
        
        // Trigger haptic feedback
        triggerHapticFeedback()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .dhikrCountUpdated, object: type)
        updateTodayStats()
        checkStreak()
    }
    
    func setDhikrCount(_ type: DhikrType, count: Int) {
        dhikrCount.setCount(type, count: count)
        
        // Trigger haptic feedback
        triggerHapticFeedback()
        
        // Post notification for UI updates
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
    
    // --- Timer for 11:59pm streak check ---
    private var streakTimer: Timer? = nil
    func startStreakTimer() {
        streakTimer?.invalidate()
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 23
        components.minute = 59
        components.second = 0
        let nextTrigger = calendar.date(from: components) ?? now
        let interval = max(nextTrigger.timeIntervalSince(now), 60)
        streakTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.checkStreak()
            self?.startStreakTimer()
        }
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

struct DailyDhikrStats: Codable {
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
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
} 