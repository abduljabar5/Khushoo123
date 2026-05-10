//
//  WhatsNewSheet.swift
//  Dhikr
//
//  Cold-start "What's new in 1.1.7" announcement. Top section showcases the
//  two new Cloudflare reciters with one-tap audio preview; below is a
//  short bullet list of other improvements.
//
//  Currently shows on every cold start — see MainTabView for the trigger.
//  When ready for production, gate by @AppStorage("hasSeenWhatsNew_v1.1.7").
//

import SwiftUI
import Kingfisher

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    /// Persistent flag flipped to true on first dismiss. MainTabView gates
    /// presentation on the inverse so the sheet shows exactly once per user
    /// per major version. Bump the key suffix on subsequent versions.
    @AppStorage("hasSeenWhatsNew_v117") private var hasSeenWhatsNew: Bool = false

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

    /// English-name keys for the new Cloudflare reciters surfaced at the top
    /// of the sheet. These match the names produced by CloudflareReciterService
    /// from the R2 index. Keep in sync if reciter names change there.
    private let newReciterNames: [String] = [
        "Saud Al Jumah",
        "Youssef Al Suqair",
    ]

    /// Default surah to play when user taps a reciter card. Both reciters have
    /// Surah Al-Mulk in their available set, and it's a beloved daily-recite.
    private let previewSurahNumber: Int = 67

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        header
                        newRecitersSection
                        improvementsSection
                        dismissButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        hasSeenWhatsNew = true
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(warmGray.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(sacredGold.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(sacredGold)
            }

            Text("What's New")
                .font(.system(size: 26, weight: .light, design: .serif))
                .foregroundColor(themeManager.theme.primaryText)

            Text("Version 1.1.7")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(warmGray)
        }
        .padding(.top, 8)
    }

    // MARK: - New Reciters

    private var newRecitersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("NEW RECITERS")

            Text("Two new voices joined the catalog. Tap to start listening.")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(warmGray)

            VStack(spacing: 10) {
                ForEach(newReciterNames, id: \.self) { name in
                    if let reciter = quranAPIService.reciters.first(where: { $0.englishName == name }) {
                        reciterCard(reciter)
                    } else {
                        // Catalog hasn't merged yet on this cold start — show
                        // a neutral placeholder so the sheet still feels
                        // intentional rather than half-loaded.
                        loadingReciterPlaceholder(name: name)
                    }
                }
            }
        }
    }

    private func reciterCard(_ reciter: Reciter) -> some View {
        Button(action: { playPreview(for: reciter) }) {
            HStack(spacing: 14) {
                KFImage(reciter.artworkURL)
                    .placeholder {
                        Circle()
                            .fill(sacredGold.opacity(0.1))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(sacredGold)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.25), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(reciter.englishName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(themeManager.theme.primaryText)

                    HStack(spacing: 6) {
                        if let country = reciter.country {
                            Text(country)
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(warmGray)
                        }
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(warmGray)
                        Text("Tap to play Al-Mulk")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(sacredGold)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(sacredGold)
                        .frame(width: 36, height: 36)
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadingReciterPlaceholder(name: String) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(sacredGold.opacity(0.1))
                .frame(width: 56, height: 56)
                .overlay(
                    ProgressView().tint(sacredGold)
                )
            Text(name)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(themeManager.theme.primaryText)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Improvements

    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("ALSO IN 1.1.7")

            VStack(alignment: .leading, spacing: 12) {
                bulletRow(icon: "eye.slash", title: "Lower Gaze",
                    body: "When you feel tempted, block social apps for as long as you need. Free for everyone.")
                bulletRow(icon: "magnifyingglass", title: "Browse every reciter",
                    body: "Free 60-second preview on premium reciters. Search and discover without signing up.")
                bulletRow(icon: "person.crop.circle.badge.plus", title: "Request a reciter",
                    body: "Suggest who you'd love to hear next — we review every week.")
                bulletRow(icon: "star.circle", title: "Daily Spotlight",
                    body: "A new featured reciter every day. Same one for everyone — share what you discover.")
                bulletRow(icon: "sparkles", title: "Beautiful new touches",
                    body: "Animations across the player, dhikr counter, and prayer schedule make the app feel more alive.")
                bulletRow(icon: "bolt", title: "Faster + more stable",
                    body: "Quicker cold starts and fixed a crash some users hit on track auto-advance.")
            }
        }
    }

    private func bulletRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(softGreen.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(softGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)
                Text(body)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(2)
            .foregroundColor(warmGray)
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            hasSeenWhatsNew = true
            dismiss()
        }) {
            Text("Got it")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(sacredGold)
                )
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func playPreview(for reciter: Reciter) {
        HapticManager.shared.impact(.medium)

        Task {
            // Pull a fresh surah list — hardcodedSurahs always covers all 114.
            let surahs = (try? await quranAPIService.fetchSurahs()) ?? []
            guard let surah = surahs.first(where: { $0.number == previewSurahNumber }) else { return }

            await MainActor.run {
                audioPlayerService.load(surah: surah, reciter: reciter)
                audioPlayerService.shouldShowFullScreenPlayer = true
                hasSeenWhatsNew = true
                dismiss()
            }
        }
    }
}
