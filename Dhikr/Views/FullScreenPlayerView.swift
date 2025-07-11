//
//  FullScreenPlayerView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher
import AVFoundation
import AVKit

struct FullScreenPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var showingReciterDetail = false
    @State private var showingSleepTimerSheet = false
    @StateObject private var artworkViewModel: PlayerArtworkViewModel
    
    var onMinimize: (() -> Void)?
    
    init(onMinimize: @escaping () -> Void) {
        self.onMinimize = onMinimize
        _artworkViewModel = StateObject(wrappedValue: PlayerArtworkViewModel(audioPlayerService: AudioPlayerService.shared))
    }

    var body: some View {
        ZStack {
            artworkBackground
            gradientOverlay

            VStack(spacing: 0) {
                header
                    .padding(.top, 80) // Increased top padding further
                    .padding(.horizontal, 24)
                
                Spacer()
                
                VStack(spacing: 24) {
                    trackInfo
                    progressBar
                    playbackControls
                    bottomControls
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 80) // Increased bottom padding further
            }
        }
        .foregroundColor(.white)
        .background(Color.black)
        .clipped()
        .sheet(isPresented: $showingReciterDetail) {
            if let reciter = audioPlayerService.currentReciter {
                NavigationView {
                    ReciterDetailView(reciter: reciter)
                }
            }
        }
        .sheet(isPresented: $showingSleepTimerSheet) {
            SleepTimerSheet(audioPlayerService: audioPlayerService)
                .presentationDetents([.height(300)])
        }
        .navigationBarHidden(true)
        .ignoresSafeArea(.all, edges: .all)
        .onChange(of: artworkViewModel.artworkURL) { newURL in
             guard let url = newURL else { return }
            
             KingfisherManager.shared.retrieveImage(with: url) { result in
                 switch result {
                 case .success(let imageResult):
                     audioPlayerService.updateArtwork(with: imageResult.image)
                 case .failure(let error):
                     print("❌ [FullScreenPlayerView] Failed to download artwork: \(error)")
                 }
             }
        }
    }
    
    // MARK: - View Components

    private var artworkBackground: some View {
        ZStack {
            // Base animated gradient, always visible
            AnimatedGradientBackground()
                .ignoresSafeArea(.all, edges: .all)

            // Display the image if we have a URL - completely independent of safe area
            if let url = artworkViewModel.artworkURL {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea(.all, edges: .all)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
                    .layoutPriority(-1) // Give this the lowest layout priority
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .all)
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
        .ignoresSafeArea(.all, edges: .all)
    }

    private var header: some View {
        HStack {
            Button(action: { onMinimize?() }) {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
            }
            Spacer()
            Text(audioPlayerService.currentReciter?.name ?? "Now Playing")
                .font(.footnote)
                .fontWeight(.semibold)
                .lineLimit(1)
            Spacer()
            
            // Favorite Reciter Button
            Button(action: {
                guard let reciter = audioPlayerService.currentReciter else {
                    print("❌ [Favorite] Reciter is nil, cannot toggle favorite.")
                    return
                }
                print("🔖 [Favorite] Toggling favorite for reciter: \(reciter.name)")
                favoritesManager.toggleFavorite(reciter: reciter)
            }) {
                if let reciter = audioPlayerService.currentReciter, favoritesManager.isFavorite(reciter: reciter) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "bookmark")
                }
            }
            .font(.body.weight(.semibold))
        }
    }
    
    private var trackInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(audioPlayerService.currentSurah?.englishName ?? "Surah Name")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                if let reciter = audioPlayerService.currentReciter {
                    Button(action: { showingReciterDetail = true }) {
                        Text(reciter.englishName)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                } else {
                    Text("Reciter Name")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
            
            Button(action: { artworkViewModel.forceRefreshArtwork() }) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.title2)
            }
            
            Button(action: {
                showingSleepTimerSheet = true
            }) {
                Image(systemName: "timer")
                    .font(.title2)
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
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
    }
    
    private var playbackControls: some View {
        HStack(spacing: 50) {
            Button(action: { audioPlayerService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            Button(action: { audioPlayerService.togglePlayPause() }) {
                Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .bold))
            }
            Button(action: { audioPlayerService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
    }

    private var bottomControls: some View {
        HStack {
            Button(action: {
                print("🔀 [Shuffle] Toggling shuffle. Current: \(audioPlayerService.isShuffleEnabled)")
                audioPlayerService.isShuffleEnabled.toggle()
            }) {
                Image(systemName: "shuffle")
                    .font(.body)
                    .foregroundColor(audioPlayerService.isShuffleEnabled ? .accentColor : .white)
            }
            
            Spacer()
            
            Button(action: {
                print("🔁 [Repeat] Toggling repeat mode. Current: \(audioPlayerService.repeatMode)")
                audioPlayerService.toggleRepeatMode()
            }) {
                Image(systemName: audioPlayerService.repeatMode.icon)
                    .font(.body)
                    .foregroundColor(audioPlayerService.repeatMode != .off ? .accentColor : .white)
            }
            
            Spacer()
            
            Button(action: {
                guard let surah = audioPlayerService.currentSurah, let reciter = audioPlayerService.currentReciter else {
                    print("❌ [Like] Surah or Reciter is nil, cannot toggle like.")
                    return
                }
                print("❤️ [Like] Toggling like for Surah \(surah.number) by Reciter \(reciter.identifier)")
                audioPlayerService.toggleLike(surahNumber: surah.number, reciterIdentifier: reciter.identifier)
            }) {
                if let surah = audioPlayerService.currentSurah, let reciter = audioPlayerService.currentReciter,
                   audioPlayerService.isLiked(surahNumber: surah.number, reciterIdentifier: reciter.identifier) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "heart")
                }
            }
            .font(.body)
        }
    }
}

