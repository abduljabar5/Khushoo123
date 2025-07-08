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
    
    init() {
        audioPlayerService.activate()
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
                .preferredColorScheme(.dark)
                .onAppear {
                    bluetoothService.startScanning()
                    audioPlayerService.activate()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        audioPlayerService.saveLastPlayed()
                    }
                }
        }
    }
} 