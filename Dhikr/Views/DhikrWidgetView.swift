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
            .navigationTitle("Dhikr Tracker")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .sheet(isPresented: $showingStats) {
                DhikrStatsView()
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
                    DhikrInputField(
                        type: dhikrType,
                        count: getCount(for: dhikrType),
                        isActive: bluetoothService.isConnected && bluetoothService.activeDhikrType == dhikrType
                    ) { newCount in
                        dhikrService.setDhikrCount(dhikrType, count: newCount)
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
                        .onAppear { editText = "\(count)"; isFocused = true }
                        .onSubmit { commitEdit() }
                        .onChange(of: isFocused) { focused in if !focused { commitEdit() } }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isFocused = false
                                }
                            }
                        }
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
    
    private let dayOrder = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var symmetricalStats: [DailyDhikrStats] {
        // Map stats to day name for lookup
        var statsByDay = Dictionary(uniqueKeysWithValues: stats.map { ($0.dayName, $0) })
        let calendar = Calendar.current
        let today = Date()
        // Find the most recent Sunday
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = (weekday + 6) % 7
        let lastSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        // Build 7 days starting from Sunday
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: lastSunday) ?? today
            let dayName = dayOrder[offset]
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
        let maxBarHeight: CGFloat = 120 // Use more vertical space
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(displayStats.enumerated()), id: \.offset) { idx, stat in
                        VStack(spacing: 6) {
                            // Bar
                            RoundedRectangle(cornerRadius: 6)
                                .fill(stat.isToday ? Color.green : Color.gray.opacity(0.3))
                                .frame(
                                    height: stat.total == 0 ? minBarHeight : max(minBarHeight, maxBarHeight * CGFloat(stat.total) / CGFloat(maxTotal))
                                )
                                .frame(maxWidth: .infinity)
                            // Day Label
                            Text(dayOrder[idx])
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: geometry.size.width / 7)
                    }
                }
                .frame(height: maxBarHeight + 24)
                Text("Total: \(displayStats.reduce(0) { $0 + $1.total }) this week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: geometry.size.width)
        }
        .frame(height: 160)
        .padding(.bottom, 32) // Use more space at the bottom
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