//
//  SearchView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings
import CoreLocation
import Combine

struct SearchView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var screenTimeAuth: ScreenTimeAuthorizationService
    @State private var showingFullScreenPlayer = false
    @State private var isBlocking = false
    @State private var showingAppPicker = false
    @State private var appSelection = FamilyActivitySelection()
    
    // Prayer time data
    @State private var prayerTimes: [PrayerTime] = []
    @State private var isLoadingPrayerTimes = false
    @State private var prayerTimesError: String?
    @State private var lastPrayerTimeFetch: Date?
    @State private var hasInitializedSettings = false
    @State private var reschedulingTimer: Timer?
    
    // Persistent flag to track if we've ever scheduled blocking (survives app restarts)
    private var hasScheduledInitialBlocking: Bool {
        UserDefaults.standard.bool(forKey: "hasScheduledInitialBlocking")
    }
    
    // Settings that trigger activity monitor updates (persisted)
    @AppStorage("focusSelectedFajr") private var selectedFajr = true
    @AppStorage("focusSelectedDhuhr") private var selectedDhuhr = true
    @AppStorage("focusSelectedAsr") private var selectedAsr = true
    @AppStorage("focusSelectedMaghrib") private var selectedMaghrib = true
    @AppStorage("focusSelectedIsha") private var selectedIsha = true
    
    private var selectedPrayers: Set<String> {
        var prayers: Set<String> = []
        if selectedFajr { prayers.insert("Fajr") }
        if selectedDhuhr { prayers.insert("Dhuhr") }
        if selectedAsr { prayers.insert("Asr") }
        if selectedMaghrib { prayers.insert("Maghrib") }
        if selectedIsha { prayers.insert("Isha") }
        return prayers
    }
    
    @AppStorage("focusBlockingDuration") private var blockingDuration: Double = 15
    
    @AppStorage("focusStrictMode") private var strictMode = false
    
    // Other UI settings (don't trigger updates)
    @State private var useCustomDuration = false
    @State private var prePrayerNotification = true
    @State private var allowEmergencyCalls = true
    @State private var showingUnlockConfirmation = false
    
    // Services
    private let locationService = LocationService()
    private let prayerTimeService = PrayerTimeService()
    @StateObject private var blockingStateService = BlockingStateService.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        
        ZStack {
            Color(red: 28/255, green: 28/255, blue: 30/255).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    HeaderImageView()
                    
                    VStack(alignment: .leading, spacing: 24) {
                        // Voice confirmation section (appears when blocking is active in strict mode)
                        VoiceConfirmationView(blockingState: blockingStateService)
                        
                        // Early unlock section (strict mode off)
                        EarlyUnlockInlineSection()
                        
                        TodaysBlockingScheduleView(
                            prayerTimes: prayerTimes,
                            duration: blockingDuration,
                            selectedPrayers: selectedPrayers,
                            isLoading: isLoadingPrayerTimes,
                            error: prayerTimesError
                        )
                        
                        SelectPrayersView(
                            selectedFajr: $selectedFajr,
                            selectedDhuhr: $selectedDhuhr,
                            selectedAsr: $selectedAsr,
                            selectedMaghrib: $selectedMaghrib,
                            selectedIsha: $selectedIsha
                        )
                        
                        BlockingDurationView(
                            duration: $blockingDuration, 
                            useCustom: $useCustomDuration
                        )
                        
                        SelectAppsToBlockView {
                            Task {
                                do {
                                    try await screenTimeAuth.requestAuthorizationIfNeeded()
                                    await MainActor.run {
                                        showingAppPicker = true
                                    }
                                } catch {
                                    // Silenced repeated auth error log
                                }
                            }
                        }
                        
                        // Screen Time authorization status
                        if screenTimeAuth.authorizationStatus == .denied {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Screen Time Access Required")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                    Text("Enable Screen Time access in Settings to use prayer blocking")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        AdditionalSettingsView(
                            strictMode: $strictMode,
                            prePrayerNotification: $prePrayerNotification,
                            allowEmergencyCalls: $allowEmergencyCalls,
                            showingConfirmationSheet: $showingUnlockConfirmation,
                            onRefreshSchedule: refreshPrayerSchedule
                        )
                        
                        TestBlockingView(
                            isBlocking: $isBlocking,
                            onBlockTapped: handleBlockButtonTap,
                            onForceUpdateSchedule: {
                                performScheduleUpdate()
                            }
                        )
                        

                    }
                    .padding(.horizontal)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onChange(of: blockingDuration) { _ in
            // Clamp to 15..60 in 5-min steps
            let clamped = min(60, max(15, round(blockingDuration / 5) * 5))
            if clamped != blockingDuration {
                blockingDuration = clamped
            }
            scheduleUpdate()
        }
        .onChange(of: selectedPrayers) { _ in
            scheduleUpdate()
        }
        .onChange(of: strictMode) { newValue in
            // Sync strict mode immediately to App Group
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(newValue, forKey: "focusStrictMode")
            }
            // Do not interrupt current block; update future schedule only
            performScheduleUpdate()
        }
        .foregroundColor(.white)

        .sheet(isPresented: $showingAppPicker) {
            if #available(iOS 15.0, *) {
        NavigationView {
                    AppPickerView()
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
        .sheet(isPresented: $showingUnlockConfirmation) {
            SpeechConfirmationView(isPresented: $showingUnlockConfirmation) {
                // Mock success action
            } onCancel: {
                // Mock cancel action
            }
                }
        .onAppear {
            // Clamp any previously persisted value
            let clamped = min(60, max(15, round(blockingDuration / 5) * 5))
            if clamped != blockingDuration {
                blockingDuration = clamped
            }
            
            // Removed per-second forceCheck to reduce I/O; UI sections manage their own lightweight ticks

            // Check Screen Time authorization status
            screenTimeAuth.updateAuthorizationStatus()
            
            fetchPrayerTimesIfNeeded()
            
            // Sync settings to UserDefaults after initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Mark as initialized first to prevent triggering updates
                hasInitializedSettings = true
                
                // Sync current settings to UserDefaults
                let defaults = UserDefaults.standard
                defaults.set(selectedFajr, forKey: "focusSelectedFajr")
                defaults.set(selectedDhuhr, forKey: "focusSelectedDhuhr")
                defaults.set(selectedAsr, forKey: "focusSelectedAsr")
                defaults.set(selectedMaghrib, forKey: "focusSelectedMaghrib")
                defaults.set(selectedIsha, forKey: "focusSelectedIsha")
                defaults.set(blockingDuration, forKey: "focusBlockingDuration")
                
                // Sync strict mode to App Group
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(strictMode, forKey: "focusStrictMode")
                }
            }
        }
        
    }
    
    // MARK: - Private Methods
    
    private func refreshPrayerSchedule() {
        // Clear and refetch prayer times
        lastPrayerTimeFetch = nil
        prayerTimes = []
        fetchPrayerTimesIfNeeded()
        
        // Schedule update will happen after fetch completes
    }
    
    
    // Save prayer schedule for cleanup tracking
    private func saveScheduleToUserDefaults(_ prayerTimes: [PrayerTime]) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let schedules = prayerTimes.map { prayer -> [String: Any] in
            let durationSeconds = blockingDuration * 60
            return [
                "name": prayer.name,
                "date": prayer.date.timeIntervalSince1970,
                "duration": durationSeconds
            ]
        }
        
        groupDefaults.set(schedules, forKey: "PrayerTimeSchedules")
        groupDefaults.set(Date().timeIntervalSince1970, forKey: "PrayerTimeSchedulesVersion")
    }
    
    private func fetchPrayerTimesIfNeeded() {
        // Check if we need to fetch prayer times
        let now = Date()
        
        // Only fetch if:
        // 1. We don't have any prayer times, OR
        // 2. It's been more than 12 hours since last fetch, OR  
        // 3. We have an error and no prayer times
        let shouldFetch = prayerTimes.isEmpty || 
                         (lastPrayerTimeFetch == nil) ||
                         (lastPrayerTimeFetch != nil && now.timeIntervalSince(lastPrayerTimeFetch!) > 12 * 3600) ||
                         (prayerTimesError != nil && prayerTimes.isEmpty)
        
        if shouldFetch {
            fetchPrayerTimes()
        }
    }
    
    private func fetchPrayerTimes() {
        isLoadingPrayerTimes = true
        prayerTimesError = nil
        
        // Check location authorization
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationAndFetchPrayerTimes()
        case .notDetermined:
            locationService.requestLocationPermission()
            // Wait for permission response
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways {
                    requestLocationAndFetchPrayerTimes()
                } else {
                    prayerTimesError = "Location permission required for prayer times"
                    isLoadingPrayerTimes = false
                }
            }
        case .denied, .restricted:
            prayerTimesError = "Location permission denied. Enable in Settings to show prayer times."
            isLoadingPrayerTimes = false
        @unknown default:
            prayerTimesError = "Location permission issue"
            isLoadingPrayerTimes = false
        }
    }
    
    private func requestLocationAndFetchPrayerTimes() {
        // Check if location is already available
        if let location = locationService.location {
            fetchPrayerTimesForLocation(location)
            return
        }
        
        // Subscribe to location updates (similar to PrayerTimeViewModel)
        locationService.$location
            .compactMap { $0 }
            .first() // We only need the first location update
            .receive(on: DispatchQueue.main)
            .sink { location in
                self.fetchPrayerTimesForLocation(location)
            }
            .store(in: &cancellables)
        
        // Request the location
        locationService.requestLocation()
        
        // Set a timeout to show error if location doesn't come within reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.prayerTimes.isEmpty && self.isLoadingPrayerTimes {
                self.prayerTimesError = "Location request timed out. Please check location permissions."
                self.isLoadingPrayerTimes = false
            }
        }
    }
    
    private func fetchPrayerTimesForLocation(_ location: CLLocation) {
        Task {
            do {
                // Try cache first (once per day per approx location)
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    let todayStart = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                    let cachedDay = groupDefaults.object(forKey: "PrayerTimesCacheFetchedDay") as? TimeInterval
                    let cachedLat = groupDefaults.object(forKey: "PrayerTimesCacheLat") as? Double
                    let cachedLon = groupDefaults.object(forKey: "PrayerTimesCacheLon") as? Double
                    let locationTolerance = 0.02 // ~2 km tolerance
                    if let cachedDay = cachedDay,
                       let cachedLat = cachedLat,
                       let cachedLon = cachedLon,
                       abs(cachedLat - location.coordinate.latitude) <= locationTolerance,
                       abs(cachedLon - location.coordinate.longitude) <= locationTolerance,
                       cachedDay == todayStart,
                       let cachedArray = groupDefaults.object(forKey: "PrayerTimesCacheArray") as? [[String: Any]] {
                        let cached: [PrayerTime] = cachedArray.compactMap { dict in
                            guard let name = dict["name"] as? String,
                                  let ts = dict["date"] as? TimeInterval else { return nil }
                            return PrayerTime(name: name, date: Date(timeIntervalSince1970: ts))
                        }
                        if !cached.isEmpty {
                            await MainActor.run {
                                self.prayerTimes = cached
                                self.isLoadingPrayerTimes = false
                                self.prayerTimesError = nil
                                self.lastPrayerTimeFetch = Date()
                                // After cache load, schedule update if settings initialized
                                if self.hasInitializedSettings {
                                    self.performScheduleUpdate()
                                }
                            }
                            return
                        }
                    }
                }
                
                var allPrayerTimes: [PrayerTime] = []
                let today = Date()
                
                // Fetch prayer times for 5 days (today + 4 more days) to ensure we have 20 future prayers
                for dayOffset in 0..<5 {
                    guard let targetDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: today) else {
                        continue
                    }
                    
                    let timings = try await prayerTimeService.fetchPrayerTimes(for: location, on: targetDate)
                    let parsedTimes = parsePrayerTimes(timings: timings, for: targetDate)
                    allPrayerTimes.append(contentsOf: parsedTimes)
                }
                
                await MainActor.run {
                    self.prayerTimes = allPrayerTimes
                    self.isLoadingPrayerTimes = false
                    self.prayerTimesError = nil
                    self.lastPrayerTimeFetch = Date()
                    
                    // Only schedule if settings are initialized (not on first load)
                    if self.hasInitializedSettings {
                        self.performScheduleUpdate()
                    }
                }
                
                // Save cache (once per day per approx location)
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    let cacheArray = allPrayerTimes.map { [
                        "name": $0.name,
                        "date": $0.date.timeIntervalSince1970
                    ] }
                    groupDefaults.set(cacheArray, forKey: "PrayerTimesCacheArray")
                    groupDefaults.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: "PrayerTimesCacheFetchedDay")
                    groupDefaults.set(location.coordinate.latitude, forKey: "PrayerTimesCacheLat")
                    groupDefaults.set(location.coordinate.longitude, forKey: "PrayerTimesCacheLon")
                }
                
            } catch {
                await MainActor.run {
                    self.prayerTimesError = "Failed to fetch prayer times: \(error.localizedDescription)"
                    self.isLoadingPrayerTimes = false
                }
            }
        }
    }
    
    private func parsePrayerTimes(timings: Timings, for date: Date) -> [PrayerTime] {
        let prayerNames = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        let timeStrings = [timings.Fajr, timings.Dhuhr, timings.Asr, timings.Maghrib, timings.Isha]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        let calendar = Calendar.current
        var prayerTimes: [PrayerTime] = []
        
        for (index, timeString) in timeStrings.enumerated() {
            // Remove timezone info if present (e.g., "05:30 (EST)" -> "05:30")
            let cleanTimeString = timeString.components(separatedBy: " ").first ?? timeString
            
            if let time = dateFormatter.date(from: cleanTimeString) {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                if let prayerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                minute: timeComponents.minute ?? 0,
                                                second: 0,
                                                of: date) {
                    prayerTimes.append(PrayerTime(name: prayerNames[index], date: prayerDate))
                }
            }
        }
        
        return prayerTimes
    }
    
    private func scheduleUpdate() {
        // Ignore updates until settings are initialized
        guard hasInitializedSettings, !prayerTimes.isEmpty else { return }
        
        // Cancel any existing timer to debounce rapid changes
        reschedulingTimer?.invalidate()
        
        // Schedule update with 0.5 second delay to batch multiple changes
        reschedulingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.performScheduleUpdate()
        }
    }
    
    private func performScheduleUpdate() {
        // Silenced periodic schedule update log
        
        // IMPORTANT: Do not interrupt current blocking. Only clean past and add new future entries up to 20.
        DeviceActivityService.shared.schedulePrayerTimeBlocking(
            prayerTimes: prayerTimes,
            duration: blockingDuration,
            selectedPrayers: selectedPrayers
        )
        
        // Save filtered schedule for tracking
        let filteredPrayerTimes = prayerTimes.filter { selectedPrayers.contains($0.name) }
        saveScheduleToUserDefaults(filteredPrayerTimes)
    }
    
    private func handleBlockButtonTap() {
        if isBlocking {
            // If already blocking, stop it. This is a quick operation.
            DeviceActivityService.shared.stopBlocking()
            self.isBlocking = false
        } else {
            // If not blocking, request permission and start.
            // Use a MainActor task to orchestrate UI and background work safely.
            Task { @MainActor in
                do {
                    try await screenTimeAuth.requestAuthorizationIfNeeded()
                    
                    self.isBlocking = true
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        DeviceActivityService.shared.scheduleBlocking(for: 900) // 900 seconds = 15 minutes
                    }
                } catch {
                    // Handle authorization error on the main thread.
                }
            }
        }
    }
}
// MARK: - Early Unlock Inline Section (Focus page)
private struct EarlyUnlockInlineSection: View {
    @StateObject private var blocking = BlockingStateService.shared
    @State private var refreshTimer: Timer?
    
