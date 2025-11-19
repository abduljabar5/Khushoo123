//
//  PrayerWidget.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Models (Mirrored from Main App)

struct PrayerTimeStorage: Codable {
    let startDate: Date
    let endDate: Date
    let latitude: Double
    let longitude: Double
    let method: Int
    let prayerTimes: [StoredPrayerTime]
    let fetchedAt: Date
}

struct StoredPrayerTime: Codable {
    let date: Date
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

struct PrayerItem: Identifiable {
    let id = UUID()
    let name: String
    let time: String
    let isCompleted: Bool
    let isNext: Bool
    let isInCooldown: Bool
}

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayers: [PrayerItem]
}

// MARK: - Provider

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), prayers: samplePrayers())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> ()) {
        let entry = PrayerEntry(date: Date(), prayers: loadPrayers())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> ()) {
        let entry = PrayerEntry(date: Date(), prayers: loadPrayers())
        
        // Refresh every 15 minutes or when significant changes happen
        // Also refresh when the next prayer time arrives
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadPrayers() -> [PrayerItem] {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return samplePrayers()
        }
        
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        
        // Load Prayer Times
        var todayTimings: StoredPrayerTime?
        if let data = groupDefaults.data(forKey: "PrayerTimeStorage_v1") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storage = try decoder.decode(PrayerTimeStorage.self, from: data)
                todayTimings = storage.prayerTimes.first { calendar.isDate($0.date, inSameDayAs: today) }
            } catch {
                print("Widget: Failed to decode prayer times: \(error)")
            }
        }
        
        // Load Completed Prayers
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: now)
        let completed = groupDefaults.array(forKey: "completed_\(todayKey)") as? [String] ?? []
        
        guard let timings = todayTimings else {
            return samplePrayers() // Fallback if no data
        }
        
        // Parse timings to Date objects to find "Next" prayer
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let prayerTimeStrings = [timings.fajr, timings.dhuhr, timings.asr, timings.maghrib, timings.isha]
        
        var items: [PrayerItem] = []
        var nextFound = false
        
        for (index, name) in prayerNames.enumerated() {
            let timeString = prayerTimeStrings[index].components(separatedBy: " ").first ?? ""
            let isCompleted = completed.contains(name)
            
            // Determine if this is the "Next" prayer
            var isNext = false
            if !nextFound {
                // Simple logic: first uncompleted prayer is "Next", OR based on time
                // Let's use time for accuracy
                if let timeDate = timeFormatter.date(from: timeString) {
                    // Combine with today's date
                    var components = calendar.dateComponents([.year, .month, .day], from: today)
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute
                    
                    if let fullDate = calendar.date(from: components) {
                        if fullDate > now {
                            isNext = true
                            nextFound = true
                        }
                    }
                }
            }
            
            // Check if prayer is in the future (disabled)
            // A prayer is disabled if it's NOT completed AND it's NOT the current/past prayer
            // Actually, user requested: "only current or past prayers should be enabled"
            
            var isFuture = false
            if let timeDate = timeFormatter.date(from: timeString) {
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute
                
                if let fullDate = calendar.date(from: components) {
                    // If prayer time is in the future (more than 15 mins buffer? No, strict future)
                    if fullDate > now {
                        isFuture = true
                    }
                }
            }
            
            // Check Cooldown
            let cooldownKey = "lastMarkedTime_\(name)"
            var isInCooldown = false
            if let lastMarked = groupDefaults.object(forKey: cooldownKey) as? Date {
                if now.timeIntervalSince(lastMarked) < 300 {
                    isInCooldown = true
                }
            }
            
            // Disable if future
            let isDisabled = isFuture
            
            items.append(PrayerItem(
                name: name,
                time: formatTime(timeString),
                isCompleted: isCompleted,
                isNext: isNext,
                isInCooldown: isInCooldown || isDisabled // Reuse this flag or add new one. Let's add new one to struct.
            ))
        }
        
        return items
    }
    
    private func formatTime(_ time: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "HH:mm"
        
        if let date = inputFormatter.date(from: time) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "h:mm a"
            return outputFormatter.string(from: date)
        }
        return time
    }
    
    private func samplePrayers() -> [PrayerItem] {
        [
            PrayerItem(name: "Fajr", time: "5:30 AM", isCompleted: true, isNext: false, isInCooldown: false),
            PrayerItem(name: "Dhuhr", time: "1:15 PM", isCompleted: false, isNext: true, isInCooldown: false),
            PrayerItem(name: "Asr", time: "4:45 PM", isCompleted: false, isNext: false, isInCooldown: false),
            PrayerItem(name: "Maghrib", time: "7:30 PM", isCompleted: false, isNext: false, isInCooldown: false),
            PrayerItem(name: "Isha", time: "9:00 PM", isCompleted: false, isNext: false, isInCooldown: false)
        ]
    }
}

// MARK: - View

struct PrayerWidgetView: View {
    var entry: PrayerProvider.Entry
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Daily Prayers")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 8)
            
            // List
            VStack(spacing: 0) {
                ForEach(entry.prayers) { prayer in
                    PrayerRow(prayer: prayer)
                    if prayer.id != entry.prayers.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PrayerRow: View {
    let prayer: PrayerItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(prayer.name)
                    .font(.subheadline)
                    .fontWeight(prayer.isNext ? .bold : .regular)
                    .foregroundColor(prayer.isNext ? .primary : .secondary)
                
                Text(prayer.time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if prayer.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Button(intent: MarkPrayerIntent(prayerName: prayer.name)) {
                    if prayer.isInCooldown {
                        Image(systemName: "hourglass")
                            .foregroundColor(.orange)
                            .font(.title3)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
                .disabled(prayer.isInCooldown)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Widget Configuration

struct PrayerWidget: Widget {
    let kind: String = "PrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Prayers")
        .description("Track your daily prayers and manage focus.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemMedium) {
    PrayerWidget()
} timeline: {
    PrayerEntry(date: .now, prayers: [
        PrayerItem(name: "Fajr", time: "5:30 AM", isCompleted: true, isNext: false, isInCooldown: false),
        PrayerItem(name: "Dhuhr", time: "1:15 PM", isCompleted: false, isNext: true, isInCooldown: false),
        PrayerItem(name: "Asr", time: "4:45 PM", isCompleted: false, isNext: false, isInCooldown: false),
        PrayerItem(name: "Maghrib", time: "7:30 PM", isCompleted: false, isNext: false, isInCooldown: false),
        PrayerItem(name: "Isha", time: "9:00 PM", isCompleted: false, isNext: false, isInCooldown: false)
    ])
}
