//
//  ProfileView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var locationService: LocationService
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var prayerNotificationService = PrayerNotificationService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingHighestStreak = false
    @State private var showingAuth = false
    @State private var showingPaywall = false
    @State private var refreshID = UUID()
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @AppStorage("autoPlayNextSurah") private var autoPlayNextSurah = true
    @AppStorage("showSleepTimer") private var showSleepTimer = true
    @AppStorage("prayerRemindersEnabled") private var prayerRemindersEnabled = true
    @AppStorage("dhikrRemindersEnabled") private var dhikrRemindersEnabled = true
    @AppStorage("userDisplayName") private var userDisplayName: String = ""

    // Computed property for display name
    private var displayName: String {
        if authService.isAuthenticated {
            return authService.currentUser?.displayName ?? "User"
        } else if !userDisplayName.isEmpty {
            return userDisplayName
        } else {
            return "Welcome!"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Compact Profile Header
                compactProfileHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Sign In Prompt (only shown when not authenticated)
                if !authService.isAuthenticated {
                    signInPromptCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }

                // Quick Stats
                quickStatsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Statistics
                statisticsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Completed Surahs Section
                completedSurahsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Subscription Section
                subscriptionSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Appearance Section
                appearanceSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Audio Section
                audioSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Notifications Section
                notificationsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Zikr Ring
                zikrRingSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Dhikr Goals
                dhikrGoalsSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // About Section
                aboutSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                // Sign Out Section (only shown when authenticated)
                if authService.isAuthenticated {
                    signOutSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // Delete Account Section
                    deleteAccountSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            .padding(.bottom, audioPlayerService.currentSurah != nil ? 90 : 0)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.theme.primaryBackground)
        .sheet(isPresented: $showingAuth) {
            ModernAuthView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? Your authentication account will be permanently deleted, but your local progress (dhikr counts, streaks, prayer history) will be preserved.")
        }
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .onChange(of: authService.isAuthenticated) { _ in
            refreshID = UUID()
        }
        .onAppear {
            // Sync initial value
            audioPlayerService.isAutoplayEnabled = autoPlayNextSurah

            // Sync prayer reminders toggle from App Group
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
               let value = groupDefaults.object(forKey: "prayerRemindersEnabled") as? Bool {
                prayerRemindersEnabled = value
            }

            // Check and schedule notifications if enabled
            Task {
                if dhikrRemindersEnabled && prayerNotificationService.hasNotificationPermission {
                    scheduleDhikrReminders()
                }
            }
        }
        .id(refreshID)
    }

    // MARK: - Compact Profile Header
    private var compactProfileHeader: some View {
        HStack(spacing: 16) {
            // Profile Image
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.theme.primaryAccent,
                            themeManager.theme.primaryAccent.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                )

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.theme.primaryText)

                if authService.isAuthenticated, let joinDate = authService.currentUser?.joinDate {
                    Text("Member since \(joinDate.formatted(.dateTime.year()))")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryText)
                } else {
                    Text("Your spiritual journey companion")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }

            Spacer()
        }
    }

    // MARK: - Sign In Prompt Card
    private var signInPromptCard: some View {
        Button(action: {
            showingAuth = true
        }) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.theme.primaryAccent,
                                        themeManager.theme.primaryAccent.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)

                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sign In to Your Account")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Sync your progress across all devices")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.theme.primaryAccent)
                }
                .padding(20)

                // Benefits
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Sync your data across devices")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.primaryText)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Save your progress and streaks")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.primaryText)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Access premium features")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.primaryText)
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(themeManager.theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeManager.theme.primaryAccent.opacity(0.5),
                                        themeManager.theme.primaryAccent.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: themeManager.theme.primaryAccent.opacity(0.2),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        let stats = dhikrService.getTodayStats()
        return HStack(spacing: 12) {
            StatPill(
                value: "\(stats.streak)",
                label: "Day Streak",
                color: themeManager.theme.primaryAccent,
                icon: "flame.fill"
            )

            StatPill(
                value: "\(stats.total)",
                label: "Today's Dhikr",
                color: themeManager.theme.primaryAccent,
                icon: "heart.fill"
            )
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Statistics", icon: "chart.bar.fill")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                EnhancedStatCard(
                    title: "Total Listening",
                    value: audioPlayerService.getTotalListeningTimeString(),
                    icon: "headphones",
                    gradient: [themeManager.theme.primaryAccent, themeManager.theme.primaryAccent.opacity(0.7)],
                    description: "Time spent listening"
                )

                // Surahs Completed Card with integrated progress bar
                SurahsCompletedCard(completedCount: audioPlayerService.getCompletedSurahCount())

                EnhancedStatCard(
                    title: "Favorite Reciter",
                    value: getMostListenedReciter(),
                    icon: "person.fill",
                    gradient: [themeManager.theme.primaryAccent, themeManager.theme.primaryAccent.opacity(0.7)],
                    description: "Most played"
                )

                InteractiveStreakCard(
                    dhikrService: dhikrService,
                    showingHighest: $showingHighestStreak
                )
            }
        }
    }

    // MARK: - Completed Surahs Section
    private var completedSurahsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionHeader(title: "Completed Surahs", icon: "checkmark.seal.fill")
                Spacer()
                if audioPlayerService.completedSurahNumbers.count > 0 {
                    NavigationLink(destination: CompletedSurahsListView()) {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.primaryAccent)
                    }
                }
            }

            if audioPlayerService.completedSurahNumbers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No surahs completed yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Complete a surah to see it here ✨")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(themeManager.theme.cardBackground.opacity(0.3))
                .cornerRadius(16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(audioPlayerService.completedSurahNumbers).sorted(), id: \.self) { surahNumber in
                            CompletedSurahBadge(surahNumber: surahNumber)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Subscription Section
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: subscriptionService.isPremium ? "Premium" : "Upgrade", icon: "crown.fill")

            if subscriptionService.isPremium {
                // Premium user - show status and manage
                VStack(spacing: 0) {
                    settingsRow(
                        icon: "checkmark.seal.fill",
                        iconColor: themeManager.theme.accentGold,
                        title: "Premium Active",
                        trailing: {
                            Image(systemName: "crown.fill")
                                .foregroundColor(themeManager.theme.accentGold)
                        }
                    )

                    Divider()
                        .padding(.leading, 50)

                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    }) {
                        settingsRow(
                            icon: "arrow.clockwise",
                            iconColor: themeManager.theme.primaryAccent,
                            title: "Restore Purchases",
                            trailing: {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.tertiaryText)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(themeManager.theme.cardBackground)
                .cornerRadius(16)
            } else {
                // Free user - show upgrade prompt
                Button(action: {
                    showingPaywall = true
                }) {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unlock Premium")
                                    .font(.headline)
                                    .foregroundColor(themeManager.theme.primaryText)

                                Text("Get full access to all features")
                                    .font(.caption)
                                    .foregroundColor(themeManager.theme.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(themeManager.theme.tertiaryText)
                        }
                        .padding(16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.theme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Appearance", icon: "paintbrush.fill")

            VStack(spacing: 12) {
                // Theme Selector
                HStack(spacing: 12) {
                    ForEach(AppThemeStyle.allCases, id: \.self) { theme in
                        ThemeOptionButton(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme,
                            action: {
                                withAnimation(.spring()) {
                                    themeManager.currentTheme = theme
                                }
                            }
                        )
                    }
                }
            }
            .padding(16)
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Audio Section
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Audio", icon: "speaker.wave.2.fill")

            VStack(spacing: 0) {
                settingsRow(
                    icon: "play.circle.fill",
                    iconColor: themeManager.theme.primaryAccent,
                    title: "Auto-play next surah",
                    trailing: {
                        Toggle("", isOn: $autoPlayNextSurah)
                            .labelsHidden()
                            .onChange(of: autoPlayNextSurah) { newValue in
                                audioPlayerService.isAutoplayEnabled = newValue
                            }
                    }
                )

                Divider()
                    .padding(.leading, 50)

                settingsRow(
                    icon: "timer",
                    iconColor: themeManager.theme.primaryAccent,
                    title: "Sleep timer button",
                    trailing: {
                        Toggle("", isOn: $showSleepTimer)
                            .labelsHidden()
                    }
                )
            }
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Notifications", icon: "bell.fill")

            VStack(spacing: 0) {
                settingsRow(
                    icon: "moon.stars.fill",
                    iconColor: themeManager.theme.primaryAccent,
                    title: "Prayer reminders",
                    trailing: {
                        Toggle("", isOn: $prayerRemindersEnabled)
                            .labelsHidden()
                            .onChange(of: prayerRemindersEnabled) { newValue in
                                handlePrayerRemindersToggle(newValue)
                            }
                    }
                )

                Divider()
                    .padding(.leading, 50)

                settingsRow(
                    icon: "sparkles",
                    iconColor: themeManager.theme.primaryAccent,
                    title: "Dhikr reminders",
                    trailing: {
                        Toggle("", isOn: $dhikrRemindersEnabled)
                            .labelsHidden()
                            .onChange(of: dhikrRemindersEnabled) { newValue in
                                handleDhikrRemindersToggle(newValue)
                            }
                    }
                )
            }
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Zikr Ring Section
    private var zikrRingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Zikr Ring", icon: "dot.radiowaves.left.and.right")

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
            .padding(16)
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Dhikr Goals Section
    private var dhikrGoalsSection: some View {
        NavigationLink(destination: DhikrGoalsView()
            .environmentObject(dhikrService)
            .environmentObject(audioPlayerService)
            .environmentObject(bluetoothService)
        ) {
            HStack(spacing: 16) {
                Circle()
                    .fill(themeManager.theme.primaryAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "target")
                            .font(.title3)
                            .foregroundColor(themeManager.theme.primaryAccent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dhikr Goals")
                        .font(.headline)
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Set and manage your daily targets")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.tertiaryText)
            }
            .padding(16)
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "About", icon: "info.circle.fill")

            VStack(spacing: 0) {
                settingsRow(
                    icon: "app.badge.fill",
                    iconColor: themeManager.theme.primaryAccent,
                    title: "Version",
                    trailing: {
                        Text("2.0.0")
                            .font(.subheadline)
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                )

                Divider()
                    .padding(.leading, 50)

                Button(action: {
                    print("Contact support tapped")
                }) {
                    settingsRow(
                        icon: "envelope.fill",
                        iconColor: themeManager.theme.primaryAccent,
                        title: "Contact Support",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(themeManager.theme.tertiaryText)
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .padding(.leading, 50)

                Button(action: {
                    print("Rate us tapped")
                }) {
                    settingsRow(
                        icon: "star.fill",
                        iconColor: themeManager.theme.primaryAccent,
                        title: "Rate Us",
                        trailing: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(themeManager.theme.tertiaryText)
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(themeManager.theme.cardBackground)
            .cornerRadius(16)
        }
    }

    // MARK: - Sign Out Section
    private var signOutSection: some View {
        Button(action: {
            try? authService.signOut()
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.title3)
                            .foregroundColor(.red)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sign Out")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("Sign out of your account")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Delete Account Section
    private var deleteAccountSection: some View {
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "trash.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete Account")
                        .font(.headline)
                        .foregroundColor(.red)

                    Text("Permanently delete your account and data")
                        .font(.caption)
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.theme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helper Functions

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(themeManager.theme.primaryAccent)
                .font(.caption)
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(themeManager.theme.primaryText)
            Spacer()
        }
    }

    private func settingsRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(iconColor.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                )

            Text(title)
                .font(.subheadline)
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            trailing()
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

    // MARK: - Notification Handlers

    private func handlePrayerRemindersToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                // Request notification permission if needed
                let granted = await prayerNotificationService.requestNotificationPermission()
                if granted {
                    // Save to both UserDefaults and App Group
                    UserDefaults.standard.set(true, forKey: "prayerRemindersEnabled")
                    if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                        groupDefaults.set(true, forKey: "prayerRemindersEnabled")
                        groupDefaults.synchronize()
                    }

                    // Trigger immediate update via BackgroundRefreshService
                    await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Prayer reminders enabled")
                } else {
                    // Permission denied, turn toggle back off
                    await MainActor.run {
                        prayerRemindersEnabled = false
                    }
                }
            } else {
                // Save to both UserDefaults and App Group
                UserDefaults.standard.set(false, forKey: "prayerRemindersEnabled")
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(false, forKey: "prayerRemindersEnabled")
                    groupDefaults.synchronize()
                }

                // Clear prayer reminders
                prayerNotificationService.clearPrePrayerNotifications()
            }
        }
    }

    private func handleDhikrRemindersToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                // Request notification permission if needed
                let granted = await prayerNotificationService.requestNotificationPermission()
                if granted {
                    scheduleDhikrReminders()
                } else {
                    // Permission denied, turn toggle back off
                    await MainActor.run {
                        dhikrRemindersEnabled = false
                    }
                }
            } else {
                // Clear dhikr reminders
                clearDhikrReminders()
            }
        }
    }

    private func scheduleDhikrReminders() {
        // Schedule daily dhikr reminders at specific times
        let notificationCenter = UNUserNotificationCenter.current()

        // Clear existing dhikr reminders first
        clearDhikrReminders()

        // Get user's first name for personalization
        let firstName = getFirstName()

        // Schedule 3 daily reminders
        let reminderTimes = [
            (hour: 9, minute: 0, message: firstName.isEmpty ? "Start your day with dhikr" : "\(firstName), start your day with dhikr"),
            (hour: 15, minute: 0, message: firstName.isEmpty ? "Take a moment for dhikr" : "\(firstName), take a moment for dhikr"),
            (hour: 21, minute: 0, message: firstName.isEmpty ? "End your day with dhikr" : "\(firstName), end your day with dhikr")
        ]

        for (index, time) in reminderTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Dhikr Reminder"
            content.body = time.message
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "dhikr_reminder_\(index)",
                content: content,
                trigger: trigger
            )

            notificationCenter.add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule dhikr reminder: \(error)")
                } else {
                    print("✅ Scheduled dhikr reminder at \(time.hour):\(time.minute)")
                }
            }
        }
    }

    private func clearDhikrReminders() {
        let notificationCenter = UNUserNotificationCenter.current()
        let identifiers = ["dhikr_reminder_0", "dhikr_reminder_1", "dhikr_reminder_2"]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cleared dhikr reminders")
    }

    // Helper to get first name for personalization
    private func getFirstName() -> String {
        let fullName: String
        if authService.isAuthenticated {
            fullName = authService.currentUser?.displayName ?? ""
        } else {
            fullName = userDisplayName
        }

        // Extract first name
        let components = fullName.components(separatedBy: " ")
        return components.first ?? ""
    }

    // MARK: - Account Deletion
    private func deleteAccount() async {
        do {
            print("🗑️ [ProfileView] Starting account deletion...")

            // Delete account from Firebase (Auth and Firestore only)
            // Local data (dhikr counts, streaks, etc.) is preserved
            try await authService.deleteAccount()

            print("✅ [ProfileView] Account deleted successfully")
            print("ℹ️ [ProfileView] Local data (dhikr progress, streaks) preserved")

        } catch {
            print("❌ [ProfileView] Failed to delete account: \(error)")

            // Handle re-authentication error
            if let authError = error as NSError?, authError.domain == "FIRAuthErrorDomain" {
                if authError.code == 17014 { // Requires recent login
                    await MainActor.run {
                        deleteErrorMessage = "For security, please sign out and sign back in, then try deleting your account again."
                        showingDeleteError = true
                    }
                } else {
                    await MainActor.run {
                        deleteErrorMessage = "Failed to delete account: \(error.localizedDescription)"
                        showingDeleteError = true
                    }
                }
            } else {
                await MainActor.run {
                    deleteErrorMessage = "Failed to delete account: \(error.localizedDescription)"
                    showingDeleteError = true
                }
            }
        }
    }
}

