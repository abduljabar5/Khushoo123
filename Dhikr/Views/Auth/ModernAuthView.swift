//
//  ModernAuthView.swift
//  Dhikr
//
//  Modern unified authentication flow
//

import SwiftUI
import AuthenticationServices

enum AuthMethod {
    case apple
    case google
    case email
    case none
}

struct ModernAuthView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var googleSignInHelper = GoogleSignInHelper()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedMethod: AuthMethod = .none
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                themeManager.theme.primaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 70))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeManager.theme.primaryAccent, themeManager.theme.secondaryAccent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text("Welcome")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("Sign in or create an account to continue")
                                .font(.subheadline)
                                .foregroundColor(themeManager.theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        // Auth Method Buttons
                        if selectedMethod == .none {
                            VStack(spacing: 16) {
                                // Apple Sign In
                                SignInWithAppleButton(.signIn) { request in
                                    let nonce = authService.randomNonceString()
                                    authService.currentNonce = nonce
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = authService.sha256(nonce)
                                } onCompletion: { result in
                                    handleAppleSignIn(result)
                                }
                                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                                .frame(height: 56)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                                // Google Sign In
                                SocialAuthButton(
                                    icon: "g.circle.fill",
                                    title: "Continue with Google",
                                    backgroundColor: .white,
                                    foregroundColor: .black,
                                    borderColor: Color.gray.opacity(0.3)
                                ) {
                                    googleSignInHelper.signIn { idToken, accessToken in
                                        Task {
                                            do {
                                                try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
                                                await MainActor.run { dismiss() }
                                            } catch let error as AuthError {
                                                await MainActor.run {
                                                    errorMessage = error.errorDescription
                                                }
                                            }
                                        }
                                    } onError: { error in
                                        errorMessage = error.localizedDescription
                                    }
                                }

                                // Email Option
                                SocialAuthButton(
                                    icon: "envelope.fill",
                                    title: "Continue with Email",
                                    backgroundColor: themeManager.theme.primaryAccent,
                                    foregroundColor: .white
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMethod = .email
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        // Email Form
                        if selectedMethod == .email {
                            VStack(spacing: 20) {
                                // Back Button
                                HStack {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedMethod = .none
                                            errorMessage = nil
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "chevron.left")
                                            Text("Other options")
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.theme.primaryAccent)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)

                                VStack(spacing: 16) {
                                    // Name Field (shown always for unified flow)
                                    CustomTextField(
                                        icon: "person.fill",
                                        placeholder: "Full Name (required for new accounts)",
                                        text: $displayName,
                                        theme: themeManager.theme
                                    )

                                    CustomTextField(
                                        icon: "envelope.fill",
                                        placeholder: "Email",
                                        text: $email,
                                        keyboardType: .emailAddress,
                                        theme: themeManager.theme
                                    )

                                    CustomSecureField(
                                        icon: "lock.fill",
                                        placeholder: "Password (min. 6 characters)",
                                        text: $password,
                                        showPassword: $showPassword,
                                        theme: themeManager.theme
                                    )
                                }
                                .padding(.horizontal, 24)

                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 24)
                                }

                                // Continue Button
                                Button(action: continueWithEmail) {
                                    HStack(spacing: 12) {
                                        if authService.isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .font(.title3)
                                        }

                                        Text("Continue")
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

                                Text("We'll automatically create an account if you don't have one")
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.tertiaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Account")
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

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                do {
                    try await authService.signInWithApple(authorization: authorization)
                    await MainActor.run { dismiss() }
                } catch let error as AuthError {
                    await MainActor.run {
                        errorMessage = error.errorDescription
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func continueWithEmail() {
        errorMessage = nil

        Task {
            do {
                try await authService.continueWithEmail(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
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

// MARK: - Social Auth Button
struct SocialAuthButton: View {
    let icon: String
    let title: String
    let backgroundColor: Color
    let foregroundColor: Color
    var borderColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernAuthView_Previews: PreviewProvider {
    static var previews: some View {
        ModernAuthView()
            .environmentObject(AuthenticationService.shared)
    }
}
