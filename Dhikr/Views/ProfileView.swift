//
//  ProfileView.swift
//  Dhikr
//
//  Sacred Minimalism redesign - contemplative, refined, spiritually appropriate
//

import SwiftUI
import Kingfisher
import UserNotifications
import StoreKit

struct ProfileView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var prayerNotificationService = PrayerNotificationService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
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

    // State
    @State private var showingHighestStreak = false
    @State private var showingAuth = false
    @State private var showingPaywall = false
    @State private var refreshID = UUID()
    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var sectionAppeared: [Bool] = Array(repeating: false, count: 10)

    // App Storage
    @AppStorage("autoPlayNextSurah") private var autoPlayNextSurah = true
    @AppStorage("showSleepTimer") private var showSleepTimer = true
    @AppStorage("prayerRemindersEnabled") private var prayerRemindersEnabled = true
    @AppStorage("dhikrRemindersEnabled") private var dhikrRemindersEnabled = true
    @AppStorage("userDisplayName") private var userDisplayName: String = ""

    private var displayName: String {
        if authService.isAuthenticated {
            return authService.currentUser?.displayName ?? "User"
        } else if !userDisplayName.isEmpty {
            return userDisplayName
        } else {
            return "Welcome"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Identity
                identitySection
                    .opacity(sectionAppeared[0] ? 1 : 0)
                    .offset(y: sectionAppeared[0] ? 0 : 20)

                // Sign In Prompt
                if !authService.isAuthenticated {
                    signInPromptCard
                        .padding(.horizontal, 24)
                        .opacity(sectionAppeared[1] ? 1 : 0)
                        .offset(y: sectionAppeared[1] ? 0 : 20)
                }

                // Journey
                journeySection
                    .opacity(sectionAppeared[2] ? 1 : 0)
                    .offset(y: sectionAppeared[2] ? 0 : 20)

                // Subscription Prompt
                if !subscriptionService.hasPremiumAccess {
                    subscriptionPromptCard
                        .padding(.horizontal, 24)
                        .opacity(sectionAppeared[3] ? 1 : 0)
                        .offset(y: sectionAppeared[3] ? 0 : 20)
                }

                // Preferences
                preferencesSection
                    .opacity(sectionAppeared[4] ? 1 : 0)
                    .offset(y: sectionAppeared[4] ? 0 : 20)

                // Premium Status
                if subscriptionService.hasPremiumAccess {
                    premiumStatusSection
                        .padding(.horizontal, 24)
                        .opacity(sectionAppeared[5] ? 1 : 0)
                        .offset(y: sectionAppeared[5] ? 0 : 20)
                }

                // Support
                supportSection
                    .opacity(sectionAppeared[6] ? 1 : 0)
                    .offset(y: sectionAppeared[6] ? 0 : 20)

                // Account
                if authService.isAuthenticated {
                    accountSection
                        .opacity(sectionAppeared[7] ? 1 : 0)
                        .offset(y: sectionAppeared[7] ? 0 : 20)
                }

                Color.clear.frame(height: audioPlayerService.currentSurah != nil ? 100 : 40)
            }
            .padding(.top, 16)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAuth) {
            ModernAuthView().environmentObject(authService)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("Are you sure you want to delete your account? Your authentication account will be permanently deleted, but your local progress will be preserved.")
        }
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .onChange(of: authService.isAuthenticated) { _ in refreshID = UUID() }
        .onAppear {
            setupOnAppear()
            animateEntrance()
        }
        .id(refreshID)
    }

    // MARK: - Identity Section
    private var identitySection: some View {
        VStack(spacing: 24) {
            // Avatar
            ZStack {
                Circle()
                    .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(cardBackground)
                    .frame(width: 80, height: 80)

                if let initial = displayName.first, displayName != "Welcome" {
                    Text(String(initial).uppercased())
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .foregroundColor(sacredGold)
                } else {
                    Image(systemName: "person")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(sacredGold)
                }
            }

            // Name
            VStack(spacing: 6) {
                Text(displayName)
                    .font(.system(size: 24, weight: .light, design: .serif))
                    .foregroundColor(themeManager.theme.primaryText)

                if authService.isAuthenticated, let joinDate = authService.currentUser?.joinDate {
                    Text("On this journey since \(joinDate.formatted(.dateTime.year()))")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .tracking(0.5)
                } else {
                    Text("Your path of remembrance")
                        .font(.system(size: 12, weight: .light, design: .serif))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .italic()
                }
            }

            // Stats Row
            statsRow
                .padding(.horizontal, 24)
        }
    }

    private var statsRow: some View {
        let stats = dhikrService.getTodayStats()
        return HStack(spacing: 16) {
            SacredProfileStatCard(
                value: "\(stats.streak)",
                label: "DAY STREAK",
                accentColor: .orange
            )

            SacredProfileStatCard(
                value: "\(stats.total)",
                label: "TODAY",
                accentColor: sacredGold
            )
        }
    }

    // MARK: - Sign In Prompt
    private var signInPromptCard: some View {
        Button(action: { showingAuth = true }) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(sacredGold.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 20))
                                .foregroundColor(sacredGold)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Sync progress across devices")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundColor(sacredGold)
                }
                .padding(20)

                Rectangle()
                    .fill(sacredGold.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    SacredBenefitRow(icon: "arrow.triangle.2.circlepath", text: "Sync your data across devices", accentColor: sacredGold)
                    SacredBenefitRow(icon: "flame", text: "Preserve your streaks", accentColor: sacredGold)
                    SacredBenefitRow(icon: "crown", text: "Access premium features", accentColor: sacredGold)
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SacredProfileButtonStyle())
    }

    // MARK: - Journey Section
    private var journeySection: some View {
        VStack(spacing: 20) {
            sacredSectionHeader(title: "YOUR JOURNEY")
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                SacredJourneyCard(
                    title: "Listening",
                    value: audioPlayerService.getTotalListeningTimeString(),
                    subtitle: "total time",
                    icon: "headphones",
                    accentColor: sacredGold
                )

                SacredJourneyCard(
                    title: "Surahs",
                    value: "\(audioPlayerService.getCompletedSurahCount())/114",
                    subtitle: "\(Int((Double(audioPlayerService.getCompletedSurahCount()) / 114.0) * 100))% complete",
                    icon: "checkmark.seal",
                    accentColor: softGreen,
                    showProgress: true,
                    progress: Double(audioPlayerService.getCompletedSurahCount()) / 114.0
                )

                SacredJourneyCard(
                    title: "Favorite",
                    value: getMostListenedReciter(),
                    subtitle: "most played",
                    icon: "person.wave.2",
                    accentColor: warmGray
                )

                SacredStreakCard(
                    dhikrService: dhikrService,
                    showingHighest: $showingHighestStreak,
                    accentColor: .orange
                )
            }
            .padding(.horizontal, 24)

            // Completed Surahs Preview
            if !audioPlayerService.completedSurahNumbers.isEmpty {
                completedSurahsPreview
            }

            // Dhikr Goals Link
            dhikrGoalsLink
                .padding(.horizontal, 24)
        }
    }

    private var completedSurahsPreview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("COMPLETED SURAHS")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(themeManager.theme.secondaryText)

                Spacer()

                NavigationLink(destination: SacredCompletedSurahsListView().environmentObject(audioPlayerService)) {
                    Text("See All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(audioPlayerService.completedSurahNumbers).sorted().prefix(8), id: \.self) { number in
                        SacredSurahChip(surahNumber: number, accentColor: softGreen)
                    }

                    if audioPlayerService.completedSurahNumbers.count > 8 {
                        Text("+\(audioPlayerService.completedSurahNumbers.count - 8)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(cardBackground))
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private var dhikrGoalsLink: some View {
        NavigationLink(destination: DhikrGoalsView()
            .environmentObject(dhikrService)
            .environmentObject(audioPlayerService)
            .environmentObject(bluetoothService)
        ) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(sacredGold.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(sacredGold)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dhikr Goals")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Set daily targets")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SacredProfileButtonStyle())
    }

    // MARK: - Subscription Prompt
    private var subscriptionPromptCard: some View {
        Button(action: { showingPaywall = true }) {
            HStack(spacing: 16) {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "crown")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(sacredGold)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlock Premium")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Full access to all features")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)

                    HStack(spacing: 4) {
                        Text("Learn more")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(sacredGold)
                    .padding(.top, 2)
                }

                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(sacredGold.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SacredProfileButtonStyle())
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(spacing: 20) {
            sacredSectionHeader(title: "PREFERENCES")
                .padding(.horizontal, 24)

            VStack(spacing: 16) {
                // Appearance
                SacredPreferenceGroup(title: "APPEARANCE") {
                    SacredThemeSelector()
                }

                // Audio
                SacredPreferenceGroup(title: "AUDIO") {
                    VStack(spacing: 0) {
                        SacredToggleRow(
                            icon: "play.circle",
                            title: "Auto-play next surah",
                            isOn: $autoPlayNextSurah,
                            accentColor: sacredGold
                        )
                        .onChange(of: autoPlayNextSurah) { newValue in
                            audioPlayerService.isAutoplayEnabled = newValue
                        }

                        SacredDivider()

                        SacredToggleRow(
                            icon: "moon.zzz",
                            title: "Sleep timer button",
                            isOn: $showSleepTimer,
                            accentColor: warmGray
                        )
                    }
                }

                // Notifications
                SacredPreferenceGroup(title: "NOTIFICATIONS") {
                    VStack(spacing: 0) {
                        SacredToggleRow(
                            icon: "moon.stars",
                            title: "Prayer reminders",
                            isOn: $prayerRemindersEnabled,
                            accentColor: sacredGold
                        )
                        .onChange(of: prayerRemindersEnabled) { newValue in
                            handlePrayerRemindersToggle(newValue)
                        }

                        SacredDivider()

                        SacredToggleRow(
                            icon: "sparkles",
                            title: "Dhikr reminders",
                            isOn: $dhikrRemindersEnabled,
                            accentColor: softGreen
                        )
                        .onChange(of: dhikrRemindersEnabled) { newValue in
                            handleDhikrRemindersToggle(newValue)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Premium Status Section
    private var premiumStatusSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 16))
                            .foregroundColor(sacredGold)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium Active")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Full access enabled")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "crown")
                    .font(.system(size: 14))
                    .foregroundColor(sacredGold)
            }
            .padding(16)

            SacredDivider()

            Button(action: {
                Task { await subscriptionService.restorePurchases() }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(sacredGold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Support Section
    private var supportSection: some View {
        VStack(spacing: 20) {
            sacredSectionHeader(title: "SUPPORT")
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                SacredInfoRow(icon: "app.badge", title: "Version", value: "1.1.0", accentColor: warmGray)

                SacredDivider()

                Button(action: {
                    if let url = URL(string: "mailto:khushooios@gmail.com?subject=Khushoo%20Support") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    SacredActionRow(icon: "envelope", title: "Contact Support", accentColor: sacredGold)
                }

                SacredDivider()

                Button(action: requestAppReview) {
                    SacredActionRow(icon: "star", title: "Rate Us", accentColor: sacredGold)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        VStack(spacing: 16) {
            Button(action: { try? authService.signOut() }) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign Out")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)

                        Text("You can sign back in anytime")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(SacredProfileButtonStyle())

            Button(action: { showingDeleteConfirmation = true }) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Delete Account")
                        .font(.system(size: 13, weight: .light))
                }
                .foregroundColor(themeManager.theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Section Header
    private func sacredSectionHeader(title: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(sacredGold.opacity(0.4))
                .frame(width: 20, height: 1)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(themeManager.theme.secondaryText)

            Spacer()
        }
    }

    // MARK: - Animation
    private func animateEntrance() {
        for index in 0..<sectionAppeared.count {
            withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.08)) {
                sectionAppeared[index] = true
            }
        }
    }

    // MARK: - Setup & Helpers
    private func setupOnAppear() {
        audioPlayerService.isAutoplayEnabled = autoPlayNextSurah

        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr"),
           let value = groupDefaults.object(forKey: "prayerRemindersEnabled") as? Bool {
            prayerRemindersEnabled = value
        }

        Task {
            if dhikrRemindersEnabled && prayerNotificationService.hasNotificationPermission {
                scheduleDhikrReminders()
            }
        }
    }

    private func getMostListenedReciter() -> String {
        let recentItems = RecentsManager.shared.recentItems
        var reciterCounts: [String: Int] = [:]
        for item in recentItems {
            reciterCounts[item.reciter.englishName, default: 0] += 1
        }
        if let mostListened = reciterCounts.max(by: { $0.value < $1.value }) {
            return mostListened.key
        }
        return "None"
    }

    private func handlePrayerRemindersToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await prayerNotificationService.requestNotificationPermission()
                if granted {
                    UserDefaults.standard.set(true, forKey: "prayerRemindersEnabled")
                    if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                        groupDefaults.set(true, forKey: "prayerRemindersEnabled")
                        groupDefaults.synchronize()
                    }
                    await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Prayer reminders enabled")
                } else {
                    await MainActor.run { prayerRemindersEnabled = false }
                }
            } else {
                UserDefaults.standard.set(false, forKey: "prayerRemindersEnabled")
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(false, forKey: "prayerRemindersEnabled")
                    groupDefaults.synchronize()
                }
                prayerNotificationService.clearPrePrayerNotifications()
            }
        }
    }

    private func handleDhikrRemindersToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                let granted = await prayerNotificationService.requestNotificationPermission()
                if granted {
                    scheduleDhikrReminders()
                } else {
                    await MainActor.run { dhikrRemindersEnabled = false }
                }
            } else {
                clearDhikrReminders()
            }
        }
    }

    private func scheduleDhikrReminders() {
        let notificationCenter = UNUserNotificationCenter.current()
        clearDhikrReminders()

        let firstName = getFirstName()
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
            let request = UNNotificationRequest(identifier: "dhikr_reminder_\(index)", content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }

    private func clearDhikrReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["dhikr_reminder_0", "dhikr_reminder_1", "dhikr_reminder_2"]
        )
    }

    private func getFirstName() -> String {
        let fullName = authService.isAuthenticated ? (authService.currentUser?.displayName ?? "") : userDisplayName
        return fullName.components(separatedBy: " ").first ?? ""
    }

    private func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch {
            if let authError = error as NSError?, authError.domain == "FIRAuthErrorDomain", authError.code == 17014 {
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
        }
    }
}

