//
//  PremiumLockedView.swift
//  Dhikr
//
//  Sacred Minimalism premium lock overlay component
//

import SwiftUI

// Sacred colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

struct PremiumLockedView: View {
    let feature: PremiumFeature
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingPaywall = false

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    var body: some View {
        ZStack {
            // Blur effect background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Lock message
            VStack(spacing: 28) {
                // Sacred lock icon in circle
                ZStack {
                    Circle()
                        .fill(cardBackground)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(sacredGold)
                }

                VStack(spacing: 12) {
                    Text("PREMIUM")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundColor(subtleText)

                    Text("\(feature.rawValue)")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text(feature.description)
                        .font(.system(size: 14))
                        .foregroundColor(subtleText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button(action: {
                    showingPaywall = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "crown")
                            .font(.system(size: 16, weight: .light))
                        Text("Unlock Premium")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(sacredGold)
                    .cornerRadius(12)
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}
