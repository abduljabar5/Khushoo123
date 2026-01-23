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

    // Entrance animation states
    @State private var artworkAppeared = false
    @State private var controlsAppeared = false
    @State private var bottomControlsAppeared = false

    // Dismiss gesture state
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingToDismiss = false

    let animation: Namespace.ID

    // Sacred colors
    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var softGreen: Color { Color(red: 0.55, green: 0.68, blue: 0.55) }
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

            ZStack {
                pageBackground
                    .ignoresSafeArea()

                // Ambient background - full screen, centered
                if let artwork = audioPlayerService.currentArtwork {
                    GeometryReader { _ in
                        ZStack {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 120)
                                .opacity(0.3)

                            LinearGradient(
                                colors: [
                                    pageBackground.opacity(0.2),
                                    pageBackground.opacity(0.6),
                                    pageBackground
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                VStack(alignment: .center, spacing: isIPad ? 0 : 10) {
                    if isIPad {
                        HStack {
                            Button(action: { isPresented = false }) {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                            Spacer()
                        }
                        .padding(.top, safeArea.top > 0 ? 0 : 20)
                        .padding(.bottom, 10)
                    } else {
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

                    FullScreenPlayerContentView(size: size, safeArea: safeArea)

                    if !isIPad {
                        Spacer()
                    }
                }
                .frame(width: size.width)
                .offset(y: dragOffset)
                .opacity(isDraggingToDismiss ? 1.0 - (dragOffset / 400.0) : 1.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .presentationBackground {
            pageBackground
        }
        .onAppear {
            animateEntrance()
        }
        .onDisappear {
            showSurahList = false
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

    @ViewBuilder
    func FullScreenPlayerContentView(size: CGSize, safeArea: EdgeInsets) -> some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let horizontalPadding: CGFloat = isIPad ? 40 : 20
        let artworkSize = isIPad ? min(size.width * 0.7, 600) : (size.width - (horizontalPadding * 2) - 10)

        VStack(alignment: .center, spacing: isIPad ? 20 : RS.spacing(24)) {
            ZStack {
                Group {
                    if let artwork = audioPlayerService.currentArtwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: artworkSize, height: artworkSize)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(cardBackground)
                            .frame(width: artworkSize, height: artworkSize)
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
                .rotation3DEffect(.degrees(showSurahList ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(showSurahList ? 0 : 1)

                surahListView(size: size, isIPad: isIPad)
                    .rotation3DEffect(.degrees(showSurahList ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    .opacity(showSurahList ? 1 : 0)
            }
            .frame(width: artworkSize, height: artworkSize)
            .scaleEffect(artworkAppeared ? 1 : 0.8)
            .opacity(artworkAppeared ? 1 : 0)

            ZStack(alignment: .center) {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showSurahList.toggle()
                    }
                }) {
                    VStack(spacing: RS.spacing(10)) {
                        // Arabic name
                        if let surah = audioPlayerService.currentSurah {
                            Text(surah.name)
                                .font(.system(size: isIPad ? 20 : RS.fontSize(16), weight: .regular, design: .serif))
                                .foregroundColor(warmGray)
                        }

                        HStack(spacing: RS.spacing(8)) {
                            Text(audioPlayerService.currentSurah?.englishName ?? "")
                                .font(.system(size: isIPad ? 26 : RS.fontSize(22), weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)
                                .lineLimit(1)

                            Image(systemName: showSurahList ? "chevron.up" : "chevron.down")
                                .font(.system(size: RS.fontSize(12), weight: .light))
                                .foregroundColor(warmGray)
                        }

                        Text(audioPlayerService.currentReciter?.englishName ?? "")
                            .font(.system(size: isIPad ? 16 : RS.fontSize(14), weight: .light))
                            .foregroundColor(warmGray)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

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
                            .font(.system(size: isIPad ? 26 : RS.fontSize(22), weight: .light))
                            .foregroundColor(isCurrentSurahLiked() ? Color(red: 0.85, green: 0.4, blue: 0.4) : warmGray)
                            .scaleEffect(isCurrentSurahLiked() ? 1.1 : 1.0)
                    }
                    .buttonStyle(SacredPlayerButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .opacity(controlsAppeared ? 1 : 0)
            .offset(y: controlsAppeared ? 0 : 20)

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
                    Spacer()
                    Text(audioPlayerService.duration.formattedTime)
                }
                .font(.system(size: isIPad ? 13 : 11, weight: .light, design: .monospaced))
                .foregroundColor(warmGray)
            }
            .padding(.horizontal, isIPad ? 40 : 10)
            .opacity(controlsAppeared ? 1 : 0)
            .offset(y: controlsAppeared ? 0 : 20)

            HStack(spacing: isIPad ? 80 : RS.spacing(60)) {
                Button(action: { audioPlayerService.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: isIPad ? 32 : RS.fontSize(26), weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)
                }
                .buttonStyle(SacredPlayerButtonStyle())

                Button(action: { audioPlayerService.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: isIPad ? 85 : RS.dimension(72), height: isIPad ? 85 : RS.dimension(72))
                            .shadow(color: sacredGold.opacity(0.4), radius: 15, x: 0, y: 8)
                        Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isIPad ? 32 : RS.fontSize(28)))
                            .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                            .offset(x: audioPlayerService.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(SacredPlayerButtonStyle())

                Button(action: { audioPlayerService.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: isIPad ? 32 : RS.fontSize(26), weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)
                }
                .buttonStyle(SacredPlayerButtonStyle())
            }
            .padding(.vertical, isIPad ? 20 : RS.spacing(10))
            .opacity(controlsAppeared ? 1 : 0)
            .scaleEffect(controlsAppeared ? 1 : 0.9)

            HStack(spacing: isIPad ? 60 : RS.spacing(50)) {
                Button(action: { audioPlayerService.toggleShuffle() }) {
                    VStack(spacing: RS.spacing(6)) {
                        Image(systemName: "shuffle")
                            .font(.system(size: isIPad ? 22 : RS.fontSize(18), weight: .light))
                            .foregroundColor(audioPlayerService.isShuffleEnabled ? sacredGold : warmGray)
                            .offset(y: audioPlayerService.isShuffleEnabled ? -2 : 0)
                            .animation(.easeInOut(duration: 0.2), value: audioPlayerService.isShuffleEnabled)

                        if audioPlayerService.isShuffleEnabled {
                            Circle()
                                .fill(sacredGold)
                                .frame(width: RS.dimension(4), height: RS.dimension(4))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .frame(height: RS.dimension(35))
                    .animation(.easeInOut(duration: 0.2), value: audioPlayerService.isShuffleEnabled)
                }
                .buttonStyle(SacredPlayerButtonStyle())

                if showSleepTimer {
                    Button(action: { showSleepTimerSheet = true }) {
                        VStack(spacing: RS.spacing(6)) {
                            Image(systemName: "moon.zzz")
                                .font(.system(size: isIPad ? 22 : RS.fontSize(18), weight: .light))
                                .foregroundColor(audioPlayerService.sleepTimeRemaining != nil ? sacredGold : warmGray)
                                .offset(y: audioPlayerService.sleepTimeRemaining != nil ? -2 : 0)
                                .animation(.easeInOut(duration: 0.2), value: audioPlayerService.sleepTimeRemaining != nil)

                            if let remaining = audioPlayerService.sleepTimeRemaining {
                                Text(formatSleepTime(remaining))
                                    .font(.system(size: RS.fontSize(8), weight: .medium))
                                    .foregroundColor(sacredGold)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .frame(height: RS.dimension(35))
                        .animation(.easeInOut(duration: 0.2), value: audioPlayerService.sleepTimeRemaining != nil)
                    }
                    .buttonStyle(SacredPlayerButtonStyle())
                }

                Button(action: { audioPlayerService.toggleRepeatMode() }) {
                    VStack(spacing: RS.spacing(6)) {
                        Image(systemName: audioPlayerService.repeatMode.icon)
                            .font(.system(size: isIPad ? 22 : RS.fontSize(18), weight: .light))
                            .foregroundColor(audioPlayerService.repeatMode != .off ? sacredGold : warmGray)
                            .offset(y: audioPlayerService.repeatMode != .off ? -2 : 0)
                            .animation(.easeInOut(duration: 0.2), value: audioPlayerService.repeatMode)

                        if audioPlayerService.repeatMode != .off {
                            Circle()
                                .fill(sacredGold)
                                .frame(width: RS.dimension(4), height: RS.dimension(4))
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .frame(height: RS.dimension(35))
                    .animation(.easeInOut(duration: 0.2), value: audioPlayerService.repeatMode)
                }
                .buttonStyle(SacredPlayerButtonStyle())
            }
            .padding(.bottom, isIPad ? 40 : 0)
            .opacity(bottomControlsAppeared ? 1 : 0)
            .offset(y: bottomControlsAppeared ? 0 : 15)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .sheet(isPresented: $showSleepTimerSheet) {
            SacredSleepTimerSheet(isPresented: $showSleepTimerSheet)
                .environmentObject(audioPlayerService)
        }
    }

    private func isCurrentSurahLiked() -> Bool {
        guard let surah = audioPlayerService.currentSurah,
              let reciter = audioPlayerService.currentReciter else { return false }
        return audioPlayerService.isLiked(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
    }

    @ViewBuilder
    private func surahListView(size: CGSize, isIPad: Bool) -> some View {
        let horizontalPadding: CGFloat = isIPad ? 40 : 20
        let artworkSize = isIPad ? min(size.width * 0.7, 600) : (size.width - (horizontalPadding * 2) - 10)

        ScrollViewReader { scrollProxy in
            ScrollView {
                if allSurahs.isEmpty {
                    VStack {
                        ProgressView()
                            .tint(sacredGold)
                            .scaleEffect(1.5)
                        Text("Loading Surahs...")
                            .font(.caption)
                            .foregroundColor(warmGray)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        if let reciter = audioPlayerService.currentReciter {
                            ForEach(allSurahs) { surah in
                                Button(action: {
                                    audioPlayerService.load(surah: surah, reciter: reciter)
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showSurahList = false
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        ZStack(alignment: .bottomTrailing) {
                                            Text("\(surah.number)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(audioPlayerService.currentSurah?.number == surah.number ? (themeManager.effectiveTheme == .dark ? .black : .white) : .white)
                                                .frame(width: 35, height: 35)
                                                .background(
                                                    Circle()
                                                        .fill(audioPlayerService.currentSurah?.number == surah.number ? sacredGold : Color.secondary.opacity(0.3))
                                                )

                                            if audioPlayerService.completedSurahNumbers.contains(surah.number) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(softGreen)
                                                    .background(Circle().fill(cardBackground).frame(width: 11, height: 11))
                                                    .offset(x: 2, y: 2)
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(surah.englishName)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(themeManager.theme.primaryText)

                                            Text("\(surah.revelationType) - \(surah.numberOfAyahs) Ayahs")
                                                .font(.caption2)
                                                .foregroundColor(warmGray)
                                        }

                                        Spacer()

                                        if audioPlayerService.currentSurah?.number == surah.number && audioPlayerService.isPlaying {
                                            Image(systemName: "waveform")
                                                .foregroundColor(sacredGold)
                                                .font(.caption)
                                                .symbolEffect(.variableColor.iterative)
                                        } else {
                                            Image(systemName: "play.circle")
                                                .foregroundColor(warmGray.opacity(0.5))
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(audioPlayerService.currentSurah?.number == surah.number
                                                  ? sacredGold.opacity(0.1)
                                                  : Color.clear)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(surah.number)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
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
            .onAppear { loadSurahsIfNeeded() }
            .onChange(of: showSurahList) { isShowing in
                if isShowing, let currentSurah = audioPlayerService.currentSurah {
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
                await MainActor.run { self.allSurahs = surahs }
            } catch {}
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

#Preview {
    @Previewable @Namespace var animation
    FullScreenPlayer(isPresented: .constant(true), showSurahList: .constant(false), animation: animation)
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
}
