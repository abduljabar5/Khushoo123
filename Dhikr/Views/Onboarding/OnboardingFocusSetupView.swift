//
//  OnboardingFocusSetupView.swift
//  Dhikr
//
//  Quick setup for prayer-time app blocking (Screen 2)
//

import SwiftUI
import FamilyControls

struct OnboardingFocusSetupView: View {
    let onContinue: () -> Void

    // Use shared FocusSettingsManager for all settings
    @StateObject private var focusManager = FocusSettingsManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    // FamilyControls app selection
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var showIncompleteAlert = false

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
        hasSelectedPrayer && hasSelectedDuration
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "iphone.slash.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(theme.primaryAccent)
                        .padding(.top, 32)

                    Text("Focus Blocking")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Text("Block distracting apps during prayer times")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                VStack(spacing: 24) {
                    // Prayer Time Toggles
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Step indicator
                            StepIndicator(number: 1, isComplete: hasSelectedPrayer, theme: theme)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Prayer Times")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Choose when to block apps")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            OnboardingPrayerToggleRow(icon: "sunrise.fill", iconColor: theme.accentGold, name: "Fajr", isOn: $focusManager.selectedFajr, theme: theme)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sun.max.fill", iconColor: theme.accentGold, name: "Dhuhr", isOn: $focusManager.selectedDhuhr, theme: theme)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sun.haze.fill", iconColor: Color(hex: "FFA726"), name: "Asr", isOn: $focusManager.selectedAsr, theme: theme)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sunset.fill", iconColor: Color(hex: "FF7043"), name: "Maghrib", isOn: $focusManager.selectedMaghrib, theme: theme)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "moon.stars.fill", iconColor: Color(hex: "5E35B1"), name: "Isha", isOn: $focusManager.selectedIsha, theme: theme)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.cardBackground)
                        )
                        .padding(.horizontal, 24)
                    }

                    // Duration Selector
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Step indicator
                            StepIndicator(number: 2, isComplete: hasSelectedDuration, theme: theme)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Blocking Duration")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Time after prayer starts")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        HStack(spacing: 12) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Button(action: {
                                    focusManager.blockingDuration = duration
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(Int(duration))")
                                            .font(.system(size: 20, weight: .bold))
                                        Text("min")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(focusManager.blockingDuration == duration ? .white : theme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(focusManager.blockingDuration == duration ? theme.primaryAccent : theme.cardBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusManager.blockingDuration == duration ? Color.clear : theme.tertiaryBackground, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // App Picker Button
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Step indicator
                            StepIndicator(number: 3, isComplete: hasSelectedApps, theme: theme)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apps to Block")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Which apps to block")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        Button(action: {
                            showAppPicker = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "app.badge")
                                    .font(.system(size: 24))
                                    .foregroundColor(theme.primaryAccent)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select Apps")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(theme.primaryText)

                                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) apps selected" : "Tap to choose")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(theme.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(theme.cardBackground)
                            )
                        }
                        .padding(.horizontal, 24)
                    }

                    // Pre-Prayer Buffer (Optional)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Optional indicator
                            ZStack {
                                Circle()
                                    .fill(theme.primaryAccent.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(theme.primaryAccent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Pre-Prayer Focus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                    Text("Optional")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(theme.primaryAccent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(theme.primaryAccent.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                Text("Start blocking before prayer time")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        HStack(spacing: 12) {
                            ForEach([0.0, 5.0, 10.0, 15.0], id: \.self) { buffer in
                                Button(action: {
                                    focusManager.prePrayerBuffer = buffer
                                }) {
                                    VStack(spacing: 4) {
                                        if buffer == 0 {
                                            Text("Off")
                                                .font(.system(size: 16, weight: .bold))
                                        } else {
                                            Text("\(Int(buffer))")
                                                .font(.system(size: 20, weight: .bold))
                                            Text("min")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                    }
                                    .foregroundColor(focusManager.prePrayerBuffer == buffer ? .white : theme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(focusManager.prePrayerBuffer == buffer ? theme.primaryAccent : theme.cardBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusManager.prePrayerBuffer == buffer ? Color.clear : theme.tertiaryBackground, lineWidth: 2)
                                    )
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
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(theme.accentGold)
                        Text("Complete all 3 steps to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.horizontal, 32)
                }

                // Actions
                VStack(spacing: 16) {
                    // Primary: Save & Continue
                    Button(action: {
                        if !allStepsComplete {
                            showIncompleteAlert = true
                            return
                        }


                        // Force immediate save of app selection before continuing
                        AppSelectionModel.shared.forceSave()

                        // FocusSettingsManager automatically syncs to UserDefaults and App Group
                        onContinue()
                    }) {
                        Text(allStepsComplete ? "Continue" : "Complete All Steps")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        allStepsComplete
                                            ? LinearGradient(
                                                colors: [theme.prayerGradientStart, theme.prayerGradientEnd],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            : LinearGradient(
                                                colors: [theme.tertiaryText, theme.secondaryText],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                    )
                            )
                    }
                    .opacity(allStepsComplete ? 1.0 : 0.6)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .background(theme.primaryBackground)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { newSelection in
            // Save selection immediately - AppSelectionModel handles the save
            AppSelectionModel.shared.selection = newSelection
            // Notify FocusSettingsManager that app selection changed
            focusManager.appSelectionChanged()
        }
        .onAppear {
            // Load existing selection if any
            let savedSelection = AppSelectionModel.shared.selection
            selection = savedSelection
        }
        .onAppear {
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
    }
}

// MARK: - Step Indicator Component

private struct StepIndicator: View {
    let number: Int
    let isComplete: Bool
    let theme: AppTheme

    var body: some View {
        ZStack {
            Circle()
                .fill(isComplete ? theme.primaryAccent : theme.tertiaryBackground)
                .frame(width: 32, height: 32)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.tertiaryText)
            }
        }
    }
}

// MARK: - Supporting Views

private struct OnboardingPrayerToggleRow: View {
    let icon: String
    let iconColor: Color
    let name: String
    @Binding var isOn: Bool
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingFocusSetupView(onContinue: {})
}
