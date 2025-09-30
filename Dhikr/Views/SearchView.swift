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
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingAppPicker = false
    @State private var appSelection = FamilyActivitySelection()

    private var theme: AppTheme { themeManager.theme }
    
    // Prayer time data
    @State private var prayerTimes: [PrayerTime] = []
    @State private var isLoadingPrayerTimes = false
    @State private var prayerTimesError: String?
    @State private var lastPrayerTimeFetch: Date?
    @State private var hasInitializedSettings = false
    @State private var reschedulingTimer: Timer?
    @State private var isUpdatingSchedule = false
    
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
    
    private func syncPrayerSelectionsToAppGroup() {
        // Sync prayer selections to App Group for extension to read
        Task.detached(priority: .background) {
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(await self.selectedFajr, forKey: "focusSelectedFajr")
                groupDefaults.set(await self.selectedDhuhr, forKey: "focusSelectedDhuhr")
                groupDefaults.set(await self.selectedAsr, forKey: "focusSelectedAsr")
                groupDefaults.set(await self.selectedMaghrib, forKey: "focusSelectedMaghrib")
                groupDefaults.set(await self.selectedIsha, forKey: "focusSelectedIsha")
                groupDefaults.synchronize()
            }
        }
    }
    
    @AppStorage("focusBlockingDuration") private var blockingDuration: Double = 15
    
    @AppStorage("focusStrictMode") private var strictMode = false

    // Other UI settings (don't trigger updates)
    @State private var prePrayerNotification = true
    @State private var showingUnlockConfirmation = false
    
    // Services
    private let locationService = LocationService()
    private let prayerTimeService = PrayerTimeService()
    @StateObject private var blockingStateService = BlockingStateService.shared
    @StateObject private var notificationService = PrayerNotificationService.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {

        ZStack {
            // Theme-aware background
            backgroundView

            ScrollView {
                VStack(spacing: 0) {
                    // Simple Header like mockup
                    VStack(spacing: 8) {
                        Text("Prayer Time")
                            .font(.largeTitle.bold())
                            .foregroundColor(theme.primaryText)
                        Text("App Blocking")
                            .font(.largeTitle.bold())
                            .foregroundColor(theme.primaryText)
                        Text("Stay focused during your prayers")
                            .font(.subheadline)
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 30)

                    // Main Content with separate containers
                    VStack(spacing: 20) {
                        // Show loading overlay when updating schedule
                        if isUpdatingSchedule {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Schedule Update")
                                    .font(.headline)
                                    .foregroundColor(theme.primaryText)

                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(theme.primaryAccent)
                                    Text("Updating schedule...")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryText)
                                    Spacer()
                                }
                                .padding()
                                .background(containerBackground)
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Voice confirmation section (appears when blocking is active in strict mode)
                        VoiceConfirmationView(blockingState: blockingStateService)

                        // Early unlock section (strict mode off)
                        EarlyUnlockInlineSection(theme: theme)

                        // Today's Blocking Schedule - Separate Container
                        MockupTodayScheduleSection(
                            prayerTimes: prayerTimes,
                            duration: blockingDuration,
                            selectedPrayers: selectedPrayers,
                            isLoading: isLoadingPrayerTimes,
                            error: prayerTimesError
                        )
                        .padding(.horizontal, 16)

                        // Select Prayers - Separate Container
                        MockupSelectPrayersSection(
                            selectedFajr: $selectedFajr,
                            selectedDhuhr: $selectedDhuhr,
                            selectedAsr: $selectedAsr,
                            selectedMaghrib: $selectedMaghrib,
                            selectedIsha: $selectedIsha
                        )
                        .padding(.horizontal, 16)

                        BlockingDurationView(
                            duration: $blockingDuration,
                            theme: theme
                        )
                        .padding(.horizontal, 16)

                        SelectAppsToBlockView(theme: theme) {
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
                        .padding(.horizontal, 16)

                        // Screen Time authorization status
                        if screenTimeAuth.authorizationStatus == .denied {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Screen Time Access")
                                    .font(.headline)
                                    .foregroundColor(theme.primaryText)

                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Screen Time Access Required")
                                            .font(.subheadline)
                                            .foregroundColor(.orange)
                                        Text("Enable Screen Time access in Settings to use prayer blocking")
                                            .font(.caption)
                                            .foregroundColor(theme.tertiaryText)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(containerBackground)
                            }
                            .padding(.horizontal, 16)
                        }

                        AdditionalSettingsView(
                            strictMode: $strictMode,
                            prePrayerNotification: $prePrayerNotification,
                            showingConfirmationSheet: $showingUnlockConfirmation,
                            theme: theme
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: blockingDuration) { newValue in
            // Clamp to 15..60 in 5-min steps
            let clamped = min(60, max(15, round(newValue / 5) * 5))
            if clamped != newValue {
                blockingDuration = clamped
            }
            // Sync to App Group in background
            Task.detached(priority: .background) {
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(await self.blockingDuration, forKey: "focusBlockingDuration")
                    groupDefaults.synchronize()
                }
            }
            scheduleUserTriggeredUpdate()
        }
        .onChange(of: selectedPrayers) { _ in
            // Sync to App Group first
            syncPrayerSelectionsToAppGroup()
            scheduleUserTriggeredUpdate()
            scheduleNotificationsIfNeeded()
        }
        .onChange(of: strictMode) { newValue in
            // Sync strict mode to App Group in background
            Task.detached(priority: .background) {
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(newValue, forKey: "focusStrictMode")
                    groupDefaults.synchronize()
                }
            }
            // Do not interrupt current block; update future schedule only
            performUserTriggeredScheduleUpdate()
        }
        .onChange(of: prePrayerNotification) { _ in
            scheduleNotificationsIfNeeded()
        }
        .foregroundColor(theme.primaryText)
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)

        .sheet(isPresented: $showingAppPicker) {
            if #available(iOS 15.0, *) {
        NavigationView {
                    AppPickerView()
                        .environmentObject(ThemeManager.shared)
                }
            }
        }
        .sheet(isPresented: $showingUnlockConfirmation) {
            SpeechConfirmationView(isPresented: $showingUnlockConfirmation, theme: theme) {
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
            
            // Check Screen Time authorization status
            screenTimeAuth.updateAuthorizationStatus()
            
            // Fetch prayer times
            fetchPrayerTimesIfNeeded()
            
            // Sync settings to UserDefaults in background after initialization
            Task.detached(priority: .background) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                await MainActor.run {
                    // Mark as initialized first to prevent triggering updates
                    self.hasInitializedSettings = true
                }
                
                // Sync current settings to UserDefaults in background
                let defaults = UserDefaults.standard
                let fajr = await self.selectedFajr
                let dhuhr = await self.selectedDhuhr
                let asr = await self.selectedAsr
                let maghrib = await self.selectedMaghrib
                let isha = await self.selectedIsha
                let duration = await self.blockingDuration
                let strict = await self.strictMode
                
                defaults.set(fajr, forKey: "focusSelectedFajr")
                defaults.set(dhuhr, forKey: "focusSelectedDhuhr")
                defaults.set(asr, forKey: "focusSelectedAsr")
                defaults.set(maghrib, forKey: "focusSelectedMaghrib")
                defaults.set(isha, forKey: "focusSelectedIsha")
                defaults.set(duration, forKey: "focusBlockingDuration")
                
                // Sync ALL settings to App Group for extension access
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(strict, forKey: "focusStrictMode")
                    groupDefaults.set(fajr, forKey: "focusSelectedFajr")
                    groupDefaults.set(dhuhr, forKey: "focusSelectedDhuhr")
                    groupDefaults.set(asr, forKey: "focusSelectedAsr")
                    groupDefaults.set(maghrib, forKey: "focusSelectedMaghrib")
                    groupDefaults.set(isha, forKey: "focusSelectedIsha")
                    groupDefaults.set(duration, forKey: "focusBlockingDuration")
                    groupDefaults.synchronize()
                }
            }
        }
        
    }

    // MARK: - Private Methods

    private var backgroundView: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                LiquidGlassBackgroundView()
            } else if themeManager.currentTheme == .dark {
                // Dark background matching mockup
                Color(red: 0.11, green: 0.13, blue: 0.16).ignoresSafeArea()
            } else {
                theme.primaryBackground.ignoresSafeArea()
            }
        }
    }

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    private func scheduleNotificationsIfNeeded() {
        guard !prayerTimes.isEmpty else { return }

        notificationService.schedulePrePrayerNotifications(
            prayerTimes: prayerTimes,
            selectedPrayers: selectedPrayers,
            isEnabled: prePrayerNotification,
            minutesBefore: 5
        )
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
                                // Cache loaded - schedule notifications if enabled
                                self.scheduleNotificationsIfNeeded()
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

                    // Prayer times fetched - schedule notifications if enabled
                    self.scheduleNotificationsIfNeeded()
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
        
        // Schedule update with reduced delay to batch multiple changes
        reschedulingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performScheduleUpdate()
        }
    }
    
    private func scheduleUserTriggeredUpdate() {
        // Ignore updates until settings are initialized
        guard hasInitializedSettings, !prayerTimes.isEmpty else { return }
        
        // Cancel any existing timer to debounce rapid changes
        reschedulingTimer?.invalidate()
        
        // Schedule update with reduced delay to batch multiple changes
        reschedulingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
            self.performUserTriggeredScheduleUpdate()
        }
    }
    
    private func performScheduleUpdate() {
        // Set loading state
        isUpdatingSchedule = true
        
        // Perform heavy operations in background
        Task.detached(priority: .background) {
            // Use regular scheduling for initial loads, only force reschedule for user changes
            let times = await self.prayerTimes
            let duration = await self.blockingDuration
            let selected = await self.selectedPrayers
            
            DeviceActivityService.shared.schedulePrayerTimeBlocking(
                prayerTimes: times,
                duration: duration,
                selectedPrayers: selected
            )
            
            // Save filtered schedule for tracking
            let filteredPrayerTimes = times.filter { selected.contains($0.name) }
            await self.saveScheduleToUserDefaults(filteredPrayerTimes)
            
            // Clear loading state on main thread
            await MainActor.run {
                self.isUpdatingSchedule = false
            }
        }
    }
    
    private func performUserTriggeredScheduleUpdate() {
        // Set loading state
        isUpdatingSchedule = true
        
        // Perform heavy operations in background
        Task.detached(priority: .background) {
            // Use forceCompleteReschedule for user-triggered changes
            let times = await self.prayerTimes
            let duration = await self.blockingDuration
            let selected = await self.selectedPrayers
            
            DeviceActivityService.shared.forceCompleteReschedule(
                prayerTimes: times,
                duration: duration,
                selectedPrayers: selected
            )
            
            // Save filtered schedule for tracking
            let filteredPrayerTimes = times.filter { selected.contains($0.name) }
            await self.saveScheduleToUserDefaults(filteredPrayerTimes)
            
            // Clear loading state on main thread
            await MainActor.run {
                self.isUpdatingSchedule = false
            }
        }
    }
    
}
// MARK: - Early Unlock Inline Section (Focus page)
private struct EarlyUnlockInlineSection: View {
    let theme: AppTheme
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshTimer: Timer?

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }
    
    var body: some View {
        Group {
            // Show only when strict mode is OFF and apps are actually blocked
            if !blocking.isStrictModeEnabled && blocking.appsActuallyBlocked {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill").foregroundColor(.orange)
                        Text("Early Unlock")
                            .font(.headline)
                            .foregroundColor(theme.primaryText)
                    }
                    .padding(.bottom, 2)
                    
                    let remaining = blocking.timeUntilEarlyUnlock()
                    if remaining > 0 {
                        Text("Available in")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                        Text(remaining.formattedForCountdown)
                            .font(.title3).monospacedDigit()
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("You can unlock apps early now.")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
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
                            .foregroundColor(theme.primaryText)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding()
                .background(containerBackground)
                .padding(.horizontal, 16)
                    .onAppear {
                    // Start a timer to keep the UI updated while this section is visible
                    refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                        // The @StateObject will automatically update the UI when properties change
                        Task { @MainActor in
                            blocking.forceCheck()
                        }
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


private struct HeaderImageView: View {
    let theme: AppTheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Theme-aware gradient background
            LinearGradient(
                gradient: Gradient(colors: [theme.prayerGradientStart, theme.prayerGradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 250)
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0.2), .clear]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )

            VStack(alignment: .center, spacing: 4) {
                Text("Prayer Time App Blocking")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.primaryText)
                Text("Stay focused during your prayers")
                    .font(.headline)
                    .foregroundColor(theme.primaryText.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(height: 250)
        .glassCard(theme: theme)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(theme.primaryAccent)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
        }
    }
}

private struct TodaysBlockingScheduleView: View {
    let prayerTimes: [PrayerTime]
    let duration: Double
    let selectedPrayers: Set<String>
    let isLoading: Bool
    let error: String?
    let theme: AppTheme
    
    private var todayPrayers: [PrayerTime] {
        let today = Date()
        return prayerTimes.filter { prayer in
            Calendar.current.isDate(prayer.date, inSameDayAs: today)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Blocking Schedule", icon: "calendar", theme: theme)
            
            VStack(spacing: 8) {
                HStack {
                    Text(Date(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                    Spacer()
                    if selectedPrayers.count == 5 {
                        Text("All prayers active")
                            .font(.caption.bold())
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accentGreen)
                            .cornerRadius(8)
                    } else {
                        Text("\(selectedPrayers.count) of 5 prayers active")
                            .font(.caption.bold())
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.accentGold)
                            .cornerRadius(8)
                    }
                }
                
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading prayer times...")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
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
                        .foregroundColor(theme.secondaryText)
                        .padding()
                } else {
                    ForEach(todayPrayers) { prayer in
                        PrayerScheduleRow(prayer: prayer, duration: duration, selectedPrayers: selectedPrayers, theme: theme)
                    }
                }
            }
            .padding()
            .glassCard(theme: theme)
        }
    }
}

private struct PrayerScheduleRow: View {
    let prayer: PrayerTime
    let duration: Double
    let selectedPrayers: Set<String>
    let theme: AppTheme
    
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
                .foregroundColor(isEnabled ? theme.accentGreen : theme.tertiaryText)
                .frame(width: 25)

            VStack(alignment: .leading) {
                Text(prayer.name)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)
                Text("\(prayer.timeString) - \(endTime, style: .time)")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            .opacity(isEnabled ? 1.0 : 0.6)

            Spacer()

            Text(isEnabled ? "\(Int(duration)) min" : "Disabled")
                .font(.caption.bold())
                .foregroundColor(isEnabled ? theme.primaryText : theme.tertiaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isEnabled ? theme.tertiaryBackground : theme.tertiaryBackground.opacity(0.5))
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
    let theme: AppTheme
    @State private var isUpdating = false
    
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
            SectionHeader(title: "Select Prayers", icon: "checklist", theme: theme)
            
            VStack {
                ForEach(allPrayers, id: \.self) { prayer in
                    Toggle(isOn: bindingForPrayer(prayer)) {
                        HStack {
                            Image(systemName: prayerIcon(forName: prayer))
                                .frame(width: 25)
                            Text(prayer)
                            if isUpdating {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.6)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .disabled(isUpdating)
                    .onChange(of: bindingForPrayer(prayer).wrappedValue) { _ in
                        // Show loading for a brief moment
                        isUpdating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUpdating = false
                        }
                    }
                    if prayer != allPrayers.last {
                        Divider().background(theme.tertiaryBackground)
                    }
                }
            }
            .padding()
            .glassCard(theme: theme)
            .cornerRadius(12)
        }
    }
}

