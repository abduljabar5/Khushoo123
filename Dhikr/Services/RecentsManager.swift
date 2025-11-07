//
//  RecentsManager.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 1723145405.0.
//

import Foundation

class RecentsManager: ObservableObject {
    
    static let shared = RecentsManager()
    @Published private(set) var recentItems: [RecentItem] = []
    
    private let recentsKey = "recentlyPlayedTracks"
    private let maxRecents = 20
    
    private init() {
        loadRecentItems()
    }
    
    /// Loads the list of recently played tracks from UserDefaults.
    private func loadRecentItems() {
        guard let data = UserDefaults.standard.data(forKey: recentsKey) else {
            return
        }
        
        do {
            let items = try JSONDecoder().decode([RecentItem].self, from: data)
            self.recentItems = items
        } catch {
            print("❌ [RecentsManager] Error decoding recent items: \(error)")
        }
    }
    
    /// Adds a track to the list of recently played items.
    func addTrack(surah: Surah, reciter: Reciter) {
        let newItem = RecentItem(surah: surah, reciter: reciter, playedAt: Date())
        
        // Remove the item if it already exists to avoid duplicates and move it to the front.
        recentItems.removeAll { $0.surah.id == newItem.surah.id && $0.reciter.id == newItem.reciter.id }
        
        // Add the new item to the beginning of the list.
        recentItems.insert(newItem, at: 0)
        
        // Ensure the list does not exceed the maximum count.
        if recentItems.count > maxRecents {
            recentItems = Array(recentItems.prefix(maxRecents))
        }
        
        // Save the updated list back to UserDefaults.
        saveItems()
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(recentItems)
            UserDefaults.standard.set(data, forKey: recentsKey)

            // Log the saved data
            let recentData = recentItems.map { item in
                return [
                    "surah": "\(item.surah.number). \(item.surah.englishName)",
                    "reciter": item.reciter.englishName,
                    "playedAt": ISO8601DateFormatter().string(from: item.playedAt)
                ]
            }

            if let json = try? JSONSerialization.data(withJSONObject: ["recentItems": recentData, "count": recentItems.count], options: .prettyPrinted),
               let jsonString = String(data: json, encoding: .utf8) {
                print("💾 [RecentsManager] Recent Items - Data Saved:")
                print(jsonString)
            }
        } catch {
            print("❌ [RecentsManager] Error encoding recent items: \(error)")
        }
    }

    /// Clears all recently played tracks from memory and UserDefaults.
    func clearAll() {
        recentItems.removeAll()
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }
} 