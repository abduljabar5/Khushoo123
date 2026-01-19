//
//  VoiceConfirmationBanner.swift
//  Dhikr
//
//  Sacred Minimalism redesign
//

import SwiftUI

struct VoiceConfirmationBanner: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var isDismissed = false
    @Binding var selectedTab: Int
    @AppStorage("focusStrictMode") private var strictMode = false

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

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

    var body: some View {
        if !isDismissed && strictMode && blocking.isWaitingForVoiceConfirmation {
            let timeRemaining = blocking.blockingEndTime.map { max(0, $0.timeIntervalSince(Date())) } ?? 0

            HStack(spacing: 14) {
                // Icon with sacred styling
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: timeRemaining > 0 ? "hourglass" : "mic")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(sacredGold)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("STRICT MODE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(warmGray)

                    if timeRemaining > 0 {
                        Text("Voice confirmation in \(timeRemaining.formattedForCountdown)")
                            .font(.system(size: 15, weight: .light))
                            .monospacedDigit()
                            .foregroundColor(themeManager.theme.primaryText)
                    } else {
                        Text("Voice confirmation required")
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                }

                Spacer(minLength: 0)

                // Countdown or chevron
                if timeRemaining > 0 {
                    Text(timeRemaining.formattedForCountdown)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(sacredGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(sacredGold.opacity(0.15))
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(sacredGold.opacity(0.2), lineWidth: 1)
            )
            .offset(y: offset)
            .opacity(1 - (abs(offset) / 100.0))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height < -50 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -200
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isDismissed = true
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                HapticManager.shared.impact(.light)
                withAnimation {
                    selectedTab = 3
                }
                isDismissed = false
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VoiceConfirmationBanner(selectedTab: .constant(0))
}
