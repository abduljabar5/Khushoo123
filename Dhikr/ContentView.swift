//
//  ContentView.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var quranAPIService = QuranAPIService.shared
    @StateObject private var audioPlayerService = AudioPlayerService.shared
    @StateObject private var backTapService = BackTapService.shared
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
        ZStack {
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
            .environmentObject(quranAPIService)
            .environmentObject(audioPlayerService)
            .environmentObject(backTapService)
            
            // Mini Player Bar - Positioned above tab bar
            if audioPlayerService.currentSurah != nil {
                VStack {
                    Spacer()
                    MiniPlayerBar(showingFullScreenPlayer: $showingFullScreenPlayer)
                        .padding(.bottom, 49) // Height of tab bar
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
        .onAppear {
            // Enable back tap service when app launches
            if backTapService.isAvailable {
                backTapService.enable()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var progressPercentage: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
}

struct BLEDebugView: View {
    @EnvironmentObject var bluetooth: BluetoothService

    var body: some View {
        VStack(spacing: 20) {
            Text(bluetooth.connectionStatus)
                .font(.headline)

            Text("Dhikr Count: \(bluetooth.dhikrCount)")
                .font(.largeTitle)
        }
        .padding()
        .onAppear {
            print("✅ BLEDebugView appeared.")
            bluetooth.startScanning()
        }
    }
}

#Preview {
    ContentView()
}