private struct BlockingDurationView: View {
    @Binding var duration: Double
    let theme: AppTheme
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isUpdating = false

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Blocking Duration")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            VStack(spacing: 16) {
                HStack {
                    Text("Set duration for all prayers")
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text("\(Int(duration)) min")
                        .bold()
                        .foregroundColor(theme.primaryText)
                }

                Slider(value: $duration, in: 15...60, step: 5)
                    .tint(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .accentColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .colorScheme(themeManager.currentTheme == .light ? .light : .dark)
                    .disabled(isUpdating)
                    .onChange(of: duration) { _ in
                        isUpdating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUpdating = false
                        }
                    }
            }
            .padding()
            .background(containerBackground)
        }
    }
}

private struct SelectAppsToBlockView: View {
    @StateObject private var appModel = AppSelectionModel.shared
    let theme: AppTheme
    @StateObject private var themeManager = ThemeManager.shared
    var onSelectTapped: () -> Void

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Add/Remove button
            HStack {
                Text("App Selection")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: onSelectTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                        Text("Add/Remove")
                            .font(.caption)
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.15))
                    .cornerRadius(8)
                }
            }

            // App grid display
            VStack(spacing: 16) {
                if !appModel.selection.applicationTokens.isEmpty || !appModel.selection.categoryTokens.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        // Application tokens
                        ForEach(Array(appModel.selection.applicationTokens), id: \.self) { token in
                            AppIconView(token: token)
                        }

                        // Category tokens
                        ForEach(Array(appModel.selection.categoryTokens), id: \.self) { token in
                            AppIconView(token: token)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "apps.iphone.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(Color(white: 0.5))

                        Text("No apps selected")
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.7))

                        Text("Tap Add/Remove to select apps to block")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(containerBackground)
        }
    }
}

