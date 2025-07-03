import SwiftUI

@main
struct DhikrApp: App {
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var backTapService = BackTapService.shared
    
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
                .preferredColorScheme(.dark)
                .onAppear {
                    bluetoothService.startScanning()
                    audioPlayerService.activate()
                }
        }
    }
} 