// MARK: - Enhanced Supporting Views

// Theme Option Button
struct ThemeOptionButton: View {
    let theme: AppThemeStyle
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(themePreviewGradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: theme.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? themeManager.theme.primaryAccent : Color.clear, lineWidth: 3)
                    )

                Text(theme.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? themeManager.theme.primaryAccent : themeManager.theme.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var themePreviewGradient: LinearGradient {
        switch theme {
        case .auto:
            return LinearGradient(
                colors: [Color.white, Color.black],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .light:
            return LinearGradient(
                colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

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
    @StateObject private var themeManager = ThemeManager.shared

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
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(isLarge ? 2 : 1)
                    .minimumScaleFactor(0.8)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.theme.primaryText)

                Text(description)
                    .font(.caption)
                    .foregroundColor(themeManager.theme.secondaryText)
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [gradient[0].opacity(0.3), gradient[1].opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .gridCellColumns(isLarge ? 2 : 1)
    }
}

// MARK: - Surahs Completed Card with Progress Bar
struct SurahsCompletedCard: View {
    let completedCount: Int
    @StateObject private var themeManager = ThemeManager.shared

    var progressPercentage: Int {
        Int((Double(completedCount) / 114.0) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.theme.primaryAccent, themeManager.theme.primaryAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()

                Circle()
                    .fill(themeManager.theme.primaryAccent.opacity(0.2))
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount)/114")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Surahs Completed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Chapters finished")
                    .font(.caption)
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            // Progress bar integrated inside card
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * CGFloat(completedCount) / 114.0,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                // Percentage text
                Text("\(progressPercentage)% Complete")
                    .font(.caption2)
                    .foregroundColor(themeManager.theme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [themeManager.theme.primaryAccent.opacity(0.3), themeManager.theme.primaryAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
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
    @StateObject private var themeManager = ThemeManager.shared

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
                            colors: [themeManager.theme.primaryAccent, themeManager.theme.primaryAccent.opacity(0.7)],
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
                        .foregroundColor(themeManager.theme.primaryAccent)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                } else {
                    Circle()
                        .fill(themeManager.theme.primaryAccent.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(currentValue)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.theme.primaryText)
                        .contentTransition(.numericText())

                    if showingHighest && streakInfo.current > 0 && !streakInfo.isCurrentBest {
                        Text("(Current: \(streakInfo.current))")
                            .font(.caption)
                            .foregroundColor(themeManager.theme.secondaryText)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingHighest)

                Text(currentTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.theme.primaryText)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showingHighest)

                Text(currentDescription)
                    .font(.caption)
                    .foregroundColor(themeManager.theme.secondaryText)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: showingHighest)
            }

            // Tap indicator
            HStack {
                Spacer()
                Text(showingHighest ? "Tap for current" : "Tap for highest")
                    .font(.caption2)
                    .foregroundColor(themeManager.theme.secondaryText)
                    .opacity(0.7)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [themeManager.theme.primaryAccent.opacity(0.3), themeManager.theme.primaryAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
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

// MARK: - Completed Surah Badge
struct CompletedSurahBadge: View {
    let surahNumber: Int
    @State private var surahName: String = ""
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Number circle with checkmark
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                VStack(spacing: 2) {
                    Text("\(surahNumber)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .green.opacity(0.3), radius: 4, x: 0, y: 2)

            // Surah name
            if !surahName.isEmpty {
                Text(surahName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(maxWidth: 70)
            } else {
                Text("Surah \(surahNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
        .task {
            await loadSurahName()
        }
    }

    private func loadSurahName() async {
        do {
            let surahs = try await QuranAPIService.shared.fetchSurahs()
            if let surah = surahs.first(where: { $0.number == surahNumber }) {
                await MainActor.run {
                    surahName = surah.englishName
                }
            }
        } catch {
            // Silently fail, will show "Surah X" as fallback
        }
    }
}

// MARK: - Completed Surahs List View
struct CompletedSurahsListView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header stats
                VStack(spacing: 8) {
                    Text("\(audioPlayerService.completedSurahNumbers.count)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryAccent)

                    Text("Surahs Completed")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("\(Int((Double(audioPlayerService.completedSurahNumbers.count) / 114.0) * 100))% of the Quran")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.bottom, 32)

                // Surah grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(Array(audioPlayerService.completedSurahNumbers).sorted(), id: \.self) { surahNumber in
                        CompletedSurahBadge(surahNumber: surahNumber)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Completed Surahs")
        .navigationBarTitleDisplayMode(.inline)
        .background(themeManager.theme.cardBackground)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(DhikrService.shared)
            .environmentObject(AudioPlayerService.shared)
            .environmentObject(BluetoothService())
            .environmentObject(LocationService())
    }
} 
