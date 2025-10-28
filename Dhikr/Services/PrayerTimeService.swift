import Foundation
import CoreLocation

// MARK: - Storage Models
struct PrayerTimeStorage: Codable {
    let startDate: Date
    let endDate: Date
    let latitude: Double
    let longitude: Double
    let method: Int
    let prayerTimes: [StoredPrayerTime]
    let fetchedAt: Date

    var isValid: Bool {
        // Check if data is still valid (covers current date + at least 3 months)
        let now = Date()
        guard now >= startDate && now <= endDate else { return false }

        let threeMonthsFromNow = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
        return endDate >= threeMonthsFromNow
    }

    var shouldRefresh: Bool {
        // Refresh if data is older than 6 months or doesn't cover next 6 months
        let now = Date()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) ?? now
        return fetchedAt < sixMonthsAgo || !isValid
    }
}

struct StoredPrayerTime: Codable {
    let date: Date
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
}

class PrayerTimeService {
    private let storageKey = "PrayerTimeStorage_v1"
    private let calculationMethod = 2 // Islamic Society of North America (ISNA)

    // MARK: - Single Day Fetch (existing functionality)
    func fetchPrayerTimes(for location: CLLocation, on date: Date = Date()) async throws -> Timings {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: date)

        let urlString = "http://api.aladhan.com/v1/timings/\(dateString)?latitude=\(latitude)&longitude=\(longitude)&method=\(calculationMethod)"

        print("🕌 [PrayerBlocking] Fetching single day prayer times: \(dateString)")

        guard let url = URL(string: urlString) else {
            print("❌ [PrayerBlocking] Invalid URL for date: \(dateString)")
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("❌ [PrayerBlocking] Bad server response for date: \(dateString)")
            throw URLError(.badServerResponse)
        }

        let prayerTimeResponse = try JSONDecoder().decode(PrayerTimeResponse.self, from: data)
        return prayerTimeResponse.data.timings
    }

    // MARK: - 6-Month Fetch
    func fetch6MonthPrayerTimes(for location: CLLocation, startingFrom startDate: Date = Date()) async throws -> PrayerTimeStorage {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)

        // Calculate end date (6 months from start)
        guard let end = calendar.date(byAdding: .month, value: 6, to: start) else {
            throw NSError(domain: "PrayerTimeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate end date"])
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"

        print("🕌 [PrayerBlocking] Starting 6-month prayer time fetch")
        print("🕌 [PrayerBlocking] Date range: \(displayFormatter.string(from: start)) to \(displayFormatter.string(from: end))")
        print("🕌 [PrayerBlocking] Location: lat=\(String(format: "%.4f", latitude)), lon=\(String(format: "%.4f", longitude))")

        var storedTimes: [StoredPrayerTime] = []
        var currentDate = start
        var fetchedDays = 0
        var totalDays = 0

        // Calculate total days for progress tracking
        let components = calendar.dateComponents([.day], from: start, to: end)
        totalDays = components.day ?? 180

        while currentDate < end {
            let dateString = dateFormatter.string(from: currentDate)
            let urlString = "http://api.aladhan.com/v1/timings/\(dateString)?latitude=\(latitude)&longitude=\(longitude)&method=\(calculationMethod)"

            guard let url = URL(string: urlString) else {
                throw URLError(.badURL)
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                let prayerTimeResponse = try JSONDecoder().decode(PrayerTimeResponse.self, from: data)
                let timings = prayerTimeResponse.data.timings

                let storedTime = StoredPrayerTime(
                    date: currentDate,
                    fajr: timings.Fajr,
                    dhuhr: timings.Dhuhr,
                    asr: timings.Asr,
                    maghrib: timings.Maghrib,
                    isha: timings.Isha
                )

                storedTimes.append(storedTime)
                fetchedDays += 1

                // Log progress every 30 days
                if fetchedDays % 30 == 0 {
                    print("🕌 [PrayerBlocking] Fetched \(fetchedDays)/\(totalDays) days (\(Int((Double(fetchedDays)/Double(totalDays))*100))%)")
                }

                // Small delay to avoid overwhelming the API (50ms per request)
                try await Task.sleep(nanoseconds: 50_000_000)

            } catch {
                print("❌ [PrayerBlocking] Failed to fetch prayer times for \(dateString): \(error.localizedDescription)")
                throw error
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        let storage = PrayerTimeStorage(
            startDate: start,
            endDate: end,
            latitude: latitude,
            longitude: longitude,
            method: calculationMethod,
            prayerTimes: storedTimes,
            fetchedAt: Date()
        )

        print("🕌 [PrayerBlocking] Completed 6-month fetch: \(fetchedDays) days")
        print("🕌 [PrayerBlocking] Date range: \(displayFormatter.string(from: start)) to \(displayFormatter.string(from: end))")

        return storage
    }

    // MARK: - Storage Operations
    func saveStorage(_ storage: PrayerTimeStorage) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            print("❌ [PrayerBlocking] Failed to access group defaults for saving storage")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(storage)
            groupDefaults.set(data, forKey: storageKey)
            groupDefaults.synchronize()

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            print("💾 [PrayerBlocking] Saved \(storage.prayerTimes.count) prayer times to UserDefaults")
            print("💾 [PrayerBlocking] Date range: \(displayFormatter.string(from: storage.startDate)) to \(displayFormatter.string(from: storage.endDate))")
        } catch {
            print("❌ [PrayerBlocking] Failed to save storage: \(error.localizedDescription)")
        }
    }

    func loadStorage() -> PrayerTimeStorage? {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
              let data = groupDefaults.data(forKey: storageKey) else {
            print("🔍 [PrayerBlocking] No stored prayer times found")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let storage = try decoder.decode(PrayerTimeStorage.self, from: data)

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            print("📖 [PrayerBlocking] Loaded \(storage.prayerTimes.count) prayer times from UserDefaults")
            print("📖 [PrayerBlocking] Date range: \(displayFormatter.string(from: storage.startDate)) to \(displayFormatter.string(from: storage.endDate))")
            print("📖 [PrayerBlocking] Valid: \(storage.isValid), Should Refresh: \(storage.shouldRefresh)")

            return storage
        } catch {
            print("❌ [PrayerBlocking] Failed to load storage: \(error.localizedDescription)")
            return nil
        }
    }

    func clearStorage() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        groupDefaults.removeObject(forKey: storageKey)
        groupDefaults.synchronize()
        print("🗑️ [PrayerBlocking] Cleared stored prayer times")
    }

    // MARK: - Location Validation
    func needsRefreshForLocation(_ location: CLLocation, storage: PrayerTimeStorage) -> Bool {
        let locationTolerance = 0.5 // ~50km tolerance (increased from 2km for better UX)
        let latDiff = abs(location.coordinate.latitude - storage.latitude)
        let lonDiff = abs(location.coordinate.longitude - storage.longitude)

        let needsRefresh = latDiff > locationTolerance || lonDiff > locationTolerance

        if needsRefresh {
            print("🔄 [PrayerBlocking] Location changed significantly - needs refresh")
            print("🔄 [PrayerBlocking] Old: lat=\(String(format: "%.4f", storage.latitude)), lon=\(String(format: "%.4f", storage.longitude))")
            print("🔄 [PrayerBlocking] New: lat=\(String(format: "%.4f", location.coordinate.latitude)), lon=\(String(format: "%.4f", location.coordinate.longitude))")
        }

        return needsRefresh
    }
} 