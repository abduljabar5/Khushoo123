//
//  FavoritesManager.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import Foundation
import Combine

class FavoritesManager: ObservableObject {
    
    static let shared = FavoritesManager()
    private let oldFavoritesKey = "favoriteReciters_v1"
    private let newFavoritesKey = "favoriteReciters_v2"
    
    @Published var favoriteReciters: [FavoriteReciterItem] = [] {
        didSet {
            saveFavorites()
        }
    }
    
    private init() {
        // Attempt to load new format first
        if let data = UserDefaults.standard.data(forKey: newFavoritesKey) {
            do {
                self.favoriteReciters = try JSONDecoder().decode([FavoriteReciterItem].self, from: data)
                print("✅ [FavoritesManager] Loaded v2 favorites.")
            } catch {
                print("❌ [FavoritesManager] Failed to decode v2 favorites: \(error). Starting fresh.")
                self.favoriteReciters = []
            }
        } else {
            // If new format doesn't exist, migrate from old format
            print("ℹ️ [FavoritesManager] v2 favorites not found. Attempting to migrate from v1.")
            migrateFromOldFormat()
        }
    }
    
    private func migrateFromOldFormat() {
        let oldIdentifiers = UserDefaults.standard.stringArray(forKey: oldFavoritesKey) ?? []
        if !oldIdentifiers.isEmpty {
            // Convert old string identifiers to the new struct, giving them a distant past date
            // so they appear at the end of the sorted list.
            self.favoriteReciters = oldIdentifiers.map {
                FavoriteReciterItem(identifier: $0, dateAdded: Date.distantPast)
            }
            print("✅ [FavoritesManager] Migrated \(oldIdentifiers.count) favorites from v1 to v2.")
            
            // Save in the new format and remove the old key
            saveFavorites()
            UserDefaults.standard.removeObject(forKey: oldFavoritesKey)
            print("ℹ️ [FavoritesManager] Removed old v1 favorites key.")
        } else {
            print("ℹ️ [FavoritesManager] No v1 favorites to migrate.")
            self.favoriteReciters = []
        }
    }
    
    /// Toggles the favorite status for a given reciter.
    func toggleFavorite(reciter: Reciter) {
        if isFavorite(reciter: reciter) {
            favoriteReciters.removeAll { $0.identifier == reciter.identifier }
        } else {
            let newItem = FavoriteReciterItem(identifier: reciter.identifier)
            favoriteReciters.append(newItem)
        }
    }
    
    /// Checks if a reciter is marked as a favorite.
    func isFavorite(reciter: Reciter) -> Bool {
        return favoriteReciters.contains { $0.identifier == reciter.identifier }
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteReciters)
            UserDefaults.standard.set(data, forKey: newFavoritesKey)
        } catch {
            print("❌ [FavoritesManager] Failed to encode and save v2 favorites: \(error)")
        }
    }
} 