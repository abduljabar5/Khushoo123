import SwiftUI
import DeviceActivity
import FamilyControls
import CoreLocation
import UserNotifications
import ManagedSettings
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct DhikrApp: App {

    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }
    
    // Connect AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment Objects
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared

    // Scene Phase
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainContentView(locationService: locationService)
                .environmentObject(dhikrService)
                .environmentObject(audioPlayerService)
                .environmentObject(bluetoothService)
                .environmentObject(quranAPIService)
                .environmentObject(favoritesManager)
                .environmentObject(locationService)
                .environmentObject(screenTimeAuth)
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(speechService)
                .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.currentTheme == .dark ? .dark : .light))
                .onAppear {
                    setupPerformanceOptimizations()
                    setupNotificationDelegate()
                    setupWindowBackground()

                    // Migrate existing users to new app selection validation
                    migrateAppSelectionValidation()

                    // Prioritize audio service for immediate UI responsiveness
                    audioPlayerService.activate()

                    // Fetch 6-month prayer times on app launch
                    fetch6MonthPrayerTimesOnLaunch()

                    // Setup premium listener for background fetches
                    setupPremiumListener()

                    // Preload last played audio in background for instant continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        audioPlayerService.preloadLastPlayed()
                    }

                    // Ensure blocking state is evaluated immediately on launch and shortly after
                    BlockingStateService.shared.forceCheck()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        BlockingStateService.shared.forceCheck()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        BlockingStateService.shared.forceCheck()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onChange(of: themeManager.currentTheme) { _ in
                    setupWindowBackground()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    handleMemoryPressure()
                }
        }
    }
    
    // Background task setup removed; early stop logic no longer used
    
    // MARK: - Performance Optimizations
    private func setupPerformanceOptimizations() {
        // Initialize image cache manager
        _ = ImageCacheManager.shared
        
        print("🚀 [DhikrApp] Performance optimizations initialized")
    }
    
    // MARK: - Notification Setup
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        // Note: Notification permissions are requested during onboarding (OnboardingPermissionsView)
        // or when user enables them in settings - not automatically on app launch
    }

    // MARK: - Window Background Setup
    private func setupWindowBackground() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            // Set window background to match theme
            switch themeManager.currentTheme {
            case .auto:
                // Use system background for auto mode
                window.backgroundColor = UIColor.systemBackground
            case .dark:
                window.backgroundColor = UIColor(Color(hex: "1E3A5F"))
            case .light:
                window.backgroundColor = UIColor.systemBackground
            }
        }
    }
    

    

    

    

     

     
     private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📲 App entering background")
            audioPlayerService.saveLastPlayed()

            // Save pending dhikr entries to disk
            dhikrService.savePendingData()

            // Check blocking state immediately when app goes to background
            BlockingStateService.shared.forceCheck()
            print("✅ Force check triggered for background")

            // Clean up resources when app goes to background
            Task {
                await BackgroundTaskManager.shared.cancelAllTasks()
                ImageCacheManager.shared.clearExpiredDiskCache()
            }
            
        case .inactive:
            print("📲 App becoming inactive")
            // Check blocking state when app becomes inactive (user switching away)
            BlockingStateService.shared.forceCheck()
            
            // Prepare for potential memory pressure
            ImageCacheManager.shared.clearMemoryCache()
            
        case .active:
            print("📲 App became active")
            // App became active - check blocking state immediately
            BlockingStateService.shared.forceCheck()

            // If audio is playing, show full-screen player (for lock screen/control center taps)
            if audioPlayerService.isPlaying && audioPlayerService.currentSurah != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    audioPlayerService.shouldShowFullScreenPlayer = true
                }
            }
            break
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Migration

    private func migrateAppSelectionValidation() {
        let migrationKey = "didMigrateAppSelectionValidation_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            print("✅ [Migration] App selection validation already migrated")
            return
        }

        print("🔄 [Migration] Starting app selection validation migration...")

        // Check if user has prayers selected but no apps
        let selection = AppSelectionModel.shared.selection
        let hasSelectedApps = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty

        if !hasSelectedApps {
            // Check if any prayers were previously toggled on
            let focusManager = FocusSettingsManager.shared
            let hasPrayersEnabled = focusManager.selectedFajr ||
                                   focusManager.selectedDhuhr ||
                                   focusManager.selectedAsr ||
                                   focusManager.selectedMaghrib ||
                                   focusManager.selectedIsha

            if hasPrayersEnabled {
                print("⚠️ [Migration] Detected prayers enabled with no apps - clearing invalid state")

                // Clear all prayer selections (they were ineffective anyway)
                focusManager.selectedFajr = false
                focusManager.selectedDhuhr = false
                focusManager.selectedAsr = false
                focusManager.selectedMaghrib = false
                focusManager.selectedIsha = false

                // Stop any existing schedules
                DeviceActivityService.shared.stopAllMonitoring()

                print("✅ [Migration] Cleared invalid prayer selections and schedules")
            }
        }

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
        print("✅ [Migration] App selection validation migration complete")
    }

    private func handleMemoryPressure() {
        print("⚠️ [DhikrApp] Memory pressure detected - cleaning up resources")

        // Aggressive memory cleanup
        ImageCacheManager.shared.clearMemoryCache()

        // Cancel non-essential background tasks
        Task {
            await BackgroundTaskManager.shared.cancelAllTasks()
        }

        // Force garbage collection
        DispatchQueue.global(qos: .utility).async {
            // Trigger garbage collection by creating and releasing memory
            _ = Array(repeating: 0, count: 1000)
        }
    }

    // MARK: - Free User Cleanup

    private func cleanupAppBlockingForFreeUsers() {
        // Only run cleanup if user is not premium
        guard !subscriptionService.isPremium else {
            print("✅ [DhikrApp] User is premium - no cleanup needed")
            return
        }

        print("🧹 [DhikrApp] Free user detected - cleaning up app blocking...")

        // Stop all app blocking schedules
        DeviceActivityService.shared.stopAllMonitoring()

        // Turn off all prayer selections in both UserDefaults
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(false, forKey: "focusSelectedFajr")
            groupDefaults.set(false, forKey: "focusSelectedDhuhr")
            groupDefaults.set(false, forKey: "focusSelectedAsr")
            groupDefaults.set(false, forKey: "focusSelectedMaghrib")
            groupDefaults.set(false, forKey: "focusSelectedIsha")
            groupDefaults.set(false, forKey: "isPremiumUser") // Ensure premium flag is false
            groupDefaults.synchronize()
        }

        UserDefaults.standard.set(false, forKey: "focusSelectedFajr")
        UserDefaults.standard.set(false, forKey: "focusSelectedDhuhr")
        UserDefaults.standard.set(false, forKey: "focusSelectedAsr")
        UserDefaults.standard.set(false, forKey: "focusSelectedMaghrib")
        UserDefaults.standard.set(false, forKey: "focusSelectedIsha")

        print("✅ [DhikrApp] App blocking cleaned up for free user")
    }

    // MARK: - Premium Listener Setup

    private func setupPremiumListener() {
        // Listen for user becoming premium
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserBecamePremium"),
            object: nil,
            queue: .main
        ) { _ in
            print("🎉 [DhikrApp] User became premium - starting background 6-month fetch...")

            Task {
                await self.fetch6MonthsForPremiumUser()
            }
        }

        // Listen for user losing premium
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserLostPremium"),
            object: nil,
            queue: .main
        ) { _ in
            print("⚠️ [DhikrApp] User lost premium - cleaning up app blocking...")

            // Stop all app blocking schedules
            DeviceActivityService.shared.stopAllMonitoring()

            // Turn off all prayer selections
            guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
            groupDefaults.set(false, forKey: "focusSelectedFajr")
            groupDefaults.set(false, forKey: "focusSelectedDhuhr")
            groupDefaults.set(false, forKey: "focusSelectedAsr")
            groupDefaults.set(false, forKey: "focusSelectedMaghrib")
            groupDefaults.set(false, forKey: "focusSelectedIsha")
            groupDefaults.set(false, forKey: "isPremiumUser") // Ensure premium flag is false
            groupDefaults.synchronize()

            // Also update main UserDefaults
            UserDefaults.standard.set(false, forKey: "focusSelectedFajr")
            UserDefaults.standard.set(false, forKey: "focusSelectedDhuhr")
            UserDefaults.standard.set(false, forKey: "focusSelectedAsr")
            UserDefaults.standard.set(false, forKey: "focusSelectedMaghrib")
            UserDefaults.standard.set(false, forKey: "focusSelectedIsha")

            print("✅ [DhikrApp] App blocking disabled for free user")
        }
    }

    private func fetch6MonthsForPremiumUser() async {
        print("📦 [DhikrApp] Fetching 6 months of prayer times for premium user...")

        let prayerTimeService = PrayerTimeService()

        // Check location permission
        guard locationService.authorizationStatus == .authorizedWhenInUse ||
              locationService.authorizationStatus == .authorizedAlways else {
            print("⚠️ [DhikrApp] Location not authorized - cannot fetch prayer times")
            return
        }

        // Request location
        locationService.requestLocation()
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        guard let location = locationService.location else {
            print("⚠️ [DhikrApp] Location not available")
            return
        }

        do {
            // Fetch 6 months
            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: 180)
            prayerTimeService.saveStorage(storage)

            print("✅ [DhikrApp] 6-month prayer times fetched successfully (\(storage.prayerTimes.count) days)")

            // Force reschedule app blocking if prayers are selected
            await forceRescheduleIfNeeded(storage: storage)

        } catch {
            print("❌ [DhikrApp] Failed to fetch 6-month prayer times: \(error)")
        }
    }

    private func forceRescheduleIfNeeded(storage: PrayerTimeStorage) async {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }

        // Check if any prayers are selected
        let selectedFajr = groupDefaults.bool(forKey: "focusSelectedFajr")
        let selectedDhuhr = groupDefaults.bool(forKey: "focusSelectedDhuhr")
        let selectedAsr = groupDefaults.bool(forKey: "focusSelectedAsr")
        let selectedMaghrib = groupDefaults.bool(forKey: "focusSelectedMaghrib")
        let selectedIsha = groupDefaults.bool(forKey: "focusSelectedIsha")

        let anyPrayerSelected = selectedFajr || selectedDhuhr || selectedAsr || selectedMaghrib || selectedIsha

        guard anyPrayerSelected else {
            print("ℹ️ [DhikrApp] No prayers selected - skipping reschedule")
            return
        }

        print("🔄 [DhikrApp] Prayers are selected - force rescheduling app blocking...")

        // Get settings
        let duration = groupDefaults.double(forKey: "focusBlockingDuration")
        let effectiveDuration = duration > 0 ? duration : 30.0

        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }

        // Schedule rolling window
        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: effectiveDuration,
            selectedPrayers: selectedPrayers
        )

        print("✅ [DhikrApp] App blocking rescheduled successfully")
    }

    // MARK: - 6-Month Prayer Time Fetch

    private func fetch6MonthPrayerTimesOnLaunch() {
        print("🔍 [DhikrApp] Checking if prayer times need to be fetched...")

        // Check if onboarding is complete before auto-requesting location
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Check if user is premium
        let isPremium = subscriptionService.isPremium

        Task {
            let prayerTimeService = PrayerTimeService()

            // Check if storage exists and is valid
            if let storage = prayerTimeService.loadStorage() {
                if storage.shouldRefresh {
                    if isPremium {
                        print("🔄 [DhikrApp] Premium user - fetching 6 months")
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                    } else {
                        print("🔄 [DhikrApp] Free user - fetching 3 days only")
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 3)
                    }
                } else {
                    print("✅ [DhikrApp] Storage is valid - no fetch needed")
                    // Check if rolling window needs update (only for premium users with app blocking)
                    if isPremium {
                        await checkAndUpdateRollingWindow(storage: storage)
                    }
                }
            } else {
                if isPremium {
                    print("🔍 [DhikrApp] No storage found - fetching 6 months (premium)")
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                } else {
                    print("🔍 [DhikrApp] No storage found - fetching 3 days (free)")
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 3)
                }
            }
        }
    }

    private func fetchPrayerTimesWithLocation(prayerTimeService: PrayerTimeService, skipPermissionRequest: Bool = false, daysToFetch: Int = 180) async {
        // Check location permission
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Has permission - get location
            locationService.requestLocation()

            // Wait for location
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if let location = locationService.location {
                await fetch6Months(prayerTimeService: prayerTimeService, location: location, daysToFetch: daysToFetch)
            } else {
                print("⚠️ [DhikrApp] Location not available yet - will fetch when available")
            }

        case .notDetermined:
            if skipPermissionRequest {
                print("📍 [DhikrApp] Location not determined - skipping auto-request (onboarding not complete)")
                return
            }

            print("📍 [DhikrApp] Requesting location permission...")
            locationService.requestLocationPermission()

            // Wait for permission response
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            if locationService.authorizationStatus == .authorizedWhenInUse ||
               locationService.authorizationStatus == .authorizedAlways {
                locationService.requestLocation()
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                if let location = locationService.location {
                    await fetch6Months(prayerTimeService: prayerTimeService, location: location, daysToFetch: daysToFetch)
                }
            } else {
                print("⚠️ [DhikrApp] Location permission denied - prayer times will not be fetched")
            }

        case .denied, .restricted:
            print("❌ [DhikrApp] Location permission denied - prayer times cannot be fetched")

        @unknown default:
            print("⚠️ [DhikrApp] Unknown location permission status")
        }
    }

    private func fetch6Months(prayerTimeService: PrayerTimeService, location: CLLocation, daysToFetch: Int = 180) async {
        do {
            print("🕌 [DhikrApp] Starting prayer time fetch (\(daysToFetch) days)...")

            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: daysToFetch)
            prayerTimeService.saveStorage(storage)

            print("✅ [DhikrApp] Prayer times fetched and saved successfully (\(storage.prayerTimes.count) days)")

            // Schedule rolling window (only for premium users with app blocking)
            if subscriptionService.isPremium {
                await scheduleRollingWindow(storage: storage)
            }

            // Also try initial scheduling for post-onboarding scenario
            // This handles the case where onboarding completed but prayer times weren't available yet
            await scheduleBlockingIfConditionsMet(storage: storage)

        } catch {
            print("❌ [DhikrApp] Failed to fetch prayer times: \(error.localizedDescription)")
        }
    }

    /// Schedule blocking if all conditions are met (post-onboarding scenario)
    /// This handles the case where user completed onboarding but prayer times weren't loaded yet
    private func scheduleBlockingIfConditionsMet(storage: PrayerTimeStorage) async {
        // Only proceed if onboarding is complete
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else {
            print("ℹ️ [DhikrApp] Onboarding not complete - skipping initial schedule check")
            return
        }

        // Check premium status
        guard subscriptionService.isPremium else {
            print("ℹ️ [DhikrApp] User not premium - skipping initial schedule")
            return
        }

        // Check if apps are selected
        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty
        guard hasAppsSelected else {
            print("ℹ️ [DhikrApp] No apps selected - skipping initial schedule")
            return
        }

        // Check if Screen Time is authorized
        guard await screenTimeAuth.isAuthorized else {
            print("ℹ️ [DhikrApp] Screen Time not authorized - skipping initial schedule")
            return
        }

        // Check if prayers are selected
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        let anyPrayerSelected = selectedFajr || selectedDhuhr || selectedAsr || selectedMaghrib || selectedIsha
        guard anyPrayerSelected else {
            print("ℹ️ [DhikrApp] No prayers selected - skipping initial schedule")
            return
        }

        // Check if we already have active schedules
        if let existingSchedules = groupDefaults?.object(forKey: "PrayerTimeSchedules") as? [[String: Any]],
           !existingSchedules.isEmpty {
            let now = Date()
            let hasFutureSchedules = existingSchedules.contains { schedule in
                guard let timestamp = schedule["date"] as? TimeInterval,
                      let duration = schedule["duration"] as? Double else { return false }
                let endTime = Date(timeIntervalSince1970: timestamp).addingTimeInterval(duration)
                return endTime > now
            }
            if hasFutureSchedules {
                print("✅ [DhikrApp] Active schedules already exist - skipping initial schedule")
                return
            }
        }

        // All conditions met - schedule blocking
        print("🚀 [DhikrApp] All conditions met - scheduling blocking after prayer times loaded")

        let duration = groupDefaults?.double(forKey: "focusBlockingDuration") ?? 15.0
        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }

        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: duration,
            selectedPrayers: selectedPrayers
        )

        print("✅ [DhikrApp] Initial blocking schedule created successfully")
    }

    private func checkAndUpdateRollingWindow(storage: PrayerTimeStorage) async {
        if DeviceActivityService.shared.needsRollingWindowUpdate() {
            print("🔄 [DhikrApp] Rolling window needs update")
            await scheduleRollingWindow(storage: storage)
        } else {
            print("✅ [DhikrApp] Rolling window is up to date")
        }
    }

    private func scheduleRollingWindow(storage: PrayerTimeStorage) async {
        print("📅 [DhikrApp] Scheduling rolling window...")

        // Get current settings
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let duration = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? 15.0

        // Default to false (disabled) - prayers must be explicitly enabled
        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }

        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: duration,
            selectedPrayers: selectedPrayers
        )

        print("✅ [DhikrApp] Rolling window scheduled")
    }

}

// MARK: - Main Content View Wrapper
// This wrapper creates PrayerTimeViewModel with LocationService dependency
struct MainContentView: View {
    @ObservedObject var locationService: LocationService
    @StateObject private var prayerTimeViewModel: PrayerTimeViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    init(locationService: LocationService) {
        self.locationService = locationService
        _prayerTimeViewModel = StateObject(wrappedValue: PrayerTimeViewModel(locationService: locationService))
    }

    var body: some View {
        MainTabView()
            .environmentObject(prayerTimeViewModel)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlowView()
            }
            .onAppear {
                // Show onboarding on first launch
                if !hasCompletedOnboarding {
                    // Delay slightly to ensure app is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                }
            }
    }
}
 