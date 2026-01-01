import SwiftUI

struct VoiceConfirmationView: View {
    @EnvironmentObject var speechService: SpeechRecognitionService
    @ObservedObject var blockingState: BlockingStateService
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("focusStrictMode") private var strictMode = false

    private var theme: AppTheme { themeManager.theme }
    
    @State private var showingConfirmation = false
    @State private var countdownTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    
    var body: some View {
        let shouldShow = strictMode && (blockingState.isCurrentlyBlocking || blockingState.isWaitingForVoiceConfirmation)
        
        // Silenced: visibility debug logging
        
        if shouldShow {
            VStack(alignment: .leading, spacing: 16) {
                // Header with lock icon
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("Prayer Time Active - Strict Mode")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                // Prayer info with countdown
                HStack(spacing: 12) {
                    Image(systemName: prayerIcon(for: blockingState.currentPrayerName))
                        .font(.system(size: 24))
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("\(blockingState.currentPrayerName) Prayer Time")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            if timeRemaining > 0 {
                                Text(timeRemaining.formattedForCountdown)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.orange)
                                    .monospacedDigit()
                            }
                        }

                        Text("Apps are currently blocked")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()
                }
                    
                // Voice confirmation section
                VStack(spacing: 12) {
                    // Say Wallahi button
                    Button(action: {
                        if timeRemaining <= 0 {
                            // Check if permission is granted
                            if !speechService.hasPermissions {
                                // Request microphone permission
                                speechService.requestPermissions()
                            } else {
                                // Permission already granted, start/stop recording
                                if speechService.isRecording {
                                    speechService.stopRecording()
                                } else {
                                    speechService.startRecording()
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 18))
                            Text(speechService.isRecording ? "Stop Recording" : "Say Wallahi")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                if timeRemaining > 0 {
                                    Color.gray.opacity(0.3)
                                } else if speechService.isRecording {
                                    Color.red
                                } else {
                                    // Green accent when countdown is finished and ready to record
                                    theme.accentGreen
                                }
                            }
                        )
                        .cornerRadius(10)
                    }
                    .disabled(timeRemaining > 0)
                        
                    if timeRemaining > 0 {
                        Text("When the timer ends, press the button above to unlock your apps.")
                            .font(.system(size: 14))
                            .foregroundColor(theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                        
                    // Show transcript when recording
                    if !speechService.transcript.isEmpty && timeRemaining <= 0 {
                        Text("You said: \"\(speechService.transcript)\"")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(speechService.isConfirmationCorrect ? theme.accentGreen : theme.primaryText)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(theme.tertiaryBackground)
                            .cornerRadius(8)
                    }

                    // Unlock button (appears when phrase is correct)
                    if speechService.isConfirmationCorrect && timeRemaining <= 0 {
                        Button(action: {
                            blockingState.clearBlocking()
                            speechService.stopRecording()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Unlock Apps")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accentGreen)
                            .cornerRadius(10)
                        }
                    }

                    // Permission message (informational, not error)
                    if !speechService.hasPermissions && timeRemaining <= 0 {
                        HStack(spacing: 8) {
                            Text("Microphone permission required")
                                .font(.system(size: 13))
                                .foregroundColor(.red)

                            Spacer()

                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(theme.primaryAccent)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.17, green: 0.18, blue: 0.20)) // Match the gray UI background
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .onAppear {
                startCountdown()
            }
            .onDisappear {
                stopCountdown()
                speechService.stopRecording()
            }
        }
    }
    
    private func prayerIcon(for prayerName: String) -> String {
        switch prayerName {
        case "Fajr": return "sun.haze.fill"
        case "Dhuhr": return "sun.max.fill"
        case "Asr": return "cloud.sun.fill"
        case "Maghrib": return "moon.fill"
        case "Isha": return "moon.stars.fill"
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

private struct SectionHeader: View {
    let title: String
    let icon: String
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.primaryText)
        }
    }
}

#Preview {
    VoiceConfirmationView(blockingState: BlockingStateService.shared)
} 