//
//  CloudflareReciterService.swift
//  Dhikr
//
//  Provides custom reciters hosted on Cloudflare R2. The bucket is fronted by
//  a public r2.dev URL with no egress fees, so AVPlayer streams MP3s directly.
//
//  Layout on R2:
//    /index.json                              ← list of reciters + per-surah filenames
//    /reciters/<slug>/<filename>.mp3          ← surah audio
//    /reciters/<slug>/<artwork>.jpg           ← cover artwork
//

import Foundation

class CloudflareReciterService {
    static let shared = CloudflareReciterService()

    /// Public r2.dev base URL for the khushoo-reciters bucket.
    /// Update when migrating to a custom domain (e.g. audio.khushoo.app).
    private let baseURL = "https://pub-1fb1a9b819da436fb17bbf38db838f82.r2.dev"

    private var cachedReciters: [Reciter] = []
    private var fileMaps: [String: [Int: String]] = [:]   // slug → {surahNumber: filename}
    private var hasLoaded = false
    private var loadTask: Task<[Reciter], Never>?

    private init() {}

    // MARK: - Fetch Reciters

    func fetchReciters() async -> [Reciter] {
        if hasLoaded { return cachedReciters }

        // De-dupe concurrent callers — only one network fetch per cold start
        if let inflight = loadTask {
            return await inflight.value
        }

        let task = Task<[Reciter], Never> {
            await loadFromIndex()
        }
        loadTask = task
        let result = await task.value
        loadTask = nil
        return result
    }

    private func loadFromIndex() async -> [Reciter] {
        guard let url = URL(string: "\(baseURL)/index.json") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            let index = try JSONDecoder().decode(CloudflareIndex.self, from: data)

            var reciters: [Reciter] = []
            for entry in index.reciters {
                // Convert string-keyed file map to Int-keyed
                var intKeyedFiles: [Int: String] = [:]
                for (key, value) in entry.files {
                    if let surahNumber = Int(key), surahNumber >= 1 && surahNumber <= 114 {
                        intKeyedFiles[surahNumber] = value
                    }
                }
                fileMaps[entry.slug] = intKeyedFiles

                let identifier = "cloudflare_\(entry.slug)"
                let artworkURL: URL? = {
                    guard let artwork = entry.artwork else { return nil }
                    return URL(string: "\(baseURL)/reciters/\(entry.slug)/\(artwork)")
                }()

                reciters.append(Reciter(
                    identifier: identifier,
                    language: "ar",
                    name: entry.arabicName ?? entry.englishName,
                    englishName: entry.englishName,
                    server: nil,
                    reciterId: nil,
                    country: entry.country,
                    dialect: nil,
                    artworkURL: artworkURL,
                    availableSurahs: Set(intKeyedFiles.keys)
                ))
            }

            cachedReciters = reciters
            hasLoaded = true
            return reciters
        } catch {
            // Index unreachable or malformed — fail open with no Cloudflare reciters
            return []
        }
    }

    // MARK: - Construct Audio URL

    func constructAudioURL(surahNumber: Int, reciterIdentifier: String) async throws -> String {
        // Lazy-load index if a caller invokes this before fetchReciters has populated cache
        if !hasLoaded {
            _ = await fetchReciters()
        }

        let slug = reciterIdentifier.replacingOccurrences(of: "cloudflare_", with: "")

        guard let fileMap = fileMaps[slug],
              let filename = fileMap[surahNumber] else {
            throw QuranAPIError.audioNotFound
        }

        // Percent-encode filename (covers Arabic chars + spaces if present in future entries)
        let encoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
        return "\(baseURL)/reciters/\(slug)/\(encoded)"
    }
}

// MARK: - Index Models

private struct CloudflareIndex: Codable {
    let version: Int
    let reciters: [CloudflareReciterEntry]
}

private struct CloudflareReciterEntry: Codable {
    let slug: String
    let englishName: String
    let arabicName: String?
    let country: String?
    let artwork: String?
    let files: [String: String]
}
