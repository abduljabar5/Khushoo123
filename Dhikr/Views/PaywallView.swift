//
//  PaywallView.swift
//  Dhikr
//
//  Premium subscription paywall - Sacred Minimalism redesign
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var referralService = ReferralCodeService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showingRestoreAlert = false
    @State private var showReferralInput = false
    @State private var referralCodeText = ""
    @FocusState private var isReferralFieldFocused: Bool

    // Sacred colors
    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var softGreen: Color { Color(red: 0.55, green: 0.68, blue: 0.55) }

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

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    /// Show referral products if user has valid code OR earned access by sharing
    private var shouldShowReferralProducts: Bool {
        referralService.hasValidReferralCode || subscriptionService.hasEarnedReferralAccess
    }

    private var displayMonthlyProduct: Product? {
        shouldShowReferralProducts
            ? subscriptionService.monthlyReferralProduct
            : subscriptionService.monthlyProduct
    }

    private var displayYearlyProduct: Product? {
        shouldShowReferralProducts
            ? subscriptionService.yearlyReferralProduct
            : subscriptionService.yearlyProduct
    }

    private var trialDurationText: String {
        shouldShowReferralProducts ? "7-Day" : "3-Day"
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 16) {
                        // Sacred crown icon
                        ZStack {
                            Circle()
                                .fill(cardBackground)
                                .frame(width: 90, height: 90)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                                )

                            Image(systemName: "crown")
                                .font(.system(size: 36, weight: .ultraLight))
                                .foregroundColor(sacredGold)
                        }

                        VStack(spacing: 8) {
                            Text("PREMIUM")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(3)
                                .foregroundColor(subtleText)

                            Text("Unlock Full Access")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("Everything you need for your spiritual journey")
                                .font(.system(size: 14))
                                .foregroundColor(subtleText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 50)

                    // Features List
                    VStack(spacing: 12) {
                        ForEach(PremiumFeature.allCases, id: \.self) { feature in
                            SacredFeatureRow(feature: feature, sacredGold: sacredGold, softGreen: softGreen, cardBackground: cardBackground, subtleText: subtleText, primaryText: themeManager.theme.primaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Subscription Options
                    VStack(spacing: 12) {
                        if subscriptionService.availableProducts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(sacredGold)
                                Text("Loading options...")
                                    .font(.system(size: 13))
                                    .foregroundColor(subtleText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            if let yearly = displayYearlyProduct {
                                SacredSubscriptionCard(
                                    product: yearly,
                                    isSelected: selectedProduct?.id == yearly.id,
                                    badge: "BEST VALUE",
                                    savings: "Save 33%",
                                    sacredGold: sacredGold,
                                    softGreen: softGreen,
                                    cardBackground: cardBackground,
                                    subtleText: subtleText,
                                    primaryText: themeManager.theme.primaryText
                                ) {
                                    selectedProduct = yearly
                                }
                            }

                            if let monthly = displayMonthlyProduct {
                                SacredSubscriptionCard(
                                    product: monthly,
                                    isSelected: selectedProduct?.id == monthly.id,
                                    badge: nil,
                                    savings: nil,
                                    sacredGold: sacredGold,
                                    softGreen: softGreen,
                                    cardBackground: cardBackground,
                                    subtleText: subtleText,
                                    primaryText: themeManager.theme.primaryText
                                ) {
                                    selectedProduct = monthly
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Referral Code Section
                    VStack(spacing: 12) {
                        if showReferralInput {
                            HStack(spacing: 12) {
                                TextField("Enter code", text: $referralCodeText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.allCharacters)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 15))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(cardBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            )
                                    )
                                    .focused($isReferralFieldFocused)

                                Button(action: {
                                    Task {
                                        let isValid = await referralService.validateCode(referralCodeText)
                                        if isValid {
                                            selectedProduct = displayYearlyProduct ?? displayMonthlyProduct
                                            isReferralFieldFocused = false
                                        }
                                    }
                                }) {
                                    if referralService.isValidating {
                                        ProgressView()
                                            .frame(width: 70, height: 44)
                                    } else {
                                        Text("Apply")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
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
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
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
                    .padding(.horizontal, 20)

                    // Purchase Button
                    if let product = selectedProduct {
                        Button(action: {
                            Task {
                                await subscriptionService.purchase(product)
                                if case .success = subscriptionService.purchaseState {
                                    referralService.clearCode()
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if case .purchasing = subscriptionService.purchaseState {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Start \(trialDurationText) Free Trial")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(sacredGold)
                            .cornerRadius(12)
                        }
                        .disabled(subscriptionService.purchaseState == .purchasing)
                        .padding(.horizontal, 20)
                    }

                    // Footer
                    VStack(spacing: 12) {
                        Button("Restore Purchases") {
                            Task {
                                await subscriptionService.restorePurchases()
                                if subscriptionService.hasPremiumAccess {
                                    dismiss()
                                } else {
                                    showingRestoreAlert = true
                                }
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(subtleText)

                        Text("Auto-renews. Cancel anytime.")
                            .font(.system(size: 12))
                            .foregroundColor(subtleText.opacity(0.7))

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: URL(string: "https://abduljabar5.github.io/Khushoo_site/#/privacy")!)
                            Text("•").foregroundColor(subtleText.opacity(0.5))
                            Link("Terms of Use", destination: URL(string: "https://abduljabar5.github.io/Khushoo_site/#/terms")!)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(subtleText)
                    }
                    .padding(.bottom, 40)
                }
            }

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtleText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(cardBackground)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                Spacer()
            }
        }
        .alert("Restore Complete", isPresented: $showingRestoreAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if subscriptionService.hasPremiumAccess {
                Text("Your premium subscription has been restored!")
            } else {
                Text("No active subscriptions found.")
            }
        }
        .onAppear {
            // Track paywall viewed
            AnalyticsService.shared.trackPaywallViewed()

            Task {
                if subscriptionService.availableProducts.isEmpty {
                    await subscriptionService.loadProducts()
                }
                selectedProduct = displayYearlyProduct ?? displayMonthlyProduct
            }
        }
        .onChange(of: subscriptionService.availableProducts) { products in
            if selectedProduct == nil && !products.isEmpty {
                selectedProduct = displayYearlyProduct ?? displayMonthlyProduct
            }
        }
        .onChange(of: referralService.hasValidReferralCode) { hasCode in
            if hasCode {
                selectedProduct = displayYearlyProduct ?? displayMonthlyProduct
            }
        }
    }
}

// MARK: - Sacred Feature Row
struct SacredFeatureRow: View {
    let feature: PremiumFeature
    let sacredGold: Color
    let softGreen: Color
    let cardBackground: Color
    let subtleText: Color
    let primaryText: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(sacredGold.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: feature.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(sacredGold)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(primaryText)

                Text(feature.description)
                    .font(.system(size: 13))
                    .foregroundColor(subtleText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(softGreen)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred Subscription Card
struct SacredSubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let savings: String?
    let sacredGold: Color
    let softGreen: Color
    let cardBackground: Color
    let subtleText: Color
    let primaryText: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                if let badge = badge {
                    HStack {
                        Spacer()
                        Text(badge)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(sacredGold)
                            )
                        Spacer()
                    }
                    .offset(y: -6)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(primaryText)

                        if let savings = savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(softGreen)
                        }

                        if let period = product.subscription?.subscriptionPeriod {
                            Text(formatPeriod(period))
                                .font(.system(size: 13))
                                .foregroundColor(subtleText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(product.displayPrice)
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(primaryText)

                        if let period = product.subscription?.subscriptionPeriod {
                            Text("per \(periodUnit(period))")
                                .font(.system(size: 11))
                                .foregroundColor(subtleText)
                        }
                    }

                    Circle()
                        .stroke(isSelected ? sacredGold : subtleText.opacity(0.3), lineWidth: isSelected ? 6 : 1.5)
                        .frame(width: 22, height: 22)
                        .padding(.leading, 12)
                }
                .padding(18)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? sacredGold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 1 ? "Daily" : "\(period.value) days"
        case .week: return period.value == 1 ? "Weekly" : "\(period.value) weeks"
        case .month: return period.value == 1 ? "Monthly" : "\(period.value) months"
        case .year: return period.value == 1 ? "Yearly" : "\(period.value) years"
        @unknown default: return "Subscription"
        }
    }

    private func periodUnit(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}

// MARK: - Preview
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}
