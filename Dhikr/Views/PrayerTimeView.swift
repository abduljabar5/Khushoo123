//
//  PrayerTimeView.swift
//  Dhikr
//
//  Sacred Minimalism redesign - contemplative, refined, spiritually appropriate
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - Prayer Model
struct Prayer {
    let name: String
    var time: String
    let icon: String
    var hasReminder: Bool
    var isCompleted: Bool
}

struct PrayerTimeView: View {
    @EnvironmentObject var viewModel: PrayerTimeViewModel
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var blockingState = BlockingStateService.shared
    @StateObject private var locationService = LocationService()
    @State private var animateProgress = false
    @State private var showingDatePicker = false
    @State private var showingPaywall = false
    @State private var showCelebration = false
    @State private var previousCompletedCount = 0
    @State private var showingSettings = false
    @State private var showingBlockedAlert = false
    @State private var showingManualLocation = false

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

    var body: some View {
        ZStack {
            // Check if we have any location (GPS or manual)
            if !locationService.hasAnyLocation {
                // No location - show prompt
                locationRequiredView
            } else {
                // Has location - show normal content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Top prayer section with mosque background
                        topPrayerSection

                        // Date navigation
                        dateNavigationSection
                            .padding(.top, 8)

                        // Content sections
                        VStack(spacing: RS.spacing(16)) {
                            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                                progressSection
                            }

                            // Qibla Compass
                            SacredQiblaCard()

                            prayerScheduleList

                            footerInfo
                        }
                        .padding(.horizontal, RS.horizontalPadding)
                        .padding(.top, RS.spacing(20))
                        .padding(.bottom, RS.spacing(20))
                    }
                }
                .ignoresSafeArea(edges: .top)
                .background(pageBackground)
            }

            // Celebration overlay
            if showCelebration {
                SacredCelebrationOverlay(isPresented: $showCelebration)
            }

            // Settings refresh loading overlay
            if viewModel.isRefreshingSettings {
                settingsRefreshOverlay
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animateProgress = true
            }
            viewModel.reloadCompletions()
            previousCompletedCount = viewModel.completedPrayers
            // Check notification permission and update reminders accordingly
            viewModel.checkNotificationPermissionAndUpdateReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when returning from Settings
            viewModel.checkNotificationPermissionAndUpdateReminders()
        }
        .onChange(of: viewModel.completedPrayers) { oldValue, newValue in
            // Show celebration when all 5 prayers completed (excluding Sunrise)
            if newValue == 5 && oldValue < 5 && Calendar.current.isDateInToday(viewModel.selectedDate) {
                HapticManager.shared.notification(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showCelebration = true
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            SacredDatePickerSheet(
                selectedDate: $viewModel.selectedDate,
                onDateSelected: { date in
                    viewModel.fetchPrayerTimes(for: date)
                    showingDatePicker = false
                }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingSettings) {
            PrayerSettingsView(
                currentCountry: viewModel.countryName,
                onSettingsApplied: {
                    viewModel.refreshForSettingsChange()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingManualLocation) {
            ManualLocationView { lat, lon, name in
                // Refresh prayer times after manual location is set
                viewModel.refreshForSettingsChange()
            }
        }
        .alert("Notifications Disabled", isPresented: $viewModel.showNotificationSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive prayer reminders, please enable notifications in Settings.")
        }
    }

    // MARK: - Location Required View
    private var locationRequiredView: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "location.circle")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                }

                // Text
                VStack(spacing: 12) {
                    Text("Location Needed")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("To show accurate prayer times, we need to know your location.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(warmGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    // Enable Location Button
                    Button(action: {
                        locationService.requestLocationPermission()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                            Text("Enable Location")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(themeManager.effectiveTheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(sacredGold)
                        )
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(warmGray.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(warmGray)
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(warmGray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    // Enter City Manually Button
                    Button(action: {
                        showingManualLocation = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                            Text("Enter City Manually")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(sacredGold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(sacredGold.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Top Prayer Section
    private var topPrayerSection: some View {
        let sectionHeight: CGFloat = RS.cardSize(320, minimum: 280)
        return ZStack(alignment: .bottom) {
            // Mosque background with gradient
            GeometryReader { geometry in
                Image("mosque-bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: sectionHeight)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.1),
                                pageBackground.opacity(0.5),
                                pageBackground
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .frame(height: sectionHeight)

            // Content overlay
            VStack(spacing: 0) {
                // Status bar spacer
                Color.clear.frame(height: RS.dimension(50))

                // Location
                Button(action: { viewModel.refreshLocation() }) {
                    HStack(spacing: RS.spacing(6)) {
                        if viewModel.isRefreshingLocation {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white.opacity(0.8))
                        } else {
                            Image(systemName: "location")
                                .font(.system(size: RS.fontSize(11), weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Text("\(viewModel.cityName), \(viewModel.countryName)")
                            .font(.system(size: RS.fontSize(12), weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)

                        if !viewModel.isRefreshingLocation {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: RS.fontSize(9)))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, RS.horizontalPadding)
                .padding(.bottom, RS.spacing(24))

                // Next prayer
                if let nextPrayer = viewModel.todaysNextPrayer {
                    VStack(spacing: RS.spacing(8)) {
                        Text(getPrayerArabicName(nextPrayer.name))
                            .font(.system(size: RS.fontSize(18), weight: .regular, design: .serif))
                            .foregroundColor(.white.opacity(0.9))

                        Text(nextPrayer.name)
                            .font(.system(size: RS.fontSize(11), weight: .medium))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.6))

                        Text(nextPrayer.time)
                            .font(.system(size: RS.fontSize(48), weight: .ultraLight))
                            .foregroundColor(.white)

                        HStack(spacing: RS.spacing(6)) {
                            Text("in \(viewModel.timeUntilNextPrayer)")
                                .font(.system(size: RS.fontSize(12), weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.horizontal, RS.spacing(16))
                        .padding(.vertical, RS.spacing(8))
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.bottom, RS.spacing(32))
                }
            }
        }
        .frame(height: sectionHeight)
    }

    // MARK: - Date Navigation Section
    private var dateNavigationSection: some View {
        VStack(spacing: RS.spacing(16)) {
            // Header
            HStack {
                sacredSectionHeader(title: "PRAYER TIMES")

                Spacer()

                if viewModel.isLoadingFuturePrayers {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(sacredGold)
                }
            }
            .padding(.horizontal, RS.horizontalPadding)

            // Navigation
            HStack(spacing: RS.spacing(12)) {
                // Previous
                Button(action: {
                    let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    viewModel.fetchPrayerTimes(for: previousDay)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: RS.fontSize(14), weight: .medium))
                        .foregroundColor(sacredGold)
                        .frame(width: RS.dimension(40), height: RS.dimension(40))
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                )
                        )
                }

                // Date display
                VStack(spacing: RS.spacing(2)) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.system(size: RS.fontSize(15), weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        Text("Today")
                            .font(.system(size: RS.fontSize(11), weight: .medium))
                            .foregroundColor(sacredGold)
                    } else {
                        Text(dayOfWeek(viewModel.selectedDate))
                            .font(.system(size: RS.fontSize(11), weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)

                // Next
                Button(action: {
                    let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: viewModel.selectedDate) ?? viewModel.selectedDate
                    viewModel.fetchPrayerTimes(for: nextDay)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: RS.fontSize(14), weight: .medium))
                        .foregroundColor(sacredGold)
                        .frame(width: RS.dimension(40), height: RS.dimension(40))
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                )
                        )
                }

                // Calendar
                Button(action: { showingDatePicker = true }) {
                    Image(systemName: "calendar")
                        .font(.system(size: RS.fontSize(14), weight: .medium))
                        .foregroundColor(sacredGold)
                        .frame(width: RS.dimension(40), height: RS.dimension(40))
                        .background(
                            Circle()
                                .fill(cardBackground)
                                .overlay(
                                    Circle()
                                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, RS.horizontalPadding)
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        HStack(spacing: RS.spacing(24)) {
            // Circular Progress
            ZStack {
                Circle()
                    .stroke(sacredGold.opacity(0.1), lineWidth: RS.dimension(6))
                    .frame(width: RS.dimension(80), height: RS.dimension(80))

                Circle()
                    .trim(from: 0, to: animateProgress ? viewModel.progressPercentage : 0)
                    .stroke(
                        sacredGold,
                        style: StrokeStyle(lineWidth: RS.dimension(6), lineCap: .round)
                    )
                    .frame(width: RS.dimension(80), height: RS.dimension(80))
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: animateProgress)

                VStack(spacing: RS.spacing(2)) {
                    Text("\(viewModel.completedPrayers)")
                        .font(.system(size: RS.fontSize(24), weight: .ultraLight))
                        .foregroundColor(sacredGold)
                    Text("of \(viewModel.totalPrayers)")
                        .font(.system(size: RS.fontSize(10), weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }

            // Streak Info
            VStack(alignment: .leading, spacing: RS.spacing(10)) {
                HStack(spacing: RS.spacing(6)) {
                    Image(systemName: "flame")
                        .font(.system(size: RS.fontSize(14), weight: .light))
                        .foregroundColor(viewModel.currentStreak > 0 ? .orange : warmGray)

                    Text("CURRENT STREAK")
                        .font(.system(size: RS.fontSize(9), weight: .medium))
                        .tracking(1)
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                HStack(alignment: .firstTextBaseline, spacing: RS.spacing(6)) {
                    Text("\(viewModel.currentStreak)")
                        .font(.system(size: RS.fontSize(28), weight: .ultraLight))
                        .foregroundColor(viewModel.currentStreak > 0 ? sacredGold : themeManager.theme.primaryText)

                    Text(viewModel.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: RS.fontSize(14), weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                HStack(spacing: RS.spacing(16)) {
                    HStack(spacing: RS.spacing(4)) {
                        Text("Best:")
                            .font(.system(size: RS.fontSize(10), weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                        Text("\(viewModel.bestStreak)")
                            .font(.system(size: RS.fontSize(10), weight: .medium))
                            .foregroundColor(sacredGold)
                    }

                    HStack(spacing: RS.spacing(4)) {
                        Text("Today:")
                            .font(.system(size: RS.fontSize(10), weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                        Text("\(Int(viewModel.progressPercentage * 100))%")
                            .font(.system(size: RS.fontSize(10), weight: .medium))
                            .foregroundColor(softGreen)
                    }
                }
            }

            Spacer()
        }
        .padding(RS.spacing(20))
        .background(
            RoundedRectangle(cornerRadius: RS.cornerRadius(20))
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: RS.cornerRadius(20))
                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Prayer Schedule List
    private var prayerScheduleList: some View {
        VStack(spacing: RS.spacing(10)) {
            let isToday = Calendar.current.isDateInToday(viewModel.selectedDate)
            let isPastDate = viewModel.selectedDate < Date() && !isToday

            ForEach(viewModel.prayers, id: \.name) { prayer in
                SacredPrayerRow(
                    prayer: prayer,
                    arabicName: getPrayerArabicName(prayer.name),
                    isActive: isToday && prayer.name == viewModel.currentPrayer?.name,
                    isToday: isToday,
                    isPastDate: isPastDate,
                    isPrayerPassed: viewModel.isPrayerPassed(prayer.name),
                    isPremium: subscriptionService.hasPremiumAccess,
                    sacredGold: sacredGold,
                    softGreen: softGreen,
                    warmGray: warmGray,
                    cardBackground: cardBackground,
                    onToggleReminder: {
                        viewModel.toggleReminder(for: prayer.name)
                    },
                    onToggleComplete: {
                        if subscriptionService.hasPremiumAccess {
                            viewModel.togglePrayerCompletion(for: prayer.name)
                        } else {
                            showingPaywall = true
                        }
                    }
                )
            }
        }
    }

    // MARK: - Footer
    private var footerInfo: some View {
        Button(action: {
            // Prevent settings changes while apps are blocked
            if blockingState.isCurrentlyBlocking {
                showingBlockedAlert = true
            } else {
                showingSettings = true
            }
        }) {
            HStack(spacing: RS.spacing(6)) {
                Image(systemName: "gearshape")
                    .font(.system(size: RS.fontSize(10), weight: .light))

                Text(viewModel.calculationMethod)
                    .font(.system(size: RS.fontSize(10), weight: .light))

                Text("•")

                Text(viewModel.asrMethod)
                    .font(.system(size: RS.fontSize(10), weight: .light))

                Text("•")

                Text(viewModel.cityName)
                    .font(.system(size: RS.fontSize(10), weight: .light))

                Image(systemName: "chevron.right")
                    .font(.system(size: RS.fontSize(8), weight: .medium))
            }
            .foregroundColor(themeManager.theme.secondaryText)
            .padding(.vertical, RS.spacing(10))
            .padding(.horizontal, RS.spacing(16))
            .background(
                Capsule()
                    .fill(cardBackground)
                    .overlay(
                        Capsule()
                            .stroke(themeManager.theme.secondaryText.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.isRefreshingSettings)
        .opacity(viewModel.isRefreshingSettings ? 0.5 : 1.0)
        .alert("Focus Mode Active", isPresented: $showingBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Settings cannot be changed during prayer time. Please wait until your focus session ends.")
        }
    }

    // MARK: - Settings Refresh Overlay
    private var settingsRefreshOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: RS.spacing(20)) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(sacredGold)

                Text("Updating prayer times...")
                    .font(.system(size: RS.fontSize(14), weight: .medium))
                    .foregroundColor(.white)

                Text("Applying new calculation settings")
                    .font(.system(size: RS.fontSize(12), weight: .light))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(RS.spacing(32))
            .background(
                RoundedRectangle(cornerRadius: RS.cornerRadius(20))
                    .fill(cardBackground)
            )
        }
    }

    // MARK: - Helpers
    private func sacredSectionHeader(title: String) -> some View {
        HStack(spacing: RS.spacing(10)) {
            Rectangle()
                .fill(sacredGold.opacity(0.4))
                .frame(width: RS.dimension(20), height: 1)

            Text(title)
                .font(.system(size: RS.fontSize(11), weight: .medium))
                .tracking(2)
                .foregroundColor(themeManager.theme.secondaryText)
        }
    }

    private func getPrayerArabicName(_ name: String) -> String {
        ["Fajr": "الفجر", "Sunrise": "الشروق", "Dhuhr": "الظهر",
         "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء"][name] ?? name
    }

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
}

// MARK: - Sacred Prayer Row
struct SacredPrayerRow: View {
    let prayer: Prayer
    let arabicName: String
    let isActive: Bool
    let isToday: Bool
    let isPastDate: Bool
    let isPrayerPassed: Bool
    let isPremium: Bool
    let sacredGold: Color
    let softGreen: Color
    let warmGray: Color
    let cardBackground: Color
    let onToggleReminder: () -> Void
    let onToggleComplete: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: RS.spacing(14)) {
            // Icon
            Image(systemName: prayer.icon)
                .font(.system(size: RS.fontSize(18), weight: .light))
                .foregroundColor(isActive ? sacredGold : warmGray)
                .frame(width: RS.dimension(24))

            // Name
            VStack(alignment: .leading, spacing: RS.spacing(2)) {
                HStack(spacing: RS.spacing(8)) {
                    Text(arabicName)
                        .font(.system(size: RS.fontSize(14), weight: .regular, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    if isActive {
                        Text("NOW")
                            .font(.system(size: RS.fontSize(8), weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(sacredGold)
                            .padding(.horizontal, RS.spacing(6))
                            .padding(.vertical, RS.spacing(2))
                            .background(
                                Capsule()
                                    .fill(sacredGold.opacity(0.15))
                            )
                    }
                }

                Text(prayer.name)
                    .font(.system(size: RS.fontSize(11), weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            Spacer()

            // Time
            Text(prayer.time)
                .font(.system(size: RS.fontSize(18), weight: isActive ? .light : .ultraLight))
                .foregroundColor(isActive ? sacredGold : themeManager.theme.primaryText)

            // Reminder (not shown for Sunrise - it's informational only)
            if prayer.name != "Sunrise" {
                Button(action: onToggleReminder) {
                    Image(systemName: prayer.hasReminder ? "bell.fill" : "bell")
                        .font(.system(size: RS.fontSize(14), weight: .light))
                        .foregroundColor(prayer.hasReminder ? sacredGold : warmGray.opacity(0.5))
                }
                .frame(width: RS.dimension(32))
            } else {
                Color.clear.frame(width: RS.dimension(32))
            }

            // Completion
            if prayer.name != "Sunrise" {
                if isToday && (isPrayerPassed || isActive) {
                    Button(action: onToggleComplete) {
                        ZStack {
                            Image(systemName: prayer.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: RS.fontSize(18), weight: .light))
                                .foregroundColor(prayer.isCompleted ? softGreen : warmGray.opacity(0.3))

                            if !isPremium {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: RS.fontSize(8), weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: RS.dimension(24))
                } else if isPastDate {
                    Image(systemName: prayer.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: RS.fontSize(18), weight: .light))
                        .foregroundColor(prayer.isCompleted ? softGreen.opacity(0.5) : warmGray.opacity(0.2))
                        .frame(width: RS.dimension(24))
                } else {
                    Color.clear.frame(width: RS.dimension(24), height: RS.dimension(18))
                }
            } else {
                Color.clear.frame(width: RS.dimension(24), height: RS.dimension(18))
            }
        }
        .padding(.horizontal, RS.spacing(16))
        .padding(.vertical, RS.spacing(14))
        .background(
            RoundedRectangle(cornerRadius: RS.cornerRadius(16))
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: RS.cornerRadius(16))
                        .stroke(isActive ? sacredGold.opacity(0.3) : themeManager.theme.secondaryText.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred Date Picker Sheet
struct SacredDatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    @State private var displayedMonth = Date()
    @State private var tempSelectedDate = Date()

    private let calendar = Calendar.current

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(cardBackground)
                            )
                    }

                    Spacer()

                    Text("Select Date")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Spacer()

                    Button("Today") {
                        tempSelectedDate = Date()
                        displayedMonth = Date()
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(sacredGold)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Month Navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(sacredGold)
                    }

                    Spacer()

                    Text(monthYearString(displayedMonth))
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(themeManager.theme.primaryText)

                    Spacer()

                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(sacredGold)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.bottom, 20)

            // Calendar Grid
            VStack(spacing: 10) {
                // Week headers
                HStack(spacing: 0) {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)

                // Days
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                    ForEach(Array(getDaysInMonth().enumerated()), id: \.offset) { index, date in
                        if let date = date {
                            PrayerDayCell(
                                date: date,
                                isSelected: isSameDay(date, tempSelectedDate),
                                isToday: isSameDay(date, Date()),
                                isCurrentMonth: isSameMonth(date, displayedMonth),
                                sacredGold: sacredGold,
                                onTap: { tempSelectedDate = date }
                            )
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // Buttons
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.theme.secondaryText.opacity(0.1), lineWidth: 1)
                            )
                    )

                Button("Select") { onDateSelected(tempSelectedDate) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(sacredGold)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(pageBackground)
        .onAppear {
            tempSelectedDate = selectedDate
            displayedMonth = selectedDate
        }
    }

    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
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

// MARK: - Prayer Day Cell
struct PrayerDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let sacredGold: Color
    let onTap: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(sacredGold)
                        .frame(width: 40, height: 40)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(sacredGold, lineWidth: 1)
                        .frame(width: 40, height: 40)
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday || isSelected ? .medium : .light))
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? sacredGold :
                        isCurrentMonth ? themeManager.theme.primaryText : themeManager.theme.secondaryText.opacity(0.4)
                    )
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sacred Qibla Card
struct SacredQiblaCard: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingCompass = false

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: { showingCompass = true }) {
            HStack(spacing: RS.spacing(14)) {
                // Icon
                Circle()
                    .fill(sacredGold.opacity(0.1))
                    .frame(width: RS.dimension(44), height: RS.dimension(44))
                    .overlay(
                        Image(systemName: "location.north")
                            .font(.system(size: RS.fontSize(20), weight: .light))
                            .foregroundColor(sacredGold)
                    )

                // Text
                VStack(alignment: .leading, spacing: RS.spacing(4)) {
                    Text("القِبلة")
                        .font(.system(size: RS.fontSize(15), weight: .regular, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Find Qibla Direction")
                        .font(.system(size: RS.fontSize(12), weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: RS.fontSize(12)))
                    .foregroundColor(sacredGold.opacity(0.6))
            }
            .padding(RS.spacing(16))
            .background(
                RoundedRectangle(cornerRadius: RS.cornerRadius(16))
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: RS.cornerRadius(16))
                            .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCompass) {
            SacredQiblaCompassModal()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Sacred Qibla Compass Modal
struct SacredQiblaCompassModal: View {
    @StateObject private var compassManager = CompassManager()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var lastProximityZone: Int = 0
    @State private var hapticTimer: Timer?

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

    private var relativeQiblaDirection: Double {
        compassManager.qiblaDirection - compassManager.heading
    }

    private var isAligned: Bool {
        let diff = abs(relativeQiblaDirection)
        return diff < 5 || diff > 355
    }

    private var proximityZone: Int {
        let diff = abs(relativeQiblaDirection)
        if diff < 5 || diff > 355 { return 4 }
        else if diff < 10 || diff > 350 { return 3 }
        else if diff < 20 || diff > 340 { return 2 }
        else if diff < 30 || diff > 330 { return 1 }
        else { return 0 }
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                sacredHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                Spacer()

                // Compass
                sacredCompassView
                    .padding(.vertical, 40)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)

                Spacer()

                // Info
                sacredInfoView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showContent = true
            }
        }
        .onChange(of: proximityZone) { oldZone, newZone in
            if newZone > 0 && newZone != oldZone {
                triggerHaptic(for: newZone)
            }
            hapticTimer?.invalidate()
            if newZone > 0 {
                let interval = hapticInterval(for: newZone)
                hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    triggerHaptic(for: newZone)
                }
            }
            lastProximityZone = newZone
        }
        .onDisappear {
            hapticTimer?.invalidate()
        }
    }

    // MARK: - Header
    private var sacredHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(cardBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeManager.theme.secondaryText)
                        )
                }
                Spacer()
            }

            VStack(spacing: 8) {
                Text("القِبلة")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Qibla Compass")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            if compassManager.locationAuthorized {
                Button(action: {
                    if compassManager.canRefresh {
                        compassManager.refreshLocation()
                        HapticManager.shared.impact(.light)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location")
                            .font(.system(size: 11))
                        Text(compassManager.cityName)
                            .font(.system(size: 12, weight: .light))
                    }
                    .foregroundColor(compassManager.canRefresh ? sacredGold : themeManager.theme.secondaryText)
                }
                .disabled(!compassManager.canRefresh)
            }
        }
    }

    // MARK: - Compass View
    private var sacredCompassView: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                .frame(width: 280, height: 280)

            // Compass ring
            sacredCompassRing
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-compassManager.heading))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

            // Center area
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 180, height: 180)
                    .overlay(
                        Circle()
                            .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    )

                // Qibla arrow
                sacredQiblaArrow
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(relativeQiblaDirection))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

                // Center dot
                Circle()
                    .fill(isAligned ? softGreen : sacredGold)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private var sacredCompassRing: some View {
        ZStack {
            // Degree markers
            ForEach(0..<72) { index in
                Rectangle()
                    .fill(sacredGold.opacity(index % 6 == 0 ? 0.6 : 0.2))
                    .frame(width: index % 6 == 0 ? 2 : 1, height: index % 6 == 0 ? 16 : 8)
                    .offset(y: -122)
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            // Cardinal directions
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 14, weight: direction == "N" ? .medium : .light))
                    .foregroundColor(direction == "N" ? sacredGold : themeManager.theme.secondaryText)
                    .offset(y: -145)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
            }
        }
    }

    private var sacredQiblaArrow: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 32))
                .foregroundColor(isAligned ? softGreen : sacredGold)

            RoundedRectangle(cornerRadius: 2)
                .fill(isAligned ? softGreen.opacity(0.6) : sacredGold.opacity(0.6))
                .frame(width: 4, height: 50)

            Spacer()
        }
        .frame(height: 180)
    }

    // MARK: - Info View
    private var sacredInfoView: some View {
        HStack(spacing: 12) {
            if !compassManager.locationAuthorized {
                sacredLocationPermissionCard
            } else {
                // Direction card
                VStack(spacing: 8) {
                    Text("DIRECTION")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text("\(Int(compassManager.qiblaDirection))°")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(sacredGold)

                    Text(headingToCardinal(compassManager.qiblaDirection))
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                        )
                )

                // Alignment card
                VStack(spacing: 8) {
                    Text("ALIGNMENT")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .foregroundColor(themeManager.theme.secondaryText)

                    Image(systemName: isAligned ? "checkmark" : "arrow.up")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(isAligned ? softGreen : themeManager.theme.primaryText)

                    Text(isAligned ? "Aligned" : proximityText)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(isAligned ? softGreen : themeManager.theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isAligned ? softGreen.opacity(0.1) : cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isAligned ? softGreen.opacity(0.3) : themeManager.theme.secondaryText.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }

    private var sacredLocationPermissionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)

            Text("Location Access Required")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(themeManager.theme.primaryText)

            Text("Enable location services to find Qibla direction")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var proximityText: String {
        switch proximityZone {
        case 3: return "Very Close"
        case 2: return "Close"
        case 1: return "Getting Close"
        default: return "Keep turning"
        }
    }

    // MARK: - Helpers
    private func triggerHaptic(for zone: Int) {
        switch zone {
        case 4: HapticManager.shared.notification(.success)
        case 3: HapticManager.shared.impact(.heavy)
        case 2: HapticManager.shared.impact(.medium)
        case 1: HapticManager.shared.impact(.light)
        default: break
        }
    }

    private func hapticInterval(for zone: Int) -> TimeInterval {
        switch zone {
        case 4: return 0.3
        case 3: return 0.5
        case 2: return 0.8
        case 1: return 1.2
        default: return 2.0
        }
    }

    private func rotationForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func headingToCardinal(_ heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45) % 8
        return directions[index]
    }
}

// MARK: - Sacred Celebration Overlay
struct SacredCelebrationOverlay: View {
    @Binding var isPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared

    // Animation states
    @State private var showContent = false
    @State private var ringScale1: CGFloat = 0.5
    @State private var ringScale2: CGFloat = 0.5
    @State private var ringScale3: CGFloat = 0.5
    @State private var ringOpacity1: Double = 0
    @State private var ringOpacity2: Double = 0
    @State private var ringOpacity3: Double = 0
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var particlePhase: Double = 0

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var overlayBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color.black.opacity(0.85)
            : Color.white.opacity(0.9)
    }

    var body: some View {
        ZStack {
            // Background
            overlayBackground
                .ignoresSafeArea()
                .onTapGesture {
                    dismissOverlay()
                }

            VStack(spacing: 32) {
                Spacer()

                // Animated rings and icon
                ZStack {
                    // Expanding rings
                    Circle()
                        .stroke(sacredGold.opacity(ringOpacity1 * 0.3), lineWidth: 1)
                        .frame(width: 200, height: 200)
                        .scaleEffect(ringScale1)

                    Circle()
                        .stroke(sacredGold.opacity(ringOpacity2 * 0.4), lineWidth: 1)
                        .frame(width: 160, height: 160)
                        .scaleEffect(ringScale2)

                    Circle()
                        .stroke(softGreen.opacity(ringOpacity3 * 0.5), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale3)

                    // Particles
                    ForEach(0..<12) { index in
                        Circle()
                            .fill(index % 2 == 0 ? sacredGold : softGreen)
                            .frame(width: 4, height: 4)
                            .offset(y: -80)
                            .rotationEffect(.degrees(Double(index) * 30 + particlePhase))
                            .opacity(showContent ? 0.6 : 0)
                    }

                    // Center icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [softGreen.opacity(0.2), softGreen.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [softGreen, sacredGold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                }

                // Text content
                VStack(spacing: 16) {
                    Text("ما شاء الله")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("ALL PRAYERS COMPLETED")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundColor(sacredGold)

                    Text("You've completed all five prayers today.\nMay Allah accept your prayers.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)

                Spacer()

                // Dismiss hint
                Text("Tap anywhere to continue")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText.opacity(0.6))
                    .opacity(textOpacity)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Icon animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Ring 1 (outer)
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            ringScale1 = 1.5
            ringOpacity1 = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            ringOpacity1 = 0
        }

        // Ring 2 (middle)
        withAnimation(.easeOut(duration: 0.9).delay(0.3)) {
            ringScale2 = 1.4
            ringOpacity2 = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            ringOpacity2 = 0
        }

        // Ring 3 (inner)
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            ringScale3 = 1.3
            ringOpacity3 = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            ringOpacity3 = 0
        }

        // Text animation
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            textOpacity = 1.0
            textOffset = 0
        }

        // Show content for particles
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            showContent = true
        }

        // Particle rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            particlePhase = 360
        }

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            dismissOverlay()
        }
    }

    private func dismissOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

#Preview {
    PrayerTimeView()
        .environmentObject(PrayerTimeViewModel(locationService: LocationService()))
}
