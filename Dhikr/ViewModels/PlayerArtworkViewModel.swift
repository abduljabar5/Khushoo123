//
//  PlayerArtworkViewModel.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

@MainActor
class PlayerArtworkViewModel: ObservableObject {
    @Published var artworkURL: URL?
    @Published var artworkImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let surahImageService = SurahImageService.shared
    private var cancellables = Set<AnyCancellable>()
    private let audioPlayerService: AudioPlayerService

    init(audioPlayerService: AudioPlayerService) {
        self.audioPlayerService = audioPlayerService

        audioPlayerService.$currentSurah
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] surah in
                guard let self = self, let surah = surah else { return }
                self.fetchArtwork(for: surah)
            }
            .store(in: &cancellables)
    }

    private func fetchArtwork(for surah: Surah) {
        // Priority 1: If user is authenticated, fetch from Firebase Storage
        if Auth.auth().currentUser != nil {
            fetchFromFirebaseStorage(for: surah)
            return
        }

        // Priority 2: If not authenticated, show no artwork
        self.artworkURL = nil
        self.artworkImage = nil
        print("ℹ️ [PlayerArtworkViewModel] User not authenticated - no artwork shown")
    }

    private func fetchFromFirebaseStorage(for surah: Surah) {
        self.isLoading = true
        self.errorMessage = nil

        Task {
            if let image = await surahImageService.fetchSurahCover(for: surah.number) {
                self.artworkImage = image
                self.artworkURL = nil // Clear URL since we're using direct image
                print("✅ [PlayerArtworkViewModel] Loaded Firebase surah cover for surah \(surah.number)")
            } else {
                // Fallback: no artwork for authenticated users if Firebase fetch fails
                self.artworkImage = nil
                self.artworkURL = nil
                print("⚠️ [PlayerArtworkViewModel] Failed to load Firebase cover for surah \(surah.number)")
            }
            self.isLoading = false
        }
    }

    func forceRefreshArtwork() {
        guard let surah = self.audioPlayerService.currentSurah else {
            print("❌ [PlayerArtworkViewModel] Could not force refresh, surah not available.")
            return
        }

        print("🔄 [PlayerArtworkViewModel] Forcing refresh for surah: \(surah.englishName)")

        // Trigger a new fetch
        fetchArtwork(for: surah)
    }
} 