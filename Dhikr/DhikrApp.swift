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

                    // Ensure blocking state is evaluated on launch
                    // Note: BlockingStateService already does initial check and polls every 15s
                    BlockingStateService.shared.forceCheck()
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
            audioPlayerService.saveLastPlayed()

            // Save pending dhikr entries to disk
            dhikrService.savePendingData()

            // Check blocking state immediately when app goes to background
            BlockingStateService.shared.forceCheck()

            // Clean up resources when app goes to background
            Task {
                await BackgroundTaskManager.shared.cancelAllTasks()
                ImageCacheManager.shared.clearExpiredDiskCache()
            }
            
        case .inactive:
            // Check blocking state when app becomes inactive (user switching away)
            BlockingStateService.shared.forceCheck()
            
            // Prepare for potential memory pressure
            ImageCacheManager.shared.clearMemoryCache()
            
        case .active:
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
            return
        }


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

                // Clear all prayer selections (they were ineffective anyway)
                focusManager.selectedFajr = false
                focusManager.selectedDhuhr = false
                focusManager.selectedAsr = false
                focusManager.selectedMaghrib = false
                focusManager.selectedIsha = false

                // Stop any existing schedules
                DeviceActivityService.shared.stopAllMonitoring()

            }
        }

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func handleMemoryPressure() {

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
            return
        }


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

    }

    // MARK: - Premium Listener Setup

    private func setupPremiumListener() {
        // Listen for user becoming premium
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserBecamePremium"),
            object: nil,
            queue: .main
        ) { _ in

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

        }
    }

    private func fetch6MonthsForPremiumUser() async {

        let prayerTimeService = PrayerTimeService()

        // Check location permission
        guard locationService.authorizationStatus == .authorizedWhenInUse ||
              locationService.authorizationStatus == .authorizedAlways else {
            return
        }

        // Request location
        locationService.requestLocation()
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        guard let location = locationService.location else {
            return
        }

        do {
            // Fetch 6 months
            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: 180)
            prayerTimeService.saveStorage(storage)


            // Force reschedule app blocking if prayers are selected
            await forceRescheduleIfNeeded(storage: storage)

        } catch {
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
            return
        }


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

    }

    // MARK: - 6-Month Prayer Time Fetch

    private func fetch6MonthPrayerTimesOnLaunch() {

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
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                    } else {
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 3)
                    }
                } else {
                    // Check if rolling window needs update (only for premium users with app blocking)
                    if isPremium {
                        await checkAndUpdateRollingWindow(storage: storage)
                    }
                }
            } else {
                if isPremium {
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                } else {
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
            }

        case .notDetermined:
            if skipPermissionRequest {
                return
            }

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
            }

        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func fetch6Months(prayerTimeService: PrayerTimeService, location: CLLocation, daysToFetch: Int = 180) async {
        do {

            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: daysToFetch)
            prayerTimeService.saveStorage(storage)


            // Schedule rolling window (only for premium users with app blocking)
            if subscriptionService.isPremium {
                await scheduleRollingWindow(storage: storage)
            }

        } catch {
        }
    }

    private func checkAndUpdateRollingWindow(storage: PrayerTimeStorage) async {
        if DeviceActivityService.shared.needsRollingWindowUpdate() {
            await scheduleRollingWindow(storage: storage)
        } else {
        }
    }

    private func scheduleRollingWindow(storage: PrayerTimeStorage) async {

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
 