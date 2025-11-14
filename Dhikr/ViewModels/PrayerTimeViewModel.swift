import SwiftUI
import CoreLocation
import Combine

class PrayerTimeViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var prayers: [Prayer] = []
    @Published var currentPrayer: Prayer?
    @Published var nextPrayer: Prayer?
    @Published var todaysNextPrayer: Prayer?
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
    @Published var selectedDate: Date = Date()
    @Published var isLoadingFuturePrayers: Bool = false
    @Published var isRefreshingLocation: Bool = false

    // MARK: - Computed Properties
    var locationName: String {
        return "\(cityName), \(stateName)"
    }

    var completedPrayersToday: Int {
        return completedPrayers
    }

    // MARK: - Private Properties
    private let locationService: LocationService
    private let prayerTimeService = PrayerTimeService()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var prayerTimes: Timings?
    private var todaysPrayers: [Prayer] = []

    // MARK: - Initialization
    init(locationService: LocationService) {
        self.locationService = locationService
        super.init()
        setupLocationObserver()
        loadSavedData()
        setupPrayers()
        startTimer()
        setupNotificationObserver()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Methods
    private func setupLocationObserver() {
        // Subscribe to location updates from shared LocationService
        locationService.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)

        // Request location if we don't have it yet
        if locationService.location == nil {
            locationService.requestLocation()
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        // Reverse geocode to get city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                self?.updateLocationInfo(from: placemark)
            }
            self?.isRefreshingLocation = false
        }

        // Fetch prayer times if we don't have cached data for today
        if !loadCachedPrayerTimes() {
            fetchPrayerTimesInBackground()
        }
    }

    private func loadSavedData() {
        // Load saved streak data
        currentStreak = UserDefaults.standard.integer(forKey: "currentPrayerStreak")
        bestStreak = UserDefaults.standard.integer(forKey: "bestPrayerStreak")

        // Check if streak should be reset (if yesterday wasn't completed)
        checkAndUpdateStreakStatus()

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

        // Note: Today's completed prayers are loaded in setupPrayers()
    }

    private func setupPrayers() {
        // Try to load cached prayer times first for faster startup
        if loadCachedPrayerTimes() {
            print("📱 Loaded cached prayer times for faster startup")
        } else {
            // Initialize with default prayer times if no cache
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
        }

        // Save initial prayers as today's prayers
        todaysPrayers = prayers

        // Load today's completed prayers and apply to both arrays
        let today = dateKey(for: Date())
        if let completed = UserDefaults.standard.array(forKey: "completed_\(today)") as? [String] {
            for i in 0..<prayers.count {
                let isCompleted = completed.contains(prayers[i].name)
                prayers[i].isCompleted = isCompleted
                todaysPrayers[i].isCompleted = isCompleted
            }
        }

        updatePrayerStates()

        // Fetch fresh prayer times in background after initial setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fetchPrayerTimesInBackground()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTimeUntilNextPrayer()
            self.updatePrayerStates()
        }
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PrayersCompletedUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadTodaysCompletions()
        }
    }

    func reloadCompletions() {
        let today = dateKey(for: Date())
        if let completed = UserDefaults.standard.array(forKey: "completed_\(today)") as? [String] {
            print("📥 Reloading prayer completions: \(completed)")
            // Update both today's prayers and current prayers if viewing today
            for i in 0..<todaysPrayers.count {
                let isCompleted = completed.contains(todaysPrayers[i].name)
                todaysPrayers[i].isCompleted = isCompleted

                // If we're viewing today, also update the current prayers array
                if Calendar.current.isDateInToday(selectedDate) && i < prayers.count {
                    prayers[i].isCompleted = isCompleted
                }
            }
            updateProgressPercentage()
        } else {
            print("📥 No completed prayers found for \(today)")
        }
    }

    private func reloadTodaysCompletions() {
        reloadCompletions()
    }

    // MARK: - Update Methods
    private func updatePrayerStates() {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        var foundCurrent = false
        var foundNext = false

        // Always work with today's prayers for current/next prayer logic
        let prayersToCheck = Calendar.current.isDateInToday(selectedDate) ? prayers : todaysPrayers

        for (index, prayer) in prayersToCheck.enumerated() {
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
                        todaysNextPrayer = prayer  // Always set today's next prayer
                        foundNext = true
                    } else if prayerDate <= now && !foundNext {
                        currentPrayer = prayer
                        foundCurrent = true
                    }
                }
            }
        }

        // If no next prayer found today, next prayer is tomorrow's Fajr
        if !foundNext && prayersToCheck.count > 0 {
            nextPrayer = prayersToCheck[0]
            todaysNextPrayer = todaysPrayers.count > 0 ? todaysPrayers[0] : prayersToCheck[0]
        }

        updateProgressPercentage()
    }

    private func updateTimeUntilNextPrayer() {
        guard let next = todaysNextPrayer else {
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
        // Only count obligatory prayers (exclude Sunrise)
        let obligatoryPrayers = prayers.filter { $0.name != "Sunrise" }
        let completed = obligatoryPrayers.filter { $0.isCompleted }.count
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
        isRefreshingLocation = true
        locationService.requestLocation()
    }

    func fetchPrayerTimes(for date: Date) {
        selectedDate = date

        if Calendar.current.isDateInToday(date) {
            // For today, restore today's prayers and update states
            prayers = todaysPrayers

            // Restore completion states for today
            let today = dateKey(for: Date())
            if let completed = UserDefaults.standard.array(forKey: "completed_\(today)") as? [String] {
                for i in 0..<prayers.count {
                    prayers[i].isCompleted = completed.contains(prayers[i].name)
                }
            }

            updatePrayerStates()
        } else {
            // For future/past dates, fetch specific prayer times
            fetchFuturePrayerTimes(for: date)
        }
    }

    private func fetchFuturePrayerTimes(for date: Date) {
        guard let location = locationService.location else { return }

        isLoadingFuturePrayers = true

        Task {
            do {
                let timings = try await prayerTimeService.fetchPrayerTimes(for: location, on: date)
                await MainActor.run {
                    self.updatePrayerTimesForDate(timings, date: date)
                    self.isLoadingFuturePrayers = false
                }
            } catch {
                await MainActor.run {
                    print("Error fetching future prayer times: \(error)")
                    self.isLoadingFuturePrayers = false
                }
            }
        }
    }

    private func updatePrayerTimesForDate(_ timings: Timings, date: Date) {
        // Convert 24-hour to 12-hour format
        let formatter24 = DateFormatter()
        formatter24.dateFormat = "HH:mm"

        let formatter12 = DateFormatter()
        formatter12.dateFormat = "h:mm a"

        // Update prayer times for selected date
        var updatedPrayers: [Prayer] = []

        if let fajrTime = formatter24.date(from: timings.Fajr.components(separatedBy: " ")[0]),
           let dhuhrTime = formatter24.date(from: timings.Dhuhr.components(separatedBy: " ")[0]),
           let asrTime = formatter24.date(from: timings.Asr.components(separatedBy: " ")[0]),
           let maghribTime = formatter24.date(from: timings.Maghrib.components(separatedBy: " ")[0]),
           let ishaTime = formatter24.date(from: timings.Isha.components(separatedBy: " ")[0]) {

            // Calculate sunrise (approximately 90 minutes after Fajr)
            let sunriseTime = fajrTime.addingTimeInterval(90 * 60)

            updatedPrayers = [
                Prayer(name: "Fajr", time: formatter12.string(from: fajrTime), icon: "sunrise.fill", hasReminder: true, isCompleted: false),
                Prayer(name: "Sunrise", time: formatter12.string(from: sunriseTime), icon: "sun.max.fill", hasReminder: false, isCompleted: false),
                Prayer(name: "Dhuhr", time: formatter12.string(from: dhuhrTime), icon: "sun.min.fill", hasReminder: true, isCompleted: false),
                Prayer(name: "Asr", time: formatter12.string(from: asrTime), icon: "sun.dust.fill", hasReminder: true, isCompleted: false),
                Prayer(name: "Maghrib", time: formatter12.string(from: maghribTime), icon: "sunset.fill", hasReminder: true, isCompleted: false),
                Prayer(name: "Isha", time: formatter12.string(from: ishaTime), icon: "moon.stars.fill", hasReminder: true, isCompleted: false)
            ]

            prayers = updatedPrayers

            // Load completion data for the selected date
            let dateKeyString = dateKey(for: date)
            if let completed = UserDefaults.standard.array(forKey: "completed_\(dateKeyString)") as? [String] {
                print("📖 Loaded prayer completions for \(dateKeyString): \(completed)")
                for i in 0..<prayers.count {
                    prayers[i].isCompleted = completed.contains(prayers[i].name)
                }
            }

            // For future dates, don't show current/next prayer for the selected date
            if !Calendar.current.isDateInToday(date) {
                currentPrayer = nil
                nextPrayer = nil
                // Keep today's next prayer and countdown intact
            } else {
                updatePrayerStates()
            }
        }
    }

    func toggleReminder(for prayerName: String) {
        if let index = prayers.firstIndex(where: { $0.name == prayerName }) {
            prayers[index].hasReminder.toggle()
            // Save reminder preference
            UserDefaults.standard.set(prayers[index].hasReminder, forKey: "reminder_\(prayerName)")
        }
    }

    func togglePrayerCompletion(for prayerName: String) {
        // Only allow toggling completion for today's prayers
        guard Calendar.current.isDateInToday(selectedDate) else {
            print("⚠️ Cannot mark prayers as completed for non-today dates")
            return
        }

        // Only allow toggling if prayer has passed or is currently active
        guard isPrayerPassed(prayerName) || prayerName == currentPrayer?.name else {
            print("⚠️ Cannot mark future prayers as completed")
            return
        }

        if let index = prayers.firstIndex(where: { $0.name == prayerName }) {
            prayers[index].isCompleted.toggle()

            // Update todaysPrayers
            if let todayIndex = todaysPrayers.firstIndex(where: { $0.name == prayerName }) {
                todaysPrayers[todayIndex].isCompleted = prayers[index].isCompleted
            }

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
            print("💾 Saved prayer completions for \(today): \(completed)")
            updateProgressPercentage()
            updateStreaks()
        }
    }

    func isPrayerPassed(_ prayerName: String) -> Bool {
        guard let prayer = prayers.first(where: { $0.name == prayerName }) else {
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        guard let prayerTime = formatter.date(from: prayer.time) else {
            return false
        }

        let calendar = Calendar.current
        let now = Date()

        var prayerComponents = calendar.dateComponents([.hour, .minute], from: prayerTime)
        prayerComponents.year = calendar.component(.year, from: now)
        prayerComponents.month = calendar.component(.month, from: now)
        prayerComponents.day = calendar.component(.day, from: now)

        guard let prayerDate = calendar.date(from: prayerComponents) else {
            return false
        }

        return prayerDate <= now
    }

    private func checkAndUpdateStreakStatus() {
        // Get yesterday's date
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayKey = dateKey(for: yesterday)
        let yesterdayCompleted = UserDefaults.standard.array(forKey: "completed_\(yesterdayKey)") as? [String] ?? []

        // Get the last streak update date
        let lastStreakUpdateKey = UserDefaults.standard.string(forKey: "lastStreakUpdateDate") ?? ""
        let todayKey = dateKey(for: Date())

        // If we haven't updated today, check if streak should continue
        if lastStreakUpdateKey != todayKey {
            // If yesterday wasn't completed fully, reset the streak
            if yesterdayCompleted.count < totalPrayers && currentStreak > 0 {
                currentStreak = 0
                UserDefaults.standard.set(currentStreak, forKey: "currentPrayerStreak")
            }
            // Save that we've checked the streak today
            UserDefaults.standard.set(todayKey, forKey: "lastStreakUpdateDate")
        }
    }

    private func updateStreaks() {
        // Check if all prayers are completed today
        if completedPrayers == totalPrayers {
            // Check if we already counted today in the streak
            let todayKey = dateKey(for: Date())
            let lastCountedDate = UserDefaults.standard.string(forKey: "lastStreakCountedDate") ?? ""

            if lastCountedDate != todayKey {
                // We haven't counted today yet
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let yesterdayKey = dateKey(for: yesterday)
                let yesterdayCompleted = UserDefaults.standard.array(forKey: "completed_\(yesterdayKey)") as? [String] ?? []

                if yesterdayCompleted.count == totalPrayers {
                    // Continue streak
                    currentStreak += 1
                } else {
                    // New streak starts today
                    currentStreak = 1
                }

                // Update best streak
                if currentStreak > bestStreak {
                    bestStreak = currentStreak
                    UserDefaults.standard.set(bestStreak, forKey: "bestPrayerStreak")
                }

                UserDefaults.standard.set(currentStreak, forKey: "currentPrayerStreak")
                UserDefaults.standard.set(todayKey, forKey: "lastStreakCountedDate")
            }
        }
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Caching Methods
    private func loadCachedPrayerTimes() -> Bool {
        let today = dateKey(for: Date())
        let cacheKey = "cachedPrayerTimes_\(today)"
        let locationCacheKey = "cachedLocation_\(today)"

        // Check if we have cached data for today
        guard let cachedData = UserDefaults.standard.data(forKey: cacheKey),
              let cachedLocation = UserDefaults.standard.data(forKey: locationCacheKey),
              let prayerTimes = try? JSONDecoder().decode([CachedPrayer].self, from: cachedData),
              let location = try? JSONDecoder().decode(CachedLocation.self, from: cachedLocation) else {
            return false
        }

        // Update location info from cache
        cityName = location.cityName
        stateName = location.stateName
        countryName = location.countryName

        // Convert cached prayers back to Prayer objects
        prayers = prayerTimes.map { cached in
            Prayer(name: cached.name, time: cached.time, icon: cached.icon, hasReminder: cached.hasReminder, isCompleted: false)
        }

        return true
    }

    private func cachePrayerTimes() {
        let today = dateKey(for: Date())
        let cacheKey = "cachedPrayerTimes_\(today)"
        let locationCacheKey = "cachedLocation_\(today)"

        // Cache prayer times
        let cachedPrayers = prayers.map { prayer in
            CachedPrayer(name: prayer.name, time: prayer.time, icon: prayer.icon, hasReminder: prayer.hasReminder)
        }

        // Cache location info
        let cachedLocation = CachedLocation(cityName: cityName, stateName: stateName, countryName: countryName)

        do {
            let prayerData = try JSONEncoder().encode(cachedPrayers)
            let locationData = try JSONEncoder().encode(cachedLocation)

            UserDefaults.standard.set(prayerData, forKey: cacheKey)
            UserDefaults.standard.set(locationData, forKey: locationCacheKey)

            print("📦 Cached prayer times for \(today)")
        } catch {
            print("❌ Failed to cache prayer times: \(error)")
        }
    }

    private func clearOldCache() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys

        // Remove cached data older than 3 days
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        for key in allKeys {
            if key.hasPrefix("cachedPrayerTimes_") || key.hasPrefix("cachedLocation_") {
                let dateString = String(key.dropFirst(key.contains("Prayer") ? 18 : 15)) // "cachedPrayerTimes_".count = 18, "cachedLocation_".count = 15
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"

                if let date = formatter.date(from: dateString), date < cutoffDate {
                    userDefaults.removeObject(forKey: key)
                }
            }
        }
    }

    // MARK: - API Methods
    private func fetchPrayerTimes() {
        guard let location = locationService.location else { return }

        Task {
            do {
                let timings = try await prayerTimeService.fetchPrayerTimes(for: location)
                await MainActor.run {
                    self.updatePrayerTimesFromAPI(timings)
                    self.cachePrayerTimes()
                    self.clearOldCache()
                }
            } catch {
                print("Error fetching prayer times: \(error)")
            }
        }
    }

    private func fetchPrayerTimesInBackground() {
        guard let location = locationService.location else {
            // If no location, try to get it first
            locationService.requestLocation()
            return
        }

        Task {
            do {
                let timings = try await prayerTimeService.fetchPrayerTimes(for: location)
                await MainActor.run {
                    // Only update if times are different (to avoid unnecessary UI updates)
                    let newTimes = self.convertTimingsToStringArray(timings)
                    let currentTimes = self.prayers.map { $0.time }

                    if newTimes != currentTimes {
                        print("🔄 Updated prayer times in background")
                        self.updatePrayerTimesFromAPI(timings)
                        self.cachePrayerTimes()
                    } else {
                        print("✅ Prayer times are up to date")
                    }
                    self.clearOldCache()
                }
            } catch {
                print("Error fetching prayer times in background: \(error)")
            }
        }
    }

    private func convertTimingsToStringArray(_ timings: Timings) -> [String] {
        let formatter24 = DateFormatter()
        formatter24.dateFormat = "HH:mm"
        let formatter12 = DateFormatter()
        formatter12.dateFormat = "h:mm a"

        var times: [String] = []

        if let fajrTime = formatter24.date(from: timings.Fajr.components(separatedBy: " ")[0]),
           let dhuhrTime = formatter24.date(from: timings.Dhuhr.components(separatedBy: " ")[0]),
           let asrTime = formatter24.date(from: timings.Asr.components(separatedBy: " ")[0]),
           let maghribTime = formatter24.date(from: timings.Maghrib.components(separatedBy: " ")[0]),
           let ishaTime = formatter24.date(from: timings.Isha.components(separatedBy: " ")[0]) {

            let sunriseTime = fajrTime.addingTimeInterval(90 * 60)

            times = [
                formatter12.string(from: fajrTime),
                formatter12.string(from: sunriseTime),
                formatter12.string(from: dhuhrTime),
                formatter12.string(from: asrTime),
                formatter12.string(from: maghribTime),
                formatter12.string(from: ishaTime)
            ]
        }

        return times
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

            // Save today's prayers
            todaysPrayers = prayers

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

// MARK: - Cache Data Structures
struct CachedPrayer: Codable {
    let name: String
    let time: String
    let icon: String
    let hasReminder: Bool
}

struct CachedLocation: Codable {
    let cityName: String
    let stateName: String
    let countryName: String
}
