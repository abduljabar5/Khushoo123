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
    
    @State private var likedItems: [LikedSurahViewModel] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading liked tracks...")
            } else if likedItems.isEmpty {
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
                List(likedItems) { item in
                    LikedSurahRow(item: item)
                        .onTapGesture {
                            play(item: item)
                        }
                }
            }
        }
        .navigationTitle("Liked")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLikedItems()
        }
    }
    
    private func loadLikedItems() {
        isLoading = true
        let likedItemsSet = audioPlayerService.getLikedItems()
        
        Task {
            do {
                let allSurahs = try await quranAPIService.fetchSurahs()
                let allReciters = try await quranAPIService.fetchReciters()
                
                let viewModels = likedItemsSet.compactMap { likedItem -> LikedSurahViewModel? in
                    guard let surah = allSurahs.first(where: { $0.number == likedItem.surahNumber }) else { return nil }
                    guard let reciter = allReciters.first(where: { $0.identifier == likedItem.reciterIdentifier }) else { return nil }
                    return LikedSurahViewModel(surah: surah, reciter: reciter)
                }
                
                DispatchQueue.main.async {
                    self.likedItems = viewModels.sorted(by: { $0.surah.number < $1.surah.number })
                    self.isLoading = false
                }
            } catch {
                print("❌ [LikedSurahsView] Error loading liked items: \(error)")
                DispatchQueue.main.async {
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