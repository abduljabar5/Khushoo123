//
//  OnboardingFlowView.swift
//  Dhikr
//
//  Single-screen onboarding: Location permission only - Sacred Minimalism
//

import SwiftUI
import CoreLocation

struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var locationService = LocationService()
    @StateObject private var themeManager = ThemeManager.shared

    @State private var isRequestingLocation = false
    @State private var showLocationDeniedAlert = false

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

    private var hasLocationPermission: Bool {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    private var isLocationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
    }

    init(compact: Bool = false) {
        // compact parameter kept for compatibility but unused
    }

    var body: some View {
        ZStack {
            pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Icon - Sacred style
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "moon.stars")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }
                .padding(.bottom, 40)

                // Title - Sacred typography
                Text("Khushoo")
                    .font(.system(size: 40, weight: .ultraLight, design: .serif))
                    .foregroundColor(themeManager.theme.primaryText)
                    .padding(.bottom, 8)

                Text("SPIRITUAL COMPANION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(3)
                    .foregroundColor(warmGray)
                    .padding(.bottom, 48)

                // Location Permission Card
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(sacredGold.opacity(0.12))
                                .frame(width: 48, height: 48)

                            Image(systemName: "location.circle")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(sacredGold)
                        }

                        // Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location Access")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("Required for accurate prayer times")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(warmGray)
                        }

                        Spacer()

                        // Status
                        if hasLocationPermission {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(softGreen)
                                Text("Enabled")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(softGreen)
                            }
                        } else if isRequestingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: sacredGold))
                                .frame(width: 70, height: 32)
                        } else {
                            Button(action: requestLocation) {
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
                .padding(.horizontal, 32)

                Spacer()

                // Continue Button - Sacred style
                Button(action: {
                    if hasLocationPermission {
                        completeOnboarding()
                    } else {
                        requestLocation()
                    }
                }) {
                    Text(hasLocationPermission ? "Continue" : "Enable Location")
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
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onChange(of: locationService.authorizationStatus) { newStatus in
            isRequestingLocation = false
            if newStatus == .denied || newStatus == .restricted {
                showLocationDeniedAlert = true
            }
        }
        .alert("Location Access Denied", isPresented: $showLocationDeniedAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location permission is required for accurate prayer times. Please enable it in Settings.")
        }
        .onAppear {
            print("📱 [Onboarding] OnboardingFlowView appeared - location permission flow")
        }
    }

    private func requestLocation() {
        if isLocationDenied {
            showLocationDeniedAlert = true
        } else {
            isRequestingLocation = true
            locationService.requestLocationPermission()
        }
    }

    private func completeOnboarding() {
        print("🎉 [Onboarding] completeOnboarding() called")
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingFlowView()
}
