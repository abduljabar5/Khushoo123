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
        audioPlayerService.activate()
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
                    bluetoothService.startScanning()
                    audioPlayerService.activate()
                    prayerTimeViewModel.start() // Pre-fetch prayer times
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        audioPlayerService.saveLastPlayed()
                    }
                }
        }
    }
} 