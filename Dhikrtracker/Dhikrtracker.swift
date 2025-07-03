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
        print("Widget: Using UserDefaults suite: \(userDefaults)")
        
        // Get current dhikr count
        let dhikrCountKey = "dhikrCount"
        var todayCount = 0
        
        // Try to get dhikr count from UserDefaults
        if let data = userDefaults.data(forKey: dhikrCountKey) {
            do {
                let dhikrCount = try JSONDecoder().decode(DhikrCount.self, from: data)
                todayCount = dhikrCount.totalCount
                print("Widget: Loaded dhikr count from UserDefaults: \(todayCount)")
                print("Widget: Breakdown - SubhanAllah: \(dhikrCount.subhanAllah), Alhamdulillah: \(dhikrCount.alhamdulillah), Astaghfirullah: \(dhikrCount.astaghfirullah)")
            } catch {
                print("Widget: Failed to decode dhikr count: \(error)")
                print("Widget: Raw data: \(String(data: data, encoding: .utf8) ?? "nil")")
            }
        } else {
            print("Widget: No dhikr count data found in UserDefaults")
        }
        
        // Get daily streak
        let streak = userDefaults.integer(forKey: "streak")
        print("Widget: Loaded streak: \(streak)")
        
        // Get last three days data
        let lastThreeDays = getLastThreeDaysData(userDefaults: userDefaults)
        
        let result = DhikrData(
            todayCount: todayCount,
            streak: streak,
            lastThreeDays: lastThreeDays
        )
        
        print("Widget: Final data - Today: \(result.todayCount), Streak: \(result.streak), Days: \(result.lastThreeDays.map { "\($0.day): \($0.count)" })")
        
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
                print("Widget: Loaded daily stats from shared UserDefaults")
            } catch {
                print("Widget: Failed to decode daily stats: \(error)")
            }
        }
        
        for i in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let key = Self.dateKey(for: date)
            let count = statsDict[key]?.total ?? 0
            
            let dayName: String
            if calendar.isDateInToday(date) {
                dayName = "Today"
            } else if calendar.isDateInYesterday(date) {
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
        
        return DhikrData(
            todayCount: 47,
            streak: 12,
            lastThreeDays: [
                DayData(day: "Today", count: 47, date: today),
                DayData(day: "Yesterday", count: 63, date: yesterday),
                DayData(day: dayFormatter.string(from: twoDaysAgo), count: 41, date: twoDaysAgo)
            ]
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
    @Environment(\.widgetFamily) var family

    var body: some View {
        // The containerBackground modifier handles the overall background.
        // The content views below will add their own padding.
        if family == .systemMedium {
            MediumWidgetContent(entry: entry)
        } else {
            LargeWidgetContent(entry: entry)
        }
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
    var body: some View {
        // MODIFICATION: Added .padding() to the VStack.
        // This adds space around all the content, fixing the clipped top and removing the large default side margins.
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.green)
                Text("Stay connected with Allah")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Today's Count
            VStack {
                Text("\(entry.dhikrData.todayCount)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("Dhikr Today")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            // Streak Bar
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.white)
                Text("Day Streak")
                    .font(.headline.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                Text("\(entry.dhikrData.streak)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding()
            .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(16)
            
            // Last Three Days List
            VStack(spacing: 8) {
                ForEach(entry.dhikrData.lastThreeDays, id: \.day) { day in
                    HStack {
                        Circle()
                            .fill(day.day == "Today" ? Color.green : (day.day == "Yesterday" ? Color.blue : Color.gray.opacity(0.5)))
                            .frame(width: 8, height: 8)
                        Text(day.day)
                            .font(.headline.weight(.regular))
                        Spacer()
                        Text("\(day.count)")
                            .font(.headline.weight(.semibold))
                            .monospacedDigit() // Ensures numbers align well
                    }
                    if day.day != entry.dhikrData.lastThreeDays.last?.day {
                        Divider()
    }
}
            }
            .padding()
            .background(.quaternary.opacity(0.4))
            .cornerRadius(16)

            Spacer(minLength: 0)
            
            // Footer
            VStack {
                 Text("Remember Allah often")
                     .font(.caption.weight(.medium))
                     .foregroundColor(.secondary)
                     .italic()
                 Text("Qur'an 33:41")
                     .font(.caption2)
                     .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding() // This padding is key to the fix.
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

// MARK: - Widget Configuration
struct Dhikrtracker: Widget {
    let kind: String = "Dhikrtracker"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Dhikr Tracker")
        .description("Track your daily dhikr and maintain your streak.")
        .supportedFamilies([.systemMedium, .systemLarge])
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
        todayCount: 1,
        streak: 1,
        lastThreeDays: [
            DayData(day: "Today", count: 1, date: Date()),
            DayData(day: "Yesterday", count: 0, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            DayData(day: "Mon", count: 0, date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        ]
    )
    DhikrEntry(date: .now, dhikrData: sampleData)
}

#Preview(as: .systemMedium) {
    Dhikrtracker()
} timeline: {
    let sampleData = DhikrData(
        todayCount: 1,
        streak: 1,
        lastThreeDays: [
            DayData(day: "Today", count: 1, date: Date()),
            DayData(day: "Yesterday", count: 0, date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
            DayData(day: "Mon", count: 0, date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        ]
    )
    DhikrEntry(date: .now, dhikrData: sampleData)
}