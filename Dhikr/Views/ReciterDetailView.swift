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
    @State private var surahs: [Surah] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
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
            KFImage(reciter.artworkURL)
                .resizable()
                .placeholder {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.gray)
                }
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(radius: 8)
                .padding(.top)
            
            VStack(spacing: 4) {
                Text(reciter.englishName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(reciter.name)
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text("Language: \(reciter.language.uppercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Surahs Section
    private var surahsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Surahs")
                .font(.headline)
                .fontWeight(.semibold)
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
                let quranCentralPrefix = "qurancentral_"

                if reciter.identifier.hasPrefix(quranCentralPrefix) {
                    // This is a Quran Central reciter, so fetch their specific surah list.
                    let slug = String(reciter.identifier.dropFirst(quranCentralPrefix.count))
                    let availableSurahNumbers = try await QuranCentralService.shared.fetchAvailableSurahNumbers(for: slug)
                    
                    let filteredSurahs = allSurahs.filter { availableSurahNumbers.contains($0.number) }
                    
                    await MainActor.run {
                        self.surahs = filteredSurahs
                        self.isLoading = false
                    }
                } else {
                    // This is an MP3Quran.net reciter, load all surahs.
                    await MainActor.run {
                        self.surahs = allSurahs
                        self.isLoading = false
                    }
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Surah Number
            Text("\(surah.number)")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 35, height: 35)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
            
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

#Preview {
    NavigationView {
        ReciterDetailView(reciter: Reciter.mock)
            .environmentObject(QuranAPIService.shared)
            .environmentObject(AudioPlayerService.shared)
    }
} 