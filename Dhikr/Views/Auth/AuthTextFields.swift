//
//  AuthTextFields.swift
//  Dhikr
//
//  Custom text field components for auth
//

import SwiftUI

// MARK: - Custom TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.primaryAccent)
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(theme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Custom Secure Field
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.primaryAccent)
                .frame(width: 24)

            if showPassword {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(theme.primaryText)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(theme.primaryText)
            }

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(theme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 1)
        )
    }
}
