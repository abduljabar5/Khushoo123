import SwiftUI
import CoreLocation
import Combine

class PrayerTimeViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var prayers: [Prayer] = []
    @Published var currentPrayer: Prayer?
    @Published var nextPrayer: Prayer?
    @Published var timeUntilNextPrayer: String = "--:--:--"
    @Published var cityName: String = "Minneapolis"
    @Published var stateName: String = "MN"
    @Published var countryName: String = "USA"
    @Published var calculationMethod: String = "ISNA"
    @Published var completedPrayers: Int = 0
    @Published var totalPrayers: Int = 5
    @Published var progressPercentage: CGFloat = 0
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let prayerTimeService = PrayerTimeService()
    private var timer: Timer?
    private var currentLocation: CLLocation?
    private var prayerTimes: Timings?

    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
        loadSavedData()
        setupPrayers()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Setup Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    private func loadSavedData() {
        // Load saved streak data
        currentStreak = UserDefaults.standard.integer(forKey: "currentPrayerStreak")
        bestStreak = UserDefaults.standard.integer(forKey: "bestPrayerStreak")

        // Load saved location if available
        if let savedCity = UserDefaults.standard.string(forKey: "savedCity") {
            cityName = savedCity
        }
        if let savedState = UserDefaults.standard.string(forKey: "savedState") {
            stateName = savedState
        }
        if let savedCountry = UserDefaults.standard.string(forKey: "savedCountry") {
            countryName = savedCountry
        }

        // Load today's completed prayers
        let today = dateKey(for: Date())
        if let completed = UserDefaults.standard.array(forKey: "completed_\(today)") as? [String] {
            updateCompletedPrayers(completed)
        }
    }

    private func setupPrayers() {
        // Initialize with default prayer times
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        // Default times (will be updated with actual API data)
        prayers = [
            Prayer(name: "Fajr", time: "5:35 AM", icon: "sunrise.fill", hasReminder: true, isCompleted: false),
            Prayer(name: "Sunrise", time: "7:02 AM", icon: "sun.max.fill", hasReminder: false, isCompleted: false),
            Prayer(name: "Dhuhr", time: "1:08 PM", icon: "sun.min.fill", hasReminder: true, isCompleted: false),
            Prayer(name: "Asr", time: "4:51 PM", icon: "sun.dust.fill", hasReminder: true, isCompleted: false),
            Prayer(name: "Maghrib", time: "7:42 PM", icon: "sunset.fill", hasReminder: true, isCompleted: false),
            Prayer(name: "Isha", time: "9:15 PM", icon: "moon.stars.fill", hasReminder: true, isCompleted: false)
        ]

        updatePrayerStates()
        fetchPrayerTimes()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTimeUntilNextPrayer()
            self.updatePrayerStates()
        }
    }

    // MARK: - Update Methods
    private func updatePrayerStates() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var foundCurrent = false
        var foundNext = false

        for (index, prayer) in prayers.enumerated() {
            // Parse prayer time
            if let prayerTime = formatter.date(from: prayer.time) {
                let calendar = Calendar.current
                var prayerComponents = calendar.dateComponents([.hour, .minute], from: prayerTime)
                prayerComponents.year = calendar.component(.year, from: now)
                prayerComponents.month = calendar.component(.month, from: now)
                prayerComponents.day = calendar.component(.day, from: now)

                if let prayerDate = calendar.date(from: prayerComponents) {
                    if prayerDate > now && !foundNext {
                        nextPrayer = prayer
                        foundNext = true
                    } else if prayerDate <= now && !foundNext {
                        currentPrayer = prayer
                        foundCurrent = true
                    }
                }
            }
        }

        // If no next prayer found today, next prayer is tomorrow's Fajr
        if !foundNext && prayers.count > 0 {
            nextPrayer = prayers[0]
        }

        updateProgressPercentage()
    }

    private func updateTimeUntilNextPrayer() {
        guard let next = nextPrayer else {
            timeUntilNextPrayer = "--:--:--"
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if let prayerTime = formatter.date(from: next.time) {
            let calendar = Calendar.current
            let now = Date()

            var prayerComponents = calendar.dateComponents([.hour, .minute], from: prayerTime)
            prayerComponents.year = calendar.component(.year, from: now)
            prayerComponents.month = calendar.component(.month, from: now)
            prayerComponents.day = calendar.component(.day, from: now)

            if var prayerDate = calendar.date(from: prayerComponents) {
                // If prayer time has passed today, it's tomorrow's prayer
                if prayerDate <= now {
                    prayerDate = calendar.date(byAdding: .day, value: 1, to: prayerDate) ?? prayerDate
                }

                let timeInterval = prayerDate.timeIntervalSince(now)
                timeUntilNextPrayer = timeInterval.formattedForCountdown
            }
        }
    }

    private func updateProgressPercentage() {
        let completed = prayers.filter { $0.isCompleted }.count
        completedPrayers = completed
        progressPercentage = CGFloat(completed) / CGFloat(totalPrayers)
    }

    private func updateCompletedPrayers(_ completedNames: [String]) {
        for i in 0..<prayers.count {
            prayers[i].isCompleted = completedNames.contains(prayers[i].name)
        }
        updateProgressPercentage()
    }

    // MARK: - Public Methods
    func refreshLocation() {
        locationManager.requestLocation()
    }

    func toggleReminder(for prayerName: String) {
        if let index = prayers.firstIndex(where: { $0.name == prayerName }) {
            prayers[index].hasReminder.toggle()
            // Save reminder preference
            UserDefaults.standard.set(prayers[index].hasReminder, forKey: "reminder_\(prayerName)")
        }
    }

    func togglePrayerCompletion(for prayerName: String) {
        if let index = prayers.firstIndex(where: { $0.name == prayerName }) {
            prayers[index].isCompleted.toggle()

            // Save completion status
            let today = dateKey(for: Date())
            var completed = UserDefaults.standard.array(forKey: "completed_\(today)") as? [String] ?? []

            if prayers[index].isCompleted {
                if !completed.contains(prayerName) {
                    completed.append(prayerName)
                }
            } else {
                completed.removeAll { $0 == prayerName }
            }

            UserDefaults.standard.set(completed, forKey: "completed_\(today)")
            updateProgressPercentage()
            updateStreaks()
        }
    }

    private func updateStreaks() {
        // Check if all prayers are completed today
        if completedPrayers == totalPrayers {
            // Update current streak
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            let yesterdayKey = dateKey(for: yesterday)
            let yesterdayCompleted = UserDefaults.standard.array(forKey: "completed_\(yesterdayKey)") as? [String] ?? []

            if yesterdayCompleted.count == totalPrayers {
                // Continue streak
                currentStreak += 1
            } else {
                // New streak
                currentStreak = 1
            }

            // Update best streak
            if currentStreak > bestStreak {
                bestStreak = currentStreak
                UserDefaults.standard.set(bestStreak, forKey: "bestPrayerStreak")
            }

            UserDefaults.standard.set(currentStreak, forKey: "currentPrayerStreak")
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - API Methods
    private func fetchPrayerTimes() {
        guard let location = currentLocation else { return }

        Task {
            do {
                let timings = try await prayerTimeService.fetchPrayerTimes(for: location)
                await MainActor.run {
                    self.updatePrayerTimesFromAPI(timings)
                }
            } catch {
                print("Error fetching prayer times: \(error)")
            }
        }
    }

    private func updatePrayerTimesFromAPI(_ timings: Timings) {
        // Convert 24-hour to 12-hour format
        let formatter24 = DateFormatter()
        formatter24.dateFormat = "HH:mm"

        let formatter12 = DateFormatter()
        formatter12.dateFormat = "h:mm a"

        // Update prayer times
        if let fajrTime = formatter24.date(from: timings.Fajr.components(separatedBy: " ")[0]),
           let dhuhrTime = formatter24.date(from: timings.Dhuhr.components(separatedBy: " ")[0]),
           let asrTime = formatter24.date(from: timings.Asr.components(separatedBy: " ")[0]),
           let maghribTime = formatter24.date(from: timings.Maghrib.components(separatedBy: " ")[0]),
           let ishaTime = formatter24.date(from: timings.Isha.components(separatedBy: " ")[0]) {

            // Calculate sunrise (approximately 90 minutes after Fajr)
            let sunriseTime = fajrTime.addingTimeInterval(90 * 60)

            prayers[0].time = formatter12.string(from: fajrTime)
            prayers[1].time = formatter12.string(from: sunriseTime)
            prayers[2].time = formatter12.string(from: dhuhrTime)
            prayers[3].time = formatter12.string(from: asrTime)
            prayers[4].time = formatter12.string(from: maghribTime)
            prayers[5].time = formatter12.string(from: ishaTime)

            updatePrayerStates()
        }
    }

    private func updateLocationInfo(from placemark: CLPlacemark) {
        cityName = placemark.locality ?? "Unknown City"
        stateName = placemark.administrativeArea ?? "Unknown State"
        countryName = placemark.country ?? "Unknown Country"

        // Save location info
        UserDefaults.standard.set(cityName, forKey: "savedCity")
        UserDefaults.standard.set(stateName, forKey: "savedState")
        UserDefaults.standard.set(countryName, forKey: "savedCountry")
    }
}

// MARK: - Location Manager Delegate
extension PrayerTimeViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        // Reverse geocode to get city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                self?.updateLocationInfo(from: placemark)
            }
        }

        // Fetch prayer times for new location
        fetchPrayerTimes()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
        // Use default location (Minneapolis)
    }
}

