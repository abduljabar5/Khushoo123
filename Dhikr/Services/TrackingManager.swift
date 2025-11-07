//
//  TrackingManager.swift
//  Dhikr
//
//  Centralized tracking service for audio playback, favorites, and statistics
//

import Foundation
import Combine

/// Centralized manager for all audio tracking data
class TrackingManager: ObservableObject {

    static let shared = TrackingManager()

    // MARK: - Published Properties
    @Published private(set) var listeningStatistics: ListeningStatistics
    @Published private(set) var recentPlays: [RecentPlayItem] = []
    @Published private(set) var likedTracks: Set<LikedTrack> = []
    @Published private(set) var favoriteReciters: [FavoriteReciter] = []
    @Published private(set) var perSurahStats: [Int: SurahStats] = [:] // New: per-surah analytics
    @Published private(set) var perReciterStats: [String: ReciterStats] = [:] // New: per-reciter analytics

    // MARK: - Storage Keys
    private let storageKey = "centralizedTrackingData_v1"
    private let batchWriteInterval: TimeInterval = 5.0 // Write every 5 seconds

    // MARK: - Batch Write Management
    private var pendingWrites = false
    private var batchWriteTimer: Timer?

    // MARK: - Computed Statistics Cache
    private var cachedMostListenedReciter: String?
    private var cachedAverageSessionDuration: TimeInterval?
    private var cacheInvalidated = true

    // MARK: - Initialization
    private init() {
        self.listeningStatistics = ListeningStatistics()
        loadAllData()
        setupBatchWriteTimer()

        print("📊 [TrackingManager] Initialized with centralized tracking")
        logAllData(context: "Initialization")
    }

    // MARK: - Public API - Listening Time

    func addListeningTime(_ seconds: TimeInterval, surahNumber: Int, reciterIdentifier: String) {
        listeningStatistics.totalListeningTime += seconds

        // Update per-surah stats
        var surahStat = perSurahStats[surahNumber] ?? SurahStats(surahNumber: surahNumber)
        surahStat.totalListeningTime += seconds
        surahStat.playCount += 1
        surahStat.lastPlayed = Date()
        perSurahStats[surahNumber] = surahStat

        // Update per-reciter stats
        var reciterStat = perReciterStats[reciterIdentifier] ?? ReciterStats(identifier: reciterIdentifier)
        reciterStat.totalListeningTime += seconds
        reciterStat.playCount += 1
        reciterStat.lastPlayed = Date()
        perReciterStats[reciterIdentifier] = reciterStat

        invalidateCache()
        scheduleBatchWrite()
    }

    func markSurahCompleted(_ surahNumber: Int) {
        let wasNew = !listeningStatistics.completedSurahs.contains(surahNumber)
        listeningStatistics.completedSurahs.insert(surahNumber)

        // Update per-surah stats
        var surahStat = perSurahStats[surahNumber] ?? SurahStats(surahNumber: surahNumber)
        surahStat.completionCount += 1
        surahStat.lastCompleted = Date()
        perSurahStats[surahNumber] = surahStat

        if wasNew {
            print("✅ [TrackingManager] Surah \(surahNumber) completed for the first time")
        }

        invalidateCache()
        scheduleBatchWrite()
    }

    // MARK: - Public API - Recents

    func addRecentPlay(surah: Surah, reciter: Reciter) {
        let newItem = RecentPlayItem(surah: surah, reciter: reciter, playedAt: Date())

        // Remove duplicates
        recentPlays.removeAll { $0.surah.id == newItem.surah.id && $0.reciter.id == newItem.reciter.id }

        // Add to front
        recentPlays.insert(newItem, at: 0)

        // Limit to 20 items
        if recentPlays.count > 20 {
            recentPlays = Array(recentPlays.prefix(20))
        }

        scheduleBatchWrite()
    }

    // MARK: - Public API - Likes

