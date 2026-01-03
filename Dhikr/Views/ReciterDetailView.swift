//
//  ReciterDetailView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher

struct ReciterDetailView: View {
    let reciter: Reciter
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @ObservedObject private var recentsManager = RecentsManager.shared
    @State private var surahs: [Surah] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Reciter Statistics
                reciterStatsSection

                // Surahs
                surahsSection
            }
        }
        .navigationTitle(reciter.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSurahs)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            ReciterArtworkImage(
                artworkURL: reciter.artworkURL,
                reciterName: reciter.name,
                size: 120
            )
            .shadow(radius: 8)
            .padding(.top)
            
            VStack(spacing: 4) {
                Text(reciter.englishName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Language: \(reciter.language.uppercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Reciter Statistics Section
    private var reciterStatsSection: some View {
        HStack(spacing: 16) {
            // Total Plays
            ReciterStatBubble(
                icon: "play.circle.fill",
                label: "Total Plays",
                value: "\(getReciterPlayCount())",
                color: .blue
            )

            // Unique Surahs
            ReciterStatBubble(
                icon: "music.note.list",
                label: "Surahs",
                value: "\(getUniqueSurahsCount())",
                color: .purple
            )

            // Last Played
            ReciterStatBubble(
                icon: "clock.fill",
                label: "Last Played",
                value: getLastPlayedText(),
                color: .orange
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Reciter Statistics Helpers
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
            HStack {
                Text(reciter.hasCompleteQuran ? "All Surahs" : "Available Surahs")
                    .font(.headline)
                    .fontWeight(.semibold)

                if !reciter.hasCompleteQuran {
                    Text("(\(surahs.count) of 114)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(surahs) { surah in
                        Button(action: {
                            // All reciters are now supported with verse-by-verse audio
                            audioPlayerService.load(surah: surah, reciter: reciter)
                        }) {
                            SurahRow(surah: surah, isPlaying: audioPlayerService.currentSurah == surah && audioPlayerService.isPlaying)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
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
                    // Filter surahs to only show ones this reciter has audio for
                    self.surahs = allSurahs.filter { reciter.hasSurah($0.number) }
                    self.isLoading = false
                }
            } catch {
                print("Error loading surahs: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct SurahRow: View {
    let surah: Surah
    var isPlaying: Bool = false
    @EnvironmentObject var audioPlayerService: AudioPlayerService

    var isCompleted: Bool {
        audioPlayerService.completedSurahNumbers.contains(surah.number)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Surah Number with completion indicator
            ZStack(alignment: .bottomTrailing) {
                Text("\(surah.number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 35, height: 35)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Circle())

                // Completion checkmark badge
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 12, height: 12)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Surah Info
            VStack(alignment: .leading, spacing: 4) {
                Text(surah.englishName)
                    .font(.headline)

                Text("\(surah.revelationType) - \(surah.numberOfAyahs) Ayahs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reciter Stat Bubble
struct ReciterStatBubble: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationView {
        ReciterDetailView(reciter: Reciter.mock)
            .environmentObject(QuranAPIService.shared)
            .environmentObject(AudioPlayerService.shared)
    }
} 