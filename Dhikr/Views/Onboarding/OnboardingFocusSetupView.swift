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
                        .foregroundColor(Color(hex: "1A9B8A"))
                        .padding(.top, 32)

                    Text("Focus Blocking")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "2C3E50"))

                    Text("Block distracting apps during prayer times")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "7F8C8D"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 32)

                VStack(spacing: 24) {
                    // Prayer Time Toggles
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Step indicator
                            StepIndicator(number: 1, isComplete: hasSelectedPrayer)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Prayer Times")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "2C3E50"))

                                Text("Choose when to block apps")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(hex: "95A5A6"))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            OnboardingPrayerToggleRow(icon: "sunrise.fill", iconColor: Color(hex: "F39C12"), name: "Fajr", isOn: $focusManager.selectedFajr)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sun.max.fill", iconColor: Color(hex: "F39C12"), name: "Dhuhr", isOn: $focusManager.selectedDhuhr)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sun.haze.fill", iconColor: Color(hex: "FFA726"), name: "Asr", isOn: $focusManager.selectedAsr)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "sunset.fill", iconColor: Color(hex: "FF7043"), name: "Maghrib", isOn: $focusManager.selectedMaghrib)
                            Divider().padding(.leading, 70)
                            OnboardingPrayerToggleRow(icon: "moon.stars.fill", iconColor: Color(hex: "5E35B1"), name: "Isha", isOn: $focusManager.selectedIsha)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        .padding(.horizontal, 24)
                    }

                    // Duration Selector
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            // Step indicator
                            StepIndicator(number: 2, isComplete: hasSelectedDuration)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Blocking Duration")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "2C3E50"))

                                Text("How long to block apps")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(hex: "95A5A6"))
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
                                    .foregroundColor(focusManager.blockingDuration == duration ? .white : Color(hex: "2C3E50"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(focusManager.blockingDuration == duration ? Color(hex: "1A9B8A") : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusManager.blockingDuration == duration ? Color.clear : Color(hex: "ECECEC"), lineWidth: 2)
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
                            StepIndicator(number: 3, isComplete: hasSelectedApps)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apps to Block")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: "2C3E50"))

                                Text("Which apps to block")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(hex: "95A5A6"))
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
                                    .foregroundColor(Color(hex: "1A9B8A"))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select Apps")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(hex: "2C3E50"))

                                    Text(selectedAppsCount > 0 ? "\(selectedAppsCount) apps selected" : "Tap to choose")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color(hex: "7F8C8D"))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "CECECE"))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                        }
                        .padding(.horizontal, 24)
                    }

                }
                .padding(.bottom, 32)

                // Progress indicator
                if !allStepsComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Color(hex: "F39C12"))
                        Text("Complete all 3 steps to continue")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "7F8C8D"))
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

                        print("[Onboarding] FocusSetup - Saving selections")
                        print("[FocusSetup] Saved - Fajr=\(focusManager.selectedFajr), Dhuhr=\(focusManager.selectedDhuhr), Asr=\(focusManager.selectedAsr), Maghrib=\(focusManager.selectedMaghrib), Isha=\(focusManager.selectedIsha), Duration=\(focusManager.blockingDuration)")

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
                                                colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            : LinearGradient(
                                                colors: [Color(hex: "BDC3C7"), Color(hex: "95A5A6")],
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
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { newSelection in
            print("[FocusSetup] Apps selected: \(selectedAppsCount)")
            // Save selection immediately - AppSelectionModel handles the save
            AppSelectionModel.shared.selection = newSelection
            // Notify FocusSettingsManager that app selection changed
            focusManager.appSelectionChanged()
        }
        .onAppear {
            // Load existing selection if any
            let savedSelection = AppSelectionModel.shared.selection
            selection = savedSelection
            print("[FocusSetup] Loaded saved app selection: \(selectedAppsCount) items")
        }
        .onAppear {
            print("[Onboarding] FocusSetup screen shown")
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

    var body: some View {
        ZStack {
            Circle()
                .fill(isComplete ? Color(hex: "1A9B8A") : Color(hex: "ECECEC"))
                .frame(width: 32, height: 32)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "95A5A6"))
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

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "2C3E50"))

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
