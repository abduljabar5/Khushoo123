import SwiftUI

@main
struct DhikrApp: App {
    
    // Connect AppDelegate for orientation lock
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Environment Objects
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var backTapService = BackTapService.shared
    @StateObject private var prayerTimeViewModel = PrayerTimeViewModel()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationService = LocationService()
    
    // Scene Phase
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dhikrService)
                .environmentObject(audioPlayerService)
                .environmentObject(bluetoothService)
                .environmentObject(quranAPIService)
                .environmentObject(backTapService)
                .environmentObject(prayerTimeViewModel)
                .environmentObject(favoritesManager)
                .environmentObject(locationService)
                .preferredColorScheme(.dark)
                .onAppear {
                    setupPerformanceOptimizations()
                    
                    // Prioritize audio service for immediate UI responsiveness
                    audioPlayerService.activate()
                    
                    // Preload last played audio in background for instant continue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        audioPlayerService.preloadLastPlayed()
                    }
                    
                    // Delay heavy operations to not block initial UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        prayerTimeViewModel.start() // Pre-fetch prayer times
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        bluetoothService.startScanning()
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
    
    // MARK: - Performance Optimizations
    private func setupPerformanceOptimizations() {
        // Initialize image cache manager
        _ = ImageCacheManager.shared
        
        print("🚀 [DhikrApp] Performance optimizations initialized")
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            audioPlayerService.saveLastPlayed()
            
            // Clean up resources when app goes to background
            Task {
                await BackgroundTaskManager.shared.cancelAllTasks()
                ImageCacheManager.shared.clearExpiredDiskCache()
            }
            
        case .inactive:
            // Prepare for potential memory pressure
            ImageCacheManager.shared.clearMemoryCache()
            
        case .active:
            // App became active - minimal resource restoration
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