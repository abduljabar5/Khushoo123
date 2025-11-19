//
//  PostPurchaseSignInPromptView.swift
//  Dhikr
//
//  Post-purchase prompt to encourage users to sign in
//

import SwiftUI

struct PostPurchaseSignInPromptView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var showingAuth = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Card
            VStack(spacing: 24) {
                // Success Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .green.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Title
                Text("Premium Unlocked!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                // Description
                VStack(spacing: 12) {
                    Text("Want to sync your premium access across all your devices?")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)

                    // Benefits
                    VStack(alignment: .leading, spacing: 10) {
                        BenefitRow(
                            icon: "icloud.fill",
                            text: "Sync across iPhone, iPad & Mac",
                            theme: theme
                        )
                        BenefitRow(
                            icon: "arrow.clockwise.circle.fill",
                            text: "Automatic backup & restore",
                            theme: theme
                        )
                        BenefitRow(
                            icon: "shield.fill",
                            text: "Secure account protection",
                            theme: theme
                        )
                    }
                    .padding(.top, 8)
                }

                // Buttons
                VStack(spacing: 12) {
                    // Sign In Button
                    Button(action: {
                        showingAuth = true
                    }) {
                        Text("Create Account")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [theme.primaryAccent, theme.primaryAccent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                    }

                    // Maybe Later Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.primaryBackground)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showingAuth) {
            NavigationStack {
                OnboardingFlowView()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let text: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryAccent)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(theme.primaryText)

            Spacer()
        }
    }
}

#Preview {
    PostPurchaseSignInPromptView()
        .environmentObject(AuthenticationService.shared)
}
