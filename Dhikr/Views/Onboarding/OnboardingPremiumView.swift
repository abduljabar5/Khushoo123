//
//  OnboardingPremiumView.swift
//  Dhikr
//
//  Premium upsell screen (Screen 4)
//

import SwiftUI
import StoreKit

struct OnboardingPremiumView: View {
    let onStartTrial: () -> Void
    let onContinueWithoutPremium: () -> Void

    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedPlanIndex = 0 // 0 = monthly (default)
    @State private var isPurchasing = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.accentGold, Color(hex: "FFA500")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)

                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)

                    Text("Unlock Premium")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Text("Get the full spiritual experience")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                // Benefits
                VStack(spacing: 16) {
                    PremiumBenefitRow(
                        icon: "person.3.fill",
                        iconColor: theme.primaryAccent,
                        title: "300+ Reciters",
                        description: "Access the world's best Quran reciters",
                        theme: theme
                    )

                    PremiumBenefitRow(
                        icon: "sparkles",
                        iconColor: theme.accentGold,
                        title: "Advanced Blocking",
                        description: "Enhanced prayer-time focus features",
                        theme: theme
                    )

                    PremiumBenefitRow(
                        icon: "photo.fill",
                        iconColor: Color(hex: "5E35B1"),
                        title: "Premium Cover Art",
                        description: "Beautiful nature wallpapers",
                        theme: theme
                    )

                    PremiumBenefitRow(
                        icon: "icloud.fill",
                        iconColor: theme.accentTeal,
                        title: "Cloud Sync",
                        description: "Access your data across devices",
                        theme: theme
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // Plan Selector
                VStack(spacing: 12) {
                    if !subscriptionService.availableProducts.isEmpty {
                        ForEach(Array(subscriptionService.availableProducts.enumerated()), id: \.element.id) { index, product in
                            PlanCard(
                                product: product,
                                isSelected: selectedPlanIndex == index,
                                isBestValue: product.subscription?.subscriptionPeriod.unit == .year,
                                theme: theme
                            ) {
                                selectedPlanIndex = index
                            }
                        }
                    } else {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading subscription options...")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(theme.secondaryText)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Trial Terms
                Text("Start with a 7-day free trial. No charge before trial ends. Cancel anytime.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)

                // Actions
                VStack(spacing: 16) {
                    // Primary: Start Trial
                    Button(action: {
                        Task {
                            await purchaseSelectedProduct()
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(theme.primaryAccent)
                                )
                        } else {
                            Text("Start 7-Day Free Trial")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [theme.accentGold, Color(hex: "FFA500")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    .disabled(isPurchasing || subscriptionService.availableProducts.isEmpty)

                    // Secondary: Continue without Premium
                    Button(action: {
                        onContinueWithoutPremium()
                    }) {
                        Text("Continue without Premium")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                    .disabled(isPurchasing)

                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.primaryAccent)
                    }
                    .disabled(isPurchasing)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                // Legal Links
                HStack(spacing: 16) {
                    Button("Terms") {
                        if let url = URL(string: "https://abduljabar5.github.io/Khushoo_site/#/terms") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(theme.tertiaryText)

                    Text("•")
                        .foregroundColor(theme.tertiaryText)

                    Button("Privacy") {
                        if let url = URL(string: "https://abduljabar5.github.io/Khushoo_site/#/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(theme.tertiaryText)
                }
                .padding(.bottom, 48)
            }
        }
        .background(theme.primaryBackground)
        .onAppear {

            // Only load if products aren't already loaded
            if subscriptionService.availableProducts.isEmpty {
                Task {
                    await subscriptionService.loadProducts()

                    // Check result after loading
                    if subscriptionService.availableProducts.isEmpty {
                    } else {
                    }
                }
            } else {
            }
        }
    }

    private func purchaseSelectedProduct() async {
        guard selectedPlanIndex < subscriptionService.availableProducts.count else {
            return
        }

        isPurchasing = true
        let product = subscriptionService.availableProducts[selectedPlanIndex]

        await subscriptionService.purchase(product)

        isPurchasing = false

        // Check if purchase succeeded - complete onboarding immediately
        if subscriptionService.isPremium {
            onStartTrial()
        }
    }
}

// MARK: - Supporting Views

struct PremiumBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(iconColor)
            }

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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
    }
}

struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let theme: AppTheme
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text(product.description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(theme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isBestValue {
                        Text("Best Value")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.accentGreen)
                            )
                    }
                }

                HStack {
                    Text(product.displayPrice)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryAccent)

                    Text("/ \(periodText)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(theme.secondaryText)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? theme.primaryAccent : theme.tertiaryText)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? theme.primaryAccent : theme.tertiaryBackground, lineWidth: 2)
                    )
            )
        }
    }

    private var periodText: String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return "month"
        }

        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "year" : "\(period.value) years"
        @unknown default:
            return "period"
        }
    }
}

#Preview {
    OnboardingPremiumView(onStartTrial: {}, onContinueWithoutPremium: {})
}
