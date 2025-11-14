import SwiftUI
import CoreLocation

struct PrayerTimeView: View {
    @EnvironmentObject var viewModel: PrayerTimeViewModel
    @ObservedObject var themeManager = ThemeManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var animateProgress = false
    @State private var showingDatePicker = false
    @State private var showingPaywall = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            // Background
            mosqueBackgroundView

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .top) {
                    // Extended mosque background only for non-glass themes
                    if !theme.hasGlassEffect {
                        mosqueBgImageView
                            .ignoresSafeArea(edges: .top)
                    }

                    VStack(spacing: 0) {
                        // Add top padding for liquid glass mode
                        if theme.hasGlassEffect {
                            Color.clear
                                .frame(height: 50)
                        }

                        // Top prayer time section content
                        topPrayerSection

                        // Date navigation section
                        dateNavigationSection

                        // Bottom content (existing sections)
                        VStack(spacing: 16) {
                            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                                progressSection
                            }

                            // Qibla Compass
                            CompactQiblaIndicator()
                                .padding(.horizontal, 16)

                            prayerScheduleList
                            footerInfo
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .ignoresSafeArea(edges: theme.hasGlassEffect ? [] : .top)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animateProgress = true
            }
            // Reload prayer completions when view appears
            viewModel.reloadCompletions()
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $viewModel.selectedDate,
                onDateSelected: { date in
                    viewModel.fetchPrayerTimes(for: date)
                    showingDatePicker = false
                },
                theme: theme
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Background View
    private var mosqueBackgroundView: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                LiquidGlassBackgroundView()
            } else {
                theme.primaryBackground
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Mosque Background Image with Fade
    private var mosqueBgImageView: some View {
        GeometryReader { geometry in
            Image("mosque-bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: 380) // Extended height
                .clipped()
                .overlay(
                    // Combined gradient overlays
                    ZStack {
                        // Gradient for text readability at top
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.1),
                                Color.black.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )

                        // Fade-out gradient at bottom
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                theme.primaryBackground.opacity(0.7),
                                theme.primaryBackground.opacity(0.95),
                                theme.primaryBackground
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
        }
        .frame(height: 380) // Extends to overlap with progress card
    }

    // MARK: - Top Prayer Section
    private var topPrayerSection: some View {
        VStack(spacing: 0) {
            // Status bar spacer
            Color.clear
                .frame(height: 50)

            // Location info
            Button(action: {
                viewModel.refreshLocation()
            }) {
                HStack {
                    if viewModel.isRefreshingLocation {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(theme.hasGlassEffect ? theme.secondaryText : .white.opacity(0.8))
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.hasGlassEffect ? theme.secondaryText : .white.opacity(0.8))
                    }

                    Text("\(viewModel.cityName), \(viewModel.countryName)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(theme.hasGlassEffect ? theme.primaryText : .white.opacity(0.9))

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.hasGlassEffect ? theme.tertiaryText : .white.opacity(0.6))
                        .opacity(viewModel.isRefreshingLocation ? 0 : 1)

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Next prayer info (always shows today's next prayer)
            if let nextPrayer = viewModel.todaysNextPrayer {
                VStack(spacing: 6) {
                    Text(nextPrayer.name)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.hasGlassEffect ? theme.primaryText : .white.opacity(0.95))

                    Text(nextPrayer.time)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(theme.hasGlassEffect ? theme.primaryText : .white)

                    HStack(spacing: 5) {
                        Text("Starts in \(viewModel.timeUntilNextPrayer)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.hasGlassEffect ? theme.secondaryText : .white.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.hasGlassEffect ? theme.cardBackground.opacity(0.3) : .white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(theme.hasGlassEffect ? theme.primaryAccent.opacity(0.3) : .white.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .frame(height: 280)
    }

    // MARK: - Date Navigation Section
    private var dateNavigationSection: some View {
        VStack(spacing: 12) {
            // Date picker header
            HStack {
                Text("Prayer Times")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)

                Spacer()

                if viewModel.isLoadingFuturePrayers {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(theme.primaryAccent)
                }
            }

            // Date navigation buttons
            HStack(spacing: 12) {
                // Previous day button
                Button(action: {
                    let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    viewModel.fetchPrayerTimes(for: previousDay)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryAccent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.cardBackground.opacity(theme.hasGlassEffect ? 0.3 : 1.0))
                                .shadow(color: theme.shadowColor.opacity(0.3), radius: 5)
                        )
                }

                // Current date display
                VStack(spacing: 2) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        Text("Today")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.primaryAccent)
                    } else {
                        Text(dayOfWeek(viewModel.selectedDate))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)

                // Next day button
                Button(action: {
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    viewModel.fetchPrayerTimes(for: nextDay)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryAccent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.cardBackground.opacity(theme.hasGlassEffect ? 0.3 : 1.0))
                                .shadow(color: theme.shadowColor.opacity(0.3), radius: 5)
                        )
                }

                // Calendar picker button
                Button(action: {
                    showingDatePicker = true
                }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryAccent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.cardBackground.opacity(theme.hasGlassEffect ? 0.3 : 1.0))
                                .shadow(color: theme.shadowColor.opacity(0.3), radius: 5)
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            theme.hasGlassEffect ?
            AnyView(Color.clear) :
            AnyView(theme.primaryBackground)
        )
    }

    // Helper functions for date formatting
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Progress Section (simplified since streak moved to card)
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

            // Daily Progress Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.currentStreak > 0 ? .orange : theme.tertiaryText)

                    Text("Current Streak")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.currentStreak > 0 ? theme.primaryAccent : theme.primaryText)

                    Text(viewModel.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("Best:")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(theme.tertiaryText)
                        Text("\(viewModel.bestStreak) days")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.primaryAccent)
                    }

                    HStack(spacing: 4) {
                        Text("Today:")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(theme.tertiaryText)
                        let progressPercent = Int(viewModel.progressPercentage * 100)
                        Text("\(progressPercent)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.accentGreen)
                    }
                }
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
            let isToday = Calendar.current.isDateInToday(viewModel.selectedDate)
            let isPastDate = viewModel.selectedDate < Date() && !isToday
            ForEach(viewModel.prayers, id: \.name) { prayer in
                PrayerRowView(
                    prayer: prayer,
                    isActive: isToday && prayer.name == viewModel.currentPrayer?.name,
                    isToday: isToday,
                    isPastDate: isPastDate,
                    isPrayerPassed: viewModel.isPrayerPassed(prayer.name),
                    theme: theme,
                    onToggleReminder: {
                        viewModel.toggleReminder(for: prayer.name)
                    },
                    onToggleComplete: {
                        if subscriptionService.isPremium {
                            viewModel.togglePrayerCompletion(for: prayer.name)
                        } else {
                            showingPaywall = true
                        }
                    },
                    isPremium: subscriptionService.isPremium
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
    let isToday: Bool
    let isPastDate: Bool
    let isPrayerPassed: Bool
    let theme: AppTheme
    let onToggleReminder: () -> Void
    let onToggleComplete: () -> Void
    let isPremium: Bool

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

            // Completion Checkbox
            // Show for: Today (past prayers/active) OR past dates
            // Interactive only for today's prayers
            if prayer.name != "Sunrise" {
                if isToday && (isPrayerPassed || isActive) {
                    // Today's prayers - interactive
                    Button(action: onToggleComplete) {
                        ZStack {
                            Image(systemName: prayer.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(prayer.isCompleted ? theme.accentGreen : theme.tertiaryText)

                            if !isPremium {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                } else if isPastDate {
                    // Past dates - display only (non-interactive)
                    Image(systemName: prayer.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(prayer.isCompleted ? theme.accentGreen.opacity(0.6) : theme.tertiaryText.opacity(0.3))
                } else {
                    // Future dates or today's future prayers - empty spacer
                    Color.clear
                        .frame(width: 20, height: 20)
                }
            } else {
                // Sunrise - always empty spacer
                Color.clear
                    .frame(width: 20, height: 20)
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

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth = Date()
    @State private var tempSelectedDate = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(theme.cardBackground.opacity(0.5))
                            )
                    }

                    Spacer()

                    Text("Select Date")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button("Today") {
                        tempSelectedDate = Date()
                        displayedMonth = Date()
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(theme.primaryAccent)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Month Navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryAccent)
                    }

                    Spacer()

                    Text(dateFormatter.string(from: displayedMonth))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(theme.primaryAccent)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.bottom, 20)

            // Calendar Grid
            VStack(spacing: 10) {
                // Week day headers
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar days
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                    ForEach(getDaysInMonth(), id: \.self) { date in
                        if let date = date {
                            DayCell(
                                date: date,
                                isSelected: isSameDay(date, tempSelectedDate),
                                isToday: isSameDay(date, Date()),
                                isCurrentMonth: isSameMonth(date, displayedMonth),
                                theme: theme,
                                onTap: {
                                    tempSelectedDate = date
                                }
                            )
                        } else {
                            Color.clear
                                .frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // Bottom buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground.opacity(0.5))
                )

                Button("Select") {
                    onDateSelected(tempSelectedDate)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.primaryAccent)
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(theme.primaryBackground)
        .onAppear {
            tempSelectedDate = selectedDate
            displayedMonth = selectedDate
        }
    }

    // MARK: - Helper Functions
    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    private func getDaysInMonth() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }

    private func isSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        calendar.isDate(date1, equalTo: date2, toGranularity: .month)
    }
}

// MARK: - Day Cell Component
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let theme: AppTheme
    let onTap: () -> Void

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryAccent)
                        .frame(width: 44, height: 44)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.primaryAccent, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }

                Text(dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: isToday || isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? theme.primaryAccent :
                        isCurrentMonth ? theme.primaryText : theme.tertiaryText.opacity(0.5)
                    )
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct PrayerTimeView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerTimeView()
    }
}