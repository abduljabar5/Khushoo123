//
//  EarlyUnlockBanner.swift
//  Dhikr
//
//  Sacred Minimalism redesign
//

import SwiftUI

struct EarlyUnlockBanner: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var isDismissed = false

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
        if !isDismissed && !blocking.isStrictModeEnabled && blocking.appsActuallyBlocked && !blocking.isEarlyUnlockedActive {
            let remaining = blocking.timeUntilEarlyUnlock()

            HStack(spacing: 14) {
                // Icon with sacred styling
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: remaining > 0 ? "hourglass" : "lock.open")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(sacredGold)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    if remaining > 0 {
                        Text("EARLY UNLOCK")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(warmGray)

                        Text("Available in \(remaining.formattedForCountdown)")
                            .font(.system(size: 15, weight: .light))
                            .monospacedDigit()
                            .foregroundColor(themeManager.theme.primaryText)
                    } else {
                        Text("EARLY UNLOCK READY")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(sacredGold)

                        Text("Tap to unlock apps now")
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                }

                Spacer(minLength: 0)

                // Action indicator
                if remaining <= 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(sacredGold)
                } else {
                    // Countdown badge
                    Text(remaining.formattedForCountdown)
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(sacredGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(sacredGold.opacity(0.15))
                        )
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
                if remaining <= 0 {
                    blocking.earlyUnlockCurrentInterval()
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    EarlyUnlockBanner()
}
