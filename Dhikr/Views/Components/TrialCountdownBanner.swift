//
//  TrialCountdownBanner.swift
//  Dhikr
//
//  Shows countdown when free trial is about to expire - Sacred Minimalism
//

import SwiftUI
import UIKit

struct TrialCountdownBanner: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingShareSheet = false
    @State private var showingShareSuccess = false
    @State private var canDismiss = false
    @State private var isDismissed = false
    @State private var showSuccessState = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var successTextOpacity: Double = 0
    @State private var dragOffset: CGFloat = 0

    var onUpgrade: () -> Void

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

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var urgentColor: Color {
        Color(red: 0.85, green: 0.5, blue: 0.4)
    }

    var body: some View {
        if subscriptionService.shouldShowTrialBanner && !isDismissed {
            VStack(spacing: 12) {
                if showSuccessState {
                    // Success state
                    HStack(spacing: 14) {
                        // Animated checkmark
                        ZStack {
                            Circle()
                                .fill(softGreen.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(softGreen)
                                .scaleEffect(checkmarkScale)
                        }

                        // Success text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SUCCESS!")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(softGreen)

                            Text("7-day trial unlocked")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)
                        }
                        .opacity(successTextOpacity)

                        Spacer(minLength: 0)

                        // View Offer button
                        Button(action: onUpgrade) {
                            Text("View Offer")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(sacredGold)
                                )
                        }
                        .opacity(successTextOpacity)
                    }
                } else {
                    // Main banner
                    HStack(spacing: 14) {
                        // Icon with sacred styling
                        ZStack {
                            Circle()
                                .fill(urgentColor.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(urgentColor)
                        }

                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TRIAL ENDING")
                                .font(.system(size: 10, weight: .medium))
                                .tracking(1.5)
                                .foregroundColor(urgentColor)

                            Text(formattedTimeRemaining)
                                .font(.system(size: 15, weight: .light))
                                .monospacedDigit()
                                .foregroundColor(themeManager.theme.primaryText)
                        }

                        Spacer(minLength: 0)

                        // Upgrade button
                        Button(action: onUpgrade) {
                            Text("Upgrade")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(sacredGold)
                                )
                        }
                    }

                    // Share for 7-day trial option
                    if subscriptionService.canEarnReferralAccess {
                        Button(action: { showingShareSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(softGreen)

                                Text("Share to unlock 7-day trial")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(softGreen)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(softGreen.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(softGreen.opacity(0.12))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
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
                    .stroke(showSuccessState ? softGreen.opacity(0.3) : urgentColor.opacity(0.3), lineWidth: 1)
            )
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow upward drag
                        if value.translation.height < 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        // Dismiss if dragged up more than 50 points
                        if value.translation.height < -50 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = -200
                                isDismissed = true
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(
                    activityItems: [shareMessage, shareURL].compactMap { $0 },
                    onComplete: { _, isValidShare in
                        if isValidShare {
                            subscriptionService.claimReferralAccess()
                            // Show success animation
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showSuccessState = true
                            }
                            // Animate checkmark
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
                                checkmarkScale = 1.0
                            }
                            // Fade in text
                            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                                successTextOpacity = 1.0
                            }
                        }
                    }
                )
            }
        }
    }

    private var shareMessage: String {
        "I'm using Khushoo to stay focused during prayer times and strengthen my connection with Allah. Try it free!"
    }

    private var shareURL: URL? {
        URL(string: "https://apps.apple.com/us/app/khushoo/id6748625242")
    }

    private var formattedTimeRemaining: String {
        // Use timeRemaining state to ensure live updates
        let remaining = timeRemaining > 0 ? timeRemaining : subscriptionService.trialTimeRemaining

        if remaining <= 0 {
            return "Trial expired"
        }

        let days = Int(remaining) / 86400
        let hours = Int(remaining) / 3600 % 24
        let minutes = Int(remaining) / 60 % 60
        let seconds = Int(remaining) % 60

        if days > 0 {
            return "\(days)d \(hours)h remaining"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        } else {
            return "\(seconds)s remaining"
        }
    }

    private func startTimer() {
        // Initialize with current value
        timeRemaining = subscriptionService.trialTimeRemaining

        // Update every second on main thread
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.timeRemaining = subscriptionService.trialTimeRemaining
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    TrialCountdownBanner(onUpgrade: {})
        .padding()
}
