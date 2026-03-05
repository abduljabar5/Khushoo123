//
//  FeedbackSheet.swift
//  Dhikr
//
//  In-app feedback form for collecting feature requests
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var feedbackText = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
    private var softGreen: Color { Color(red: 0.55, green: 0.68, blue: 0.55) }
    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }
    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }
    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var canSend: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(showSuccess ? softGreen.opacity(0.12) : sacredGold.opacity(0.12))
                                    .frame(width: 80, height: 80)

                                Image(systemName: showSuccess ? "checkmark" : "lightbulb.fill")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(showSuccess ? softGreen : sacredGold)
                            }

                            Text(showSuccess ? "Thank You!" : "Share Your Ideas")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text(showSuccess
                                 ? "Your feedback helps us make Khushoo better"
                                 : "What features would you love to see in Khushoo?")
                                .font(.system(size: 14))
                                .foregroundColor(warmGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                        .animation(.easeInOut(duration: 0.3), value: showSuccess)

                        if !showSuccess {
                            // Text input
                            ZStack(alignment: .topLeading) {
                                if feedbackText.isEmpty {
                                    Text("Tell us your ideas, suggestions, or what you'd improve...")
                                        .font(.system(size: 15))
                                        .foregroundColor(warmGray.opacity(0.6))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                }

                                TextEditor(text: $feedbackText)
                                    .font(.system(size: 15))
                                    .foregroundColor(themeManager.theme.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 160)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(warmGray.opacity(0.15), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 24)

                            // Send button
                            Button(action: sendFeedback) {
                                HStack(spacing: 10) {
                                    if isSending {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 14))
                                    }
                                    Text(isSending ? "Sending..." : "Send Feedback")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(canSend ? sacredGold : sacredGold.opacity(0.4))
                                )
                            }
                            .disabled(!canSend)
                            .padding(.horizontal, 24)
                        }

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(warmGray.opacity(0.5))
                    }
                }
            }
            .alert("Couldn't send feedback", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again or email khushooios@gmail.com")
            }
        }
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true

        let data: [String: Any] = [
            "message": trimmed,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": Auth.auth().currentUser?.uid ?? "anonymous",
            "isPremium": SubscriptionService.shared.hasPremiumAccess,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "platform": "iOS"
        ]

        Firestore.firestore().collection("feedback").addDocument(data: data) { error in
            DispatchQueue.main.async {
                isSending = false
                if let error = error {
                    print("Feedback error: \(error.localizedDescription)")
                    showError = true
                } else {
                    AnalyticsService.shared.trackFeedbackSubmitted()
                    withAnimation {
                        showSuccess = true
                    }
                    // Auto-dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
}
