import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingFullScreenPlayer = false
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                ReciterDirectoryView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Reciters")
                    }
                    .tag(1)
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(2)
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(3)
            }
            // Mini Player Overlay
            if audioPlayerService.currentSurah != nil {
                MiniPlayerBar(showingFullScreenPlayer: $showingFullScreenPlayer)
                    .padding(.bottom, 0)
                    .ignoresSafeArea(.keyboard)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
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