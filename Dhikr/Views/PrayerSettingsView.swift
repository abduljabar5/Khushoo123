//
//  PrayerSettingsView.swift
//  Dhikr
//
//  Sacred Minimalism design - Prayer calculation settings
//

import SwiftUI

struct PrayerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsManager = PrayerCalculationSettingsManager.shared

    // Current selections (local state until confirmed)
    @State private var selectedMethod: CalculationMethod
    @State private var selectedAsrMethod: AsrJuristicMethod

    // UI State
    @State private var showingConfirmation = false
    @State private var isApplyingChanges = false
    @State private var hasChanges = false

    // Location for recommendation
    let currentCountry: String

    // Callback when settings are applied
    var onSettingsApplied: (() -> Void)?

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

    private var recommendedMethod: CalculationMethod {
        settingsManager.recommendedMethod(for: currentCountry)
    }

    init(currentCountry: String, onSettingsApplied: (() -> Void)? = nil) {
        self.currentCountry = currentCountry
        self.onSettingsApplied = onSettingsApplied
        _selectedMethod = State(initialValue: PrayerCalculationSettingsManager.shared.calculationMethod)
        _selectedAsrMethod = State(initialValue: PrayerCalculationSettingsManager.shared.asrMethod)
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Calculation Method Section
                        calculationMethodSection

                        // Asr Method Section
                        asrMethodSection

                        // Info Note
                        infoNote
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }

                // Apply Button
                if hasChanges {
                    applyButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 34)
                }
            }

            // Loading Overlay
            if isApplyingChanges {
                loadingOverlay
            }
        }
        .onChange(of: selectedMethod) { _, _ in checkForChanges() }
        .onChange(of: selectedAsrMethod) { _, _ in checkForChanges() }
        .alert("Update Prayer Times?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                applyChanges()
            }
        } message: {
            Text("Your prayer times will be recalculated using the new settings. This may take a moment.")
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                    )
            }

            Spacer()

            VStack(spacing: 4) {
                Text("Prayer Settings")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)
            }

            Spacer()

            // Invisible spacer for balance
            Circle()
                .fill(Color.clear)
                .frame(width: 36, height: 36)
        }
    }

    // MARK: - Calculation Method Section
    private var calculationMethodSection: some View {
        VStack(spacing: 14) {
            sacredSectionHeader(title: "CALCULATION METHOD")

            VStack(spacing: 0) {
                ForEach(Array(CalculationMethod.orderedCases.enumerated()), id: \.element.id) { index, method in
                    VStack(spacing: 0) {
                        CalculationMethodRow(
                            method: method,
                            isSelected: selectedMethod == method,
                            isRecommended: method == recommendedMethod,
                            sacredGold: sacredGold,
                            softGreen: softGreen,
                            cardBackground: cardBackground
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMethod = method
                            }
                            HapticManager.shared.impact(.light)
                        }

                        if index < CalculationMethod.orderedCases.count - 1 {
                            Rectangle()
                                .fill(pageBackground)
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Asr Method Section
    private var asrMethodSection: some View {
        VStack(spacing: 14) {
            sacredSectionHeader(title: "ASR CALCULATION")

            VStack(spacing: 0) {
                ForEach(Array(AsrJuristicMethod.allCases.enumerated()), id: \.element.id) { index, method in
                    VStack(spacing: 0) {
                        AsrMethodRow(
                            method: method,
                            isSelected: selectedAsrMethod == method,
                            sacredGold: sacredGold,
                            cardBackground: cardBackground
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedAsrMethod = method
                            }
                            HapticManager.shared.impact(.light)
                        }

                        if index < AsrJuristicMethod.allCases.count - 1 {
                            Rectangle()
                                .fill(pageBackground)
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Info Note
    private var infoNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(warmGray)

            Text("Different methods use varying sun angles to calculate Fajr and Isha times. Choose the method commonly used in your region or by your local mosque.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
                .lineSpacing(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground.opacity(0.5))
        )
    }

    // MARK: - Apply Button
    private var applyButton: some View {
        Button(action: { showingConfirmation = true }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                Text("Apply Changes")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(sacredGold)
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(sacredGold)

                Text("Updating prayer times...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
            )
        }
    }

    // MARK: - Section Header
    private func sacredSectionHeader(title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(sacredGold.opacity(0.4))
                .frame(width: 20, height: 1)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(themeManager.theme.secondaryText)

            Spacer()
        }
    }

    // MARK: - Helpers
    private func checkForChanges() {
        withAnimation(.easeInOut(duration: 0.25)) {
            hasChanges = selectedMethod != settingsManager.calculationMethod ||
                         selectedAsrMethod != settingsManager.asrMethod
        }
    }

    private func applyChanges() {
        isApplyingChanges = true

        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Update settings (this triggers the refresh)
            settingsManager.updateCalculationMethod(selectedMethod, triggerRefresh: false)
            settingsManager.updateAsrMethod(selectedAsrMethod, triggerRefresh: false)

            // Trigger the callback
            onSettingsApplied?()

            // Wait a moment then dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isApplyingChanges = false
                hasChanges = false
                dismiss()
            }
        }
    }
}

// MARK: - Calculation Method Row
struct CalculationMethodRow: View {
    let method: CalculationMethod
    let isSelected: Bool
    let isRecommended: Bool
    let sacredGold: Color
    let softGreen: Color
    let cardBackground: Color
    let onTap: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? sacredGold : themeManager.theme.secondaryText.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: 12, height: 12)
                    }
                }

                // Method info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(method.name)
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundColor(themeManager.theme.primaryText)

                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(softGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(softGreen.opacity(0.15))
                                )
                        }
                    }

                    Text(method.angles)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text(method.regions)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Asr Method Row
struct AsrMethodRow: View {
    let method: AsrJuristicMethod
    let isSelected: Bool
    let sacredGold: Color
    let cardBackground: Color
    let onTap: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? sacredGold : themeManager.theme.secondaryText.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(sacredGold)
                            .frame(width: 12, height: 12)
                    }
                }

                // Method info
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.name)
                        .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text(method.description)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text(method.detail)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText.opacity(0.7))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PrayerSettingsView(currentCountry: "United States")
}
