//
//  QuranModels.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import Foundation

// MARK: - MP3Quran API Models
struct MP3QuranRecitersResponse: Codable {
    let reciters: [MP3QuranReciter]
}

struct MP3QuranReciter: Codable {
    let id: Int
    let name: String
    let letter: String
    let date: String
    let moshaf: [MP3QuranMoshaf]
}

struct MP3QuranMoshaf: Codable {
    let id: Int
    let name: String
    let server: String
    let surahTotal: Int
    let moshafType: Int
    let surahList: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, server
        case surahTotal = "surah_total"
        case moshafType = "moshaf_type"
        case surahList = "surah_list"
    }
}

// MARK: - Generic API Response
struct AlQuranCloudResponse<T: Codable>: Codable {
    let code: Int
    let status: String
    let data: T
}

// MARK: - Reciter (Audio Edition)
struct Reciter: Codable, Identifiable, Equatable {
    var id: String { identifier }
    let identifier: String
    let language: String
    let name: String
    let englishName: String
    let server: String?
    let reciterId: Int?
    let country: String?
    let dialect: String?
    let artworkURL: URL?
    
    // For mock data and easier use
    static var mock: Reciter {
        Reciter(identifier: "ar.alafasy", language: "ar", name: "مشاري راشد العفاسي", englishName: "Mishary Rashid Alafasy", server: nil, reciterId: nil, country: "Kuwait", dialect: "Hafs", artworkURL: URL(string: "https://artwork.qurancentral.com/mishary-rashid-alafasy.jpg"))
    }
}

// MARK: - Surah
struct Surah: Codable, Identifiable, Hashable {
    var id: Int { number }
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
    let numberOfAyahs: Int
    let revelationType: String
    
    var displayName: String {
        return "\(number). \(englishName)"
    }
    
    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }

    // Conformance to Equatable
    static func == (lhs: Surah, rhs: Surah) -> Bool {
        lhs.number == rhs.number
    }
}

// MARK: - Ayah
struct Ayah: Codable, Identifiable {
    var id: Int { number }
    let number: Int
    let audio: String
    let text: String
    let numberInSurah: Int
    let juz: Int
    let manzil: Int
    let page: Int
    let ruku: Int
    let hizbQuarter: Int
}

// MARK: - Full Surah Detail
// This model represents the response from /surah/{number}/{edition}
struct SurahDetail: Codable {
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
    let revelationType: String
    let numberOfAyahs: Int
    let ayahs: [Ayah]
    let edition: EditionDetail
}

// The edition object nested inside the surah detail response
struct EditionDetail: Codable {
    let identifier: String
    let language: String
    let name: String
    let englishName: String
    let format: String
    let type: String
}
 