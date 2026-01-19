//
//  SignUpView.swift
//  Dhikr
//
//  Sacred Minimalism sign up screen
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

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
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

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(cardBackground)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(softGreen.opacity(0.4), lineWidth: 1)
                                )

                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 30, weight: .ultraLight))
                                .foregroundColor(softGreen)
                        }

                        VStack(spacing: 8) {
                            Text("BEGIN YOUR JOURNEY")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(2)
                                .foregroundColor(subtleText)

                            Text("Create Account")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)
                        }
                    }
                    .padding(.top, 32)

                    // Form
                    VStack(spacing: 14) {
                        CustomTextField(
                            icon: "person",
                            placeholder: "Full Name",
                            text: $displayName,
                            theme: themeManager.theme
                        )

                        CustomTextField(
                            icon: "envelope",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            theme: themeManager.theme
                        )

                        CustomSecureField(
                            icon: "lock",
                            placeholder: "Password",
                            text: $password,
                            showPassword: $showPassword,
                            theme: themeManager.theme
                        )

                        CustomSecureField(
                            icon: "lock",
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            showPassword: $showPassword,
                            theme: themeManager.theme
                        )

                        // Password hint
                        Text("Password must be at least 6 characters")
                            .font(.system(size: 12))
                            .foregroundColor(subtleText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 24)
                    }

                    // Create Account Button
                    Button(action: signUp) {
                        HStack(spacing: 12) {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(softGreen)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authService.isLoading || !isFormValid)
                    .opacity((authService.isLoading || !isFormValid) ? 0.5 : 1.0)
                    .padding(.horizontal, 24)

                    Spacer()
                }
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
