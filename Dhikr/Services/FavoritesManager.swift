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
    private let favoritesKey = "favoriteReciters_v1"
    
    @Published var favoriteReciterIdentifiers: Set<String>
    
    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        self.favoriteReciterIdentifiers = Set(saved)
    }
    
    /// Toggles the favorite status for a given reciter.
    func toggleFavorite(reciter: Reciter) {
        if favoriteReciterIdentifiers.contains(reciter.identifier) {
            favoriteReciterIdentifiers.remove(reciter.identifier)
        } else {
            favoriteReciterIdentifiers.insert(reciter.identifier)
        }
        
        UserDefaults.standard.set(Array(favoriteReciterIdentifiers), forKey: favoritesKey)
    }
    
    /// Checks if a reciter is marked as a favorite.
    func isFavorite(reciter: Reciter) -> Bool {
        return favoriteReciterIdentifiers.contains(reciter.identifier)
    }
} 