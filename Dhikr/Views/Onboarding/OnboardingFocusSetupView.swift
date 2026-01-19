//
//  OnboardingFocusSetupView.swift
//  Dhikr
//
//  Quick setup for prayer-time app blocking (Screen 2) - Sacred Minimalism redesign
//

import SwiftUI
import FamilyControls

struct OnboardingFocusSetupView: View {
    let onContinue: () -> Void

    // Use shared FocusSettingsManager for all settings
    @StateObject private var focusManager = FocusSettingsManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared

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

    // FamilyControls app selection
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showIncompleteAlert = false
    @State private var isRequestingScreenTime = false

    private let durationOptions: [Double] = [15, 30, 45, 60]

    // Computed property for app count
    private var selectedAppsCount: Int {
        let selection = AppSelectionModel.shared.selection
        return selection.applicationTokens.count +
               selection.categoryTokens.count +
               selection.webDomainTokens.count
    }

    // Step completion checks
    private var hasSelectedPrayer: Bool {
        focusManager.selectedFajr || focusManager.selectedDhuhr ||
        focusManager.selectedAsr || focusManager.selectedMaghrib ||
        focusManager.selectedIsha
    }

    private var hasSelectedDuration: Bool {
        focusManager.blockingDuration > 0
    }

    private var hasSelectedApps: Bool {
        selectedAppsCount > 0
    }

    private var allStepsComplete: Bool {
        hasSelectedPrayer && hasSelectedDuration && hasSelectedApps
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header - Sacred style
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(sacredGold.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                            )

                        Image(systemName: "shield.fill")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(sacredGold)
                    }
                    .padding(.top, 32)

                    Text("Focus Blocking")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Block distracting apps during prayer times")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(warmGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                VStack(spacing: 28) {
                    // Step 1: Prayer Time Toggles
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            SacredStepIndicator(number: 1, isComplete: hasSelectedPrayer)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("SELECT PRAYER TIMES")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(warmGray)

