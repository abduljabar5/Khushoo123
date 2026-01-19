//
//  ModernAuthView.swift
//  Dhikr
//
//  Sacred Minimalism unified authentication flow
//

import SwiftUI
import AuthenticationServices

// Sacred colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

enum AuthMethod {
    case apple
    case email
    case none
}

struct ModernAuthView: View {
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("userDisplayName") private var userDisplayName: String = ""

    @State private var selectedMethod: AuthMethod = .none
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var showPassword = false
    @State private var errorMessage: String?

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
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(cardBackground)
                                    .frame(width: 90, height: 90)
                                    .overlay(
                                        Circle()
                                            .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                                    )

                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 40, weight: .ultraLight))
                                    .foregroundColor(sacredGold)
                            }

                            VStack(spacing: 8) {
                                Text("WELCOME")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(3)
                                    .foregroundColor(subtleText)

                                Text("Sign In")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundColor(themeManager.theme.primaryText)

                                Text("Sign in or create an account to continue")
                                    .font(.system(size: 13))
                                    .foregroundColor(subtleText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 40)

                        // Auth Method Buttons
                        if selectedMethod == .none {
                            VStack(spacing: 14) {
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
                                .frame(height: 52)
                                .cornerRadius(12)

                                // Email Option
                                SacredAuthButton(
                                    icon: "envelope",
                                    title: "Continue with Email",
                                    accentColor: sacredGold,
                                    cardBackground: cardBackground
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
                                        HStack(spacing: 6) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 12, weight: .medium))
                                            Text("Other options")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundColor(sacredGold)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)

                                VStack(spacing: 14) {
                                    CustomTextField(
                                        icon: "person",
                                        placeholder: "Full Name (required for new accounts)",
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
                                        placeholder: "Password (min. 6 characters)",
                                        text: $password,
                                        showPassword: $showPassword,
                                        theme: themeManager.theme
                                    )
                                }
                                .padding(.horizontal, 24)

                                if let errorMessage = errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                                        .padding(.horizontal, 24)
                                }

                                // Continue Button
                                Button(action: continueWithEmail) {
                                    HStack(spacing: 10) {
                                        if authService.isLoading {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Text("Continue")
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

                                Text("We'll automatically create an account if you don't have one")
                                    .font(.system(size: 11))
                                    .foregroundColor(subtleText)
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
                    .font(.system(size: 15))
                    .foregroundColor(sacredGold)
                }
            }
            .onAppear {
                if !userDisplayName.isEmpty && displayName.isEmpty {
                    displayName = userDisplayName
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

// MARK: - Sacred Auth Button
struct SacredAuthButton: View {
    let icon: String
    let title: String
    let accentColor: Color
    let cardBackground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))

                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(cardBackground)
            .foregroundColor(accentColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentColor.opacity(0.3), lineWidth: 1)
            )
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
