//
//  AuthenticationView.swift
//  Dhikr
//
//  Main authentication container with tabs
//

import SwiftUI

struct AuthenticationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                themeManager.theme.primaryBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom Tab Selector
                    HStack(spacing: 0) {
                        TabButton(
                            title: "Sign In",
                            isSelected: selectedTab == 0,
                            theme: themeManager.theme
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = 0
                            }
                        }

                        TabButton(
                            title: "Sign Up",
                            isSelected: selectedTab == 1,
                            theme: themeManager.theme
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTab = 1
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Content
                    TabView(selection: $selectedTab) {
                        SignInView()
                            .tag(0)

                        SignUpView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.theme.primaryAccent)
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? theme.primaryAccent : theme.secondaryText)

                Rectangle()
                    .fill(isSelected ? theme.primaryAccent : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
