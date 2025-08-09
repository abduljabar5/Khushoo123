//
//  DhikrWidgetView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct DhikrWidgetView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingStats = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Stats
                    headerStats
                    
                    // Dhikr Counters
                    dhikrCounters
                    
                    // Motivational Message
                    motivationalSection
                    
                    // Weekly Stats
                    weeklyStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dhikr Tracker")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .sheet(isPresented: $showingStats) {
                DhikrHistoryView()
            }
        }
    }
    
    // MARK: - Header Stats
    private var headerStats: some View {
        let stats = dhikrService.getTodayStats()
        
        return VStack(spacing: 16) {
            // Total Count
            VStack(spacing: 8) {
                Text("\(stats.total)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("Total Dhikr Today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Streak
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(stats.streak)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Day Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text(stats.mostUsedDhikr.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Most Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Dhikr Counters
    private var dhikrCounters: some View {
        VStack(spacing: 16) {
            Text("Enter Your Count")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(DhikrType.allCases, id: \.self) { dhikrType in
                    VStack(spacing: 8) {
                    DhikrInputField(
                        type: dhikrType,
                        count: getCount(for: dhikrType),
                        isActive: bluetoothService.isConnected && bluetoothService.activeDhikrType == dhikrType
                    ) { newCount in
                        dhikrService.setDhikrCount(dhikrType, count: newCount)
                        }
                        GoalProgressView(dhikrType: dhikrType, dhikrService: dhikrService)
                    }
                }
            }
        }
    }
    
    // MARK: - Motivational Section
    private var motivationalSection: some View {
        VStack(spacing: 12) {
            Text("💫")
                .font(.title)
            
            Text(dhikrService.getMotivationalMessage())
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            Text("Every dhikr brings you closer to Allah")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    // MARK: - Weekly Stats Section
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    showingStats = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            WeeklyProgressChart(stats: dhikrService.getWeeklyStats())
        }
    }
    
    // MARK: - Helper Methods
    private func getCount(for type: DhikrType) -> Int {
        let stats = dhikrService.getTodayStats()
        switch type {
        case .subhanAllah:
            return stats.subhanAllah
        case .alhamdulillah:
            return stats.alhamdulillah
        case .astaghfirullah:
            return stats.astaghfirullah
        }
    }
}

// MARK: - Goal Progress View
struct GoalProgressView: View {
    let dhikrType: DhikrType
    @ObservedObject var dhikrService: DhikrService

    private var progress: Double {
        let count = Double(currentCount)
        let goal = Double(currentGoal)
        return goal > 0 ? min(count / goal, 1.0) : 0
    }

    private var currentCount: Int {
        let stats = dhikrService.getTodayStats()
        switch dhikrType {
        case .subhanAllah: return stats.subhanAllah
        case .alhamdulillah: return stats.alhamdulillah
        case .astaghfirullah: return stats.astaghfirullah
        }
    }

    private var currentGoal: Int {
        switch dhikrType {
        case .subhanAllah: return dhikrService.goal.subhanAllah
        case .alhamdulillah: return dhikrService.goal.alhamdulillah
        case .astaghfirullah: return dhikrService.goal.astaghfirullah
        }
    }
    
    private var color: Color {
        switch dhikrType {
        case .subhanAllah: return .blue
        case .alhamdulillah: return .green
        case .astaghfirullah: return .purple
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
            Text("\(currentCount) / \(currentGoal)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
    }
}


// MARK: - Dhikr Input Field
struct DhikrInputField: View {
    let type: DhikrType
    let count: Int
    let isActive: Bool
    let action: (Int) -> Void
    
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Arabic Text
            Text(type.arabicText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            // English Text
            Text(type.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            // Editable Count
            Group {
                if isEditing {
                    TextField("0", text: $editText)
                        .font(.title3.bold())
                        .foregroundColor(getColor(for: type))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .frame(width: 70)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isFocused = false
                                    commitEdit()
                                }
                                .fontWeight(.bold)
                            }
                        }
                        .onAppear { 
                            editText = "\(count)"
                            // Small delay to avoid conflicting with system keyboard management
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isFocused = true
                                }
                            }
                        .onSubmit { commitEdit() }
                        .onChange(of: isFocused) { focused in if !focused { commitEdit() } }
                } else {
                    Text("\(count)")
                        .font(.title3.bold())
                        .foregroundColor(getColor(for: type))
                        .onTapGesture {
                            isEditing = true
                        }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(getColor(for: type).opacity(0.3), lineWidth: 2)
                )
        )
        .shadow(
            color: isActive ? getColor(for: type) : .clear,
            radius: isActive ? 8 : 0,
            x: 0,
            y: 0
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
    
    private func commitEdit() {
        if let newCount = Int(editText), newCount >= 0 {
            action(newCount)
        }
        isEditing = false
    }
    
    private func getColor(for type: DhikrType) -> Color {
        switch type {
        case .subhanAllah:
            return .blue
        case .alhamdulillah:
            return .green
        case .astaghfirullah:
            return .purple
        }
    }
}

// MARK: - Weekly Progress Chart
struct WeeklyProgressChart: View {
    let stats: [DailyDhikrStats]
    @State private var selectedStat: DailyDhikrStats?
    
    private let dayOrder = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var symmetricalStats: [DailyDhikrStats] {
        let calendar = Calendar.current
        let today = Date()
        // Find the most recent Sunday
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = (weekday + 6) % 7
        let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        // Build 7 days starting from Sunday
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: lastSunday) ?? today
            if let stat = stats.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                return stat
            } else {
                return DailyDhikrStats(date: date, subhanAllah: 0, alhamdulillah: 0, astaghfirullah: 0, total: 0)
            }
        }
    }
    
    var body: some View {
        let displayStats = symmetricalStats
        let maxTotal = max(displayStats.map { $0.total }.max() ?? 1, 1)
        let minBarHeight: CGFloat = 8
        let maxBarHeight: CGFloat = 120

        VStack(spacing: 16) {
            // Header for selected day
            selectedDayHeader
                .padding(.horizontal, 8)

        GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(displayStats.enumerated()), id: \.offset) { idx, stat in
                        Button(action: {
                            withAnimation(.spring()) {
                                selectedStat = stat
                            }
                        }) {
                        VStack(spacing: 6) {
                            // Bar
                            RoundedRectangle(cornerRadius: 6)
                                    .fill(barColor(for: stat))
                                .frame(
                                    height: stat.total == 0 ? minBarHeight : max(minBarHeight, maxBarHeight * CGFloat(stat.total) / CGFloat(maxTotal))
                                )
                                .frame(maxWidth: .infinity)
                            // Day Label
                            Text(dayOrder[idx])
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                    .fontWeight(selectedStat?.dayName == stat.dayName ? .bold : .regular)
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Use plain style to avoid default button appearance
                        .frame(width: geometry.size.width / 7)
                    }
                }
                .frame(height: maxBarHeight + 24)
            }
            .frame(height: maxBarHeight + 24)

            // Total this week
                Text("Total: \(displayStats.reduce(0) { $0 + $1.total }) this week")
                    .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .onAppear {
            // Pre-select today's stats on appear
            if selectedStat == nil {
                selectedStat = symmetricalStats.first(where: { $0.isToday })
            }
        }
    }

    @ViewBuilder
    private var selectedDayHeader: some View {
        if let stat = selectedStat {
            VStack(alignment: .leading, spacing: 8) {
                Text(stat.isToday ? "Today's Dhikr" : stat.formattedDate)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if stat.total > 0 {
                    HStack(spacing: 16) {
                        DhikrCountPill(type: .subhanAllah, count: stat.subhanAllah)
                        DhikrCountPill(type: .alhamdulillah, count: stat.alhamdulillah)
                        DhikrCountPill(type: .astaghfirullah, count: stat.astaghfirullah)
                        Spacer()
                    }
                } else {
                    Text("No dhikr recorded for this day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 50) // Give a fixed height to prevent layout jumps
        } else {
            // Placeholder to prevent layout shift
            VStack {
                Text("Select a day to see details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 50)
        }
    }

    private func barColor(for stat: DailyDhikrStats) -> Color {
        if selectedStat?.dayName == stat.dayName {
            return .green
        } else if stat.isToday {
            return .green.opacity(0.6)
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// Pill view for displaying individual Dhikr counts
struct DhikrCountPill: View {
    let type: DhikrType
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(type.rawValue.prefix(1))
            Text("\(count)")
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(getColor(for: type).opacity(0.2))
        .foregroundColor(getColor(for: type))
        .cornerRadius(20)
    }

    private func getColor(for type: DhikrType) -> Color {
        switch type {
        case .subhanAllah: return .blue
        case .alhamdulillah: return .green
        case .astaghfirullah: return .purple
        }
    }
}

// MARK: - Dhikr Stats View
struct DhikrStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dhikrService: DhikrService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Detailed Stats
                    detailedStats
                    
                    // Weekly Chart
                    weeklyChart
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var detailedStats: some View {
        let stats = dhikrService.getTodayStats()
        
        return VStack(spacing: 16) {
            ForEach(DhikrType.allCases, id: \.self) { type in
                HStack {
                    Text(type.arabicText)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Text("\(getCount(for: type, stats: stats))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(getColor(for: type))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            WeeklyProgressChart(stats: dhikrService.getWeeklyStats())
        }
    }
    
    private func getCount(for type: DhikrType, stats: DhikrStats) -> Int {
        switch type {
        case .subhanAllah:
            return stats.subhanAllah
        case .alhamdulillah:
            return stats.alhamdulillah
        case .astaghfirullah:
            return stats.astaghfirullah
        }
    }
    
    private func getColor(for type: DhikrType) -> Color {
        switch type {
        case .subhanAllah:
            return .blue
        case .alhamdulillah:
            return .green
        case .astaghfirullah:
            return .purple
        }
    }
}

#Preview {
    DhikrWidgetView()
        .environmentObject(DhikrService.shared)
} 