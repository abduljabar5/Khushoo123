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
    let onSkip: () -> Void

    // Prayer toggles (all preselected by default)
    @AppStorage("focusSelectedFajr") private var selectedFajr = true
    @AppStorage("focusSelectedDhuhr") private var selectedDhuhr = true
    @AppStorage("focusSelectedAsr") private var selectedAsr = true
    @AppStorage("focusSelectedMaghrib") private var selectedMaghrib = true
    @AppStorage("focusSelectedIsha") private var selectedIsha = true

    // Blocking duration (default 30 minutes)
    @AppStorage("focusBlockingDuration") private var blockingDuration: Double = 30.0

    // FamilyControls app selection
    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var selectedAppsCount = 0

    private let durationOptions: [Double] = [15, 30, 45, 60]

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
                        Text("Select Prayer Times")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "2C3E50"))
                            .padding(.horizontal, 24)

                        VStack(spacing: 0) {
                            PrayerToggleRow(icon: "sunrise.fill", iconColor: Color(hex: "F39C12"), name: "Fajr", isOn: $selectedFajr)
                            Divider().padding(.leading, 70)
                            PrayerToggleRow(icon: "sun.max.fill", iconColor: Color(hex: "F39C12"), name: "Dhuhr", isOn: $selectedDhuhr)
                            Divider().padding(.leading, 70)
                            PrayerToggleRow(icon: "sun.haze.fill", iconColor: Color(hex: "FFA726"), name: "Asr", isOn: $selectedAsr)
                            Divider().padding(.leading, 70)
                            PrayerToggleRow(icon: "sunset.fill", iconColor: Color(hex: "FF7043"), name: "Maghrib", isOn: $selectedMaghrib)
                            Divider().padding(.leading, 70)
                            PrayerToggleRow(icon: "moon.stars.fill", iconColor: Color(hex: "5E35B1"), name: "Isha", isOn: $selectedIsha)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        .padding(.horizontal, 24)
                    }

                    // Duration Selector
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Blocking Duration")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "2C3E50"))
                            .padding(.horizontal, 24)

                        HStack(spacing: 12) {
                            ForEach(durationOptions, id: \.self) { duration in
                                Button(action: {
                                    blockingDuration = duration
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(Int(duration))")
                                            .font(.system(size: 20, weight: .bold))
                                        Text("min")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(blockingDuration == duration ? .white : Color(hex: "2C3E50"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 64)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(blockingDuration == duration ? Color(hex: "1A9B8A") : Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(blockingDuration == duration ? Color.clear : Color(hex: "ECECEC"), lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // App Picker Button
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Apps to Block")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "2C3E50"))
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

                // Actions
                VStack(spacing: 16) {
                    // Primary: Save & Continue
                    Button(action: {
                        print("[Onboarding] FocusSetup - Saving selections")
                        saveToAppGroup()
                        print("[FocusSetup] Saved - Fajr=\(selectedFajr), Dhuhr=\(selectedDhuhr), Asr=\(selectedAsr), Maghrib=\(selectedMaghrib), Isha=\(selectedIsha), Duration=\(blockingDuration)")
                        onContinue()
                    }) {
                        Text("Save & Continue")
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

                    // Secondary: Skip
                    Button(action: {
                        print("[Onboarding] FocusSetup - Skip (using defaults)")
                        saveToAppGroup() // Save defaults
                        onSkip()
                    }) {
                        Text("Skip (use defaults)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "7F8C8D"))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { newSelection in
            selectedAppsCount = newSelection.applicationTokens.count + newSelection.categoryTokens.count
            print("[FocusSetup] Apps selected: \(selectedAppsCount)")
            // Save selection immediately
            FamilyActivitySelectionStore.shared.saveSelection(newSelection)
        }
        .onAppear {
            // Load existing selection if any
            if let savedSelection = FamilyActivitySelectionStore.shared.loadSelection() {
                selection = savedSelection
                selectedAppsCount = savedSelection.applicationTokens.count + savedSelection.categoryTokens.count
                print("[FocusSetup] Loaded saved app selection: \(selectedAppsCount) items")
            }
        }
        .onAppear {
            print("[Onboarding] FocusSetup screen shown")
        }
    }

    private func saveToAppGroup() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            print("[FocusSetup] Failed to access App Group")
            return
        }

        // Save to App Group
        groupDefaults.set(selectedFajr, forKey: "focusSelectedFajr")
        groupDefaults.set(selectedDhuhr, forKey: "focusSelectedDhuhr")
        groupDefaults.set(selectedAsr, forKey: "focusSelectedAsr")
        groupDefaults.set(selectedMaghrib, forKey: "focusSelectedMaghrib")
        groupDefaults.set(selectedIsha, forKey: "focusSelectedIsha")
        groupDefaults.set(blockingDuration, forKey: "focusBlockingDuration")
        groupDefaults.synchronize()

        print("[FocusSetup] Settings saved to App Group")
    }
}

// MARK: - Supporting Views

struct PrayerToggleRow: View {
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
    OnboardingFocusSetupView(onContinue: {}, onSkip: {})
}
