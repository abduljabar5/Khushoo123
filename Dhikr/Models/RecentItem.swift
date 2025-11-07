import Foundation

struct RecentItem: Codable, Identifiable, Equatable {
    // Stable ID based on surah, reciter, and timestamp to prevent unnecessary SwiftUI redraws
    let id: String
    let surah: Surah
    let reciter: Reciter
    let playedAt: Date

    init(surah: Surah, reciter: Reciter, playedAt: Date) {
        self.surah = surah
        self.reciter = reciter
        self.playedAt = playedAt
        // Create stable identifier combining surah, reciter, and timestamp
        self.id = "\(surah.id)-\(reciter.id)-\(playedAt.timeIntervalSince1970)"
    }

    static func == (lhs: RecentItem, rhs: RecentItem) -> Bool {
        return lhs.surah.id == rhs.surah.id && lhs.reciter.id == rhs.reciter.id && lhs.playedAt == rhs.playedAt
    }
} 