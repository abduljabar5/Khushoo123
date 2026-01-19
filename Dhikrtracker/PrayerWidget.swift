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
    let isPremium: Bool
}

// MARK: - Provider

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), prayers: samplePrayers(), isPremium: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> ()) {
        let isPremium = checkPremiumStatus()
        let entry = PrayerEntry(date: Date(), prayers: loadPrayers(), isPremium: isPremium)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> ()) {
        let isPremium = checkPremiumStatus()
        let entry = PrayerEntry(date: Date(), prayers: loadPrayers(), isPremium: isPremium)

        // Refresh every 15 minutes or when significant changes happen
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func checkPremiumStatus() -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return false
        }
        return groupDefaults.bool(forKey: "isPremiumUser") || groupDefaults.bool(forKey: "hasGrantedAccess")
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
                if let timeDate = timeFormatter.date(from: timeString) {
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

            var isFuture = false
            if let timeDate = timeFormatter.date(from: timeString) {
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                components.hour = timeComponents.hour
                components.minute = timeComponents.minute

                if let fullDate = calendar.date(from: components) {
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

            let isDisabled = isFuture

            items.append(PrayerItem(
                name: name,
                time: formatTime(timeString),
                isCompleted: isCompleted,
                isNext: isNext,
                isInCooldown: isInCooldown || isDisabled
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

// MARK: - Sacred Minimalism Colors

private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)
private let pageBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
private let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
private let subtleText = Color(white: 0.5)

// MARK: - View

struct PrayerWidgetView: View {
    var entry: PrayerProvider.Entry

    var body: some View {
        if entry.isPremium {
            premiumContent
        } else {
            lockedContent
        }
    }

    private var premiumContent: some View {
        VStack(spacing: 6) {
            // Header - Sacred Minimalism style
            HStack(alignment: .firstTextBaseline) {
                Text("DAILY PRAYERS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(sacredGold)

                Spacer()

                Text(Date(), style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(subtleText)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            // Prayer List
            VStack(spacing: 5) {
                ForEach(entry.prayers) { prayer in
                    SacredPrayerRow(prayer: prayer)
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            pageBackground
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(sacredGold)
            }

            VStack(spacing: 6) {
                Text("PREMIUM")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundColor(subtleText)

                Text("Unlock Widgets")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.white)
            }

            Text("Open Khushoo to upgrade")
                .font(.system(size: 11))
                .foregroundColor(subtleText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            pageBackground
        }
    }
}

struct SacredPrayerRow: View {
    let prayer: PrayerItem

    var body: some View {
        HStack(spacing: 10) {
            // Prayer icon - minimal circle
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(prayer.isNext ? sacredGold.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: prayerIcon(for: prayer.name))
                    .font(.system(size: 14))
                    .foregroundColor(prayer.isNext ? sacredGold : subtleText)
            }

            // Prayer info
            VStack(alignment: .leading, spacing: 2) {
                Text(prayer.name)
                    .font(.system(size: 13, weight: prayer.isNext ? .medium : .regular))
                    .foregroundColor(prayer.isNext ? .white : Color.white.opacity(0.85))

                Text(prayer.time)
                    .font(.system(size: 10))
                    .foregroundColor(subtleText)
            }

            Spacer()

            // Status indicator
            if prayer.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(softGreen)
                    .font(.system(size: 18))
            } else {
                Button(intent: MarkPrayerIntent(prayerName: prayer.name)) {
                    if prayer.isInCooldown {
                        Image(systemName: "hourglass")
                            .foregroundColor(sacredGold)
                            .font(.system(size: 16))
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                    }
                }
                .buttonStyle(.plain)
                .disabled(prayer.isInCooldown)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(prayer.isNext ? sacredGold.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func prayerIcon(for prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "sun.haze.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "cloud.sun.fill"
        case "Maghrib": return "moon.fill"
        case "Isha": return "moon.stars.fill"
        default: return "sparkles"
        }
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
    ], isPremium: true)
}
