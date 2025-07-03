//
//  FavoritesView.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 6/25/25.
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @State private var likedSurahs: [Surah] = []
    @State private var isLoading = true
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading favorites...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if likedSurahs.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Favorites Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Like surahs while listening to add them here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(likedSurahs) { surah in
                        FavoriteSurahRow(surah: surah)
                            .onTapGesture {
                                playSurah(surah)
                            }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadFavorites()
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
    }
    
    private func loadFavorites() {
        Task {
            do {
                let allSurahs = try await quranAPIService.fetchSurahs()
                let likedSurahNumbers = Set(UserDefaults.standard.array(forKey: "likedSurahs") as? [Int] ?? [])
                
                await MainActor.run {
                    self.likedSurahs = allSurahs.filter { likedSurahNumbers.contains($0.number) }
                    self.isLoading = false
                }
            } catch {
                print("❌ [FavoritesView] Error loading favorites: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func playSurah(_ surah: Surah) {
        Task {
            do {
                let reciters = try await quranAPIService.fetchReciters()
                if let firstReciter = reciters.first {
                    await MainActor.run {
                        audioPlayerService.load(surah: surah, reciter: firstReciter)
                        showingFullScreenPlayer = true
                    }
                }
            } catch {
                print("❌ [FavoritesView] Error playing surah: \(error)")
            }
        }
    }
}

struct FavoriteSurahRow: View {
    let surah: Surah
    
    var body: some View {
        HStack(spacing: 16) {
            // Surah number circle
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text("\(surah.number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            // Surah info
            VStack(alignment: .leading, spacing: 4) {
                Text(surah.englishName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(surah.englishNameTranslation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(surah.numberOfAyahs) Ayahs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play button
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    FavoritesView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
} 