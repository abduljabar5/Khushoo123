//
//  AmbientSoundSheet.swift
//  Dhikr
//
//  Picker for layering ambient sounds (rain, ocean, fire, etc.)
//  underneath the Quran audio.
//

import SwiftUI

struct AmbientSoundSheet: View {
    @ObservedObject private var service = BackgroundSoundService.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }
    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.theme.primaryBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Layer a calming sound underneath your recitation")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(AmbientSound.all) { sound in
                            soundTile(sound)
                        }
                    }
                    .padding(.horizontal, 20)

                    if service.currentSound != nil {
                        volumeSection
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()
                }
                .padding(.top, 12)
            }
            .navigationTitle("Background Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(themeManager.theme.secondaryText.opacity(0.1))
                            )
                    }
                }
                if service.currentSound != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Stop") {
                            HapticManager.shared.impact(.light)
                            withAnimation { service.stop() }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(sacredGold)
                    }
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private func soundTile(_ sound: AmbientSound) -> some View {
        let isActive = service.currentSound?.id == sound.id

        return Button(action: {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                service.play(sound)
            }
        }) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isActive ? sacredGold.opacity(0.18) : cardBackground)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(isActive ? sacredGold : warmGray.opacity(0.2), lineWidth: 1)
                        )

                    Image(systemName: sound.systemImage)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isActive ? sacredGold : warmGray)
                }

                Text(sound.title)
                    .font(.system(size: 12, weight: isActive ? .medium : .light))
                    .foregroundColor(isActive ? sacredGold : themeManager.theme.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var volumeSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Volume")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(warmGray)
                Spacer()
            }

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundColor(warmGray)

                Slider(value: $service.volume, in: 0...1)
                    .tint(sacredGold)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(warmGray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
