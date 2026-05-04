//
//  LowerGazeBanner.swift
//  Dhikr
//
//  Banner shown at the top of the Focus tab while a Lower Gaze (panic)
//  session is active. Non-dismissable — there is no early stop.
//
//  Tapping expands into a fuller view with cooloff CTAs that keep the
//  user inside Khushoo (Quran selections, dhikr counter) instead of
//  bouncing to other apps during the cooloff window.
//

import SwiftUI

struct LowerGazeBanner: View {
    @StateObject private var panicService = PanicModeService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isExpanded = false

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var softGreen: Color { Color(red: 0.55, green: 0.68, blue: 0.55) }
    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }
    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        if panicService.isActive {
            VStack(spacing: 0) {
                // Compact header (always visible)
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(sacredGold.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(sacredGold)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("LOWER GAZE")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(sacredGold)
                            Text(panicService.formattedTimeRemaining)
                                .font(.system(size: 16, weight: .light))
                                .monospacedDigit()
                                .foregroundColor(themeManager.theme.primaryText)
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(warmGray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                if isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Expanded Cooloff Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider().background(sacredGold.opacity(0.15))

            Text("REPLACE THE URGE")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(warmGray)

            VStack(spacing: 8) {
                cooloffRow(
                    icon: "headphones",
                    title: "Listen to Surah Mulk",
                    subtitle: "30-minute recitation",
                    action: { openSurah(67) }
                )
                cooloffRow(
                    icon: "circle.dotted",
                    title: "Make 100 dhikr",
                    subtitle: "Subhan Allah · Alhamdulillah · Allahu Akbar",
                    action: openDhikr
                )
                cooloffRow(
                    icon: "book.closed",
                    title: "Read a verse",
                    subtitle: "Today's verse of the day",
                    action: scrollToVerse
                )
            }

            Text("Apps unblock automatically when the timer ends.")
                .font(.system(size: 11))
                .foregroundColor(warmGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func cooloffRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(softGreen.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(softGreen)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(themeManager.theme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(warmGray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(warmGray.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(softGreen.opacity(0.05))
            )
        }
    }

    // MARK: - Cooloff Actions

    /// Deep-link into the player by loading a specific surah with the user's
    /// last-played reciter (or the first popular one we can find).
    private func openSurah(_ surahNumber: Int) {
        Task { @MainActor in
            let api = QuranAPIService.shared
            let player = AudioPlayerService.shared

            let reciter = player.currentReciter
                ?? api.reciters.first(where: { !$0.isPremium })
                ?? api.reciters.first

            let surah: Surah?
            do {
                surah = try await api.fetchSurahs().first(where: { $0.number == surahNumber })
            } catch {
                surah = nil
            }

            if let reciter = reciter, let surah = surah {
                player.load(surah: surah, reciter: reciter)
                player.shouldShowFullScreenPlayer = true
            }
        }
    }

    private func openDhikr() {
        // Post a notification — MainTabView listens and switches tabs.
        NotificationCenter.default.post(name: .lowerGazeOpenDhikr, object: nil)
    }

    private func scrollToVerse() {
        NotificationCenter.default.post(name: .lowerGazeOpenVerse, object: nil)
    }
}

extension Notification.Name {
    static let lowerGazeOpenDhikr = Notification.Name("lowerGazeOpenDhikr")
    static let lowerGazeOpenVerse = Notification.Name("lowerGazeOpenVerse")
}
