import SwiftUI

struct VoiceConfirmationView: View {
    @StateObject private var speechService = SpeechRecognitionService()
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
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: blockingState.isWaitingForVoiceConfirmation ? "Voice Confirmation Required" : "Prayer Time Active - Strict Mode", icon: "lock.fill", theme: theme)
                
                VStack(spacing: 16) {
                    // Prayer info with countdown
                    HStack {
                        Image(systemName: prayerIcon(for: blockingState.currentPrayerName))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(blockingState.currentPrayerName) Prayer Time")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                if timeRemaining > 0 {
                                    Text(timeRemaining.formattedForCountdown)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.orange)
                                        .monospacedDigit()
                                }
                            }
                            Text(blockingState.isWaitingForVoiceConfirmation ? "Apps blocked - Voice confirmation required" : "Apps are currently blocked")
                                .font(.subheadline)
                                .foregroundColor(theme.secondaryText)
                        }
                        Spacer()
                    }
                    
                    // Voice confirmation section
                    VStack(spacing: 12) {
                        // Say Wallahi button
                        Button(action: {
                            if timeRemaining <= 0 {
                                if speechService.isRecording {
                                    speechService.stopRecording()
                                } else {
                                    speechService.startRecording()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title2)
                                Text(speechService.isRecording ? "Stop Recording" : "Say Wallahi")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(timeRemaining > 0 ? theme.tertiaryText : theme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(timeRemaining > 0 ? Color.gray.opacity(0.3) : (speechService.isRecording ? Color.red : Color.blue))
                            .cornerRadius(12)
                        }
                        .disabled(timeRemaining > 0 || !speechService.hasPermissions)
                        
                        if timeRemaining > 0 {
                            Text("When the timer ends, press the button above to unlock your apps.")
                                .font(.subheadline)
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                        } else {
                            VStack(spacing: 8) {
                                Text("Prayer time has ended. Press the button above and say one of these phrases: 'Wallahi I prayed'")
                                    .font(.subheadline)
                                    .foregroundColor(theme.secondaryText)
                                    .multilineTextAlignment(.center)
                                
                                // VStack(spacing: 4) {
                                //     Text("\"Wallahi I prayed\"")
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.orange)
                                //     Text("\"Wallah I prayed\"")
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.orange)
                                //     Text("\"Walhi I prayed\"")
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.orange)
                                //     Text("\"Walha I prayed\"")
                                //         .font(.caption)
                                //         .fontWeight(.medium)
                                //         .foregroundColor(.orange)
                                // }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        
                        // Show transcript when recording
                        if !speechService.transcript.isEmpty && timeRemaining <= 0 {
                            Text("You said: \"\(speechService.transcript)\"")
                                .font(.body)
                                .italic()
                                .foregroundColor(speechService.isConfirmationCorrect ? theme.accentGreen : theme.primaryText)
                                .padding()
                                .background(theme.tertiaryBackground)
                                .cornerRadius(8)
                        }
                        
                        // Unlock button (appears when phrase is correct)
                        if speechService.isConfirmationCorrect && timeRemaining <= 0 {
                            Button(action: {
                                blockingState.clearBlocking()
                                speechService.stopRecording()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Unlock Apps")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.accentGreen)
                                .cornerRadius(12)
                            }
                        }
                        
                        // Permission error
                        if !speechService.hasPermissions {
                            VStack(spacing: 8) {
                                Text("Microphone permission required")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Button("Open Settings") {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(theme.primaryAccent)
                            }
                        }
                    }
                }
                .padding()
                .background(theme.cardBackground)
                .cornerRadius(12)
            }
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