    func toggleLike(surahNumber: Int, reciterIdentifier: String) -> Bool {
        let track = LikedTrack(surahNumber: surahNumber, reciterIdentifier: reciterIdentifier)

        if likedTracks.contains(track) {
            likedTracks.remove(track)
            print("💔 [TrackingManager] Unliked: Surah \(surahNumber) by \(reciterIdentifier)")
            scheduleBatchWrite()
            return false
        } else {
            likedTracks.insert(track)
            print("❤️ [TrackingManager] Liked: Surah \(surahNumber) by \(reciterIdentifier)")
            scheduleBatchWrite()
            return true
        }
    }

    func isLiked(surahNumber: Int, reciterIdentifier: String) -> Bool {
        let track = LikedTrack(surahNumber: surahNumber, reciterIdentifier: reciterIdentifier)
        return likedTracks.contains(track)
    }

    // MARK: - Public API - Favorites

    func toggleFavoriteReciter(_ reciter: Reciter) -> Bool {
        if let index = favoriteReciters.firstIndex(where: { $0.identifier == reciter.identifier }) {
            favoriteReciters.remove(at: index)
            print("💔 [TrackingManager] Removed favorite: \(reciter.englishName)")
            scheduleBatchWrite()
            return false
        } else {
            let favorite = FavoriteReciter(identifier: reciter.identifier)
            favoriteReciters.append(favorite)
            print("⭐️ [TrackingManager] Added favorite: \(reciter.englishName)")
            scheduleBatchWrite()
            return true
        }
    }

    func isFavorite(_ reciter: Reciter) -> Bool {
        return favoriteReciters.contains { $0.identifier == reciter.identifier }
    }

    // MARK: - Public API - Analytics

    func getMostListenedReciter() -> String? {
        if !cacheInvalidated, let cached = cachedMostListenedReciter {
            return cached
        }

        let result = perReciterStats.max(by: { $0.value.totalListeningTime < $1.value.totalListeningTime })?.key
        cachedMostListenedReciter = result
        return result
    }

    func getAverageSessionDuration() -> TimeInterval {
        if !cacheInvalidated, let cached = cachedAverageSessionDuration {
            return cached
        }

        let totalPlays = perSurahStats.values.reduce(0) { $0 + $1.playCount }
        guard totalPlays > 0 else { return 0 }

        let result = listeningStatistics.totalListeningTime / Double(totalPlays)
        cachedAverageSessionDuration = result
        return result
    }

