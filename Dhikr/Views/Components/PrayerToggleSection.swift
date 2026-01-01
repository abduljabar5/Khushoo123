//
//  PrayerToggleSection.swift
//  Dhikr
//
//  Created by Claude Code
//

import SwiftUI

/// Reusable component for displaying prayer time toggles with app selection validation
struct PrayerToggleSection: View {
    @ObservedObject var focusManager: FocusSettingsManager
    let showOverlayWhenEmpty: Bool
    let onSelectApps: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var containerBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        ZStack {
            // Prayer toggles
            VStack(alignment: .leading, spacing: 16) {
                Text("Select Prayers")
                    .font(.headline)
                    .foregroundColor(theme.primaryText)

                VStack(spacing: 0) {
                    PrayerToggleRow(
                        prayerName: "Fajr",
                        icon: "sun.haze.fill",
                        isSelected: $focusManager.selectedFajr
                    )
                    .disabled(!focusManager.hasAppsSelected)
                    .opacity(focusManager.hasAppsSelected ? 1.0 : 0.5)

                    Divider().background(Color(white: 0.2))

                    PrayerToggleRow(
                        prayerName: "Dhuhr",
                        icon: "sun.max.fill",
                        isSelected: $focusManager.selectedDhuhr
                    )
                    .disabled(!focusManager.hasAppsSelected)
                    .opacity(focusManager.hasAppsSelected ? 1.0 : 0.5)

                    Divider().background(Color(white: 0.2))

                    PrayerToggleRow(
                        prayerName: "Asr",
                        icon: "cloud.sun.fill",
                        isSelected: $focusManager.selectedAsr
                    )
                    .disabled(!focusManager.hasAppsSelected)
                    .opacity(focusManager.hasAppsSelected ? 1.0 : 0.5)

                    Divider().background(Color(white: 0.2))

                    PrayerToggleRow(
                        prayerName: "Maghrib",
                        icon: "moon.fill",
                        isSelected: $focusManager.selectedMaghrib
                    )
                    .disabled(!focusManager.hasAppsSelected)
                    .opacity(focusManager.hasAppsSelected ? 1.0 : 0.5)

                    Divider().background(Color(white: 0.2))

                    PrayerToggleRow(
                        prayerName: "Isha",
                        icon: "moon.stars.fill",
                        isSelected: $focusManager.selectedIsha
                    )
                    .disabled(!focusManager.hasAppsSelected)
                    .opacity(focusManager.hasAppsSelected ? 1.0 : 0.5)
                }
                .background(containerBackground)
            }

            // Overlay when no apps selected
            if !focusManager.hasAppsSelected && showOverlayWhenEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge")
                        .font(.system(size: 48))
                        .foregroundColor(theme.primaryAccent)

                    Text("Select apps to block first")
                        .font(.headline)
                        .foregroundColor(theme.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Choose which apps to block during prayer times")
                        .font(.subheadline)
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(action: onSelectApps) {
                        HStack {
                            Image(systemName: "app.badge.checkmark")
                            Text("Select Apps")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(theme.primaryAccent)
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    themeManager.effectiveTheme == .dark ?
                    Color(red: 0.15, green: 0.17, blue: 0.20).opacity(0.95) :
                    theme.cardBackground.opacity(0.95)
                )
                .cornerRadius(12)
            }
        }
    }
}

/// Individual prayer toggle row component
private struct PrayerToggleRow: View {
    let prayerName: String
    let icon: String
    @Binding var isSelected: Bool

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isSelected ? Color(red: 0.2, green: 0.8, blue: 0.6) : theme.tertiaryText)
                .frame(width: 20)

            Text(prayerName)
                .font(.system(size: 15))
                .foregroundColor(theme.primaryText)

            Spacer()

            Toggle("", isOn: $isSelected)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.8, blue: 0.6)))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        PrayerToggleSection(
            focusManager: FocusSettingsManager.shared,
            showOverlayWhenEmpty: true,
            onSelectApps: {
                print("Select apps tapped")
            }
        )
    }
    .padding()
}
