//
//  FullScreenPlayer.swift
//  Dhikr
//
//  Sacred Minimalism redesign of Full Screen Player
//

import SwiftUI

struct FullScreenPlayer: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var isPresented: Bool
    @Binding var showSurahList: Bool
    @State private var showSleepTimerSheet = false
    @State private var allSurahs: [Surah] = []
    @AppStorage("showSleepTimer") private var showSleepTimer = true

    // Animation states
    @State private var artworkAppeared = false
    @State private var controlsAppeared = false
    @State private var bottomControlsAppeared = false

    // Dismiss gesture state
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingToDismiss = false

    let animation: Namespace.ID

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let safeArea = geometry.safeAreaInsets
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad

            ZStack(alignment: .center) {
                // Ambient Background
                sacredAmbientBackground

                // Main content
                VStack(spacing: isIPad ? 0 : 10) {
                    if isIPad {
                        // iPad: Close button
                        HStack {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "chevron.down.circle")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(warmGray)
                            }
                            .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, safeArea.top > 0 ? 0 : 20)
                        .padding(.bottom, 10)
                    } else {
                        // iPhone: Drag handle
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(warmGray.opacity(0.4))
                                .frame(width: 36, height: 5)
                                .padding(.top, 8)

                            Spacer()
                        }
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    if value.translation.height > 0 {
                                        isDraggingToDismiss = true
                                        dragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    let velocity = value.predictedEndLocation.y - value.location.y
                                    if value.translation.height > 80 || velocity > 200 {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            isPresented = false
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                            isDraggingToDismiss = false
                                        }
                                    }
                                }
                        )
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.25)) {
                                isPresented = false
                            }
                        }
                    }

                    // Player content
                    playerContent(size: size, safeArea: safeArea, isIPad: isIPad)

                    if !isIPad {
                        Spacer()
                    }
                }
                .frame(width: size.width)
                .offset(y: dragOffset)
                .opacity(isDraggingToDismiss ? 1.0 - (dragOffset / 400.0) : 1.0)
            }
            .frame(width: size.width, height: size.height)
        }
        .presentationBackground {
            pageBackground
        }
        .onAppear {
            loadSurahs()
            animateEntrance()
        }
        .onDisappear {
            showSurahList = false
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SacredSleepTimerSheet(isPresented: $showSleepTimerSheet)
                .environmentObject(audioPlayerService)
        }
    }

    // MARK: - Sacred Ambient Background

    @ViewBuilder
    private var sacredAmbientBackground: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            if let artwork = audioPlayerService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 120)
                    .opacity(0.3)
                    .scaleEffect(1.5)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        pageBackground.opacity(0.2),
                        pageBackground.opacity(0.6),
                        pageBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Player Content

    @ViewBuilder
    private func playerContent(size: CGSize, safeArea: EdgeInsets, isIPad: Bool) -> some View {
        let artworkSize = isIPad ? min(size.width * 0.7, 600) : (size.width - 50)

        VStack(spacing: isIPad ? 20 : 24) {
            // Artwork with Flip Animation
            ZStack {
                sacredArtworkView(size: artworkSize)
                    .rotation3DEffect(
                        .degrees(showSurahList ? 180 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(showSurahList ? 0 : 1)

                sacredSurahListView(size: size, artworkSize: artworkSize, isIPad: isIPad)
                    .rotation3DEffect(
                        .degrees(showSurahList ? 0 : -180),
                        axis: (x: 0, y: 1, z: 0)
                    )
                    .opacity(showSurahList ? 1 : 0)
            }
            .frame(width: artworkSize, height: artworkSize)
            .scaleEffect(artworkAppeared ? 1 : 0.8)
            .opacity(artworkAppeared ? 1 : 0)

            // Track Info
            sacredTrackInfoView(isIPad: isIPad)
                .opacity(controlsAppeared ? 1 : 0)
                .offset(y: controlsAppeared ? 0 : 20)

            // Progress Slider
            sacredProgressSliderView(isIPad: isIPad)
                .opacity(controlsAppeared ? 1 : 0)
                .offset(y: controlsAppeared ? 0 : 20)

            // Playback Controls
            sacredPlaybackControlsView(isIPad: isIPad)
                .opacity(controlsAppeared ? 1 : 0)
                .scaleEffect(controlsAppeared ? 1 : 0.9)

            // Bottom Controls
            sacredBottomControlsView(isIPad: isIPad)
                .opacity(bottomControlsAppeared ? 1 : 0)
                .offset(y: bottomControlsAppeared ? 0 : 15)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Sacred Artwork View

    @ViewBuilder
    private func sacredArtworkView(size: CGFloat) -> some View {
        Group {
            if let artwork = audioPlayerService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(sacredGold.opacity(0.4))
                    )
            }
        }
    }

    // MARK: - Sacred Track Info View

    @ViewBuilder
    private func sacredTrackInfoView(isIPad: Bool) -> some View {
        ZStack {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSurahList.toggle()
                }
            }) {
                VStack(spacing: 10) {
                    // Arabic name
                    if let surah = audioPlayerService.currentSurah {
                        Text(surah.name)
                            .font(.system(size: isIPad ? 20 : 16, weight: .regular, design: .serif))
                            .foregroundColor(warmGray)
                    }

                    HStack(spacing: 8) {
                        Text(audioPlayerService.currentSurah?.englishName ?? "")
                            .font(.system(size: isIPad ? 26 : 22, weight: .light))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Image(systemName: showSurahList ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(warmGray)
                    }

                    Text(audioPlayerService.currentReciter?.englishName ?? "")
                        .font(.system(size: isIPad ? 16 : 14, weight: .light))
                        .foregroundColor(warmGray)
                        .lineLimit(1)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Like button
            HStack {
                Spacer()
                Button(action: {
                    if let surah = audioPlayerService.currentSurah,
                       let reciter = audioPlayerService.currentReciter {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            audioPlayerService.toggleLike(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
                        }
                    }
                }) {
                    Image(systemName: isCurrentSurahLiked() ? "heart.fill" : "heart")
                        .font(.system(size: isIPad ? 26 : 22, weight: .light))
                        .foregroundColor(isCurrentSurahLiked() ? Color(red: 0.85, green: 0.4, blue: 0.4) : warmGray)
                        .scaleEffect(isCurrentSurahLiked() ? 1.1 : 1.0)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Sacred Progress Slider

    @ViewBuilder
    private func sacredProgressSliderView(isIPad: Bool) -> some View {
        VStack(spacing: isIPad ? 10 : 8) {
            SacredSlider(
                value: Binding(
                    get: { audioPlayerService.currentTime },
                    set: { audioPlayerService.seek(to: $0) }
                ),
                range: 0...max(audioPlayerService.duration, 1),
                accentColor: sacredGold
            )
            .frame(height: 20)

            HStack {
                Text(audioPlayerService.currentTime.formattedTime)
                    .font(.system(size: isIPad ? 13 : 11, weight: .light, design: .monospaced))
                Spacer()
                Text(audioPlayerService.duration.formattedTime)
                    .font(.system(size: isIPad ? 13 : 11, weight: .light, design: .monospaced))
            }
            .foregroundColor(warmGray)
        }
        .padding(.horizontal, isIPad ? 40 : 10)
    }

    // MARK: - Sacred Playback Controls

    @ViewBuilder
    private func sacredPlaybackControlsView(isIPad: Bool) -> some View {
        HStack(spacing: isIPad ? 80 : 60) {
            // Previous
            Button(action: { audioPlayerService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: isIPad ? 32 : 26, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
            }
            .buttonStyle(SacredPlayerButtonStyle())

            // Play/Pause
            Button(action: { audioPlayerService.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(sacredGold)
                        .frame(width: isIPad ? 85 : 72, height: isIPad ? 85 : 72)
                        .shadow(color: sacredGold.opacity(0.4), radius: 15, x: 0, y: 8)

                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isIPad ? 32 : 28))
                        .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                        .offset(x: audioPlayerService.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(SacredPlayerButtonStyle())

            // Next
            Button(action: { audioPlayerService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: isIPad ? 32 : 26, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
            }
            .buttonStyle(SacredPlayerButtonStyle())
        }
        .padding(.vertical, isIPad ? 20 : 10)
    }

    // MARK: - Sacred Bottom Controls

    @ViewBuilder
    private func sacredBottomControlsView(isIPad: Bool) -> some View {
        HStack(spacing: isIPad ? 60 : 50) {
            // Shuffle
            Button(action: { audioPlayerService.toggleShuffle() }) {
                VStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: isIPad ? 22 : 18, weight: .light))
                        .foregroundColor(audioPlayerService.isShuffleEnabled ? sacredGold : warmGray)

                    if audioPlayerService.isShuffleEnabled {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 35)
            }
            .buttonStyle(SacredPlayerButtonStyle())

            // Timer
            if showSleepTimer {
                Button(action: { showSleepTimerSheet = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: isIPad ? 22 : 18, weight: .light))
                                .foregroundColor(audioPlayerService.sleepTimeRemaining != nil ? sacredGold : warmGray)

                            if let remaining = audioPlayerService.sleepTimeRemaining {
                                Text(formatSleepTime(remaining))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(sacredGold)
                                    .offset(y: 18)
                            }
                        }

                        if audioPlayerService.sleepTimeRemaining != nil {
                            Circle()
                                .fill(sacredGold)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 35)
                }
                .buttonStyle(SacredPlayerButtonStyle())
            }

            // Repeat
            Button(action: { audioPlayerService.toggleRepeatMode() }) {
                VStack(spacing: 6) {
                    Image(systemName: audioPlayerService.repeatMode.icon)
                        .font(.system(size: isIPad ? 22 : 18, weight: .light))
                        .foregroundColor(audioPlayerService.repeatMode != .off ? sacredGold : warmGray)

                    if audioPlayerService.repeatMode != .off {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 35)
            }
            .buttonStyle(SacredPlayerButtonStyle())
        }
        .padding(.horizontal, isIPad ? 80 : 60)
        .padding(.bottom, isIPad ? 40 : 0)
    }

    // MARK: - Sacred Surah List View

    @ViewBuilder
    private func sacredSurahListView(size: CGSize, artworkSize: CGFloat, isIPad: Bool) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                if allSurahs.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(sacredGold)
                            .scaleEffect(1.2)
                        Text("Loading Surahs...")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(warmGray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        if let reciter = audioPlayerService.currentReciter {
                            ForEach(allSurahs) { surah in
                                sacredSurahRow(surah: surah, reciter: reciter, isIPad: isIPad)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
            }
            .frame(width: artworkSize, height: artworkSize)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
            .onAppear {
                if let currentNumber = audioPlayerService.currentSurah?.number {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation {
                            scrollProxy.scrollTo(currentNumber, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sacredSurahRow(surah: Surah, reciter: Reciter, isIPad: Bool) -> some View {
        let isCurrentSurah = audioPlayerService.currentSurah?.number == surah.number
        let isCompleted = audioPlayerService.completedSurahNumbers.contains(surah.number)

        Button(action: {
            audioPlayerService.load(surah: surah, reciter: reciter)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showSurahList = false
            }
        }) {
            HStack(spacing: 12) {
                // Surah Number
                ZStack(alignment: .bottomTrailing) {
                    Text("\(surah.number)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isCurrentSurah ? (themeManager.effectiveTheme == .dark ? .black : .white) : sacredGold)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(isCurrentSurah ? sacredGold : sacredGold.opacity(0.1))
                        )

                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(softGreen)
                            .background(
                                Circle()
                                    .fill(cardBackground)
                                    .frame(width: 11, height: 11)
                            )
                            .offset(x: 2, y: 2)
                    }
                }

                // Surah Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(surah.englishName)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text(surah.name)
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundColor(warmGray)
                    }

                    Text("\(surah.revelationType) · \(surah.numberOfAyahs) Ayahs")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(warmGray)
                }

                Spacer()

                // Play indicator
                if isCurrentSurah && audioPlayerService.isPlaying {
                    Image(systemName: "waveform")
                        .foregroundColor(sacredGold)
                        .font(.system(size: 14))
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundColor(warmGray.opacity(0.5))
                        .font(.system(size: 18, weight: .light))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentSurah ? sacredGold.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .id(surah.number)
    }

    // MARK: - Helper Functions

    private func isCurrentSurahLiked() -> Bool {
        guard let surah = audioPlayerService.currentSurah,
              let reciter = audioPlayerService.currentReciter else {
            return false
        }
        return audioPlayerService.isLiked(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
    }

    private func loadSurahs() {
        Task {
            do {
                let surahs = try await quranAPIService.fetchSurahs()
                await MainActor.run {
                    allSurahs = surahs
                }
            } catch {
                print("Failed to load surahs: \(error)")
            }
        }
    }

    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            artworkAppeared = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
            controlsAppeared = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
            bottomControlsAppeared = true
        }
    }

    private func formatSleepTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }
}

// MARK: - Sacred Player Button Style

struct SacredPlayerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Sacred Slider

struct SacredSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let accentColor: Color

    @State private var isDragging = false
    @StateObject private var themeManager = ThemeManager.shared

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(warmGray.opacity(0.2))
                    .frame(height: 4)

                // Progress fill
                Capsule()
                    .fill(accentColor)
                    .frame(width: width * clampedProgress, height: 4)

                // Thumb
                Circle()
                    .fill(accentColor)
                    .frame(width: isDragging ? 16 : 10, height: isDragging ? 16 : 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: isDragging ? 2 : 0)
                    )
                    .offset(x: (width * clampedProgress) - (isDragging ? 8 : 5))
                    .animation(.spring(response: 0.2), value: isDragging)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newProgress = gesture.location.x / width
                        let clampedNewProgress = min(max(newProgress, 0), 1)
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * clampedNewProgress
                        value = newValue
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

// MARK: - Sacred Sleep Timer Sheet

struct SacredSleepTimerSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(sacredGold)

                        Text("SLEEP TIMER")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(2)
                            .foregroundColor(warmGray)
                    }
                    .padding(.top, 20)

                    // Timer options
                    VStack(spacing: 8) {
                        ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                            sleepTimerButton(minutes: minutes)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Cancel button
                    if audioPlayerService.sleepTimeRemaining != nil {
                        Button(action: {
                            audioPlayerService.cancelSleepTimer()
                            isPresented = false
                        }) {
                            Text("Cancel Timer")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(sacredGold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sleepTimerButton(minutes: Int) -> some View {
        let isSelected = isTimerSelected(minutes: minutes)

        return Button(action: {
            audioPlayerService.setSleepTimer(minutes: Double(minutes))
            isPresented = false
        }) {
            HStack {
                Text("\(minutes) minutes")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? sacredGold.opacity(0.3) : sacredGold.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    private func isTimerSelected(minutes: Int) -> Bool {
        guard let remaining = audioPlayerService.sleepTimeRemaining else { return false }
        return Int(remaining / 60) == minutes
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var animation

    FullScreenPlayer(
        isPresented: .constant(true),
        showSurahList: .constant(false),
        animation: animation
    )
    .environmentObject(AudioPlayerService.shared)
    .environmentObject(QuranAPIService.shared)
}
