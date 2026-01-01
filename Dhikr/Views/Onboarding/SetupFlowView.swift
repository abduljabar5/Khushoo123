//
//  SetupFlowView.swift
//  Dhikr
//
//  Re-entry flow for Focus Setup and Permissions (accessible from Settings)
//

import SwiftUI

struct SetupFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
    @State private var currentPage = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F8F9FA")
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
                }
            }
        }
    }
}

#Preview {
    SetupFlowView()
        .environmentObject(LocationService())
}
