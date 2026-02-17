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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var playerExpandProgress: CGFloat = 0
    @State private var playerIsExpanded = false
    @State private var selectedTab: Int = 0
    @State private var showPaywall = false
    @State private var showShareReferralPopup = false

    private var shouldShowMiniPlayer: Bool {
        audioPlayerService.currentSurah != nil && (audioPlayerService.isPlaying || audioPlayerService.hasPlayedOnce || audioPlayerService.isLoading)
    }

    var body: some View {
        GeometryReader { rootGeo in
            ZStack {
                // Root background visible behind scaled tab view
                Color.black
                    .ignoresSafeArea()

                // Tab content — always full-screen, scale + corner radius is purely visual
                NativeTabView(shouldShowMiniPlayer ? 64 : 0)
                    .ignoresSafeArea(.keyboard, edges: .all)
                    .scaleEffect(1 - 0.08 * playerExpandProgress, anchor: .center)
                    .mask {
                        RoundedRectangle(cornerRadius: playerExpandProgress * 50, style: .continuous)
                            .ignoresSafeArea()
                    }
                    .allowsHitTesting(playerExpandProgress < 0.5)

                // Dimming overlay on top of tabs
                Color.black.opacity(0.3 * playerExpandProgress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Expandable player overlay
                if shouldShowMiniPlayer {
                    ExpandablePlayerView(
                        expandProgress: $playerExpandProgress,
                        isExpanded: $playerIsExpanded
                    )
                    .environmentObject(audioPlayerService)
                    .environmentObject(quranAPIService)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: shouldShowMiniPlayer)
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
            .opacity(1 - playerExpandProgress)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showShareReferralPopup) {
            ShareReferralPopup(isPresented: $showShareReferralPopup, onUpgrade: {
                showPaywall = true
            })
        }
        .environmentObject(audioPlayerService)
        .environmentObject(quranAPIService)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onAppear {
            configureTabBarAppearance()
            checkAndShowReferralPopup()
        }
        .onChange(of: themeManager.currentTheme) { _ in
            configureTabBarAppearance()
        }
        .onChange(of: audioPlayerService.shouldShowFullScreenPlayer) { shouldShow in
            if shouldShow && audioPlayerService.currentSurah != nil {
                withAnimation(.spring(duration: 0.5, bounce: 0)) {
                    playerExpandProgress = 1.0
                    playerIsExpanded = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioPlayerService.shouldShowFullScreenPlayer = false
                }
            }
        }
        .onChange(of: shouldShowMiniPlayer) { showMini in
            if !showMini && playerIsExpanded {
                withAnimation(.spring(duration: 0.5, bounce: 0)) {
                    playerExpandProgress = 0.0
                    playerIsExpanded = false
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

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    // MARK: - Referral Popup Logic
    private func checkAndShowReferralPopup() {
        guard !subscriptionService.hasPremiumAccess else { return }
        guard subscriptionService.canEarnReferralAccess else { return }

        let defaults = UserDefaults.standard
        let launchCountKey = "appLaunchCountForReferral"
        let lastShownKey = "lastReferralPopupShownDate"

        var launchCount = defaults.integer(forKey: launchCountKey)
        launchCount += 1
        defaults.set(launchCount, forKey: launchCountKey)

        if launchCount % 4 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showShareReferralPopup = true
            }
            defaults.set(Date(), forKey: lastShownKey)
        }
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
            if selectedTab == targetTab {
                hasLoaded = true
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == targetTab && !hasLoaded {
                hasLoaded = true
            }
        }
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
                    let audioPlayer = AudioPlayerService.shared
                    audioPlayer.duration = 300
                    audioPlayer.currentTime = 0
                    audioPlayer.isPlaying = false
                }
        }
    }
}
