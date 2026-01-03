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
}

enum UnblockState {
    case idle // Not blocking
    case waiting // Blocking active, waiting for 5 min timer
    case ready // 5 min timer over, ready to unblock
}

// MARK: - Provider

struct UnblockProvider: TimelineProvider {
    func placeholder(in context: Context) -> UnblockEntry {
        UnblockEntry(date: Date(), state: .idle, nextPrayerName: "Fajr", nextPrayerTime: Date().addingTimeInterval(3600), unlockAvailableAt: nil)
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
                unlockAvailableAt: unlockTime
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
    
    private func createEntry() -> UnblockEntry {
        let now = Date()
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return UnblockEntry(date: now, state: .idle, nextPrayerName: nil, nextPrayerTime: nil, unlockAvailableAt: nil)
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
            unlockAvailableAt: unlockAvailableAt
        )
    }
}

// MARK: - View

struct UnblockWidgetView: View {
    var entry: UnblockProvider.Entry
    
    var body: some View {
        VStack {
            if entry.state == .idle {
                IdleView(entry: entry)
            } else if entry.state == .waiting {
                WaitingView(entry: entry)
            } else {
                ReadyView()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct IdleView: View {
    var entry: UnblockProvider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.slash")
                .font(.title)
                .foregroundColor(.secondary)
            
            if let name = entry.nextPrayerName, let time = entry.nextPrayerTime {
                Text("Next: \(name)")
                    .font(.headline)
                Text(time, style: .timer)
                    .font(.monospacedDigit(.subheadline)())
                    .foregroundColor(.secondary)
            } else {
                Text("No active blocking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WaitingView: View {
    var entry: UnblockProvider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Unblock in")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let target = entry.unlockAvailableAt {
                Text(target, style: .timer)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
            }
            
            Button("Unblock Apps") {
                // Disabled
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .disabled(true)
        }
    }
}

struct ReadyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.title)
                .foregroundColor(.green)
            
            Text("You can now unblock")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(intent: UnblockAppIntent()) {
                Text("Unblock Apps")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal)
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
    UnblockEntry(date: .now, state: .idle, nextPrayerName: "Dhuhr", nextPrayerTime: Date().addingTimeInterval(1200), unlockAvailableAt: nil)
    UnblockEntry(date: .now, state: .waiting, nextPrayerName: "Dhuhr", nextPrayerTime: nil, unlockAvailableAt: Date().addingTimeInterval(120))
    UnblockEntry(date: .now, state: .ready, nextPrayerName: "Dhuhr", nextPrayerTime: nil, unlockAvailableAt: Date().addingTimeInterval(-60))
}
