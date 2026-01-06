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
    @EnvironmentObject var speechService: SpeechRecognitionService
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingAppPicker = false
    @State private var appSelection = FamilyActivitySelection()

    private var theme: AppTheme { themeManager.theme }
    
    // Prayer time data
    @State private var prayerTimes: [PrayerTime] = []
    @State private var isLoadingPrayerTimes = false
    @State private var prayerTimesError: String?
    @State private var lastPrayerTimeFetch: Date?
    @State private var prayerStorage: PrayerTimeStorage? = nil
    @State private var showingUnlockConfirmation = false
    
    // Persistent flag to track if we've ever scheduled blocking (survives app restarts)
    private var hasScheduledInitialBlocking: Bool {
        UserDefaults.standard.bool(forKey: "hasScheduledInitialBlocking")
    }
    
    @StateObject private var focusManager = FocusSettingsManager.shared
    
    // Services
    @EnvironmentObject var locationService: LocationService
    private let prayerTimeService = PrayerTimeService()
    @StateObject private var blockingStateService = BlockingStateService.shared
    @StateObject private var notificationService = PrayerNotificationService.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {

        ZStack {
            // Theme-aware background
            backgroundView

            // Main content (always show for blur effect)
            mainContent
                .blur(radius: subscriptionService.isPremium && screenTimeAuth.isAuthorized ? 0 : 10)

            // Premium lock overlay
            if !subscriptionService.isPremium {
                PremiumLockedView(feature: .focus)
            }

            // Screen Time permission overlay (shown only if premium but not authorized)
            if subscriptionService.isPremium && !screenTimeAuth.isAuthorized {
                ScreenTimePermissionOverlay(screenTimeAuth: screenTimeAuth)
            }
        }
        .foregroundColor(theme.primaryText)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))

        .sheet(isPresented: $showingAppPicker) {
            if #available(iOS 15.0, *) {
                NavigationView {
                    AppPickerView()
                        .environmentObject(ThemeManager.shared)
                        .onDisappear {
                            // Trigger update when picker closes
                            focusManager.appSelectionChanged()
                        }
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
            // Skip if not premium - app blocking is premium only
            guard subscriptionService.isPremium else {
                return
            }

            // Check Screen Time authorization status
            screenTimeAuth.updateAuthorizationStatus()

            // Fetch prayer times
            fetchPrayerTimesIfNeeded()

            // Ensure initial scheduling happens if conditions are met
            // This handles the post-onboarding scenario where scheduling may have failed
            focusManager.ensureInitialSchedulingIfNeeded()
        }
    }

    // MARK: - Private Methods

    private var mainContent: some View {
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
                    .padding(.top, theme.hasGlassEffect ? 60 : 20)
                    .padding(.bottom, 30)

                    // Main Content with separate containers
                    VStack(spacing: 20) {
                        // Show loading overlay when updating schedule
                        if focusManager.isUpdating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Updating schedule...")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryText)
                            }
                            .padding(.bottom, 8)
                            .transition(.opacity)
                        }

                        // Show banner when settings are locked during active blocking
                        if blockingStateService.isCurrentlyBlocking || blockingStateService.appsActuallyBlocked {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Settings Locked")
                                        .font(.subheadline.bold())
                                        .foregroundColor(theme.primaryText)
                                    Text("Settings cannot be changed while apps are blocked")
                                        .font(.caption)
                                        .foregroundColor(theme.secondaryText)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.15))
                            )
                            .padding(.horizontal, 16)
                        }

                        // Voice confirmation section (appears when blocking is active in strict mode)
                        VoiceConfirmationView(blockingState: blockingStateService)

                        // Early unlock section (strict mode off)
                        EarlyUnlockInlineSection(theme: theme)

                        // Today's Blocking Schedule - Separate Container
                        MockupTodayScheduleSection(
                            prayerTimes: prayerTimes,
                            duration: focusManager.blockingDuration,
                            selectedPrayers: focusManager.getSelectedPrayers(),
                            isLoading: isLoadingPrayerTimes,
                            error: prayerTimesError
                        )
                        .padding(.horizontal, 16)

                        // Select Prayers - Separate Container
                        PrayerToggleSection(
                            focusManager: focusManager,
                            showOverlayWhenEmpty: true,
                            onSelectApps: {
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
                        )
                        .padding(.horizontal, 16)

                        BlockingDurationView(
                            duration: $focusManager.blockingDuration,
                            theme: theme
                        )
                        .padding(.horizontal, 16)

                        PrePrayerBufferView(
                            buffer: $focusManager.prePrayerBuffer,
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
                            strictMode: $focusManager.strictMode,
                            prePrayerNotification: $focusManager.prayerRemindersEnabled,
                            showingConfirmationSheet: $showingUnlockConfirmation,
                            theme: theme
                        )
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 40)
                }
            }
        }


    // MARK: - Private Methods

    private var backgroundView: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                // Dark background matching mockup
                Color(red: 0.11, green: 0.13, blue: 0.16).ignoresSafeArea()
            } else {
                theme.primaryBackground.ignoresSafeArea()
            }
        }
    }

    private var containerBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
            selectedPrayers: focusManager.getSelectedPrayers(),
            isEnabled: focusManager.prayerRemindersEnabled,
            minutesBefore: 5
        )
    }
    
    // Save prayer schedule for cleanup tracking
    private func saveScheduleToUserDefaults(_ prayerTimes: [PrayerTime]) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let schedules = prayerTimes.map { prayer -> [String: Any] in
            let durationSeconds = focusManager.blockingDuration * 60
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

        // Try to load existing storage first
        if prayerStorage == nil {
            prayerStorage = prayerTimeService.loadStorage()
        }

        // Check if we need to fetch
        let shouldFetch: Bool
        if let storage = prayerStorage {
            shouldFetch = storage.shouldRefresh
            if shouldFetch {
            } else {
                // Load prayer times from storage for display
                loadPrayerTimesFromStorage(storage)
                // Check if rolling window needs update
                checkRollingWindowUpdate()
                return
            }
        } else {
            shouldFetch = true
        }

        if shouldFetch {
            fetchPrayerTimes()
        } else {
            // Load existing storage for display
            if let storage = prayerStorage {
                loadPrayerTimesFromStorage(storage)
            }
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
                // Check if existing storage is valid and location-appropriate
                if let storage = prayerStorage ?? prayerTimeService.loadStorage() {
                    // Check if storage is still valid (not expired)
                    if !storage.shouldRefresh {
                        // Check if location changed significantly
                        let needsLocationRefresh = await prayerTimeService.needsRefreshForLocation(location, storage: storage)

                        if !needsLocationRefresh {
                            prayerStorage = storage
                            await MainActor.run {
                                self.loadPrayerTimesFromStorage(storage)
                                self.isLoadingPrayerTimes = false
                                self.prayerTimesError = nil
                                self.lastPrayerTimeFetch = Date()
                                self.scheduleNotificationsIfNeeded()
                                self.scheduleRollingWindowFromStorage()
                            }
                            return
                        } else {
                            prayerTimeService.clearStorage()
                            prayerStorage = nil
                        }
                    } else {
                        prayerTimeService.clearStorage()
                        prayerStorage = nil
                    }
                }


                // Fetch 6 months of prayer times
                let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location)

                // Save storage
                prayerTimeService.saveStorage(storage)
                prayerStorage = storage

                // Load prayer times for display (next 4 days)
                await MainActor.run {
                    self.loadPrayerTimesFromStorage(storage)
                    self.isLoadingPrayerTimes = false
                    self.prayerTimesError = nil
                    self.lastPrayerTimeFetch = Date()

                    // Schedule notifications if enabled
                    self.scheduleNotificationsIfNeeded()

                    // Schedule rolling window
                    self.scheduleRollingWindowFromStorage()
                }

            } catch {
                await MainActor.run {
                    self.prayerTimesError = "Failed to fetch prayer times: \(error.localizedDescription)"
                    self.isLoadingPrayerTimes = false
                }
            }
        }
    }

    private func loadPrayerTimesFromStorage(_ storage: PrayerTimeStorage) {

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Load next 4 days for UI display
        guard let endOfDisplay = calendar.date(byAdding: .day, value: 4, to: startOfToday) else { return }

        let displayTimes = storage.prayerTimes.filter { $0.date >= startOfToday && $0.date < endOfDisplay }

        var prayerTimes: [PrayerTime] = []
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for storedTime in displayTimes {
            let prayers = [
                ("Fajr", storedTime.fajr),
                ("Dhuhr", storedTime.dhuhr),
                ("Asr", storedTime.asr),
                ("Maghrib", storedTime.maghrib),
                ("Isha", storedTime.isha)
            ]

            for (name, timeString) in prayers {
                let cleanTimeString = timeString.components(separatedBy: " ").first ?? timeString
                guard let time = timeFormatter.date(from: cleanTimeString) else { continue }

                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                if let prayerDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                  minute: timeComponents.minute ?? 0,
                                                  second: 0,
                                                  of: storedTime.date) {
                    prayerTimes.append(PrayerTime(name: name, date: prayerDate))
                }
            }
        }

        self.prayerTimes = prayerTimes.sorted { $0.date < $1.date }
    }

    private func checkRollingWindowUpdate() {
        guard let storage = prayerStorage else { return }

        if DeviceActivityService.shared.needsRollingWindowUpdate() {
            scheduleRollingWindowFromStorage()
        } else {
        }
    }

    private func scheduleRollingWindowFromStorage() {
        guard let storage = prayerStorage else {
            return
        }

        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: focusManager.blockingDuration,
            selectedPrayers: focusManager.getSelectedPrayers(),
            prePrayerBuffer: focusManager.prePrayerBuffer
        )
    }
    
    // MARK: - Helper Methods
    
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
}

