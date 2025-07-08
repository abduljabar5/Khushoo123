import Foundation

class RecentRecitersManager {
    
    static let shared = RecentRecitersManager()
    private let recentsKey = "recentlyViewedReciters_v2" // Use a new key to avoid conflicts
    private let maxRecents = 10
    
    private init() {}
    
    /// Loads the list of recently viewed reciters from UserDefaults.
    func loadRecentReciters() -> [Reciter] {
        guard let data = UserDefaults.standard.data(forKey: recentsKey) else {
            return []
        }
        
        do {
            let reciters = try JSONDecoder().decode([Reciter].self, from: data)
            return reciters
        } catch {
            print("❌ [RecentRecitersManager] Error decoding recent reciters: \(error)")
            return []
        }
    }
    
    /// Adds a reciter to the list of recently viewed items.
    /// This method ensures no duplicates are added and keeps the list trimmed to a max count.
    func addReciter(_ reciter: Reciter) {
        var recents = loadRecentReciters()
        
        // Remove the reciter if it already exists to avoid duplicates and move it to the front.
        recents.removeAll { $0.id == reciter.id }
        
        // Add the new reciter to the beginning of the list.
        recents.insert(reciter, at: 0)
        
        // Ensure the list does not exceed the maximum count.
        if recents.count > maxRecents {
            recents = Array(recents.prefix(maxRecents))
        }
        
        // Save the updated list back to UserDefaults.
        do {
            let data = try JSONEncoder().encode(recents)
            UserDefaults.standard.set(data, forKey: recentsKey)
        } catch {
            print("❌ [RecentRecitersManager] Error encoding recent reciters: \(error)")
        }
    }
    
    /// Clears all recently viewed reciters from UserDefaults.
    func clearAllReciters() {
        UserDefaults.standard.removeObject(forKey: recentsKey)
    }
} 