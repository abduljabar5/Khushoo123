//
//  OnboardingPermissionsView.swift
//  Dhikr
//
//  Permissions & Services setup (Screen 3)
//

import SwiftUI
import CoreLocation
import UserNotifications
import FamilyControls

struct OnboardingPermissionsView: View {
    let onContinue: () -> Void

    @StateObject private var locationService = LocationService()
    @StateObject private var notificationService = PrayerNotificationService.shared
    @StateObject private var screenTimeAuth = ScreenTimeAuthorizationService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showLocationAlert = false

    private var theme: AppTheme { themeManager.theme }

    private var hasLocationPermission: Bool {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(theme.primaryAccent)

                Text("Permissions")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Text("Enable these to get the most out of Khushoo")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)

            // Permission Rows
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "location.circle.fill",
                    iconColor: theme.accentGold,
                    title: "Location",
                    description: "For accurate prayer times",
                    status: locationPermissionStatus,
                    theme: theme,
                    action: {
                        locationService.requestLocationPermission()
                    }
                )

                PermissionRow(
                    icon: "bell.badge.fill",
                    iconColor: Color(hex: "FF7043"),
                    title: "Notifications",
                    description: "Prayer and dhikr reminders",
                    status: notificationService.hasNotificationPermission ? "Enabled" : "Not now",
                    theme: theme,
                    action: {
                        Task {
                            await notificationService.requestNotificationPermission()
                        }
                    }
                )

                PermissionRow(
                    icon: "hourglass.circle.fill",
                    iconColor: Color(hex: "5E35B1"),
                    title: "Screen Time",
                    description: "For prayer-time app blocking",
                    status: screenTimeAuth.isAuthorized ? "Enabled" : "Not now",
                    theme: theme,
                    action: {
                        Task {
                            do {
                                try await screenTimeAuth.requestAuthorization()
                            } catch {
                            }
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // Warning message if location not enabled
            if !hasLocationPermission {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.accentGold)
                    Text("Location is required for prayer times")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            // Action
            Button(action: {
                if !hasLocationPermission {
                    showLocationAlert = true
                    return
                }

                onContinue()
            }) {
                Text(hasLocationPermission ? "Continue to App" : "Enable Location to Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                hasLocationPermission
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
            .opacity(hasLocationPermission ? 1.0 : 0.6)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(theme.primaryBackground)
        .onAppear {
        }
        .alert("Location Permission Required", isPresented: $showLocationAlert) {
            Button("Enable Location", role: .none) {
                locationService.requestLocationPermission()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is required to calculate accurate prayer times for your area. Please enable location permission to continue.")
        }
    }

    private var locationPermissionStatus: String {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Enabled"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not now"
        @unknown default:
            return "Not now"
        }
    }
}

// MARK: - Supporting Views

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            // Status/Action
            if status == "Enabled" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.accentGreen)
                    Text("Enabled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.accentGreen)
                }
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.primaryAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.primaryAccent, lineWidth: 2)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
    }
}

#Preview {
    OnboardingPermissionsView(onContinue: {})
}
