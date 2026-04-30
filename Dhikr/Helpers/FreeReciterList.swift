//
//  FreeReciterList.swift
//  Dhikr
//
//  Single source of truth for which reciters get full free playback.
//  Everything outside this list is premium with a 60-second preview.
//
//  Match is on englishName because that's what MP3Quran's reciter records use
//  and it's what the home page popular/soothing lists already key on.
//

import Foundation

enum FreeReciterList {
    /// Curated free reciters — the popular and soothing lists that show on home page.
    /// Keep this small and high-quality; every name added here loses paywall pressure
    /// for that reciter forever.
    static let names: Set<String> = [
        // Popular
        "Maher Al Meaqli",
        "Abdulbasit Abdulsamad",
        "Mishary Alafasi",
        "Saud Al-Shuraim",
        "Abdulrahman Alsudaes",
        "Ahmad Al-Ajmy",
        "Fares Abbad",
        "Yasser Al-Dosari",
        "Mohammed Ayyub",
        "Idrees Abkr",
        // Soothing (overlap with popular is intentional — Set deduplicates)
        "Saad Al-Ghamdi",
        "Nasser Alqatami",
        "Abdullah Al-Johany",
        "Mohammed Siddiq Al-Minshawi",
    ]

    static func contains(englishName: String) -> Bool {
        return names.contains(englishName)
    }
}