    var body: some View {
        Group {
            // Show only when strict mode is OFF and apps are actually blocked
            if !blocking.isStrictModeEnabled && blocking.appsActuallyBlocked {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill").foregroundColor(.orange)
                        Text("Early Unlock")
                            .font(.headline)
                    }
                    .padding(.bottom, 2)
                    
                    let remaining = blocking.timeUntilEarlyUnlock()
                    if remaining > 0 {
                        Text("Available in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(remaining.formattedForCountdown)
                            .font(.title3).monospacedDigit()
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("You can unlock apps early now.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            // SIMPLIFIED: Clear restrictions and update flag directly
                            let store = ManagedSettingsStore()
                            store.clearAllSettings()
                            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                                groupDefaults.set(false, forKey: "appsActuallyBlocked")
                            }
                            // Silenced manual unlock log
                        }) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Unlock Apps Now")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(12)
                    .onAppear {
                    // Start a timer to keep the UI updated while this section is visible
                    refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                        // The @StateObject will automatically update the UI when properties change
                        blocking.forceCheck()
                    }
                }
                .onDisappear {
                    refreshTimer?.invalidate()
                    refreshTimer = nil
                }
            }
        }
    }
}

// MARK: - UI Components

private struct UnlockSectionView: View {
    let timeRemaining: TimeInterval
    var onUnlockTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Strict Mode Active", icon: "lock.fill")
            
