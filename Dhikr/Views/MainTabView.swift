import SwiftUI

struct MainTabView: View {
    @State private var selection = 0
    @State private var showingFullScreenPlayer = false
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var backTapService: BackTapService
    @EnvironmentObject var quranAPIService: QuranAPIService
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                HomeView()
                    .tabItem {
                        Label("Listen Now", systemImage: "play.circle.fill")
                    }
                    .tag(0)
                
                PrayerTimeBlockerView()
                    .tabItem {
                        Label("Prayer Times", systemImage: "clock.fill")
                    }
                    .tag(1)
                
                ReciterDirectoryView()
                    .tabItem {
                        Label("Reciters", systemImage: "person.3.fill")
                    }
                    .tag(2)
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(3)

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(4)
            }
            
            // Mini Player Overlay
            if audioPlayerService.currentSurah != nil {
                MiniPlayerBar(showingFullScreenPlayer: $showingFullScreenPlayer)
                    .padding(.bottom, 49) // Standard TabView height
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
        .environmentObject(DhikrService.shared)
        .environmentObject(BluetoothService())
        .environmentObject(BackTapService.shared)
} 