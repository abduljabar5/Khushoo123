//
//  SplashView.swift
//  Dhikr
//
//  Animated splash screen - Sacred Minimalism design
//

import SwiftUI

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    // Animation states
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var isPulsing: Bool = false

    // Sacred Minimalism colors - adapts to light/dark mode
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)

    private var subtleText: Color {
        colorScheme == .dark ? Color(white: 0.5) : Color(white: 0.4)
    }

    private var titleColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.15, green: 0.15, blue: 0.15)
    }

    var body: some View {
        ZStack {
            // Background
            pageBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo with animated ring
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                        .frame(width: 140, height: 140)
                        .scaleEffect(isPulsing ? 1.15 : 1.0)
                        .opacity(ringOpacity * (isPulsing ? 0.3 : 0.6))

                    // Inner ring
                    Circle()
                        .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        .frame(width: 110, height: 110)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Icon container
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        sacredGold.opacity(0.15),
                                        sacredGold.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)

                        // Crescent moon - Islamic symbol
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [sacredGold, sacredGold.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                }

                // App name
                VStack(spacing: 8) {
                    Text("KHUSHOO")
                        .font(.system(size: 28, weight: .light))
                        .tracking(8)
                        .foregroundColor(titleColor)

                    Text("Mindful Prayer")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(2)
                        .foregroundColor(subtleText)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                Spacer()

                // Loading indicator
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(sacredGold.opacity(isPulsing ? 0.8 : 0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(isPulsing ? 1.0 : 0.6)
                            .animation(
                                Animation
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: isPulsing
                            )
                    }
                }
                .padding(.bottom, 60)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo fade in and scale
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1
            logoScale = 1
        }

        // Ring animation
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            ringScale = 1
            ringOpacity = 1
        }

        // Text fade in and slide up
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            textOpacity = 1
            textOffset = 0
        }

        // Start pulsing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    SplashView()
}