private struct AppIconView: View {
    let applicationToken: ApplicationToken?
    let categoryToken: ActivityCategoryToken?

    init(token: ApplicationToken) {
        self.applicationToken = token
        self.categoryToken = nil
    }

    init(token: ActivityCategoryToken) {
        self.applicationToken = nil
        self.categoryToken = token
    }

    var body: some View {
        VStack(spacing: 0) {
            if let appToken = applicationToken {
                Label(appToken)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.8)
            } else if let catToken = categoryToken {
                Label(catToken)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.8)
            }
        }
        .frame(width: 44, height: 44)
    }
}

private struct AdditionalSettingsView: View {
    @Binding var strictMode: Bool
    @Binding var prePrayerNotification: Bool
    @Binding var showingConfirmationSheet: Bool
    let theme: AppTheme
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var notificationService = PrayerNotificationService.shared
    @StateObject private var themeManager = ThemeManager.shared

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Settings")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Strict Mode")
                            .foregroundColor(theme.primaryText)
                        Text("Prevent early unblocking")
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { strictMode },
                        set: { newValue in
                            if blocking.canToggleStrictMode {
                                strictMode = newValue
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                    .disabled(!blocking.canToggleStrictMode)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color(white: 0.2))

                HStack {
                    VStack(alignment: .leading) {
                        Text("Pre-Prayer Notification")
                            .foregroundColor(theme.primaryText)
                        if notificationService.hasNotificationPermission {
                            Text("5 min reminder before blocking")
                                .font(.caption)
                                .foregroundColor(theme.secondaryText)
                        } else {
                            Text("Tap to enable notifications")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()

                    if notificationService.isRequestingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { prePrayerNotification && notificationService.hasNotificationPermission },
                            set: { newValue in
                                if newValue && !notificationService.hasNotificationPermission {
                                    // Request permission first
                                    Task {
                                        let granted = await notificationService.requestNotificationPermission()
                                        if granted {
                                            prePrayerNotification = true
                                            // Schedule notifications will be handled in onChange
                                        }
                                    }
                                } else {
                                    prePrayerNotification = newValue
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(containerBackground)
        }
    }
}


private struct SpeechConfirmationView: View {
    @Binding var isPresented: Bool
    let theme: AppTheme
    var onSuccess: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            if ThemeManager.shared.currentTheme == .liquidGlass {
                LiquidGlassBackgroundView()
            } else {
                theme.primaryBackground.ignoresSafeArea()
            }

            VStack(spacing: 24) {
                Text("Confirm You've Prayed")
                    .font(.largeTitle.bold())
                    .foregroundColor(theme.primaryText)

            Text("To unblock your apps, please say 'wallahi i prayed'.")
                .font(.body)
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)

            Text("Mock transcript: wallahi i prayed")
                .font(.title2)
                .italic()
                .foregroundColor(theme.primaryAccent)

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
                    .foregroundColor(theme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(theme.accentGreen)
                    .cornerRadius(12)
        }

            Button(action: {
                onCancel()
                isPresented = false
            }) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(theme.tertiaryBackground)
                    .cornerRadius(12)
            }
            }
            .padding()
        }
        .preferredColorScheme(ThemeManager.shared.currentTheme == .dark ? .dark : .light)
    }
}

