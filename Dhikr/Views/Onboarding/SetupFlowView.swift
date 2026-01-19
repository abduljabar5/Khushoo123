//
//  SetupFlowView.swift
//  Dhikr
//
//  Re-entry flow for Focus Setup and Permissions (accessible from Settings) - Sacred Minimalism redesign
//

import SwiftUI

struct SetupFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var currentPage = 0

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground
                    .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    // Focus Setup
                    OnboardingFocusSetupView(
                        onContinue: { currentPage = 1 }
                    )
                    .tag(0)

                    // Permissions
                    OnboardingPermissionsView(onContinue: {
                        dismiss()
                    })
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .navigationTitle("Setup & Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(sacredGold)
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }
}

#Preview {
    SetupFlowView()
        .environmentObject(LocationService())
}
