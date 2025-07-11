//
//  QuranAPIService.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 6/21/25.
//

import Foundation

// MARK: - Quran API Error
enum QuranAPIError: Error {
    case invalidURL
    case networkError
    case decodingError
    case audioNotFound
    case invalidResponse
}

// MARK: - Quran API Service
class QuranAPIService: ObservableObject {
    // MARK: - Singleton
    static let shared = QuranAPIService()
    
    @Published var reciters: [Reciter] = []
    private var allReciters: [Reciter] = []
    
    private init() {}
    
    // MARK: - API Base URLs
    private let mp3QuranBaseURL = "https://www.mp3quran.net/api/v3"
    
    // MARK: - Hardcoded Surahs Data (keeping this for now since MP3Quran doesn't provide surah metadata)
    private let hardcodedSurahs: [Surah] = [
        Surah(number: 1, name: "الفاتحة", englishName: "Al-Fatiha", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan"),
        Surah(number: 2, name: "البقرة", englishName: "Al-Baqarah", englishNameTranslation: "The Cow", numberOfAyahs: 286, revelationType: "Medinan"),
        Surah(number: 3, name: "آل عمران", englishName: "Aal-Imran", englishNameTranslation: "The Family of Imran", numberOfAyahs: 200, revelationType: "Medinan"),
        Surah(number: 4, name: "النساء", englishName: "An-Nisa", englishNameTranslation: "The Women", numberOfAyahs: 176, revelationType: "Medinan"),
        Surah(number: 5, name: "المائدة", englishName: "Al-Ma'idah", englishNameTranslation: "The Table Spread", numberOfAyahs: 120, revelationType: "Medinan"),
        Surah(number: 6, name: "الأنعام", englishName: "Al-An'am", englishNameTranslation: "The Cattle", numberOfAyahs: 165, revelationType: "Meccan"),
        Surah(number: 7, name: "الأعراف", englishName: "Al-A'raf", englishNameTranslation: "The Heights", numberOfAyahs: 206, revelationType: "Meccan"),
        Surah(number: 8, name: "الأنفال", englishName: "Al-Anfal", englishNameTranslation: "The Spoils of War", numberOfAyahs: 75, revelationType: "Medinan"),
        Surah(number: 9, name: "التوبة", englishName: "At-Tawbah", englishNameTranslation: "The Repentance", numberOfAyahs: 129, revelationType: "Medinan"),
        Surah(number: 10, name: "يونس", englishName: "Yunus", englishNameTranslation: "Jonah", numberOfAyahs: 109, revelationType: "Meccan"),
        Surah(number: 11, name: "هود", englishName: "Hud", englishNameTranslation: "Hud", numberOfAyahs: 123, revelationType: "Meccan"),
        Surah(number: 12, name: "يوسف", englishName: "Yusuf", englishNameTranslation: "Joseph", numberOfAyahs: 111, revelationType: "Meccan"),
        Surah(number: 13, name: "الرعد", englishName: "Ar-Ra'd", englishNameTranslation: "The Thunder", numberOfAyahs: 43, revelationType: "Medinan"),
        Surah(number: 14, name: "إبراهيم", englishName: "Ibrahim", englishNameTranslation: "Abraham", numberOfAyahs: 52, revelationType: "Meccan"),
        Surah(number: 15, name: "الحجر", englishName: "Al-Hijr", englishNameTranslation: "The Rocky Tract", numberOfAyahs: 99, revelationType: "Meccan"),
        Surah(number: 16, name: "النحل", englishName: "An-Nahl", englishNameTranslation: "The Bees", numberOfAyahs: 128, revelationType: "Meccan"),
        Surah(number: 17, name: "الإسراء", englishName: "Al-Isra", englishNameTranslation: "The Night Journey", numberOfAyahs: 111, revelationType: "Meccan"),
        Surah(number: 18, name: "الكهف", englishName: "Al-Kahf", englishNameTranslation: "The Cave", numberOfAyahs: 110, revelationType: "Meccan"),
        Surah(number: 19, name: "مريم", englishName: "Maryam", englishNameTranslation: "Mary", numberOfAyahs: 98, revelationType: "Meccan"),
        Surah(number: 20, name: "طه", englishName: "Ta-Ha", englishNameTranslation: "Ta-Ha", numberOfAyahs: 135, revelationType: "Meccan"),
        Surah(number: 21, name: "الأنبياء", englishName: "Al-Anbya", englishNameTranslation: "The Prophets", numberOfAyahs: 112, revelationType: "Meccan"),
        Surah(number: 22, name: "الحج", englishName: "Al-Hajj", englishNameTranslation: "The Pilgrimage", numberOfAyahs: 78, revelationType: "Medinan"),
        Surah(number: 23, name: "المؤمنون", englishName: "Al-Mu'minun", englishNameTranslation: "The Believers", numberOfAyahs: 118, revelationType: "Meccan"),
        Surah(number: 24, name: "النور", englishName: "An-Nur", englishNameTranslation: "The Light", numberOfAyahs: 64, revelationType: "Medinan"),
        Surah(number: 25, name: "الفرقان", englishName: "Al-Furqan", englishNameTranslation: "The Criterion", numberOfAyahs: 77, revelationType: "Meccan"),
        Surah(number: 26, name: "الشعراء", englishName: "Ash-Shu'ara", englishNameTranslation: "The Poets", numberOfAyahs: 227, revelationType: "Meccan"),
        Surah(number: 27, name: "النمل", englishName: "An-Naml", englishNameTranslation: "The Ants", numberOfAyahs: 93, revelationType: "Meccan"),
        Surah(number: 28, name: "القصص", englishName: "Al-Qasas", englishNameTranslation: "The Stories", numberOfAyahs: 88, revelationType: "Meccan"),
        Surah(number: 29, name: "العنكبوت", englishName: "Al-Ankabut", englishNameTranslation: "The Spider", numberOfAyahs: 69, revelationType: "Meccan"),
        Surah(number: 30, name: "الروم", englishName: "Ar-Rum", englishNameTranslation: "The Romans", numberOfAyahs: 60, revelationType: "Meccan"),
        Surah(number: 31, name: "لقمان", englishName: "Luqman", englishNameTranslation: "Luqman", numberOfAyahs: 34, revelationType: "Meccan"),
        Surah(number: 32, name: "السجدة", englishName: "As-Sajdah", englishNameTranslation: "The Prostration", numberOfAyahs: 30, revelationType: "Meccan"),
        Surah(number: 33, name: "الأحزاب", englishName: "Al-Ahzab", englishNameTranslation: "The Combined Forces", numberOfAyahs: 73, revelationType: "Medinan"),
        Surah(number: 34, name: "سبأ", englishName: "Saba", englishNameTranslation: "Sheba", numberOfAyahs: 54, revelationType: "Meccan"),
        Surah(number: 35, name: "فاطر", englishName: "Fatir", englishNameTranslation: "Originator", numberOfAyahs: 45, revelationType: "Meccan"),
        Surah(number: 36, name: "يس", englishName: "Ya-Sin", englishNameTranslation: "Ya-Sin", numberOfAyahs: 83, revelationType: "Meccan"),
        Surah(number: 37, name: "الصافات", englishName: "As-Saffat", englishNameTranslation: "Those Who Set The Ranks", numberOfAyahs: 182, revelationType: "Meccan"),
        Surah(number: 38, name: "ص", englishName: "Sad", englishNameTranslation: "Sad", numberOfAyahs: 88, revelationType: "Meccan"),
        Surah(number: 39, name: "الزمر", englishName: "Az-Zumar", englishNameTranslation: "The Troops", numberOfAyahs: 75, revelationType: "Meccan"),
        Surah(number: 40, name: "غافر", englishName: "Ghafir", englishNameTranslation: "The Forgiver", numberOfAyahs: 85, revelationType: "Meccan"),
        Surah(number: 41, name: "فصلت", englishName: "Fussilat", englishNameTranslation: "Explained in Detail", numberOfAyahs: 54, revelationType: "Meccan"),
        Surah(number: 42, name: "الشورى", englishName: "Ash-Shuraa", englishNameTranslation: "The Consultation", numberOfAyahs: 53, revelationType: "Meccan"),
        Surah(number: 43, name: "الزخرف", englishName: "Az-Zukhruf", englishNameTranslation: "The Ornaments of Gold", numberOfAyahs: 89, revelationType: "Meccan"),
        Surah(number: 44, name: "الدخان", englishName: "Ad-Dukhan", englishNameTranslation: "The Smoke", numberOfAyahs: 59, revelationType: "Meccan"),
        Surah(number: 45, name: "الجاثية", englishName: "Al-Jathiyah", englishNameTranslation: "The Kneeling", numberOfAyahs: 37, revelationType: "Meccan"),
        Surah(number: 46, name: "الأحقاف", englishName: "Al-Ahqaf", englishNameTranslation: "The Wind-Curved Sandhills", numberOfAyahs: 35, revelationType: "Meccan"),
        Surah(number: 47, name: "محمد", englishName: "Muhammad", englishNameTranslation: "Muhammad", numberOfAyahs: 38, revelationType: "Medinan"),
        Surah(number: 48, name: "الفتح", englishName: "Al-Fath", englishNameTranslation: "The Victory", numberOfAyahs: 29, revelationType: "Medinan"),
        Surah(number: 49, name: "الحجرات", englishName: "Al-Hujurat", englishNameTranslation: "The Private Apartments", numberOfAyahs: 18, revelationType: "Medinan"),
        Surah(number: 50, name: "ق", englishName: "Qaf", englishNameTranslation: "Qaf", numberOfAyahs: 45, revelationType: "Meccan"),
        Surah(number: 51, name: "الذاريات", englishName: "Adh-Dhariyat", englishNameTranslation: "The Winnowing Winds", numberOfAyahs: 60, revelationType: "Meccan"),
        Surah(number: 52, name: "الطور", englishName: "At-Tur", englishNameTranslation: "The Mount", numberOfAyahs: 49, revelationType: "Meccan"),
        Surah(number: 53, name: "النجم", englishName: "An-Najm", englishNameTranslation: "The Star", numberOfAyahs: 62, revelationType: "Meccan"),
        Surah(number: 54, name: "القمر", englishName: "Al-Qamar", englishNameTranslation: "The Moon", numberOfAyahs: 55, revelationType: "Meccan"),
        Surah(number: 55, name: "الرحمن", englishName: "Ar-Rahman", englishNameTranslation: "The Beneficent", numberOfAyahs: 78, revelationType: "Medinan"),
        Surah(number: 56, name: "الواقعة", englishName: "Al-Waqi'ah", englishNameTranslation: "The Inevitable", numberOfAyahs: 96, revelationType: "Meccan"),
        Surah(number: 57, name: "الحديد", englishName: "Al-Hadid", englishNameTranslation: "The Iron", numberOfAyahs: 29, revelationType: "Medinan"),
        Surah(number: 58, name: "المجادلة", englishName: "Al-Mujadila", englishNameTranslation: "The Pleading Woman", numberOfAyahs: 22, revelationType: "Medinan"),
        Surah(number: 59, name: "الحشر", englishName: "Al-Hashr", englishNameTranslation: "The Exile", numberOfAyahs: 24, revelationType: "Medinan"),
        Surah(number: 60, name: "الممتحنة", englishName: "Al-Mumtahanah", englishNameTranslation: "The Woman to be Examined", numberOfAyahs: 13, revelationType: "Medinan"),
        Surah(number: 61, name: "الصف", englishName: "As-Saf", englishNameTranslation: "The Ranks", numberOfAyahs: 14, revelationType: "Medinan"),
        Surah(number: 62, name: "الجمعة", englishName: "Al-Jumu'ah", englishNameTranslation: "The Congregation", numberOfAyahs: 11, revelationType: "Medinan"),
        Surah(number: 63, name: "المنافقون", englishName: "Al-Munafiqun", englishNameTranslation: "The Hypocrites", numberOfAyahs: 11, revelationType: "Medinan"),
        Surah(number: 64, name: "التغابن", englishName: "At-Taghabun", englishNameTranslation: "The Mutual Disillusion", numberOfAyahs: 18, revelationType: "Medinan"),
        Surah(number: 65, name: "الطلاق", englishName: "At-Talaq", englishNameTranslation: "Divorce", numberOfAyahs: 12, revelationType: "Medinan"),
        Surah(number: 66, name: "التحريم", englishName: "At-Tahrim", englishNameTranslation: "The Prohibition", numberOfAyahs: 12, revelationType: "Medinan"),
        Surah(number: 67, name: "الملك", englishName: "Al-Mulk", englishNameTranslation: "The Sovereignty", numberOfAyahs: 30, revelationType: "Meccan"),
        Surah(number: 68, name: "القلم", englishName: "Al-Qalam", englishNameTranslation: "The Pen", numberOfAyahs: 52, revelationType: "Meccan"),
        Surah(number: 69, name: "الحاقة", englishName: "Al-Haqqah", englishNameTranslation: "The Reality", numberOfAyahs: 52, revelationType: "Meccan"),
        Surah(number: 70, name: "المعارج", englishName: "Al-Ma'arij", englishNameTranslation: "The Ascending Stairways", numberOfAyahs: 44, revelationType: "Meccan"),
        Surah(number: 71, name: "نوح", englishName: "Nuh", englishNameTranslation: "Noah", numberOfAyahs: 28, revelationType: "Meccan"),
        Surah(number: 72, name: "الجن", englishName: "Al-Jinn", englishNameTranslation: "The Jinn", numberOfAyahs: 28, revelationType: "Meccan"),
        Surah(number: 73, name: "المزمل", englishName: "Al-Muzzammil", englishNameTranslation: "The Enshrouded One", numberOfAyahs: 20, revelationType: "Meccan"),
        Surah(number: 74, name: "المدثر", englishName: "Al-Muddathir", englishNameTranslation: "The Cloaked One", numberOfAyahs: 56, revelationType: "Meccan"),
        Surah(number: 75, name: "القيامة", englishName: "Al-Qiyamah", englishNameTranslation: "The Resurrection", numberOfAyahs: 40, revelationType: "Meccan"),
        Surah(number: 76, name: "الإنسان", englishName: "Al-Insan", englishNameTranslation: "Man", numberOfAyahs: 31, revelationType: "Medinan"),
        Surah(number: 77, name: "المرسلات", englishName: "Al-Mursalat", englishNameTranslation: "The Emissaries", numberOfAyahs: 50, revelationType: "Meccan"),
        Surah(number: 78, name: "النبأ", englishName: "An-Naba", englishNameTranslation: "The Tidings", numberOfAyahs: 40, revelationType: "Meccan"),
        Surah(number: 79, name: "النازعات", englishName: "An-Nazi'at", englishNameTranslation: "Those Who Drag Forth", numberOfAyahs: 46, revelationType: "Meccan"),
        Surah(number: 80, name: "عبس", englishName: "Abasa", englishNameTranslation: "He Frowned", numberOfAyahs: 42, revelationType: "Meccan"),
        Surah(number: 81, name: "التكوير", englishName: "At-Takwir", englishNameTranslation: "The Overthrowing", numberOfAyahs: 29, revelationType: "Meccan"),
        Surah(number: 82, name: "الإنفطار", englishName: "Al-Infitar", englishNameTranslation: "The Cleaving", numberOfAyahs: 19, revelationType: "Meccan"),
        Surah(number: 83, name: "المطففين", englishName: "Al-Mutaffifin", englishNameTranslation: "The Defrauding", numberOfAyahs: 36, revelationType: "Meccan"),
        Surah(number: 84, name: "الإنشقاق", englishName: "Al-Inshiqaq", englishNameTranslation: "The Splitting Open", numberOfAyahs: 25, revelationType: "Meccan"),
        Surah(number: 85, name: "البروج", englishName: "Al-Buruj", englishNameTranslation: "The Mansions of the Stars", numberOfAyahs: 22, revelationType: "Meccan"),
        Surah(number: 86, name: "الطارق", englishName: "At-Tariq", englishNameTranslation: "The Morning Star", numberOfAyahs: 17, revelationType: "Meccan"),
        Surah(number: 87, name: "الأعلى", englishName: "Al-A'la", englishNameTranslation: "The Most High", numberOfAyahs: 19, revelationType: "Meccan"),
        Surah(number: 88, name: "الغاشية", englishName: "Al-Ghashiyah", englishNameTranslation: "The Overwhelming", numberOfAyahs: 26, revelationType: "Meccan"),
        Surah(number: 89, name: "الفجر", englishName: "Al-Fajr", englishNameTranslation: "The Dawn", numberOfAyahs: 30, revelationType: "Meccan"),
        Surah(number: 90, name: "البلد", englishName: "Al-Balad", englishNameTranslation: "The City", numberOfAyahs: 20, revelationType: "Meccan"),
        Surah(number: 91, name: "الشمس", englishName: "Ash-Shams", englishNameTranslation: "The Sun", numberOfAyahs: 15, revelationType: "Meccan"),
        Surah(number: 92, name: "الليل", englishName: "Al-Layl", englishNameTranslation: "The Night", numberOfAyahs: 21, revelationType: "Meccan"),
        Surah(number: 93, name: "الضحى", englishName: "Ad-Duha", englishNameTranslation: "The Morning Hours", numberOfAyahs: 11, revelationType: "Meccan"),
        Surah(number: 94, name: "الشرح", englishName: "Ash-Sharh", englishNameTranslation: "The Relief", numberOfAyahs: 8, revelationType: "Meccan"),
        Surah(number: 95, name: "التين", englishName: "At-Tin", englishNameTranslation: "The Fig", numberOfAyahs: 8, revelationType: "Meccan"),
        Surah(number: 96, name: "العلق", englishName: "Al-Alaq", englishNameTranslation: "The Clot", numberOfAyahs: 19, revelationType: "Meccan"),
        Surah(number: 97, name: "القدر", englishName: "Al-Qadr", englishNameTranslation: "The Power", numberOfAyahs: 5, revelationType: "Meccan"),
        Surah(number: 98, name: "البينة", englishName: "Al-Bayyinah", englishNameTranslation: "The Clear Proof", numberOfAyahs: 8, revelationType: "Medinan"),
        Surah(number: 99, name: "الزلزلة", englishName: "Az-Zalzalah", englishNameTranslation: "The Earthquake", numberOfAyahs: 8, revelationType: "Medinan"),
        Surah(number: 100, name: "العاديات", englishName: "Al-Adiyat", englishNameTranslation: "The Coursers", numberOfAyahs: 11, revelationType: "Meccan"),
        Surah(number: 101, name: "القارعة", englishName: "Al-Qari'ah", englishNameTranslation: "The Calamity", numberOfAyahs: 11, revelationType: "Meccan"),
        Surah(number: 102, name: "التكاثر", englishName: "At-Takathur", englishNameTranslation: "The Rivalry in World Increase", numberOfAyahs: 8, revelationType: "Meccan"),
        Surah(number: 103, name: "العصر", englishName: "Al-Asr", englishNameTranslation: "The Declining Day", numberOfAyahs: 3, revelationType: "Meccan"),
        Surah(number: 104, name: "الهمزة", englishName: "Al-Humazah", englishNameTranslation: "The Traducer", numberOfAyahs: 9, revelationType: "Meccan"),
        Surah(number: 105, name: "الفيل", englishName: "Al-Fil", englishNameTranslation: "The Elephant", numberOfAyahs: 5, revelationType: "Meccan"),
        Surah(number: 106, name: "قريش", englishName: "Quraysh", englishNameTranslation: "Quraysh", numberOfAyahs: 4, revelationType: "Meccan"),
        Surah(number: 107, name: "الماعون", englishName: "Al-Ma'un", englishNameTranslation: "The Small Kindnesses", numberOfAyahs: 7, revelationType: "Meccan"),
        Surah(number: 108, name: "الكوثر", englishName: "Al-Kawthar", englishNameTranslation: "The Abundance", numberOfAyahs: 3, revelationType: "Meccan"),
        Surah(number: 109, name: "الكافرون", englishName: "Al-Kafirun", englishNameTranslation: "The Disbelievers", numberOfAyahs: 6, revelationType: "Meccan"),
        Surah(number: 110, name: "النصر", englishName: "An-Nasr", englishNameTranslation: "The Divine Support", numberOfAyahs: 3, revelationType: "Medinan"),
        Surah(number: 111, name: "المسد", englishName: "Al-Masad", englishNameTranslation: "The Palm Fiber", numberOfAyahs: 5, revelationType: "Meccan"),
        Surah(number: 112, name: "الإخلاص", englishName: "Al-Ikhlas", englishNameTranslation: "The Sincerity", numberOfAyahs: 4, revelationType: "Meccan"),
        Surah(number: 113, name: "الفلق", englishName: "Al-Falaq", englishNameTranslation: "The Daybreak", numberOfAyahs: 5, revelationType: "Meccan"),
        Surah(number: 114, name: "الناس", englishName: "An-Nas", englishNameTranslation: "Mankind", numberOfAyahs: 6, revelationType: "Meccan")
    ]
    
    // Public accessor for the hardcoded surahs
    func getHardcodedSurahs() -> [Surah] {
        return hardcodedSurahs
    }
    
    // MARK: - Fetch Reciters from MP3Quran API
    func fetchReciters() async throws -> [Reciter] {
        // If we have already fetched the reciters, return the cached version.
        if !allReciters.isEmpty {
            print("✅ [QuranAPIService] Returning cached reciters.")
            return allReciters
        }

        print("🔍 [QuranAPIService] Fetching reciters from all sources...")

        var mp3quranReciters: [Reciter] = []
        var quranCentralReciters: [Reciter] = []
        
        // Try to fetch from MP3Quran
        do {
            mp3quranReciters = try await fetchMP3QuranReciters()
            print("✅ [QuranAPIService] Fetched \(mp3quranReciters.count) reciters from MP3Quran.net")
        } catch {
            print("⚠️ [QuranAPIService] Failed to fetch from MP3Quran: \(error)")
        }
        
        // Try to fetch from QuranCentral
        do {
            quranCentralReciters = try await QuranCentralService.shared.fetchAllReciters()
            print("✅ [QuranAPIService] Fetched \(quranCentralReciters.count) reciters from Quran Central")
        } catch {
            print("⚠️ [QuranAPIService] Failed to fetch from Quran Central: \(error)")
        }
        
        // If both services failed, throw an error
        if mp3quranReciters.isEmpty && quranCentralReciters.isEmpty {
            print("❌ [QuranAPIService] All services failed to fetch reciters")
            throw QuranAPIError.networkError
        }

        // De-duplication logic: Prioritize Quran Central reciters.
        // Only add reciters from MP3Quran if a reciter with a similar name doesn't already exist in the Quran Central list.
        var uniqueReciters = quranCentralReciters
        let quranCentralNames = Set(quranCentralReciters.map { $0.englishName.lowercased() })
        
        for mp3Reciter in mp3quranReciters {
            if !quranCentralNames.contains(mp3Reciter.englishName.lowercased()) {
                uniqueReciters.append(mp3Reciter)
            }
        }
        
        print("✅ [QuranAPIService] Combined and de-duplicated lists. Total unique reciters: \(uniqueReciters.count)")
        
        let sortedReciters = uniqueReciters.sorted { $0.englishName < $1.englishName }
        
        // Cache the reciters
        self.allReciters = sortedReciters
        
        // Publish the change
        await MainActor.run {
            self.reciters = sortedReciters
        }
        
        return sortedReciters
    }

    private func fetchMP3QuranReciters() async throws -> [Reciter] {
        print("🔍 [QuranAPIService] Fetching reciters from MP3Quran API...")
        
        guard let url = URL(string: "\(mp3QuranBaseURL)/reciters?language=eng") else {
            throw QuranAPIError.invalidURL
        }
        
            let (data, response) = try await URLSession.shared.data(from: url)
            
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw QuranAPIError.networkError
            }
            
            let mp3QuranResponse = try JSONDecoder().decode(MP3QuranRecitersResponse.self, from: data)
            
            // Convert MP3Quran reciters to our Reciter model
            let reciters = mp3QuranResponse.reciters.compactMap { mp3Reciter -> Reciter? in
                guard let completeMoshaf = mp3Reciter.moshaf.first(where: { $0.surahTotal == 114 && $0.moshafType == 11 }) else {
                    return nil
                }
            
            // A manual mapping for reciters whose names don't match their artwork slugs.
            let slugMap = [
                "Abdul Basit 'Abd us-Samad": "abdul-basit-abd-us-samad"
            ]
            
            // Create a slug from the name to attempt to find artwork on Quran Central.
            // Use the map if available, otherwise generate it automatically.
            let generatedSlug = mp3Reciter.name.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "--", with: "-")
            let slug = slugMap[mp3Reciter.name] ?? generatedSlug
            let artworkURL = URL(string: "https://artwork.qurancentral.com/\(slug).jpg")
                
                return Reciter(
                    identifier: "mp3quran_\(mp3Reciter.id)",
                    language: "ar",
                    name: mp3Reciter.name,
                englishName: mp3Reciter.name,
                    server: completeMoshaf.server,
                reciterId: mp3Reciter.id,
                country: nil,
                dialect: nil,
                artworkURL: artworkURL
                )
            }
            
