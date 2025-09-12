import SwiftUI
import DeviceActivity
import FamilyControls
import CoreLocation
import UserNotifications
import ManagedSettings

@main
struct DhikrApp: App {
    
    // Connect AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment Objects
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var prayerTimeViewModel = PrayerTimeViewModel()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationService = LocationService()
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared
    
    // Scene Phase
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dhikrService)
                .environmentObject(audioPlayerService)
                .environmentObject(bluetoothService)
                .environmentObject(quranAPIService)
                .environmentObject(prayerTimeViewModel)
                .environmentObject(favoritesManager)
                .environmentObject(locationService)
                .environmentObject(screenTimeAuth)
                .preferredColorScheme(.dark)
                .onAppear {
                    setupPerformanceOptimizations()
                    setupNotificationDelegate()
                    
                    // Prioritize audio service for immediate UI responsiveness
                    audioPlayerService.activate()
                    
                    // Start prayer time fetching and scheduling
                    prayerTimeViewModel.start()
                    
                    // Preload last played audio in background for instant continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        audioPlayerService.preloadLastPlayed()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        bluetoothService.startScanning()
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
    

} 