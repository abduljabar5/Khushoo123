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
            } catch {
                self.favoriteReciters = []
            }
        } else {
            // If new format doesn't exist, migrate from old format
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
            
            // Save in the new format and remove the old key
            saveFavorites()
            UserDefaults.standard.removeObject(forKey: oldFavoritesKey)
        } else {
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

            // Log the saved data
            let favoritesData = favoriteReciters.map { item in
                return [
                    "identifier": item.identifier,
                    "dateAdded": ISO8601DateFormatter().string(from: item.dateAdded)
                ]
            }

            if let json = try? JSONSerialization.data(withJSONObject: ["favoriteReciters": favoritesData, "count": favoriteReciters.count], options: .prettyPrinted),
               let jsonString = String(data: json, encoding: .utf8) {
            }
        } catch {
        }
    }
} 