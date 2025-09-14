import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Binding var showingFullScreenPlayer: Bool
    @StateObject private var themeManager = ThemeManager.shared
    
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
                        .animation(.linear(duration: 0.5), value: progressPercentage)
                }
            }
            .frame(height: 2)
            .padding(.top, 0)
            
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
            themeManager.theme.hasGlassEffect ?
            AnyView(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            ) :
            AnyView(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        )
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding(.horizontal, 8) // Reduced padding to make it wider
        .padding(.bottom, 8)
        .animation(.spring(), value: audioPlayerService.currentSurah?.id)
    }
    
    private var progressPercentage: Double {
        guard audioPlayerService.duration > 0 else { return 0 }
        return audioPlayerService.currentTime / audioPlayerService.duration
    }
} 