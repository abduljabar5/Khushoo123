import SwiftUI

/// Banner that shows scheduling progress and completion status
/// Displays while app blocking is being set up in the background after onboarding
struct SchedulingProgressBanner: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var isDismissed = false
    @Binding var selectedTab: Int

    var body: some View {
        // Show when scheduling is in progress OR just completed (not dismissed)
        if !isDismissed && (blocking.isSchedulingBlocking || blocking.schedulingDidComplete) {
            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: blocking.schedulingDidComplete
                                    ? [Color.green, Color.green.opacity(0.8)]
                                    : [themeManager.theme.prayerGradientStart, themeManager.theme.prayerGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    if blocking.schedulingDidComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }

                // Notification Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("DHIKR")
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

                    if blocking.schedulingDidComplete {
                        Text("Prayer Blocking Ready")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Your apps will be blocked during prayers")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .lineLimit(1)
                    } else {
                        Text("Setting Up Prayer Blocking")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Fetching prayer times...")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Chevron for tap action (only when complete)
                if blocking.schedulingDidComplete {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
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
                // Navigate to Focus tab when completed
                if blocking.schedulingDidComplete {
                    withAnimation {
                        selectedTab = 3
                    }
                    isDismissed = true
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onChange(of: blocking.schedulingDidComplete) { completed in
                // Auto-dismiss after 5 seconds when scheduling completes
                if completed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDismissed = true
                        }
                    }
                }
            }
            .onChange(of: blocking.isSchedulingBlocking) { isScheduling in
                // Reset dismiss state when scheduling starts again
                if isScheduling {
                    isDismissed = false
                    offset = 0
                }
            }
        }
    }
}

#Preview {
    SchedulingProgressBanner(selectedTab: .constant(0))
}
