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
    @StateObject private var authService = AuthenticationService.shared
    @State private var selectedPlanIndex = 0 // 0 = monthly (default)
    @State private var isPurchasing = false
    @State private var showSignUpPrompt = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
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
                        .foregroundColor(Color(hex: "2C3E50"))

                    Text("Get the full spiritual experience")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "7F8C8D"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                // Benefits
                VStack(spacing: 16) {
                    PremiumBenefitRow(
                        icon: "person.3.fill",
                        iconColor: Color(hex: "1A9B8A"),
                        title: "300+ Reciters",
                        description: "Access the world's best Quran reciters"
                    )

                    PremiumBenefitRow(
                        icon: "sparkles",
                        iconColor: Color(hex: "F39C12"),
                        title: "Advanced Blocking",
                        description: "Enhanced prayer-time focus features"
                    )

                    PremiumBenefitRow(
                        icon: "photo.fill",
                        iconColor: Color(hex: "5E35B1"),
                        title: "Premium Cover Art",
                        description: "Beautiful nature wallpapers"
                    )

                    PremiumBenefitRow(
                        icon: "icloud.fill",
                        iconColor: Color(hex: "16A085"),
                        title: "Cloud Sync",
                        description: "Access your data across devices"
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
                                onSelect: {
                                    selectedPlanIndex = index
                                }
                            )
                        }
                    } else {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading subscription options...")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "7F8C8D"))
                        }
                        .padding()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Trial Terms
                Text("Start with a 7-day free trial. No charge before trial ends. Cancel anytime.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)

                // Actions
                VStack(spacing: 16) {
                    // Primary: Start Trial
                    Button(action: {
                        print("[Premium] Start trial tapped")
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
                                        .fill(Color(hex: "1A9B8A"))
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
                                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
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
                        print("[Premium] Continued without premium")
                        onContinueWithoutPremium()
                    }) {
                        Text("Continue without Premium")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "7F8C8D"))
                    }
                    .disabled(isPurchasing)

                    // Restore Purchases
                    Button(action: {
                        print("[Premium] Restore purchases tapped")
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "1A9B8A"))
                    }
                    .disabled(isPurchasing)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                // Legal Links
                HStack(spacing: 16) {
                    Button("Terms") {
                        print("[Premium] Terms tapped")
                        // TODO: Open terms URL
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "CECECE"))

                    Text("•")
                        .foregroundColor(Color(hex: "CECECE"))

                    Button("Privacy") {
                        print("[Premium] Privacy tapped")
                        // TODO: Open privacy URL
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "CECECE"))
                }
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showSignUpPrompt) {
            AccountCreationPromptView(
                onCreateAccount: {
                    showSignUpPrompt = false
                    // Complete onboarding first
                    onStartTrial()
                    // User will see auth in main app via profile or settings
                },
                onSkip: {
                    showSignUpPrompt = false
                    print("[Premium] User skipped account creation")
                    onStartTrial()
                }
            )
        }
        .fullScreenCover(isPresented: $subscriptionService.showPostPurchaseSignInPrompt) {
            PostPurchaseSignInPromptView()
                .environmentObject(authService)
        }
        .onAppear {
            print("[Onboarding] Premium screen shown")
            print("[Premium] Current products count: \(subscriptionService.availableProducts.count)")

            // Only load if products aren't already loaded
            if subscriptionService.availableProducts.isEmpty {
                Task {
                    print("[Premium] Loading products...")
                    await subscriptionService.loadProducts()

                    // Check result after loading
                    if subscriptionService.availableProducts.isEmpty {
                        print("❌ [Premium] Failed to load products - check StoreKit configuration")
                        print("❌ [Premium] Make sure Xcode scheme has StoreKit Configuration set to Khushoo.storekit")
                    } else {
                        print("✅ [Premium] Successfully loaded \(subscriptionService.availableProducts.count) products")
                    }
                }
            } else {
                print("[Premium] Products already loaded: \(subscriptionService.availableProducts.count)")
            }
        }
    }

    private func purchaseSelectedProduct() async {
        guard selectedPlanIndex < subscriptionService.availableProducts.count else {
            print("[Premium] Invalid plan selection")
            return
        }

        isPurchasing = true
        let product = subscriptionService.availableProducts[selectedPlanIndex]

        await subscriptionService.purchase(product)

        isPurchasing = false

        // Check if purchase succeeded
        if subscriptionService.isPremium {
            print("[Premium] Trial started successfully")

            // Prompt to create account if not already authenticated
            if !authService.isAuthenticated {
                print("[Premium] User not authenticated - prompting to create account")
                showSignUpPrompt = true
            } else {
                print("[Premium] User already authenticated")
                onStartTrial()
            }
        } else {
            print("[Premium] Purchase did not complete (user cancelled or error)")
        }
    }
}

// MARK: - Supporting Views

struct AccountCreationPromptView: View {
    let onCreateAccount: () -> Void
    let onSkip: () -> Void
    @StateObject private var authService = AuthenticationService.shared
    @State private var showAuth = false
    @State private var showSkipWarning = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)

                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 24)

                // Title
                Text("One More Step")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2C3E50"))
                    .padding(.bottom, 12)

                // Message
                Text("Create an account to unlock the full power of your premium subscription")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)

                // Benefits
                VStack(spacing: 16) {
                    BenefitRow(
                        icon: "icloud.fill",
                        text: "Sync across all devices",
                        color: Color(hex: "1A9B8A")
                    )
                    BenefitRow(
                        icon: "arrow.clockwise.circle.fill",
                        text: "Restore purchases anytime",
                        color: Color(hex: "F39C12")
                    )
                    BenefitRow(
                        icon: "checkmark.shield.fill",
                        text: "Secure your premium access",
                        color: Color(hex: "27AE60")
                    )
                }
                .padding(.horizontal, 40)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button(action: {
                        showAuth = true
                    }) {
                        Text("Create Account")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }

                    Button(action: {
                        showSkipWarning = true
                    }) {
                        Text("Maybe Later")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "7F8C8D"))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .background(Color(hex: "F8F9FA"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAuth) {
                ModernAuthView()
                    .environmentObject(authService)
                    .onDisappear {
                        // If user created account, complete onboarding
                        if authService.isAuthenticated {
                            onCreateAccount()
                        }
                    }
            }
            .alert("Limited Premium Features", isPresented: $showSkipWarning) {
                Button("Create Account") {
                    showAuth = true
                }
                Button("Continue Anyway", role: .destructive) {
                    onSkip()
                }
            } message: {
                Text("Without an account, you'll miss:\n\n• Premium player cover art\n• Silent prayer notifications\n• Cloud sync across devices\n\nAlso, you must open the app every 3 days to keep app blocking active.")
            }
        }
    }

    struct BenefitRow: View {
        let icon: String
        let text: String
        let color: Color

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 28)

                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "2C3E50"))

                Spacer()
            }
        }
    }
}

struct PremiumBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

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
                    .foregroundColor(Color(hex: "2C3E50"))

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }
}

struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "2C3E50"))

                        Text(product.description)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "7F8C8D"))
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
                                    .fill(Color(hex: "27AE60"))
                            )
                    }
                }

                HStack {
                    Text(product.displayPrice)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "1A9B8A"))

                    Text("/ \(periodText)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "7F8C8D"))

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? Color(hex: "1A9B8A") : Color(hex: "CECECE"))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color(hex: "1A9B8A") : Color(hex: "ECECEC"), lineWidth: 2)
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
