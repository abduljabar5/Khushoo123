//
//  OnboardingWelcomeView.swift
//  Dhikr
//
//  Welcome screen with app value points (Screen 1)
//

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon or Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
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
                .foregroundColor(Color(hex: "2C3E50"))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            // Subtitle
            Text("Your companion for prayer, dhikr, and spiritual focus")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Color(hex: "7F8C8D"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // Value Points
            VStack(spacing: 24) {
                ValuePointRow(
                    icon: "iphone.slash",
                    iconColor: Color(hex: "1A9B8A"),
                    title: "Prayer-Time App Blocking",
                    description: "Stay focused during prayer times"
                )

                ValuePointRow(
                    icon: "location.circle.fill",
                    iconColor: Color(hex: "F39C12"),
                    title: "Accurate Prayer Times",
                    description: "Based on your location"
                )

                ValuePointRow(
                    icon: "hands.sparkles",
                    iconColor: Color(hex: "27AE60"),
                    title: "Dhikr Tracking & Zikr Ring",
                    description: "Track your daily remembrance"
                )

                ValuePointRow(
                    icon: "waveform",
                    iconColor: Color(hex: "16A085"),
                    title: "Quran Audio",
                    description: "15+ free reciters included"
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
                                        colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
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

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "2C3E50"))

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
}
