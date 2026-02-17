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
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var showSurahList: Bool
    @Binding var isExpanded: Bool
    @State private var showSleepTimerSheet = false
    @AppStorage("showSleepTimer") private var showSleepTimer = true

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
    }

    // MARK: - Title Section
    private var titleSection: some View {
        ZStack(alignment: .center) {
            Button(action: {
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
    }

    // MARK: - Slider Section
    private func sliderSection(horizontalPadding: CGFloat) -> some View {
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
    }

    // MARK: - Transport Controls
    private var transportControls: some View {
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
    }

    // MARK: - Bottom Controls (Shuffle / Sleep / Repeat)
    private func bottomControls(horizontalPadding: CGFloat) -> some View {
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
}
