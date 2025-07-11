//
//  LikedSurahsView.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct LikedSurahViewModel: Identifiable {
    var id: String { "\(surah.id)-\(reciter.id)" }
    let surah: Surah
    let reciter: Reciter
}

struct LikedSurahsView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    
    @State private var allSurahs: [Surah] = []
    @State private var allReciters: [Reciter] = []
    @State private var isLoading = true
    
    var likedSurahViewModels: [LikedSurahViewModel] {
        // Sort the liked items by date before mapping to view models
        let sortedLikedItems = audioPlayerService.likedItems.sorted { $0.dateAdded > $1.dateAdded }
        
        return sortedLikedItems.compactMap { likedItem -> LikedSurahViewModel? in
            guard let surah = allSurahs.first(where: { $0.number == likedItem.surahNumber }) else { return nil }
            guard let reciter = allReciters.first(where: { $0.identifier == likedItem.reciterIdentifier }) else { return nil }
            return LikedSurahViewModel(surah: surah, reciter: reciter)
        }
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
            } else if likedSurahViewModels.isEmpty {
                VStack {
                    Image(systemName: "heart.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No Liked Tracks Yet")
                        .font(.headline)
                        .padding(.top)
                    Text("You can like a track from the player screen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List(likedSurahViewModels) { item in
                    LikedSurahRow(item: item)
                        .onTapGesture {
                            play(item: item)
                        }
                }
            }
        }
        .navigationTitle("Liked Tracks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadInitialData()
        }
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
                print("❌ [LikedSurahsView] Error loading initial data: \(error)")
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

struct LikedSurahRow: View {
    let item: LikedSurahViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.surah.englishName)
                    .font(.headline)
                Text(item.reciter.englishName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "play.circle")
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 8)
    }
}

struct LikedSurahsView_Previews: PreviewProvider {
    static var previews: some View {
        LikedSurahsView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
    }
} 