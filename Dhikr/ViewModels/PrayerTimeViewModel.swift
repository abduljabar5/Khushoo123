import Foundation
import CoreLocation
import Combine
import SwiftUI

// A model representing a single prayer time, making it easier to work with.
struct PrayerTime: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let date: Date
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@MainActor
class PrayerTimeViewModel: ObservableObject {
    
    // Represents the two main states of the prayer time screen
    enum DisplayState {
        case countingDownToNext
        case withinCurrentPrayer
    }
    
    // MARK: - Published Properties for UI
    @Published var prayerTimes: [PrayerTime] = []
    @Published var nextPrayer: PrayerTime?
    @Published var currentPrayer: PrayerTime?
    @Published var timeValue: TimeInterval = 0 // Can be time *until* or time *since* a prayer
    @Published var displayState: DisplayState = .countingDownToNext
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus

    // Animation-driving properties
    @Published var glowOpacity: Double = 0.0
    @Published var glowScale: CGFloat = 1.0
    @Published var glowColor: Color = .green
    @Published var countdownColor: Color = .white
    
    // MARK: - Private Properties
    private let locationService = LocationService()
    private let prayerTimeService = PrayerTimeService()
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    init() {
        self.locationAuthorizationStatus = locationService.authorizationStatus
        
        print("🕌 [PrayerTimeViewModel] Initialized. Current location auth status: \(locationAuthorizationStatus.rawValue)")
        
        // Subscribe to authorization status changes
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthorizationStatus = status
            }
            .store(in: &cancellables)
    }
    
    deinit {
        updateTimer?.invalidate()
    }

    func start() {
        print("🕌 [PrayerTimeViewModel] Start method called.")
        // This is now the entry point to begin the process.
        // It's called from the view's onAppear.
        locationService.$location
            .compactMap { $0 }
            .first() // We only need the first location update.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                print("🕌 [PrayerTimeViewModel] Received location update. Fetching prayer times.")
                self?.fetchAllRequiredPrayerTimes(for: location)
            }
            .store(in: &cancellables)

        // Check the current authorization status to decide the next action.
        print("🕌 [PrayerTimeViewModel] Checking auth status in start(): \(locationService.authorizationStatus.rawValue)")
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission is already granted, just request the location.
            print("🕌 [PrayerTimeViewModel] Status: Authorized. Requesting location.")
            locationService.requestLocation()
        case .notDetermined:
            // Permission has not been asked for yet.
            print("🕌 [PrayerTimeViewModel] Status: Not Determined. Requesting permission.")
            locationService.requestLocationPermission()
        case .denied, .restricted:
            // Permission has been denied. Show an error message.
            print("🕌 [PrayerTimeViewModel] Status: Denied/Restricted. Showing error.")
            errorMessage = "Location permission is required to show prayer times. Please enable it in Settings."
        @unknown default:
            // Handle any future cases.
            print("🕌 [PrayerTimeViewModel] Status: Unknown. Requesting permission.")
            locationService.requestLocationPermission()
        }
    }
    
    func requestLocationPermission() {
        locationService.requestLocationPermission()
    }
    
    /// Fetches prayer times for today and tomorrow to ensure a continuous list.
    private func fetchAllRequiredPrayerTimes(for location: CLLocation) {
        isLoading = true
        errorMessage = nil
        print("🕌 [PrayerTimeViewModel] Fetching all required prayer times for location: \(location.coordinate)")
        
        Task {
            do {
                // Try cache first (once per day per approx location)
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                    let cachedDay = groupDefaults.object(forKey: "PrayerTimesCacheFetchedDay") as? TimeInterval
                    let cachedLat = groupDefaults.object(forKey: "PrayerTimesCacheLat") as? Double
                    let cachedLon = groupDefaults.object(forKey: "PrayerTimesCacheLon") as? Double
                    let tolerance = 0.02 // ~2 km
                    if let cachedDay = cachedDay,
                       let cachedLat = cachedLat,
                       let cachedLon = cachedLon,
                       abs(cachedLat - location.coordinate.latitude) <= tolerance,
                       abs(cachedLon - location.coordinate.longitude) <= tolerance,
                       cachedDay == todayStart,
                       let cachedArray = groupDefaults.object(forKey: "PrayerTimesCacheArray") as? [[String: Any]] {
                        let cached: [PrayerTime] = cachedArray.compactMap { dict in
                            guard let name = dict["name"] as? String,
                                  let ts = dict["date"] as? TimeInterval else { return nil }
                            return PrayerTime(name: name, date: Date(timeIntervalSince1970: ts))
                        }
                        if !cached.isEmpty {
                            await MainActor.run { self.prayerTimes = cached }
                            print("✅ [PrayerTimeViewModel] Loaded prayer times from cache")
                            // Kick off scheduling and timer as usual
                            Task.detached { await self.schedulePrayerBlocking() }
                            self.startUpdateTimer()
                            isLoading = false
                            return
                        }
                    }
                }
                
                // Fetch prayer times for 5 days to ensure we have enough for 20 prayers
                var allPrayerTimes: [PrayerTime] = []
                let today = Date()
                
                for dayOffset in 0..<5 {
                    guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: today) else {
                        continue
                    }
                    
                    let timings = try await prayerTimeService.fetchPrayerTimes(for: location, on: targetDate)
                    let parsedTimes = parse(timings: timings, for: targetDate)
                    allPrayerTimes.append(contentsOf: parsedTimes)
                }
                
                // Store all prayer times on main thread
                await MainActor.run {
                    self.prayerTimes = allPrayerTimes
                }
                
                // Log fetched prayer times
                print("✅ [PrayerTimeViewModel] Fetched \(self.prayerTimes.count) real prayer times from API (5 days)")
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                
                // Show all prayer times, grouped by day
                let calendar = Calendar.current
                var currentDay: Date?
                
                for prayer in self.prayerTimes {
                    let prayerDay = calendar.startOfDay(for: prayer.date)
                    
                    // Print day header when we start a new day
                    if currentDay != prayerDay {
                        currentDay = prayerDay
                        let dayFormatter = DateFormatter()
                        dayFormatter.dateStyle = .medium
                        print("   📆 \(dayFormatter.string(from: prayerDay)):")
                    }
                    
                    print("      📅 \(prayer.name) at \(formatter.string(from: prayer.date))")
                }
                
                // Automatically schedule prayer blocking on app launch (background task)
                Task.detached {
                    await self.schedulePrayerBlocking()
                }
                
                // Start the timer to update the UI every second.
                self.startUpdateTimer()
                
                // Save cache for the day and approximate location
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    let cacheArray = self.prayerTimes.map { [
                        "name": $0.name,
                        "date": $0.date.timeIntervalSince1970
                    ] }
                    groupDefaults.set(cacheArray, forKey: "PrayerTimesCacheArray")
                    groupDefaults.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: "PrayerTimesCacheFetchedDay")
                    groupDefaults.set(location.coordinate.latitude, forKey: "PrayerTimesCacheLat")
                    groupDefaults.set(location.coordinate.longitude, forKey: "PrayerTimesCacheLon")
                }
            } catch {
                self.errorMessage = "Failed to fetch prayer times: \(error.localizedDescription)"
                print("❌ [PrayerTimeViewModel] Error fetching prayer times: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updatePrayerState() // Run once immediately to set the initial state
        // Reduced frequency for better performance - every 30 seconds instead of every second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                self?.updatePrayerState()
            }
        }
    }

    private func updatePrayerState() {
        let now = Date()
        
        let lastPrayer = prayerTimes.last { $0.date <= now }
        let upcomingPrayer = prayerTimes.first { $0.date > now }
        self.nextPrayer = upcomingPrayer

        if let last = lastPrayer, now.timeIntervalSince(last.date) < 3600 {
            // STATE: Within the current prayer's active one-hour window.
            self.displayState = .withinCurrentPrayer
            self.currentPrayer = last
            self.timeValue = now.timeIntervalSince(last.date)
            updateWithinPrayerAnimation()
        } else {
            // STATE: Counting down to the next prayer.
            self.displayState = .countingDownToNext
            self.currentPrayer = nil
            
            if let next = upcomingPrayer {
                self.timeValue = next.date.timeIntervalSince(now)
                updateCountdownAnimation()
            } else {
                // This case should now only happen if the full 2-day fetch fails.
                timeValue = 0
            }
        }
    }

    private func updateCountdownAnimation() {
        let remaining = timeValue
        glowColor = .green

        if remaining <= 600 { // Under 10 minutes
            glowOpacity = 0.7
            glowScale = 1.05
        } else if remaining <= 1800 { // Under 30 minutes
            glowOpacity = 0.4
            glowScale = 1.02
        } else { // More than 30 minutes
            glowOpacity = 0.0 // Starts with no glow
            glowScale = 1.0
        }
        countdownColor = .white
    }
    
    private func updateWithinPrayerAnimation() {
        let timeSince = timeValue
        let progress = min(timeSince / 3600, 1.0)
        
        let redValue = min(progress * 2, 1.0)
        let greenValue = 1.0 - (max(progress - 0.5, 0.0) * 2)
        
        glowColor = Color(red: redValue, green: greenValue, blue: 0)
        glowOpacity = 1.0 - (progress * 0.7)
        glowScale = 1.0
        countdownColor = glowColor
    }
    
    private func parse(timings: Timings, for date: Date) -> [PrayerTime] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        let dayOfPrayer = calendar.startOfDay(for: date)
        
        var parsedTimes: [PrayerTime] = []
        let prayerData: [(String, String)] = [
            ("Fajr", timings.Fajr),
            ("Dhuhr", timings.Dhuhr),
            ("Asr", timings.Asr),
            ("Maghrib", timings.Maghrib),
            ("Isha", timings.Isha)
        ]
        
        for (name, timeString) in prayerData {
            if let time = dateFormatter.date(from: timeString),
               let timeComponents = calendar.dateComponents([.hour, .minute], from: time) as DateComponents?,
               let prayerDate = calendar.date(byAdding: timeComponents, to: dayOfPrayer) {
                parsedTimes.append(PrayerTime(name: name, date: prayerDate))
            }
        }
        return parsedTimes.sorted { $0.date < $1.date }
    }
    
    // Schedule prayer blocking automatically on app launch
    private func schedulePrayerBlocking() async {
        // First request Screen Time authorization if needed
        do {
            try await ScreenTimeAuthorizationService.shared.requestAuthorizationIfNeeded()
        } catch {
            print("❌ Screen Time authorization failed: \(error.localizedDescription)")
            return
        }
        
        // Get user settings
        let selectedPrayers = getSelectedPrayers()
        let blockingDuration = getBlockingDuration()
        
        guard !selectedPrayers.isEmpty else {
            return
        }
        
        // Filter to future prayers only and limit to 20
        let now = Date()
        let futurePrayers = prayerTimes.filter { $0.date > now }
        let selectedPrayerTimes = Array(futurePrayers.filter { selectedPrayers.contains($0.name) }.prefix(20))
        
        guard !selectedPrayerTimes.isEmpty else {
            return
        }
        
        // Save schedule and schedule in DeviceActivity
        saveScheduleToUserDefaults(selectedPrayerTimes, duration: blockingDuration)
        
        // Schedule with DeviceActivityService on main actor to avoid threading issues
        await MainActor.run {
            let deviceActivityService = DeviceActivityService.shared
            deviceActivityService.schedulePrayerTimeBlocking(
                prayerTimes: selectedPrayerTimes,
                duration: blockingDuration,
                selectedPrayers: selectedPrayers
            )
        }
    }
    
    // Get selected prayers from settings
    private func getSelectedPrayers() -> Set<String> {
        var selectedPrayers: Set<String> = []
        
        // Check both App Group and standard UserDefaults
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        
        // Read prayer selections with proper defaults (same as SearchView UI)
        let selectedFajr = groupDefaults?.object(forKey: "focusSelectedFajr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedFajr") as? Bool ?? true
        let selectedDhuhr = groupDefaults?.object(forKey: "focusSelectedDhuhr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedDhuhr") as? Bool ?? true
        let selectedAsr = groupDefaults?.object(forKey: "focusSelectedAsr") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedAsr") as? Bool ?? true
        let selectedMaghrib = groupDefaults?.object(forKey: "focusSelectedMaghrib") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedMaghrib") as? Bool ?? true
        let selectedIsha = groupDefaults?.object(forKey: "focusSelectedIsha") as? Bool ?? UserDefaults.standard.object(forKey: "focusSelectedIsha") as? Bool ?? true
        
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }
        
        return selectedPrayers
    }
    
    // Get blocking duration from settings
    private func getBlockingDuration() -> Double {
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        // Read duration with proper default (same as SearchView UI)
        let raw = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? UserDefaults.standard.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
        // Clamp to 15..60 in 5-min steps
        let clamped = min(60, max(15, round(raw / 5) * 5))
        return clamped
    }
    
    // Save prayer schedule for cleanup tracking
    private func saveScheduleToUserDefaults(_ prayerTimes: [PrayerTime], duration: Double) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let schedules = prayerTimes.map { prayer -> [String: Any] in
            let durationSeconds = duration * 60
            return [
                "name": prayer.name,
                "date": prayer.date.timeIntervalSince1970,
                "duration": durationSeconds
            ]
        }
        
        groupDefaults.set(schedules, forKey: "PrayerTimeSchedules")
    }
} 