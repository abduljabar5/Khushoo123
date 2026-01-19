//
//  OnboardingNameView.swift
//  Dhikr
//
//  Name input screen for personalization (Screen 1.5) - Sacred Minimalism redesign
//

import SwiftUI

struct OnboardingNameView: View {
    let onContinue: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool
    @StateObject private var themeManager = ThemeManager.shared

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
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

    // Validation
    private var isNameValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon - Sacred style
            ZStack {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "person.circle")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundColor(sacredGold)
            }
            .padding(.bottom, 40)

            // Title - Sacred typography
            Text("What should we call you?")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(themeManager.theme.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Subtitle
            Text("We'll use your name to personalize your experience")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // Name Input Field - Sacred style
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR NAME")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)
                    .padding(.leading, 4)

                TextField("", text: $name, prompt: Text("Enter your name").foregroundColor(warmGray.opacity(0.6)))
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isNameFieldFocused ? sacredGold.opacity(0.5) : sacredGold.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .focused($isNameFieldFocused)
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .onSubmit {
                        if isNameValid {
                            handleContinue()
                        }
                    }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue Button - Sacred style
            VStack(spacing: 12) {
                Button(action: handleContinue) {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(0.5)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(isNameValid ? (themeManager.effectiveTheme == .dark ? .black : .white) : warmGray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isNameValid ? sacredGold : sacredGold.opacity(0.3))
                    )
                }
                .disabled(!isNameValid)

                // Helper text
                if !name.isEmpty && !isNameValid {
                    Text("Name must be at least 2 characters")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Color(red: 0.85, green: 0.4, blue: 0.4))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(pageBackground)
        .onAppear {
            // Auto-focus the name field for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isNameFieldFocused = true
            }
        }
    }

    private func handleContinue() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNameValid else { return }

        isNameFieldFocused = false
        onContinue(trimmedName)
    }
}

#Preview {
    OnboardingNameView(onContinue: { name in
    })
}
