//
//  QuranCentralService.swift
//  Dhikr
//
//  Created by Your Name on 1723145405.0.
//

import Foundation

// MARK: - Codable Models for Quran Central API
struct QuranCentralResponse: Codable {
    let title: String
    let items: [QuranCentralPlaylistItem]
}

struct QuranCentralPlaylistItem: Codable, Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let duration: String
}

struct QuranCentralAPIReciter: Codable {
    let slug: String
    let name: String
    let country: String?
    let dialect: String?
}

// MARK: - Error Enum
enum QuranCentralError: Error {
    case invalidURL
    case networkError
    case decodingError
    case audioTrackNotFound
}

// MARK: - API Service
class QuranCentralService {
    
    static let shared = QuranCentralService()
    private init() {}

    private let apiBaseURL = "https://data.qurancentral.com/categories/"
    private let audioBaseURL = "https://podcasts.qurancentral.com/"

    /// Fetches the playlist for a given reciter and finds the specific audio track for a surah.
    func fetchAudioURL(for surahNumber: Int, surahName: String, reciterSlug: String) async throws -> URL {
        print("▶️ [QuranCentralService] Fetching playlist for slug: \(reciterSlug)")
        
        let apiUrl = "\(apiBaseURL)\(reciterSlug).json"
        guard let url = URL(string: apiUrl) else {
            throw QuranCentralError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(QuranCentralResponse.self, from: data)
        
        print("🔍 [QuranCentralService] Searching for Surah #\(surahNumber) ('\(surahName)')...")

        // Search for the track using the most likely patterns.
        let cleanedSurahName = surahName.replacingOccurrences(of: "-", with: " ")
        let formattedSurahNumber = String(format: "%03d", surahNumber)

        guard let track = response.items.first(where: {
            $0.title.localizedCaseInsensitiveContains(cleanedSurahName) || $0.title.contains(formattedSurahNumber)
        }) else {
            print("❌ [QuranCentralService] Could not find track for Surah #\(surahNumber) in the playlist.")
            // For debugging, print all available titles if the search fails.
            print("--- [QuranCentralService] Available Tracks for \(reciterSlug): ---")
            response.items.forEach { print("  - \($0.title)") }
            print("--- End of Track List ---")
            throw QuranCentralError.audioTrackNotFound
        }
        
        print("✅ [QuranCentralService] Found track: \(track.title)")
        
        guard let finalURL = URL(string: "\(audioBaseURL)\(track.url)") else {
            throw QuranCentralError.invalidURL
        }
        
        return finalURL
    }

    /// Fetches the set of available surah numbers for a given reciter.
    func fetchAvailableSurahNumbers(for reciterSlug: String) async throws -> Set<Int> {
        print("▶️ [QuranCentralService] Fetching available surah numbers for slug: \(reciterSlug)")
        
        let apiUrl = "\(apiBaseURL)\(reciterSlug).json"
        guard let url = URL(string: apiUrl) else {
            throw QuranCentralError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(QuranCentralResponse.self, from: data)
        
        let surahNumbers = response.items.compactMap { item -> Int? in
            // Use regex to find a 3-digit number in the title, which reliably represents the surah number.
            if let range = item.title.range(of: "\\d{3}", options: .regularExpression) {
                let numberString = String(item.title[range])
                return Int(numberString)
            }
            return nil
        }
        
        print("✅ [QuranCentralService] Found \(surahNumbers.count) available surahs for \(reciterSlug).")
        return Set(surahNumbers)
    }

    /// Fetches a list of all available reciters from Quran Central.
    func fetchAllReciters() async throws -> [Reciter] {
        print("▶️ [QuranCentralService] Fetching all reciters from Quran Central...")
        let endpoint = "https://data.qurancentral.com/reciters.json"
        
        guard let url = URL(string: endpoint) else {
            print("❌ [QuranCentralService] Error: Invalid URL for all reciters endpoint.")
            throw QuranCentralError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let qcReciters = try JSONDecoder().decode([QuranCentralAPIReciter].self, from: data)
        
        print("✅ [QuranCentralService] Successfully decoded \(qcReciters.count) reciters from Quran Central API.")

        // Map the API response to the app's Reciter model
        let reciters = qcReciters.map { qcReciter in
            let artworkURL = URL(string: "https://artwork.qurancentral.com/\(qcReciter.slug).jpg")
            
            return Reciter(
                identifier: "qurancentral_\(qcReciter.slug)",
                language: "ar", // Defaulting to 'ar' as it's not provided by the API
                name: qcReciter.name,
                englishName: qcReciter.name,
                server: nil, // Not applicable for Quran Central, URL is built dynamically
                reciterId: nil, // Not applicable for Quran Central
                country: qcReciter.country,
                dialect: qcReciter.dialect,
                artworkURL: artworkURL
            )
        }
        
        return reciters
    }
} 