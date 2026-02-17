//
//  Dhikrtracker.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import WidgetKit
import SwiftUI

// MARK: - Data Models
struct DhikrData {
    let todayCount: Int
    let streak: Int
    let lastThreeDays: [DayData]
    let dailyGoal: Int
    let highestStreak: Int
}

struct DayData {
    let day: String
    let count: Int
    let date: Date
}

// MARK: - Timeline Provider
struct DhikrProvider: TimelineProvider {
    func placeholder(in context: Context) -> DhikrEntry {
        DhikrEntry(date: Date(), dhikrData: sampleData(), isPremium: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (DhikrEntry) -> ()) {
        let isPremium = checkPremiumStatus()
        let entry = DhikrEntry(date: Date(), dhikrData: loadDhikrData(), isPremium: isPremium)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DhikrEntry>) -> ()) {
        let isPremium = checkPremiumStatus()
        let entry = DhikrEntry(date: Date(), dhikrData: loadDhikrData(), isPremium: isPremium)

        // By using .atEnd, we tell WidgetKit to display this entry indefinitely
        // until the app tells it to reload using WidgetCenter.
        let timeline = Timeline(entries: [entry], policy: .atEnd)

        completion(timeline)
    }

    private func checkPremiumStatus() -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return false
        }
        // Check paid subscription
        if groupDefaults.bool(forKey: "isPremiumUser") {
            return true
        }
        // Check manual grant (influencers, gifts)
        if groupDefaults.bool(forKey: "hasManualGrant") {
            return true
        }
        return false
    }

    private func loadDhikrData() -> DhikrData {
        // Use standard UserDefaults for now since App Groups aren't working
        let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") ?? .standard

        // Get current dhikr count
        let dhikrCountKey = "dhikrCount"
        var todayCount = 0

        // Try to get dhikr count from UserDefaults
        if let data = userDefaults.data(forKey: dhikrCountKey) {
            do {
                let dhikrCount = try JSONDecoder().decode(DhikrCount.self, from: data)
                todayCount = dhikrCount.totalCount
            } catch {
            }
        } else {
        }

        // Get daily streak
        let streak = userDefaults.integer(forKey: "streak")

        // Get daily goal from goals
        var dailyGoal = 99 // Default
        if let goalsData = userDefaults.data(forKey: "dhikrGoals") {
            do {
                let goals = try JSONDecoder().decode(DhikrGoals.self, from: goalsData)
                dailyGoal = goals.totalDailyGoal
            } catch {
            }
        }

        // Get highest streak (personal best)
        var highestStreak = userDefaults.integer(forKey: "highestStreak")
        if highestStreak == 0 { highestStreak = max(streak, 1) } // Use current if no best recorded, minimum 1

        // Get last three days data
        let lastThreeDays = getLastThreeDaysData(userDefaults: userDefaults)

        let result = DhikrData(
            todayCount: todayCount,
            streak: streak,
            lastThreeDays: lastThreeDays,
            dailyGoal: dailyGoal,
            highestStreak: highestStreak
        )


        return result
    }

    private func getLastThreeDaysData(userDefaults: UserDefaults) -> [DayData] {
        let calendar = Calendar.current
        let today = Date()
        var days: [DayData] = []

        // Get daily stats from shared UserDefaults
        let dailyStatsKey = "dailyStats"
        var statsDict: [String: DailyDhikrStats] = [:]

        if let data = userDefaults.data(forKey: dailyStatsKey) {
            do {
                statsDict = try JSONDecoder().decode([String: DailyDhikrStats].self, from: data)
            } catch {
            }
        }

        // Get yesterday, 2 days ago, and 3 days ago (skip today)
        for i in 1...3 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let key = Self.dateKey(for: date)
            let count = statsDict[key]?.total ?? 0

            let dayName: String
            if calendar.isDateInYesterday(date) {
                dayName = "Yesterday"
            } else {
                dayName = dayFormatter.string(from: date)
            }

            days.append(DayData(day: dayName, count: count, date: date))
        }

        return days
    }

    private static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func sampleData() -> DhikrData {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!

        return DhikrData(
            todayCount: 1250,
            streak: 47,
            lastThreeDays: [
                DayData(day: "Yesterday", count: 1200, date: yesterday),
                DayData(day: "2 Days Ago", count: 1150, date: twoDaysAgo),
                DayData(day: "3 Days Ago", count: 1100, date: threeDaysAgo)
            ],
            dailyGoal: 2000,
            highestStreak: 50
        )
    }
}

// MARK: - Timeline Entry
struct DhikrEntry: TimelineEntry {
    let date: Date
    let dhikrData: DhikrData
    let isPremium: Bool
}

// MARK: - Sacred Minimalism Colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)
private let pageBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
private let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
private let subtleText = Color(white: 0.5)

// MARK: - Widget View
struct DhikrWidgetView: View {
    var entry: DhikrProvider.Entry

