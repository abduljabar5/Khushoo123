//
//  RecentsView.swift
//  Dhikr
//
//  Sacred Minimalism redesign
//

import SwiftUI
import Kingfisher

struct RecentsView: View {
    @ObservedObject private var recentsManager = RecentsManager.shared
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

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

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if recentsManager.recentItems.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(recentsManager.recentItems) { item in
                                    Button(action: {
                                        HapticManager.shared.impact(.light)
                                        audioPlayerService.load(surah: item.surah, reciter: item.reciter)
                                        dismiss()
                                    }) {
                                        SacredRecentItemRow(item: item, accentColor: sacredGold)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("RECENTLY PLAYED")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(warmGray)

                        Text("\(recentsManager.recentItems.count) tracks")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(themeManager.theme.secondaryText.opacity(0.1))
                            )
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(sacredGold.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("No Recent Tracks")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Your listening history\nwill appear here")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Sacred Recent Item Row
struct SacredRecentItemRow: View {
    let item: RecentItem
    let accentColor: Color

    @StateObject private var themeManager = ThemeManager.shared
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Artwork
            KFImage(item.reciter.artworkURL)
                .placeholder {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.1))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(accentColor.opacity(0.5))
                        )
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(item.surah.englishName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.reciter.englishName)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .lineLimit(1)

                    Circle()
                        .fill(warmGray.opacity(0.5))
                        .frame(width: 3, height: 3)

                    Text(item.playedAt, style: .relative)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(warmGray)
                        .id(currentTime)
                }
            }

            Spacer()

            // Play indicator
            Image(systemName: "play.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(accentColor.opacity(0.1), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}

// MARK: - Preview
#Preview {
    RecentsView()
        .environmentObject(AudioPlayerService.shared)
}
