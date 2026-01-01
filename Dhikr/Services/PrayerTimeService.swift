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
        // Check if data is still valid (covers current date + reasonable future coverage)
        let now = Date()
        guard now >= startDate && now <= endDate else { return false }

        // For short-term data (< 7 days), just check if it covers today
        let daysCovered = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysCovered < 7 {
            // Short-term data (free users) - valid if covers today
            return true
        }

        // For long-term data (>= 7 days), require at least 3 months future coverage
        let threeMonthsFromNow = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
        return endDate >= threeMonthsFromNow
    }

    var shouldRefresh: Bool {
        // Refresh if data is older than 6 months or doesn't cover current needs
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

        let urlString = "https://api.aladhan.com/v1/timings/\(dateString)?latitude=\(latitude)&longitude=\(longitude)&method=\(calculationMethod)"

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

    // MARK: - 6-Month Fetch (using calendar API for bulk fetching)
    func fetch6MonthPrayerTimes(for location: CLLocation, startingFrom startDate: Date = Date(), daysToFetch: Int = 180) async throws -> PrayerTimeStorage {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)

        // Calculate end date based on days to fetch
        guard let end = calendar.date(byAdding: .day, value: daysToFetch, to: start) else {
            throw NSError(domain: "PrayerTimeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to calculate end date"])
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"

        print("🕌 [PrayerBlocking] Starting prayer time fetch (\(daysToFetch) days) using calendar API")
        print("🕌 [PrayerBlocking] Date range: \(displayFormatter.string(from: start)) to \(displayFormatter.string(from: end))")
        print("🕌 [PrayerBlocking] Location: lat=\(String(format: "%.4f", latitude)), lon=\(String(format: "%.4f", longitude))")

        var storedTimes: [StoredPrayerTime] = []
        var currentDate = start
        var fetchedMonths = 0
        var totalMonths = 0

        // Calculate number of months to fetch
        let monthComponents = calendar.dateComponents([.month], from: start, to: end)
        totalMonths = max((monthComponents.month ?? 0) + 1, 1)

        while currentDate < end {
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)

            // Use calendar API to fetch entire month at once
            let urlString = "https://api.aladhan.com/v1/calendar/\(year)/\(month)?latitude=\(latitude)&longitude=\(longitude)&method=\(calculationMethod)"

            guard let url = URL(string: urlString) else {
                throw URLError(.badURL)
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }

                let calendarResponse = try JSONDecoder().decode(CalendarResponse.self, from: data)

                // Process each day in the month
                for dayData in calendarResponse.data {
                    // Convert timestamp string to TimeInterval
                    guard let timestamp = TimeInterval(dayData.date.timestamp) else {
                        print("⚠️ [PrayerBlocking] Failed to parse timestamp: \(dayData.date.timestamp)")
                        continue
                    }

                    let dayDate = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))

                    // Only include dates within our range
                    if dayDate >= start && dayDate < end {
                        let storedTime = StoredPrayerTime(
                            date: dayDate,
                            fajr: dayData.timings.Fajr,
                            dhuhr: dayData.timings.Dhuhr,
                            asr: dayData.timings.Asr,
                            maghrib: dayData.timings.Maghrib,
                            isha: dayData.timings.Isha
                        )
                        storedTimes.append(storedTime)
                    }
                }

                fetchedMonths += 1
                print("🕌 [PrayerBlocking] Fetched month \(fetchedMonths)/\(totalMonths) (\(year)-\(String(format: "%02d", month)))")

                // Small delay to be respectful to API (100ms per month request)
                try await Task.sleep(nanoseconds: 100_000_000)

            } catch {
                print("❌ [PrayerBlocking] Failed to fetch prayer times for \(year)-\(month): \(error.localizedDescription)")
                throw error
            }

            // Move to next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextMonth
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

        print("🕌 [PrayerBlocking] Completed 6-month fetch: \(storedTimes.count) days from \(fetchedMonths) months")
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

    // MARK: - Location Validation (Tiered System)
    func needsRefreshForLocation(_ location: CLLocation, storage: PrayerTimeStorage) async -> Bool {
        let latDiff = abs(location.coordinate.latitude - storage.latitude)
        let lonDiff = abs(location.coordinate.longitude - storage.longitude)

        // Tiered thresholds
        let smallChange = 0.18  // ~20km - prayer times differ by <1 minute
        let mediumChange = 0.9  // ~100km - check if times actually changed

        let maxDiff = max(latDiff, lonDiff)

        // Tier 1: Small change (<20km) - Don't refresh
        if maxDiff <= smallChange {
            print("✅ [PrayerBlocking] Location change small (<20km) - keeping data")
            return false
        }

        // Tier 2: Medium change (20-100km) - Fetch 1 day to check if times actually changed
        if maxDiff <= mediumChange {
            print("🔍 [PrayerBlocking] Location change medium (20-100km) - checking if times differ...")
            print("🔍 [PrayerBlocking] Old: lat=\(String(format: "%.4f", storage.latitude)), lon=\(String(format: "%.4f", storage.longitude))")
            print("🔍 [PrayerBlocking] New: lat=\(String(format: "%.4f", location.coordinate.latitude)), lon=\(String(format: "%.4f", location.coordinate.longitude))")

            do {
                // Fetch prayer times for today at new location
                let newTimings = try await fetchPrayerTimes(for: location, on: Date())

                // Get stored times for today
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())

                if let todayStored = storage.prayerTimes.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                    // Compare times - if any prayer differs by >5 minutes, refresh
                    let timeDiff = maxTimeDifference(stored: todayStored, new: newTimings)

                    if timeDiff > 5 {
                        print("⚠️ [PrayerBlocking] Prayer times differ by \(timeDiff) minutes - needs refresh")
                        return true
                    } else {
                        print("✅ [PrayerBlocking] Prayer times similar (diff: \(timeDiff) min) - keeping data")
                        return false
                    }
                }
            } catch {
                print("⚠️ [PrayerBlocking] Failed to check time difference: \(error.localizedDescription) - refreshing to be safe")
                return true
            }
        }

        // Tier 3: Large change (>100km) - Always refresh
        print("🔄 [PrayerBlocking] Location changed significantly (>100km) - needs refresh")
        print("🔄 [PrayerBlocking] Old: lat=\(String(format: "%.4f", storage.latitude)), lon=\(String(format: "%.4f", storage.longitude))")
        print("🔄 [PrayerBlocking] New: lat=\(String(format: "%.4f", location.coordinate.latitude)), lon=\(String(format: "%.4f", location.coordinate.longitude))")
        return true
    }

    // Helper to calculate max time difference between stored and new timings
    private func maxTimeDifference(stored: StoredPrayerTime, new: Timings) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let prayers = [
            (stored.fajr, new.Fajr),
            (stored.dhuhr, new.Dhuhr),
            (stored.asr, new.Asr),
            (stored.maghrib, new.Maghrib),
            (stored.isha, new.Isha)
        ]

        var maxDiff = 0
        for (storedTime, newTime) in prayers {
            // Parse times (format: "HH:mm" or "HH:mm (TZ)")
            let storedCleaned = storedTime.components(separatedBy: " ").first ?? storedTime
            let newCleaned = newTime.components(separatedBy: " ").first ?? newTime

            guard let storedDate = formatter.date(from: storedCleaned),
                  let newDate = formatter.date(from: newCleaned) else {
                continue
            }

            let diff = Int(abs(storedDate.timeIntervalSince(newDate)) / 60)
            maxDiff = max(maxDiff, diff)
        }

        return maxDiff
    }
} 