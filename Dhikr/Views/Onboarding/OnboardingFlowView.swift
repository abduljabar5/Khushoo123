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
    @AppStorage("userDisplayName") private var userDisplayName: String = ""
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared
    @StateObject private var themeManager = ThemeManager.shared

    @State private var currentPage = 0
    @State private var isCompact: Bool = false // For Settings re-entry
    @State private var userName: String = ""
    @State private var isSchedulingBlocking = false

    private var theme: AppTheme { themeManager.theme }

    init(compact: Bool = false) {
        _isCompact = State(initialValue: compact)
    }

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Screen 1: Welcome
                OnboardingWelcomeView(onContinue: { currentPage = 1 })
                    .tag(0)

                // Screen 2: Name Input (NEW)
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

                    currentPage = 2
                })
                .tag(1)

                // Screen 3: Focus Setup
                OnboardingFocusSetupView(onContinue: { currentPage = 3 })
                    .tag(2)

                // Screen 4: Permissions
                OnboardingPermissionsView(onContinue: {
                    if subscriptionService.isPremium {
                        // Skip premium screen if already subscribed
                        completeOnboarding()
                    } else {
                        currentPage = 4
                    }
                })
                .tag(3)

                // Screen 5: Premium (skip if already premium)
                if !subscriptionService.isPremium {
                    OnboardingPremiumView(
                        onStartTrial: completeOnboarding,
                        onContinueWithoutPremium: completeOnboarding
                    )
                    .tag(4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Loading overlay when scheduling blocking
            if isSchedulingBlocking {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)

                        Text("Setting up prayer blocking...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.cardBackground)
                    )
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onAppear {
        }
    }

    private func completeOnboarding() {

        // Schedule prayer blocking if user configured it during onboarding
        Task {
            // Check if scheduling is needed before showing loading
            if await shouldScheduleBlocking() {
                isSchedulingBlocking = true
            }

            await scheduleBlockingFromOnboardingSettings()

            // Complete onboarding
            hasCompletedOnboarding = true
            isSchedulingBlocking = false
            dismiss()
        }
    }

    /// Check if we should schedule blocking (quick pre-check)
    private func shouldScheduleBlocking() async -> Bool {
        // Quick check: premium + prayers selected + apps selected + screen time permission
        guard subscriptionService.isPremium else { return false }

        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        let anyPrayerSelected = selectedFajr || selectedDhuhr || selectedAsr || selectedMaghrib || selectedIsha
        guard anyPrayerSelected else { return false }

        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty
        guard hasAppsSelected else { return false }

        guard await screenTimeAuth.isAuthorized else { return false }

        return true
    }

    /// Schedule prayer blocking based on settings saved in onboarding
    private func scheduleBlockingFromOnboardingSettings() async {

        // 1. Check if user is premium (required for focus blocking)
        guard subscriptionService.isPremium else {
            return
        }

        // 2. Get settings from UserDefaults (saved in OnboardingFocusSetupView)
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

        // Check if any prayers are selected
        let selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? false
        let selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? false
        let selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? false
        let selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? false
        let selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? false

        let anyPrayerSelected = selectedFajr || selectedDhuhr || selectedAsr || selectedMaghrib || selectedIsha

        guard anyPrayerSelected else {
            return
        }

        // 3. Check if apps are selected
        let selection = AppSelectionModel.getCurrentSelection()
        let hasAppsSelected = !selection.applicationTokens.isEmpty ||
                             !selection.categoryTokens.isEmpty ||
                             !selection.webDomainTokens.isEmpty

        guard hasAppsSelected else {
            return
        }

        // 4. Check if Screen Time permission is granted
        guard await screenTimeAuth.isAuthorized else {
            return
        }

        // 5. Get duration and buffer
        let duration = groupDefaults?.double(forKey: "focusBlockingDuration") ?? 15.0
        let prePrayerBuffer = groupDefaults?.double(forKey: "focusPrePrayerBuffer") ?? 0

        // Build selected prayers set
        var selectedPrayers: Set<String> = []
        if selectedFajr { selectedPrayers.insert("Fajr") }
        if selectedDhuhr { selectedPrayers.insert("Dhuhr") }
        if selectedAsr { selectedPrayers.insert("Asr") }
        if selectedMaghrib { selectedPrayers.insert("Maghrib") }
        if selectedIsha { selectedPrayers.insert("Isha") }

        // 6. Wait for prayer times to be fetched (give location + fetch time)
        // The app should have already started fetching prayer times in DhikrApp.swift
        // Wait up to 5 seconds for prayer times to become available
        let prayerTimeService = PrayerTimeService()
        var storage: PrayerTimeStorage? = nil

        for attempt in 1...10 {
            storage = prayerTimeService.loadStorage()
            if storage != nil {
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        guard let prayerStorage = storage else {
            return
        }

        // 7. Schedule the rolling window
        DeviceActivityService.shared.scheduleRollingWindow(
            from: prayerStorage,
            duration: duration,
            selectedPrayers: selectedPrayers,
            prePrayerBuffer: prePrayerBuffer
        )

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
