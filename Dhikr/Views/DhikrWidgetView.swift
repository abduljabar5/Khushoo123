//
//  DhikrWidgetView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct TimeBreakdown {
    let morning: Int
    let afternoon: Int
    let evening: Int
    let night: Int
}

struct MonthlyStats {
    let total: Int
    let subhanAllah: Int
    let alhamdulillah: Int
    let astaghfirullah: Int
    let dailyAverage: Int
    let bestDay: (count: Int, dateString: String)
    let goalsMetPercentage: Int
    let timeBreakdown: TimeBreakdown
}

struct DhikrWidgetView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    // MARK: - Consistent Background Helpers
    private var cardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            }
        }
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.16)
            : theme.primaryBackground
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                HStack {
                    Text("Today's Dhikr")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.primaryText)
                    Spacer()

                    // Goals button
                    NavigationLink(destination: DhikrGoalsView()
                        .environmentObject(dhikrService)
                        .environmentObject(audioPlayerService)
                        .environmentObject(bluetoothService)
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.system(size: 16))
                            Text("Goals")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(theme.primaryAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.primaryAccent.opacity(0.15))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Main count display
                mainCountDisplay()

                // Stats row (Day Streak, This Week, All Time)
                statsRow()

                // Zikr Ring Status - Hidden until Bluetooth feature is ready
                // zikrRingStatus()

                // Today's Practice section
                todaysPracticeSection()

                // Monthly Activity section
                monthlyActivitySection()

                // Lifetime Statistics section
                lifetimeStatisticsSection()
            }
            .padding(.bottom, 100)
        }
        .background(pageBackground.ignoresSafeArea())
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    // MARK: - Main Count Display
    private func mainCountDisplay() -> some View {
        let stats = dhikrService.getTodayStats()

        return Text("\(stats.total)")
            .font(.system(size: 72, weight: .bold))
            .foregroundColor(theme.primaryAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    // MARK: - Stats Row
    private func statsRow() -> some View {
        let stats = dhikrService.getTodayStats()
        let weeklyStats = dhikrService.getWeeklyStats()
        let thisWeekTotal = weeklyStats.reduce(0) { $0 + $1.total }
        let allTimeTotal = dhikrService.getAllTimeTotal()

        return HStack(spacing: 12) {
            DhikrStatCard(value: "\(stats.streak)", label: "Day Streak", icon: "flame.fill", iconColor: .orange)
            DhikrStatCard(value: formatNumber(thisWeekTotal), label: "This Week", icon: "calendar", iconColor: theme.primaryAccent)
            DhikrStatCard(value: formatNumber(allTimeTotal), label: "All Time", icon: "infinity", iconColor: theme.accentGreen)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Zikr Ring Status
    private func zikrRingStatus() -> some View {
        let isConnected = bluetoothService.isConnected
        // TODO: Add batteryLevel to BluetoothService when hardware supports it
        let batteryLevel = 78 // Placeholder until battery reporting is implemented

        return HStack(spacing: 12) {
            // Status indicator circle
            Circle()
                .fill(isConnected ? theme.accentGreen : theme.tertiaryText)
                .frame(width: 10, height: 10)

            Text(isConnected ? "Zikr Ring Active" : "Zikr Ring Disconnected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isConnected ? theme.accentGreen : theme.tertiaryText)

            Spacer()

            // Battery icon and percentage (only show when connected)
            if isConnected {
                HStack(spacing: 6) {
                    Image(systemName: batteryIcon(for: batteryLevel))
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                    Text("\(batteryLevel)%")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(cardBackground)
        .shadow(color: theme.primaryAccent.opacity(0.08), radius: 6, x: 0, y: 3)
        .padding(.horizontal, 20)
    }

    // MARK: - Helper for Battery Icon
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 76...100:
            return "battery.100"
        case 51...75:
            return "battery.75"
        case 26...50:
            return "battery.50"
        case 1...25:
            return "battery.25"
        default:
            return "battery.0"
        }
    }

    // MARK: - Today's Practice Section
    private func todaysPracticeSection() -> some View {
        let stats = dhikrService.getTodayStats()

        return VStack(alignment: .leading, spacing: 20) {
            Text("Today's Practice")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                DhikrCard(
                    type: .astaghfirullah,
                    count: stats.astaghfirullah,
                    goal: dhikrService.goal.astaghfirullah,
                    color: .purple,
                    onIncrement: { amount in
                        dhikrService.incrementDhikr(.astaghfirullah, by: amount)
                    },
                    onReset: {
                        dhikrService.setDhikrCount(.astaghfirullah, count: 0)
                    }
                )

                DhikrCard(
                    type: .alhamdulillah,
                    count: stats.alhamdulillah,
                    goal: dhikrService.goal.alhamdulillah,
                    color: .green,
                    onIncrement: { amount in
                        dhikrService.incrementDhikr(.alhamdulillah, by: amount)
                    },
                    onReset: {
                        dhikrService.setDhikrCount(.alhamdulillah, count: 0)
                    }
                )

                DhikrCard(
                    type: .subhanAllah,
                    count: stats.subhanAllah,
                    goal: dhikrService.goal.subhanAllah,
                    color: .cyan,
                    onIncrement: { amount in
                        dhikrService.incrementDhikr(.subhanAllah, by: amount)
                    },
                    onReset: {
                        dhikrService.setDhikrCount(.subhanAllah, count: 0)
                    }
                )
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helper Methods
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    // MARK: - Monthly Activity Section
    private func monthlyActivitySection() -> some View {
        MonthlyActivityContainer(dhikrService: dhikrService)
    }

    // MARK: - Lifetime Statistics Section
    private func lifetimeStatisticsSection() -> some View {
        let allTimeTotal = dhikrService.getAllTimeTotal()
        let allStats = dhikrService.getAllDhikrStats()
        let activeDays = allStats.filter { $0.total > 0 }.count

        // Calculate totals by type
        let totalSubhanAllah = allStats.reduce(0) { $0 + $1.subhanAllah }
        let totalAlhamdulillah = allStats.reduce(0) { $0 + $1.alhamdulillah }
        let totalAstaghfirullah = allStats.reduce(0) { $0 + $1.astaghfirullah }

        // Calculate daily average
        let dailyAverage = activeDays > 0 ? allTimeTotal / activeDays : 0

        // Find best day
        let bestDay = allStats.max(by: { $0.total < $1.total })?.total ?? 0

        return VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(theme.accentGold.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.accentGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Stats")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text("Lifetime achievements")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            // Main stats card
            VStack(alignment: .leading, spacing: 20) {
                // TOTAL badge
                HStack(spacing: 6) {
                    Text("TOTAL")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accentGreen)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.accentGreen.opacity(0.3), lineWidth: 1.5)
                )

                // Total count
                Text("\(allTimeTotal.formatted())")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(theme.accentGreen)

                Text("Total Dhikr Count")
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryText)

                // Bottom stats row
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(activeDays)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("DAYS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dailyAverage)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("DAILY AVG")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bestDay)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("BEST DAY")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(cardBackground)
            .padding(.horizontal, 20)

            // Breakdown by Type section
            VStack(alignment: .leading, spacing: 16) {
                Text("Breakdown by Type")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                VStack(spacing: 12) {
                    // SubhanAllah - cyan/teal
                    dhikrBreakdownRow(
                        icon: "sparkles",
                        name: "Subhan'Allah",
                        subtitle: "Glory be to Allah",
                        percentage: allTimeTotal > 0 ? Int((Double(totalSubhanAllah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalSubhanAllah,
                        color: theme.primaryAccent
                    )

                    // Alhamdulillah - green
                    dhikrBreakdownRow(
                        icon: "hands.clap.fill",
                        name: "Alhamdulillah",
                        subtitle: "All praise to Allah",
                        percentage: allTimeTotal > 0 ? Int((Double(totalAlhamdulillah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalAlhamdulillah,
                        color: theme.accentGreen
                    )

                    // Astaghfirullah - purple
                    dhikrBreakdownRow(
                        icon: "heart.fill",
                        name: "Astaghfirullah",
                        subtitle: "I seek forgiveness",
                        percentage: allTimeTotal > 0 ? Int((Double(totalAstaghfirullah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalAstaghfirullah,
                        color: Color(red: 0.6, green: 0.4, blue: 1.0)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Helper for breakdown rows
    private func dhikrBreakdownRow(icon: String, name: String, subtitle: String, percentage: Int, count: Int, color: Color) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }

            // Name and subtitle
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("• \(percentage)%")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            // Count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count.formatted())")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)

                Text("times")
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.effectiveTheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.20) : theme.cardBackground)
        )
        .shadow(color: color.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Dhikr Stat Card
struct DhikrStatCard: View {
    let value: String
    let label: String
    var icon: String? = nil
    var iconColor: Color? = nil
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var cardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor ?? theme.primaryAccent)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.primaryAccent)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBackground)
        .shadow(color: theme.primaryAccent.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Dhikr Card
struct DhikrCard: View {
    let type: DhikrType
    let count: Int
    let goal: Int
    let color: Color
    let onIncrement: (Int) -> Void
    let onReset: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingInputSheet = false
    @State private var inputText = ""

    private var theme: AppTheme { themeManager.theme }

    private var cardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBackground)
            }
        }
    }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1.0)
    }

    private var extraCount: Int {
        return max(0, count - goal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Arabic text and count
            HStack(alignment: .top) {
                Text(type.arabicText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Button(action: {
                        inputText = "\(count)"
                        showingInputSheet = true
                    }) {
                        Text("\(count)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(color)
                    }

                    Text("of \(goal)")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
            }

            // English name
            Text(type.rawValue)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.tertiaryBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 8)

            // Progress percentage and extra count
            HStack {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)

                Spacer()

                Text(extraCount > 0 ? "+\(extraCount) extra" : "")
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)
                    .frame(minWidth: 60, alignment: .trailing)
            }

            // Action buttons
            HStack(spacing: 12) {
                IncrementButton(label: "+1", color: color) {
                    onIncrement(1)
                }

                IncrementButton(label: "+10", color: color) {
                    onIncrement(10)
                }

                IncrementButton(label: "+33", color: color) {
                    onIncrement(33)
                }

                ResetButton(onReset: onReset)
            }
        }
        .padding(20)
        .background(cardBackground)
        .shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingInputSheet) {
            DhikrInputSheet(
                currentCount: count,
                color: color,
                dhikrType: type,
                onSave: { newValue in
                    if newValue >= 0 {
                        // Calculate difference and increment by that amount
                        let difference = newValue - count
                        if difference > 0 {
                            onIncrement(difference)
                        } else if difference < 0 {
                            // If user wants to decrease, we can reset and add the new value
                            onReset()
                            if newValue > 0 {
                                onIncrement(newValue)
                            }
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Increment Button
struct IncrementButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Reset Button
struct ResetButton: View {
    let onReset: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            onReset()
        }) {
            Text("Reset")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.secondaryText.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.secondaryText.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Monthly Activity Container
struct MonthlyActivityContainer: View {
    @ObservedObject var dhikrService: DhikrService
    @State private var selectedMonth = Date()
    @State private var selectedDayStats: DailyDhikrStats?
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var cardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBackground)
            }
        }
    }

    private var smallCardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Monthly Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 20)

            VStack(spacing: 20) {
                // Month navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(theme.primaryText)
                    }

                    Spacer()

                    Text(monthYearString)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(theme.primaryText)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar grid
                MonthlyCalendarView(
                    month: selectedMonth,
                    dhikrService: dhikrService,
                    onDayTapped: { stats in
                        selectedDayStats = stats
                    }
                )

                // Legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)

                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.accentGreen.opacity(0.2 + Double(index) * 0.2))
                            .frame(width: 20, height: 20)
                    }

                    Text("More")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .background(cardBackground)
            .padding(.horizontal, 20)

            // Monthly Statistics Section
            monthlyStatisticsView()
        }
        .sheet(item: $selectedDayStats) { stats in
            DayDetailSheet(stats: stats)
        }
    }

    private func monthlyStatisticsView() -> some View {
        let monthStats = getMonthStats()
        let lastMonthStats = getLastMonthStats()
        let percentageChange = calculatePercentageChange(current: monthStats.total, previous: lastMonthStats.total)

        return VStack(spacing: 16) {
            // Main stats card
            VStack(alignment: .leading, spacing: 16) {
                Text(monthYearString)
                    .font(.system(size: 14))
                    .foregroundColor(theme.secondaryText)

                Text("Total Dhikr")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)

                Text(formatNumber(monthStats.total))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Rectangle()
                    .fill(theme.accentGreen)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: 60)
                    .padding(.top, 8)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(monthStats.dailyAverage)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("Daily Avg")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(percentageChange >= 0 ? "+\(Int(percentageChange))%" : "\(Int(percentageChange))%")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(percentageChange >= 0 ? theme.accentGreen : Color(red: 1.0, green: 0.4, blue: 0.4))

                            Image(systemName: percentageChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(percentageChange >= 0 ? theme.accentGreen : Color(red: 1.0, green: 0.4, blue: 0.4))
                        }

                        Text("vs Last Mo")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(themeManager.effectiveTheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.20) : theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.accentGreen.opacity(0.3), lineWidth: 1)
                    )
            )

            // Best Day and Goals Met cards
            HStack(spacing: 16) {
                // Best Day Card
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.accentGold.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.accentGold)
                    }

                    Text("\(monthStats.bestDay.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.accentGold)

                    Text("Best Day")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)

                    Text(monthStats.bestDay.dateString)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(smallCardBackground)
                .shadow(color: theme.accentGold.opacity(0.1), radius: 6, x: 0, y: 3)

                // Goals Met Card
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(theme.primaryAccent.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.primaryAccent)
                    }

                    Text("\(monthStats.goalsMetPercentage)%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.primaryAccent)

                    Text("Goals Met")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(smallCardBackground)
                .shadow(color: theme.primaryAccent.opacity(0.1), radius: 6, x: 0, y: 3)
            }

            // Distribution
            VStack(alignment: .leading, spacing: 20) {
                Text("Distribution")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                HStack(spacing: 16) {
                    // SubhanAllah - cyan/teal
                    distributionCard(
                        name: "SubhanAllah",
                        count: monthStats.subhanAllah,
                        total: monthStats.total,
                        color: theme.primaryAccent
                    )

                    // Alhamdulillah - green
                    distributionCard(
                        name: "Alhamdulillah",
                        count: monthStats.alhamdulillah,
                        total: monthStats.total,
                        color: theme.accentGreen
                    )

                    // Astaghfirullah - purple
                    distributionCard(
                        name: "Astaghfirullah",
                        count: monthStats.astaghfirullah,
                        total: monthStats.total,
                        color: Color(red: 0.6, green: 0.4, blue: 1.0)
                    )
                }
            }

            Spacer().frame(height: 32)

            // Most Active Times
            VStack(alignment: .leading, spacing: 20) {
                Text("Most Active Times")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                VStack(alignment: .leading, spacing: 16) {
                    timeSlotRow(label: "Morning", percentage: monthStats.timeBreakdown.morning)
                    timeSlotRow(label: "Afternoon", percentage: monthStats.timeBreakdown.afternoon)
                    timeSlotRow(label: "Evening", percentage: monthStats.timeBreakdown.evening)
                    timeSlotRow(label: "Night", percentage: monthStats.timeBreakdown.night)
                }
                .padding(20)
                .background(smallCardBackground)
            }
        }
        .padding(.horizontal, 20)
    }

    private func distributionCard(name: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0

        return VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(theme.tertiaryBackground, lineWidth: 8)
                    .frame(width: 80, height: 80)

                // Progress circle
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                // Percentage text
                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("\(formatNumber(count)) total")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(smallCardBackground)
    }

    private func timeSlotRow(label: String, percentage: Int) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)
                .frame(width: 140, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.tertiaryBackground)
                        .frame(height: 24)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [theme.accentGreen, theme.primaryAccent]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (Double(percentage) / 100), height: 24)

                    Text("\(percentage)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .padding(.leading, 8)
                }
            }
            .frame(height: 24)
        }
    }

    private func getMonthStats() -> MonthlyStats {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        let allStats = dhikrService.getAllDhikrStats()
        let monthlyStats = allStats.filter { stats in
            stats.date >= monthStart && stats.date <= monthEnd
        }

        let totalDhikr = monthlyStats.reduce(0) { $0 + $1.total }
        let totalSubhanAllah = monthlyStats.reduce(0) { $0 + $1.subhanAllah }
        let totalAlhamdulillah = monthlyStats.reduce(0) { $0 + $1.alhamdulillah }
        let totalAstaghfirullah = monthlyStats.reduce(0) { $0 + $1.astaghfirullah }

        let activeDays = monthlyStats.filter { $0.total > 0 }.count
        let dailyAverage = activeDays > 0 ? totalDhikr / activeDays : 0

        let bestDayStats = monthlyStats.max(by: { $0.total < $1.total })
        let bestDayCount = bestDayStats?.total ?? 0
        let bestDayDate = bestDayStats?.date ?? Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let bestDayString = bestDayStats != nil ? dateFormatter.string(from: bestDayDate) : "N/A"

        // Calculate goals met
        let goal = dhikrService.goal
        let totalGoal = goal.subhanAllah + goal.alhamdulillah + goal.astaghfirullah
        let daysWithGoalsMet = monthlyStats.filter { stats in
            stats.total >= totalGoal
        }.count
        let goalsMetPercentage = activeDays > 0 ? (daysWithGoalsMet * 100) / activeDays : 0

        // Calculate time breakdown (simulated distribution)
        // Since we don't track exact times, we'll use a realistic distribution pattern
        let timeBreakdown = calculateTimeBreakdown(from: monthlyStats)

        return MonthlyStats(
            total: totalDhikr,
            subhanAllah: totalSubhanAllah,
            alhamdulillah: totalAlhamdulillah,
            astaghfirullah: totalAstaghfirullah,
            dailyAverage: dailyAverage,
            bestDay: (count: bestDayCount, dateString: bestDayString),
            goalsMetPercentage: goalsMetPercentage,
            timeBreakdown: timeBreakdown
        )
    }

    private func calculateTimeBreakdown(from stats: [DailyDhikrStats]) -> TimeBreakdown {
        // Get the date range for the stats
        guard let firstDate = stats.first?.date,
              let lastDate = stats.last?.date else {
            return TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        }

        // Get actual entries from DhikrService
        let entries = dhikrService.getEntries(from: min(firstDate, lastDate), to: max(firstDate, lastDate))

        // If no entries yet (new user or old data), show default distribution
        guard !entries.isEmpty else {
            return TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        }

        // Use real time breakdown calculation
        let breakdown = dhikrService.calculateTimeBreakdown(for: entries)
        let total = breakdown.morning + breakdown.afternoon + breakdown.evening + breakdown.night

        // Convert to percentages
        guard total > 0 else {
            return TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        }

        return TimeBreakdown(
            morning: (breakdown.morning * 100) / total,
            afternoon: (breakdown.afternoon * 100) / total,
            evening: (breakdown.evening * 100) / total,
            night: (breakdown.night * 100) / total
        )
    }

    private func getLastMonthStats() -> MonthlyStats {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else {
            return MonthlyStats(
                total: 0,
                subhanAllah: 0,
                alhamdulillah: 0,
                astaghfirullah: 0,
                dailyAverage: 0,
                bestDay: (0, "N/A"),
                goalsMetPercentage: 0,
                timeBreakdown: TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
            )
        }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!

        let allStats = dhikrService.getAllDhikrStats()
        let monthlyStats = allStats.filter { stats in
            stats.date >= monthStart && stats.date <= monthEnd
        }

        let totalDhikr = monthlyStats.reduce(0) { $0 + $1.total }

        return MonthlyStats(
            total: totalDhikr,
            subhanAllah: 0,
            alhamdulillah: 0,
            astaghfirullah: 0,
            dailyAverage: 0,
            bestDay: (0, "N/A"),
            goalsMetPercentage: 0,
            timeBreakdown: TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        )
    }

    private func calculatePercentageChange(current: Int, previous: Int) -> Double {
        guard previous > 0 else { return current > 0 ? 100.0 : 0.0 }
        return ((Double(current - previous) / Double(previous)) * 100.0)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private func changeMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

// MARK: - Monthly Calendar View
struct MonthlyCalendarView: View {
    let month: Date
    @ObservedObject var dhikrService: DhikrService
    let onDayTapped: (DailyDhikrStats) -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    let days = ["S", "M", "T", "W", "T", "F", "S"]

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }

        var dates: [Date] = []
        var currentDate = monthFirstWeek.start

        while currentDate < monthLastWeek.end {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = (geometry.size.width - 24) / 7 // 24 for spacing (6 gaps * 4)

            VStack(spacing: 12) {
                // Day headers
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                            .frame(width: cellWidth)
                    }
                }

                // Calendar days
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(monthDates, id: \.self) { date in
                        let day = calendar.component(.day, from: date)
                        let isInCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)

                        if isInCurrentMonth {
                            CalendarDayCell(
                                day: day,
                                stats: getStats(for: date),
                                maxTotal: maxDhikrTotal,
                                onTap: {
                                    // Create stats object even if no dhikr recorded
                                    let stats = getStats(for: date) ?? DailyDhikrStats(
                                        date: date,
                                        subhanAllah: 0,
                                        alhamdulillah: 0,
                                        astaghfirullah: 0,
                                        total: 0
                                    )
                                    onDayTapped(stats)
                                }
                            )
                            .frame(width: cellWidth)
                        } else {
                            // Empty cell for days outside current month
                            Color.clear
                                .frame(width: cellWidth, height: 40)
                        }
                    }
                }
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 12)
    }

    private var maxDhikrTotal: Int {
        let allStats = dhikrService.getAllDhikrStats()
        return allStats.map { $0.total }.max() ?? 1
    }

    private func getStats(for date: Date) -> DailyDhikrStats? {
        return dhikrService.getAllDhikrStats().first { stats in
            calendar.isDate(stats.date, inSameDayAs: date)
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let day: Int
    let stats: DailyDhikrStats?
    let maxTotal: Int
    let onTap: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var cellBackground: Color {
        if themeManager.effectiveTheme == .dark {
            return Color(red: 0.15, green: 0.17, blue: 0.20)
        } else {
            return theme.cardBackground
        }
    }

    private var intensity: Double {
        guard let stats = stats, stats.total > 0, maxTotal > 0 else { return 0 }
        return Double(stats.total) / Double(maxTotal)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(intensity > 0 ? theme.accentGreen.opacity(0.3 + intensity * 0.7) : cellBackground)
                    .frame(height: 40)

                Text("\(day)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(intensity > 0 ? .white : theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Day Detail Sheet
struct DayDetailSheet: View {
    let stats: DailyDhikrStats
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.16)
            : theme.primaryBackground
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text(formattedDate)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(.top, 20)

            if stats.total > 0 {
                // Total count
                VStack(spacing: 8) {
                    Text("\(stats.total)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(theme.primaryAccent)

                    Text("Total Dhikr")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical, 20)

                // Breakdown
                VStack(spacing: 16) {
                    DhikrStatRow(name: "Astaghfirullah", count: stats.astaghfirullah, color: Color(red: 0.6, green: 0.4, blue: 1.0))
                    DhikrStatRow(name: "Alhamdulillah", count: stats.alhamdulillah, color: theme.accentGreen)
                    DhikrStatRow(name: "SubhanAllah", count: stats.subhanAllah, color: theme.primaryAccent)
                }
            } else {
                // No dhikr message
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 60))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 40)

                    Text("No Dhikr Recorded")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text("You didn't record any dhikr on this day")
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: stats.date)
    }
}

