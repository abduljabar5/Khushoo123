import Foundation

struct PrayerTimeResponse: Decodable {
    let data: PrayerTimeData
}

struct PrayerTimeData: Decodable {
    let timings: Timings
}

struct Timings: Decodable {
    let Fajr: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
} 