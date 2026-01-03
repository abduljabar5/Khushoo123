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
    @State private var dragOffset: CGFloat = 0
    @State private var showSleepTimerSheet = false
    @State private var showSurahList = false
    @State private var allSurahs: [Surah] = []
    @State private var selectedTab: Int = 0
    @AppStorage("showSleepTimer") private var showSleepTimer = true
    @Namespace private var animation

    // Computed property to determine if mini player should be shown
    private var shouldShowMiniPlayer: Bool {
        audioPlayerService.currentSurah != nil && (audioPlayerService.isPlaying || audioPlayerService.hasPlayedOnce || audioPlayerService.isLoading)
    }

    // Animation progress for Spotify-like transitions (0 = mini, 1 = full)
    private var expandProgress: CGFloat {
        if expandMiniPlayer {
            // When expanded, calculate progress based on drag
            let screenHeight = UIScreen.main.bounds.height
            return max(0, min(1, 1 - (dragOffset / screenHeight)))
        }
        return 0
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height

            ZStack {
                // Main content with scale effect when player expands
                Group {
                    if #available(iOS 26.1, *) {
                        NativeTabView()
                            .tabViewBottomAccessory(isEnabled: shouldShowMiniPlayer && !expandMiniPlayer) {
                                miniPlayerContent
                            }
                    } else {
                        NativeTabView(60)
                            .overlay(alignment: .bottom) {
                                if shouldShowMiniPlayer && !expandMiniPlayer {
                                    miniPlayerContent
                                        .padding(.vertical, 8)
                                        .background {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .fill(.gray.opacity(0.3))
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .fill(.background)
                                                    .padding(1.2)
                                            }
                                            .compositingGroup()
                                        }
                                        .offset(y: -52)
                                        .padding(.horizontal, 15)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .ignoresSafeArea(.keyboard, edges: .all)
                            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: shouldShowMiniPlayer)
                    }
                }
                // Scale down background when player is expanded (Spotify-style)
                .scaleEffect(expandMiniPlayer ? 0.92 - (0.02 * (1 - expandProgress)) : 1)
                .cornerRadius(expandMiniPlayer ? 20 : 0)
                .blur(radius: expandMiniPlayer ? 2 * expandProgress : 0)
                .allowsHitTesting(!expandMiniPlayer)

                // Dim overlay
                Color.black
                    .opacity(expandMiniPlayer ? 0.3 * expandProgress : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Full screen player overlay
                if expandMiniPlayer, let _ = audioPlayerService.currentSurah, let _ = audioPlayerService.currentReciter {
                    fullScreenPlayerView(screenHeight: screenHeight, size: geometry.size, safeArea: geometry.safeAreaInsets)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    expandMiniPlayer = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioPlayerService.shouldShowFullScreenPlayer = false
                }
            }
        }
    }

    // MARK: - Mini Player Content
    @ViewBuilder
    private var miniPlayerContent: some View {
        MiniPlayerView(expanded: $expandMiniPlayer, animationNamespace: animation)
            .environmentObject(audioPlayerService)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onEnded { value in
                        if value.translation.height < -15 || value.predictedEndTranslation.height < -50 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                expandMiniPlayer = true
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    expandMiniPlayer = true
                }
            }
    }

    // MARK: - Full Screen Player View
    @ViewBuilder
    private func fullScreenPlayerView(screenHeight: CGFloat, size: CGSize, safeArea: EdgeInsets) -> some View {
        ZStack {
            // Background
            themeManager.theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // Drag indicator
                Capsule()
                    .fill(.primary.tertiary)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Spacer()
                    .frame(height: 60)

                // Player content
                FullScreenPlayerContentView(size: size, safeArea: safeArea)

                Spacer()
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    // Only drag down, with rubber band effect at top
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    } else {
                        // Rubber band effect when dragging up
                        dragOffset = value.translation.height * 0.2
                    }
                }
                .onEnded { value in
                    let velocity = value.velocity.height
                    let translation = value.translation.height

                    // Dismiss if dragged far enough or with enough velocity
                    if translation > 120 || velocity > 800 {
                        // Animate out
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            dragOffset = screenHeight
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            expandMiniPlayer = false
                            dragOffset = 0
                            showSurahList = false
                        }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            dragOffset = 0
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

    // MARK: - Full Screen Player Content
    @ViewBuilder
    func FullScreenPlayerContentView(size: CGSize, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 24) {
            // Large Artwork or Surah List with flip animation
            ZStack {
                // Front side - Artwork
                Group {
                    if let artwork = audioPlayerService.currentArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width - 50, height: size.width - 50)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .shadow(radius: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.gray.opacity(0.3))
                            .frame(width: size.width - 50, height: size.width - 50)
                    }
                }
                .rotation3DEffect(
                    .degrees(showSurahList ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(showSurahList ? 0 : 1)

                // Back side - Surah List
                surahListView(size: size)
                    .rotation3DEffect(
                        .degrees(showSurahList ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(showSurahList ? 1 : 0)
            }

            // Track info with like button
            ZStack {
                // Centered track info
                Button(action: {
                    Task { @MainActor in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showSurahList.toggle()
                        }
                    }
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(audioPlayerService.currentSurah?.englishName ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Image(systemName: showSurahList ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(audioPlayerService.currentReciter?.englishName ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Like button overlaid on the right
                HStack {
                    Spacer()
                    Button(action: {
                        Task { @MainActor in
                            if let surah = audioPlayerService.currentSurah,
                               let reciter = audioPlayerService.currentReciter {
                                audioPlayerService.toggleLike(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
                            }
                        }
                    }) {
                        Image(systemName: isCurrentSurahLiked() ? "heart.fill" : "heart")
                            .font(.title2)
                            .foregroundColor(isCurrentSurahLiked() ? .red : .secondary)
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(.horizontal)

            // Progress slider
            VStack(spacing: 6) {
                Slider(value: Binding(
                    get: { audioPlayerService.currentTime },
                    set: { audioPlayerService.seek(to: $0) }
                ), in: 0...max(audioPlayerService.duration, 1), step: 1)
                .tint(.primary)

                HStack {
                    Text(audioPlayerService.currentTime.formattedTime)
                    Spacer()
                    Text(audioPlayerService.duration.formattedTime)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 30)

            // Playback controls
            HStack(spacing: 60) {
                Button(action: { audioPlayerService.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }

                Button(action: { audioPlayerService.togglePlayPause() }) {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.primary)
                }

                Button(action: { audioPlayerService.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundColor(.primary)
                }
            }

            // Bottom controls
            HStack(spacing: 40) {
                Button(action: { audioPlayerService.toggleShuffle() }) {
                    Image(systemName: "shuffle")
                        .font(.body)
                        .foregroundColor(audioPlayerService.isShuffleEnabled ? .accentColor : .secondary)
                }

                // Timer button (conditionally shown)
                if showSleepTimer {
                    Button(action: { showSleepTimerSheet = true }) {
                        Image(systemName: audioPlayerService.sleepTimeRemaining != nil ? "timer.circle.fill" : "timer.circle")
                            .font(.body)
                            .foregroundColor(audioPlayerService.sleepTimeRemaining != nil ? .accentColor : .secondary)
                    }
                }

                Button(action: { audioPlayerService.toggleRepeatMode() }) {
                    Image(systemName: audioPlayerService.repeatMode.icon)
                        .font(.body)
                        .foregroundColor(audioPlayerService.repeatMode != .off ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 60)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showSleepTimerSheet) {
            sleepTimerSheet
        }
    }

    // MARK: - Helper Functions

    private func isCurrentSurahLiked() -> Bool {
        guard let surah = audioPlayerService.currentSurah,
              let reciter = audioPlayerService.currentReciter else {
            return false
        }
        return audioPlayerService.isLiked(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
    }

    // MARK: - Surah List View

    @ViewBuilder
    private func surahListView(size: CGSize) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                if allSurahs.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading Surahs...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        if let reciter = audioPlayerService.currentReciter {
                            ForEach(allSurahs) { surah in
                                Button(action: {
                                    Task { @MainActor in
                                        audioPlayerService.load(surah: surah, reciter: reciter)
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            showSurahList = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        // Surah Number with completion indicator
                                        ZStack(alignment: .bottomTrailing) {
                                            Text("\(surah.number)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .frame(width: 35, height: 35)
                                                .background(
                                                    Circle()
                                                        .fill(audioPlayerService.currentSurah?.number == surah.number ? themeManager.theme.primaryAccent : Color.secondary.opacity(0.3))
                                                )

                                            // Completion checkmark badge
                                            if audioPlayerService.completedSurahNumbers.contains(surah.number) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.green)
                                                    .background(
                                                        Circle()
                                                            .fill(themeManager.theme.cardBackground)
                                                            .frame(width: 12, height: 12)
                                                    )
                                                    .offset(x: 2, y: 2)
                                            }
                                        }

                                        // Surah Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(surah.englishName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)

                                            Text("\(surah.revelationType) - \(surah.numberOfAyahs) Ayahs")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        if audioPlayerService.currentSurah?.number == surah.number && audioPlayerService.isPlaying {
                                            Image(systemName: "waveform")
                                                .foregroundColor(themeManager.theme.primaryAccent)
                                                .font(.caption)
                                        } else {
                                            Image(systemName: "play.circle")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(themeManager.theme.cardBackground.opacity(0.5))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(surah.number) // Add id for scrolling
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: size.width - 50, height: size.width - 50)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(themeManager.theme.tertiaryBackground.opacity(0.3))
            )
            .onAppear {
                loadSurahsIfNeeded()
            }
            .onChange(of: showSurahList) { isShowing in
                // Scroll to current surah when list becomes visible
                if isShowing, let currentSurah = audioPlayerService.currentSurah {
                    // Small delay to ensure list is rendered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(currentSurah.number, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func loadSurahsIfNeeded() {
        guard allSurahs.isEmpty else { return }
        Task {
            do {
                let surahs = try await quranAPIService.fetchSurahs()
                await MainActor.run {
                    self.allSurahs = surahs
                }
            } catch {
            }
        }
    }

    // MARK: - Sleep Timer Sheet

    private var sleepTimerSheet: some View {
        NavigationView {
            List {
                Section {
                    if let remaining = audioPlayerService.sleepTimeRemaining {
                        HStack {
                            Text("Time Remaining")
                            Spacer()
                            Text(formatTime(remaining))
                                .foregroundColor(.secondary)
                        }

                        Button(role: .destructive) {
                            audioPlayerService.cancelSleepTimer()
                            showSleepTimerSheet = false
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Cancel Timer")
                            }
                        }
                    } else {
                        ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                            Button {
                                audioPlayerService.setSleepTimer(minutes: Double(minutes))
                                showSleepTimerSheet = false
                            } label: {
                                HStack {
                                    Image(systemName: "timer")
                                    Text("\(minutes) minutes")
                                    Spacer()
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSleepTimerSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
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
