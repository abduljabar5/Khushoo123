//
//  PlayerArtworkViewModel.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import Foundation
import Combine
import SwiftUI

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
        self.isLoading = true
        self.errorMessage = nil

        Task {
            if let image = await surahImageService.fetchSurahCover(for: surah.number) {
                self.artworkImage = image
                self.artworkURL = nil
            } else {
                self.artworkImage = nil
                self.artworkURL = nil
            }
            self.isLoading = false
        }
    }

    func forceRefreshArtwork() {
        guard let surah = self.audioPlayerService.currentSurah else {
            return
        }


        // Trigger a new fetch
        fetchArtwork(for: surah)
    }
} 