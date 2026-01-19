//
//  AuthTextFields.swift
//  Dhikr
//
//  Sacred Minimalism text field components for auth
//

import SwiftUI

// MARK: - Sacred Colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)
private let darkCardBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
private let darkPageBackground = Color(red: 0.08, green: 0.09, blue: 0.11)

// MARK: - Sacred TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    let theme: AppTheme

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardBackground: Color {
        isDarkMode ? darkCardBackground : Color.white
    }

    private var subtleText: Color {
        isDarkMode ? Color(white: 0.5) : Color(white: 0.45)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(isFocused ? sacredGold : subtleText)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(theme.primaryText)
                .font(.system(size: 15))
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? sacredGold.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Sacred Secure Field
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    let theme: AppTheme

    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardBackground: Color {
        isDarkMode ? darkCardBackground : Color.white
    }

    private var subtleText: Color {
        isDarkMode ? Color(white: 0.5) : Color(white: 0.45)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(isFocused ? sacredGold : subtleText)
                .frame(width: 20)

            if showPassword {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundColor(theme.primaryText)
                    .font(.system(size: 15))
                    .focused($isFocused)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(theme.primaryText)
                    .font(.system(size: 15))
                    .focused($isFocused)
            }

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(subtleText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? sacredGold.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
