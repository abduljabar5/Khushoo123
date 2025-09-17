import SwiftUI
import CoreLocation

struct PrayerTimeView: View {
    @StateObject private var viewModel = PrayerTimeViewModel()
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedPrayer: String? = nil
    @State private var animateProgress = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            backgroundView

            ScrollView {
                VStack(spacing: 20) {
                    locationHeader
                    nextPrayerCard
                    progressSection
                    prayerScheduleList
                    footerInfo
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Background View
    private var backgroundView: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                LiquidGlassBackgroundView(
                    backgroundType: themeManager.liquidGlassBackground,
                    backgroundImageURL: themeManager.selectedBackgroundImageURL
                )
            } else {
                theme.primaryBackground
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Location Header
    private var locationHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text(viewModel.cityName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Text("•")
                    .foregroundColor(theme.tertiaryText)

                Text(viewModel.countryName)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(theme.secondaryText)

                Spacer()

                Button(action: {
                    viewModel.refreshLocation()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.primaryAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                theme.hasGlassEffect ?
                AnyView(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                ) :
                AnyView(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor, radius: 5)
                )
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Next Prayer Card
    private var nextPrayerCard: some View {
        VStack(spacing: 0) {
            if let nextPrayer = viewModel.nextPrayer {
                VStack(spacing: 16) {
                    // Prayer Name
                    Text(nextPrayer.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    // Prayer Time
                    Text(nextPrayer.time)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    // Countdown
                    HStack(spacing: 8) {
                        Text("Starts in \(viewModel.timeUntilNextPrayer)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if theme.hasGlassEffect {
                            // Liquid Glass theme - darker teal/cyan gradient matching the image
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        Color(hex: "006B6B"),  // Dark teal
                                        Color(hex: "008B8B"),  // Dark cyan
                                        Color(hex: "00A5A5")   // Medium teal
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                // Subtle glass overlay
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            }
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        } else {
                            // Light/Dark theme - original gradient
                            ZStack {
                                LinearGradient(
                                    colors: [
                                        theme.prayerGradientStart,
                                        theme.prayerGradientEnd
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )

                                // Decorative elements for non-glass themes
                                GeometryReader { geometry in
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 100
                                            )
                                        )
                                        .frame(width: 200, height: 200)
                                        .offset(x: -50, y: -50)
                                        .blur(radius: 40)

                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    theme.accentGold.opacity(0.3),
                                                    Color.clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 80
                                            )
                                        )
                                        .frame(width: 150, height: 150)
                                        .offset(x: geometry.size.width - 80, y: geometry.size.height - 80)
                                        .blur(radius: 30)
                                }
                            }
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                )
                .shadow(color: theme.shadowColor.opacity(0.5), radius: 20, x: 0, y: 10)
            }
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        HStack(spacing: 24) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(theme.tertiaryBackground, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: animateProgress ? viewModel.progressPercentage : 0)
                    .stroke(
                        LinearGradient(
                            colors: [theme.accentGreen, theme.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animateProgress)

                VStack(spacing: 2) {
                    Text("\(viewModel.completedPrayers)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)
                    Text("of \(viewModel.totalPrayers)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }
            }

            // Streak Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(theme.accentGold)

                    Text("Current Streak")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }

                Text("\(viewModel.currentStreak) days")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Text("Best: \(viewModel.bestStreak) days")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()
        }
        .padding(20)
        .background(
            theme.hasGlassEffect ?
            AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)
            ) :
            AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.shadowColor, radius: 10)
            )
        )
    }

    // MARK: - Prayer Schedule List
    private var prayerScheduleList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.prayers, id: \.name) { prayer in
                PrayerRowView(
                    prayer: prayer,
                    isActive: prayer.name == viewModel.currentPrayer?.name,
                    theme: theme,
                    onToggleReminder: {
                        viewModel.toggleReminder(for: prayer.name)
                    },
                    onToggleComplete: {
                        viewModel.togglePrayerCompletion(for: prayer.name)
                    }
                )
            }
        }
    }

    // MARK: - Footer Info
    private var footerInfo: some View {
        HStack {
            Text(viewModel.calculationMethod)
                .font(.system(size: 11, weight: .medium, design: .rounded))

            Text("•")

            Text("Based on \(viewModel.cityName), \(viewModel.stateName)")
                .font(.system(size: 11, weight: .regular, design: .rounded))
        }
        .foregroundColor(theme.tertiaryText)
        .padding(.vertical, 8)
    }
}

// MARK: - Prayer Row Component
struct PrayerRowView: View {
    let prayer: Prayer
    let isActive: Bool
    let theme: AppTheme
    let onToggleReminder: () -> Void
    let onToggleComplete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Prayer Icon & Name
            HStack(spacing: 12) {
                Image(systemName: prayer.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? theme.primaryAccent : theme.secondaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    if isActive {
                        Text("NOW")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(theme.primaryAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(theme.primaryAccent.opacity(0.2))
                            )
                    }
                }
            }

            Spacer()

            // Prayer Time
            Text(prayer.time)
                .font(.system(size: 18, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundColor(isActive ? theme.primaryAccent : theme.primaryText)

            // Reminder Toggle
            Button(action: onToggleReminder) {
                Image(systemName: prayer.hasReminder ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(prayer.hasReminder ? theme.accentGold : theme.tertiaryText)
            }

            // Completion Checkbox (not for Sunrise)
            if prayer.name != "Sunrise" {
                Button(action: onToggleComplete) {
                    Image(systemName: prayer.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(prayer.isCompleted ? theme.accentGreen : theme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primaryAccent.opacity(0.15),
                                    theme.primaryAccent.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.primaryAccent.opacity(0.3), lineWidth: 1)
                        )
                } else if theme.hasGlassEffect {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor.opacity(0.3), radius: 5)
                }
            }
        )
    }
}

// MARK: - Prayer Model
struct Prayer {
    let name: String
    var time: String
    let icon: String
    var hasReminder: Bool
    var isCompleted: Bool
}

// MARK: - Preview
struct PrayerTimeView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerTimeView()
    }
}