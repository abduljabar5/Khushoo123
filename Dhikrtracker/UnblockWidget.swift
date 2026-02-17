//
//  UnblockWidget.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data Models

struct UnblockEntry: TimelineEntry {
    let date: Date
    let state: UnblockState
    let nextPrayerName: String?
    let nextPrayerTime: Date?
    let unlockAvailableAt: Date?
    let isPremium: Bool
}

enum UnblockState {
    case idle // Not blocking
    case waiting // Blocking active, waiting for 5 min timer
    case ready // 5 min timer over, ready to unblock
}

// MARK: - Provider

struct UnblockProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnblockEntry {
        UnblockEntry(date: Date(), state: .idle, nextPrayerName: "Fajr", nextPrayerTime: Date().addingTimeInterval(3600), unlockAvailableAt: nil, isPremium: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (UnblockEntry) -> ()) {
        let entry = createEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnblockEntry>) -> ()) {
        let entry = createEntry()

        var entries = [entry]
        var policy: TimelineReloadPolicy = .atEnd

        // If waiting, schedule a refresh when the timer ends
        if entry.state == .waiting, let unlockTime = entry.unlockAvailableAt {
            let readyEntry = UnblockEntry(
                date: unlockTime,
                state: .ready,
                nextPrayerName: entry.nextPrayerName,
                nextPrayerTime: entry.nextPrayerTime,
                unlockAvailableAt: unlockTime,
                isPremium: entry.isPremium
            )
            entries.append(readyEntry)
            policy = .after(unlockTime)
        } else if let nextPrayer = entry.nextPrayerTime {
            // Refresh at next prayer time
             policy = .after(nextPrayer)
        } else {
            // Refresh every 15 mins if idle
            policy = .after(Date().addingTimeInterval(900))
        }

        let timeline = Timeline(entries: entries, policy: policy)
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

    private func createEntry() -> UnblockEntry {
        let now = Date()
        let isPremium = checkPremiumStatus()

        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return UnblockEntry(date: now, state: .idle, nextPrayerName: nil, nextPrayerTime: nil, unlockAvailableAt: nil, isPremium: isPremium)
        }

        // Check if strict mode is enabled - widgets cannot unblock in strict mode
        let isStrictMode = groupDefaults.bool(forKey: "focusStrictMode")

        // Check Blocking Status
        let isBlocking = groupDefaults.object(forKey: "blockingStartTime") != nil
        let appsBlocked = groupDefaults.bool(forKey: "appsActuallyBlocked")
        let unlockAvailableAtTimestamp = groupDefaults.object(forKey: "earlyUnlockAvailableAt") as? TimeInterval

        var state: UnblockState = .idle
        var unlockAvailableAt: Date? = nil

        if isBlocking || appsBlocked {
            if let ts = unlockAvailableAtTimestamp {
                let date = Date(timeIntervalSince1970: ts)
                unlockAvailableAt = date
                if now >= date {
                    state = .ready
                } else {
                    state = .waiting
                }
            } else {
                // Fallback if timestamp missing but blocking
                state = .waiting
                unlockAvailableAt = now.addingTimeInterval(300) // Assume 5 mins from now if unknown
            }
        }

        // Find Next Prayer
        var nextPrayerName: String?
        var nextPrayerTime: Date?

        if let data = groupDefaults.data(forKey: "PrayerTimeStorage_v1") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let storage = try decoder.decode(PrayerTimeStorage.self, from: data)

                // Find next prayer logic
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: now)

                if let todayTimings = storage.prayerTimes.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
                    let prayerTimeStrings = [todayTimings.fajr, todayTimings.dhuhr, todayTimings.asr, todayTimings.maghrib, todayTimings.isha]
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"

                    for (index, timeStr) in prayerTimeStrings.enumerated() {
                        let cleanTime = timeStr.components(separatedBy: " ").first ?? ""
                        if let timeDate = formatter.date(from: cleanTime) {
                            var components = calendar.dateComponents([.year, .month, .day], from: today)
                            let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                            components.hour = timeComponents.hour
                            components.minute = timeComponents.minute

                            if let fullDate = calendar.date(from: components), fullDate > now {
                                nextPrayerName = prayerNames[index]
                                nextPrayerTime = fullDate
                                break
                            }
                        }
                    }
                }
            } catch {
            }
        }

        return UnblockEntry(
            date: now,
            state: state,
            nextPrayerName: nextPrayerName,
            nextPrayerTime: nextPrayerTime,
            unlockAvailableAt: unlockAvailableAt,
            isPremium: isPremium
        )
    }
}

