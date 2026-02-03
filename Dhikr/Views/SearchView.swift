//
//  SearchView.swift
//  Dhikr
//
//  Sacred Minimalism redesign of Focus/SearchView
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

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var theme: AppTheme { themeManager.theme }

    // Prayer time data
    @State private var prayerTimes: [PrayerTime] = []
    @State private var isLoadingPrayerTimes = false
    @State private var prayerTimesError: String?
    @State private var lastPrayerTimeFetch: Date?
    @State private var prayerStorage: PrayerTimeStorage? = nil
    @State private var showingUnlockConfirmation = false

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
            pageBackground.ignoresSafeArea()

            mainContent
                .blur(radius: subscriptionService.hasPremiumAccess && screenTimeAuth.isAuthorized ? 0 : 10)

            if !subscriptionService.hasPremiumAccess {
                PremiumLockedView(feature: .focus)
            }

            if subscriptionService.hasPremiumAccess && !screenTimeAuth.isAuthorized {
                SacredScreenTimePermissionOverlay(screenTimeAuth: screenTimeAuth)
            }
        }
        .foregroundColor(themeManager.theme.primaryText)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .sheet(isPresented: $showingAppPicker) {
            if #available(iOS 15.0, *) {
                NavigationView {
                    AppPickerView()
                        .environmentObject(ThemeManager.shared)
                        .onDisappear {
                            focusManager.appSelectionChanged()
                        }
                }
            }
        }
        .sheet(isPresented: $showingUnlockConfirmation) {
            SacredSpeechConfirmationView(isPresented: $showingUnlockConfirmation) {
                // Success action
            } onCancel: {
                // Cancel action
            }
        }
        .onAppear {
            // Track focus feature viewed
            AnalyticsService.shared.trackFocusBlockingViewed()

            guard subscriptionService.hasPremiumAccess else { return }
            screenTimeAuth.updateAuthorizationStatus()
            fetchPrayerTimesIfNeeded()
            focusManager.ensureInitialSchedulingIfNeeded()
        }
        .onChange(of: subscriptionService.hasPremiumAccess) { isPremium in
            if isPremium {
                screenTimeAuth.updateAuthorizationStatus()
            }
        }
        .alert("Screen Time Error", isPresented: $screenTimeAuth.showErrorAlert) {
            Button("OK", role: .cancel) {
                screenTimeAuth.clearError()
            }
        } message: {
            if let error = screenTimeAuth.lastError {
                Text("\(error.errorDescription ?? "An error occurred.")\n\n\(error.recoverySuggestion)")
            } else {
                Text("An error occurred while requesting Screen Time permission. You can try again later in Settings.")
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Sacred Header
                VStack(spacing: RS.spacing(12)) {
                    Text("FOCUS")
                        .font(.system(size: RS.fontSize(11), weight: .medium))
                        .tracking(3)
                        .foregroundColor(warmGray)

                    Text("Prayer Time Blocking")
                        .font(.system(size: RS.fontSize(28), weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Stay present during your prayers")
                        .font(.system(size: RS.fontSize(14), weight: .light))
                        .foregroundColor(warmGray)
                }
                .padding(.top, RS.spacing(24))
                .padding(.bottom, RS.spacing(32))

                VStack(spacing: RS.spacing(20)) {
                    // Setup progress banner
                    if blockingStateService.isSchedulingBlocking {
                        SacredSetupProgressBanner()
                    }

                    // Loading indicator
                    if focusManager.isUpdating {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Updating schedule...")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(warmGray)
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }

                    // Settings locked banner
                    if (blockingStateService.isCurrentlyBlocking || blockingStateService.appsActuallyBlocked) && !blockingStateService.isEarlyUnlockedActive {
                        SacredSettingsLockedBanner()
                    }

                    // Voice confirmation section
                    VoiceConfirmationView(blockingState: blockingStateService)

                    // Early unlock section
                    SacredEarlyUnlockSection()

                    // Today's Schedule (reads from actual saved blocking schedule)
                    SacredTodayScheduleSection(
                        isLocked: (blockingStateService.isCurrentlyBlocking || blockingStateService.appsActuallyBlocked) && !blockingStateService.isEarlyUnlockedActive
                    )
                    .padding(.horizontal, RS.horizontalPadding)

                    // Select Prayers
                    SacredPrayerToggleSection(
                        focusManager: focusManager,
                        showOverlayWhenEmpty: true,
                        onSelectApps: {
                            Task {
                                let success = await screenTimeAuth.requestAuthorizationIfNeededWithErrorHandling()
                                if success {
                                    await MainActor.run {
                                        showingAppPicker = true
                                    }
                                }
                            }
                        }
                    )
                    .padding(.horizontal, RS.horizontalPadding)

                    // Blocking Duration
                    SacredBlockingDurationView(duration: $focusManager.blockingDuration)
                        .padding(.horizontal, RS.horizontalPadding)

                    // Pre-Prayer Buffer
                    SacredPrePrayerBufferView(buffer: $focusManager.prePrayerBuffer)
                        .padding(.horizontal, RS.horizontalPadding)

                    // App Selection
                    SacredSelectAppsView {
                        Task {
                            let success = await screenTimeAuth.requestAuthorizationIfNeededWithErrorHandling()
                            if success {
                                await MainActor.run {
                                    showingAppPicker = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, RS.horizontalPadding)

                    // Screen Time denied warning
                    if screenTimeAuth.authorizationStatus == .denied {
                        SacredScreenTimeWarning()
                            .padding(.horizontal, RS.horizontalPadding)
                    }

                    // Additional Settings
                    SacredAdditionalSettingsView(
                        strictMode: $focusManager.strictMode,
                        prePrayerNotification: $focusManager.prayerRemindersEnabled,
                        showingConfirmationSheet: $showingUnlockConfirmation
                    )
                    .padding(.horizontal, RS.horizontalPadding)
                }
                .padding(.bottom, RS.spacing(40))
            }
        }
    }

    // MARK: - Prayer Time Fetching Methods

    private func scheduleNotificationsIfNeeded() {
        guard !prayerTimes.isEmpty else { return }
        notificationService.schedulePrePrayerNotifications(
            prayerTimes: prayerTimes,
            selectedPrayers: focusManager.getSelectedPrayers(),
            isEnabled: focusManager.prayerRemindersEnabled,
            minutesBefore: 5
        )
    }

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
        if prayerStorage == nil {
            prayerStorage = prayerTimeService.loadStorage()
        }

        let shouldFetch: Bool
        if let storage = prayerStorage {
            shouldFetch = storage.shouldRefresh
            if !shouldFetch {
                loadPrayerTimesFromStorage(storage)
                checkRollingWindowUpdate()
                return
            }
        } else {
            shouldFetch = true
        }

        if shouldFetch {
            fetchPrayerTimes()
        } else {
            if let storage = prayerStorage {
                loadPrayerTimesFromStorage(storage)
            }
        }
    }

    private func fetchPrayerTimes() {
        isLoadingPrayerTimes = true
        prayerTimesError = nil

        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationAndFetchPrayerTimes()
        case .notDetermined:
            locationService.requestLocationPermission()
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
        if let location = locationService.location {
            fetchPrayerTimesForLocation(location)
            return
        }

        locationService.$location
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { location in
                self.fetchPrayerTimesForLocation(location)
            }
            .store(in: &cancellables)

        locationService.requestLocation()

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
                if let storage = prayerStorage ?? prayerTimeService.loadStorage() {
                    if !storage.shouldRefresh {
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

                let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location)
                prayerTimeService.saveStorage(storage)
                prayerStorage = storage

                await MainActor.run {
                    self.loadPrayerTimesFromStorage(storage)
                    self.isLoadingPrayerTimes = false
                    self.prayerTimesError = nil
                    self.lastPrayerTimeFetch = Date()
                    self.scheduleNotificationsIfNeeded()
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
        }
    }

    private func scheduleRollingWindowFromStorage() {
        guard let storage = prayerStorage else { return }
        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: focusManager.blockingDuration,
            selectedPrayers: focusManager.getSelectedPrayers(),
            prePrayerBuffer: focusManager.prePrayerBuffer
        )
    }
}

// MARK: - Sacred Setup Progress Banner

private struct SacredSetupProgressBanner: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
                .tint(sacredGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("Setting Up Prayer Blocking")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Fetching prayer times and scheduling...")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .transition(.opacity)
    }
}

// MARK: - Sacred Settings Locked Banner

private struct SacredSettingsLockedBanner: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16))
                .foregroundColor(sacredGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings Locked")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Settings cannot be changed while apps are blocked")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Sacred Early Unlock Section

