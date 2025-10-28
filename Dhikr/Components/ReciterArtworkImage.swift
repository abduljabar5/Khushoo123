//
//  ReciterArtworkImage.swift
//  Dhikr
//
//  Reciter artwork with automatic fallback to placeholder
//

import SwiftUI
import Kingfisher

/// A view that displays reciter artwork with automatic fallback to generated placeholder
/// if the primary artwork URL fails to load
struct ReciterArtworkImage: View {
    let artworkURL: URL?
    let reciterName: String
    let size: CGFloat
    let showPlaceholder: Bool

    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    init(
        artworkURL: URL?,
        reciterName: String,
        size: CGFloat = 60,
        showPlaceholder: Bool = true
    ) {
        self.artworkURL = artworkURL
        self.reciterName = reciterName
        self.size = size
        self.showPlaceholder = showPlaceholder
    }

    var body: some View {
        ZStack {
            if let url = artworkURL {
                KFImage(url)
                    .onFailure { error in
                        print("⚠️ [ReciterArtwork] Artwork failed for \(reciterName), showing placeholder")
                    }
                    .resizable()
                    .loadDiskFileSynchronously()
                    .diskCacheExpiration(.never)
                    .fade(duration: 0.1)
                    .placeholder {
                        if showPlaceholder {
                            placeholderView
                        }
                    }
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if showPlaceholder {
                // No URL, show placeholder
                placeholderView
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholderView: some View {
        Circle()
            .fill(theme.tertiaryBackground)
            .overlay(
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(theme.tertiaryText)
            )
            .frame(width: size, height: size)
    }
}

/// Compact version for smaller displays
struct ReciterArtworkImageCompact: View {
    let artworkURL: URL?
    let reciterName: String

    @EnvironmentObject private var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        if let url = artworkURL {
            KFImage(url)
                .onFailure { _ in
                    print("⚠️ [ReciterArtwork] Compact artwork failed for \(reciterName), showing placeholder")
                }
                .resizable()
                .loadDiskFileSynchronously()
                .diskCacheExpiration(.never)
                .fade(duration: 0.1)
                .placeholder {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.tertiaryText)
                }
                .scaledToFill()
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(theme.tertiaryText)
        }
    }
}