// MARK: - Sacred Profile Components

struct SacredProfileStatCard: View {
    let value: String
    let label: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(value)
                .font(.system(size: 32, weight: .ultraLight))
                .foregroundColor(accentColor)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1.5)
                .foregroundColor(themeManager.theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct SacredJourneyCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    var showProgress: Bool = false
    var progress: Double = 0
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)

                Text(subtitle)
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            // Always reserve space for progress bar to maintain consistent height
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor.opacity(showProgress ? 0.15 : 0))
                        .frame(height: 4)

                    if showProgress {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct SacredStreakCard: View {
    @ObservedObject var dhikrService: DhikrService
    @Binding var showingHighest: Bool
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        let streakInfo = dhikrService.getHighestStreakInfo()
        let currentValue = showingHighest ? streakInfo.highest : streakInfo.current
        let currentTitle = showingHighest ? "Best Streak" : "Current Streak"

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(accentColor)

                Spacer()

                if showingHighest && streakInfo.isCurrentBest {
                    Image(systemName: "crown")
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentValue)")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundColor(themeManager.theme.primaryText)
                    .contentTransition(.numericText())

                Text(currentTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Tap to toggle")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            // Spacer for consistent height with other cards
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingHighest.toggle()
            }
            HapticManager.shared.impact(.light)
        }
    }
}

