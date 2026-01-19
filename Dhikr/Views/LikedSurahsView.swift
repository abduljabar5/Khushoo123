//
//  LikedSurahsView.swift
//  Dhikr
//
//  Sacred Minimalism redesign
//

import SwiftUI
import Kingfisher

struct LikedSurahViewModel: Identifiable {
    var id: String { "\(surah.id)-\(reciter.id)" }
    let surah: Surah
    let reciter: Reciter
}

struct LikedSurahsView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    @State private var allSurahs: [Surah] = []
    @State private var allReciters: [Reciter] = []
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

    var likedSurahViewModels: [LikedSurahViewModel] {
        let sortedLikedItems = audioPlayerService.likedItems.sorted { $0.dateAdded > $1.dateAdded }

        return sortedLikedItems.compactMap { likedItem -> LikedSurahViewModel? in
            guard let surah = allSurahs.first(where: { $0.number == likedItem.surahNumber }) else { return nil }
            guard let reciter = allReciters.first(where: { $0.identifier == likedItem.reciterIdentifier }) else { return nil }
            return LikedSurahViewModel(surah: surah, reciter: reciter)
        }
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading {
                    loadingView
                } else if likedSurahViewModels.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(likedSurahViewModels) { item in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    play(item: item)
                                }) {
                                    SacredLikedSurahRow(item: item, accentColor: sacredGold)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("LIKED TRACKS")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(warmGray)

                    if !isLoading {
                        Text("\(likedSurahViewModels.count) tracks")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }
            }
        }
        .onAppear {
            loadInitialData()
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(sacredGold)
            Text("Loading...")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: "heart")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(sacredGold.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("No Liked Tracks")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Tap the heart on the player\nto save your favorites")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func loadInitialData() {
        guard isLoading else { return }

        Task {
            do {
                async let surahs = quranAPIService.fetchSurahs()
                async let reciters = quranAPIService.fetchReciters()

                let (fetchedSurahs, fetchedReciters) = try await (surahs, reciters)

                await MainActor.run {
                    self.allSurahs = fetchedSurahs
                    self.allReciters = fetchedReciters
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func play(item: LikedSurahViewModel) {
        audioPlayerService.load(surah: item.surah, reciter: item.reciter)
    }
}

// MARK: - Sacred Liked Surah Row
struct SacredLikedSurahRow: View {
    let item: LikedSurahViewModel
    let accentColor: Color

    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Artwork
            KFImage(item.reciter.artworkURL)
                .placeholder {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.1))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(accentColor.opacity(0.5))
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.surah.englishName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)

                    Text(item.surah.name)
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundColor(warmGray)
                }

                Text(item.reciter.englishName)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Heart and Play
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))

                Image(systemName: "play.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        LikedSurahsView()
            .environmentObject(AudioPlayerService.shared)
            .environmentObject(QuranAPIService.shared)
    }
}
