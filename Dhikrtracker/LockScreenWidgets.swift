//
//  LockScreenWidgets.swift
//  Dhikrtracker
//
//  Lock screen widgets for Dhikr app - iOS 16+ compatible
//

import WidgetKit
import SwiftUI

// MARK: - Dhikr Lock Screen Widgets

/// Circular gauge showing today's dhikr progress (Apple Fitness style)
struct DhikrCircularWidget: Widget {
    let kind = "DhikrCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrCircularView(entry: entry)
        }
        .configurationDisplayName("Dhikr Progress")
        .description("Today's dhikr progress at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct DhikrCircularView: View {
    let entry: DhikrEntry

    private var progress: Double {
        guard entry.dhikrData.dailyGoal > 0 else { return 0 }
        return min(Double(entry.dhikrData.todayCount) / Double(entry.dhikrData.dailyGoal), 1.0)
    }

    var body: some View {
        if entry.isPremium {
            Gauge(value: progress) {
                Image(systemName: "hands.clap.fill")
                    .font(.system(size: 12))
            } currentValueLabel: {
                Text(formatCount(entry.dhikrData.todayCount))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .widgetAccentable()
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

/// Rectangular widget showing streak and today's count (Streaks app style)
struct DhikrRectangularWidget: Widget {
    let kind = "DhikrRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrRectangularView(entry: entry)
        }
        .configurationDisplayName("Dhikr Summary")
        .description("Your streak and today's count.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct DhikrRectangularView: View {
    let entry: DhikrEntry

    private var progress: Double {
        guard entry.dhikrData.dailyGoal > 0 else { return 0 }
        return min(Double(entry.dhikrData.todayCount) / Double(entry.dhikrData.dailyGoal), 1.0)
    }

    private var goalReached: Bool {
        entry.dhikrData.todayCount >= entry.dhikrData.dailyGoal
    }

    var body: some View {
        if entry.isPremium {
            premiumContent
        } else {
            lockedContent
        }
    }

    private var premiumContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Streak row
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text("\(entry.dhikrData.streak) day streak")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            // Today's count with goal context
            HStack(spacing: 4) {
                Text("\(entry.dhikrData.todayCount.formatted())")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("/ \(entry.dhikrData.dailyGoal.formatted())")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                if goalReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .widgetAccentable()
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.tertiary)
                        .frame(height: 4)

                    Capsule()
                        .fill(.primary)
                        .frame(width: geo.size.width * progress, height: 4)
                        .widgetAccentable()
                }
            }
            .frame(height: 4)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var lockedContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16))
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium Widget")
                    .font(.system(size: 13, weight: .semibold))
                Text("Open app to unlock")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Inline widget showing streak (simple badge style)
struct DhikrInlineWidget: Widget {
    let kind = "DhikrInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrInlineView(entry: entry)
        }
        .configurationDisplayName("Dhikr Streak")
        .description("Your current streak.")
        .supportedFamilies([.accessoryInline])
    }
}

struct DhikrInlineView: View {
    let entry: DhikrEntry

    var body: some View {
        if entry.isPremium {
            Label {
                Text("\(entry.dhikrData.streak) day streak")
            } icon: {
                Image(systemName: "flame.fill")
            }
        } else {
            Label {
                Text("Premium Widget")
            } icon: {
                Image(systemName: "lock.fill")
            }
        }
    }
}

// MARK: - Prayer Lock Screen Widgets