// MARK: - Early Unlock Inline Section (Focus page)
private struct EarlyUnlockInlineSection: View {
    let theme: AppTheme
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshTimer: Timer?

    private var containerBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
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
    @StateObject private var blockingState = BlockingStateService.shared

    /// Whether settings should be disabled (during active blocking)
    private var isDisabled: Bool {
        blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked
    }

    private var backgroundShape: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Blocking Duration")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Text("Time after prayer starts")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            VStack(spacing: 16) {
                HStack {
                    Text("Block apps for")
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Text("\(Int(duration)) min after prayer")
                        .bold()
                        .foregroundColor(theme.primaryText)
                }

                // Duration Buttons
                HStack(spacing: 10) {
                    DurationButton(value: 15, current: Int(duration), theme: theme) {
                        duration = 15
                    }
                    .disabled(isDisabled)

                    DurationButton(value: 20, current: Int(duration), theme: theme) {
                        duration = 20
                    }
                    .disabled(isDisabled)

                    DurationButton(value: 30, current: Int(duration), theme: theme) {
                        duration = 30
                    }
                    .disabled(isDisabled)

                    CustomDurationButton(current: Int(duration), theme: theme) { customValue in
                        duration = Double(customValue)
                    }
                    .disabled(isDisabled)
                }
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding()
            .background(backgroundShape)
        }
    }
}

