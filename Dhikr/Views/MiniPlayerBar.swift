import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Binding var showingFullScreenPlayer: Bool
    @GestureState private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progressPercentage, height: 2)
                }
            }
            .frame(height: 2)
            // Player bar
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .font(.title3)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioPlayerService.currentSurah?.englishName ?? "Surah")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(audioPlayerService.currentReciter?.englishName ?? "Reciter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 16) {
                    Button(action: {
                        if audioPlayerService.isPlaying {
                            audioPlayerService.pause()
                        } else {
                            audioPlayerService.play()
                        }
                    }) {
                        ZStack {
                            if audioPlayerService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(!audioPlayerService.isReadyToPlay)
                    Button(action: { showingFullScreenPlayer = true }) {
                        Image(systemName: "chevron.up")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .top
            )
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < -40 {
                        showingFullScreenPlayer = true
                    }
                }
        )
        .onTapGesture {
            showingFullScreenPlayer = true
        }
    }
    private var progressPercentage: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
} 