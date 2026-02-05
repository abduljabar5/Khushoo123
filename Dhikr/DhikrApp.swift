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

        // Configure TelemetryDeck analytics
        AnalyticsService.shared.configure()
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
                    // Track first app open (install)
                    AnalyticsService.shared.trackAppOpened()

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
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OnboardingCompleted"))) { _ in
                    print("📬 [DhikrApp] Received OnboardingCompleted notification - starting prayer time fetch")
                    fetch6MonthPrayerTimesOnLaunch()
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
        // Note: Notification permissions can be enabled in settings
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
            // Save last played info when app becomes inactive (catch swipe-away gesture)
            audioPlayerService.saveLastPlayed()

            // Check blocking state when app becomes inactive (user switching away)
            BlockingStateService.shared.forceCheck()

            // Prepare for potential memory pressure
            ImageCacheManager.shared.clearMemoryCache()

        case .active:
            // App became active - check blocking state immediately
            BlockingStateService.shared.forceCheck()

            // CRITICAL: Check if user is blocked but no longer has premium
            // This handles the case where premium expired while app was in background/closed
            // Use retry mechanism to wait for subscription verification to complete
            checkPremiumStatusWithRetry(attempt: 1, maxAttempts: 3)

            // Reschedule prayer notifications for the next 7 days
            // This ensures notifications continue working even if user doesn't open app daily
            PrayerNotificationService.shared.scheduleWeeklyPrayerReminders()

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
        guard !subscriptionService.hasPremiumAccess else {
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
            print("⚠️ [DhikrApp] UserLostPremium notification received")

            // FIX: Double-check that user is actually not premium before clearing settings
            // This is a safety guard in case the notification was sent incorrectly
            guard !self.subscriptionService.hasPremiumAccess else {
                print("⚠️ [DhikrApp] UserLostPremium received but isPremium is true - ignoring")
                return
            }

            print("🔴 [DhikrApp] Confirmed user lost premium - stopping blocking and clearing settings")

            // CRITICAL: Clear the actual app shields immediately
            // This ensures users aren't locked out if their premium expires while apps are blocked
            let store = ManagedSettingsStore()
            store.clearAllSettings()
            print("✅ [DhikrApp] Cleared ManagedSettingsStore - apps unblocked")

            // Stop all app blocking schedules
            DeviceActivityService.shared.stopAllMonitoring()

            // Clear BlockingStateService state (voice confirmation, blocking flags, etc.)
            BlockingStateService.shared.clearBlocking()
            print("✅ [DhikrApp] Cleared BlockingStateService state")

            // Turn off all prayer selections
            guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
            groupDefaults.set(false, forKey: "focusSelectedFajr")
            groupDefaults.set(false, forKey: "focusSelectedDhuhr")
            groupDefaults.set(false, forKey: "focusSelectedAsr")
            groupDefaults.set(false, forKey: "focusSelectedMaghrib")
            groupDefaults.set(false, forKey: "focusSelectedIsha")
            groupDefaults.set(false, forKey: "isPremiumUser") // Ensure premium flag is false
            groupDefaults.set(false, forKey: "isWaitingForVoiceConfirmation") // Clear voice confirmation
            groupDefaults.set(false, forKey: "appsActuallyBlocked") // Clear blocking flag
            groupDefaults.removeObject(forKey: "blockingStartTime")
            groupDefaults.removeObject(forKey: "blockingEndTime")
            groupDefaults.synchronize()

            // Also update main UserDefaults
            UserDefaults.standard.set(false, forKey: "focusSelectedFajr")
            UserDefaults.standard.set(false, forKey: "focusSelectedDhuhr")
            UserDefaults.standard.set(false, forKey: "focusSelectedAsr")
            UserDefaults.standard.set(false, forKey: "focusSelectedMaghrib")
            UserDefaults.standard.set(false, forKey: "focusSelectedIsha")

        }
    }

    /// Retry checking premium status until verification completes or max attempts reached
    private func checkPremiumStatusWithRetry(attempt: Int, maxAttempts: Int) {
        // Delay increases with each attempt: 1s, 2s, 3s
        let delay = Double(attempt)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // If verification completed, run the check
            if self.subscriptionService.hasVerifiedPremiumStatus {
                self.checkAndUnblockIfPremiumExpired()
            } else if attempt < maxAttempts {
                // Retry if not yet verified and attempts remaining
                print("⏳ [DhikrApp] Premium verification pending, retry \(attempt + 1)/\(maxAttempts)")
                self.checkPremiumStatusWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                // Max attempts reached - verification never completed
                // This is fine, user probably has premium (cached) and StoreKit is just slow
                print("⏳ [DhikrApp] Premium verification didn't complete after \(maxAttempts) attempts - skipping check")
            }
        }
    }

    /// Check if user is currently blocked but no longer has premium access
    /// This handles edge cases where premium expired while app was closed/background
    private func checkAndUnblockIfPremiumExpired() {
        // CRITICAL: Only proceed if subscription service has completed verification
        // This prevents race condition where we check before StoreKit sync completes
        guard subscriptionService.hasVerifiedPremiumStatus else {
            print("⏳ [DhikrApp] Subscription status not yet verified - skipping premium check")
            return
        }

        // Check if user currently has apps blocked or is waiting for voice confirmation
        let blockingState = BlockingStateService.shared
        let isBlocked = blockingState.appsActuallyBlocked ||
                       blockingState.isWaitingForVoiceConfirmation ||
                       blockingState.isCurrentlyBlocking

        guard isBlocked else {
            // Not blocked, nothing to check
            return
        }

        // Now we can trust hasPremiumAccess since verification completed
        let hasPremium = subscriptionService.hasPremiumAccess

        if !hasPremium {
            print("🚨 [DhikrApp] User is blocked but premium VERIFIED as expired - unblocking immediately")

            // Clear the actual app shields
            let store = ManagedSettingsStore()
            store.clearAllSettings()

            // Stop all monitoring
            DeviceActivityService.shared.stopAllMonitoring()

            // Clear blocking state
            blockingState.clearBlocking()

            // Clear UserDefaults flags
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(false, forKey: "isWaitingForVoiceConfirmation")
                groupDefaults.set(false, forKey: "appsActuallyBlocked")
                groupDefaults.removeObject(forKey: "blockingStartTime")
                groupDefaults.removeObject(forKey: "blockingEndTime")
                groupDefaults.synchronize()
            }

            print("✅ [DhikrApp] Emergency unblock complete - user can now access apps")
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

        // Get pre-prayer buffer
        let prePrayerBuffer = groupDefaults.double(forKey: "focusPrePrayerBuffer")

        // Schedule rolling window
        DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: effectiveDuration,
            selectedPrayers: selectedPrayers,
            prePrayerBuffer: prePrayerBuffer
        )

    }

    // MARK: - 6-Month Prayer Time Fetch

    private func fetch6MonthPrayerTimesOnLaunch() {
        print("🚀 [DhikrApp] fetch6MonthPrayerTimesOnLaunch() called")

        // Check if onboarding is complete before auto-requesting location
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("   hasCompletedOnboarding: \(hasCompletedOnboarding)")

        // Check if user is premium
        let isPremium = subscriptionService.hasPremiumAccess
        print("   isPremium: \(isPremium)")

        Task {
            let prayerTimeService = PrayerTimeService()

            // Check if storage exists and is valid
            if let storage = prayerTimeService.loadStorage() {
                print("📦 [DhikrApp] Existing storage found with \(storage.prayerTimes.count) days, shouldRefresh: \(storage.shouldRefresh)")

                // Check if calculation settings have changed (method or Asr school)
                let settingsChanged = prayerTimeService.needsRefreshForSettings(storage: storage)
                if settingsChanged {
                    print("⚙️ [DhikrApp] Calculation settings changed - fetching new data")
                }

                if storage.shouldRefresh || settingsChanged {
                    print("🔄 [DhikrApp] Storage needs refresh - fetching new data")
                    if isPremium {
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                    } else {
                        await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 3)
                    }
                } else {
                    print("✅ [DhikrApp] Storage is valid - checking rolling window")
                    // Check if rolling window needs update (only for premium users with app blocking)
                    if isPremium {
                        await checkAndUpdateRollingWindow(storage: storage)
                    }
                }
            } else {
                print("📭 [DhikrApp] No existing storage - fetching fresh data")
                if isPremium {
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 180)
                } else {
                    await fetchPrayerTimesWithLocation(prayerTimeService: prayerTimeService, skipPermissionRequest: !hasCompletedOnboarding, daysToFetch: 3)
                }
            }
        }
    }

    private func fetchPrayerTimesWithLocation(prayerTimeService: PrayerTimeService, skipPermissionRequest: Bool = false, daysToFetch: Int = 180) async {
        print("📍 [DhikrApp] fetchPrayerTimesWithLocation - skipPermissionRequest: \(skipPermissionRequest), daysToFetch: \(daysToFetch)")
        print("   Location status: \(locationService.authorizationStatus.rawValue)")

        // Check location permission
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Has permission - get location
            print("✅ [DhikrApp] Location authorized - requesting location")
            locationService.requestLocation()

            // Wait for location
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if let location = locationService.location {
                print("📍 [DhikrApp] Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                await fetch6Months(prayerTimeService: prayerTimeService, location: location, daysToFetch: daysToFetch)
            } else {
                print("❌ [DhikrApp] Failed to get location after waiting")
            }

        case .notDetermined:
            print("❓ [DhikrApp] Location not determined")
            if skipPermissionRequest {
                print("⏭️ [DhikrApp] Skipping permission request (onboarding not complete)")
                return
            }

            print("🔔 [DhikrApp] Requesting location permission")
            locationService.requestLocationPermission()

            // Wait for permission response
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            if locationService.authorizationStatus == .authorizedWhenInUse ||
               locationService.authorizationStatus == .authorizedAlways {
                print("✅ [DhikrApp] Permission granted - requesting location")
                locationService.requestLocation()
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                if let location = locationService.location {
                    print("📍 [DhikrApp] Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    await fetch6Months(prayerTimeService: prayerTimeService, location: location, daysToFetch: daysToFetch)
                } else {
                    print("❌ [DhikrApp] Failed to get location after permission granted")
                }
            } else {
                print("❌ [DhikrApp] Permission not granted")
            }

        case .denied, .restricted:
            print("🚫 [DhikrApp] Location denied/restricted")
            break
        @unknown default:
            print("❓ [DhikrApp] Unknown location status")
            break
        }
    }

    private func fetch6Months(prayerTimeService: PrayerTimeService, location: CLLocation, daysToFetch: Int = 180) async {
        // For premium users fetching 6 months, use split fetch approach:
        // 1. Fetch first month quickly
        // 2. Schedule blocking immediately
        // 3. Fetch remaining 5 months in background

        let isPremiumFetch = daysToFetch >= 30 && subscriptionService.hasPremiumAccess
        print("📍 [DhikrApp] fetch6Months called - isPremium: \(subscriptionService.hasPremiumAccess), daysToFetch: \(daysToFetch), usingSplitApproach: \(isPremiumFetch)")

        if isPremiumFetch {
            print("🔀 [DhikrApp] Using SPLIT fetch approach (premium user)")
            await fetchWithSplitApproach(prayerTimeService: prayerTimeService, location: location)
        } else {
            // Non-premium or short fetch - do it all at once
            print("🔄 [DhikrApp] Using single fetch approach (non-premium or short fetch)")
            await fetchAllAtOnce(prayerTimeService: prayerTimeService, location: location, daysToFetch: daysToFetch)
        }
    }

    /// Split fetch: First month → Schedule → Remaining months in background
    private func fetchWithSplitApproach(prayerTimeService: PrayerTimeService, location: CLLocation) async {
        print("🚀 [DhikrApp] Starting split fetch approach (1 month first, then remaining)")

        // PHASE 1: Fetch first month (35 days to be safe for rolling window)
        do {
            print("📅 [DhikrApp] Phase 1: Fetching first 35 days...")
            let initialStorage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: 35)
            prayerTimeService.saveStorage(initialStorage)
            print("✅ [DhikrApp] Phase 1 complete - saved \(initialStorage.prayerTimes.count) days")

            // Schedule blocking immediately with first month data
            if subscriptionService.hasPremiumAccess {
                print("⏰ [DhikrApp] Scheduling blocking with initial data...")
                await scheduleRollingWindow(storage: initialStorage)
            }

            // Also try initial scheduling for post-onboarding scenario
            await scheduleBlockingIfConditionsMet(storage: initialStorage)

            // Mark scheduling as complete and trigger success banner
            await MainActor.run {
                if BlockingStateService.shared.isSchedulingBlocking {
                    print("✅ [DhikrApp] Background scheduling complete - updating state")
                    BlockingStateService.shared.isSchedulingBlocking = false
                    BlockingStateService.shared.schedulingDidComplete = true

                    // Reset the completion flag after a delay (for banner to show and dismiss)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        BlockingStateService.shared.schedulingDidComplete = false
                    }
                }
            }

            // PHASE 2: Fetch remaining 5 months in background
            print("📅 [DhikrApp] Phase 2: Starting background fetch of remaining 145 days...")
            Task.detached(priority: .utility) {
                await self.fetchRemainingMonthsInBackground(
                    prayerTimeService: prayerTimeService,
                    location: location,
                    existingStorage: initialStorage
                )
            }

        } catch {
            print("❌ [DhikrApp] Phase 1 fetch failed: \(error.localizedDescription)")
            // Fall back to single fetch if split fails
            await fetchAllAtOnce(prayerTimeService: prayerTimeService, location: location, daysToFetch: 180)
        }
    }

    /// Background fetch of remaining months (Phase 2)
    private func fetchRemainingMonthsInBackground(prayerTimeService: PrayerTimeService, location: CLLocation, existingStorage: PrayerTimeStorage) async {
        do {
            // Calculate start date for remaining fetch (day after existing storage ends)
            let calendar = Calendar.current
            guard let remainingStartDate = calendar.date(byAdding: .day, value: 1, to: existingStorage.endDate) else {
                print("❌ [DhikrApp] Failed to calculate remaining start date")
                return
            }

            // Fetch remaining ~145 days (35 + 145 = 180 total)
            let remainingStorage = try await prayerTimeService.fetch6MonthPrayerTimes(
                for: location,
                startingFrom: remainingStartDate,
                daysToFetch: 145
            )

            // Merge with existing storage
            let mergedStorage = prayerTimeService.extendStorage(existingStorage: existingStorage, with: remainingStorage)
            prayerTimeService.saveStorage(mergedStorage)

            print("✅ [DhikrApp] Phase 2 complete - total \(mergedStorage.prayerTimes.count) days stored")

        } catch {
            print("⚠️ [DhikrApp] Background fetch failed: \(error.localizedDescription) - but initial data is still valid")
            // Don't propagate error - initial data is still valid and blocking is working
        }
    }

    /// Single fetch (for non-premium or fallback)
    private func fetchAllAtOnce(prayerTimeService: PrayerTimeService, location: CLLocation, daysToFetch: Int) async {
        do {
            let storage = try await prayerTimeService.fetch6MonthPrayerTimes(for: location, daysToFetch: daysToFetch)
            prayerTimeService.saveStorage(storage)

            // Schedule rolling window (only for premium users with app blocking)
            if subscriptionService.hasPremiumAccess {
                await scheduleRollingWindow(storage: storage)
            }

            // Also try initial scheduling for post-onboarding scenario
            await scheduleBlockingIfConditionsMet(storage: storage)

        } catch {
            print("❌ [DhikrApp] Fetch failed: \(error.localizedDescription)")
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
        guard subscriptionService.hasPremiumAccess else {
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
            await scheduleRollingWindow(storage: storage)
        } else {
        }
    }

    private func scheduleRollingWindow(storage: PrayerTimeStorage) async {

        // Get current settings
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let duration = groupDefaults?.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
        let prePrayerBuffer = groupDefaults?.double(forKey: "focusPrePrayerBuffer") ?? 0

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
            selectedPrayers: selectedPrayers,
            prePrayerBuffer: prePrayerBuffer
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
    @State private var showSplash = true

    init(locationService: LocationService) {
        self.locationService = locationService
        _prayerTimeViewModel = StateObject(wrappedValue: PrayerTimeViewModel(locationService: locationService))
    }

    var body: some View {
        ZStack {
            // Main content (always rendered underneath)
            MainTabView()
                .environmentObject(prayerTimeViewModel)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingFlowView()
                        .environmentObject(locationService)
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
                .onChange(of: hasCompletedOnboarding) { completed in
                    if completed {
                        print("🎉 [DhikrApp] Onboarding completed - triggering prayer time fetch")
                        // Trigger prayer time fetch now that onboarding is complete
                        NotificationCenter.default.post(name: Notification.Name("OnboardingCompleted"), object: nil)
                    }
                }

            // Splash screen overlay
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Dismiss splash after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}