            VStack(spacing: 16) {
                Text(timeRemaining > 0 ? "Apps are currently blocked. You may unlock them with voice confirmation after the blocking duration ends." : "Blocking duration has ended. You may now unlock your apps.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if timeRemaining > 0 {
                    HStack {
                        Text("Time remaining:")
                            .fontWeight(.medium)
                        Spacer()
                        Text(timeRemaining.formattedForCountdown)
                            .font(.headline.monospacedDigit())
                            .foregroundColor(.orange)
                    }
                }
                
                Button(action: onUnlockTapped) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Unlock with Voice Confirmation")
                    }
                    .font(.headline.bold())
                    .foregroundColor(timeRemaining > 0 ? .white.opacity(0.5) : .white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(timeRemaining > 0 ? Color.gray : Color.orange)
                    .cornerRadius(12)
                }
                .disabled(timeRemaining > 0)
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct HeaderImageView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Using a gradient background since we don't have the mosque image
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 250)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.8), .black.opacity(0.6), .clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            
            VStack(alignment: .center, spacing: 4) {
                Text("Prayer Time App Blocking")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Stay focused during your prayers")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(height: 250)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
    }
}

private struct TodaysBlockingScheduleView: View {
    let prayerTimes: [PrayerTime]
    let duration: Double
    let selectedPrayers: Set<String>
    let isLoading: Bool
    let error: String?
    
