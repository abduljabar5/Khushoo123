//
//  VoiceConfirmationView.swift
//  Dhikr
//
//  Sacred Minimalism redesign
//

import SwiftUI

struct VoiceConfirmationView: View {
    @EnvironmentObject var speechService: SpeechRecognitionService
    @ObservedObject var blockingState: BlockingStateService
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("focusStrictMode") private var strictMode = false

    @State private var showingConfirmation = false
    @State private var countdownTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var mutedPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        let shouldShow = strictMode && (blockingState.appsActuallyBlocked || blockingState.isWaitingForVoiceConfirmation)

        if shouldShow {
            VStack(spacing: 28) {
                // Header Icon
                ZStack {
                    Circle()
                        .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(sacredGold.opacity(0.1))
                        .frame(width: 72, height: 72)

                    Image(systemName: prayerIcon(for: blockingState.currentPrayerName))
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(sacredGold)
                }

                // Prayer Info
                VStack(spacing: 12) {
                    Text("STRICT MODE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .foregroundColor(warmGray)

                    Text("\(blockingState.currentPrayerName) Prayer")
                        .font(.system(size: 22, weight: .light, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    if timeRemaining > 0 {
                        Text(timeRemaining.formattedForCountdown)
                            .font(.system(size: 36, weight: .ultraLight))
                            .monospacedDigit()
                            .foregroundColor(sacredGold)
                    }

                    Text("Apps are blocked until prayer is confirmed")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .multilineTextAlignment(.center)
                }

                // Divider
                Rectangle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // Voice Confirmation Section
                VStack(spacing: 16) {
                    Text("VOICE CONFIRMATION")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .foregroundColor(warmGray)

                    // Record Button
                    Button(action: {
                        if timeRemaining <= 0 {
                            HapticManager.shared.impact(.medium)
                            if !speechService.hasPermissions {
                                speechService.requestPermissions()
                            } else {
                                if speechService.isRecording {
                                    speechService.stopRecording()
                                } else {
                                    speechService.startRecording()
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(buttonColor.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: speechService.isRecording ? "stop.fill" : "mic")
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(buttonColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(buttonTitle)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(themeManager.theme.primaryText)

                                Text(buttonSubtitle)
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(themeManager.theme.secondaryText)
                            }

                            Spacer()

                            if timeRemaining <= 0 && !speechService.isRecording {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(warmGray)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(buttonColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .disabled(timeRemaining > 0)
                    .opacity(timeRemaining > 0 ? 0.6 : 1)

                    // Transcript Display
                    if !speechService.transcript.isEmpty && timeRemaining <= 0 {
                        VStack(spacing: 8) {
                            Text("You said:")
                                .font(.system(size: 11, weight: .medium))
                                .tracking(1)
                                .foregroundColor(warmGray)

                            Text("\"\(speechService.transcript)\"")
                                .font(.system(size: 15, weight: .light, design: .serif))
                                .italic()
                                .foregroundColor(speechService.isConfirmationCorrect ? softGreen : themeManager.theme.primaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(speechService.isConfirmationCorrect ? softGreen.opacity(0.1) : cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(speechService.isConfirmationCorrect ? softGreen.opacity(0.3) : sacredGold.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }

                    // Unlock Button
                    if speechService.isConfirmationCorrect && timeRemaining <= 0 {
                        Button(action: {
                            HapticManager.shared.notification(.success)
                            blockingState.clearBlocking()
                            speechService.stopRecording()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 16, weight: .light))
                                Text("Unlock Apps")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(themeManager.effectiveTheme == .dark ? Color.black : Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(softGreen)
                            )
                        }
                    }

                    // Permission Warning
                    if !speechService.hasPermissions && timeRemaining <= 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.8))

                            Text("Microphone permission required")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(themeManager.theme.secondaryText)

                            Spacer()

                            Button("Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(sacredGold)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .onAppear {
                startCountdown()
            }
            .onDisappear {
                stopCountdown()
                speechService.stopRecording()
            }
        }
    }

    private var buttonColor: Color {
        if timeRemaining > 0 {
            return warmGray
        } else if speechService.isRecording {
            return .red
        } else {
            return sacredGold
        }
    }

    private var buttonTitle: String {
        if timeRemaining > 0 {
            return "Voice Confirmation"
        } else if speechService.isRecording {
            return "Recording..."
        } else {
            return "Say Wallahi"
        }
    }

    private var buttonSubtitle: String {
        if timeRemaining > 0 {
            return "Available when timer ends"
        } else if speechService.isRecording {
            return "Say: \"Wallahi I prayed\""
        } else {
            return "Tap to start recording"
        }
    }

    private func prayerIcon(for prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "sunrise"
        case "Dhuhr": return "sun.max"
        case "Asr": return "sun.haze"
        case "Maghrib": return "sunset"
        case "Isha": return "moon.stars"
        default: return "sparkles"
        }
    }

    private func startCountdown() {
        updateTimeRemaining()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeRemaining()
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateTimeRemaining() {
        if let endTime = blockingState.blockingEndTime {
            timeRemaining = max(0, endTime.timeIntervalSince(Date()))
        } else {
            timeRemaining = 0
        }
    }
}

#Preview {
    VoiceConfirmationView(blockingState: BlockingStateService.shared)
}
