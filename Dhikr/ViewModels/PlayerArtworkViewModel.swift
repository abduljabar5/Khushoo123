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

    private let unsplashService = UnsplashService.shared
    private let surahImageService = SurahImageService.shared
    private let imageURLCache = NSCache<NSString, NSURL>()
    private var cancellables = Set<AnyCancellable>()
    private let persistentCacheKey = "artworkURLPersistentCache_Unsplash"
    private let audioPlayerService: AudioPlayerService

    init(audioPlayerService: AudioPlayerService) {
        self.audioPlayerService = audioPlayerService
        loadPersistentCache() // Load saved URLs into memory on initialization

        audioPlayerService.$currentSurah
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] surah in
                guard let self = self, let surah = surah else { return }
                self.fetchArtwork(for: surah)
            }
            .store(in: &cancellables)
    }

    /// Loads the persistently stored URL cache from UserDefaults into the in-memory NSCache.
    private func loadPersistentCache() {
        guard let savedCache = UserDefaults.standard.dictionary(forKey: persistentCacheKey) as? [String: String] else {
            return
        }
        for (key, urlString) in savedCache {
            if let url = URL(string: urlString) {
                imageURLCache.setObject(url as NSURL, forKey: key as NSString)
            }
        }
    }

    /// Saves a new URL to the persistent UserDefaults cache.
    private func saveToPersistentCache(key: String, url: URL) {
        var savedCache = UserDefaults.standard.dictionary(forKey: persistentCacheKey) as? [String: String] ?? [:]
        savedCache[key] = url.absoluteString
        UserDefaults.standard.set(savedCache, forKey: persistentCacheKey)
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
        
        // Clear caches for the current surah
        let cacheKey = surah.englishName as NSString
        imageURLCache.removeObject(forKey: cacheKey)
        
        var savedCache = UserDefaults.standard.dictionary(forKey: persistentCacheKey) as? [String: String] ?? [:]
        savedCache.removeValue(forKey: surah.englishName)
        UserDefaults.standard.set(savedCache, forKey: persistentCacheKey)

        // Trigger a new fetch
        fetchArtwork(for: surah)
    }
} 