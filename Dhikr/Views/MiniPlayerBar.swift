import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Binding var showingFullScreenPlayer: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.isDragGestureActive) private var isDragging
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar with smooth animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.systemGray4))
                        .frame(height: 2)
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progressPercentage)
                        .animation(isDragging ? nil : .linear(duration: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 2)
            .padding(.top, 0)
            .padding(.horizontal, themeManager.theme.hasGlassEffect ? 8 : 0)
            
            // Player controls
            HStack {
                if let artwork = audioPlayerService.currentArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .cornerRadius(4)
                        .clipped()
                } else {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(4)
                        .background(Color.gray.opacity(0.3))
                }
                
                VStack(alignment: .leading) {
                    Text(audioPlayerService.currentSurah?.englishName ?? "Not Playing")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(audioPlayerService.currentReciter?.englishName ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 8)
                
                Spacer()
                
                Button(action: {
                    audioPlayerService.togglePlayPause()
                }) {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 70)
        .background(
            Group {
                if themeManager.theme.hasGlassEffect {
                    // Enhanced liquid glass effect for iOS 26+
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .glassEffect( in: .rect(cornerRadius: 16.0))
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.1)
                            )
                    } else {
                        // Fallback for older iOS versions
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                } else {
                    // Standard background for light/dark themes
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                }
            }
        )
        .shadow(
            color: themeManager.theme.hasGlassEffect ?
                Color.black.opacity(0.15) :
                Color.black.opacity(0.1),
            radius: themeManager.theme.hasGlassEffect ? 10 : 5,
            x: 0,
            y: themeManager.theme.hasGlassEffect ? 5 : 2
        )
        .padding(.horizontal, 8) // Reduced padding to make it wider
        .padding(.bottom, 8)
        .animation(.spring(), value: audioPlayerService.currentSurah?.id)
    }
    
    private var progressPercentage: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
} 