// MARK: - Sleep Timer Sheet
struct SleepTimerSheet: View {
    @ObservedObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) var dismiss

    let timerOptions: [Double] = [15, 30, 45, 60] // in minutes

    var body: some View {
        NavigationView {
            List {
                if let remaining = audioPlayerService.sleepTimeRemaining {
                    Section("Active Timer") {
                        HStack {
                            Text("Time remaining:")
                            Spacer()
                            Text(remaining.formattedForCountdown)
                                .fontWeight(.bold)
                        }
                        Button("Cancel Sleep Timer", role: .destructive) {
                            audioPlayerService.cancelSleepTimer()
                            dismiss()
                        }
                    }
                }

                Section("Set Timer") {
                    ForEach(timerOptions, id: \.self) { minutes in
                        Button("\(Int(minutes)) minutes") {
                            audioPlayerService.setSleepTimer(minutes: minutes)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Helper Extensions
extension TimeInterval {
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Previews
struct FullScreenPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let audioPlayer = AudioPlayerService.shared
        // Mock data for preview
        let surah = Surah(number: 1, name: "Al-Fatihah", englishName: "The Opening", englishNameTranslation: "The Opening", numberOfAyahs: 7, revelationType: "Meccan")
        let reciter = Reciter.mock
        
        audioPlayer.currentSurah = surah
        audioPlayer.currentReciter = reciter
        audioPlayer.isPlaying = true
        audioPlayer.duration = 240
        audioPlayer.currentTime = 60

        // Manually like the item for preview purposes
        audioPlayer.toggleLike(surahNumber: surah.number, reciterIdentifier: reciter.identifier)

        return FullScreenPlayerView(onMinimize: {})
            .environmentObject(audioPlayer)
            .environmentObject(FavoritesManager.shared)
    }
}

struct AirPlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        let routePickerView = AVRoutePickerView()
        routePickerView.activeTintColor = UIColor.systemBlue
        routePickerView.tintColor = UIColor.white
        return routePickerView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

#Preview {
    FullScreenPlayerView(onMinimize: {})
    .environmentObject(AudioPlayerService.shared)
} 