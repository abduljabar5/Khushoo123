//
//  RequestReciterSheet.swift
//  Dhikr
//
//  User-driven catalog growth: lets people suggest reciters they want to see
//  added. Writes to Firestore reciter_requests collection (write-only from
//  client; console reads weekly to prioritize what to upload to R2 next).
//

import SwiftUI

struct RequestReciterSheet: View {
    /// Optional initial name to prefill — caller can pass the search query that
    /// found nothing, so the user doesn't have to retype it.
    let prefillName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var name: String = ""
    @State private var note: String = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false

    init(prefillName: String = "") {
        self.prefillName = prefillName
    }

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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
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

                                Image(systemName: showSuccess ? "checkmark" : "person.crop.circle.badge.plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(showSuccess ? softGreen : sacredGold)
                            }

                            Text(showSuccess ? "Request Sent" : "Suggest a Reciter")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text(showSuccess
                                 ? "We review requests every week and add the most popular reciters."
                                 : "Who would you love to hear in Khushoo?")
                                .font(.system(size: 14))
                                .foregroundColor(warmGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)
                        .animation(.easeInOut(duration: 0.3), value: showSuccess)

                        if !showSuccess {
                            VStack(alignment: .leading, spacing: 16) {
                                // Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("RECITER NAME")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1)
                                        .foregroundColor(warmGray)

                                    TextField("e.g. Khalid Al-Jaleel", text: $name)
                                        .font(.system(size: 15))
                                        .foregroundColor(themeManager.theme.primaryText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(cardBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(warmGray.opacity(0.15), lineWidth: 1)
                                                )
                                        )
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.words)
                                }

                                // Optional note
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("NOTES (OPTIONAL)")
                                        .font(.system(size: 11, weight: .medium))
                                        .tracking(1)
                                        .foregroundColor(warmGray)

                                    ZStack(alignment: .topLeading) {
                                        if note.isEmpty {
                                            Text("Riwayah, country, or where you heard them")
                                                .font(.system(size: 14))
                                                .foregroundColor(warmGray.opacity(0.6))
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 16)
                                        }

                                        TextEditor(text: $note)
                                            .font(.system(size: 14))
                                            .foregroundColor(themeManager.theme.primaryText)
                                            .scrollContentBackground(.hidden)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .frame(minHeight: 100)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(cardBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(warmGray.opacity(0.15), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 24)

                            // Send button
                            Button(action: sendRequest) {
                                HStack(spacing: 10) {
                                    if isSending {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 14))
                                    }
                                    Text(isSending ? "Sending..." : "Submit Request")
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
            .alert("Couldn't send request", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please try again or email khushooios@gmail.com")
            }
            .onAppear {
                if name.isEmpty && !prefillName.isEmpty {
                    name = prefillName
                }
            }
        }
    }

    private func sendRequest() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSending = true

        Task {
            do {
                try await ReciterRequestService.shared.submitRequest(
                    name: trimmedName,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                isSending = false
                withAnimation { showSuccess = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    dismiss()
                }
            } catch {
                isSending = false
                showError = true
            }
        }
    }
}