struct SacredSurahChip: View {
    let surahNumber: Int
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentColor)

            Text("\(surahNumber)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.theme.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(cardBackground)
                .overlay(
                    Capsule()
                        .stroke(accentColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

struct SacredBenefitRow: View {
    let icon: String
    let text: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(accentColor)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()
        }
    }
}

struct SacredPreferenceGroup<Content: View>: View {
    let title: String
    let content: () -> Content
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(themeManager.theme.secondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

struct SacredThemeSelector: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var selectorBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppThemeStyle.allCases, id: \.self) { theme in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        themeManager.currentTheme = theme
                    }
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: theme.icon)
                            .font(.system(size: 11, weight: .medium))

                        Text(theme.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(themeManager.currentTheme == theme ? .white : themeManager.theme.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme == theme ? sacredGold : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selectorBackground)
        )
        .padding(12)
    }
}

struct SacredToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentColor)
                )

            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SacredInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentColor)
                )

            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SacredActionRow: View {
    let icon: String
    let title: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(accentColor.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accentColor)
                )

            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(themeManager.theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SacredDivider: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        Rectangle()
            .fill(pageBackground)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

struct SacredProfileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Sacred Completed Surahs List View
struct SacredCompletedSurahsListView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var allSurahs: [Surah] = []

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
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

    private var completedSurahs: [Surah] {
        allSurahs.filter { audioPlayerService.completedSurahNumbers.contains($0.number) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if completedSurahs.isEmpty {
                    VStack(spacing: 20) {
                        Circle()
                            .fill(sacredGold.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "checkmark.seal")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(sacredGold.opacity(0.5))
                            )

                        VStack(spacing: 8) {
                            Text("No completed surahs yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("Complete listening to a surah to see it here")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(themeManager.theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 80)
                } else {
                    ForEach(completedSurahs) { surah in
                        HStack(spacing: 14) {
                            // Number circle
                            Circle()
                                .fill(sacredGold.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text("\(surah.number)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(sacredGold)
                                )

                            // Info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(surah.englishName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(themeManager.theme.primaryText)

                                Text("\(surah.revelationType) • \(surah.numberOfAyahs) Ayahs")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(themeManager.theme.secondaryText)
                            }

                            Spacer()

                            // Checkmark
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(softGreen)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(softGreen.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("Completed Surahs")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadSurahs()
        }
    }

    private func loadSurahs() async {
        do {
            allSurahs = try await QuranAPIService.shared.fetchSurahs()
        } catch {
            print("Failed to load surahs: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(DhikrService.shared)
            .environmentObject(AudioPlayerService.shared)
            .environmentObject(BluetoothService())
            .environmentObject(AuthenticationService.shared)
    }
}