// MARK: - Dhikr Stat Row
struct DhikrStatRow: View {
    let name: String
    let count: Int
    let color: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var cardBackground: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
            }
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(name)
                .font(.system(size: 16))
                .foregroundColor(theme.primaryText)

            Spacer()

            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .padding(16)
        .background(cardBackground)
    }
}

// MARK: - Dhikr Input Sheet
struct DhikrInputSheet: View {
    let currentCount: Int
    let color: Color
    let dhikrType: DhikrType
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var inputText: String
    @FocusState private var isFocused: Bool

    private var theme: AppTheme { themeManager.theme }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.16)
            : theme.primaryBackground
    }

    private var inputFieldBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.15, green: 0.17, blue: 0.20)
            : theme.cardBackground
    }

    init(currentCount: Int, color: Color, dhikrType: DhikrType, onSave: @escaping (Int) -> Void) {
        self.currentCount = currentCount
        self.color = color
        self.dhikrType = dhikrType
        self.onSave = onSave
        _inputText = State(initialValue: "\(currentCount)")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text(dhikrType.arabicText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(theme.primaryText)

                    Text(dhikrType.rawValue)
                        .font(.system(size: 16))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.top, 20)

                // Input field
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter Count")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.secondaryText)

                    TextField("0", text: $inputText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(color)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(inputFieldBackground)
                        )
                        .focused($isFocused)
                }
                .padding(.horizontal, 20)

                // Quick add buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 20)

                    HStack(spacing: 12) {
                        QuickAddButton(label: "+1", color: color) {
                            addToInput(1)
                        }
                        QuickAddButton(label: "+10", color: color) {
                            addToInput(10)
                        }
                        QuickAddButton(label: "+33", color: color) {
                            addToInput(33)
                        }
                        QuickAddButton(label: "+100", color: color) {
                            addToInput(100)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Save button
                Button(action: {
                    if let value = Int(inputText) {
                        onSave(value)
                        dismiss()
                    }
                }) {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(pageBackground.ignoresSafeArea())
            .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func addToInput(_ amount: Int) {
        let currentValue = Int(inputText) ?? 0
        inputText = "\(currentValue + amount)"
    }
}

// MARK: - Quick Add Button
struct QuickAddButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.3), lineWidth: 1.5)
                )
        }
    }
}

#Preview {
    DhikrWidgetView()
        .environmentObject(DhikrService.shared)
        .environmentObject(BluetoothService())
}
