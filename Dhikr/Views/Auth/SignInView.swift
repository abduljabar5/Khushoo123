//
//  SignInView.swift
//  Dhikr
//
//  Sacred Minimalism sign in screen
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
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
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(cardBackground)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                                )

                            Image(systemName: "person")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(sacredGold)
                        }

                        VStack(spacing: 8) {
                            Text("WELCOME BACK")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(2)
                                .foregroundColor(subtleText)

                            Text("Sign In")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)
                        }
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
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

                        // Forgot Password
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showResetPassword = true
                            }
                            .font(.system(size: 13))
                            .foregroundColor(sacredGold)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                            .padding(.horizontal, 24)
                    }

                    // Sign In Button
                    Button(action: signIn) {
                        HStack(spacing: 12) {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(sacredGold)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                    .opacity((authService.isLoading || email.isEmpty || password.isEmpty) ? 0.5 : 1.0)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .alert("Reset Password", isPresented: $showResetPassword) {
            TextField("Email", text: $resetEmail)
            Button("Cancel", role: .cancel) {}
            Button("Send Reset Link") {
                resetPassword()
            }
        } message: {
            Text("Enter your email to receive a password reset link")
        }
        .alert("Success", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset link sent to \(resetEmail)")
        }
    }

    private func signIn() {
        errorMessage = nil

        Task {
            do {
                try await authService.signIn(email: email, password: password)
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

    private func resetPassword() {
        Task {
            do {
                try await authService.resetPassword(email: resetEmail)
                await MainActor.run {
                    showResetSuccess = true
                    resetEmail = ""
                }
            } catch let error as AuthError {
                await MainActor.run {
                    errorMessage = error.errorDescription
                }
            }
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(AuthenticationService.shared)
    }
}
