//
//  FullScreenPlayerView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher

struct FullScreenPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var isExpanded = false
    @State private var showSleepTimerSheet = false
    @State private var showSurahPickerSheet = false
    @State private var sleepTimerMinutes: Int? = nil
    @State private var sleepTimerActive = false
    @State private var sleepTimerRemaining: Int = 0
    @State private var sleepTimer: Timer? = nil
    @State private var likedSurahs: Set<Int> = Set(UserDefaults.standard.array(forKey: "likedSurahs") as? [Int] ?? [])
    @StateObject private var artworkViewModel: PlayerArtworkViewModel
    var onMinimize: (() -> Void)? = nil
    
    init(onMinimize: @escaping () -> Void) {
        self.onMinimize = onMinimize
        _artworkViewModel = StateObject(wrappedValue: PlayerArtworkViewModel(audioPlayerService: AudioPlayerService.shared))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen Artwork Background with Loading/Error states
                artworkBackground

                // Gradient Overlay for Readability
                gradientOverlay

                // Main Player UI
                VStack {
                    header
                    Spacer()
                    VStack(spacing: 15) {
                        trackInfo
                        progressBar
                        playbackControls
                        bottomToolbar
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom)
                .padding(.top, 20)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .foregroundColor(.white)
            .gesture(
                DragGesture().onEnded { value in
                    if value.translation.height > 50 {
                        onMinimize?()
                    }
                }
            )
            .sheet(isPresented: $showSleepTimerSheet) {
                SleepTimerSheet(selectedMinutes: $sleepTimerMinutes, onSet: { minutes in
                    setSleepTimer(minutes: minutes)
                })
            }
            .sheet(isPresented: $showSurahPickerSheet) {
                SurahPickerSheet(
                    reciter: audioPlayerService.currentReciter,
                    selectedSurah: audioPlayerService.currentSurah,
                    onSelect: { surah in
                        if let reciter = audioPlayerService.currentReciter {
                            audioPlayerService.load(surah: surah, reciter: reciter)
                        }
                        showSurahPickerSheet = false
                    }
                )
            }
            .onAppear {
                // Restore liked surahs
                likedSurahs = Set(UserDefaults.standard.array(forKey: "likedSurahs") as? [Int] ?? [])
            }
        }
    }
    
    // MARK: - View Components

    private var artworkBackground: some View {
        ZStack {
            // Base animated gradient, always visible
            AnimatedGradientBackground()

            // Display the image if we have a URL
            if let url = artworkViewModel.artworkURL {
                Color.clear
                    .overlay(
                        KFImage(url)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }
            
            // Overlay for loading and error states during URL generation
            if artworkViewModel.isLoading {
                ProgressView().tint(.white)
            } else if let errorMessage = artworkViewModel.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                    Text("Failed to create image")
                        .fontWeight(.semibold)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .black.opacity(0.6), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .clear, location: 0.7),
                .init(color: .black.opacity(0.8), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .edgesIgnoringSafeArea(.all)
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
            }
            Spacer()
            Text(audioPlayerService.currentReciter?.name ?? "Now Playing")
                .font(.footnote)
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            Button(action: {}) {
                Image(systemName: "ellipsis")
            }
        }
        .padding(.top, 20)
    }
    
    private var trackInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(audioPlayerService.currentSurah?.englishName ?? "Surah Name")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(audioPlayerService.currentReciter?.englishName ?? "Reciter Name")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { showSleepTimerSheet = true }) {
                Image(systemName: "timer")
                    .font(.title2)
            }
        }
        .padding(.horizontal)
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            Slider(value: Binding(
                get: { audioPlayerService.currentTime },
                set: { audioPlayerService.seek(to: $0) }
            ), in: 0...audioPlayerService.duration, step: 1)
            .accentColor(.white)

            HStack {
                Text(audioPlayerService.currentTime.formattedTime)
                Spacer()
                Text(audioPlayerService.duration.formattedTime)
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal)
    }
    
    private var playbackControls: some View {
        HStack(spacing: 40) {
            Button(action: { audioPlayerService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            Button(action: { audioPlayerService.togglePlayPause() }) {
                Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44, weight: .bold))
            }
            Button(action: { audioPlayerService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: { audioPlayerService.toggleAutoplay() }) {
                Image(systemName: audioPlayerService.isAutoplayEnabled ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle")
            }
            .foregroundColor(audioPlayerService.isAutoplayEnabled ? .accentColor : .white)
            Spacer()
            Button(action: { audioPlayerService.toggleShuffle() }) {
                Image(systemName: "shuffle")
            }
            .foregroundColor(audioPlayerService.isShuffleEnabled ? .accentColor : .white)
            Spacer()
            Button(action: { audioPlayerService.toggleRepeatMode() }) {
                Image(systemName: audioPlayerService.repeatMode.icon)
            }
            .foregroundColor(audioPlayerService.repeatMode != .off ? .accentColor : .white)
            Spacer()
            Button(action: toggleLike) {
                Image(systemName: isSurahLiked() ? "heart.fill" : "heart")
            }
            .foregroundColor(isSurahLiked() ? .pink : .white)
        }
        .font(.headline)
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    private var progressPercentage: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
    
    private var repeatModeIcon: String {
        switch audioPlayerService.repeatMode {
        case .off:
            return "repeat"
        case .one:
            return "repeat.1"
        case .all:
            return "repeat"
        }
    }
    
    private var repeatModeColor: Color {
        switch audioPlayerService.repeatMode {
        case .off:
            return .white.opacity(0.6)
        case .one, .all:
            return .white
        }
    }
    
    private var shuffleModeColor: Color {
        audioPlayerService.isShuffleEnabled ? .white : .white.opacity(0.6)
    }
    
    // MARK: - Helper Methods
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func isSurahLiked() -> Bool {
        guard let surahNum = audioPlayerService.currentSurah?.number else { return false }
        return likedSurahs.contains(surahNum)
    }
    
    // Sleep timer logic
    private func setSleepTimer(minutes: Int) {
        sleepTimerMinutes = minutes
        sleepTimerRemaining = minutes * 60
        sleepTimerActive = true
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            sleepTimerRemaining -= 1
            if sleepTimerRemaining <= 0 {
                audioPlayerService.pause()
                sleepTimerActive = false
                sleepTimer?.invalidate()
            }
        }
    }
    private func cancelSleepTimer() {
        sleepTimerActive = false
        sleepTimer?.invalidate()
    }
    // Like/Unlike logic
    private func toggleLike() {
        guard let surahNum = audioPlayerService.currentSurah?.number else { return }
        if likedSurahs.contains(surahNum) {
            likedSurahs.remove(surahNum)
        } else {
            likedSurahs.insert(surahNum)
        }
        UserDefaults.standard.set(Array(likedSurahs), forKey: "likedSurahs")
    }
}

// MARK: - Animated Background
struct AnimatedGradientBackground: View {
    @State private var startPoint = UnitPoint.topLeading
    @State private var endPoint = UnitPoint.bottomTrailing
    
    let colors = [
        Color.blue.opacity(0.8),
        Color.purple.opacity(0.6),
        Color.pink.opacity(0.6),
        Color.orange.opacity(0.5)
    ]

    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    self.startPoint = .bottomTrailing
                    self.endPoint = .topLeading
                }
            }
    }
}

