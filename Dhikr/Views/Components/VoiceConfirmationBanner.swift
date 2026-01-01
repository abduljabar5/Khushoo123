import SwiftUI

struct VoiceConfirmationBanner: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var isDismissed = false
    @Binding var selectedTab: Int
    @AppStorage("focusStrictMode") private var strictMode = false

    var body: some View {
        if !isDismissed && strictMode && blocking.isWaitingForVoiceConfirmation {
            let timeRemaining = blocking.blockingEndTime.map { max(0, $0.timeIntervalSince(Date())) } ?? 0

            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: timeRemaining > 0 ? "hourglass" : "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Notification Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("KUSHOO")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.theme.secondaryText)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.theme.secondaryText.opacity(0.5))

                        Text("now")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.theme.secondaryText)

                        Spacer()
                    }

                    if timeRemaining > 0 {
                        Text("Prayer Time Active")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Voice confirmation in \(timeRemaining.formattedForCountdown)")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                    } else {
                        Text("Voice Confirmation Required")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Tap to confirm prayer completion")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Action Button
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Group {
                    if themeManager.theme.hasGlassEffect {
                        // Enhanced liquid glass effect for iOS 26+
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .glassEffect(.clear, in: .rect(cornerRadius: 16))
                                .shadow(color: themeManager.theme.shadowColor, radius: 12, x: 0, y: 4)
                        } else {
                            // Fallback for older iOS versions
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: themeManager.theme.shadowColor, radius: 12, x: 0, y: 4)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.theme.cardBackground)
                            .shadow(color: themeManager.theme.shadowColor, radius: 12, x: 0, y: 4)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        themeManager.theme.hasGlassEffect ?
                        Color.white.opacity(0.2) :
                        Color.clear,
                        lineWidth: 1
                    )
            )
            .offset(y: offset)
            .opacity(1 - (abs(offset) / 100.0))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow upward swipe
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height < -50 {
                            // Dismiss if swiped up more than 50 points
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -200
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isDismissed = true
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                // Navigate to Focus tab (index 3)
                withAnimation {
                    selectedTab = 3
                }
                // Reset dismiss state after navigation
                isDismissed = false
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VoiceConfirmationBanner(selectedTab: .constant(0))
}