    private var todayPrayers: [PrayerTime] {
        let today = Date()
        return prayerTimes.filter { prayer in
            Calendar.current.isDate(prayer.date, inSameDayAs: today)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Blocking Schedule", icon: "calendar")
            
            VStack(spacing: 8) {
                HStack {
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if selectedPrayers.count == 5 {
                        Text("All prayers active")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    } else {
                        Text("\(selectedPrayers.count) of 5 prayers active")
                            .font(.caption.bold())
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading prayer times...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                } else if todayPrayers.isEmpty {
                    Text("No prayer times available for today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(todayPrayers) { prayer in
                        PrayerScheduleRow(prayer: prayer, duration: duration, selectedPrayers: selectedPrayers)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct PrayerScheduleRow: View {
    let prayer: PrayerTime
    let duration: Double
    let selectedPrayers: Set<String>
    
    private func prayerIcon(forName name: String) -> String {
        switch name {
        case "Fajr": return "sun.haze.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "cloud.sun.fill"
        case "Maghrib": return "moon.fill"
        case "Isha": return "moon.stars.fill"
        default: return "sparkles"
        }
    }
    
    private var endTime: Date {
        prayer.date.addingTimeInterval(duration * 60)
    }
    
    private var isEnabled: Bool {
        selectedPrayers.contains(prayer.name)
    }
    
    var body: some View {
        HStack {
            Image(systemName: prayerIcon(forName: prayer.name))
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 25)
            
            VStack(alignment: .leading) {
                Text(prayer.name)
                    .fontWeight(.bold)
                Text("\(prayer.timeString) - \(endTime, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .opacity(isEnabled ? 1.0 : 0.6)
            
            Spacer()
            
            Text(isEnabled ? "\(Int(duration)) min" : "Disabled")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isEnabled ? Color.secondary.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

private struct SelectPrayersView: View {
    @Binding var selectedFajr: Bool
    @Binding var selectedDhuhr: Bool
    @Binding var selectedAsr: Bool
    @Binding var selectedMaghrib: Bool
    @Binding var selectedIsha: Bool
    
    private let allPrayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    
    private func bindingForPrayer(_ prayer: String) -> Binding<Bool> {
        switch prayer {
        case "Fajr": return $selectedFajr
        case "Dhuhr": return $selectedDhuhr
        case "Asr": return $selectedAsr
        case "Maghrib": return $selectedMaghrib
        case "Isha": return $selectedIsha
        default: return .constant(false)
        }
    }
    
    private func prayerIcon(forName name: String) -> String {
        switch name {
        case "Fajr": return "sun.haze.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "cloud.sun.fill"
        case "Maghrib": return "moon.fill"
        case "Isha": return "moon.stars.fill"
        default: return "sparkles"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Select Prayers", icon: "checklist")
            
            VStack {
                ForEach(allPrayers, id: \.self) { prayer in
                    Toggle(isOn: bindingForPrayer(prayer)) {
                        HStack {
                            Image(systemName: prayerIcon(forName: prayer))
                                .frame(width: 25)
                            Text(prayer)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    if prayer != allPrayers.last {
                        Divider().background(Color.secondary.opacity(0.3))
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct BlockingDurationView: View {
    @Binding var duration: Double
    @Binding var useCustom: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Blocking Duration", icon: "timer")
            
            VStack(spacing: 16) {
                HStack {
                    Text("Set duration for all prayers")
                    Spacer()
                    Text("\(Int(duration)) min").bold()
                }
                
                Slider(value: $duration, in: 15...60, step: 5)
                    .tint(.green)
                
                Toggle("Custom duration per prayer", isOn: $useCustom)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .disabled(true) // Disabled for MVP
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct SelectAppsToBlockView: View {
    @StateObject private var appModel = AppSelectionModel.shared
    var onSelectTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Select Apps to Block", icon: "apps.iphone")
            
            VStack(spacing: 16) {
                // Search bar-like button
                Button(action: onSelectTapped) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search apps...")
                Spacer()
            }
                    .padding(12)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Block all apps toggle
                Toggle("Block all apps", isOn: .constant(false))
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .disabled(true)
                
                Divider().background(Color.secondary.opacity(0.3))
                
                // Display selected apps horizontally with names
                if !appModel.selection.applicationTokens.isEmpty || !appModel.selection.categoryTokens.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Blocked Apps & Categories")
                            .font(.subheadline).bold()
                            .padding(.bottom, 4)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(Array(appModel.selection.applicationTokens), id: \.self) { token in
                                    VStack {
                                        Label(token)
                                            .labelStyle(.iconOnly)
                                            .scaleEffect(1.25)
                                        Label(token)
                                            .labelStyle(.titleOnly)
                                            .font(.caption2)
                                    }
                                }
                                ForEach(Array(appModel.selection.categoryTokens), id: \.self) { token in
                                    VStack {
                                        Label(token)
                                            .labelStyle(.iconOnly)
                                            .scaleEffect(1.25)
                                        Label(token)
                                            .labelStyle(.titleOnly)
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("No apps selected. Tap search to begin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct AdditionalSettingsView: View {
    @Binding var strictMode: Bool
    @Binding var prePrayerNotification: Bool
    @Binding var allowEmergencyCalls: Bool
    @Binding var showingConfirmationSheet: Bool
    let onRefreshSchedule: () -> Void
    @StateObject private var blocking = BlockingStateService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Additional Settings", icon: "gearshape.fill")
            
            VStack {
                Toggle(isOn: $strictMode) {
                    VStack(alignment: .leading) {
                        Text("Strict Mode")
                        Text("Prevent early unblocking").font(.caption).foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                // Disable strict-mode toggle while apps are blocked, during early unlock, or while waiting for voice confirmation
                .disabled(blocking.appsActuallyBlocked || blocking.isEarlyUnlockedActive || blocking.isWaitingForVoiceConfirmation)
                
                Divider().background(Color.secondary.opacity(0.3))
                
                Toggle(isOn: $prePrayerNotification) {
                    VStack(alignment: .leading) {
                        Text("Pre-Prayer Notification")
                        Text("Reminder before blocking").font(.caption).foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                
                Divider().background(Color.secondary.opacity(0.3))

                Toggle(isOn: $allowEmergencyCalls) {
                    VStack(alignment: .leading) {
                        Text("Allow Emergency Calls")
                        Text("Even during blocking").font(.caption).foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                
                Divider().background(Color.secondary.opacity(0.3))
                
                Button(action: onRefreshSchedule) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        VStack(alignment: .leading) {
                            Text("Refresh Prayer Schedule")
                            Text("Update times after device time changes").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .foregroundColor(.primary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct TestBlockingView: View {
    @Binding var isBlocking: Bool
    var onBlockTapped: () -> Void
    var onForceUpdateSchedule: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Test Blocking", icon: "hammer.fill")
            
            VStack(spacing: 16) {
                Button(action: onBlockTapped) {
                    HStack {
                        Image(systemName: isBlocking ? "shield.slash.fill" : "shield.fill")
                        Text(isBlocking ? "Stop Blocking" : "Block in 30 Seconds")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isBlocking ? Color.red : Color.purple)
                    .cornerRadius(12)
                }
                
                if let onForceUpdateSchedule = onForceUpdateSchedule {
                    Button(action: onForceUpdateSchedule) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Force Update Schedule")
                        }
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
                
                Text("Test the blocking functionality. Apps will be blocked 30 seconds after pressing the button for 15 minutes. You can close the app after pressing the button.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

private struct SpeechConfirmationView: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Confirm You've Prayed")
                .font(.largeTitle.bold())
            
            Text("To unblock your apps, please say 'wallahi i prayed'.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Mock transcript: wallahi i prayed")
                .font(.title2)
                .italic()
                .foregroundColor(.green)
            
            Button(action: {
                // Mock microphone button
            }) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
            }
            
            Button(action: {
                onSuccess()
                isPresented = false
            }) {
                Text("Confirm")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
        }
            
            Button(action: {
                onCancel()
                isPresented = false
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

#Preview {
    SearchView()
        .environmentObject(AudioPlayerService.shared)
} 