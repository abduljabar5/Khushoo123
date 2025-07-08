import Foundation

struct RecentItem: Codable, Identifiable, Equatable {
    var id: UUID {
        return UUID() // Conform to Identifiable
    }
    let surah: Surah
    let reciter: Reciter
    let playedAt: Date
    
    static func == (lhs: RecentItem, rhs: RecentItem) -> Bool {
        return lhs.surah.id == rhs.surah.id && lhs.reciter.id == rhs.reciter.id
    }
} 