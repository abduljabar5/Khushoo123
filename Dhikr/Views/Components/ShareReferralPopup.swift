//
//  ShareReferralPopup.swift
//  Dhikr
//
//  Popup shown on app launch for trial users who haven't shared yet
//

import SwiftUI
import UIKit

struct ShareReferralPopup: View {
    @Binding var isPresented: Bool
    var onUpgrade: () -> Void = {}
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingShareSheet = false
    @State private var showSuccess = false

    // Animation states
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var sparkleOpacity: Double = 0
    @State private var sparkleRotation: Double = 0

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

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        VStack {
            if showSuccess {
                // Success celebration view
                successView
            } else {
                // Popup card
                sharePromptView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheetView(
                activityItems: [shareMessage, shareURL].compactMap { $0 },
                onComplete: { _, isValidShare in
                    if isValidShare {
                        subscriptionService.claimReferralAccess()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showSuccess = true
                        }
                        startSuccessAnimation()
                    }
                }
            )
        }
    }

    // MARK: - Share Prompt View
    private var sharePromptView: some View {
        VStack(spacing: 24) {
            // Gift icon
            ZStack {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "gift.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(sacredGold)
            }

            // Text
            VStack(spacing: 8) {
                Text("Unlock 7-Day Free Trial")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Share Khushoo with a friend and get access to our extended 7-day free trial")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(warmGray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Share button
            Button(action: {
                showingShareSheet = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))

                    Text("Share Khushoo")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(sacredGold)
                )
            }

            // Maybe later
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPresented = false
                }
            }) {
                Text("Maybe Later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(warmGray)
            }
        }
        .padding(24)
        .padding(.top, 20)
    }

    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: 24) {
            // Animated checkmark with sparkles
            ZStack {
                // Outer sparkle ring
                ForEach(0..<8) { i in
                    Circle()
                        .fill(sacredGold)
                        .frame(width: 6, height: 6)
                        .offset(y: -60)
                        .rotationEffect(.degrees(Double(i) * 45 + sparkleRotation))
                        .opacity(sparkleOpacity)
                }

                // Expanding ring
                Circle()
                    .stroke(softGreen.opacity(0.3), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                // Success circle background
                Circle()
                    .fill(softGreen.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(softGreen.opacity(0.4), lineWidth: 2)
                    )

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(softGreen)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }

            // Success text
            VStack(spacing: 8) {
                Text("You're All Set!")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("7-day free trial unlocked")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(softGreen)
            }
            .opacity(textOpacity)

            // View Offer button
            Button(action: {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onUpgrade()
                }
            }) {
                Text("View Offer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(sacredGold)
                    )
            }
            .opacity(textOpacity)

            // Dismiss button
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    isPresented = false
                }
            }) {
                Text("Maybe Later")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(warmGray)
            }
            .opacity(textOpacity)
        }
        .padding(24)
        .padding(.top, 20)
    }

    // MARK: - Animation
    private func startSuccessAnimation() {
        // Ring expansion
        withAnimation(.easeOut(duration: 0.6)) {
            ringScale = 1.3
            ringOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            ringOpacity = 0
        }

        // Checkmark bounce in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1
        }

        // Sparkles
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            sparkleOpacity = 1
        }
        withAnimation(.linear(duration: 2).delay(0.2)) {
            sparkleRotation = 45
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            sparkleOpacity = 0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1
        }
    }

    private var shareMessage: String {
        "I'm using Khushoo to stay focused during prayer times and strengthen my connection with Allah. Try it free!"
    }

    private var shareURL: URL? {
        URL(string: "https://apps.apple.com/us/app/khushoo/id6748625242")
    }
}

#Preview {
    ShareReferralPopup(isPresented: .constant(true), onUpgrade: {})
}
