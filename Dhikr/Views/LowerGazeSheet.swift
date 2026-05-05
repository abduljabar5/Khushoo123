//
//  LowerGazeSheet.swift
//  Dhikr
//
//  Duration picker for the Lower Gaze (panic) feature. Shown when the user
//  taps the button on the Haya Mode card. Picks duration → starts shield.
//
//  If the panic-specific app selection is empty (first run), prompts the
//  user to pick apps via FamilyActivityPicker before they can choose a
//  duration. Subsequent runs skip the picker.
//

import SwiftUI
import FamilyControls

struct LowerGazeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var panicService = PanicModeService.shared
    @StateObject private var selectionModel = PanicAppSelectionModel.shared

    @State private var showAppPicker = false
    /// Last-used duration is remembered between sessions so the picker pre-selects
    /// the user's recent choice on subsequent opens. Stored in seconds. Default
    /// 30 min on first run.
    @AppStorage("lowerGazeLastUsedDuration") private var lastUsedDuration: Double = 1800
    @State private var selectedDuration: TimeInterval = 1800

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var softGreen: Color { Color(red: 0.55, green: 0.68, blue: 0.55) }
    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }
    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }
    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    /// Built-in presets. Until-next-prayer is dynamic.
    private struct DurationOption: Identifiable {
        let id = UUID()
        let label: String
        let seconds: TimeInterval
    }

    private var durationOptions: [DurationOption] {
        var opts: [DurationOption] = [
            DurationOption(label: "15 min", seconds: 15 * 60),
            DurationOption(label: "30 min", seconds: 30 * 60),
            DurationOption(label: "1 hour", seconds: 60 * 60),
            DurationOption(label: "2 hours", seconds: 2 * 60 * 60),
        ]
        if let prayer = nextPrayerTime() {
            let secondsUntil = prayer.time.timeIntervalSinceNow
            // Only show "until prayer" if it's at least 5 minutes away — sub-5min
            // is too short to be useful and feels weird.
            if secondsUntil > 5 * 60 {
                opts.append(DurationOption(
                    label: "Until \(prayer.name) (\(formatPrayerWindow(secondsUntil)))",
                    seconds: secondsUntil
                ))
            }
        }
        return opts
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(sacredGold.opacity(0.12))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(sacredGold)
                            }

                            Text("Lower Gaze")
                                .font(.system(size: 24, weight: .light, design: .serif))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("Block social apps when tempted.\nCannot be disabled until the timer ends.")
                                .font(.system(size: 13))
                                .foregroundColor(warmGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 12)

                        // Empty state: show a prominent setup card up top so
                        // existing Haya users (who installed before the chained-
                        // picker flow shipped) have an obvious path to configure
                        // their app block list. Without this, the only entry was
                        // the small "Add apps" text link below — too easy to miss.
                        if !selectionModel.hasSelection {
                            setupAppsCard
                        }

                        durationPickerCards
                        startButton

                        if selectionModel.hasSelection {
                            changeAppsLink
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(warmGray.opacity(0.6))
                    }
                }
            }
            .familyActivityPicker(
                isPresented: $showAppPicker,
                selection: $selectionModel.selection
            )
            .onChange(of: showAppPicker) { showing in
                // Persist immediately when the picker closes so the next run
                // sees the new selection without waiting for the debounce.
                if !showing { selectionModel.forceSave() }
            }
            .onAppear {
                // Pre-select the user's last-used duration when the sheet opens.
                selectedDuration = lastUsedDuration
            }
        }
    }

    // MARK: - First-Run Picker

    private var firstRunPickerCard: some View {
        VStack(spacing: 16) {
            Text("Pick the apps to block")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.theme.primaryText)

            Text("Choose the social apps you want Lower Gaze to block. We recommend Instagram, TikTok, X, Snapchat, and YouTube.")
                .font(.system(size: 12))
                .foregroundColor(warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button(action: {
                HapticManager.shared.impact(.light)
                showAppPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                    Text("Choose apps")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(sacredGold))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Duration Cards

    private var durationPickerCards: some View {
        VStack(spacing: 10) {
            ForEach(durationOptions) { option in
                Button(action: {
                    HapticManager.shared.selection()
                    selectedDuration = option.seconds
                }) {
                    HStack {
                        Text(option.label)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)
                        Spacer()
                        if abs(selectedDuration - option.seconds) < 1 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(sacredGold)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(warmGray.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        abs(selectedDuration - option.seconds) < 1
                                            ? sacredGold.opacity(0.4)
                                            : sacredGold.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            }
        }
    }

    private var startButton: some View {
        Button(action: startSession) {
            HStack(spacing: 10) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 14))
                Text("Start Lower Gaze")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(sacredGold)
            )
        }
        .padding(.top, 4)
    }

    private var changeAppsLink: some View {
        Button(action: { showAppPicker = true }) {
            Text(selectionModel.hasSelection ? "Change apps to block" : "Add apps to block")
                .font(.system(size: 12))
                .foregroundColor(warmGray)
        }
        .padding(.top, 4)
    }

    /// Prominent first-run setup card for users who haven't picked any apps yet.
    /// Shown when PanicAppSelectionModel is empty — most importantly, for users
    /// who already had Haya Mode enabled before the chained-picker flow existed,
    /// since they never got the auto-prompt during Haya enable.
    private var setupAppsCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(sacredGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set up your block list")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                    Text("Pick the social apps Lower Gaze should block. Recommended: Instagram, TikTok, X, Snapchat, YouTube.")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(warmGray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button(action: {
                HapticManager.shared.impact(.light)
                showAppPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Pick apps to block")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sacredGold)
                )
            }

            Text("You can still start a session without picking apps — Safari will block social sites either way.")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(warmGray)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sacredGold.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    private func startSession() {
        guard PanicModeService.shared.start(duration: selectedDuration) else {
            // Selection became empty between picker and start — re-prompt
            showAppPicker = true
            return
        }
        // Remember this choice so the next session pre-selects it.
        lastUsedDuration = selectedDuration
        HapticManager.shared.notification(.success)
        dismiss()
    }

    // MARK: - Next-Prayer Helper

    private func nextPrayerTime() -> (name: String, time: Date)? {
        let storage = PrayerTimeService().loadStorage()
        guard let storage = storage else { return nil }

        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Look at today and tomorrow
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            guard let stored = storage.prayerTimes.first(where: {
                calendar.isDate($0.date, inSameDayAs: dayStart)
            }) else { continue }

            let prayers: [(String, String)] = [
                ("Fajr", stored.fajr),
                ("Dhuhr", stored.dhuhr),
                ("Asr", stored.asr),
                ("Maghrib", stored.maghrib),
                ("Isha", stored.isha),
            ]

            for (name, timeString) in prayers {
                let cleanString = timeString.components(separatedBy: " ")[0]
                guard let parsed = formatter.date(from: cleanString) else { continue }
                let comps = calendar.dateComponents([.hour, .minute], from: parsed)
                guard let combined = calendar.date(
                    bySettingHour: comps.hour ?? 0,
                    minute: comps.minute ?? 0,
                    second: 0,
                    of: dayStart
                ) else { continue }

                if combined > now {
                    return (name, combined)
                }
            }
        }
        return nil
    }

    private func formatPrayerWindow(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
