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

struct PrayerTime: Identifiable {
    let id = UUID()
    let name: String
    let date: Date

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Calendar API Response Models
struct CalendarResponse: Decodable {
    let data: [CalendarDayData]
}

struct CalendarDayData: Decodable {
    let timings: Timings
    let date: DateInfo
}

struct DateInfo: Decodable {
    let timestamp: String
} 