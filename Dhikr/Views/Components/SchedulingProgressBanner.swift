import SwiftUI

// Sacred colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

/// Banner that shows scheduling progress and completion status
/// Displays while app blocking is being set up in the background after onboarding
struct SchedulingProgressBanner: View {
    @StateObject private var blocking = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var offset: CGFloat = 0
    @State private var isDismissed = false
    @Binding var selectedTab: Int

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    var body: some View {
        // Show when scheduling is in progress OR just completed (not dismissed)
        if !isDismissed && (blocking.isSchedulingBlocking || blocking.schedulingDidComplete) {
            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(blocking.schedulingDidComplete ? softGreen : sacredGold)
                        .frame(width: 44, height: 44)

                    if blocking.schedulingDidComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                }

                // Notification Content
                VStack(alignment: .leading, spacing: 3) {
                    Text("DHIKR")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(subtleText)

                    if blocking.schedulingDidComplete {
                        Text("Prayer Blocking Ready")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Your apps will be blocked during prayers")
                            .font(.system(size: 12))
                            .foregroundColor(subtleText)
                            .lineLimit(1)
                    } else {
                        Text("Setting Up Prayer Blocking")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Fetching prayer times...")
                            .font(.system(size: 12))
                            .foregroundColor(subtleText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Chevron for tap action (only when complete)
                if blocking.schedulingDidComplete {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(subtleText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
