//
//  ProfileView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var backTapService: BackTapService
    @State private var showingSettings = false
    @State private var showingBackTapSettings = false
    @State private var showingBackTapTest = false
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Statistics
                        statisticsSection
                        
                        // Zikr Ring
                        zikrRingSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Recent Activity
                        recentActivitySection
                        
                        // Settings
                        settingsSection
                    }
                    .padding(.horizontal, 16)
                .padding(.bottom, audioPlayerService.currentSurah != nil ? 90 : 0)
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
                .background(Color(.systemBackground))
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showingBackTapSettings) {
                    BackTapSettingsView()
                }
                .sheet(isPresented: $showingBackTapTest) {
                    BackTapTestView()
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                )
            
            // User Info
            VStack(spacing: 4) {
                Text("QariVerse User")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Member since 2024")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Dhikr Streak
            let stats = dhikrService.getTodayStats()
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
                    Text("\(stats.total)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Today's Dhikr")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Zikr Ring Section
    private var zikrRingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zikr Ring")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(bluetoothService.connectionStatus)
                        .fontWeight(.medium)
                        .foregroundColor(bluetoothService.isConnected ? .green : .orange)
                }

                HStack {
                    Text("Ring Count:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(bluetoothService.dhikrCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Button(action: {
                    if bluetoothService.isConnected {
                        bluetoothService.disconnect()
                    } else {
                        bluetoothService.startScanning()
                    }
                }) {
                    HStack {
                        Image(systemName: bluetoothService.isConnected ? "xmark.circle.fill" : "magnifyingglass")
                        Text(bluetoothService.isConnected ? "Disconnect" : "Scan for Ring")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(bluetoothService.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total Listening",
                    value: audioPlayerService.getTotalListeningTimeString(),
                    icon: "headphones",
                    color: .blue
                )
                
                StatCard(
                    title: "Surahs Completed",
                    value: "\(audioPlayerService.getCompletedSurahCount())",
                    icon: "checkmark.seal.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Most Listened Reciter",
                    value: getMostListenedReciter(),
                    icon: "person.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Day Streak",
                    value: "\(dhikrService.getTodayStats().streak)",
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                NavigationLink(destination: DhikrWidgetView()) {
                    QuickActionRow(
                        title: "Dhikr Tracker",
                        subtitle: "Track your daily dhikr",
                        icon: "heart.fill",
                        color: .green
                    )
                }
                
                Button(action: {
                    // Show favorites - for now just show a placeholder
                    print("Favorites tapped")
                }) {
                    QuickActionRow(
                        title: "Favorites",
                        subtitle: "Your saved recitations",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                Button(action: {
                    // Show listening history
                    print("Listening history tapped")
                }) {
                    QuickActionRow(
                        title: "Listening History",
                        subtitle: "Recently played surahs",
                        icon: "clock.fill",
                        color: .blue
                    )
                }
            }
        }
    }
    
    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(getRecentActivity(), id: \.id) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }
    
    // MARK: - Get Recent Activity
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
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button(action: {
                    showingSettings = true
                }) {
                    QuickActionRow(
                        title: "App Settings",
                        subtitle: "Audio quality, notifications",
                        icon: "gear",
                        color: .gray
                    )
                }
                
                Button(action: {
                    showingBackTapSettings = true
                }) {
                    QuickActionRow(
                        title: "Back Tap Settings",
                        subtitle: backTapService.isEnabled ? "Double tap: \(backTapService.doubleTapType.rawValue)" : "Disabled",
                        icon: "hand.tap",
                        color: backTapService.isEnabled ? .green : .gray
                    )
                }
                
                Button(action: {
                    showingBackTapTest = true
                }) {
                    QuickActionRow(
                        title: "Test Back Tap",
                        subtitle: "Try the back tap functionality",
                        icon: "hand.tap.fill",
                        color: .blue
                    )
                }
                
                Button(action: {
                    // Show about
                }) {
                    QuickActionRow(
                        title: "About QariVerse",
                        subtitle: "Version 1.0.0",
                        icon: "info.circle.fill",
                        color: .blue
                    )
                }
                
                // Liked
                NavigationLink(destination: LikedSurahsView()) {
                    SettingsRow(
                        imageName: "heart.fill",
                        title: "Liked",
                        value: "\(audioPlayerService.likedItems.count) Tracks"
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatListeningTime() -> String {
        // For now, return a placeholder. In a real app, you'd track this in UserDefaults
        let totalMinutes = UserDefaults.standard.integer(forKey: "totalListeningMinutes")
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func getFavoriteReciter() -> String {
        // For now, return the current reciter or a placeholder
        if let currentReciter = audioPlayerService.currentReciter {
            return currentReciter.englishName
        } else if let lastPlayed = audioPlayerService.getLastPlayedInfo() {
            return lastPlayed.reciter.englishName
        } else {
            return "None"
        }
    }
    
    private func getCompletedSurahs() -> Int {
        // For now, return a placeholder. In a real app, you'd track completed surahs
        return UserDefaults.standard.integer(forKey: "completedSurahs")
    }
    
    private func getMostListenedReciter() -> String {
        // Implement logic to get the most listened reciter
        return "Not Implemented"
    }
}

// MARK: - Supporting Views
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
        case .listened:
            return .blue
        case .dhikr:
            return .green
        case .favorited:
            return .red
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var audioQuality = "High"
    @State private var notificationsEnabled = true
    @State private var autoPlay = false
    @State private var darkMode = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Audio") {
                    Picker("Audio Quality", selection: $audioQuality) {
                        Text("Low (128kbps)").tag("Low")
                        Text("Medium (192kbps)").tag("Medium")
                        Text("High (320kbps)").tag("High")
                    }
                    
                    Toggle("Auto-play next surah", isOn: $autoPlay)
                }
                
                Section("Notifications") {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        NavigationLink("Prayer time reminders") {
                            Text("Prayer time settings")
                        }
                        
                        NavigationLink("Dhikr reminders") {
                            Text("Dhikr reminder settings")
                        }
                    }
                }
                
                Section("Appearance") {
                    Toggle("Dark mode", isOn: $darkMode)
                }
                
                Section("Data") {
                    Button("Clear listening history") {
                        // Clear history
                    }
                    .foregroundColor(.red)
                    
                    Button("Export data") {
                        // Export data
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // Show privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // Show terms
                    }
                }
            }
            .navigationTitle("Settings")
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
}

// MARK: - Supporting Models
struct ActivityItem {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let time: String
    let icon: String
}

enum ActivityType {
    case listened
    case dhikr
    case favorited
}

// MARK: - Profile Settings Row
struct SettingsRow: View {
    var imageName: String
    var title: String
    var value: String?
    
    var body: some View {
        HStack {
            Image(systemName: imageName)
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProfileView()
        .environmentObject(DhikrService.shared)
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(BluetoothService())
        .environmentObject(BackTapService.shared)
} 