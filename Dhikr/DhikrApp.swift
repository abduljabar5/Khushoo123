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
                .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
                .onAppear {
                    setupPerformanceOptimizations()
                    setupNotificationDelegate()
                    setupWindowBackground()

                    // Prioritize audio service for immediate UI responsiveness
                    audioPlayerService.activate()

                    // Fetch 6-month prayer times on app launch
                    fetch6MonthPrayerTimesOnLaunch()

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

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Notification permission granted: \(granted)")
        }
    }

    // MARK: - Window Background Setup
    private func setupWindowBackground() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            // Set window background to match theme
            switch themeManager.currentTheme {
            case .dark:
                window.backgroundColor = UIColor(Color(hex: "1E3A5F"))
            case .light:
                window.backgroundColor = UIColor.systemBackground
            case .liquidGlass:
                window.backgroundColor = UIColor.clear
            }
        }
    }
    

    

    

    

     

     
     private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📲 App entering background")
            audioPlayerService.saveLastPlayed()
            
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
            break
            
        @unknown default:
            break
        }
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

    // MARK: - 6-Month Prayer Time Fetch

    private func fetch6MonthPrayerTimesOnLaunch() {
        print("🔍 [DhikrApp] Checking if 6-month prayer times need to be fetched...")

        Task {
            let prayerTimeService = PrayerTimeService()

            // Check if storage exists and is valid
            if let storage = prayerTimeService.loadStorage() {
                if storage.shouldRefresh {
                    print("🔄 [DhikrApp] Storage needs refresh - fetching new 6 months")
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService)
                } else {
                    print("✅ [DhikrApp] Storage is valid - no fetch needed")
                    // Check if rolling window needs update
                    await checkAndUpdateRollingWindow(storage: storage)
                }
            } else {
                print("🔍 [DhikrApp] No storage found - fetching 6 months")
                await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService)
            }
        }
    }

    private func fetchPrayerTimesWithLocation(prayerTimeService: PrayerTimeService) async {
        // Check location permission
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Has permission - get location
            locationService.requestLocation()

            // Wait for location
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if let location = locationService.location {
                await fetch6Months(prayerTimeService: prayerTimeService, location: location)
            } else {
                print("⚠️ [DhikrApp] Location not available yet - will fetch when available")
            }

        case .notDetermined:
            print("📍 [DhikrApp] Requesting location permission...")
            locationService.requestLocationPermission()

            // Wait for permission response
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            if locationService.authorizationStatus == .authorizedWhenInUse ||
               locationService.authorizationStatus == .authorizedAlways {
                locationService.requestLocation()
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                if let location = locationService.location {
                    await fetch6Months(prayerTimeService: prayerTimeService, location: location)
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

    private func fetch6Months(prayerTimeService: PrayerTimeService, location: CLLocation) async {
        do {
            print("🕌 [DhikrApp] Starting 6-month prayer time fetch...")

            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location)
            prayerTimeService.saveStorage(storage)

            print("✅ [DhikrApp] 6-month prayer times fetched and saved successfully")

            // Schedule rolling window
            await scheduleRollingWindow(storage: storage)

        } catch {
            print("❌ [DhikrApp] Failed to fetch 6-month prayer times: \(error.localizedDescription)")
        }
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

    init(locationService: LocationService) {
        self.locationService = locationService
        _prayerTimeViewModel = StateObject(wrappedValue: PrayerTimeViewModel(locationService: locationService))
    }

    var body: some View {
        MainTabView()
            .environmentObject(prayerTimeViewModel)
    }
}
 