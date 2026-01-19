//
//  DhikrWidgetView.swift
//  Dhikr
//
//  Sacred Minimalism redesign - contemplative, refined, spiritually appropriate
//

import SwiftUI

// MARK: - Statistics Models
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

// MARK: - Main View
struct DhikrWidgetView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    // Sacred color palette - muted, grounded
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46) // #C4A574
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55) // Muted sage green
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.35, green: 0.35, blue: 0.38)
            : Color(red: 0.65, green: 0.63, blue: 0.60)
    }

    private var forgivenessPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65) // Muted, dignified purple
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    // Animation states
    @State private var sectionAppeared: [Bool] = Array(repeating: false, count: 6)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                headerSection
                    .opacity(sectionAppeared[0] ? 1 : 0)
                    .offset(y: sectionAppeared[0] ? 0 : 20)

                // Today's count - subtle, not dominant
                todayCountSection
                    .padding(.top, 32)
                    .opacity(sectionAppeared[1] ? 1 : 0)
                    .offset(y: sectionAppeared[1] ? 0 : 20)

                // Journey stats - refined
                journeyStatsSection
                    .padding(.top, 40)
                    .opacity(sectionAppeared[2] ? 1 : 0)
                    .offset(y: sectionAppeared[2] ? 0 : 20)

                // Dhikr cards - emphasis on Arabic
                dhikrCardsSection
                    .padding(.top, 48)
                    .opacity(sectionAppeared[3] ? 1 : 0)
                    .offset(y: sectionAppeared[3] ? 0 : 20)

                // Monthly reflection
                monthlySection
                    .padding(.top, 48)
                    .opacity(sectionAppeared[4] ? 1 : 0)
                    .offset(y: sectionAppeared[4] ? 0 : 20)

                // Lifetime journey
                lifetimeSection
                    .padding(.top, 48)
                    .opacity(sectionAppeared[5] ? 1 : 0)
                    .offset(y: sectionAppeared[5] ? 0 : 20)
            }
            .padding(.bottom, 120)
        }
        .background(pageBackground.ignoresSafeArea())
        .onAppear {
            animateEntrance()
        }
    }

    // MARK: - Animations
    private func animateEntrance() {
        for index in 0..<sectionAppeared.count {
            withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.1)) {
                sectionAppeared[index] = true
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DHIKR")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(3)
                    .foregroundColor(theme.secondaryText)

                Text("Today's Practice")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(theme.primaryText)
            }

            Spacer()

            NavigationLink(destination: DhikrGoalsView()
                .environmentObject(dhikrService)
                .environmentObject(audioPlayerService)
                .environmentObject(bluetoothService)
            ) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(sacredGold.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13))
                                .foregroundColor(sacredGold)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Today Count Section
    private var todayCountSection: some View {
        let stats = dhikrService.getTodayStats()

        return VStack(spacing: 8) {
            Text("\(stats.total)")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(theme.primaryText)

            Text("remembrances today")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(theme.secondaryText)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Journey Stats Section
    private var journeyStatsSection: some View {
        let stats = dhikrService.getTodayStats()
        let weeklyStats = dhikrService.getWeeklyStats()
        let thisWeekTotal = weeklyStats.reduce(0) { $0 + $1.total }
        let allTimeTotal = dhikrService.getAllTimeTotal()

        return HStack(spacing: 0) {
            // Streak
            statItem(
                value: "\(stats.streak)",
                label: "STREAK",
                sublabel: "days"
            )

            divider

            // This Week
            statItem(
                value: formatNumber(thisWeekTotal),
                label: "WEEK",
                sublabel: nil
            )

            divider

            // All Time
            statItem(
                value: formatNumber(allTimeTotal),
                label: "LIFETIME",
                sublabel: nil
            )
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.secondaryText.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private func statItem(value: String, label: String, sublabel: String?) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(theme.primaryText)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(theme.secondaryText)

            if let sublabel = sublabel {
                Text(sublabel)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.secondaryText.opacity(0.15))
            .frame(width: 1, height: 50)
    }

    // MARK: - Dhikr Cards Section
    private var dhikrCardsSection: some View {
        let stats = dhikrService.getTodayStats()

        return VStack(alignment: .leading, spacing: 24) {
            Text("PRACTICE")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                // Astaghfirullah first (seeking forgiveness)
                SacredDhikrCard(
                    type: .astaghfirullah,
                    count: stats.astaghfirullah,
                    goal: dhikrService.goal.astaghfirullah,
                    accentColor: forgivenessPurple,
                    onIncrement: { dhikrService.incrementDhikr(.astaghfirullah, by: $0) },
                    onReset: { dhikrService.setDhikrCount(.astaghfirullah, count: 0) }
                )

                // Alhamdulillah (gratitude)
                SacredDhikrCard(
                    type: .alhamdulillah,
                    count: stats.alhamdulillah,
                    goal: dhikrService.goal.alhamdulillah,
                    accentColor: softGreen,
                    onIncrement: { dhikrService.incrementDhikr(.alhamdulillah, by: $0) },
                    onReset: { dhikrService.setDhikrCount(.alhamdulillah, count: 0) }
                )

                // SubhanAllah (glorification)
                SacredDhikrCard(
                    type: .subhanAllah,
                    count: stats.subhanAllah,
                    goal: dhikrService.goal.subhanAllah,
                    accentColor: sacredGold,
                    onIncrement: { dhikrService.incrementDhikr(.subhanAllah, by: $0) },
                    onReset: { dhikrService.setDhikrCount(.subhanAllah, count: 0) }
                )
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Monthly Section
    private var monthlySection: some View {
        MonthlyActivityContainerRedesigned(
            dhikrService: dhikrService,
            sacredGold: sacredGold,
            softGreen: softGreen,
            forgivenessPurple: forgivenessPurple
        )
    }

    // MARK: - Lifetime Section
    private var lifetimeSection: some View {
        let allTimeTotal = dhikrService.getAllTimeTotal()
        let allStats = dhikrService.getAllDhikrStats()
        let activeDays = allStats.filter { $0.total > 0 }.count
        let dailyAverage = activeDays > 0 ? allTimeTotal / activeDays : 0
        let bestDay = allStats.max(by: { $0.total < $1.total })?.total ?? 0

        // Calculate totals by type
        let totalSubhanAllah = allStats.reduce(0) { $0 + $1.subhanAllah }
        let totalAlhamdulillah = allStats.reduce(0) { $0 + $1.alhamdulillah }
        let totalAstaghfirullah = allStats.reduce(0) { $0 + $1.astaghfirullah }

        return VStack(alignment: .leading, spacing: 24) {
            Text("LIFETIME JOURNEY")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 32) {
                // Total with elegant presentation
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(allTimeTotal.formatted())")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(sacredGold)

                    Text("total remembrances")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }

                // Subtle divider
                Rectangle()
                    .fill(sacredGold.opacity(0.3))
                    .frame(width: 40, height: 1)

                // Stats row
                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(activeDays)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(theme.primaryText)
                        Text("days")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dailyAverage)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(theme.primaryText)
                        Text("daily avg")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(bestDay)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(theme.primaryText)
                        Text("best day")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)

            // Breakdown by Type
            VStack(alignment: .leading, spacing: 16) {
                Text("BY TYPE")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    lifetimeBreakdownRow(
                        arabicText: "أستغفر الله",
                        name: "Astaghfirullah",
                        meaning: "I seek forgiveness",
                        count: totalAstaghfirullah,
                        total: allTimeTotal,
                        color: forgivenessPurple
                    )

                    lifetimeBreakdownRow(
                        arabicText: "الحمد لله",
                        name: "Alhamdulillah",
                        meaning: "Praise be to Allah",
                        count: totalAlhamdulillah,
                        total: allTimeTotal,
                        color: softGreen
                    )

                    lifetimeBreakdownRow(
                        arabicText: "سبحان الله",
                        name: "SubhanAllah",
                        meaning: "Glory be to Allah",
                        count: totalSubhanAllah,
                        total: allTimeTotal,
                        color: sacredGold
                    )
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func lifetimeBreakdownRow(arabicText: String, name: String, meaning: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0

        return HStack(spacing: 16) {
            // Arabic text
            Text(arabicText)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundColor(theme.primaryText)
                .frame(width: 100, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Text("• \(percentage)%")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                }

                Text(meaning)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            Text("\(count.formatted())")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Helpers
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000.0)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Sacred Dhikr Card
struct SacredDhikrCard: View {
    let type: DhikrType
    let count: Int
    let goal: Int
    let accentColor: Color
    let onIncrement: (Int) -> Void
    let onReset: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingInputSheet = false

    private var theme: AppTheme { themeManager.theme }

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1.0)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            VStack(alignment: .leading, spacing: 20) {
                // Arabic text - PROMINENT
                Text(type.arabicText)
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .foregroundColor(theme.primaryText)

                // English transliteration
                Text(type.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.secondaryText)

                // Count and goal
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Button(action: {
                        showingInputSheet = true
                    }) {
                        Text("\(count)")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(accentColor)
                    }

                    Text("/ \(goal)")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(theme.secondaryText)

                    Spacer()

                    // Circular progress indicator
                    ZStack {
                        Circle()
                            .stroke(accentColor.opacity(0.15), lineWidth: 3)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(progress * 100))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }

                // Thin progress line
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(accentColor.opacity(0.15))
                            .frame(height: 2)

                        Rectangle()
                            .fill(accentColor)
                            .frame(width: geometry.size.width * progress, height: 2)
                            .animation(.easeOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 2)
            }
            .padding(24)

            // Action buttons - subtle, refined
            HStack(spacing: 12) {
                SacredIncrementButton(label: "+1", color: accentColor) {
                    onIncrement(1)
                }

                SacredIncrementButton(label: "+10", color: accentColor) {
                    onIncrement(10)
                }

                SacredIncrementButton(label: "+33", color: accentColor) {
                    onIncrement(33)
                }

                Spacer()

                Button(action: {
                    HapticManager.shared.impact(.light)
                    onReset()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.secondaryText.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingInputSheet) {
            DhikrInputSheet(
                currentCount: count,
                color: accentColor,
                dhikrType: type,
                onSave: { newValue in
                    if newValue >= 0 {
                        let difference = newValue - count
                        if difference > 0 {
                            onIncrement(difference)
                        } else if difference < 0 {
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

// MARK: - Sacred Increment Button
struct SacredIncrementButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 56, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.1))
                )
        }
        .buttonStyle(SacredButtonStyle())
    }
}

// MARK: - Sacred Button Style
struct SacredButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Monthly Activity Container Redesigned
struct MonthlyActivityContainerRedesigned: View {
    @ObservedObject var dhikrService: DhikrService
    let sacredGold: Color
    let softGreen: Color
    let forgivenessPurple: Color

    @State private var selectedMonth = Date()
    @State private var selectedDayStats: DailyDhikrStats?
    @StateObject private var themeManager = ThemeManager.shared

    private var theme: AppTheme { themeManager.theme }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("MONTHLY REFLECTION")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 24)

            VStack(spacing: 24) {
                // Month navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }

                    Spacer()

                    Text(monthYearString)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                    }
                }

                // Calendar grid
                SacredCalendarView(
                    month: selectedMonth,
                    dhikrService: dhikrService,
                    onDayTapped: { stats in
                        selectedDayStats = stats
                    },
                    accentColor: sacredGold
                )

                // Legend - more subtle
                HStack(spacing: 6) {
                    Text("Less")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)

                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(sacredGold.opacity(0.15 + Double(index) * 0.2))
                            .frame(width: 16, height: 16)
                    }

                    Text("More")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)

            // Monthly Statistics
            monthlyStatisticsView()
        }
        .sheet(item: $selectedDayStats) { stats in
            SacredDayDetailSheet(
                stats: stats,
                sacredGold: sacredGold,
                softGreen: softGreen,
                forgivenessPurple: forgivenessPurple
            )
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonth = newMonth
            }
        }
    }

    // MARK: - Monthly Statistics
    private func monthlyStatisticsView() -> some View {
        let monthStats = getMonthStats()
        let lastMonthStats = getLastMonthStats()
        let percentageChange = calculatePercentageChange(current: monthStats.total, previous: lastMonthStats.total)

        return VStack(spacing: 20) {
            // Main stats card
            VStack(alignment: .leading, spacing: 20) {
                Text(monthYearString.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(theme.secondaryText)

                Text("\(formatNumber(monthStats.total))")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(theme.primaryText)

                Text("total remembrances")
                    .font(.system(size: 13))
                    .foregroundColor(theme.secondaryText)

                Rectangle()
                    .fill(sacredGold.opacity(0.4))
                    .frame(width: 40, height: 1)

                HStack(spacing: 32) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(monthStats.dailyAverage)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(theme.primaryText)
                        Text("daily avg")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(percentageChange >= 0 ? "+\(Int(percentageChange))%" : "\(Int(percentageChange))%")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(percentageChange >= 0 ? softGreen : Color(red: 0.8, green: 0.4, blue: 0.4))

                            Image(systemName: percentageChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 12))
                                .foregroundColor(percentageChange >= 0 ? softGreen : Color(red: 0.8, green: 0.4, blue: 0.4))
                        }
                        Text("vs last month")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)

            // Best Day & Goals Met
            HStack(spacing: 16) {
                // Best Day
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(monthStats.bestDay.count)")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(sacredGold)

                    Text("best day")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)

                    Text(monthStats.bestDay.dateString)
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                        )
                )

                // Goals Met
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(monthStats.goalsMetPercentage)%")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(softGreen)

                    Text("goals met")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)

                    Text("of active days")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)

            // Distribution by Type
            VStack(alignment: .leading, spacing: 16) {
                Text("DISTRIBUTION")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(theme.secondaryText)

                HStack(spacing: 12) {
                    distributionItem(
                        name: "Astaghfirullah",
                        count: monthStats.astaghfirullah,
                        total: monthStats.total,
                        color: forgivenessPurple
                    )
                    distributionItem(
                        name: "Alhamdulillah",
                        count: monthStats.alhamdulillah,
                        total: monthStats.total,
                        color: softGreen
                    )
                    distributionItem(
                        name: "SubhanAllah",
                        count: monthStats.subhanAllah,
                        total: monthStats.total,
                        color: sacredGold
                    )
                }
            }
            .padding(.horizontal, 24)

            // Most Active Times
            mostActiveTimesView(timeBreakdown: monthStats.timeBreakdown)
        }
    }

    private func distributionItem(name: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(percentage * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }

            Text(name.prefix(6) + "...")
                .font(.system(size: 10))
                .foregroundColor(theme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func mostActiveTimesView(timeBreakdown: TimeBreakdown) -> some View {
        let hasTimeData = timeBreakdown.morning > 0 || timeBreakdown.afternoon > 0 ||
                          timeBreakdown.evening > 0 || timeBreakdown.night > 0

        return VStack(alignment: .leading, spacing: 16) {
            Text("ACTIVE TIMES")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(theme.secondaryText)

            if hasTimeData {
                VStack(spacing: 12) {
                    timeSlotRow(label: "Morning", time: "6am-12pm", percentage: timeBreakdown.morning)
                    timeSlotRow(label: "Afternoon", time: "12pm-6pm", percentage: timeBreakdown.afternoon)
                    timeSlotRow(label: "Evening", time: "6pm-10pm", percentage: timeBreakdown.evening)
                    timeSlotRow(label: "Night", time: "10pm-6am", percentage: timeBreakdown.night)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 12) {
                    Text("Time breakdown will appear")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                    Text("as you practice throughout the day")
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func timeSlotRow(label: String, time: String, percentage: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primaryText)
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(theme.secondaryText)
            }
            .frame(width: 80, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(sacredGold.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(sacredGold)
                        .frame(width: geometry.size.width * (Double(percentage) / 100), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(percentage)%")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(sacredGold)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Data Helpers
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
        let bestDayString = bestDayStats != nil ? dateFormatter.string(from: bestDayDate) : "—"

        let goal = dhikrService.goal
        let totalGoal = goal.subhanAllah + goal.alhamdulillah + goal.astaghfirullah
        let daysWithGoalsMet = monthlyStats.filter { stats in
            stats.total >= totalGoal
        }.count
        let goalsMetPercentage = activeDays > 0 ? (daysWithGoalsMet * 100) / activeDays : 0

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
        guard let firstDate = stats.first?.date,
              let lastDate = stats.last?.date else {
            return TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        }

        let entries = dhikrService.getEntries(from: min(firstDate, lastDate), to: max(firstDate, lastDate))

        guard !entries.isEmpty else {
            return TimeBreakdown(morning: 0, afternoon: 0, evening: 0, night: 0)
        }

        let breakdown = dhikrService.calculateTimeBreakdown(for: entries)
        let total = breakdown.morning + breakdown.afternoon + breakdown.evening + breakdown.night

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
                total: 0, subhanAllah: 0, alhamdulillah: 0, astaghfirullah: 0,
                dailyAverage: 0, bestDay: (0, "—"), goalsMetPercentage: 0,
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
            total: totalDhikr, subhanAllah: 0, alhamdulillah: 0, astaghfirullah: 0,
            dailyAverage: 0, bestDay: (0, "—"), goalsMetPercentage: 0,
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
}

// MARK: - Sacred Calendar View
struct SacredCalendarView: View {
    let month: Date
    @ObservedObject var dhikrService: DhikrService
    let onDayTapped: (DailyDhikrStats) -> Void
    let accentColor: Color

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    let days = ["S", "M", "T", "W", "T", "F", "S"]

    private var calendar: Calendar { Calendar.current }

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

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = (geometry.size.width - 24) / 7

            VStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.secondaryText)
                            .frame(width: cellWidth)
                    }
                }

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(monthDates, id: \.self) { date in
                        let day = calendar.component(.day, from: date)
                        let isInCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)

                        if isInCurrentMonth {
                            SacredDayCell(
                                day: day,
                                stats: getStats(for: date),
                                maxTotal: maxDhikrTotal,
                                accentColor: accentColor,
                                onTap: {
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

// MARK: - Sacred Day Cell
struct SacredDayCell: View {
    let day: Int
    let stats: DailyDhikrStats?
    let maxTotal: Int
    let accentColor: Color
    let onTap: () -> Void

    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    private var cellBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.15, green: 0.16, blue: 0.18)
            : Color(red: 0.95, green: 0.94, blue: 0.92)
    }

    private var intensity: Double {
        guard let stats = stats, stats.total > 0, maxTotal > 0 else { return 0 }
        return Double(stats.total) / Double(maxTotal)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(intensity > 0 ? accentColor.opacity(0.25 + intensity * 0.6) : cellBackground)
                    .frame(height: 40)

                Text("\(day)")
                    .font(.system(size: 14, weight: intensity > 0.5 ? .medium : .regular))
                    .foregroundColor(intensity > 0.5 ? .white : theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sacred Day Detail Sheet
struct SacredDayDetailSheet: View {
    let stats: DailyDhikrStats
    let sacredGold: Color
    let softGreen: Color
    let forgivenessPurple: Color

    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    private var theme: AppTheme { themeManager.theme }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(spacing: 32) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("REFLECTION")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(theme.secondaryText)

                    Text(formattedDate)
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(theme.primaryText)
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(theme.secondaryText.opacity(0.1))
                        )
                }
            }
            .padding(.top, 24)

            if stats.total > 0 {
                // Total count
                VStack(spacing: 8) {
                    Text("\(stats.total)")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundColor(sacredGold)

                    Text("remembrances")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical, 16)

                // Breakdown
                VStack(spacing: 12) {
                    sacredStatRow(
                        arabicText: "أستغفر الله",
                        name: "Astaghfirullah",
                        count: stats.astaghfirullah,
                        color: forgivenessPurple
                    )
                    sacredStatRow(
                        arabicText: "الحمد لله",
                        name: "Alhamdulillah",
                        count: stats.alhamdulillah,
                        color: softGreen
                    )
                    sacredStatRow(
                        arabicText: "سبحان الله",
                        name: "SubhanAllah",
                        count: stats.subhanAllah,
                        color: sacredGold
                    )
                }
            } else {
                // No dhikr message
                VStack(spacing: 16) {
                    Text("—")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(theme.secondaryText)

                    Text("No practice recorded")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(theme.primaryText)

                    Text("on this day")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.vertical, 40)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(pageBackground)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private func sacredStatRow(arabicText: String, name: String, count: Int, color: Color) -> some View {
        HStack(spacing: 16) {
            Text(arabicText)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(theme.primaryText)
                .frame(width: 90, alignment: .leading)

            Text(name)
                .font(.system(size: 14))
                .foregroundColor(theme.secondaryText)

            Spacer()

            Text("\(count)")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(color)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: stats.date)
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

// MARK: - Preview
#Preview {
    NavigationView {
        DhikrWidgetView()
            .environmentObject(DhikrService.shared)
            .environmentObject(BluetoothService())
            .environmentObject(AudioPlayerService.shared)
    }
}
