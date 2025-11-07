//
//  MiniPlayerView.swift
//  Dhikr
//
//  Created for mini player display
//

import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Binding var expanded: Bool
    var animationNamespace: Namespace.ID

    var body: some View {
        HStack(spacing: 15) {
            PlayerInfo(.init(width: 45, height: 45))

            Spacer(minLength: 0)

            /// Action Buttons
            if audioPlayerService.isLoading {
                // Show loading indicator when audio is loading
                ProgressView()
                    .scaleEffect(0.9)
                    .padding(.trailing, 10)
            } else {
                Button {
                    audioPlayerService.togglePlayPause()
                } label: {
                    Image(systemName: audioPlayerService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .contentShape(.rect)
                }
                .padding(.trailing, 10)

                Button {
                    audioPlayerService.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .contentShape(.rect)
                }
            }
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }

    /// Player Info
    @ViewBuilder
    func PlayerInfo(_ size: CGSize) -> some View {
        HStack(spacing: 12) {
            // Artwork
            if audioPlayerService.isLoading {
                // Show shimmer placeholder while loading
                RoundedRectangle(cornerRadius: 7)
                    .fill(.gray.opacity(0.2))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            } else if let artwork = audioPlayerService.currentArtwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.gray.opacity(0.3))
                    .frame(width: size.width, height: size.height)
            }

            // Text info
            VStack(alignment: .leading, spacing: 6) {
                if audioPlayerService.isLoading {
                    // Loading placeholder text
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
    }
}
