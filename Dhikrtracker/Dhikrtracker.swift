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
        DhikrEntry(date: Date(), dhikrData: sampleData())
    }

    func getSnapshot(in context: Context, completion: @escaping (DhikrEntry) -> ()) {
        let entry = DhikrEntry(date: Date(), dhikrData: loadDhikrData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // --- FIX: Create a single entry timeline that reloads on demand ---
        let entry = DhikrEntry(date: Date(), dhikrData: loadDhikrData())
        
        // By using .atEnd, we tell WidgetKit to display this entry indefinitely
        // until the app tells it to reload using WidgetCenter.
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        // --- END FIX ---
        
        completion(timeline)
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
}

// MARK: - Widget View
struct DhikrWidgetView: View {
    var entry: DhikrProvider.Entry

    var body: some View {
        LargeWidgetContent(entry: entry)
    }
}

// MARK: - Medium Widget Content
struct MediumWidgetContent: View {
    var entry: DhikrProvider.Entry
    @State private var showingPreviousDays = false
    
    var body: some View {
        // MODIFICATION: Added .padding() to the VStack.
        // This adds space around all the content, fixing the clipped top and removing the large default side margins.
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "hand.thumbsup.fill") // A more distinct icon suggestion
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
        .padding() // This padding is key to the fix.
    }
}


// MARK: - Large Widget Content
struct LargeWidgetContent: View {
    var entry: DhikrProvider.Entry

    var lastThreeDaysTotal: Int {
        entry.dhikrData.lastThreeDays.reduce(0) { $0 + $1.count }
    }

    var streakProgress: Double {
        // Progress based on beating personal best
        guard entry.dhikrData.highestStreak > 0 else { return 0 }
        return min(Double(entry.dhikrData.streak) / Double(entry.dhikrData.highestStreak), 1.0)
    }

    var todayProgress: Double {
        // Progress based on daily goal
        guard entry.dhikrData.dailyGoal > 0 else { return 0 }
        return min(Double(entry.dhikrData.todayCount) / Double(entry.dhikrData.dailyGoal), 1.0)
    }

    var body: some View {
        // Main card container (widget is just the card, title is handled by iOS)
        VStack(spacing: 12) {
                // Circular progress with today's count - WITH DEPTH
                ZStack {
                    // Outer shadow ring (dark) for depth
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.black.opacity(0.4), Color.black.opacity(0.2)],
                                center: .center,
                                startRadius: 50,
                                endRadius: 65
                            )
                        )
                        .frame(width: 130, height: 130)
                        .blur(radius: 5)
                        .offset(y: 2)

                    // Middle ring with lighter gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 125, height: 125)

                    // Main circle background with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.22), Color(white: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 6)
                        .shadow(color: Color.white.opacity(0.1), radius: 2, x: -2, y: -2)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: todayProgress)
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    // Center content
                    VStack(spacing: 1) {
                        Text("Today's Total:")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(entry.dhikrData.todayCount.formatted())")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color.white)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)

                // Streak section WITH DEPTH
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("🔥")
                            .font(.system(size: 18))
                        Text("Days Streak: \(entry.dhikrData.streak) Days")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Streak progress bar with depth
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background with inset shadow
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(white: 0.18))
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)

                            // Progress - gradient from blue to red
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.29, green: 0.56, blue: 0.89), Color(red: 0.91, green: 0.29, blue: 0.24)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * streakProgress)
                                .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 1)
                        }
                    }
                    .frame(height: 9)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.22), Color(white: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.white.opacity(0.05), radius: 1, x: -1, y: -1)
                )
                .padding(.horizontal, 12)

                // Last 3 days summary WITH DEPTH
                VStack(spacing: 8) {
                    Text("Last 3 Days Total: \(lastThreeDaysTotal.formatted())")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    // Three columns for days with depth
                    HStack(spacing: 6) {
                        ForEach(Array(entry.dhikrData.lastThreeDays.enumerated()), id: \.element.day) { index, day in
                            VStack(spacing: 4) {
                                Text(getDayLabel(for: index))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(day.count.formatted())")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(white: 0.18))
                                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.22), Color(white: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                        .shadow(color: Color.white.opacity(0.05), radius: 1, x: -1, y: -1)
                )
                .padding(.horizontal, 12)
        }
        .padding(12)
    }

    private func getDayLabel(for index: Int) -> String {
        switch index {
        case 0: return "Yesterday:"
        case 1: return "2 Days Ago:"
        case 2: return "3 Days Ago:"
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
                .containerBackground(Color(white: 0.15), for: .widget)
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
    DhikrEntry(date: .now, dhikrData: sampleData)
}