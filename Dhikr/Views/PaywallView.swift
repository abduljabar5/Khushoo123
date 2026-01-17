//
//  PaywallView.swift
//  Dhikr
//
//  Premium subscription paywall
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showingRestoreAlert = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            // Background
            theme.primaryBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Unlock Premium")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primaryText)

                        Text("Get full access to all features")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.top, 40)

                    // Features List
                    VStack(spacing: 16) {
                        ForEach(PremiumFeature.allCases, id: \.self) { feature in
                            FeatureRow(feature: feature, theme: theme)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Subscription Options
                    VStack(spacing: 12) {
                        if subscriptionService.availableProducts.isEmpty {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .tint(theme.primaryAccent)
                                Text("Loading subscription options...")
                                    .font(.caption)
                                    .foregroundColor(theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            if let yearly = subscriptionService.yearlyProduct {
                                SubscriptionCard(
                                    product: yearly,
                                    isSelected: selectedProduct?.id == yearly.id,
                                    badge: "BEST VALUE",
                                    savings: "Save 33%",
                                    theme: theme
                                ) {
                                    selectedProduct = yearly
                                }
                            }

                            if let monthly = subscriptionService.monthlyProduct {
                                SubscriptionCard(
                                    product: monthly,
                                    isSelected: selectedProduct?.id == monthly.id,
                                    badge: nil,
                                    savings: nil,
                                    theme: theme
                                ) {
                                    selectedProduct = monthly
                                }
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
                                    dismiss()
                                }
                            }
                        }) {
                            HStack {
                                if case .purchasing = subscriptionService.purchaseState {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Start Free Trial")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [theme.primaryAccent, theme.primaryAccent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                        }
                        .disabled(subscriptionService.purchaseState == .purchasing)
                        .padding(.horizontal, 20)
                    }

                    // Footer
                    VStack(spacing: 12) {
                        Button("Restore Purchases") {
                            Task {
                                await subscriptionService.restorePurchases()
                                // FIX: Auto-dismiss if premium was restored successfully
                                if subscriptionService.hasPremiumAccess {
                                    dismiss()
                                } else {
                                    showingRestoreAlert = true
                                }
                            }
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)

                        Text("Auto-renews. Cancel anytime.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(theme.tertiaryText)

                        // Legal Links (Required by App Store)
                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: URL(string: "https://abduljabar5.github.io/Khushoo_site/#/privacy")!)

                            Text("•")
                                .foregroundColor(theme.tertiaryText)

                            Link("Terms of Use", destination: URL(string: "https://abduljabar5.github.io/Khushoo_site/#/terms")!)
                        }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
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
                            .foregroundColor(theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(theme.cardBackground)
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
            // Load products if not already loaded
            Task {
                if subscriptionService.availableProducts.isEmpty {
                    await subscriptionService.loadProducts()
                }
                // Pre-select yearly plan after products load
                selectedProduct = subscriptionService.yearlyProduct ?? subscriptionService.monthlyProduct
            }
        }
        .onChange(of: subscriptionService.availableProducts) { products in
            // Auto-select yearly product when products load
            if selectedProduct == nil && !products.isEmpty {
                selectedProduct = subscriptionService.yearlyProduct ?? subscriptionService.monthlyProduct
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let feature: PremiumFeature
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(theme.primaryAccent)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(theme.primaryAccent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Text(feature.description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(theme.accentGreen)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
                .shadow(color: theme.shadowColor.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Subscription Card
struct SubscriptionCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let savings: String?
    let theme: AppTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Badge
                if let badge = badge {
                    HStack {
                        Spacer()
                        Text(badge)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        Spacer()
                    }
                    .offset(y: -8)
                }

                // Card Content
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primaryText)

                        if let savings = savings {
                            Text(savings)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.accentGreen)
                        }

                        if let period = product.subscription?.subscriptionPeriod {
                            Text(formatPeriod(period))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primaryText)

                        if let period = product.subscription?.subscriptionPeriod {
                            Text("per \(periodUnit(period))")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                        }
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? theme.primaryAccent : theme.tertiaryText)
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? theme.primaryAccent : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(color: isSelected ? theme.primaryAccent.opacity(0.3) : theme.shadowColor.opacity(0.1), radius: 8)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatPeriod(_ period: Product.SubscriptionPeriod) -> String {
        let unit = period.unit
        let value = period.value

        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) years"
        @unknown default:
            return "Subscription"
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
