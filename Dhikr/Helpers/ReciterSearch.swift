//
//  ReciterSearch.swift
//  Dhikr
//
//  Fuzzy search for Arabic transliterated names.
//  Handles common spelling variants (ai/ay, ee/i, kh/k, etc.)
//  without requiring AI — phonetic normalization + edit distance.
//

import Foundation

enum ReciterSearch {

    // MARK: - Phonetic normalization for Arabic transliterations

    /// Lightly normalizes common Arabic transliteration variants to a canonical form.
    /// Unifies equivalent spellings without destroying letters.
    /// e.g. "faisal" and "faysal" both → "faysal", "hussein" and "husain" both → "husayn"
    static func normalize(_ input: String) -> String {
        var s = input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove diacritics/accents
        s = s.folding(options: .diacriticInsensitive, locale: .current)

        // Unify equivalent transliterations (order matters — longer patterns first)
        let replacements: [(String, String)] = [
            // Diphthongs → canonical form
            ("ai", "ay"),
            ("ei", "ay"),
            // Long vowels → canonical
            ("ee", "i"),
            ("oo", "u"),
            ("ou", "u"),
            ("aa", "a"),
            // Double consonants → single
            ("ll", "l"),
            ("mm", "m"),
            ("nn", "n"),
            ("ss", "s"),
            ("tt", "t"),
            ("dd", "d"),
            ("rr", "r"),
            // Remove hyphens/apostrophes in articles
            ("al-", "al "),
            ("el-", "al "),
            ("ul-", "ul "),
            ("ud-", "ud "),
            ("ur-", "ur "),
        ]

        for (from, to) in replacements {
            s = s.replacingOccurrences(of: from, with: to)
        }

        // Remove remaining apostrophes and hyphens
        s = s.replacingOccurrences(of: "'", with: "")
        s = s.replacingOccurrences(of: "\u{2019}", with: "")
        s = s.replacingOccurrences(of: "-", with: " ")

        // Collapse multiple spaces
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }

        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Scoring

    /// Returns a match score (0 = no match, higher = better match).
    static func score(
        reciterName: String,
        query: String,
        normalizedQuery: String,
        queryTokens: [String]
    ) -> Int {
        let lowerName = reciterName.lowercased()
        let lowerQuery = query.lowercased()

        // Exact substring match — best score
        if lowerName.contains(lowerQuery) {
            if lowerName.hasPrefix(lowerQuery) { return 1000 }
            // Check if any word starts with query
            let words = lowerName.split(separator: " ")
            if words.contains(where: { $0.hasPrefix(lowerQuery) }) { return 950 }
            return 900
        }

        let normalizedName = normalize(reciterName)
        let nameTokens = normalizedName.split(separator: " ").map(String.init)

        // Normalized substring match
        if normalizedName.contains(normalizedQuery) {
            return 800
        }

        // Token-based matching: each query token should match some name token
        var matchedTokens = 0
        var totalScore = 0

        for qt in queryTokens {
            var bestScore = 0
            for nt in nameTokens {
                // Exact token match
                if nt == qt {
                    bestScore = max(bestScore, 100)
                }
                // Prefix match (user typing partial name)
                else if nt.hasPrefix(qt) {
                    bestScore = max(bestScore, 85)
                }
                else if qt.hasPrefix(nt) {
                    bestScore = max(bestScore, 75)
                }
                // Contains
                else if nt.contains(qt) {
                    bestScore = max(bestScore, 60)
                }
                // Edit distance — allows typos and minor misspellings
                else {
                    let maxLen = max(nt.count, qt.count)
                    let minLen = min(nt.count, qt.count)
                    // Skip if lengths are too different
                    guard minLen * 2 >= maxLen else { continue }
                    let threshold = max(1, (maxLen + 2) / 3)  // ~33% tolerance
                    let dist = editDistance(Array(nt), Array(qt))
                    if dist <= threshold {
                        // Scale score based on distance
                        let s = max(10, 50 - (dist * 15))
                        bestScore = max(bestScore, s)
                    }
                }
            }
            if bestScore > 0 {
                matchedTokens += 1
                totalScore += bestScore
            }
        }

        // All query tokens must match something
        guard matchedTokens == queryTokens.count else { return 0 }

        return totalScore
    }

    // MARK: - Edit Distance (Levenshtein)

    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count
        let n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j - 1], prev[j], curr[j - 1])
                }
            }
            prev = curr
        }

        return prev[n]
    }
}
