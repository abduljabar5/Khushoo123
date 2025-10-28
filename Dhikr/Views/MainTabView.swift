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
    @AppStorage("showSleepTimer") private var showSleepTimer = true
    @Namespace private var animation

    var body: some View {
        ZStack {
            // Root background that shows during zoom transition - black to match system edges
            Color.black
                .ignoresSafeArea()

            Group {
                if #available(iOS 26, *) {
                    NativeTabView()
                        .tabViewBottomAccessory {
                        if audioPlayerService.currentSurah != nil {
                            MiniPlayerView(expanded: $expandMiniPlayer, animationNamespace: animation)
                                .environmentObject(audioPlayerService)
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 10)
                                        .onEnded { value in
                                            let velocity = value.predictedEndLocation.y - value.location.y
                                            if value.translation.height < -20 || velocity < -100 {
                                                expandMiniPlayer = true
                                            }
                                        }
                                )
                                .onTapGesture {
                                    expandMiniPlayer.toggle()
                                }
                        }
                    }
            } else {
                NativeTabView(60)
                    .overlay(alignment: .bottom) {
                        if audioPlayerService.currentSurah != nil {
                            MiniPlayerView(expanded: $expandMiniPlayer, animationNamespace: animation)
                                .environmentObject(audioPlayerService)
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
                                .contentShape(Rectangle())
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 10)
                                        .onEnded { value in
                                            let velocity = value.predictedEndLocation.y - value.location.y
                                            if value.translation.height < -20 || velocity < -100 {
                                                expandMiniPlayer = true
                                            }
                                        }
                                )
                                .onTapGesture {
                                    expandMiniPlayer.toggle()
                                }
                                .offset(y: -52)
                                .padding(.horizontal, 15)
                        }
                    }
                    .ignoresSafeArea(.keyboard, edges: .all)
            }
            }
        }
        .fullScreenCover(isPresented: $expandMiniPlayer) {
            if let surah = audioPlayerService.currentSurah, let reciter = audioPlayerService.currentReciter {
                GeometryReader { geometry in
                    let size = geometry.size
                    let safeArea = geometry.safeAreaInsets

                    ZStack {
                        // Background color that matches theme
                        themeManager.theme.primaryBackground
                            .ignoresSafeArea()

                        VStack(spacing: 10) {
                            /// Drag Indicator
                            Capsule()
                                .fill(.primary.secondary)
                                .frame(width: 35, height: 3)
                                .padding(.top, 10)

                            Spacer()
                                .frame(height: 80)

                            /// Full Player Controls
                            FullScreenPlayerContentView(size: size, safeArea: safeArea)

                            Spacer()
                        }
                    }
                    .navigationTransition(.zoom(sourceID: "MINIPLAYER", in: animation))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .presentationBackground(themeManager.theme.primaryBackground)
                .onAppear {
                    // Set window background to match theme during presentation
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.backgroundColor = UIColor(themeManager.theme.primaryBackground)
                    }
                }
                .onDisappear {
                    // Reset surah list view when player is dismissed
                    showSurahList = false
                }
            }
        }
        .environmentObject(audioPlayerService)
        .environmentObject(quranAPIService)
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : nil)
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: themeManager.currentTheme) { _ in
            configureTabBarAppearance()
        }
    }

    // MARK: - Native TabView
    @ViewBuilder
    func NativeTabView(_ safeAreaBottomPadding: CGFloat = 0) -> some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Prayer", systemImage: "timer") {
                NavigationStack {
                    PrayerTimeView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Dhikr", systemImage: "hand.point.up.left.fill") {
                NavigationStack {
                    DhikrWidgetView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Focus", systemImage: "shield.fill") {
                NavigationStack {
                    SearchView()
                        .safeAreaPadding(.bottom, safeAreaBottomPadding)
                }
            }

            Tab("Reciters", systemImage: "person.wave.2.fill", role: .search) {
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
                                    // Surah Number
                                    Text("\(surah.number)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 35, height: 35)
                                        .background(
                                            Circle()
                                                .fill(audioPlayerService.currentSurah?.number == surah.number ? themeManager.theme.primaryAccent : Color.secondary.opacity(0.3))
                                        )

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
                print("❌ [MainTabView] Failed to load surahs: \(error)")
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
        case .light:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground

        case .dark:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "1E3A5F"))

        case .liquidGlass:
            // Since UIDesignRequiresCompatibility is enabled globally,
            // we use transparent background which will work with our manual glass effects
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.clear
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