// MARK: - TimeInterval Extension
extension TimeInterval {
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Sleep Timer Sheet
struct SleepTimerSheet: View {
    @Binding var selectedMinutes: Int?
    var onSet: (Int) -> Void
    let increments = [15, 30, 45, 60, 90, 120]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List(increments, id: \.self) { min in
                Button("\(min) minutes") {
                    selectedMinutes = min
                    onSet(min)
                    dismiss()
                }
            }
            .navigationTitle("Set Sleep Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// Surah Picker Sheet
struct SurahPickerSheet: View {
    let reciter: Reciter?
    let selectedSurah: Surah?
    var onSelect: (Surah) -> Void
    @EnvironmentObject var quranAPIService: QuranAPIService
    @State private var surahs: [Surah] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List(surahs) { surah in
                        Button(action: {
                            onSelect(surah)
                            dismiss()
                        }) {
                            HStack {
                                Text("\(surah.number). \(surah.englishName)")
                                Spacer()
                                if surah == selectedSurah {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Surah")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    do {
                        let fetched = try await quranAPIService.fetchSurahs()
                        await MainActor.run {
                            self.surahs = fetched
                            self.isLoading = false
                        }
                    } catch {
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

struct FullScreenPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock audio service instance for the preview
        let audioService = AudioPlayerService.shared
        
        // Setup mock data for preview
        audioService.currentSurah = Surah(number: 1, name: "Al-Fatihah", englishName: "The Opening", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        audioService.currentReciter = Reciter(identifier: "ar.alafasy", language: "ar", name: "مشاري راشد العفاسي", englishName: "Mishary Rashid Alafasy", server: nil, reciterId: nil)
        audioService.duration = 245
        audioService.currentTime = 120
        
        // Pass the required onMinimize parameter in the initializer
        return FullScreenPlayerView(onMinimize: {
            print("Preview minimize action triggered.")
        })
        .environmentObject(audioService)
    }
}

#Preview {
    FullScreenPlayerView(onMinimize: {
        print("Preview minimize action triggered.")
    })
    .environmentObject(AudioPlayerService.shared)
} 