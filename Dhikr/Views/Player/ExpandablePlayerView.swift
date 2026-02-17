//
//  ExpandablePlayerView.swift
//  Dhikr
//
//  Apple Music-style continuous morphing player.
//  A single expandProgress (0=mini, 1=full) drives all visual interpolation.
//  ALL content is always in the view tree — only opacity changes. No conditional if/else
//  that adds/removes views mid-transition.
//

import SwiftUI

struct ExpandablePlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @ObservedObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    @Binding var expandProgress: CGFloat
    @Binding var isExpanded: Bool
    @State private var showSurahList = false
    @State private var allSurahs: [Surah] = []

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
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

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var isCurrentReciterFavorite: Bool {
        guard let reciter = audioPlayerService.currentReciter else { return false }
        return favoritesManager.isFavorite(reciter: reciter)
    }

    // Opacity curves — smooth cross-fade
    private var miniOpacity: CGFloat { 1.0 - min(expandProgress / 0.3, 1.0) }
    private var fullOpacity: CGFloat { max((expandProgress - 0.3) / 0.5, 0) }

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let screenHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom

            let progress = expandProgress
            let miniBarHeight: CGFloat = 64
            let playerHeight = miniBarHeight + (screenHeight - miniBarHeight) * progress
            let artworkSmall: CGFloat = 45
            let artworkLarge: CGFloat = isIPad ? min(screenWidth * 0.7, 600) : (screenWidth - 50)
            let artworkSize = artworkSmall + (artworkLarge - artworkSmall) * progress
            let artworkRadius: CGFloat = 7 + (13 * progress) // 7→20
            let bgCornerRadius: CGFloat = 15 + (40 * progress)

            ZStack(alignment: .bottom) {
                // === Full-screen layer (background + ambient + full content) ===
                ZStack {
                    // Solid background
                    pageBackground

                    // Ambient artwork blur
                    if let artwork = audioPlayerService.currentArtwork {
                        ZStack {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: screenWidth, height: screenHeight)
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

                    // Full-screen content
                    VStack(spacing: 0) {
                        // Capsule handle / iPad chevron
                        if isIPad {
                            HStack {
                                Button(action: { collapsePlayer() }) {
                                    Image(systemName: "chevron.down.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                                Spacer()
                            }
                            .padding(.top, safeTop + 8)
                            .padding(.bottom, 10)
                        } else {
                            capsuleHandleArea(safeTop: safeTop)
                        }

                        Spacer().frame(maxHeight: 20)

                        // Artwork + surah list overlay (card flip)
                        ZStack {
                            artworkView(size: artworkSize, cornerRadius: artworkRadius)
                                .rotation3DEffect(.degrees(showSurahList ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                                .opacity(showSurahList ? 0 : 1)

                            surahListView(size: artworkSize)
                                .rotation3DEffect(.degrees(showSurahList ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                                .opacity(showSurahList ? 1 : 0)
                        }
                        .frame(width: artworkSize, height: artworkSize)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSurahList)

                        // Full-screen controls
                        FullScreenPlayerContent(
                            showSurahList: $showSurahList,
                            isExpanded: $isExpanded,
                            artworkSize: artworkSize,
                            isIPad: isIPad
                        )
                        .environmentObject(audioPlayerService)
                        .environmentObject(quranAPIService)
                        .padding(.top, RS.spacing(10))

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: screenWidth, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: bgCornerRadius, style: .continuous))
                .offset(y: (1 - progress) * screenHeight)
                .opacity(fullOpacity)
                .allowsHitTesting(progress > 0.3)

                // === Mini bar layer ===
                HStack(spacing: 0) {
                    HStack(spacing: 12) {
                        miniArtwork(size: artworkSmall)
                        miniTextInfo
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { expandPlayer() }

                    miniButtons
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 15)
                .frame(height: miniBarHeight)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: -2)
                )
                .padding(.horizontal, 15 * (1 - progress))
                .offset(y: -(safeBottom + 85) * (1 - progress))
                .opacity(miniOpacity)
                .allowsHitTesting(progress < 0.3)
            }
            .frame(width: screenWidth, height: playerHeight, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            .gesture(
                PanGesture { value in
                    guard !isIPad else { return }
                    let translationY = value.translation.height
                    if isExpanded {
                        if translationY > 0 {
                            expandProgress = max(1.0 - (translationY / (screenHeight * 0.6)), 0)
                        }
                    } else {
                        if translationY < 0 {
                            expandProgress = min(-translationY / (screenHeight * 0.6), 1.0)
                        }
                    }
                } onEnd: { value in
                    guard !isIPad else { return }
                    let velocityY = value.velocity.height
                    let translationY = value.translation.height

                    if isExpanded {
                        if translationY > 200 || velocityY > 300 {
                            collapsePlayer()
                        } else {
                            expandPlayer()
                        }
                    } else {
                        if -translationY > 100 || -velocityY > 300 {
                            expandPlayer()
                        } else {
                            collapsePlayer()
                        }
                    }
                }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Capsule Handle

    private func capsuleHandleArea(safeTop: CGFloat) -> some View {
        let effectiveSafeTop = max(safeTop, 59)
        return VStack(spacing: 0) {
            Capsule()
                .fill(warmGray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, effectiveSafeTop + 10)
            Spacer()
        }
        .frame(height: effectiveSafeTop + 40)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { collapsePlayer() }
    }

    // MARK: - Artwork (shared, morphing)

    private func artworkView(size: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            Group {
                if let artwork = audioPlayerService.currentArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.25 * expandProgress), radius: 20, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(themeManager.effectiveTheme == .dark
                              ? Color(red: 0.12, green: 0.13, blue: 0.15)
                              : Color.white)
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.15 * expandProgress), radius: 15, x: 0, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
        .frame(width: size, height: size)
    }

    // MARK: - Mini Player Parts

    @ViewBuilder
    private func miniArtwork(size: CGFloat) -> some View {
        if audioPlayerService.isLoading {
            RoundedRectangle(cornerRadius: 7)
                .fill(.gray.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(ProgressView().scaleEffect(0.7))
        } else if let artwork = audioPlayerService.currentArtwork {
            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(.gray.opacity(0.3))
                .frame(width: size, height: size)
        }
    }

    private var miniTextInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if audioPlayerService.isLoading {
                Text("Loading...")
                    .font(.callout)
                    .foregroundStyle(.gray.opacity(0.7))
                Text("Please wait")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.5))
            } else {
                Text(audioPlayerService.currentSurah?.englishName ?? "Not Playing")
                    .font(.callout)
                Text(audioPlayerService.currentReciter?.englishName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var miniButtons: some View {
        if audioPlayerService.isLoading {
            ProgressView()
                .scaleEffect(0.9)
                .padding(.trailing, 10)
        } else {
            HStack(spacing: 0) {
                Button {
                    HapticManager.shared.impact(.light)
                    if let reciter = audioPlayerService.currentReciter {
                        favoritesManager.toggleFavorite(reciter: reciter)
                    }
                } label: {
                    Image(systemName: isCurrentReciterFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(isCurrentReciterFavorite ? Color(red: 0.85, green: 0.65, blue: 0.2) : Color.gray)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Button {
                    audioPlayerService.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }

                Button {
                    audioPlayerService.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Surah List (overlays artwork)

    @ViewBuilder
    private func surahListView(size: CGFloat) -> some View {
        let cardBg: Color = themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
        let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

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
                                                    .background(Circle().fill(cardBg).frame(width: 11, height: 11))
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
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBg)
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

    // MARK: - Actions

    private func expandPlayer() {
        withAnimation(.spring(duration: 0.5, bounce: 0)) {
            expandProgress = 1.0
            isExpanded = true
        }
    }

    private func collapsePlayer() {
        withAnimation(.spring(duration: 0.5, bounce: 0)) {
            expandProgress = 0.0
            isExpanded = false
            showSurahList = false
        }
    }
}