// MARK: - Sacred Minimalism Colors

private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)
private let pageBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
private let cardBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
private let subtleText = Color(white: 0.5)

// MARK: - View

struct UnblockWidgetView: View {
    var entry: UnblockProvider.Entry

    var body: some View {
        if entry.isPremium {
            premiumContent
        } else {
            lockedContent
        }
    }

    private var premiumContent: some View {
        VStack {
            if entry.state == .idle {
                SacredIdleView(entry: entry)
            } else if entry.state == .waiting {
                SacredWaitingView(entry: entry)
            } else {
                SacredReadyView()
            }
        }
        .containerBackground(for: .widget) {
            pageBackground
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(sacredGold)
            }

            VStack(spacing: 4) {
                Text("PREMIUM")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(subtleText)

                Text("Unlock")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            pageBackground
        }
    }
}

struct SacredIdleView: View {
    var entry: UnblockProvider.Entry

    var body: some View {
        VStack(spacing: 10) {
            // Icon in circle
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: "shield.slash")
                    .font(.system(size: 20))
                    .foregroundColor(subtleText)
            }

            if let name = entry.nextPrayerName, let time = entry.nextPrayerTime {
                VStack(spacing: 4) {
                    Text("NEXT: \(name.uppercased())")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(sacredGold)

                    Text(time, style: .timer)
                        .font(.system(size: 16, weight: .light).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("No active blocking")
                    .font(.system(size: 11))
                    .foregroundColor(subtleText)
            }
        }
    }
}

struct SacredWaitingView: View {
    var entry: UnblockProvider.Entry

    var body: some View {
        VStack(spacing: 10) {
            // Hourglass icon
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                    )

                Image(systemName: "hourglass")
                    .font(.system(size: 20))
                    .foregroundColor(sacredGold)
            }

            Text("UNBLOCK IN")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtleText)

            if let target = entry.unlockAvailableAt {
                Text(target, style: .timer)
                    .font(.system(size: 22, weight: .light).monospacedDigit())
                    .foregroundColor(.white)
            }

            // Disabled button
            Text("Unblock Apps")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(subtleText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
    }
}

struct SacredReadyView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Unlock icon
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(softGreen.opacity(0.5), lineWidth: 1)
                    )

                Image(systemName: "lock.open.fill")
                    .font(.system(size: 20))
                    .foregroundColor(softGreen)
            }

            Text("READY TO UNBLOCK")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(softGreen.opacity(0.8))

            Button(intent: UnblockAppIntent()) {
                Text("Unblock Apps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(softGreen.opacity(0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Widget Configuration

struct UnblockWidget: Widget {
    let kind: String = "UnblockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UnblockProvider()) { entry in
            UnblockWidgetView(entry: entry)
        }
        .configurationDisplayName("Unblock Apps")
        .description("Countdown to unblock apps after prayer.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    UnblockWidget()
} timeline: {
    UnblockEntry(date: .now, state: .idle, nextPrayerName: "Dhuhr", nextPrayerTime: Date().addingTimeInterval(1200), unlockAvailableAt: nil, isPremium: true)
    UnblockEntry(date: .now, state: .waiting, nextPrayerName: "Dhuhr", nextPrayerTime: nil, unlockAvailableAt: Date().addingTimeInterval(120), isPremium: true)
    UnblockEntry(date: .now, state: .ready, nextPrayerName: "Dhuhr", nextPrayerTime: nil, unlockAvailableAt: Date().addingTimeInterval(-60), isPremium: true)
}
