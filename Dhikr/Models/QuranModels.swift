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

// MARK: - Moshaf Version (Quran edition/style for a reciter)
struct MoshafVersion: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let server: String
    let availableSurahs: Set<Int>

    /// Display-friendly name: strips common prefixes like "Rewayat Hafs A'n Assem - "
    var displayName: String {
        let prefixes = ["Rewayat Hafs A'n Assem - ", "Rewayat Hafs A'n Assem -"]
        var cleaned = name
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Reciter (Audio Edition)
struct Reciter: Codable, Identifiable, Equatable, Hashable {
    var id: String { identifier }
    let identifier: String
    let language: String
    let name: String
    let englishName: String
    var server: String?
    let reciterId: Int?
    let country: String?
    let dialect: String?
    let artworkURL: URL?
    var availableSurahs: Set<Int>  // Surah numbers this reciter has audio for
    var moshafVersions: [MoshafVersion]  // All available moshaf editions

    // For mock data and easier use
    static var mock: Reciter {
        Reciter(identifier: "ar.alafasy", language: "ar", name: "مشاري راشد العفاسي", englishName: "Mishary Rashid Alafasy", server: nil, reciterId: nil, country: "Kuwait", dialect: "Hafs", artworkURL: nil, availableSurahs: Set(1...114))
    }

    /// Check if reciter has audio for a specific surah
    func hasSurah(_ surahNumber: Int) -> Bool {
        return availableSurahs.contains(surahNumber)
    }

    /// Returns true if reciter has the complete Quran (all 114 surahs)
    var hasCompleteQuran: Bool {
        return availableSurahs.count >= 114
    }

    // Custom decoder for backwards compatibility with stored data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        language = try container.decode(String.self, forKey: .language)
        name = try container.decode(String.self, forKey: .name)
        englishName = try container.decode(String.self, forKey: .englishName)
        server = try container.decodeIfPresent(String.self, forKey: .server)
        reciterId = try container.decodeIfPresent(Int.self, forKey: .reciterId)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        dialect = try container.decodeIfPresent(String.self, forKey: .dialect)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        // Default to all 114 surahs for backwards compatibility with stored data
        availableSurahs = try container.decodeIfPresent(Set<Int>.self, forKey: .availableSurahs) ?? Set(1...114)
        moshafVersions = try container.decodeIfPresent([MoshafVersion].self, forKey: .moshafVersions) ?? []
    }

    // Memberwise initializer
    init(identifier: String, language: String, name: String, englishName: String, server: String?, reciterId: Int?, country: String?, dialect: String?, artworkURL: URL?, availableSurahs: Set<Int> = Set(1...114), moshafVersions: [MoshafVersion] = []) {
        self.identifier = identifier
        self.language = language
        self.name = name
        self.englishName = englishName
        self.server = server
        self.reciterId = reciterId
        self.country = country
        self.dialect = dialect
        self.artworkURL = artworkURL
        self.availableSurahs = availableSurahs
        self.moshafVersions = moshafVersions
    }

    private enum CodingKeys: String, CodingKey {
        case identifier, language, name, englishName, server, reciterId, country, dialect, artworkURL, availableSurahs, moshafVersions
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
 