// MARK: - New Mockup Components

private struct MockupTodayScheduleSection: View {
    let prayerTimes: [PrayerTime]
    let duration: Double
    let selectedPrayers: Set<String>
    let isLoading: Bool
    let error: String?

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    private var todayPrayers: [PrayerTime] {
        let today = Date()
        return prayerTimes.filter { prayer in
            Calendar.current.isDate(prayer.date, inSameDayAs: today)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with badge
            HStack {
                Text("Today's Blocking Schedule")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                Spacer()

                if selectedPrayers.count == 5 {
                    Text("All prayers active")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }

            // Content box
            VStack(spacing: 0) {
                // Date at top of content box
                HStack {
                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(theme.tertiaryText)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading prayer times...")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding()
                } else if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                } else if todayPrayers.isEmpty {
                    // Show fallback prayers
                    ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayerName in
                        MockupPrayerRow(
                            prayerName: prayerName,
                            time: getFallbackTime(for: prayerName),
                            duration: duration,
                            isEnabled: selectedPrayers.contains(prayerName)
                        )
                        if prayerName != "Isha" {
                            Divider().background(Color(white: 0.2))
                        }
                    }
                } else {
                    // Show actual prayer times
                    let prayersToShow = Array(todayPrayers.prefix(5))
                    ForEach(Array(prayersToShow.enumerated()), id: \.element.id) { index, prayer in
                        MockupPrayerRow(
                            prayerName: prayer.name,
                            time: prayer.timeString,
                            duration: duration,
                            isEnabled: selectedPrayers.contains(prayer.name)
                        )
                        if index < prayersToShow.count - 1 {
                            Divider().background(Color(white: 0.2))
                        }
                    }
                }
            }
            .background(containerBackground)
        }
    }

    private func getFallbackTime(for prayer: String) -> String {
        switch prayer {
        case "Fajr": return "5:48 AM"
        case "Dhuhr": return "1:04 PM"
        case "Asr": return "4:21 PM"
        case "Maghrib": return "6:59 PM"
        case "Isha": return "8:14 PM"
        default: return "12:00 PM"
        }
    }
}

