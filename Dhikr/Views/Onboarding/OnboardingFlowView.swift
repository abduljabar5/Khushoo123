//
//  OnboardingFlowView.swift
//  Dhikr
//
//  4-screen onboarding flow container - Sacred Minimalism redesign
//

import SwiftUI
import CoreLocation

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared
    @StateObject private var themeManager = ThemeManager.shared

    @State private var currentPage = 0
    @State private var isCompact: Bool = false // For Settings re-entry
    @State private var userName: String = ""

    // Sacred colors
    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    init(compact: Bool = false) {
        _isCompact = State(initialValue: compact)
    }

    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            // Use conditional views instead of TabView to prevent swipe navigation
            Group {
                switch currentPage {
                case 0:
                    // Screen 1: Welcome
                    OnboardingWelcomeView(onContinue: {
                        print("📱 [Onboarding] Page 0 → 1 (Welcome → Name)")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = 1
                        }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case 1:
                    // Screen 2: Name Input
                    OnboardingNameView(onContinue: { name in
                        userName = name
                        userDisplayName = name // Save to AppStorage

                        // If user is already authenticated with "Apple User", update their name now
                        if authService.isAuthenticated,
                           let currentUser = authService.currentUser,
                           (currentUser.displayName == "Apple User" || currentUser.displayName.isEmpty) {
                            Task {
                                await updateAuthenticatedUserName(name: name)
                            }
                        }

                        print("📱 [Onboarding] Page 1 → 2 (Name → Focus Setup)")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = 2
                        }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case 2:
                    // Screen 3: Focus Setup
                    OnboardingFocusSetupView(onContinue: {
                        print("📱 [Onboarding] Page 2 → 3 (Focus Setup → Permissions)")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = 3
                        }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case 3:
                    // Screen 4: Permissions
                    OnboardingPermissionsView(onContinue: {
                        if subscriptionService.hasPremiumAccess {
                            // Skip premium screen if already subscribed
                            print("📱 [Onboarding] Page 3 → Complete (Permissions → Skip Premium, already subscribed)")
                            completeOnboarding()
                        } else {
                            print("📱 [Onboarding] Page 3 → 4 (Permissions → Premium)")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage = 4
                            }
                        }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case 4:
                    // Screen 5: Premium (only shown if not already premium)
                    OnboardingPremiumView(
                        onStartTrial: completeOnboarding,
                        onContinueWithoutPremium: completeOnboarding
                    )
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                default:
                    OnboardingWelcomeView(onContinue: { currentPage = 1 })
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onAppear {
            print("📱 [Onboarding] OnboardingFlowView appeared - starting on page \(currentPage)")
        }
    }

    private func completeOnboarding() {
        print("🎉 [Onboarding] completeOnboarding() called")

        Task {
            // Check if scheduling will be needed (quick pre-check)
            let needsScheduling = await shouldScheduleBlocking()
            print("📋 [Onboarding] Should schedule blocking: \(needsScheduling)")

            // Set global scheduling state so UI can show progress indicator
            if needsScheduling {
                await MainActor.run {
                    BlockingStateService.shared.isSchedulingBlocking = true
                }
                print("🔄 [Onboarding] Set isSchedulingBlocking = true (will show progress in app)")
            }

            // Mark onboarding complete - triggers DhikrApp's prayer time fetch
            print("✅ [Onboarding] Marking onboarding as complete")
            hasCompletedOnboarding = true

            // Dismiss immediately - don't make user wait!
            // DhikrApp will handle scheduling in background and update BlockingStateService when done
            print("👋 [Onboarding] Dismissing immediately - scheduling continues in background")
            dismiss()
        }
    }

    /// Check if we should schedule blocking (quick pre-check)
    private func shouldScheduleBlocking() async -> Bool {
        print("🔍 [Onboarding] Checking if should schedule blocking...")

        // Quick check: premium + prayers selected + apps selected + screen time permission
        guard subscriptionService.hasPremiumAccess else {
            print("   ❌ Not premium")
            return false
        }
        print("   ✅ Is premium")

        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        let anyPrayerSelected = selectedFajr || selectedDhuhr || selectedAsr || selectedMaghrib || selectedIsha
        guard anyPrayerSelected else {
            print("   ❌ No prayers selected")
            return false
        }
        print("   ✅ Prayers selected - Fajr:\(selectedFajr) Dhuhr:\(selectedDhuhr) Asr:\(selectedAsr) Maghrib:\(selectedMaghrib) Isha:\(selectedIsha)")

        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty
        guard hasAppsSelected else {
            print("   ❌ No apps selected")
            return false
        }
        print("   ✅ Apps selected - apps:\(selection.applicationTokens.count) categories:\(selection.categoryTokens.count) domains:\(selection.webDomainTokens.count)")

        let isAuthorized = await screenTimeAuth.isAuthorized
        guard isAuthorized else {
            print("   ❌ Screen Time not authorized")
            return false
        }
        print("   ✅ Screen Time authorized")

        return true
    }

    private func updateAuthenticatedUserName(name: String) async {
        do {
            try await authService.updateDisplayName(newName: name)
        } catch {
        }
    }
}

#Preview {
    OnboardingFlowView()
}
