//
//  ProfileView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher

struct ProfileView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var bluetoothService: BluetoothService
    @State private var showingSettings = false
    @State private var showingHighestStreak = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Profile Header
                profileHeader

                // Statistics
                statisticsSection

                // Zikr Ring
                zikrRingSection

                // Settings
                settingsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, audioPlayerService.currentSurah != nil ? 90 : 0)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Profile Image with enhanced design
            ZStack {
            Circle()
                .fill(
                    LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.8),
                                Color.pink.opacity(0.6)
                            ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                
                    Image(systemName: "person.fill")
                    .font(.system(size: 45, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // User Info with better typography
            VStack(spacing: 6) {
                Text("QariVerse User")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Member since 2024")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Enhanced Dhikr Stats
            let stats = dhikrService.getTodayStats()
            HStack(spacing: 32) {
                StatPill(
                    value: "\(stats.streak)",
                    label: "Day Streak",
                    color: .orange,
                    icon: "flame.fill"
                )
                
                StatPill(
                    value: "\(stats.total)",
                    label: "Today's Dhikr",
                    color: .green,
                    icon: "heart.fill"
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Your Statistics")
                        .font(.title2)
                        .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                }
                
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                EnhancedStatCard(
                    title: "Total Listening",
                    value: audioPlayerService.getTotalListeningTimeString(),
                    icon: "headphones",
                    gradient: [.blue, .cyan],
                    description: "Time spent listening"
                )
                
                EnhancedStatCard(
                    title: "Surahs Completed",
                    value: "\(audioPlayerService.getCompletedSurahCount())",
                    icon: "checkmark.seal.fill",
                    gradient: [.purple, .pink],
                    description: "Chapters finished"
                )
                
                EnhancedStatCard(
                    title: "Favorite Reciter",
                    value: getMostListenedReciter(),
                    icon: "person.fill",
                    gradient: [.green, .mint],
                    description: "Most played",
                    isLarge: true
                )
                
                InteractiveStreakCard(
                    dhikrService: dhikrService,
                    showingHighest: $showingHighestStreak
                )
            }
        }
    }
    
    // MARK: - Zikr Ring Section
    private var zikrRingSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
            Text("Zikr Ring")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                    .font(.title3)
            }

            VStack(spacing: 16) {
                // Status and Ring Count in a more visual way
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                HStack {
                            Circle()
                                .fill(bluetoothService.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            
                            Text("Status")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        }
                        
                    Text(bluetoothService.connectionStatus)
                            .font(.title3)
                            .fontWeight(.semibold)
                        .foregroundColor(bluetoothService.isConnected ? .green : .orange)
                }

                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Ring Count")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                    Text("\(bluetoothService.dhikrCount)")
                            .font(.title)
                        .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: {
                        if bluetoothService.isConnected {
                            bluetoothService.disconnectActive()
                        } else if let first = bluetoothService.discoveredRings.first {
                            bluetoothService.connectToDiscoveredRing(id: first.id)
                        } else {
                            bluetoothService.startScanning()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: bluetoothService.isConnected ? "xmark.circle.fill" : (bluetoothService.isScanning ? "antenna.radiowaves.left.and.right" : "magnifyingglass"))
                                .font(.title3)
                            
                            Text(bluetoothService.isConnected ? "Disconnect Ring" : (bluetoothService.isScanning ? "Scanning…" : "Scan for Rings"))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: bluetoothService.isConnected ? 
                                    [Color.red, Color.red.opacity(0.8)] : 
                                    [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: (bluetoothService.isConnected ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if !bluetoothService.isConnected && bluetoothService.isScanning && bluetoothService.discoveredRings.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .padding(.trailing, 8)
                            Text("Looking for Zikr rings nearby...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                    
                    if !bluetoothService.isConnected && !bluetoothService.discoveredRings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Available Zikr Rings")
                                    .font(.subheadline).fontWeight(.semibold)
                                Spacer()
                                Button("Stop") { bluetoothService.stopScanning(withMessage: "Scan stopped") }
                                    .font(.caption)
                            }
                            ForEach(bluetoothService.discoveredRings.sorted(by: { $0.rssi > $1.rssi })) { ring in
                                Button(action: { bluetoothService.connectToDiscoveredRing(id: ring.id) }) {
                                    HStack {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .foregroundColor(.blue)
                                        Text(ring.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("RSSI \(ring.rssi)")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(10)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
            Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
            }
            
            VStack(spacing: 12) {
                NavigationLink(destination: DhikrWidgetView()) {
                    EnhancedQuickActionRow(
                        title: "Dhikr Tracker",
                        subtitle: "Track your daily dhikr progress",
                        icon: "heart.fill",
                        gradient: [.green, .mint]
                    )
                }
                
                NavigationLink(destination: DhikrGoalsView()) {
                    EnhancedQuickActionRow(
                        title: "Dhikr Goals",
                        subtitle: "Set and manage your daily targets",
                        icon: "target",
                        gradient: [.blue, .cyan]
                    )
                }
                
                Button(action: {
                    // Show favorites - for now just show a placeholder
                    print("Favorites tapped")
                }) {
                    EnhancedQuickActionRow(
                        title: "Favorites",
                        subtitle: "Your saved recitations",
                        icon: "heart.fill",
                        gradient: [.red, .pink]
                    )
                }
                
                Button(action: {
                    // Show listening history
                    print("Listening history tapped")
                }) {
                    EnhancedQuickActionRow(
                        title: "Listening History",
                        subtitle: "View your recent activity",
                        icon: "clock.fill",
                        gradient: [.purple, .indigo]
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
            Text("Recent Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
            
            VStack(spacing: 8) {
                ForEach(getRecentActivity()) { activity in
                    EnhancedActivityRow(activity: activity)
                }
            }
        }
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings & More")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                // Dhikr Goals
                NavigationLink(destination: DhikrGoalsView()
                    .environmentObject(dhikrService)
                    .environmentObject(audioPlayerService)
                    .environmentObject(bluetoothService)
                ) {
                    SettingsRow(
                        icon: "target",
                        iconColor: .blue,
                        title: "Dhikr Goals",
                        showChevron: true
                    )
                }

                Divider()
                    .padding(.leading, 44)

                // Settings
                Button(action: { showingSettings = true }) {
                    SettingsRow(
                        icon: "gearshape.fill",
                        iconColor: .gray,
                        title: "Settings",
                        showChevron: true
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Settings Row Component
    private func SettingsRow(icon: String, iconColor: Color, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .cornerRadius(6)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    // MARK: - Helper Methods
    private func getRecentActivity() -> [ActivityItem] {
        var activities: [ActivityItem] = []
        
        // Add current playing activity if any
        if let currentSurah = audioPlayerService.currentSurah,
           let currentReciter = audioPlayerService.currentReciter {
            activities.append(ActivityItem(
                id: "current",
                type: .listened,
                title: "Currently Playing: \(currentSurah.englishName)",
                subtitle: currentReciter.englishName,
                time: "Now",
                icon: "play.circle.fill"
            ))
        }
        
        // Add last played activity
        if let lastPlayed = audioPlayerService.getLastPlayedInfo() {
            activities.append(ActivityItem(
                id: "last",
                type: .listened,
                title: "Last Played: \(lastPlayed.surah.englishName)",
                subtitle: lastPlayed.reciter.englishName,
                time: "Recently",
                icon: "headphones"
            ))
        }
        
        // Add dhikr activity
        let stats = dhikrService.getTodayStats()
        if stats.total > 0 {
            activities.append(ActivityItem(
                id: "dhikr",
                type: .dhikr,
                title: "Completed \(stats.total) Dhikr",
                subtitle: "Today's progress",
                time: "Today",
                icon: "heart.fill"
            ))
        }
        
        // If no activities, show placeholder
        if activities.isEmpty {
            activities.append(ActivityItem(
                id: "placeholder",
                type: .listened,
                title: "No recent activity",
                subtitle: "Start listening to see your activity",
                time: "Never",
                icon: "info.circle"
            ))
        }
        
        return activities
    }
    
    private func getCompletedSurahs() -> Int {
        // For now, return a placeholder. In a real app, you'd track completed surahs
        return UserDefaults.standard.integer(forKey: "completedSurahs")
    }
    
    private func getMostListenedReciter() -> String {
        let recentItems = RecentsManager.shared.recentItems
        
        // Count occurrences of each reciter
        var reciterCounts: [String: Int] = [:]
        for item in recentItems {
            let reciterName = item.reciter.englishName
            reciterCounts[reciterName, default: 0] += 1
        }
        
        // Find the most listened reciter
        if let mostListened = reciterCounts.max(by: { $0.value < $1.value }) {
            if mostListened.value == 1 {
                return mostListened.key
            } else {
                return "\(mostListened.key)"
            }
        }
        
        return "None"
    }
}

// MARK: - Enhanced Supporting Views

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct EnhancedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    let description: String
    var isLarge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Spacer()
                
                if !isLarge {
                    Circle()
                        .fill(gradient[0].opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(isLarge ? .title : .title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(isLarge ? 2 : 1)
                    .minimumScaleFactor(0.8)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [gradient[0].opacity(0.3), gradient[1].opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: gradient[0].opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .gridCellColumns(isLarge ? 2 : 1)
            }
        }

struct EnhancedQuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        )
    }
}

struct EnhancedActivityRow: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(getColor(for: activity.type).opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: activity.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(getColor(for: activity.type))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Circle()
                    .fill(getColor(for: activity.type))
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func getColor(for type: ActivityType) -> Color {
        switch type {
        case .listened: return .blue
        case .dhikr: return .green
        case .completed: return .purple
        }
    }
}

// MARK: - Legacy Supporting Views (keeping for compatibility)
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ActivityRow: View {
    let activity: ActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .foregroundColor(getColor(for: activity.type))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(activity.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(activity.time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func getColor(for type: ActivityType) -> Color {
        switch type {
        case .listened: return .blue
        case .dhikr: return .green
        case .completed: return .purple
        }
    }
}

// MARK: - Activity Types
enum ActivityType {
    case listened
    case dhikr
    case completed
}

struct ActivityItem: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let time: String
    let icon: String
}

// MARK: - Interactive Streak Card
struct InteractiveStreakCard: View {
    @ObservedObject var dhikrService: DhikrService
    @Binding var showingHighest: Bool
    @State private var isAnimating = false
    
    var body: some View {
        let streakInfo = dhikrService.getHighestStreakInfo()
        let currentValue = showingHighest ? streakInfo.highest : streakInfo.current
        let currentTitle = showingHighest ? "Highest Streak" : "Current Streak"
        let currentDescription = showingHighest ? streakInfo.achievement : "Days in a row"
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: showingHighest ? [.red, .orange] : [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                
                Spacer()
                
                if showingHighest && streakInfo.isCurrentBest {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                } else {
                    Circle()
                        .fill((showingHighest ? Color.red : Color.orange).opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(currentValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    
                    if showingHighest && streakInfo.current > 0 && !streakInfo.isCurrentBest {
                        Text("(Current: \(streakInfo.current))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingHighest)
                
                Text(currentTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showingHighest)
                
                Text(currentDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showingHighest)
            }
            
            // Tap indicator
            HStack {
                Spacer()
                Text(showingHighest ? "Tap for current" : "Tap for highest")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: showingHighest ? 
                                    [Color.red.opacity(0.3), Color.orange.opacity(0.1)] :
                                    [Color.orange.opacity(0.3), Color.yellow.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: (showingHighest ? Color.red : Color.orange).opacity(0.1), 
                    radius: 8, x: 0, y: 4
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingHighest.toggle()
                isAnimating = true
            }
            
            // Reset animation state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Enhanced Settings View with Theme Switcher
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                // Theme Section
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Choose your theme")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            ForEach(AppThemeStyle.allCases, id: \.self) { theme in
                                ThemePreviewCard(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme == theme,
                                    action: {
                                        withAnimation(.spring()) {
                                            themeManager.currentTheme = theme
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
                } header: {
                    HStack {
                        Image(systemName: "paintbrush.fill")
                            .foregroundColor(.blue)
                        Text("Theme")
                    }
                }

                // Wallpaper selection for Liquid Glass theme only
                if themeManager.currentTheme == .liquidGlass {
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose Wallpaper")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ThemeManager.availableWallpapers, id: \.self) { wallpaperName in
                                        WallpaperThumbnail(
                                            wallpaperName: wallpaperName,
                                            isSelected: themeManager.selectedWallpaper == wallpaperName,
                                            onSelect: {
                                                themeManager.selectedWallpaper = wallpaperName
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundColor(.purple)
                            Text("Wallpaper")
                        }
                    }
                }

                Section("Audio") {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Auto-play next surah")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Sleep timer")
                        Spacer()
                        Text("Off")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Prayer reminders")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                    }
                    
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        Text("Dhikr reminders")
                        Spacer()
                        Toggle("", isOn: .constant(false))
                            .labelsHidden()
                    }
                }
                
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Contact Support")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        Text("Rate Us")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Wallpaper Thumbnail View
struct WallpaperThumbnail: View {
    let wallpaperName: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if let image = loadWallpaperImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 120)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                Text(getDisplayName())
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 4)
                            }
                        )
                }

                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .background(Color.white.clipShape(Circle()))
                        }
                        Spacer()
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func loadWallpaperImage() -> UIImage? {
        // Try to load from bundle with wallpapers/ prefix
        if let path = Bundle.main.path(forResource: "wallpapers/\(wallpaperName)", ofType: nil),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        // Try without wallpapers/ prefix
        if let image = UIImage(named: wallpaperName) {
            return image
        }

        // Fallback: try source directory for development
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/Dhikr/wallpapers/\(wallpaperName)"
        if let image = UIImage(contentsOfFile: sourcePath) {
            return image
        }

        return nil
    }

    private func getDisplayName() -> String {
        // Extract a simple name from the filename
        let name = wallpaperName
            .replacingOccurrences(of: ".jpg", with: "")
            .replacingOccurrences(of: ".jpeg", with: "")
            .replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".webp", with: "")

        // Return a shortened version if it's too long
        if name.count > 15 {
            return String(name.prefix(12)) + "..."
        }
        return name
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
    ProfileView()
        .environmentObject(DhikrService.shared)
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(BluetoothService())
} 
} 