            return reciters
    }
    
    // MARK: - Fetch Surahs
    func fetchSurahs() async throws -> [Surah] {
        print("🔍 [QuranAPIService] Returning hardcoded surahs data...")
        print("✅ [QuranAPIService] Successfully returned \(hardcodedSurahs.count) surahs")
        return hardcodedSurahs
    }
    
    // MARK: - Construct Audio URL
    func constructAudioURL(surahNumber: Int, reciter: Reciter) async throws -> String {
        let quranCentralPrefix = "qurancentral_"
        
        if reciter.identifier.hasPrefix(quranCentralPrefix) {
            // This is a Quran Central reciter. Use the new service.
            print("▶️ [QuranAPIService] Using Quran Central service for reciter: \(reciter.englishName)")
            
            // Find the surah name to pass to the new service for more robust searching
            guard let surah = self.getHardcodedSurahs().first(where: { $0.number == surahNumber }) else {
                print("❌ [QuranAPIService] Could not find surah details for number \(surahNumber)")
                throw QuranAPIError.audioNotFound
            }
            
            let slug = String(reciter.identifier.dropFirst(quranCentralPrefix.count))
            let url = try await QuranCentralService.shared.fetchAudioURL(for: surahNumber, surahName: surah.englishName, reciterSlug: slug)
            return url.absoluteString
            
        } else {
            // This is an MP3Quran.net reciter. Use the original logic.
            print("▶️ [QuranAPIService] Using MP3Quran service for reciter: \(reciter.englishName)")
        guard let server = reciter.server else {
            throw QuranAPIError.audioNotFound
        }
        let formattedSurahNumber = String(format: "%03d", surahNumber)
        return "\(server)/\(formattedSurahNumber).mp3"
        }
    }
    
    // MARK: - Validate Audio URL
    func isAudioURLValid(_ audioURL: String) async -> Bool {
        guard let url = URL(string: audioURL) else {
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("❌ [QuranAPIService] Audio URL validation failed for \(audioURL): \(error)")
            return false
        }
        
        return false
    }
    
    // MARK: - Validate Reciter Audio Files
    func validateReciterAudio(reciter: Reciter) async -> Bool {
        guard let server = reciter.server else {
            return false
        }
        
        // Test a few key surahs to ensure the reciter has working audio
        let testSurahs = [1, 2, 36, 55, 67, 112, 113, 114] // Al-Fatiha, Al-Baqarah, Ya-Sin, Ar-Rahman, Al-Mulk, Al-Ikhlas, Al-Falaq, An-Nas
        
        for surahNumber in testSurahs {
            let audioURL = "\(server)/\(String(format: "%03d", surahNumber)).mp3"
            let isValid = await isAudioURLValid(audioURL)
            if !isValid {
                print("❌ [QuranAPIService] Reciter \(reciter.englishName) failed validation for surah \(surahNumber)")
                return false
            }
        }
        
        print("✅ [QuranAPIService] Reciter \(reciter.englishName) passed audio validation")
        return true
    }
    
    // MARK: - Get Validated Reciters
    func fetchValidatedReciters() async throws -> [Reciter] {
        let allReciters = try await fetchReciters()
        print("🔍 [QuranAPIService] Validating \(allReciters.count) reciters...")
        
        var validatedReciters: [Reciter] = []
        
        for reciter in allReciters {
            let isValid = await validateReciterAudio(reciter: reciter)
            if isValid {
                validatedReciters.append(reciter)
            }
        }
        
        print("✅ [QuranAPIService] Found \(validatedReciters.count) validated reciters out of \(allReciters.count) total")
        return validatedReciters
    }
} 