/// Circular countdown to next prayer (Timer style)
struct PrayerCircularWidget: Widget {
    let kind = "PrayerCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerLockScreenProvider()) { entry in
            PrayerCircularView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to next prayer.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct PrayerCircularView: View {
    let entry: PrayerLockScreenEntry

    private var completedCount: Int {
        entry.prayerStatus.filter { $0.isCompleted }.count
    }

    var body: some View {
        if !entry.isPremium {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .widgetAccentable()
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else if let nextPrayer = entry.nextPrayer, let prayerTime = entry.nextPrayerTime {
            // Show next prayer with countdown or "Now" if in grace period
            ZStack {
                AccessoryWidgetBackground()

                VStack(spacing: 0) {
                    Image(systemName: prayerIcon(for: nextPrayer))
                        .font(.system(size: 14, weight: .semibold))
                        .widgetAccentable()

                    if entry.isCurrentPrayerActive {
                        // Within 30-minute grace period - show "Now"
                        Text("Now")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    } else {
                        // Show countdown to future prayer
                        Text(prayerTime, style: .timer)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            // All prayers passed - show completion progress
            Gauge(value: Double(completedCount) / 5.0) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 10))
            } currentValueLabel: {
                Text("\(completedCount)/5")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private func prayerIcon(for prayer: String) -> String {
        switch prayer {
        case "Fajr": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.haze.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
}

/// Rectangular widget showing next prayer with time and completion status
struct PrayerRectangularWidget: Widget {
    let kind = "PrayerRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerLockScreenProvider()) { entry in
            PrayerRectangularView(entry: entry)
        }
        .configurationDisplayName("Prayer Status")
        .description("Next prayer and completion status.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct PrayerRectangularView: View {
    let entry: PrayerLockScreenEntry

    private var completedCount: Int {
        entry.prayerStatus.filter { $0.isCompleted }.count
    }

    private func isCurrentPrayer(_ prayerName: String) -> Bool {
        entry.isCurrentPrayerActive && entry.nextPrayer == prayerName
    }

    var body: some View {
        if !entry.isPremium {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium Widget")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Open app to unlock")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            premiumContent
        }
    }

    private var premiumContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Completion status row - evenly distributed
            HStack(spacing: 0) {
                ForEach(entry.prayerStatus, id: \.name) { prayer in
                    VStack(spacing: 1) {
                        Image(systemName: prayerStatusIcon(for: prayer))
                            .font(.system(size: 11))
                            .foregroundStyle(prayer.isCompleted ? .primary : (isCurrentPrayer(prayer.name) ? .primary : .tertiary))
                            .widgetAccentable(prayer.isCompleted || isCurrentPrayer(prayer.name))
                        Text(prayerShortName(prayer.name))
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(isCurrentPrayer(prayer.name) ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let nextPrayer = entry.nextPrayer, let prayerTime = entry.nextPrayerTime {
                // Next prayer info or current prayer "Now" state
                HStack(spacing: 6) {
                    Image(systemName: prayerIcon(for: nextPrayer))
                        .font(.system(size: 14, weight: .semibold))
                        .widgetAccentable()

                    VStack(alignment: .leading, spacing: 0) {
                        Text(nextPrayer)
                            .font(.system(size: 14, weight: .semibold))
                        if entry.isCurrentPrayerActive {
                            Text("Pray now")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(prayerTime, style: .time)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Countdown or "Now" indicator
                    if entry.isCurrentPrayerActive {
                        Text("Now")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .widgetAccentable()
                    } else {
                        Text(prayerTime, style: .timer)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Day ended - show completion summary
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14))
                        .widgetAccentable()

                    Text("\(completedCount) of 5 prayers today")
                        .font(.system(size: 13, weight: .medium))
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func prayerStatusIcon(for prayer: PrayerStatus) -> String {
        if prayer.isCompleted {
            return "checkmark.circle.fill"
        } else if isCurrentPrayer(prayer.name) {
            return "circle.inset.filled" // Current prayer - distinct indicator
        } else {
            return "circle"
        }
    }

    private func prayerShortName(_ name: String) -> String {
        switch name {
        case "Fajr": return "Faj"
        case "Dhuhr": return "Dhu"
        case "Asr": return "Asr"
        case "Maghrib": return "Mag"
        case "Isha": return "Ish"
        default: return name
        }
    }

    private func prayerIcon(for prayer: String) -> String {
        switch prayer {
        case "Fajr": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.haze.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
}

/// Inline widget showing next prayer time
struct PrayerInlineWidget: Widget {
    let kind = "PrayerInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerLockScreenProvider()) { entry in
            PrayerInlineView(entry: entry)
        }
        .configurationDisplayName("Next Prayer")
        .description("Next prayer name and time.")
        .supportedFamilies([.accessoryInline])
    }
}

struct PrayerInlineView: View {
    let entry: PrayerLockScreenEntry

    private var completedCount: Int {
        entry.prayerStatus.filter { $0.isCompleted }.count
    }

    var body: some View {
        if !entry.isPremium {
            Label {
                Text("Premium Widget")
            } icon: {
                Image(systemName: "lock.fill")
            }
        } else if let nextPrayer = entry.nextPrayer, let prayerTime = entry.nextPrayerTime {
            Label {
                if entry.isCurrentPrayerActive {
                    // Within 30-minute grace period
                    Text("\(nextPrayer) - Now")
                } else {
                    Text("\(nextPrayer) at ") + Text(prayerTime, style: .time)
                }
            } icon: {
                Image(systemName: prayerIcon(for: nextPrayer))
            }
        } else {
            Label("\(completedCount)/5 prayers today", systemImage: "moon.stars.fill")
        }
    }

    private func prayerIcon(for prayer: String) -> String {
        switch prayer {
        case "Fajr": return "sunrise.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "sun.haze.fill"
        case "Maghrib": return "sunset.fill"
        case "Isha": return "moon.stars.fill"
        default: return "clock.fill"
        }
    }
}

// MARK: - Prayer Lock Screen Provider

struct PrayerLockScreenEntry: TimelineEntry {
    let date: Date
    let nextPrayer: String?
    let nextPrayerTime: Date?
    let prayerStatus: [PrayerStatus]
    // When true, we're within 30 min of the displayed prayer (show "Now" instead of countdown)
    let isCurrentPrayerActive: Bool
    let isPremium: Bool
}

struct PrayerStatus {
    let name: String
    let isCompleted: Bool
}

struct PrayerLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerLockScreenEntry {
        PrayerLockScreenEntry(
            date: Date(),
            nextPrayer: "Dhuhr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            prayerStatus: [
                PrayerStatus(name: "Fajr", isCompleted: true),
                PrayerStatus(name: "Dhuhr", isCompleted: false),
                PrayerStatus(name: "Asr", isCompleted: false),
                PrayerStatus(name: "Maghrib", isCompleted: false),
                PrayerStatus(name: "Isha", isCompleted: false)
            ],
            isCurrentPrayerActive: false,
            isPremium: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerLockScreenEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerLockScreenEntry>) -> Void) {
        let entry = loadEntry()
        let calendar = Calendar.current

        // Determine next refresh time
        let nextRefresh: Date
        if entry.isCurrentPrayerActive, let prayerTime = entry.nextPrayerTime {
            // In grace period - refresh when the 30-minute grace period ends
            nextRefresh = calendar.date(byAdding: .minute, value: 30, to: prayerTime) ?? Date().addingTimeInterval(900)
        } else if let prayerTime = entry.nextPrayerTime {
            // Refresh at next prayer time
            nextRefresh = prayerTime
        } else {
            // No prayer time - refresh in 15 minutes
            nextRefresh = Date().addingTimeInterval(900)
        }

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func checkPremiumStatus() -> Bool {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return false
        }
        return groupDefaults.bool(forKey: "isPremiumUser") || groupDefaults.bool(forKey: "hasGrantedAccess")
    }

    private func loadEntry() -> PrayerLockScreenEntry {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let isPremium = checkPremiumStatus()

        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return sampleEntry(isPremium: isPremium)
        }

        // Load completed prayers
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: now)
        let completed = groupDefaults.array(forKey: "completed_\(todayKey)") as? [String] ?? []

        // Load prayer times
        var todayTimings: StoredPrayerTime?
        if let data = groupDefaults.data(forKey: "PrayerTimeStorage_v1") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storage = try decoder.decode(PrayerTimeStorage.self, from: data)
                todayTimings = storage.prayerTimes.first { calendar.isDate($0.date, inSameDayAs: today) }
            } catch {}
        }

        let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

        // Build prayer status
        let prayerStatus = prayerNames.map { name in
            PrayerStatus(name: name, isCompleted: completed.contains(name))
        }

        // Find next prayer or current prayer (within 30-min grace period)
        var nextPrayer: String?
        var nextPrayerTime: Date?
        var isCurrentPrayerActive = false

        if let timings = todayTimings {
            let prayerTimeStrings = [timings.fajr, timings.dhuhr, timings.asr, timings.maghrib, timings.isha]
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"

            var foundNext = false

            for (index, timeStr) in prayerTimeStrings.enumerated() {
                let cleanTime = timeStr.components(separatedBy: " ").first ?? ""
                if let timeDate = timeFormatter.date(from: cleanTime) {
                    var components = calendar.dateComponents([.year, .month, .day], from: today)
                    let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                    components.hour = timeComponents.hour
                    components.minute = timeComponents.minute

                    if let fullDate = calendar.date(from: components) {
                        // 30-minute grace period - show as "Now" for 30 min after prayer time
                        let graceEndTime = calendar.date(byAdding: .minute, value: 30, to: fullDate) ?? fullDate

                        if fullDate > now && !foundNext {
                            // Future prayer - show countdown
                            nextPrayer = prayerNames[index]
                            nextPrayerTime = fullDate
                            foundNext = true
                        } else if fullDate <= now && graceEndTime > now && !foundNext {
                            // Within 30-minute grace period - this is the "current" prayer
                            nextPrayer = prayerNames[index]
                            nextPrayerTime = fullDate
                            isCurrentPrayerActive = true
                            foundNext = true
                        }
                    }
                }
            }
        }

        return PrayerLockScreenEntry(
            date: now,
            nextPrayer: nextPrayer,
            nextPrayerTime: nextPrayerTime,
            prayerStatus: prayerStatus,
            isCurrentPrayerActive: isCurrentPrayerActive,
            isPremium: isPremium
        )
    }

    private func sampleEntry(isPremium: Bool = true) -> PrayerLockScreenEntry {
        PrayerLockScreenEntry(
            date: Date(),
            nextPrayer: "Dhuhr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            prayerStatus: [
                PrayerStatus(name: "Fajr", isCompleted: true),
                PrayerStatus(name: "Dhuhr", isCompleted: false),
                PrayerStatus(name: "Asr", isCompleted: false),
                PrayerStatus(name: "Maghrib", isCompleted: false),
                PrayerStatus(name: "Isha", isCompleted: false)
            ],
            isCurrentPrayerActive: false,
            isPremium: isPremium
        )
    }
}

// MARK: - Previews

#Preview("Dhikr Circular", as: .accessoryCircular) {
    DhikrCircularWidget()
} timeline: {
    DhikrEntry(date: .now, dhikrData: DhikrData(
        todayCount: 75,
        streak: 47,
        lastThreeDays: [],
        dailyGoal: 99,
        highestStreak: 50
    ), isPremium: true)
}

#Preview("Dhikr Rectangular", as: .accessoryRectangular) {
    DhikrRectangularWidget()
} timeline: {
    DhikrEntry(date: .now, dhikrData: DhikrData(
        todayCount: 1250,
        streak: 47,
        lastThreeDays: [],
        dailyGoal: 2000,
        highestStreak: 50
    ), isPremium: true)
}

#Preview("Prayer Circular", as: .accessoryCircular) {
    PrayerCircularWidget()
} timeline: {
    PrayerLockScreenEntry(
        date: .now,
        nextPrayer: "Dhuhr",
        nextPrayerTime: Date().addingTimeInterval(3600),
        prayerStatus: [
            PrayerStatus(name: "Fajr", isCompleted: true),
            PrayerStatus(name: "Dhuhr", isCompleted: false),
            PrayerStatus(name: "Asr", isCompleted: false),
            PrayerStatus(name: "Maghrib", isCompleted: false),
            PrayerStatus(name: "Isha", isCompleted: false)
        ],
        isCurrentPrayerActive: false,
        isPremium: true
    )
}

#Preview("Prayer Rectangular", as: .accessoryRectangular) {
    PrayerRectangularWidget()
} timeline: {
    PrayerLockScreenEntry(
        date: .now,
        nextPrayer: "Asr",
        nextPrayerTime: Date().addingTimeInterval(5400),
        prayerStatus: [
            PrayerStatus(name: "Fajr", isCompleted: true),
            PrayerStatus(name: "Dhuhr", isCompleted: true),
            PrayerStatus(name: "Asr", isCompleted: false),
            PrayerStatus(name: "Maghrib", isCompleted: false),
            PrayerStatus(name: "Isha", isCompleted: false)
        ],
        isCurrentPrayerActive: false,
        isPremium: true
    )
}
