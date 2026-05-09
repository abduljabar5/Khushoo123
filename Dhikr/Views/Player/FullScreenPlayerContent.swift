//
//  FullScreenPlayerContent.swift
//  Dhikr
//
//  Full screen player content (title, slider, transport, surah list)
//  Artwork is managed by ExpandablePlayerView for morphing.
//

import SwiftUI

struct FullScreenPlayerContent: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @ObservedObject var progress: PlaybackProgress
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var showSurahList: Bool
    @Binding var isExpanded: Bool
    @State private var showSleepTimerSheet = false
    @State private var showAmbientSoundSheet = false

    /// Heart pop animation state. heartScale springs to 1.3x then back to 1.0
    /// (or 1.1 if liked) on tap. heartRippleOpacity fades a ring out behind.
    @State private var heartScale: CGFloat = 1.0
    @State private var heartRippleScale: CGFloat = 0.5
    @State private var heartRippleOpacity: Double = 0
    @ObservedObject private var ambientSoundService = BackgroundSoundService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @AppStorage("showSleepTimer") private var showSleepTimer = true

    private var isPreviewMode: Bool {
        guard let reciter = audioPlayerService.currentReciter else { return false }
        return reciter.isPremium && !subscriptionService.hasPremiumAccess
    }

    // Sacred colors
    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    let artworkSize: CGFloat
    let isIPad: Bool

    var body: some View {
        let horizontalPadding: CGFloat = isIPad ? 40 : 20

        VStack(spacing: isIPad ? 20 : RS.spacing(24)) {
            // Title / Artist / Chevron + Like
            titleSection

            // Error banner
            if let error = audioPlayerService.errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.45, blue: 0.35).opacity(0.9))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: audioPlayerService.errorMessage)
            }

            // Slider + time labels
            sliderSection(horizontalPadding: horizontalPadding)

            // Transport controls
            transportControls

            // Shuffle / Sleep / Repeat row
            bottomControls(horizontalPadding: horizontalPadding)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, isIPad ? 40 : 20)
        .sheet(isPresented: $showSleepTimerSheet) {
            SacredSleepTimerSheet(isPresented: $showSleepTimerSheet)
                .environmentObject(audioPlayerService)
        }
        .sheet(isPresented: $showAmbientSoundSheet) {
            AmbientSoundSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        ZStack(alignment: .center) {
            Button(action: {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showSurahList.toggle()
                }
            }) {
                VStack(spacing: RS.spacing(10)) {
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

                    HStack(spacing: 8) {
                        Text(audioPlayerService.currentReciter?.englishName ?? "")
                            .font(.system(size: isIPad ? 16 : RS.fontSize(14), weight: .light))
                            .foregroundColor(warmGray)
                            .lineLimit(1)

                        if isPreviewMode {
                            Text("PREVIEW · 60s")
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(sacredGold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(sacredGold.opacity(0.15))
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PlainButtonStyle())

            HStack {
                Spacer()
                Button(action: {
                    if let surah = audioPlayerService.currentSurah,
                       let reciter = audioPlayerService.currentReciter {
                        HapticManager.shared.impact(.medium)
                        audioPlayerService.toggleLike(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
                        playHeartPop()
                    }
                }) {
                    ZStack {
                        // Ripple ring expanding behind the heart on tap.
                        Circle()
                            .stroke(Color(red: 0.85, green: 0.4, blue: 0.4), lineWidth: 1.5)
                            .frame(width: isIPad ? 36 : RS.fontSize(32),
                                   height: isIPad ? 36 : RS.fontSize(32))
                            .scaleEffect(heartRippleScale)
                            .opacity(heartRippleOpacity)
                            .allowsHitTesting(false)

                        Image(systemName: isCurrentSurahLiked() ? "heart.fill" : "heart")
                            .font(.system(size: isIPad ? 26 : RS.fontSize(22), weight: .light))
                            .foregroundColor(isCurrentSurahLiked() ? Color(red: 0.85, green: 0.4, blue: 0.4) : warmGray)
                            .scaleEffect(heartScale)
                    }
                }
                .buttonStyle(SacredPlayerButtonStyle())
                .onAppear {
                    // Settle to the resting scale for the current liked state.
                    heartScale = isCurrentSurahLiked() ? 1.1 : 1.0
                }
                .onChange(of: audioPlayerService.currentSurah?.number) { _ in
                    // New track loaded — snap heart to resting state for new context.
                    heartScale = isCurrentSurahLiked() ? 1.1 : 1.0
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Slider Section
    private func sliderSection(horizontalPadding: CGFloat) -> some View {
        VStack(spacing: isIPad ? 10 : 8) {
            SacredSlider(
                value: Binding(
                    get: { audioPlayerService.progress.currentTime },
                    set: { audioPlayerService.seek(to: $0) }
                ),
                range: 0...max(audioPlayerService.progress.duration, 1),
                accentColor: sacredGold
            )
            .frame(height: 20)

            HStack {
                Text(audioPlayerService.progress.currentTime.formattedTime)
                Spacer()
                Text(audioPlayerService.progress.duration.formattedTime)
            }
            .font(.system(size: isIPad ? 13 : 11, weight: .light, design: .monospaced))
            .foregroundColor(warmGray)
        }
        .padding(.horizontal, isIPad ? 40 : 10)
    }

    // MARK: - Transport Controls
    private var transportControls: some View {
        HStack(spacing: isIPad ? 80 : RS.spacing(60)) {
            Button(action: {
                HapticManager.shared.impact(.light)
                audioPlayerService.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: isIPad ? 32 : RS.fontSize(26), weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
            }
            .buttonStyle(SacredPlayerButtonStyle())

            Button(action: {
                HapticManager.shared.impact(.medium)
                audioPlayerService.togglePlayPause()
            }) {
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

            Button(action: {
                HapticManager.shared.impact(.light)
                audioPlayerService.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: isIPad ? 32 : RS.fontSize(26), weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
            }
            .buttonStyle(SacredPlayerButtonStyle())
        }
        .padding(.vertical, isIPad ? 20 : RS.spacing(10))
    }

    // MARK: - Bottom Controls (Shuffle / Sleep / Ambient / Repeat)
    private func bottomControls(horizontalPadding: CGFloat) -> some View {
        HStack(spacing: isIPad ? 50 : RS.spacing(38)) {
            Button(action: {
                HapticManager.shared.selection()
                audioPlayerService.toggleShuffle()
            }) {
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
                Button(action: {
                    HapticManager.shared.impact(.light)
                    showSleepTimerSheet = true
                }) {
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

            Button(action: {
                HapticManager.shared.impact(.light)
                showAmbientSoundSheet = true
            }) {
                VStack(spacing: RS.spacing(6)) {
                    Image(systemName: "leaf")
                        .font(.system(size: isIPad ? 22 : RS.fontSize(18), weight: .light))
                        .foregroundColor(ambientSoundService.currentSound != nil ? sacredGold : warmGray)
                        .offset(y: ambientSoundService.currentSound != nil ? -2 : 0)
                        .animation(.easeInOut(duration: 0.2), value: ambientSoundService.currentSound?.id)

                    if ambientSoundService.currentSound != nil {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: RS.dimension(4), height: RS.dimension(4))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: RS.dimension(35))
                .animation(.easeInOut(duration: 0.2), value: ambientSoundService.currentSound?.id)
            }
            .buttonStyle(SacredPlayerButtonStyle())

            Button(action: {
                HapticManager.shared.selection()
                audioPlayerService.toggleRepeatMode()
            }) {
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
    }

    // MARK: - Helpers

    private func isCurrentSurahLiked() -> Bool {
        guard let surah = audioPlayerService.currentSurah,
              let reciter = audioPlayerService.currentReciter else { return false }
        return audioPlayerService.isLiked(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
    }

    private func formatSleepTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        return "\(minutes)m"
    }

    /// Heart pop: scale up + spring back, ripple ring expands and fades.
    /// Plays on every tap (like AND unlike) for consistent tactile feedback.
    private func playHeartPop() {
        // Pop the heart up then settle to the (newly toggled) resting state.
        let restingScale: CGFloat = isCurrentSurahLiked() ? 1.1 : 1.0
        heartScale = restingScale
        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            heartScale = 1.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                heartScale = restingScale
            }
        }

        // Ripple ring expands and fades.
        heartRippleScale = 0.5
        heartRippleOpacity = 0.7
        withAnimation(.easeOut(duration: 0.55)) {
            heartRippleScale = 2.0
            heartRippleOpacity = 0
        }
    }
}