                                Text("Choose when to block apps")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(warmGray.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            SacredOnboardingPrayerToggle(
                                icon: "sunrise",
                                arabicName: "الفجر",
                                name: "Fajr",
                                isOn: $focusManager.selectedFajr,
                                color: sacredGold
                            )
                            OnboardingDivider()
                            SacredOnboardingPrayerToggle(
                                icon: "sun.max",
                                arabicName: "الظهر",
                                name: "Dhuhr",
                                isOn: $focusManager.selectedDhuhr,
                                color: sacredGold
                            )
                            OnboardingDivider()
                            SacredOnboardingPrayerToggle(
                                icon: "sun.haze",
                                arabicName: "العصر",
                                name: "Asr",
                                isOn: $focusManager.selectedAsr,
                                color: Color(red: 0.85, green: 0.6, blue: 0.4)
                            )
                            OnboardingDivider()
                            SacredOnboardingPrayerToggle(
                                icon: "sunset",
                                arabicName: "المغرب",
                                name: "Maghrib",
                                isOn: $focusManager.selectedMaghrib,
                                color: Color(red: 0.85, green: 0.5, blue: 0.4)
                            )
                            OnboardingDivider()
                            SacredOnboardingPrayerToggle(
                                icon: "moon.stars",
                                arabicName: "العشاء",
                                name: "Isha",
                                isOn: $focusManager.selectedIsha,
                                color: mutedPurple
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                    }

                    // Step 2: Duration Selector
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            SacredStepIndicator(number: 2, isComplete: hasSelectedDuration)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("BLOCKING DURATION")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(warmGray)

                                Text("Time after prayer starts")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(warmGray.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        HStack(spacing: 10) {
                            ForEach(durationOptions, id: \.self) { duration in
                                SacredDurationOption(
                                    duration: Int(duration),
                                    isSelected: focusManager.blockingDuration == duration
                                ) {
                                    focusManager.blockingDuration = duration
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Step 3: App Picker Button
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            SacredStepIndicator(number: 3, isComplete: hasSelectedApps)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("APPS TO BLOCK")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(warmGray)

                                Text("Which apps to block")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(warmGray.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        Button(action: {
                            if screenTimeAuth.isAuthorized {
                                showAppPicker = true
                            } else {
                                isRequestingScreenTime = true
                                Task {
                                    let success = await screenTimeAuth.requestAuthorizationWithErrorHandling()
                                    await MainActor.run {
                                        isRequestingScreenTime = false
                                        if success {
                                            showAppPicker = true
                                        }
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(sacredGold.opacity(0.12))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: "app.badge")
                                        .font(.system(size: 20, weight: .light))
                                        .foregroundColor(sacredGold)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select Apps")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(themeManager.theme.primaryText)

                                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) apps selected" : "Tap to choose")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundColor(warmGray)
                                }

                                Spacer()

                                if isRequestingScreenTime {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: sacredGold))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundColor(warmGray)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isRequestingScreenTime)
                        .padding(.horizontal, 24)
                    }

                    // Optional: Pre-Prayer Buffer
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(sacredGold.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(sacredGold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("PRE-PRAYER FOCUS")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(2)
                                        .foregroundColor(warmGray)

                                    Text("Optional")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(sacredGold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(sacredGold.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                Text("Start blocking before prayer time")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(warmGray.opacity(0.7))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        HStack(spacing: 10) {
                            ForEach([0.0, 5.0, 10.0, 15.0], id: \.self) { buffer in
                                SacredBufferOption(
                                    buffer: Int(buffer),
                                    isSelected: focusManager.prePrayerBuffer == buffer
                                ) {
                                    focusManager.prePrayerBuffer = buffer
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 32)

                // Progress indicator
                if !allStepsComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(sacredGold)
                        Text("Complete all 3 steps to continue")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(warmGray)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }

                // Continue Button - Sacred style
                Button(action: {
                    if !allStepsComplete {
                        showIncompleteAlert = true
                        return
                    }

                    AppSelectionModel.shared.forceSave()
                    onContinue()
                }) {
                    Text(allStepsComplete ? "Continue" : "Complete All Steps")
                        .font(.system(size: 16, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(allStepsComplete ? (themeManager.effectiveTheme == .dark ? .black : .white) : warmGray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(allStepsComplete ? sacredGold : sacredGold.opacity(0.3))
                        )
                }
                .opacity(allStepsComplete ? 1.0 : 0.7)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(pageBackground)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { newSelection in
            AppSelectionModel.shared.selection = newSelection
            focusManager.appSelectionChanged()
        }
        .onAppear {
            let savedSelection = AppSelectionModel.shared.selection
            selection = savedSelection
        }
        .alert("Complete Setup Required", isPresented: $showIncompleteAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if !hasSelectedPrayer {
                Text("Please select at least one prayer time to block apps.")
            } else if !hasSelectedDuration {
                Text("Please select a blocking duration.")
            } else if !hasSelectedApps {
                Text("Please select at least one app to block during prayer times.")
            }
        }
        .alert("Screen Time Error", isPresented: $screenTimeAuth.showErrorAlert) {
            Button("OK", role: .cancel) {
                screenTimeAuth.clearError()
            }
        } message: {
            if let error = screenTimeAuth.lastError {
                Text("\(error.errorDescription ?? "An error occurred.")\n\n\(error.recoverySuggestion)")
            } else {
                Text("Screen Time permission is required to select apps for blocking. Please try again.")
            }
        }
    }
}

// MARK: - Sacred Step Indicator

private struct SacredStepIndicator: View {
    let number: Int
    let isComplete: Bool

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    @StateObject private var themeManager = ThemeManager.shared

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isComplete ? softGreen : warmGray.opacity(0.2))
                .frame(width: 32, height: 32)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(warmGray)
            }
        }
    }
}

// MARK: - Sacred Onboarding Prayer Toggle

private struct SacredOnboardingPrayerToggle: View {
    let icon: String
    let arabicName: String
    let name: String
    @Binding var isOn: Bool
    let color: Color

    @StateObject private var themeManager = ThemeManager.shared

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(arabicName)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundColor(warmGray)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(red: 0.77, green: 0.65, blue: 0.46))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Sacred Duration Option

private struct SacredDurationOption: View {
    let duration: Int
    let isSelected: Bool
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
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
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(duration)")
                    .font(.system(size: 22, weight: .ultraLight))
                Text("min")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
            }
            .foregroundColor(isSelected ? (themeManager.effectiveTheme == .dark ? .black : .white) : themeManager.theme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? sacredGold : cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Sacred Buffer Option

private struct SacredBufferOption: View {
    let buffer: Int
    let isSelected: Bool
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
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
        Button(action: action) {
            VStack(spacing: 4) {
                if buffer == 0 {
                    Text("Off")
                        .font(.system(size: 15, weight: .light))
                } else {
                    Text("\(buffer)")
                        .font(.system(size: 22, weight: .ultraLight))
                    Text("min")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1)
                }
            }
            .foregroundColor(isSelected ? (themeManager.effectiveTheme == .dark ? .black : .white) : themeManager.theme.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? sacredGold : cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.clear : sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Onboarding Divider

private struct OnboardingDivider: View {
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    var body: some View {
        Rectangle()
            .fill(sacredGold.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, 70)
    }
}

#Preview {
    OnboardingFocusSetupView(onContinue: {})
}
