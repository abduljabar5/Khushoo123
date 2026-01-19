//
//  OnboardingWelcomeView.swift
//  Dhikr
//
//  Welcome screen with app value points (Screen 1) - Sacred Minimalism redesign
//

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var mutedPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65)
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
        VStack(spacing: 0) {
            Spacer()

            // App Icon - Sacred style
            ZStack {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "moon.stars")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(sacredGold)
            }
            .padding(.bottom, 40)

            // Title - Sacred typography
            Text("Khushoo")
                .font(.system(size: 40, weight: .ultraLight, design: .serif))
                .foregroundColor(themeManager.theme.primaryText)
                .padding(.bottom, 8)

            Text("SPIRITUAL COMPANION")
                .font(.system(size: 11, weight: .medium))
                .tracking(3)
                .foregroundColor(warmGray)
                .padding(.bottom, 48)

            // Value Points - Sacred style
            VStack(spacing: 20) {
                SacredValuePointRow(
                    icon: "shield.fill",
                    title: "Prayer-Time Focus",
                    description: "Block distractions during salah",
                    color: sacredGold
                )

                SacredValuePointRow(
                    icon: "location.circle",
                    title: "Accurate Prayer Times",
                    description: "Based on your location",
                    color: softGreen
                )

                SacredValuePointRow(
                    icon: "hands.sparkles",
                    title: "Dhikr Tracking",
                    description: "Track your daily remembrance",
                    color: mutedPurple
                )

                SacredValuePointRow(
                    icon: "waveform",
                    title: "Quran Audio",
                    description: "15+ free reciters included",
                    color: warmGray
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue Button - Sacred style
            Button(action: onContinue) {
                Text("Begin")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(1)
                    .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(sacredGold)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(pageBackground)
    }
}

// MARK: - Sacred Value Point Row

private struct SacredValuePointRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    @StateObject private var themeManager = ThemeManager.shared

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
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(description)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(warmGray)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