    func getTotalListeningTimeString() -> String {
        let time = listeningStatistics.totalListeningTime
        if time <= 0 {
            return "0s"
        }

        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    func getTopSurahs(limit: Int = 5) -> [(surahNumber: Int, stats: SurahStats)] {
        return perSurahStats.sorted { $0.value.totalListeningTime > $1.value.totalListeningTime }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    func getTopReciters(limit: Int = 5) -> [(identifier: String, stats: ReciterStats)] {
        return perReciterStats.sorted { $0.value.totalListeningTime > $1.value.totalListeningTime }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Batch Write Management

    private func setupBatchWriteTimer() {
        batchWriteTimer = Timer.scheduledTimer(withTimeInterval: batchWriteInterval, repeats: true) { [weak self] _ in
            self?.executeBatchWrite()
        }
    }

    private func scheduleBatchWrite() {
        pendingWrites = true
    }

    private func executeBatchWrite() {
        guard pendingWrites else { return }

        saveAllData()
        pendingWrites = false
    }

    private func invalidateCache() {
        cacheInvalidated = true
        cachedMostListenedReciter = nil
        cachedAverageSessionDuration = nil
    }

    // MARK: - Data Persistence

    private func saveAllData() {
        let trackingData = CentralizedTrackingData(
            listeningStatistics: listeningStatistics,
            recentPlays: recentPlays,
            likedTracks: Array(likedTracks),
            favoriteReciters: favoriteReciters,
            perSurahStats: perSurahStats,
            perReciterStats: perReciterStats
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trackingData)
            UserDefaults.standard.set(data, forKey: storageKey)

            logAllData(context: "Batch Write")
        } catch {
            print("❌ [TrackingManager] Failed to save tracking data: \(error)")
        }
    }

    private func loadAllData() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("ℹ️ [TrackingManager] No existing tracking data found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let trackingData = try decoder.decode(CentralizedTrackingData.self, from: data)

            self.listeningStatistics = trackingData.listeningStatistics
            self.recentPlays = trackingData.recentPlays
            self.likedTracks = Set(trackingData.likedTracks)
            self.favoriteReciters = trackingData.favoriteReciters
            self.perSurahStats = trackingData.perSurahStats
            self.perReciterStats = trackingData.perReciterStats

            print("✅ [TrackingManager] Loaded tracking data successfully")
        } catch {
            print("❌ [TrackingManager] Failed to load tracking data: \(error)")
        }
    }

    // MARK: - Logging

    private func logAllData(context: String) {
        print("📊 ==================== TRACKING DATA (\(context)) ====================")

        let summary: [String: Any] = [
            "listeningStatistics": [
                "totalTime": listeningStatistics.totalListeningTime,
                "totalTimeFormatted": getTotalListeningTimeString(),
                "completedSurahs": Array(listeningStatistics.completedSurahs).sorted(),
                "completedCount": listeningStatistics.completedSurahs.count
            ],
            "recentPlaysCount": recentPlays.count,
            "likedTracksCount": likedTracks.count,
            "favoriteRecitersCount": favoriteReciters.count,
            "perSurahStatsCount": perSurahStats.count,
            "perReciterStatsCount": perReciterStats.count,
            "topSurahs": getTopSurahs(limit: 3).map { ["number": $0.surahNumber, "time": $0.stats.totalListeningTime, "plays": $0.stats.playCount] },
            "topReciters": getTopReciters(limit: 3).map { ["identifier": $0.identifier, "time": $0.stats.totalListeningTime, "plays": $0.stats.playCount] }
        ]

        if let json = try? JSONSerialization.data(withJSONObject: summary, options: .prettyPrinted),
           let jsonString = String(data: json, encoding: .utf8) {
            print(jsonString)
        }

        print("📊 ================================================================")
    }

    deinit {
        batchWriteTimer?.invalidate()
        executeBatchWrite() // Save any pending writes
    }
}

// MARK: - Data Models

struct CentralizedTrackingData: Codable {
    let listeningStatistics: ListeningStatistics
    let recentPlays: [RecentPlayItem]
    let likedTracks: [LikedTrack]
    let favoriteReciters: [FavoriteReciter]
    let perSurahStats: [Int: SurahStats]
    let perReciterStats: [String: ReciterStats]
}

struct ListeningStatistics: Codable {
    var totalListeningTime: TimeInterval = 0
    var completedSurahs: Set<Int> = []
}

struct RecentPlayItem: Codable, Identifiable {
    let id: String
    let surah: Surah
    let reciter: Reciter
    let playedAt: Date

    init(surah: Surah, reciter: Reciter, playedAt: Date) {
        self.surah = surah
        self.reciter = reciter
        self.playedAt = playedAt
        self.id = "\(surah.id)-\(reciter.id)-\(playedAt.timeIntervalSince1970)"
    }
}

struct LikedTrack: Codable, Hashable {
    let surahNumber: Int
    let reciterIdentifier: String
    let dateAdded: Date

    init(surahNumber: Int, reciterIdentifier: String, dateAdded: Date = Date()) {
        self.surahNumber = surahNumber
        self.reciterIdentifier = reciterIdentifier
        self.dateAdded = dateAdded
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(surahNumber)
        hasher.combine(reciterIdentifier)
    }

    static func == (lhs: LikedTrack, rhs: LikedTrack) -> Bool {
        return lhs.surahNumber == rhs.surahNumber && lhs.reciterIdentifier == rhs.reciterIdentifier
    }
}

struct FavoriteReciter: Codable, Identifiable {
    let id = UUID()
    let identifier: String
    let dateAdded: Date

    init(identifier: String, dateAdded: Date = Date()) {
        self.identifier = identifier
        self.dateAdded = dateAdded
    }
}

struct SurahStats: Codable {
    let surahNumber: Int
    var totalListeningTime: TimeInterval = 0
    var playCount: Int = 0
    var completionCount: Int = 0
    var lastPlayed: Date?
    var lastCompleted: Date?
}

struct ReciterStats: Codable {
    let identifier: String
    var totalListeningTime: TimeInterval = 0
    var playCount: Int = 0
    var lastPlayed: Date?
}
