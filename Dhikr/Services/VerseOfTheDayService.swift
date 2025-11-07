//
//  VerseOfTheDayService.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 10/28/25.
//

import Foundation

// MARK: - Models
struct VerseOfTheDay: Codable {
    let text: String
    let translation: String
    let surahName: String
    let surahNameArabic: String
    let verseNumber: Int
    let surahNumber: Int

    var reference: String {
        "\(surahName) \(surahNumber):\(verseNumber)"
    }
}

struct AlQuranVerseResponse: Codable {
    let data: AlQuranVerseData
}

struct AlQuranVerseData: Codable {
    let number: Int
    let text: String
    let surah: AlQuranSurah
    let numberInSurah: Int
}

struct AlQuranSurah: Codable {
    let number: Int
    let name: String
    let englishName: String
}

struct AlQuranTranslationResponse: Codable {
    let data: AlQuranTranslationData
}

struct AlQuranTranslationData: Codable {
    let text: String
}

// MARK: - Service
class VerseOfTheDayService {
    static let shared = VerseOfTheDayService()

    private let baseURL = "https://api.alquran.cloud/v1"
    private let totalVerses = 6236

    private init() {}

    /// Get verse of the day (consistent per day, rotates daily)
    func fetchVerseOfTheDay() async throws -> VerseOfTheDay {
        let verseNumber = getDailyVerseNumber()
        return try await fetchVerse(number: verseNumber)
    }

    /// Get a random verse
    func fetchRandomVerse() async throws -> VerseOfTheDay {
        let randomNumber = Int.random(in: 1...totalVerses)
        return try await fetchVerse(number: randomNumber)
    }

    /// Get a specific verse by absolute number (1-6236)
    func fetchVerse(number: Int) async throws -> VerseOfTheDay {
        // Fetch Arabic text
        let arabicURL = URL(string: "\(baseURL)/ayah/\(number)")!
        let (arabicData, _) = try await URLSession.shared.data(from: arabicURL)
        let arabicResponse = try JSONDecoder().decode(AlQuranVerseResponse.self, from: arabicData)

        // Fetch English translation
        let translationURL = URL(string: "\(baseURL)/ayah/\(number)/en.asad")!
        let (translationData, _) = try await URLSession.shared.data(from: translationURL)
        let translationResponse = try JSONDecoder().decode(AlQuranTranslationResponse.self, from: translationData)

        return VerseOfTheDay(
            text: arabicResponse.data.text,
            translation: translationResponse.data.text,
            surahName: arabicResponse.data.surah.englishName,
            surahNameArabic: arabicResponse.data.surah.name,
            verseNumber: arabicResponse.data.numberInSurah,
            surahNumber: arabicResponse.data.surah.number
        )
    }

    // MARK: - Private Helpers

    /// Calculate verse number based on today's date (consistent per day)
    private func getDailyVerseNumber() -> Int {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        // Rotate through all verses over the year
        return (dayOfYear % totalVerses) + 1
    }
}