// MARK: - Duration Button Components

private struct DurationButton: View {
    let value: Int
    let current: Int
    let theme: AppTheme
    let action: () -> Void

    var isSelected: Bool {
        current == value
    }

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "1A9B8A") : Color.gray.opacity(0.2))
                )
        }
    }
}

private struct CustomDurationButton: View {
    let current: Int
    let theme: AppTheme
    let onSet: (Int) -> Void

    @State private var showingInput = false
    @State private var customValue = ""

    private var isCustomValue: Bool {
        ![10, 15, 20, 30].contains(current)
    }

    var body: some View {
        Button(action: {
            customValue = "\(current)"
            showingInput = true
        }) {
            VStack(spacing: 2) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                if isCustomValue {
                    Text("\(current)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(isCustomValue ? .white : theme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCustomValue ? Color(hex: "1A9B8A") : Color.gray.opacity(0.2))
            )
        }
        .alert("Custom Duration", isPresented: $showingInput) {
            TextField("Minutes (10-90)", text: $customValue)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                if let value = Int(customValue), value >= 10, value <= 90 {
                    onSet(value)
                }
            }
        } message: {
            Text("Enter blocking duration between 10 and 90 minutes")
        }
    }
}

// MARK: - Pre-Prayer Buffer View

private struct PrePrayerBufferView: View {
    @Binding var buffer: Double
    let theme: AppTheme
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared

    /// Whether settings should be disabled (during active blocking)
    private var isDisabled: Bool {
        blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked
    }

    private var backgroundShape: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
            VStack(alignment: .leading, spacing: 4) {
                Text("Pre-Prayer Focus")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)
                Text("Start blocking before prayer time to prepare")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(Color(hex: "1A9B8A"))
                    Text("Buffer Time")
                        .foregroundColor(theme.primaryText)
                    Spacer()
                    Text(buffer == 0 ? "Off" : "\(Int(buffer)) min before")
                        .bold()
                        .foregroundColor(buffer == 0 ? theme.tertiaryText : theme.primaryText)
                }

                // Buffer Time Buttons
                HStack(spacing: 10) {
                    BufferButton(value: 0, current: Int(buffer), theme: theme) {
                        buffer = 0
                    }
                    .disabled(isDisabled)

                    BufferButton(value: 5, current: Int(buffer), theme: theme) {
                        buffer = 5
                    }
                    .disabled(isDisabled)

                    BufferButton(value: 10, current: Int(buffer), theme: theme) {
                        buffer = 10
                    }
                    .disabled(isDisabled)

                    BufferButton(value: 15, current: Int(buffer), theme: theme) {
                        buffer = 15
                    }
                    .disabled(isDisabled)
                }
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding()
            .background(backgroundShape)
        }
    }
}