private struct MockupPrayerRow: View {
    let prayerName: String
    let time: String
    let duration: Double
    let isEnabled: Bool

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    private func prayerIcon(for name: String) -> String {
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
        HStack {
            Image(systemName: prayerIcon(for: prayerName))
                .foregroundColor(isEnabled ? Color(red: 0.2, green: 0.8, blue: 0.6) : theme.tertiaryText)
                .frame(width: 20)

            Text(prayerName)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)
                .frame(width: 60, alignment: .leading)

            Text(time)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
                .frame(width: 80, alignment: .leading)

            Spacer()

            Text("\(Int(duration)) min")
                .font(.caption)
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct MockupSelectPrayersSection: View {
    @Binding var selectedFajr: Bool
    @Binding var selectedDhuhr: Bool
    @Binding var selectedAsr: Bool
    @Binding var selectedMaghrib: Bool
    @Binding var selectedIsha: Bool

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    private var containerBackground: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
            } else if themeManager.currentTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Prayers")
                .font(.headline)
                .foregroundColor(theme.primaryText)

            VStack(spacing: 0) {
                MockupPrayerToggleRow(
                    prayerName: "Fajr",
                    icon: "sun.haze.fill",
                    isSelected: $selectedFajr
                )
                Divider().background(Color(white: 0.2))

                MockupPrayerToggleRow(
                    prayerName: "Dhuhr",
                    icon: "sun.max.fill",
                    isSelected: $selectedDhuhr
                )
                Divider().background(Color(white: 0.2))

                MockupPrayerToggleRow(
                    prayerName: "Asr",
                    icon: "cloud.sun.fill",
                    isSelected: $selectedAsr
                )
                Divider().background(Color(white: 0.2))

                MockupPrayerToggleRow(
                    prayerName: "Maghrib",
                    icon: "moon.fill",
                    isSelected: $selectedMaghrib
                )
                Divider().background(Color(white: 0.2))

                MockupPrayerToggleRow(
                    prayerName: "Isha",
                    icon: "moon.stars.fill",
                    isSelected: $selectedIsha
                )
            }
            .background(containerBackground)
        }
    }
}

private struct MockupPrayerToggleRow: View {
    let prayerName: String
    let icon: String
    @Binding var isSelected: Bool

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isSelected ? Color(red: 0.2, green: 0.8, blue: 0.6) : theme.tertiaryText)
                .frame(width: 20)

            Text(prayerName)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)

            Spacer()

            Toggle("", isOn: $isSelected)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    SearchView()
        .environmentObject(AudioPlayerService.shared)
} 