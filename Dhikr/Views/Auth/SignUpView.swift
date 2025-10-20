//
//  SignUpView.swift
//  Dhikr
//
//  Sign up screen
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.theme.accentGreen, themeManager.theme.accentTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Create Account")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Join us and start your spiritual journey")
                        .font(.subheadline)
                        .foregroundColor(themeManager.theme.secondaryText)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
                    // Name Field
                    CustomTextField(
                        icon: "person.fill",
                        placeholder: "Full Name",
                        text: $displayName,
                        theme: themeManager.theme
                    )

                    // Email Field
                    CustomTextField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        keyboardType: .emailAddress,
                        theme: themeManager.theme
                    )

                    // Password Field
                    CustomSecureField(
                        icon: "lock.fill",
                        placeholder: "Password",
                        text: $password,
                        showPassword: $showPassword,
                        theme: themeManager.theme
                    )

                    // Confirm Password Field
                    CustomSecureField(
                        icon: "lock.fill",
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        showPassword: $showPassword,
                        theme: themeManager.theme
                    )

                    // Password Requirements
                    Text("Password must be at least 6 characters")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)

                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Sign Up Button
                Button(action: signUp) {
                    HStack(spacing: 12) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }

                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [themeManager.theme.accentGreen, themeManager.theme.accentTeal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: themeManager.theme.accentGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(authService.isLoading || !isFormValid)
                .opacity((authService.isLoading || !isFormValid) ? 0.6 : 1.0)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
            }
        }
    }

    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }

    private func signUp() {
        errorMessage = nil

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        Task {
            do {
                try await authService.signUp(email: email, password: password, displayName: displayName)
                await MainActor.run {
                    dismiss()
                }
            } catch let error as AuthError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    errorMessage = "An unexpected error occurred"
                }
            }
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthenticationService.shared)
    }
}
