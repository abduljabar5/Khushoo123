//
//  ReciterDetailView.swift
//  Dhikr
//
//  Sacred Minimalism redesign of Reciter Detail/Profile page
//

import SwiftUI
import Kingfisher

struct ReciterDetailView: View {
    let reciter: Reciter
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @ObservedObject private var recentsManager = RecentsManager.shared
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var surahs: [Surah] = []
    @State private var isLoading = true

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

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

    private var isFavorite: Bool {
        favoritesManager.isFavorite(reciter: reciter)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                reciterStatsSection
                surahsSection
            }
            .padding(.bottom, 20)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle(reciter.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSurahs)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Avatar with sacred border
            KFImage(reciter.artworkURL)
                .placeholder {
                    SacredReciterPlaceholder(size: 140, iconSize: 48)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(sacredGold.opacity(0.3), lineWidth: 2)
                )
                .padding(.top, 24)

            // Name and info
            VStack(spacing: 8) {
                Text(reciter.englishName)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)

                HStack(spacing: 12) {
                    if let country = reciter.country {
                        SacredDetailTag(text: country, color: softGreen)
                    }
                    if let dialect = reciter.dialect {
                        SacredDetailTag(text: dialect, color: sacredGold)
                    }
                    SacredDetailTag(text: reciter.language.uppercased(), color: warmGray)
                }
            }

            // Action Buttons
            HStack(spacing: 16) {
                // Shuffle Play Button
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    playShuffledSurah()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .medium))
                        Text("Shuffle Play")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(sacredGold)
                    )
                }

                // Bookmark Button
                Button(action: {
                    HapticManager.shared.impact(.light)
                    toggleFavorite()
                }) {
                    Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(isFavorite ? sacredGold : warmGray)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Toggle Favorite
    private func toggleFavorite() {
        favoritesManager.toggleFavorite(reciter: reciter)
    }

    // MARK: - Shuffle Play
    private func playShuffledSurah() {
        guard !surahs.isEmpty else { return }
        let randomSurah = surahs.randomElement()!
        audioPlayerService.load(surah: randomSurah, reciter: reciter)
    }

    // MARK: - Reciter Statistics Section
    private var reciterStatsSection: some View {
        HStack(spacing: 0) {
            SacredReciterStatCard(
                icon: "play.circle",
                label: "PLAYS",
                value: "\(getReciterPlayCount())",
                color: softGreen
            )

            // Divider
            Rectangle()
                .fill(warmGray.opacity(0.2))
                .frame(width: 1, height: 50)

            SacredReciterStatCard(
                icon: "music.note.list",
                label: "SURAHS",
                value: "\(getUniqueSurahsCount())",
                color: sacredGold
            )

            // Divider
            Rectangle()
                .fill(warmGray.opacity(0.2))
                .frame(width: 1, height: 50)

            SacredReciterStatCard(
                icon: "clock",
                label: "LAST PLAYED",
                value: getLastPlayedText(),
                color: warmGray
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Statistics Helpers
    private func getReciterPlayCount() -> Int {
        return recentsManager.recentItems.filter { $0.reciter.identifier == reciter.identifier }.count
    }

    private func getUniqueSurahsCount() -> Int {
        let uniqueSurahs = Set(recentsManager.recentItems
            .filter { $0.reciter.identifier == reciter.identifier }
            .map { $0.surah.number })
        return uniqueSurahs.count
    }

    private func getLastPlayedText() -> String {
        guard let lastPlayed = recentsManager.recentItems
            .filter({ $0.reciter.identifier == reciter.identifier })
            .first else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastPlayed.playedAt, relativeTo: Date())
    }

    // MARK: - Surahs Section
    private var surahsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(reciter.hasCompleteQuran ? "ALL SURAHS" : "AVAILABLE SURAHS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Spacer()

                if !reciter.hasCompleteQuran {
                    Text("\(surahs.count) of 114")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(warmGray)
                }
            }
            .padding(.horizontal, 20)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(sacredGold)
                    Spacer()
                }
                .frame(minHeight: 200)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(surahs) { surah in
                        Button(action: {
                            audioPlayerService.load(surah: surah, reciter: reciter)
                        }) {
                            SacredSurahRow(
                                surah: surah,
                                isPlaying: audioPlayerService.currentSurah == surah && audioPlayerService.isPlaying,
                                isCompleted: audioPlayerService.completedSurahNumbers.contains(surah.number)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Data Loading
    private func loadSurahs() {
        isLoading = true
        Task {
            do {
                let allSurahs = try await quranAPIService.fetchSurahs()
                await MainActor.run {
                    self.surahs = allSurahs.filter { reciter.hasSurah($0.number) }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Sacred Detail Tag

private struct SacredDetailTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Sacred Reciter Stat Card

private struct SacredReciterStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .ultraLight))
                .foregroundColor(themeManager.theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundColor(color.opacity(0.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sacred Surah Row

private struct SacredSurahRow: View {
    let surah: Surah
    let isPlaying: Bool
    let isCompleted: Bool

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

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
        HStack(spacing: 14) {
            // Surah Number with completion indicator
            ZStack(alignment: .bottomTrailing) {
                Text("\(surah.number)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(sacredGold)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(sacredGold.opacity(0.1))
                    )

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(softGreen)
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Surah Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(surah.englishName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text(surah.name)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundColor(warmGray)
                }

                Text("\(surah.revelationType) · \(surah.numberOfAyahs) Ayahs")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(warmGray)
            }

            Spacer()

            // Play indicator
            if isPlaying {
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(sacredGold)
                    .symbolEffect(.variableColor.iterative)
            } else {
                Image(systemName: "play.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(warmGray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(sacredGold.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ReciterDetailView(reciter: Reciter.mock)
            .environmentObject(QuranAPIService.shared)
            .environmentObject(AudioPlayerService.shared)
    }
}
