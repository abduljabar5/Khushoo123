//
//  SignInView.swift
//  Dhikr
//
//  Sign in screen
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

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.theme.primaryAccent, themeManager.theme.secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Sign In")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Welcome back! Sign in to continue")
                        .font(.subheadline)
                        .foregroundColor(themeManager.theme.secondaryText)
                }
                .padding(.top, 40)

                // Form
                VStack(spacing: 16) {
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

                    // Forgot Password
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            showResetPassword = true
                        }
                        .font(.subheadline)
                        .foregroundColor(themeManager.theme.primaryAccent)
                    }
                    .padding(.top, -8)
                }
                .padding(.horizontal, 24)

                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }

                // Sign In Button
                Button(action: signIn) {
                    HStack(spacing: 12) {
                        if authService.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }

                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [themeManager.theme.primaryAccent, themeManager.theme.primaryAccent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: themeManager.theme.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
                .opacity((authService.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()
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
