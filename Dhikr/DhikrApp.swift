import SwiftUI

@main
struct DhikrApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var backTapService = BackTapService.shared
    @StateObject private var prayerTimeViewModel = PrayerTimeViewModel()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var locationService = LocationService()
    
    init() {
        // Request permission as soon as the app is initialized
        locationService.requestLocationPermission()
    }

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
                    if newPhase == .background {
                        audioPlayerService.saveLastPlayed()
                    }
                }
        }
    }
} 