//
//  OnboardingPermissionsView.swift
//  Dhikr
//
//  Permissions & Services setup (Screen 3) - Sacred Minimalism redesign
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
    @State private var showLocationDeniedAlert = false
    @State private var showNotificationDeniedAlert = false
    @State private var showScreenTimeDeniedAlert = false
    @State private var isRequestingLocation = false
    @State private var isRequestingNotifications = false
    @State private var isRequestingScreenTime = false

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

    private var isLocationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
    }

    private var isNotificationDenied: Bool {
        notificationService.isNotificationPermissionDenied
    }

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

                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }

                Text("Permissions")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Enable these to get the most out of Khushoo")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)

            // Permission Rows - Sacred style
            VStack(spacing: 12) {
                SacredPermissionRow(
                    icon: "location.circle",
                    iconColor: sacredGold,
                    title: "Location",
                    description: "For accurate prayer times",
                    status: locationPermissionStatus,
                    isLoading: isRequestingLocation,
                    action: {
                        if isLocationDenied {
                            showLocationDeniedAlert = true
                        } else {
                            isRequestingLocation = true
                            locationService.requestLocationPermission()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRequestingLocation = false
                            }
                        }
                    }
                )

                SacredPermissionRow(
                    icon: "bell.badge",
                    iconColor: Color(red: 0.85, green: 0.5, blue: 0.4),
                    title: "Notifications",
                    description: "Prayer and dhikr reminders",
                    status: notificationPermissionStatus,
                    isLoading: isRequestingNotifications,
                    action: {
                        if isNotificationDenied {
                            showNotificationDeniedAlert = true
                        } else {
                            isRequestingNotifications = true
                            Task {
                                await notificationService.requestNotificationPermission()
                                await MainActor.run {
                                    isRequestingNotifications = false
                                }
                            }
                        }
                    }
                )

                SacredPermissionRow(
                    icon: "hourglass.circle",
                    iconColor: mutedPurple,
                    title: "Screen Time",
                    description: "For prayer-time app blocking",
                    status: screenTimePermissionStatus,
                    isLoading: isRequestingScreenTime,
                    action: {
                        if screenTimeAuth.authorizationStatus == .denied {
                            showScreenTimeDeniedAlert = true
                        } else {
                            isRequestingScreenTime = true
                            Task {
                                let _ = await screenTimeAuth.requestAuthorizationWithErrorHandling()
                                await MainActor.run {
                                    isRequestingScreenTime = false
                                }
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
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(sacredGold)
                    Text("Location is required for prayer times")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(warmGray)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
            }

            // Continue Button - Sacred style
            Button(action: {
                if !hasLocationPermission {
                    showLocationAlert = true
                    return
                }
                onContinue()
            }) {
                Text(hasLocationPermission ? "Continue" : "Enable Location to Continue")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(hasLocationPermission ? (themeManager.effectiveTheme == .dark ? .black : .white) : warmGray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(hasLocationPermission ? sacredGold : sacredGold.opacity(0.3))
                    )
            }
            .opacity(hasLocationPermission ? 1.0 : 0.7)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(pageBackground)
        .onChange(of: locationService.authorizationStatus) { newStatus in
            if newStatus == .denied || newStatus == .restricted {
                isRequestingLocation = false
                showLocationDeniedAlert = true
            }
        }
        .onChange(of: notificationService.isNotificationPermissionDenied) { isDenied in
            if isDenied {
                isRequestingNotifications = false
                showNotificationDeniedAlert = true
            }
        }
        .alert("Location Permission Required", isPresented: $showLocationAlert) {
            Button("Enable Location", role: .none) {
                locationService.requestLocationPermission()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is required to calculate accurate prayer times for your area. Please enable location permission to continue.")
        }
        .alert("Location Access Denied", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings", role: .none) {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location permission was denied. Please enable it in Settings to get accurate prayer times for your location.")
        }
        .alert("Notifications Disabled", isPresented: $showNotificationDeniedAlert) {
            Button("Open Settings", role: .none) {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Notification permission was denied. Please enable it in Settings to receive prayer time reminders.")
        }
        .alert("Screen Time Access Denied", isPresented: $showScreenTimeDeniedAlert) {
            Button("Open Settings", role: .none) {
                openSettings()
            }
            Button("Skip", role: .cancel) { }
        } message: {
            Text("Screen Time permission was denied. Please enable it in Settings to use prayer-time app blocking.")
        }
        .alert("Screen Time Error", isPresented: $screenTimeAuth.showErrorAlert) {
            Button("OK", role: .cancel) {
                screenTimeAuth.clearError()
            }
        } message: {
            if let error = screenTimeAuth.lastError {
                Text("\(error.errorDescription ?? "An error occurred.")\n\n\(error.recoverySuggestion)")
            } else {
                Text("An error occurred while requesting Screen Time permission. You can skip this step and enable it later.")
            }
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

    private var notificationPermissionStatus: String {
        if notificationService.hasNotificationPermission {
            return "Enabled"
        } else if notificationService.isNotificationPermissionDenied {
            return "Denied"
        } else {
            return "Not now"
        }
    }

    private var screenTimePermissionStatus: String {
        switch screenTimeAuth.authorizationStatus {
        case .approved:
            return "Enabled"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not now"
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Sacred Permission Row

private struct SacredPermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: String
    var isLoading: Bool = false
    let action: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

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

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(description)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(warmGray)
            }

            Spacer()

            // Status/Action
            if status == "Enabled" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(softGreen)
                    Text("Enabled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(softGreen)
                }
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: sacredGold))
                    .frame(width: 70, height: 32)
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(sacredGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                        )
                }
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
}

#Preview {
    OnboardingPermissionsView(onContinue: {})
}
