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
    @State private var showLocationAlert = false

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
                    .foregroundColor(Color(hex: "1A9B8A"))

                Text("Permissions")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2C3E50"))

                Text("Enable these to get the most out of Khushoo")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)

            // Permission Rows
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "location.circle.fill",
                    iconColor: Color(hex: "F39C12"),
                    title: "Location",
                    description: "For accurate prayer times",
                    status: locationPermissionStatus,
                    action: {
                        print("[Permissions] Requesting location")
                        locationService.requestLocationPermission()
                    }
                )

                PermissionRow(
                    icon: "bell.badge.fill",
                    iconColor: Color(hex: "FF7043"),
                    title: "Notifications",
                    description: "Prayer and dhikr reminders",
                    status: notificationService.hasNotificationPermission ? "Enabled" : "Not now",
                    action: {
                        print("[Permissions] Requesting notifications")
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
                    action: {
                        print("[Permissions] Requesting Screen Time authorization")
                        Task {
                            do {
                                try await screenTimeAuth.requestAuthorization()
                            } catch {
                                print("❌ [Permissions] Screen Time authorization failed: \(error)")
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
                        .foregroundColor(Color(hex: "F39C12"))
                    Text("Location is required for prayer times")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "7F8C8D"))
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

                print("[Permissions] Current statuses - Location: \(locationPermissionStatus), Notifications: \(notificationService.hasNotificationPermission ? "Enabled" : "Not now"), Screen Time: \(screenTimeAuth.isAuthorized ? "Enabled" : "Not now")")
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
            .opacity(hasLocationPermission ? 1.0 : 0.6)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            print("[Onboarding] Permissions screen shown")
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
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "2C3E50"))

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "7F8C8D"))
            }

            Spacer()

            // Status/Action
            if status == "Enabled" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "27AE60"))
                    Text("Enabled")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "27AE60"))
                }
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1A9B8A"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "1A9B8A"), lineWidth: 2)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
        )
    }
}

#Preview {
    OnboardingPermissionsView(onContinue: {})
}
