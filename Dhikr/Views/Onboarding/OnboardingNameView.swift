//
//  OnboardingNameView.swift
//  Dhikr
//
//  Name input screen for personalization (Screen 1.5)
//

import SwiftUI

struct OnboardingNameView: View {
    let onContinue: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    // Validation
    private var isNameValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 32)

            // Title
            Text("What should we call you?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "2C3E50"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Subtitle
            Text("We'll use your name to personalize your experience")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(hex: "7F8C8D"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // Name Input Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Name")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "2C3E50"))
                    .padding(.leading, 4)

                TextField("Enter your name", text: $name)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "2C3E50"))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isNameFieldFocused ? Color(hex: "1A9B8A") : Color.clear,
                                lineWidth: 2
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

            // Continue Button
            VStack(spacing: 12) {
                Button(action: handleContinue) {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                isNameValid
                                    ? LinearGradient(
                                        colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [Color(hex: "BDC3C7"), Color(hex: "95A5A6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                            )
                    )
                }
                .disabled(!isNameValid)

                // Helper text
                if !name.isEmpty && !isNameValid {
                    Text("Name must be at least 2 characters")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "E74C3C"))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(hex: "F8F9FA"))
        .onAppear {
            // Auto-focus the name field for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isNameFieldFocused = true
            }
            print("[Onboarding] Name screen shown")
        }
    }

    private func handleContinue() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNameValid else { return }

        print("[Onboarding] Name - Continue tapped with name: \(trimmedName)")
        isNameFieldFocused = false
        onContinue(trimmedName)
    }
}

#Preview {
    OnboardingNameView(onContinue: { name in
        print("Name: \(name)")
    })
}
