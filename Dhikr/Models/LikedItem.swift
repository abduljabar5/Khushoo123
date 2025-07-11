//
//  LikedItem.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import Foundation

struct LikedItem: Codable, Hashable {
    let surahNumber: Int
    let reciterIdentifier: String
    let dateAdded: Date

    // Custom Hashable conformance to uniquely identify a liked item by surah and reciter,
    // ignoring the dateAdded property for equality checks.
    func hash(into hasher: inout Hasher) {
        hasher.combine(surahNumber)
        hasher.combine(reciterIdentifier)
    }

    // Custom Equatable to match the Hashable conformance.
    static func == (lhs: LikedItem, rhs: LikedItem) -> Bool {
        return lhs.surahNumber == rhs.surahNumber &&
               lhs.reciterIdentifier == rhs.reciterIdentifier
    }
    
    // Convenience initializer for creating new items. Defaults to the current date.
    init(surahNumber: Int, reciterIdentifier: String, dateAdded: Date = Date()) {
        self.surahNumber = surahNumber
        self.reciterIdentifier = reciterIdentifier
        self.dateAdded = dateAdded
    }

    // Custom decoder to handle old data that doesn't have `dateAdded`.
    // This provides backward compatibility with items you've already liked.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surahNumber = try container.decode(Int.self, forKey: .surahNumber)
        reciterIdentifier = try container.decode(String.self, forKey: .reciterIdentifier)
        // Provide a default date for old items, so they appear at the bottom.
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date.distantPast
    }

    // Explicitly declare coding keys to make the custom decoder work.
    private enum CodingKeys: String, CodingKey {
        case surahNumber, reciterIdentifier, dateAdded
    }
} 