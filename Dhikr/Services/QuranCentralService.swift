//
//  QuranCentralService.swift
//  Dhikr
//
//  Fetches reciters from Quran Central for search integration.
//  QC reciters appear in search results only, not the main reciter list.
//

import Foundation

class QuranCentralService {
    static let shared = QuranCentralService()

    private let recitersURL = "https://data.qurancentral.com/reciters.json"
    private let categoriesBaseURL = "https://data.qurancentral.com/categories"
    private let podcastsBaseURL = "https://podcasts.qurancentral.com"
    private let artworkBaseURL = "https://artwork.qurancentral.com"

    private var cachedReciters: [Reciter] = []
    private var hasLoaded = false
    private var isLoading = false

    // Cache playlists per slug so we don't re-fetch
    private var playlistCache: [String: [QCPlaylistItem]] = [:]

    private init() {}

    // MARK: - Fetch Reciters

    func fetchReciters() async -> [Reciter] {
        if hasLoaded { return cachedReciters }
        guard !isLoading else {
            // Wait for the in-progress load
            while isLoading { try? await Task.sleep(nanoseconds: 100_000_000) }
            return cachedReciters
        }

        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: recitersURL) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            let qcReciters = try JSONDecoder().decode([QCReciter].self, from: data)

            cachedReciters = qcReciters.map { qc in
                Reciter(
                    identifier: "qurancentral_\(qc.slug)",
                    language: "ar",
                    name: qc.name,
                    englishName: qc.name,
                    server: nil,
                    reciterId: nil,
                    country: qc.country,
                    dialect: qc.dialect,
                    artworkURL: URL(string: "\(artworkBaseURL)/\(qc.slug).jpg"),
                    availableSurahs: Set(1...114) // Assume full until playlist is fetched
                )
            }

            hasLoaded = true
        } catch {
            // Silently fail — search will just not show QC results
        }

        return cachedReciters
    }

    // MARK: - Construct Audio URL

    func constructAudioURL(surahNumber: Int, reciterIdentifier: String) async throws -> String {
        let slug = reciterIdentifier.replacingOccurrences(of: "qurancentral_", with: "")

        let items = try await fetchPlaylist(slug: slug)

        // Match by surah number prefix in the title (e.g., "001 Al-Fatiha")
        let formatted = String(format: "%03d", surahNumber)
        if let item = items.first(where: { $0.title.hasPrefix(formatted) }) {
            return "\(podcastsBaseURL)/\(item.url)"
        }

        throw QuranAPIError.audioNotFound
    }

    // MARK: - Fetch Playlist

    private func fetchPlaylist(slug: String) async throws -> [QCPlaylistItem] {
        if let cached = playlistCache[slug] { return cached }

        guard let url = URL(string: "\(categoriesBaseURL)/\(slug).json") else {
            throw QuranAPIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw QuranAPIError.networkError
        }

        let detail = try JSONDecoder().decode(QCReciterDetail.self, from: data)
        let items = detail.items ?? []
        playlistCache[slug] = items
        return items
    }
}

// MARK: - Quran Central JSON Models

private struct QCReciter: Codable {
    let id: Int
    let slug: String
    let name: String
    let postCount: Int?
    let country: String?
    let dialect: String?
    let popular: Bool?
    let female: Bool?

    enum CodingKeys: String, CodingKey {
        case id, slug, name
        case postCount = "post_count"
        case country, dialect, popular, female
    }
}

private struct QCReciterDetail: Codable {
    let title: String?
    let description: String?
    let image: String?
    let items: [QCPlaylistItem]?
}

struct QCPlaylistItem: Codable {
    let title: String
    let url: String
    let duration: String?
}
