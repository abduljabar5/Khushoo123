//
//  OnboardingPremiumView.swift
//  Dhikr
//
//  Premium upsell screen (Screen 4) - Sacred Minimalism redesign
//

import SwiftUI
import StoreKit

struct OnboardingPremiumView: View {
    let onStartTrial: () -> Void
    let onContinueWithoutPremium: () -> Void

    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var referralService = ReferralCodeService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedPlanIndex = 0
    @State private var isPurchasing = false
    @State private var showReferralInput = false
    @State private var referralCodeText = ""
    @FocusState private var isReferralFieldFocused: Bool

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

    private var mutedPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    /// Products to display based on referral code status
    private var displayProducts: [Product] {
        if referralService.hasValidReferralCode {
            return subscriptionService.referralProducts
        } else {
            return subscriptionService.standardProducts
        }
    }

    /// Trial duration text based on referral code status
    private var trialDurationText: String {
        referralService.hasValidReferralCode ? "7-day" : "3-day"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header - Sacred style
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(sacredGold.opacity(0.15))
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: "crown")
                            .font(.system(size: 44, weight: .ultraLight))
                            .foregroundColor(sacredGold)
                    }
                    .padding(.top, 32)

                    Text("Unlock Premium")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Get the full spiritual experience")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(warmGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                // Benefits - Sacred style
                VStack(spacing: 12) {
                    SacredPremiumBenefitRow(
                        icon: "person.3",
                        title: "300+ Reciters",
                        description: "Access the world's best Quran reciters",
                        color: sacredGold
                    )

                    SacredPremiumBenefitRow(
                        icon: "sparkles",
                        title: "Advanced Blocking",
                        description: "Enhanced prayer-time focus features",
                        color: softGreen
                    )

                    SacredPremiumBenefitRow(
                        icon: "photo",
                        title: "Premium Cover Art",
                        description: "Beautiful nature wallpapers",
                        color: mutedPurple
                    )

                    SacredPremiumBenefitRow(
                        icon: "icloud",
                        title: "Cloud Sync",
                        description: "Access your data across devices",
                        color: warmGray
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Plan Selector - Sacred style
                VStack(spacing: 12) {
                    if !displayProducts.isEmpty {
                        ForEach(Array(displayProducts.enumerated()), id: \.element.id) { index, product in
                            SacredPlanCard(
                                product: product,
                                isSelected: selectedPlanIndex == index,
                                isBestValue: product.subscription?.subscriptionPeriod.unit == .year
                            ) {
                                selectedPlanIndex = index
                            }
                        }
                    } else {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(sacredGold)
                            Text("Loading subscription options...")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(warmGray)
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Referral Code Section - Sacred style
                VStack(spacing: 12) {
                    if showReferralInput {
                        HStack(spacing: 12) {
                            TextField("Enter code", text: $referralCodeText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .font(.system(size: 15, weight: .light))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .focused($isReferralFieldFocused)

                            Button(action: {
                                Task {
                                    let isValid = await referralService.validateCode(referralCodeText)
                                    if isValid {
                                        selectedPlanIndex = 0
                                        isReferralFieldFocused = false
                                    }
                                }
                            }) {
                                if referralService.isValidating {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(width: 70, height: 44)
                                } else {
                                    Text("Apply")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                                        .frame(width: 70, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(sacredGold)
                                        )
                                }
                            }
                            .disabled(referralCodeText.isEmpty || referralService.isValidating)
                        }

                        if let error = referralService.validationError {
                            Text(error)
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(Color(red: 0.85, green: 0.4, blue: 0.4))
                        }

                        if referralService.hasValidReferralCode {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(softGreen)
                                Text("Code applied! You get a 7-day free trial.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(softGreen)
                            }
                        }
                    } else {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReferralInput = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isReferralFieldFocused = true
                            }
                        }) {
                            Text("Have a referral code?")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(sacredGold)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Trial Terms
                Text("Start with a \(trialDurationText) free trial. No charge before trial ends. Cancel anytime.")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)

                // Actions - Sacred style
                VStack(spacing: 16) {
                    // Primary: Start Trial
                    Button(action: {
                        Task {
                            await purchaseSelectedProduct()
                        }
                    }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.effectiveTheme == .dark ? .black : .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(sacredGold)
                                )
                        } else {
                            Text("Start \(trialDurationText.capitalized) Free Trial")
                                .font(.system(size: 16, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(sacredGold)
                                )
                        }
                    }
                    .disabled(isPurchasing || displayProducts.isEmpty)

                    // Secondary: Continue without Premium
                    Button(action: {
                        onContinueWithoutPremium()
                    }) {
                        Text("Continue without Premium")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(warmGray)
                    }
                    .disabled(isPurchasing)

                    // Restore Purchases
                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(sacredGold)
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
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray.opacity(0.7))

                    Text("·")
                        .foregroundColor(warmGray.opacity(0.5))

                    Button("Privacy") {
                        if let url = URL(string: "https://abduljabar5.github.io/Khushoo_site/#/privacy") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(warmGray.opacity(0.7))
                }
                .padding(.bottom, 48)
            }
        }
        .background(pageBackground)
        .onAppear {
            if subscriptionService.availableProducts.isEmpty {
                Task {
                    await subscriptionService.loadProducts()
                }
            }
        }
    }

    private func purchaseSelectedProduct() async {
        guard selectedPlanIndex < displayProducts.count else {
            return
        }

        isPurchasing = true
        let product = displayProducts[selectedPlanIndex]

        await subscriptionService.purchase(product)

        isPurchasing = false

        if subscriptionService.hasPremiumAccess {
            referralService.clearCode()
            onStartTrial()
        }
    }
}

// MARK: - Sacred Premium Benefit Row

private struct SacredPremiumBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    @StateObject private var themeManager = ThemeManager.shared

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

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(description)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(warmGray)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(sacredGold.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred Plan Card

private struct SacredPlanCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

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

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text(product.description)
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(warmGray)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isBestValue {
                        Text("Best Value")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(softGreen)
                            )
                    }
                }

                HStack {
                    Text(product.displayPrice)
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(sacredGold)

                    Text("/ \(periodText)")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(warmGray)

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(isSelected ? sacredGold : warmGray.opacity(0.5))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? sacredGold.opacity(0.5) : sacredGold.opacity(0.1), lineWidth: isSelected ? 2 : 1)
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