private struct BufferButton: View {
    let value: Int
    let current: Int
    let theme: AppTheme
    let action: () -> Void

    var isSelected: Bool {
        current == value
    }

    var body: some View {
        Button(action: action) {
            Text(value == 0 ? "Off" : "\(value)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "1A9B8A") : Color.gray.opacity(0.2))
                )
        }
    }
}


private struct SelectAppsToBlockView: View {
    @StateObject private var appModel = AppSelectionModel.shared
    let theme: AppTheme
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared
    var onSelectTapped: () -> Void

    /// Whether settings should be disabled (during active blocking)
    private var isDisabled: Bool {
        blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked
    }

    private var backgroundShape: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
                    .foregroundColor(isDisabled ? theme.tertiaryText : Color(red: 0.2, green: 0.8, blue: 0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background((isDisabled ? theme.tertiaryText : Color(red: 0.2, green: 0.8, blue: 0.6)).opacity(0.15))
                    .cornerRadius(8)
                }
                .disabled(isDisabled)
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
            .background(backgroundShape)
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
    @StateObject private var focusManager = FocusSettingsManager.shared

    /// Whether settings should be disabled (during active blocking)
    private var isDisabled: Bool {
        blocking.isCurrentlyBlocking || blocking.appsActuallyBlocked
    }

    private var backgroundShape: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
                            if blocking.canToggleStrictMode && !isDisabled {
                                strictMode = newValue
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                    .disabled(!blocking.canToggleStrictMode || isDisabled)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(isDisabled ? 0.5 : 1.0)

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
                                guard !isDisabled else { return }
                                if newValue && !notificationService.hasNotificationPermission {
                                    // Request permission first
                                    Task {
                                        let granted = await notificationService.requestNotificationPermission()
                                        if granted {
                                            await MainActor.run {
                                                prePrayerNotification = true
                                            }
                                            // Explicitly trigger notification scheduling after permission granted
                                            if let storage = PrayerTimeService().loadStorage() {
                                                let prayerTimes = focusManager.parsePrayerTimesPublic(from: storage)
                                                PrayerNotificationService.shared.schedulePrePrayerNotifications(
                                                    prayerTimes: prayerTimes,
                                                    selectedPrayers: focusManager.getSelectedPrayers(),
                                                    isEnabled: true,
                                                    minutesBefore: 5
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    prePrayerNotification = newValue
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                        .disabled(isDisabled)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .background(backgroundShape)
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
            theme.primaryBackground.ignoresSafeArea()

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
        .preferredColorScheme(ThemeManager.shared.currentTheme == .auto ? nil : (ThemeManager.shared.effectiveTheme == .dark ? .dark : .light))
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

    private var backgroundShape: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
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
            .background(backgroundShape)
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
            if themeManager.effectiveTheme == .dark {
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

// MARK: - Screen Time Permission Overlay

private struct ScreenTimePermissionOverlay: View {
    @ObservedObject var screenTimeAuth: ScreenTimeAuthorizationService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isRequesting = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            // Background
            theme.primaryBackground.opacity(0.98)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(theme.primaryAccent.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(theme.primaryAccent)
                }

                // Title
                Text("Screen Time Permission Required")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Description
                VStack(spacing: 16) {
                    Text("To use Focus Mode and block apps during prayer times, Khushoo needs Screen Time permission.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        ScreenTimeBenefitRow(
                            icon: "iphone.slash",
                            text: "Block distracting apps automatically",
                            theme: theme
                        )
                        ScreenTimeBenefitRow(
                            icon: "clock.fill",
                            text: "Set custom blocking durations",
                            theme: theme
                        )
                        ScreenTimeBenefitRow(
                            icon: "checkmark.shield.fill",
                            text: "Stay focused during prayer times",
                            theme: theme
                        )
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Action Button
                VStack(spacing: 16) {
                    Button(action: {
                        isRequesting = true
                        Task {
                            do {
                                try await screenTimeAuth.requestAuthorization()
                            } catch {
                            }
                            isRequesting = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                            }

                            Text(isRequesting ? "Requesting..." : "Enable Screen Time")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.prayerGradientStart, theme.prayerGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .disabled(isRequesting)

                    Text("You can also enable this later in Settings")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

private struct ScreenTimeBenefitRow: View {
    let icon: String
    let text: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.primaryAccent)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(theme.primaryText)

            Spacer()
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AudioPlayerService.shared)
} 