    var body: some View {
        if entry.isPremium {
            SacredLargeWidgetContent(entry: entry)
        } else {
            lockedContent
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(sacredGold)
            }

            VStack(spacing: 8) {
                Text("PREMIUM")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(subtleText)

                Text("Unlock Widgets")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Text("Open Khushoo to upgrade")
                .font(.system(size: 12))
                .foregroundColor(subtleText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget Content
struct MediumWidgetContent: View {
    var entry: DhikrProvider.Entry
    @State private var showingPreviousDays = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "hand.thumbsup.fill")
                    .foregroundColor(.green)
                Text("Stay connected with Allah")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Main Content
            HStack(alignment: .top, spacing: 16) {
                // Left side: Today's Count & Streak
                VStack(spacing: 8) {
                    VStack {
                        Text("\(entry.dhikrData.todayCount)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("Dhikr Today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Day Streak")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(entry.dhikrData.streak)")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.gradient)
                    .cornerRadius(12)
                }

                // Right side: Recent Days
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.dhikrData.lastThreeDays, id: \.day) { day in
                        HStack {
                            Text(day.day)
                                .font(.caption.weight(.medium))
                                .frame(width: 70, alignment: .leading)
                            Spacer()
                            Text("\(day.count)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                        Divider()
                    }
                }
            }
        }
        .padding()
    }
}


// MARK: - Large Widget Content (Legacy)
struct LargeWidgetContent: View {
    var entry: DhikrProvider.Entry

    var body: some View {
        SacredLargeWidgetContent(entry: entry)
    }
}

// MARK: - Sacred Large Widget Content
struct SacredLargeWidgetContent: View {
    var entry: DhikrProvider.Entry

    var lastThreeDaysTotal: Int {
        entry.dhikrData.lastThreeDays.reduce(0) { $0 + $1.count }
    }

    var streakProgress: Double {
        guard entry.dhikrData.highestStreak > 0 else { return 0 }
        return min(Double(entry.dhikrData.streak) / Double(entry.dhikrData.highestStreak), 1.0)
    }

    var todayProgress: Double {
        guard entry.dhikrData.dailyGoal > 0 else { return 0 }
        return min(Double(entry.dhikrData.todayCount) / Double(entry.dhikrData.dailyGoal), 1.0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("DHIKR")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(sacredGold)
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(subtleText)
            }
            .padding(.horizontal, 4)

            // Main circular progress
            ZStack {
                // Background circle
                Circle()
                    .fill(cardBackground)
                    .frame(width: 110, height: 110)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: todayProgress)
                    .stroke(sacredGold.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundColor(subtleText)
                    Text("\(entry.dhikrData.todayCount.formatted())")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
            }

            // Streak card
            HStack(spacing: 10) {
                // Flame icon
                ZStack {
                    Circle()
                        .fill(cardBackground)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        )
                    Text("🔥")
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DAY STREAK")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundColor(subtleText)

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(sacredGold.opacity(0.6))
                                .frame(width: geometry.size.width * streakProgress)
                        }
                    }
                    .frame(height: 6)
                }

                Spacer()

                Text("\(entry.dhikrData.streak)")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )

            // Last 3 days
            VStack(spacing: 10) {
                HStack {
                    Text("LAST 3 DAYS")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundColor(subtleText)
                    Spacer()
                    Text("\(lastThreeDaysTotal.formatted()) total")
                        .font(.system(size: 10))
                        .foregroundColor(subtleText)
                }

                HStack(spacing: 8) {
                    ForEach(Array(entry.dhikrData.lastThreeDays.enumerated()), id: \.element.day) { index, day in
                        VStack(spacing: 4) {
                            Text(getShortDayLabel(for: index))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(subtleText)
                            Text("\(day.count.formatted())")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .padding(14)
    }

    private func getShortDayLabel(for index: Int) -> String {
        switch index {
        case 0: return "YST"
        case 1: return "-2D"
        case 2: return "-3D"
        default: return ""
        }
    }
}


// MARK: - Supporting Models (for widget)
struct DhikrCount: Codable {
    let subhanAllah: Int
    let alhamdulillah: Int
    let astaghfirullah: Int

    var totalCount: Int {
        subhanAllah + alhamdulillah + astaghfirullah
    }
}

struct DailyDhikrStats: Codable, Equatable {
    let date: Date
    let subhanAllah: Int
    let alhamdulillah: Int
    let astaghfirullah: Int
    let total: Int
}

struct DhikrGoals: Codable {
    var subhanAllah: Int
    var alhamdulillah: Int
    var astaghfirullah: Int

    var totalDailyGoal: Int {
        subhanAllah + alhamdulillah + astaghfirullah
    }
}

// MARK: - Widget Configuration
struct Dhikrtracker: Widget {
    let kind: String = "Dhikrtracker"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    pageBackground
                }
        }
        .configurationDisplayName("Dhikr Tracker")
        .description("Track your daily dhikr and maintain your streak.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Helper Extensions
private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE" // e.g., "Mon"
    return formatter
}()

// MARK: - Previews
#Preview(as: .systemLarge) {
    Dhikrtracker()
} timeline: {
    let sampleData = DhikrData(
        todayCount: 1250,
        streak: 47,
        lastThreeDays: [
            DayData(day: "Yesterday", count: 1200, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            DayData(day: "2 Days Ago", count: 1150, date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!),
            DayData(day: "3 Days Ago", count: 1100, date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!)
        ],
        dailyGoal: 2000,
        highestStreak: 50
    )
    DhikrEntry(date: .now, dhikrData: sampleData, isPremium: true)
}
