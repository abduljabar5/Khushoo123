import SwiftUI

@main
struct DhikrApp: App {
    @StateObject private var dhikrService = DhikrService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var quranAPIService = QuranAPIService.shared
    
    init() {
        audioPlayerService.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dhikrService)
                .environmentObject(audioPlayerService)
                .environmentObject(bluetoothService)
                .environmentObject(quranAPIService)
                .preferredColorScheme(.dark)
                .onAppear {
                    bluetoothService.startScanning()
        }
    }
}
} 