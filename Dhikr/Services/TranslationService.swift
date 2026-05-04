//
//  TranslationService.swift
//  Dhikr
//
//  Fetches surah text + translation from AlQuran.cloud (free, no auth).
//  Translation is reciter-agnostic — the Arabic Quran is canonical and
//  translations are indexed by surah/verse number only. Same text overlay
//  works across MP3Quran, QuranCentral, and Cloudflare reciters.
//
//  Caches per surah to disk so we hit the network at most once per surah
//  per app install. Translations are static so cache is forever.
//

import Foundation

class TranslationService {
    static let shared = TranslationService()

    /// Single combined request that returns Arabic + chosen translation
    private let baseURL = "https://api.alquran.cloud/v1"

    /// Default translation. Sahih International is widely-accepted across
    /// most Sunni mainstream usage and is the most common default in major
    /// Quran apps. User-selectable in the future if we want to expose it.
    static let defaultTranslationEdition = "en.sahih"

    private let fileManager = FileManager.default
    private var cacheDirectory: URL? {
        guard let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let subdir = dir.appendingPathComponent("Translations", isDirectory: true)
        if !fileManager.fileExists(atPath: subdir.path) {
            try? fileManager.createDirectory(at: subdir, withIntermediateDirectories: true)
        }
        return subdir
    }

    private init() {}

    // MARK: - Public API

    /// Fetch a surah's parallel Arabic + translation. Returns from cache when
    /// available, otherwise hits the network. Returns nil only on hard failures
    /// (no network and no cache).
    func fetchSurah(number: Int, edition: String = TranslationService.defaultTranslationEdition) async -> SurahTranslation? {
        if let cached = loadFromCache(surahNumber: number, edition: edition) {
            return cached
        }

        guard let url = URL(string: "\(baseURL)/surah/\(number)/editions/quran-uthmani,\(edition)") else {
            return nil
        }

        do {
            let (data, urlResponse) = try await URLSession.shared.data(from: url)
            guard let http = urlResponse as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let decoded = try JSONDecoder().decode(TranslationAPIResponse.self, from: data)
            guard decoded.code == 200,
                  let editions = decoded.data,
                  editions.count == 2,
                  editions[0].ayahs.count == editions[1].ayahs.count else {
                return nil
            }

            let arabic = editions[0]
            let translated = editions[1]

            var verses: [TranslatedVerse] = []
            for i in 0..<arabic.ayahs.count {
                verses.append(TranslatedVerse(
                    number: arabic.ayahs[i].numberInSurah,
                    arabic: arabic.ayahs[i].text,
                    translation: translated.ayahs[i].text
                ))
            }

            let result = SurahTranslation(
                surahNumber: number,
                englishName: arabic.englishName,
                arabicName: arabic.name,
                verses: verses
            )

            saveToCache(translation: result, edition: edition)
            return result
        } catch {
            return nil
        }
    }

    // MARK: - Cache

    private func cacheURL(surahNumber: Int, edition: String) -> URL? {
        return cacheDirectory?.appendingPathComponent("\(surahNumber)_\(edition).json")
    }

    private func loadFromCache(surahNumber: Int, edition: String) -> SurahTranslation? {
        guard let url = cacheURL(surahNumber: surahNumber, edition: edition),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(SurahTranslation.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func saveToCache(translation: SurahTranslation, edition: String) {
        guard let url = cacheURL(surahNumber: translation.surahNumber, edition: edition),
              let data = try? JSONEncoder().encode(translation) else {
            return
        }
        try? data.write(to: url)
    }
}

// MARK: - Public Models

struct SurahTranslation: Codable {
    let surahNumber: Int
    let englishName: String
    let arabicName: String
    let verses: [TranslatedVerse]
}

struct TranslatedVerse: Codable, Identifiable {
    var id: Int { number }
    let number: Int
    let arabic: String
    let translation: String
}

// MARK: - AlQuran.cloud Response Shapes

private struct TranslationAPIResponse: Codable {
    let code: Int
    let data: [TranslationAPIEdition]?
}

private struct TranslationAPIEdition: Codable {
    let number: Int
    let name: String
    let englishName: String
    let ayahs: [TranslationAPIAyah]
}

private struct TranslationAPIAyah: Codable {
    let numberInSurah: Int
    let text: String
}
