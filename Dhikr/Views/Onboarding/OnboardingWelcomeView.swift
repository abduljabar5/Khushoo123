//
//  OnboardingWelcomeView.swift
//  Dhikr
//
//  Welcome screen with app value points (Screen 1)
//

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon or Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.prayerGradientStart, theme.prayerGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 32)

            // Title
            Text("Welcome to Khushoo")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Subtitle
            Text("Your companion for prayer, dhikr, and spiritual focus")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // Value Points
            VStack(spacing: 24) {
                ValuePointRow(
                    icon: "iphone.slash",
                    iconColor: theme.primaryAccent,
                    title: "Prayer-Time App Blocking",
                    description: "Stay focused during prayer times",
                    theme: theme
                )

                ValuePointRow(
                    icon: "location.circle.fill",
                    iconColor: theme.accentGold,
                    title: "Accurate Prayer Times",
                    description: "Based on your location",
                    theme: theme
                )

                ValuePointRow(
                    icon: "hands.sparkles",
                    iconColor: theme.accentGreen,
                    title: "Dhikr Tracking & Zikr Ring",
                    description: "Track your daily remembrance",
                    theme: theme
                )

                ValuePointRow(
                    icon: "waveform",
                    iconColor: theme.accentTeal,
                    title: "Quran Audio",
                    description: "15+ free reciters included",
                    theme: theme
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Actions
            VStack(spacing: 16) {
                // Primary: Continue
                Button(action: {
                    onContinue()
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.prayerGradientStart, theme.prayerGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(theme.primaryBackground)
        .onAppear {
        }
    }
}

// MARK: - Supporting Views

struct ValuePointRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
