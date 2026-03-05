//
//  QuranCentralService.swift
//  Dhikr
//
//  Provides Quran Central reciters from hardcoded data and fetches
//  episodes via Apple's iTunes Lookup API. Audio streams from the
//  QC CDN via AVPlayer which uses Apple's media user agent.
//

import Foundation

class QuranCentralService {
    static let shared = QuranCentralService()

    private var cachedReciters: [Reciter] = []
    private var hasLoaded = false

    // Cache episodes per collectionId
    private var episodeCache: [Int: [QCEpisode]] = [:]

    private init() {}

    // MARK: - Fetch Reciters (from hardcoded data)

    func fetchReciters() async -> [Reciter] {
        if hasLoaded { return cachedReciters }

        var reciters: [Reciter] = []
        for entry in QuranCentralData.allReciters {
            let artworkURL = URL(string: "https://artwork.qurancentral.com/\(entry.slug).jpg")

            reciters.append(Reciter(
                identifier: "qurancentral_\(entry.slug)",
                language: "ar",
                name: entry.name,
                englishName: entry.name,
                server: nil,
                reciterId: entry.collectionId,
                country: nil,
                dialect: nil,
                artworkURL: artworkURL,
                availableSurahs: Set(1...114)
            ))
        }

        cachedReciters = reciters
        hasLoaded = true
        return reciters
    }

    // MARK: - Construct Audio URL (via iTunes Lookup API)

    func constructAudioURL(surahNumber: Int, reciterIdentifier: String) async throws -> String {
        let episodes = try await fetchEpisodes(for: reciterIdentifier)

        let formatted = String(format: "%03d", surahNumber)
        if let episode = episodes.first(where: { $0.title.hasPrefix(formatted) }) {
            return episode.audioURL
        }

        throw QuranAPIError.audioNotFound
    }

    // MARK: - Resolve Available Surahs

    func resolveAvailableSurahs(for reciterIdentifier: String) async -> Set<Int> {
        do {
            let episodes = try await fetchEpisodes(for: reciterIdentifier)
            var surahs = Set<Int>()

            for episode in episodes {
                if episode.title.count >= 3,
                   let surahNumber = Int(episode.title.prefix(3)),
                   surahNumber >= 1 && surahNumber <= 114 {
                    surahs.insert(surahNumber)
                }
            }

            return surahs.isEmpty ? Set(1...114) : surahs
        } catch {
            return Set(1...114)
        }
    }

    func updateCachedReciter(identifier: String, availableSurahs: Set<Int>) {
        if let index = cachedReciters.firstIndex(where: { $0.identifier == identifier }) {
            cachedReciters[index].availableSurahs = availableSurahs
        }
    }

    // MARK: - Fetch Episodes (via iTunes Lookup API)

    private func fetchEpisodes(for reciterIdentifier: String) async throws -> [QCEpisode] {
        // Find the reciter's collectionId
        guard let reciter = cachedReciters.first(where: { $0.identifier == reciterIdentifier }),
              let collectionId = reciter.reciterId else {
            throw QuranAPIError.invalidURL
        }

        // Return cached episodes if available
        if let cached = episodeCache[collectionId] { return cached }

        // Fetch episodes from iTunes Lookup API — entirely Apple's servers
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(collectionId)&media=podcast&entity=podcastEpisode&limit=300") else {
            throw QuranAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw QuranAPIError.networkError
        }

        let result = try JSONDecoder().decode(ITunesLookupResult.self, from: data)

        // Filter to episode results only (first result is the podcast itself)
        let episodes = result.results.compactMap { item -> QCEpisode? in
            guard item.wrapperType == "podcastEpisode",
                  let title = item.trackName,
                  let audioURL = item.episodeUrl,
                  !title.isEmpty && !audioURL.isEmpty else { return nil }

            // Only include episodes that look like surahs (3-digit number prefix)
            guard title.count >= 3,
                  let num = Int(title.prefix(3)),
                  num >= 1 && num <= 114 else { return nil }

            return QCEpisode(title: title, audioURL: audioURL)
        }

        guard !episodes.isEmpty else {
            throw QuranAPIError.audioNotFound
        }

        episodeCache[collectionId] = episodes
        return episodes
    }
}

// MARK: - iTunes Lookup API Models

private struct ITunesLookupResult: Codable {
    let resultCount: Int
    let results: [ITunesLookupItem]
}

private struct ITunesLookupItem: Codable {
    let wrapperType: String?
    let trackName: String?
    let episodeUrl: String?
    let collectionId: Int?
    let trackTimeMillis: Int?
}

// MARK: - Episode Model

struct QCEpisode {
    let title: String
    let audioURL: String
}