private struct SacredEarlyUnlockSection: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshTimer: Timer?

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Group {
            if !blocking.isStrictModeEnabled && blocking.appsActuallyBlocked {
                let remaining = blocking.timeUntilEarlyUnlock()

                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                            .frame(width: 72, height: 72)

                        Circle()
                            .fill(sacredGold.opacity(0.1))
                            .frame(width: 64, height: 64)

                        Image(systemName: remaining > 0 ? "hourglass" : "lock.open")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(sacredGold)
                    }

                    // Content
                    VStack(spacing: 12) {
                        Text("EARLY UNLOCK")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(2)
                            .foregroundColor(warmGray)

                        if remaining > 0 {
                            Text("Available in")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(themeManager.theme.secondaryText)

                            Text(remaining.formattedForCountdown)
                                .font(.system(size: 44, weight: .ultraLight))
                                .monospacedDigit()
                                .foregroundColor(sacredGold)
                        } else {
                            Text("Ready to unlock")
                                .font(.system(size: 16, weight: .light, design: .serif))
                                .foregroundColor(themeManager.theme.primaryText)

                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                blocking.earlyUnlockCurrentInterval()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.open")
                                        .font(.system(size: 15, weight: .light))
                                    Text("Unlock Apps Now")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(themeManager.effectiveTheme == .dark ? Color.black : Color.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(sacredGold)
                                )
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .onAppear {
                    refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
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

// MARK: - Sacred Today Schedule Section

private struct SacredTodayScheduleSection: View {
    let isLocked: Bool

    @StateObject private var themeManager = ThemeManager.shared
    @State private var refreshTrigger = UUID() // Forces re-read from UserDefaults
    @State private var cachedPrayers: [ScheduledPrayer] = []
    @State private var isShowingTomorrow: Bool = false

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Represents a scheduled prayer from the saved blocking schedule
    private struct ScheduledPrayer: Identifiable {
        let id = UUID()
        let name: String
        let blockingStartTime: Date
        let durationSeconds: Double
        let isPast: Bool
    }

    /// Result of loading scheduled prayers - includes which day they're for
    private struct ScheduleLoadResult {
        let prayers: [ScheduledPrayer]
        let isForTomorrow: Bool
    }

    /// Read scheduled prayers - today's first (including past ones grayed out), then tomorrow's after all today's are done
    private func loadScheduledPrayers() -> ScheduleLoadResult {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
              let schedules = groupDefaults.object(forKey: "PrayerTimeSchedules") as? [[String: Any]] else {
            return ScheduleLoadResult(prayers: [], isForTomorrow: false)
        }

        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return ScheduleLoadResult(prayers: [], isForTomorrow: false)
        }

        // Convert all schedules to ScheduledPrayer with their dates
        func makePrayer(from schedule: [String: Any]) -> ScheduledPrayer? {
            guard let name = schedule["name"] as? String,
                  let timestamp = schedule["date"] as? TimeInterval,
                  let duration = schedule["duration"] as? Double else {
                return nil
            }
            let blockingStart = Date(timeIntervalSince1970: timestamp)
            let blockingEnd = blockingStart.addingTimeInterval(duration)
            // Prayer is past if blocking period has ended
            let isPast = now > blockingEnd
            return ScheduledPrayer(
                name: name,
                blockingStartTime: blockingStart,
                durationSeconds: duration,
                isPast: isPast
            )
        }

        // Get all today's prayers (including past ones)
        let todayPrayers = schedules.compactMap { makePrayer(from: $0) }
            .filter { calendar.isDate($0.blockingStartTime, inSameDayAs: today) }
            .sorted { $0.blockingStartTime < $1.blockingStartTime }

        // Check if ALL today's prayers are past (switch to tomorrow after Isha is done)
        let allTodayPast = !todayPrayers.isEmpty && todayPrayers.allSatisfy { $0.isPast }

        if !todayPrayers.isEmpty && !allTodayPast {
            return ScheduleLoadResult(prayers: todayPrayers, isForTomorrow: false)
        }

        // If no today prayers or all are past, show tomorrow's
        let tomorrowPrayers = schedules.compactMap { makePrayer(from: $0) }
            .filter { calendar.isDate($0.blockingStartTime, inSameDayAs: tomorrow) }
            .sorted { $0.blockingStartTime < $1.blockingStartTime }

        // If we have tomorrow prayers, show them; otherwise show today's (all past)
        if !tomorrowPrayers.isEmpty {
            return ScheduleLoadResult(prayers: tomorrowPrayers, isForTomorrow: true)
        }

        // Fallback: show today's prayers even if all past
        return ScheduleLoadResult(prayers: todayPrayers, isForTomorrow: false)
    }

    /// Get the set of prayer names that are scheduled for today
    private var scheduledPrayerNames: Set<String> {
        Set(cachedPrayers.map { $0.name })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(isShowingTomorrow ? "TOMORROW'S SCHEDULE" : "TODAY'S SCHEDULE")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Spacer()

                if scheduledPrayerNames.count == 5 {
                    Text("All active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(softGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(softGreen.opacity(0.15))
                        )
                } else if scheduledPrayerNames.isEmpty {
                    Text("No prayers scheduled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(warmGray.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(warmGray.opacity(0.1))
                        )
                }
            }

            // Content
            VStack(spacing: 0) {
                // Date with tomorrow indicator
                HStack {
                    if isShowingTomorrow {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        Text(tomorrow, style: .date)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(warmGray)
                    } else {
                        Text(Date(), style: .date)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(warmGray)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

                if cachedPrayers.isEmpty {
                    // No schedules - show placeholder for all prayers
                    ForEach(["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"], id: \.self) { prayerName in
                        SacredPrayerScheduleRow(
                            prayerName: prayerName,
                            time: "Not scheduled",
                            duration: 0,
                            isEnabled: false,
                            isLocked: isLocked,
                            isPast: false
                        )
                        if prayerName != "Isha" {
                            Divider()
                                .background(warmGray.opacity(0.2))
                                .padding(.horizontal, 16)
                        }
                    }
                } else {
                    // Show scheduled prayers from saved schedule
                    ForEach(Array(cachedPrayers.enumerated()), id: \.element.id) { index, prayer in
                        SacredPrayerScheduleRow(
                            prayerName: prayer.name,
                            time: timeFormatter.string(from: prayer.blockingStartTime),
                            duration: prayer.durationSeconds / 60, // Convert to minutes for display
                            isEnabled: true,
                            isLocked: isLocked,
                            isPast: prayer.isPast
                        )
                        if index < cachedPrayers.count - 1 {
                            Divider()
                                .background(warmGray.opacity(0.2))
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .onAppear {
            let result = loadScheduledPrayers()
            cachedPrayers = result.prayers
            isShowingTomorrow = result.isForTomorrow
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PrayerScheduleUpdated"))) { _ in
            let result = loadScheduledPrayers()
            cachedPrayers = result.prayers
            isShowingTomorrow = result.isForTomorrow
        }
        .id(refreshTrigger) // Force view identity change when trigger changes
    }
}

// MARK: - Sacred Prayer Schedule Row

private struct SacredPrayerScheduleRow: View {
    let prayerName: String
    let time: String
    let duration: Double
    let isEnabled: Bool
    let isLocked: Bool
    let isPast: Bool

    @StateObject private var themeManager = ThemeManager.shared

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private func prayerIcon(for name: String) -> String {
        switch name {
        case "Fajr": return "sun.haze"
        case "Dhuhr": return "sun.max"
        case "Asr": return "cloud.sun"
        case "Maghrib": return "moon"
        case "Isha": return "moon.stars"
        default: return "sparkles"
        }
    }

    /// Effective opacity based on enabled state, locked state, and past state
    private var effectiveOpacity: Double {
        if isPast {
            return 0.4
        }
        if isLocked {
            return 0.5
        }
        return isEnabled ? 1.0 : 0.5
    }

    var body: some View {
        HStack {
            Image(systemName: isPast ? "checkmark.circle.fill" : prayerIcon(for: prayerName))
                .font(.system(size: 14, weight: .light))
                .foregroundColor(isPast ? warmGray.opacity(0.5) : (isEnabled && !isLocked ? softGreen : warmGray.opacity(0.5)))
                .frame(width: 24)

            Text(prayerName)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.theme.primaryText)
                .opacity(effectiveOpacity)
                .strikethrough(isPast, color: warmGray.opacity(0.5))
                .frame(width: 70, alignment: .leading)

            Text(time)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(warmGray)
                .opacity(effectiveOpacity)
                .strikethrough(isPast, color: warmGray.opacity(0.5))

            Spacer()

            if isPast {
                Text("Done")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(softGreen.opacity(0.6))
            } else {
                Text("\(Int(duration)) min")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(warmGray)
                    .opacity(effectiveOpacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Sacred Prayer Toggle Section

private struct SacredPrayerToggleSection: View {
    @ObservedObject var focusManager: FocusSettingsManager
    let showOverlayWhenEmpty: Bool
    let onSelectApps: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var isDisabled: Bool {
        (blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked) && !blockingState.isEarlyUnlockedActive
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("SELECT PRAYERS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                VStack(spacing: 0) {
                    SacredPrayerToggleRow(
                        prayerName: "Fajr",
                        arabicName: "الفجر",
                        icon: "sun.haze",
                        isSelected: $focusManager.selectedFajr
                    )
                    .disabled(!focusManager.hasAppsSelected || isDisabled)
                    .opacity(focusManager.hasAppsSelected && !isDisabled ? 1.0 : 0.5)

                    Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                    SacredPrayerToggleRow(
                        prayerName: "Dhuhr",
                        arabicName: "الظهر",
                        icon: "sun.max",
                        isSelected: $focusManager.selectedDhuhr
                    )
                    .disabled(!focusManager.hasAppsSelected || isDisabled)
                    .opacity(focusManager.hasAppsSelected && !isDisabled ? 1.0 : 0.5)

                    Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                    SacredPrayerToggleRow(
                        prayerName: "Asr",
                        arabicName: "العصر",
                        icon: "cloud.sun",
                        isSelected: $focusManager.selectedAsr
                    )
                    .disabled(!focusManager.hasAppsSelected || isDisabled)
                    .opacity(focusManager.hasAppsSelected && !isDisabled ? 1.0 : 0.5)

                    Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                    SacredPrayerToggleRow(
                        prayerName: "Maghrib",
                        arabicName: "المغرب",
                        icon: "moon",
                        isSelected: $focusManager.selectedMaghrib
                    )
                    .disabled(!focusManager.hasAppsSelected || isDisabled)
                    .opacity(focusManager.hasAppsSelected && !isDisabled ? 1.0 : 0.5)

                    Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                    SacredPrayerToggleRow(
                        prayerName: "Isha",
                        arabicName: "العشاء",
                        icon: "moon.stars",
                        isSelected: $focusManager.selectedIsha
                    )
                    .disabled(!focusManager.hasAppsSelected || isDisabled)
                    .opacity(focusManager.hasAppsSelected && !isDisabled ? 1.0 : 0.5)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                        )
                )
            }

            // Overlay when no apps selected
            if !focusManager.hasAppsSelected && showOverlayWhenEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(sacredGold)

                    VStack(spacing: 8) {
                        Text("Select apps first")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Choose which apps to block during prayer times")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(warmGray)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: onSelectApps) {
                        HStack(spacing: 8) {
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 14))
                            Text("Select Apps")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(themeManager.effectiveTheme == .dark ? Color.black : Color.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(sacredGold)
                        )
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground.opacity(0.98))
                )
            }
        }
    }
}

// MARK: - Sacred Prayer Toggle Row

private struct SacredPrayerToggleRow: View {
    let prayerName: String
    let arabicName: String
    let icon: String
    @Binding var isSelected: Bool

    @StateObject private var themeManager = ThemeManager.shared

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(isSelected ? softGreen : warmGray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(prayerName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(arabicName)
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundColor(warmGray)
            }

            Spacer()

            Toggle("", isOn: $isSelected)
                .toggleStyle(SwitchToggleStyle(tint: softGreen))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Sacred Blocking Duration View

private struct SacredBlockingDurationView: View {
    @Binding var duration: Double
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var isDisabled: Bool {
        (blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked) && !blockingState.isEarlyUnlockedActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BLOCKING DURATION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Text("Time after prayer starts")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray.opacity(0.8))
            }

            VStack(spacing: 16) {
                HStack {
                    Text("Block apps for")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)
                    Spacer()
                    Text("\(Int(duration)) min")
                        .font(.system(size: 18, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }

                HStack(spacing: 10) {
                    SacredDurationButton(value: 15, current: Int(duration)) {
                        duration = 15
                    }
                    .disabled(isDisabled)

                    SacredDurationButton(value: 20, current: Int(duration)) {
                        duration = 20
                    }
                    .disabled(isDisabled)

                    SacredDurationButton(value: 30, current: Int(duration)) {
                        duration = 30
                    }
                    .disabled(isDisabled)

                    SacredCustomDurationButton(current: Int(duration)) { customValue in
                        duration = Double(customValue)
                    }
                    .disabled(isDisabled)
                }
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Sacred Duration Button

private struct SacredDurationButton: View {
    let value: Int
    let current: Int
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var isSelected: Bool {
        current == value
    }

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(.system(size: 15, weight: isSelected ? .medium : .light))
                .foregroundColor(isSelected ? (themeManager.effectiveTheme == .dark ? .black : .white) : themeManager.theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? sacredGold : warmGray.opacity(0.15))
                )
        }
    }
}

// MARK: - Sacred Custom Duration Button

private struct SacredCustomDurationButton: View {
    let current: Int
    let onSet: (Int) -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingInput = false
    @State private var customValue = ""

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

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
                    .font(.system(size: 12, weight: .light))
                if isCustomValue {
                    Text("\(current)")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundColor(isCustomValue ? (themeManager.effectiveTheme == .dark ? .black : .white) : themeManager.theme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCustomValue ? sacredGold : warmGray.opacity(0.15))
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

// MARK: - Sacred Pre-Prayer Buffer View

private struct SacredPrePrayerBufferView: View {
    @Binding var buffer: Double
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var isDisabled: Bool {
        (blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked) && !blockingState.isEarlyUnlockedActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRE-PRAYER FOCUS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Text("Start blocking before prayer time to prepare")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray.opacity(0.8))
            }

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(sacredGold)

                    Text("Buffer Time")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Spacer()

                    Text(buffer == 0 ? "Off" : "\(Int(buffer)) min before")
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundColor(buffer == 0 ? warmGray : sacredGold)
                }

                HStack(spacing: 10) {
                    SacredBufferButton(value: 0, current: Int(buffer)) {
                        buffer = 0
                    }
                    .disabled(isDisabled)

                    SacredBufferButton(value: 5, current: Int(buffer)) {
                        buffer = 5
                    }
                    .disabled(isDisabled)

                    SacredBufferButton(value: 10, current: Int(buffer)) {
                        buffer = 10
                    }
                    .disabled(isDisabled)

                    SacredBufferButton(value: 15, current: Int(buffer)) {
                        buffer = 15
                    }
                    .disabled(isDisabled)
                }
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Sacred Buffer Button

private struct SacredBufferButton: View {
    let value: Int
    let current: Int
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var isSelected: Bool {
        current == value
    }

    var body: some View {
        Button(action: action) {
            Text(value == 0 ? "Off" : "\(value)")
                .font(.system(size: 15, weight: isSelected ? .medium : .light))
                .foregroundColor(isSelected ? (themeManager.effectiveTheme == .dark ? .black : .white) : themeManager.theme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? sacredGold : warmGray.opacity(0.15))
                )
        }
    }
}

// MARK: - Sacred Select Apps View

private struct SacredSelectAppsView: View {
    @StateObject private var appModel = AppSelectionModel.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var blockingState = BlockingStateService.shared
    var onSelectTapped: () -> Void

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var isDisabled: Bool {
        (blockingState.isCurrentlyBlocking || blockingState.appsActuallyBlocked) && !blockingState.isEarlyUnlockedActive
    }

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("APP SELECTION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Spacer()

                Button(action: onSelectTapped) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12, weight: .light))
                        Text("Add/Remove")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isDisabled ? warmGray.opacity(0.5) : sacredGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(sacredGold.opacity(isDisabled ? 0.05 : 0.15))
                    )
                }
                .disabled(isDisabled)
            }

            VStack(spacing: 16) {
                if !appModel.selection.applicationTokens.isEmpty || !appModel.selection.categoryTokens.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(Array(appModel.selection.applicationTokens), id: \.self) { token in
                            SacredAppIconView(token: token)
                        }
                        ForEach(Array(appModel.selection.categoryTokens), id: \.self) { token in
                            SacredCategoryIconView(token: token)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "apps.iphone.badge.plus")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(warmGray)

                        Text("No apps selected")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(warmGray)

                        Text("Tap Add/Remove to select apps to block")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(warmGray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Sacred App Icon View

private struct SacredAppIconView: View {
    let token: ApplicationToken

    var body: some View {
        Label(token)
            .labelStyle(.iconOnly)
            .scaleEffect(1.8)
            .frame(width: 44, height: 44)
    }
}

// MARK: - Sacred Category Icon View

private struct SacredCategoryIconView: View {
    let token: ActivityCategoryToken

    var body: some View {
        Label(token)
            .labelStyle(.iconOnly)
            .scaleEffect(1.8)
            .frame(width: 44, height: 44)
    }
}

// MARK: - Sacred Screen Time Warning

private struct SacredScreenTimeWarning: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SCREEN TIME ACCESS")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(warmGray)

            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(sacredGold)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Screen Time Access Required")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(sacredGold)

                    Text("Enable Screen Time access in Settings to use prayer blocking")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(warmGray)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Sacred Additional Settings View

private struct SacredAdditionalSettingsView: View {
    @Binding var strictMode: Bool
    @Binding var prePrayerNotification: Bool
    @Binding var showingConfirmationSheet: Bool
    @EnvironmentObject var speechService: SpeechRecognitionService
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var notificationService = PrayerNotificationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var focusManager = FocusSettingsManager.shared
    @State private var showingPermissionDeniedAlert = false
    @State private var showingNotificationDeniedAlert = false
    // Haya Mode alerts
    @State private var showingHayaModeEnableAlert = false
    @State private var showingHayaModeDisableStep1Alert = false
    @State private var showingHayaModeDisableStep2Alert = false
    // Timer for Haya Mode countdown
    private let hayaModeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var isDisabled: Bool {
        (blocking.isCurrentlyBlocking || blocking.appsActuallyBlocked) && !blocking.isEarlyUnlockedActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADDITIONAL SETTINGS")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(warmGray)

            VStack(spacing: 0) {
                // Strict Mode
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strict Mode")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Prevent early unblocking")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(warmGray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { strictMode },
                        set: { newValue in
                            if blocking.canToggleStrictMode && !isDisabled {
                                if newValue {
                                    if speechService.isPermissionDenied {
                                        showingPermissionDeniedAlert = true
                                        return
                                    }
                                    if !speechService.hasPermissions {
                                        strictMode = true
                                        speechService.requestPermissions { granted in
                                            if !granted {
                                                strictMode = false
                                            }
                                        }
                                    } else {
                                        strictMode = true
                                    }
                                } else {
                                    strictMode = false
                                }
                            }
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: softGreen))
                    .disabled(!blocking.canToggleStrictMode || isDisabled)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .opacity(isDisabled ? 0.5 : 1.0)

                Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                // Haya Mode - Adult Content Filter
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Haya Mode")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        if focusManager.hayaModeDisablePending {
                            Text("Disabling in \(focusManager.hayaModeTimeUntilDisableFormatted)")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(sacredGold)
                        } else {
                            Text("Block adult content")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(warmGray)
                        }
                    }

                    Spacer()

                    if focusManager.hayaModeDisablePending {
                        // Show cancel button when disable is pending
                        Button(action: {
                            focusManager.cancelHayaModeDisableRequest()
                        }) {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(sacredGold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(sacredGold.opacity(0.15))
                                .cornerRadius(8)
                        }
                    } else {
                        Toggle("", isOn: Binding(
                            get: { focusManager.hayaMode },
                            set: { newValue in
                                if newValue {
                                    // Trying to enable - show warning first
                                    showingHayaModeEnableAlert = true
                                } else {
                                    // Trying to disable - show guilt warning first
                                    showingHayaModeDisableStep1Alert = true
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: softGreen))
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(warmGray.opacity(0.2)).padding(.horizontal, 16)

                // Pre-Prayer Notification
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pre-Prayer Notification")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        if notificationService.hasNotificationPermission {
                            Text("5 min reminder before blocking")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(warmGray)
                        } else {
                            Text("Tap to enable notifications")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(sacredGold)
                        }
                    }

                    Spacer()

                    if notificationService.isRequestingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(sacredGold)
                    } else {
                        Toggle("", isOn: Binding(
                            get: { prePrayerNotification && notificationService.hasNotificationPermission },
                            set: { newValue in
                                guard !isDisabled else { return }
                                if newValue && !notificationService.hasNotificationPermission {
                                    if notificationService.isNotificationPermissionDenied {
                                        showingNotificationDeniedAlert = true
                                        return
                                    }
                                    Task {
                                        let granted = await notificationService.requestNotificationPermission()
                                        if granted {
                                            await MainActor.run {
                                                prePrayerNotification = true
                                            }
                                            if let storage = PrayerTimeService().loadStorage() {
                                                let prayerTimes = focusManager.parsePrayerTimesPublic(from: storage)
                                                PrayerNotificationService.shared.schedulePrePrayerNotifications(
                                                    prayerTimes: prayerTimes,
                                                    selectedPrayers: focusManager.getSelectedPrayers(),
                                                    isEnabled: true,
                                                    minutesBefore: 5
                                                )
                                            }
                                        } else {
                                            notificationService.checkPermissionStatus()
                                        }
                                    }
                                } else {
                                    prePrayerNotification = newValue
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: softGreen))
                        .disabled(isDisabled)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .opacity(isDisabled ? 0.5 : 1.0)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Strict mode requires microphone and speech recognition permissions. Please enable them in Settings.")
        }
        .alert("Notification Permission Required", isPresented: $showingNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Pre-prayer notifications require notification permissions. Please enable them in Settings.")
        }
        // Haya Mode - Enable Warning
        .alert("Enable Haya Mode?", isPresented: $showingHayaModeEnableAlert) {
            Button("Enable", role: .destructive) {
                focusManager.hayaMode = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Haya Mode blocks adult content to help you maintain modesty and focus.\n\nOnce enabled, it takes 48 hours to disable. This waiting period helps you stay committed during moments of weakness.")
        }
        // Haya Mode - Disable Step 1 (Guilt)
        .alert("Remember Your Intention", isPresented: $showingHayaModeDisableStep1Alert) {
            Button("I Still Want to Disable", role: .destructive) {
                showingHayaModeDisableStep2Alert = true
            }
            Button("Keep It On", role: .cancel) { }
        } message: {
            Text("You enabled Haya Mode to protect yourself from content that distances you from Allah.\n\n\"Indeed, Allah is with those who are patient.\" - Quran 2:153\n\nAre you sure you want to disable this protection?")
        }
        // Haya Mode - Disable Step 2 (48hr Notice)
        .alert("48-Hour Waiting Period", isPresented: $showingHayaModeDisableStep2Alert) {
            Button("Start 48hr Countdown", role: .destructive) {
                focusManager.requestHayaModeDisable()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To help you overcome momentary temptation, Haya Mode will remain active for 48 more hours.\n\nIf you still want it disabled after this period, it will turn off automatically.")
        }
        .onReceive(hayaModeTimer) { _ in
            // Check if 48 hours have passed and complete disable if ready
            if focusManager.hayaModeDisablePending {
                focusManager.completeHayaModeDisableIfReady()
            }
        }
        .onAppear {
            // Check on appear in case 48 hours passed while view was not visible
            if focusManager.hayaModeDisablePending {
                focusManager.completeHayaModeDisableIfReady()
            }
        }
    }
}

// MARK: - Sacred Speech Confirmation View

private struct SacredSpeechConfirmationView: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Text("Confirm You've Prayed")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("To unblock your apps, please say 'wallahi i prayed'.")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(warmGray)
                    .multilineTextAlignment(.center)

                Text("Mock transcript: wallahi i prayed")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundColor(sacredGold)

                Button(action: {}) {
                    Image(systemName: "mic.circle")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        onSuccess()
                        isPresented = false
                    }) {
                        Text("Confirm")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(softGreen)
                            )
                    }

                    Button(action: {
                        onCancel()
                        isPresented = false
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(warmGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(warmGray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }
}

// MARK: - Sacred Screen Time Permission Overlay

private struct SacredScreenTimePermissionOverlay: View {
    @ObservedObject var screenTimeAuth: ScreenTimeAuthorizationService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isRequesting = false

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        ZStack {
            pageBackground.opacity(0.98)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                        .frame(width: 120, height: 120)

                    Image(systemName: "hourglass.circle")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }

                // Title
                VStack(spacing: 12) {
                    Text("SCREEN TIME")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundColor(warmGray)

                    Text("Permission Required")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)
                }

                // Description
                VStack(spacing: 20) {
                    Text("To use Focus Mode and block apps during prayer times, Khushoo needs Screen Time permission.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(warmGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    // Benefits
                    VStack(alignment: .leading, spacing: 14) {
                        FocusBenefitRow(icon: "iphone.slash", text: "Block distracting apps automatically")
                        FocusBenefitRow(icon: "clock", text: "Set custom blocking durations")
                        FocusBenefitRow(icon: "checkmark.shield", text: "Stay focused during prayer times")
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Action Button
                VStack(spacing: 16) {
                    Button(action: {
                        isRequesting = true
                        Task {
                            let _ = await screenTimeAuth.requestAuthorizationWithErrorHandling()
                            isRequesting = false
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.effectiveTheme == .dark ? .black : .white))
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 18, weight: .light))
                            }

                            Text(isRequesting ? "Requesting..." : "Enable Screen Time")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(sacredGold)
                        )
                    }
                    .disabled(isRequesting)

                    Text("You can also enable this later in Settings")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(warmGray)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .alert("Screen Time Error", isPresented: $screenTimeAuth.showErrorAlert) {
            Button("OK", role: .cancel) {
                screenTimeAuth.clearError()
            }
        } message: {
            if let error = screenTimeAuth.lastError {
                Text("\(error.errorDescription ?? "An error occurred.")\n\n\(error.recoverySuggestion)")
            } else {
                Text("An error occurred while requesting Screen Time permission. You can try again later in Settings.")
            }
        }
    }
}

// MARK: - Focus Benefit Row

private struct FocusBenefitRow: View {
    let icon: String
    let text: String

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(sacredGold)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(ScreenTimeAuthorizationService.shared)
        .environmentObject(SpeechRecognitionService())
        .environmentObject(LocationService())
}
