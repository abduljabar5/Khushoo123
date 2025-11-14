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
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                HStack {
                    Text("Today's Dhikr")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Main count display
                mainCountDisplay()

                // Stats row (Day Streak, This Week, All Time)
                statsRow()

                // Zikr Ring Active
                zikrRingStatus()

                // Today's Practice section
                todaysPracticeSection()

                // Monthly Activity section
                monthlyActivitySection()

                // Lifetime Statistics section
                lifetimeStatisticsSection()
            }
            .padding(.bottom, 100)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Main Count Display
    private func mainCountDisplay() -> some View {
        let stats = dhikrService.getTodayStats()

        return Text("\(stats.total)")
            .font(.system(size: 72, weight: .bold))
            .foregroundColor(Color.cyan)
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
            DhikrStatCard(value: "\(stats.streak) 🔥", label: "DAY STREAK")
            DhikrStatCard(value: formatNumber(thisWeekTotal), label: "THIS WEEK")
            DhikrStatCard(value: formatNumber(allTimeTotal), label: "ALL TIME")
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
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

            Text(isConnected ? "Zikr Ring Active" : "Zikr Ring Disconnected")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isConnected ? .green : .gray)

            Spacer()

            // Battery icon and percentage (only show when connected)
            if isConnected {
                HStack(spacing: 6) {
                    Image(systemName: batteryIcon(for: batteryLevel))
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("\(batteryLevel)%")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
        )
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
            Text("TODAY'S PRACTICE")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
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
        if number >= 1000 {
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
                Text("🏆")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Stats")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Lifetime achievements")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
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
                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.0, green: 0.8, blue: 0.6).opacity(0.3), lineWidth: 1.5)
                )

                // Total count
                Text("\(allTimeTotal.formatted())")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 0.9, blue: 0.7))

                Text("Total Dhikr Count")
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                // Bottom stats row
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(activeDays)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("DAYS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dailyAverage)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("DAILY AVG")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bestDay)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("BEST DAY")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
            )
            .padding(.horizontal, 20)

            // Breakdown by Type section
            VStack(alignment: .leading, spacing: 16) {
                Text("Breakdown by Type")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    // SubhanAllah
                    dhikrBreakdownRow(
                        emoji: "💙",
                        name: "Subhan'Allah",
                        subtitle: "Glory be to Allah",
                        percentage: allTimeTotal > 0 ? Int((Double(totalSubhanAllah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalSubhanAllah,
                        color: Color(red: 0.3, green: 0.6, blue: 1.0)
                    )

                    // Alhamdulillah
                    dhikrBreakdownRow(
                        emoji: "💚",
                        name: "Alhamdulillah",
                        subtitle: "All praise to Allah",
                        percentage: allTimeTotal > 0 ? Int((Double(totalAlhamdulillah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalAlhamdulillah,
                        color: Color(red: 0.0, green: 0.8, blue: 0.4)
                    )

                    // Astaghfirullah
                    dhikrBreakdownRow(
                        emoji: "💜",
                        name: "Astaghfirullah",
                        subtitle: "I seek forgiveness",
                        percentage: allTimeTotal > 0 ? Int((Double(totalAstaghfirullah) / Double(allTimeTotal)) * 100) : 0,
                        count: totalAstaghfirullah,
                        color: Color(red: 0.7, green: 0.5, blue: 1.0)
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // Helper for breakdown rows
    private func dhikrBreakdownRow(emoji: String, name: String, subtitle: String, percentage: Int, count: Int, color: Color) -> some View {
        HStack(spacing: 16) {
            // Emoji icon
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12))
                )

            // Name and subtitle
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("• \(percentage)%")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }

            Spacer()

            // Count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(count.formatted())")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)

                Text("times")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
    }
}

// MARK: - Dhikr Stat Card
struct DhikrStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.cyan)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
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
                    .foregroundColor(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(color)

                    Text("of \(goal)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }

            // English name
            Text(type.rawValue)
                .font(.system(size: 14))
                .foregroundColor(.gray)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
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
                    .foregroundColor(.gray)
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
        )
    }
}

// MARK: - Increment Button
struct IncrementButton: View {
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

// MARK: - Reset Button
struct ResetButton: View {
    let onReset: () -> Void

    var body: some View {
        Button(action: onReset) {
            Text("Reset")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Monthly Activity Container
struct MonthlyActivityContainer: View {
    @ObservedObject var dhikrService: DhikrService
    @State private var selectedMonth = Date()
    @State private var selectedDayStats: DailyDhikrStats?
    @State private var showingDayDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Monthly Activity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            VStack(spacing: 20) {
                // Month navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Text(monthYearString)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar grid
                MonthlyCalendarView(
                    month: selectedMonth,
                    dhikrService: dhikrService,
                    onDayTapped: { stats in
                        selectedDayStats = stats
                        showingDayDetail = true
                    }
                )

                // Legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.2 + Double(index) * 0.2))
                            .frame(width: 20, height: 20)
                    }

                    Text("More")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
            )
            .padding(.horizontal, 20)

            // Monthly Statistics Section
            monthlyStatisticsView()
        }
        .sheet(isPresented: $showingDayDetail) {
            if let stats = selectedDayStats {
                DayDetailSheet(stats: stats)
            }
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
                    .foregroundColor(.gray)

                Text("Total Dhikr")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                Text(formatNumber(monthStats.total))
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)

                Rectangle()
                    .fill(Color.green)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: 60)
                    .padding(.top, 8)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(monthStats.dailyAverage)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Daily Avg")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(percentageChange >= 0 ? "+\(Int(percentageChange))%" : "\(Int(percentageChange))%")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(percentageChange >= 0 ? .green : .red)

                            Image(systemName: percentageChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(percentageChange >= 0 ? .green : .red)
                        }

                        Text("vs Last Mo")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )

            // Best Day and Goals Met cards
            HStack(spacing: 16) {
                // Best Day Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("⭐")
                        .font(.system(size: 32))

                    Text("\(monthStats.bestDay.count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.4))

                    Text("Best Day")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)

                    Text(monthStats.bestDay.dateString)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                )

                // Goals Met Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("✓")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)

                    Text("\(monthStats.goalsMetPercentage)%")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.blue)

                    Text("Goals Met")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                )
            }

            // Distribution
            VStack(alignment: .leading, spacing: 20) {
                Text("Distribution")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    // SubhanAllah
                    distributionCard(
                        name: "SubhanAllah",
                        count: monthStats.subhanAllah,
                        total: monthStats.total,
                        color: Color(red: 0.0, green: 0.5, blue: 1.0)
                    )

                    // Alhamdulillah
                    distributionCard(
                        name: "Alhamdulillah",
                        count: monthStats.alhamdulillah,
                        total: monthStats.total,
                        color: Color(red: 0.0, green: 0.8, blue: 0.4)
                    )

                    // Astaghfirullah
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
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 16) {
                    timeSlotRow(label: "Morning", percentage: monthStats.timeBreakdown.morning)
                    timeSlotRow(label: "Afternoon", percentage: monthStats.timeBreakdown.afternoon)
                    timeSlotRow(label: "Evening", percentage: monthStats.timeBreakdown.evening)
                    timeSlotRow(label: "Night", percentage: monthStats.timeBreakdown.night)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.08))
                )
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
                    .stroke(Color(white: 0.15), lineWidth: 8)
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
                    .foregroundColor(.white)

                Text("\(formatNumber(count)) total")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
    }

    private func timeSlotRow(label: String, percentage: Int) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .frame(width: 140, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.15))
                        .frame(height: 24)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.0, green: 0.6, blue: 0.5)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (Double(percentage) / 100), height: 24)

                    Text("\(percentage)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
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
        if number >= 1000 {
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
                            .foregroundColor(.gray)
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

    private var intensity: Double {
        guard let stats = stats, stats.total > 0, maxTotal > 0 else { return 0 }
        return Double(stats.total) / Double(maxTotal)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(intensity > 0 ? Color.green.opacity(0.3 + intensity * 0.7) : Color(white: 0.12))
                    .frame(height: 40)

                Text("\(day)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(intensity > 0 ? .white : .gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Day Detail Sheet
struct DayDetailSheet: View {
    let stats: DailyDhikrStats
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text(formattedDate)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 20)

            if stats.total > 0 {
                // Total count
                VStack(spacing: 8) {
                    Text("\(stats.total)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.cyan)

                    Text("Total Dhikr")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 20)

                // Breakdown
                VStack(spacing: 16) {
                    DhikrStatRow(name: "Astaghfirullah", count: stats.astaghfirullah, color: .purple)
                    DhikrStatRow(name: "Alhamdulillah", count: stats.alhamdulillah, color: .green)
                    DhikrStatRow(name: "SubhanAllah", count: stats.subhanAllah, color: .cyan)
                }
            } else {
                // No dhikr message
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                        .padding(.top, 40)

                    Text("No Dhikr Recorded")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("You didn't record any dhikr on this day")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .preferredColorScheme(.dark)
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

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(name)
                .font(.system(size: 16))
                .foregroundColor(.white)

            Spacer()

            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.1))
        )
    }
}

#Preview {
    DhikrWidgetView()
        .environmentObject(DhikrService.shared)
        .environmentObject(BluetoothService())
}
