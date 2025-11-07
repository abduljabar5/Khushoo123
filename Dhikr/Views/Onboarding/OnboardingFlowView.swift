//
//  OnboardingFlowView.swift
//  Dhikr
//
//  4-screen onboarding flow container
//

import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var subscriptionService = SubscriptionService.shared

    @State private var currentPage = 0
    @State private var isCompact: Bool = false // For Settings re-entry

    init(compact: Bool = false) {
        _isCompact = State(initialValue: compact)
    }

    var body: some View {
        ZStack {
            Color(hex: "F8F9FA")
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Screen 1: Welcome
                OnboardingWelcomeView(onContinue: { currentPage = 1 }, onSkip: completeOnboarding)
                    .tag(0)

                // Screen 2: Focus Setup
                OnboardingFocusSetupView(onContinue: { currentPage = 2 }, onSkip: { currentPage = 2 })
                    .tag(1)

                // Screen 3: Permissions
                OnboardingPermissionsView(onContinue: {
                    if subscriptionService.isPremium {
                        // Skip premium screen if already subscribed
                        completeOnboarding()
                    } else {
                        currentPage = 3
                    }
                })
                .tag(2)

                // Screen 4: Premium (skip if already premium)
                if !subscriptionService.isPremium {
                    OnboardingPremiumView(
                        onStartTrial: completeOnboarding,
                        onContinueWithoutPremium: completeOnboarding
                    )
                    .tag(3)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .onAppear {
            print("[Onboarding] Flow started - compact=\(isCompact)")
        }
    }

    private func completeOnboarding() {
        print("[Onboarding] Completing onboarding")
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingFlowView()
}
