//
//  MainTabView.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/05/2024.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    
    // Player Gesture State
    @State private var viewState = CGSize.zero
    @State private var playerOffset: CGFloat = UIScreen.main.bounds.height
    
    // We will measure the tab bar height dynamically
    @State private var tabBarHeight: CGFloat = 0
    
    // Player dimension constants
    private let miniPlayerHeight: CGFloat = 70
    private let bottomPadding: CGFloat = 98 // A small padding to lift the player slightly
    
    private var minimizedPlayerOffset: CGFloat {
        // We calculate the offset using the dynamically measured tab bar height and a small padding
        UIScreen.main.bounds.height - tabBarHeight - miniPlayerHeight - bottomPadding
    }
    
    private var fullScreenPlayerOffset: CGFloat {
        0
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                PrayerTimeBlockerView()
                    .tabItem {
                        Label("Prayer", systemImage: "timer")
                    }
                    .tag(1)

                ReciterDirectoryView()
                    .tabItem {
                        Label("Reciters", systemImage: "person.wave.2.fill")
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
            .background(
                // Use a geometry reader to measure the actual height of the tab bar area
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            self.tabBarHeight = UIScreen.main.bounds.height - geo.frame(in: .global).maxY
                        }
                        .onChange(of: geo.size) { newSize in
                            self.tabBarHeight = UIScreen.main.bounds.height - geo.frame(in: .global).maxY
                        }
                }
            )

            // Player View as an overlay
            playerView(minimizedOffset: self.minimizedPlayerOffset)
                .onAppear {
                    // Set initial position correctly if a track is already playing
                    if audioPlayerService.currentSurah != nil && playerOffset == UIScreen.main.bounds.height {
                        // We need to wait for the tabBarHeight to be calculated
                        DispatchQueue.main.async {
                            if self.tabBarHeight > 0 {
                                self.playerOffset = self.minimizedPlayerOffset
                            }
                        }
                    }
                }
        }
        .environmentObject(audioPlayerService)
        .environmentObject(quranAPIService)
    }

    private func playerView(minimizedOffset: CGFloat) -> some View {
        let drag = DragGesture()
            .onChanged { value in
                // On the first moment of dragging, capture the current offset
                if self.viewState == .zero {
                    self.viewState.height = self.playerOffset
                }
                
                // Calculate the new offset from the start of the drag
                let newOffset = self.viewState.height + value.translation.height
                
                // Update the player offset, ensuring it doesn't go above the top of the screen
                self.playerOffset = max(self.fullScreenPlayerOffset, newOffset)
            }
            .onEnded { value in
                // Reset the viewState for the next gesture
                self.viewState = .zero

                let predictedEndTranslation = value.predictedEndTranslation.height
                
                // Determine whether to snap to full screen or minimized based on the gesture
                let snapThreshold = (fullScreenPlayerOffset - minimizedOffset) / 2
                let newOffset: CGFloat

                if predictedEndTranslation < -150 || value.translation.height < -snapThreshold {
                    newOffset = fullScreenPlayerOffset
                } else if predictedEndTranslation > 150 || value.translation.height > snapThreshold {
                    newOffset = minimizedOffset
                } else {
                    // If it wasn't a clear flick, snap to the nearest state
                    newOffset = (abs(self.playerOffset - fullScreenPlayerOffset) < abs(self.playerOffset - minimizedOffset)) ? fullScreenPlayerOffset : minimizedOffset
                }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.playerOffset = newOffset
                }
            }

        // The container for both player views. The drag gesture is attached to this.
        return ZStack(alignment: .top) {
            // Full Screen Player is always in the hierarchy for a smooth transition.
            FullScreenPlayerView {
                // onMinimize closure
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    self.playerOffset = minimizedOffset
                }
            }
            .opacity(fullPlayerOpacity(for: playerOffset, minimizedOffset: minimizedOffset))
            
            // Mini Player Bar - appears when player is minimized
            MiniPlayerBar(showingFullScreenPlayer: .constant(playerOffset == fullScreenPlayerOffset))
                .onTapGesture {
                    // onExpand closure
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.playerOffset = 0
                    }
                }
                .opacity(miniPlayerOpacity(for: playerOffset, minimizedOffset: minimizedOffset))
        }
        .frame(height: UIScreen.main.bounds.height)
        .offset(y: playerOffset)
        .gesture(drag)
        .onChange(of: audioPlayerService.currentSurah) { _ in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.playerOffset = self.minimizedPlayerOffset
            }
        }
    }
    
    // MARK: - Opacity Calculations
    private func miniPlayerOpacity(for offset: CGFloat, minimizedOffset: CGFloat) -> Double {
        // Calculate the progress of the drag from full screen (0) to minimized (minimizedOffset)
        guard minimizedOffset > 0 else { return 0 }
        let progress = (offset - fullScreenPlayerOffset) / (minimizedOffset - fullScreenPlayerOffset)
        return Double(max(0, min(1, progress)))
    }
    
    private func fullPlayerOpacity(for offset: CGFloat, minimizedOffset: CGFloat) -> Double {
        return 1.0 - miniPlayerOpacity(for: offset, minimizedOffset: minimizedOffset)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AudioPlayerService.shared)
            .environmentObject(QuranAPIService.shared)
    }
} 