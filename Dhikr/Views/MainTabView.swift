//
//  MainTabView.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/05/2024.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var expandMiniPlayer = false
    @State private var showSurahList = false
    @State private var selectedTab: Int = 0
    @Namespace private var animation

    // Computed property to determine if mini player should be shown
    private var shouldShowMiniPlayer: Bool {
        audioPlayerService.currentSurah != nil && (audioPlayerService.isPlaying || audioPlayerService.hasPlayedOnce || audioPlayerService.isLoading)
    }

    var body: some View {
        ZStack {
            // Root background that shows during zoom transition - black to match system edges
            Color.black
                .ignoresSafeArea()

            if #available(iOS 26.1, *) {
                // iOS 26: Always apply modifier to prevent TabView recreation and scroll jumping
                NativeTabView()
                    .tabViewBottomAccessory(isEnabled: shouldShowMiniPlayer) {

                        // Gesture wrapper prevents re-render interruptions
                        MiniPlayerGestureWrapper(expanded: $expandMiniPlayer) {
                            MiniPlayerView(expanded: $expandMiniPlayer, animationNamespace: animation)
                                .environmentObject(audioPlayerService)
                        }
                    }
            } else {
                NativeTabView(60)
                    .overlay(alignment: .bottom) {
                        if shouldShowMiniPlayer {
                            // Gesture wrapper prevents re-render interruptions
                            MiniPlayerGestureWrapper(expanded: $expandMiniPlayer) {
                                MiniPlayerView(expanded: $expandMiniPlayer, animationNamespace: animation)
                                    .environmentObject(audioPlayerService)
                            }
                            .padding(.vertical, 8)
                            .background(content: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(.gray.opacity(0.3))

                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(.background)
                                        .padding(1.2)
                                }
                                .compositingGroup()
                            })
                            .offset(y: -52)
                            .padding(.horizontal, 15)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .all)
                    .animation(.spring(response: 0.35, dampingFraction: 0.88), value: shouldShowMiniPlayer)
            }
        }
        .fullScreenCover(isPresented: $expandMiniPlayer) {
            if audioPlayerService.currentSurah != nil, audioPlayerService.currentReciter != nil {
                FullScreenPlayer(
                    isPresented: $expandMiniPlayer,
                    showSurahList: $showSurahList,
                    animation: animation
                )
                .environmentObject(audioPlayerService)
                .environmentObject(quranAPIService)
                .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
                .onAppear {
                    // Set window background to match theme during presentation
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.backgroundColor = UIColor(themeManager.theme.primaryBackground)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                SchedulingProgressBanner(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .zIndex(102)

                VoiceConfirmationBanner(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .zIndex(101)

                EarlyUnlockBanner()
                    .padding(.horizontal, 16)
                    .zIndex(100)
            }
            .padding(.top, 8)
        }
        .environmentObject(audioPlayerService)
        .environmentObject(quranAPIService)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: themeManager.currentTheme) { _ in
            configureTabBarAppearance()
        }
        .onChange(of: audioPlayerService.shouldShowFullScreenPlayer) { shouldShow in
            if shouldShow && audioPlayerService.currentSurah != nil {
                expandMiniPlayer = true
                // Reset the flag after showing the player
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioPlayerService.shouldShowFullScreenPlayer = false
                }
            }
        }
    }

    // MARK: - Native TabView
    @ViewBuilder
    func NativeTabView(_ safeAreaBottomPadding: CGFloat = 0) -> some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                NavigationStack {
                    HomeView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Prayer", systemImage: "timer", value: 1) {
                NavigationStack {
                    PrayerTimeView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Dhikr", systemImage: "hand.point.up.left.fill", value: 2) {
                NavigationStack {
                    DhikrWidgetView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Focus", systemImage: "shield.fill", value: 3) {
                NavigationStack {
                    SearchView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Reciters", systemImage: "person.wave.2.fill", value: 4, role: .search) {
                NavigationStack {
                    ReciterDirectoryView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }
        }
    }

    // MARK: - Player Info View
    @ViewBuilder
    func PlayerInfoView(size: CGSize) -> some View {
        HStack(spacing: 12) {
            if let artwork = audioPlayerService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: size.height / 4))
            } else {
                RoundedRectangle(cornerRadius: size.height / 4)
                    .fill(.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(audioPlayerService.currentSurah?.englishName ?? "Not Playing")
                    .font(.callout)

                Text(audioPlayerService.currentReciter?.englishName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .lineLimit(1)
        }
    }

    // MARK: - Tab Bar Appearance Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()

        switch themeManager.currentTheme {
        case .auto:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground

        case .light:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground

        case .dark:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "0D1A2D"))
        }

        // Apply the appearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Lazy Tab Loading Component
struct LazyTabContent<Content: View>: View {
    let selectedTab: Int
    let targetTab: Int
    let content: () -> Content
    
    @State private var hasLoaded = false
    
    var body: some View {
        Group {
            if hasLoaded {
                content()
            } else {
                // Show loading placeholder
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            // Load content when tab becomes visible
            if selectedTab == targetTab {
                hasLoaded = true
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Load content when tab is selected
            if newTab == targetTab && !hasLoaded {
                hasLoaded = true
            }
        }
    }
}

// MARK: - Mini Player Gesture Wrapper
// This wrapper is STABLE - it doesn't observe AudioPlayerService
// so it won't re-render when currentTime updates every 0.5s.
// This prevents gesture recognizers from being interrupted.
// NOTE: Only handles DRAG gesture. Tap is handled inside MiniPlayerView.
struct MiniPlayerGestureWrapper<Content: View>: View {
    @Binding var expanded: Bool
    let content: Content

    init(expanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._expanded = expanded
        self.content = content()
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        // Swipe up to expand
                        if value.translation.height < -50 || (value.predictedEndLocation.y - value.location.y) < -200 {
                            expanded = true
                        }
                    }
            )
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let locationService = LocationService()
        Group {
        MainTabView()
                .environmentObject(DhikrService.shared)
            .environmentObject(AudioPlayerService.shared)
                .environmentObject(BluetoothService())
            .environmentObject(QuranAPIService.shared)
                .environmentObject(PrayerTimeViewModel(locationService: locationService))
                .environmentObject(FavoritesManager.shared)
                .environmentObject(locationService)
                .previewDisplayName("Main Tab View")
                .onAppear {
                    // Initialize audio player with safe values for preview
                    let audioPlayer = AudioPlayerService.shared
                    audioPlayer.duration = 300 // 5 minutes
                    audioPlayer.currentTime = 0
                    audioPlayer.isPlaying = false
                }
        }
    }
} 
