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
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let unsplashService = UnsplashService.shared
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
        let cacheKey = surah.englishName as NSString

        // 1. Check in-memory cache first
        if let cachedURL = imageURLCache.object(forKey: cacheKey) {
            self.artworkURL = cachedURL as URL
            return
        }

        // 2. If not in cache, start loading and fetch from API
        self.isLoading = true
        self.errorMessage = nil
        self.artworkURL = nil

        Task {
            do {
                let url = try await unsplashService.fetchNatureImageURL(query: surah.englishName)
                
                // 3. Update UI and save to both in-memory and persistent caches
                self.artworkURL = url
                self.imageURLCache.setObject(url as NSURL, forKey: cacheKey)
                self.saveToPersistentCache(key: surah.englishName, url: url)
                
            } catch {
                if let unsplashError = error as? UnsplashError, case .networkError(let statusCode) = unsplashError {
                    self.errorMessage = "Network Error (\(statusCode ?? 0))"
                } else {
                    self.errorMessage = "Error fetching artwork"
                }
                print("❌ [PlayerArtworkViewModel] Error: \(error.localizedDescription)")
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