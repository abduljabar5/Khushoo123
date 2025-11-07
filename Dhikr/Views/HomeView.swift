//
//  HomeView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher

struct HomeView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var blockingState = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var prayerViewModel: PrayerTimeViewModel
    @State private var earlyUnlockTickHome = 0
    
    @State private var featuredReciter: Reciter?
    @State private var topReciter: Reciter?
    @State private var secondReciter: Reciter?
    @State private var thirdReciter: Reciter?
    @State private var popularReciters: [Reciter] = []
    @State private var soothingReciters: [Reciter] = []
    @State private var recentSurahs: [Surah] = []
    @State private var isLoading = true
    @State private var showingRecents = false
    @State private var showingAllPopular = false
    @State private var showingAllSoothing = false
    @State private var showingProfile = false
    @State private var verseOfTheDay: (arabic: String, translation: String, reference: String)?
    // Early-unlock countdown tick to drive UI updates
    @State private var earlyUnlockTick = 0
    // Statistics slideshow current page
    @State private var currentStatPage = 3 // Start at middle position for infinite scroll
    // Timer for auto-switching slideshow
    @State private var slideshowTimer: Timer?
    
    // Static lists of reciter names (English names as they appear in the API)
    private let popularReciterNames = [
        "Maher Al Meaqli",
        "Abdulbasit Abdulsamad",
        "Mishary Alafasi",
        "Saud Al-Shuraim",
        "Abdulrahman Alsudaes",
        "Ahmad Al-Ajmy",
        "Fares Abbad",
        "Yasser Al-Dosari",
        "Mohammed Ayyub",
        "Idrees Abkr"
    ]

    private let soothingReciterNames = [
        "Maher Al Meaqli",
        "Mishary Alafasi",
        "Saad Al-Ghamdi",
        "Abdulbasit Abdulsamad",
        "Yasser Al-Dosari",
        "Idrees Abkr",
        "Nasser Alqatami",
        "Ahmad Al-Ajmy",
        "Abdullah Al-Johany",
        "Mohammed Siddiq Al-Minshawi"
    ]
    
    var body: some View {
            ZStack {
                // Background for themes
                if themeManager.currentTheme == .liquidGlass {
                    LiquidGlassBackgroundView()
                } else if themeManager.currentTheme == .dark {
                Color.black
                        .ignoresSafeArea()
                } else {
                Color.white
                        .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Greeting Section
                        greetingSection

                        // Prayer Time Card
                        prayerTimeCard

                        // Featured Reciter
                        featuredReciterCard

                        // Quick Actions
                        quickActionsRow

                        // Reciter Carousels
                        reciterSections

                        // Statistics Slideshow
                        statisticsSlideshow

                        // Early Unlock Section (if applicable)
                        earlyUnlockSection
                    }
                    .padding(.horizontal, 20)
                .padding(.top, themeManager.currentTheme == .liquidGlass ? 50 : 8)
                    .padding(.bottom, audioPlayerService.currentSurah != nil ? 130 : 80)
                }
            .ignoresSafeArea(edges: themeManager.currentTheme == .liquidGlass ? [] : .bottom)
            }
        .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
            .onAppear {
                loadData()
                // Prayer time fetching starts automatically in the view model
                // Double-check blocking state on first appearance of Home
                BlockingStateService.shared.forceCheck()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    BlockingStateService.shared.forceCheck()
                }
            }
            .onReceive(quranAPIService.$reciters) { reciters in
                // Update when global reciters are loaded
                if !reciters.isEmpty && (featuredReciter == nil || popularReciters.isEmpty || soothingReciters.isEmpty) {
                    print("🔄 [HomeView] Global reciters loaded, updating UI")
                    processReciters(reciters)
                }
            }
            // Compact banner overlay at the very top (Home only)
            .overlay(alignment: .top) {
                if !blockingState.isStrictModeEnabled && blockingState.appsActuallyBlocked && !blockingState.isEarlyUnlockedActive {
                    EarlyUnlockCompactBannerHome()
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Smoothly tick the countdown once per second while Home is visible
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                earlyUnlockTick &+= 1
        }
        .sheet(isPresented: $showingRecents) {
            RecentsView()
                .environmentObject(audioPlayerService)
        }
        .sheet(isPresented: $showingAllPopular) {
            allRecitersSheet(title: "Popular Reciters", reciters: popularReciters)
        }
        .sheet(isPresented: $showingAllSoothing) {
            allRecitersSheet(title: "Soothing Reciters", reciters: soothingReciters)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView()
                    .environmentObject(audioPlayerService)
                    .environmentObject(quranAPIService)
            }
        }
    }

    // MARK: - All Reciters Sheet
    private func allRecitersSheet(title: String, reciters: [Reciter]) -> some View {
        NavigationView {
            ZStack {
                // Background for themes
                if themeManager.currentTheme == .liquidGlass {
                    LiquidGlassBackgroundView()
                } else if themeManager.currentTheme == .dark {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    Color.white
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(reciters.enumerated()), id: \.element.identifier) { index, reciter in
                            reciterListCard(reciter: reciter, rank: index + 1, showStyle: true)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if title == "Popular Reciters" {
                            showingAllPopular = false
                        } else {
                            showingAllSoothing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }
            }
        }
    }
    
    // MARK: - Greeting Section
    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("السلام عليكم")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(themeManager.theme.primaryAccent)

                Text(getGreeting())
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            Spacer()

            Button(action: {
                showingProfile = true
            }) {
                Circle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Prayer Time Card
    private var prayerTimeCard: some View {
        Group {
            if let nextPrayer = prayerViewModel.nextPrayer {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with title and location
                    HStack {
                        Text("Next Prayer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                            Text(prayerViewModel.locationName)
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }

                    // Prayer name in Arabic and English
                    Text(getPrayerNameInArabic(nextPrayer.name) + " - " + nextPrayer.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    // Large time display
                    Text(nextPrayer.time)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    // Countdown
                    Text("in " + prayerViewModel.timeUntilNextPrayer)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))

                    // Progress bar
                    HStack(spacing: 8) {
                        Text("\(prayerViewModel.completedPrayers)/\(prayerViewModel.totalPrayers)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * (CGFloat(prayerViewModel.completedPrayers) / CGFloat(prayerViewModel.totalPrayers)), height: 6)
                                    .animation(.easeInOut, value: prayerViewModel.completedPrayers)
                            }
                        }
                        .frame(height: 6)

                        Text("prayers today")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(24)
                .background(
                    Group {
                        if themeManager.theme.hasGlassEffect {
                            // Enhanced liquid glass effect for iOS 26+
                            if #available(iOS 26.0, *) {
                                RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius, style: .continuous)
                                    .glassEffect(.clear, in: .rect(cornerRadius: themeManager.theme.cardCornerRadius))
                                    .overlay(
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                // Fallback for older iOS versions
                                RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.3)
                                    .overlay(
                                        LinearGradient(
                                            colors: [themeManager.theme.prayerGradientStart.opacity(0.3), themeManager.theme.prayerGradientEnd.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        } else {
                            // Standard gradient for light/dark themes
                            LinearGradient(
                                colors: [themeManager.theme.prayerGradientStart, themeManager.theme.prayerGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .cornerRadius(themeManager.theme.cardCornerRadius)
            } else {
                // Loading placeholder for prayer time
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 100, height: 20)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 140, height: 32)
                            .shimmer()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 60, height: 14)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 80, height: 20)
                            .shimmer()
                    }
                }
                .padding(20)
                .background(
                    themeManager.currentTheme == .liquidGlass ?
                    AnyView(Color.clear) :
                    AnyView(
                        LinearGradient(
                            colors: [
                                themeManager.theme.prayerGradientStart.opacity(0.7),
                                themeManager.theme.prayerGradientEnd.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .glassCard(theme: themeManager.theme)
            }
        }
    }
    
    // MARK: - Featured Reciter Card
    private var featuredReciterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

                Text("Featured")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.theme.primaryText)

                Spacer()
            }

            // Main Featured Card
            if let reciter = featuredReciter {
                featuredMainCard(reciter: reciter)
            } else {
                featuredMainCardPlaceholder
            }

            // Bottom Two Cards
            HStack(spacing: 12) {
                if let reciter = secondReciter {
                    featuredSmallCard(reciter: reciter, rank: 2)
                } else {
                    featuredSmallCardPlaceholder
                }

                if let reciter = thirdReciter {
                    featuredSmallCard(reciter: reciter, rank: 3)
                } else {
                    featuredSmallCardPlaceholder
                }
            }
        }
    }

    // MARK: - Featured Main Card
    private func featuredMainCard(reciter: Reciter) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Reciter Image Background
                    KFImage(reciter.artworkURL)
                .placeholder {
                    ReciterPlaceholder(iconSize: 80)
                }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

            // Top Badges
            VStack {
                HStack(spacing: 8) {
                    // Crown Emoji + #1 Badge
                    HStack(spacing: 4) {
                        Text("👑")
                            .font(.system(size: 12))
                        Text("#1")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )

                            Spacer()

                    // Share Button
                    Button(action: {
                        // Share action
                    }) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                    }

                    // Favorite Button
                    Button(action: {
                        // Favorite action
                    }) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "heart")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .padding(12)

                Spacer()
            }

            // Bottom Info
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reciter.englishName)
                        .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                        .lineLimit(1)

                                    if let country = reciter.country {
                        HStack(spacing: 4) {
                                        Text(countryFlag(for: country))
                                .font(.system(size: 12))
                            Text(country)
                                .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                        }
                    }

                    HStack(spacing: 12) {
                        // Follower count
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.theme.primaryAccent)
                            Text("5.8M")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )

                        // Track count
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.theme.primaryAccent)
                            Text("114")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )
                                }
                            }

                            Spacer()

                // Play Button
                            Button(action: {
                                Task {
                                    await playRandomSurah(for: reciter)
                                }
                            }) {
                    Circle()
                        .fill(themeManager.theme.primaryAccent)
                        .frame(width: 50, height: 50)
                        .overlay(
                                    Image(systemName: "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        )
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .cornerRadius(16)
    }

    // MARK: - Featured Main Card Placeholder
    private var featuredMainCardPlaceholder: some View {
        ZStack(alignment: .bottomLeading) {
                                                    Rectangle()
                .fill(themeManager.theme.tertiaryBackground)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 150, height: 22)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 100, height: 12)
                    .shimmer()

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 24)
                        .shimmer()

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 50, height: 24)
                        .shimmer()
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .cornerRadius(16)
    }

    // MARK: - Featured Small Card
    private func featuredSmallCard(reciter: Reciter, rank: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Reciter Image Background
            KFImage(reciter.artworkURL)
                .placeholder {
                    ReciterPlaceholder(iconSize: 60)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 180)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Rank Badge (Top-left)
            VStack {
                HStack {
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text("#\(rank)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )

                    Spacer()
                }
                .padding(10)

                Spacer()
            }

            // Bottom Info with Stats and Play Button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reciter.englishName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let country = reciter.country {
                        HStack(spacing: 3) {
                            Text(countryFlag(for: country))
                                .font(.system(size: 9))
                            Text(country)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                    }

                    // Stats
                    HStack(spacing: 8) {
                        // Viewer count
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                                .foregroundColor(themeManager.theme.primaryAccent)
                            Text("\(String(format: "%.1f", Double.random(in: 2...5)))M")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )

                        // Surah count
                        HStack(spacing: 3) {
                            Image(systemName: "music.note")
                                .font(.system(size: 8))
                                .foregroundColor(themeManager.theme.primaryAccent)
                            Text("114")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.4))
                        )
                    }
                }

                Spacer()

                // Play Button (Right side)
                Button(action: {
                    Task {
                        await playRandomSurah(for: reciter)
                    }
                }) {
                    Circle()
                        .fill(themeManager.theme.primaryAccent)
                        .frame(width: 36, height: 36)
                    .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        )
                }
            }
            .padding(12)
        }
        .frame(height: 180)
        .cornerRadius(14)
    }

    // MARK: - Featured Small Card Placeholder
    private var featuredSmallCardPlaceholder: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(themeManager.theme.tertiaryBackground)
                .frame(height: 180)
                .shimmer()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 90, height: 13)
                        .shimmer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 70, height: 10)
                        .shimmer()

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 45, height: 18)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 18)
                            .shimmer()
                    }
                }

                Spacer()

                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .shimmer()
            }
            .padding(12)
        }
        .frame(height: 180)
        .cornerRadius(14)
    }
    
    // MARK: - Quick Actions Row
    private var quickActionsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

            Text("Quick Actions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(themeManager.theme.primaryText)

                Spacer()
            }

            HStack(spacing: 12) {
                // Qibla Compass
                CompassView()

                // Continue
                Button(action: {
                    _ = audioPlayerService.continueLastPlayed()
                }) {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.theme.prayerGradientStart, themeManager.theme.prayerGradientEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                        Text("Continue")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                // Liked
                NavigationLink(destination: LikedSurahsView()) {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                        Text("Liked")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                // Recent
                Button(action: {
                    showingRecents = true
                }) {
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            )
                        Text("Recent")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Reciter Sections
    private var reciterSections: some View {
        VStack(spacing: 24) {
            mostListenedSection
            peacefulRecitationsSection
            verseOfTheDaySection
            favoriteRecitersSection
        }
    }

    // MARK: - Most Listened Section
    private var mostListenedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Popular Reciters")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Top voices this week")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Button(action: {
                    showingAllPopular = true
                }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(themeManager.theme.primaryAccent)
                }
            }

            VStack(spacing: 12) {
                ForEach(Array(popularReciters.prefix(4).enumerated()), id: \.element.identifier) { index, reciter in
                    reciterListCard(reciter: reciter, rank: index + 1, showStyle: true)
                }
            }
        }
    }

    // MARK: - Peaceful Recitations Section
    private var peacefulRecitationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Soothing Reciters")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("For peaceful reflection")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                Button(action: {
                    showingAllSoothing = true
                }) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(themeManager.theme.primaryAccent)
                }
            }

            VStack(spacing: 12) {
                ForEach(Array(soothingReciters.prefix(4).enumerated()), id: \.element.identifier) { index, reciter in
                    reciterListCard(reciter: reciter, rank: index + 1, showStyle: true)
                }
            }
        }
    }

    // MARK: - Verse of the Day Section
    private var verseOfTheDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Verse of the Day")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Daily inspiration from the Quran")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()
            }

            if let verse = verseOfTheDay {
                VStack(alignment: .leading, spacing: 16) {
                    // Arabic Text
                    Text(verse.arabic)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineSpacing(8)
                        .padding(.top, 8)

                    Divider()
                        .background(themeManager.theme.secondaryText.opacity(0.3))

                    // Translation
                    Text(verse.translation)
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineSpacing(4)

                    // Reference
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.theme.primaryAccent)

                        Text(verse.reference)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryAccent)

                        Spacer()

                        Button(action: {
                            // Share verse
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(themeManager.theme.primaryAccent)
                        }
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        themeManager.theme.cardBackground

                        // Darkness gradient overlay (right side darker)
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                )
                .cornerRadius(16)
            } else {
                // Placeholder
                VStack(alignment: .leading, spacing: 16) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeManager.theme.tertiaryBackground)
                        .frame(height: 60)
                        .shimmer()

                    Divider()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.theme.tertiaryBackground)
                        .frame(height: 40)
                        .shimmer()

                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.theme.tertiaryBackground)
                            .frame(width: 120, height: 16)
                            .shimmer()
                        Spacer()
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        themeManager.theme.cardBackground

                        // Darkness gradient overlay (right side darker)
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                )
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Favorite Reciters Section
    @ViewBuilder
    private var favoriteRecitersSection: some View {
            if !favoritesManager.favoriteReciters.isEmpty {
                let sortedFavoriteIdentifiers = favoritesManager.favoriteReciters
                    .sorted { $0.dateAdded > $1.dateAdded }
                    .map { $0.identifier }
                let reciterDict = Dictionary(uniqueKeysWithValues: quranAPIService.reciters.map { ($0.identifier, $0) })
                let favoriteReciters = sortedFavoriteIdentifiers.compactMap { reciterDict[$0] }
                
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Rectangle()
                        .fill(themeManager.theme.primaryAccent)
                        .frame(width: 4, height: 24)

                    Text("Your Favorite Reciters")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryText)

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(favoriteReciters.prefix(5)), id: \.identifier) { reciter in
                            reciterCardView(reciter: reciter, showBadge: false)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Reciter Section Header
    private func reciterSectionHeader(title: String, actionTitle: String) -> some View {
        HStack {
            Rectangle()
                .fill(themeManager.theme.primaryAccent)
                .frame(width: 4, height: 24)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            Button(action: {
                // Navigate to see all
            }) {
                Text(actionTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.theme.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
        }
    }

    // MARK: - Reciter Card View
    private func reciterCardView(reciter: Reciter, showBadge: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                // Reciter Image with automatic fallback
                ReciterArtworkImage(
                    artworkURL: reciter.artworkURL,
                    reciterName: reciter.name,
                    size: 100
                )

                // Stats badge (only for Most Listened)
                if showBadge {
                    statsBadge
                }
            }

            // Reciter Name
            Text(reciter.englishName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 110)

            // Country
            if let country = reciter.country {
                Text(country)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
        .padding(.vertical, 20)
        .background(
            Group {
                if themeManager.theme.hasGlassEffect {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.theme.prayerGradientStart.opacity(0.75),
                                    themeManager.theme.prayerGradientEnd.opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    themeManager.theme.hasGlassEffect ?
                    Color.white.opacity(0.2) :
                    Color.clear,
                    lineWidth: 1
                )
        )
        .onTapGesture {
                        Task {
                            await playRandomSurah(for: reciter)
                        }
                    }
    }

    // MARK: - Stats Badge
    private var statsBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill")
                .font(.system(size: 8))
            Text("\(String(format: "%.1f", Double.random(in: 10...50)))K")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.8))
        )
        .offset(x: 8, y: -5)
    }

    // MARK: - Reciter List Card
    private func reciterListCard(reciter: Reciter, rank: Int, showStyle: Bool) -> some View {
        HStack(spacing: 0) {
            // Rank Badge + Image (fills to edges)
            ZStack(alignment: .topLeading) {
                KFImage(reciter.artworkURL)
                    .placeholder {
                        ReciterPlaceholder(size: 120, iconSize: 40)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipped()

                // Rank Badge
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7))
                    )
                    .offset(x: 8, y: 8)
            }
            .frame(width: 120, height: 120)

            // Info Section
            VStack(alignment: .leading, spacing: 6) {
                Text(reciter.englishName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(1)

                if let country = reciter.country {
                    HStack(spacing: 4) {
                        Text(countryFlag(for: country))
                            .font(.system(size: 12))
                        Text(country)
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }

                if showStyle {
                    Text(getReciterStyle(reciter.englishName))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryAccent)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(String(format: "%.1f", Double.random(in: 2...5)))M")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(themeManager.theme.secondaryText)

                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                        Text("114 Surahs")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(themeManager.theme.secondaryText)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Play Button
            Button(action: {
                Task {
                    await playRandomSurah(for: reciter)
                }
            }) {
                Circle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    )
            }
            .padding(.trailing, 12)
        }
        .frame(height: 120)
        .background(
            ZStack {
                themeManager.theme.cardBackground

                // Darkness gradient overlay (right side darker)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(14)
    }

    // MARK: - Get Reciter Style
    private func getReciterStyle(_ name: String) -> String {
        let styles = [
            "Mishary Rashid Alafasy": "Murattal Style",
            "Abdur Rahman As-Sudais": "Mujawwad Style",
            "Saad al-Ghamdi": "Classical Style",
            "Saud Al-Shuraim": "Hafs Style",
            "Islam Sobhi": "Calm Style",
            "Omar Hisham Al Arabi": "Clear Style"
        ]
        return styles[name] ?? "Murattal Style"
    }
    
    // MARK: - Statistics Slideshow
    private var statisticsSlideshow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(themeManager.theme.primaryAccent)
                    .frame(width: 4, height: 24)

                Text("Your Journey")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.theme.primaryText)
                Spacer()
                
                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(getActualPageIndex() == index ? themeManager.theme.primaryAccent : themeManager.theme.tertiaryBackground)
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: currentStatPage)
                    }
                }
            }
            
            TabView(selection: $currentStatPage) {
                // Duplicate slides for infinite scrolling
                // End slides (duplicates)
                mostListenedToBanner
                    .tag(0)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                listeningTimeBanner
                    .tag(1)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                surahsProgressBanner
                    .tag(2)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                // Main slides
                listeningTimeBanner
                    .tag(3)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                surahsProgressBanner
                    .tag(4)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                mostListenedToBanner
                    .tag(5)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                // Beginning slides (duplicates)
                listeningTimeBanner
                    .tag(6)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                surahsProgressBanner
                    .tag(7)
                    .padding(.horizontal, 4)
                    .frame(height: 120)

                mostListenedToBanner
                    .tag(8)
                    .padding(.horizontal, 4)
                    .frame(height: 120)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 140)
            .onChange(of: currentStatPage) { newPage in
                handlePageChange(newPage)
            }
            .onAppear {
                startSlideshowTimer()
            }
            .onDisappear {
                stopSlideshowTimer()
            }
        }
    }
    
    // MARK: - Listening Time Banner
    private var listeningTimeBanner: some View {
        HStack(spacing: 20) {
            // Icon and time
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(themeManager.theme.primaryAccent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Listening")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                        Text(formatListeningTime(audioPlayerService.totalListeningTime))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                }
                
                // Weekly stats
                HStack(spacing: 3) {
                    ForEach(0..<7) { day in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                day < 4 ?
                                LinearGradient(
                                    colors: [themeManager.theme.primaryAccent, themeManager.theme.secondaryAccent],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ) :
                                LinearGradient(
                                    colors: [themeManager.theme.tertiaryBackground, themeManager.theme.tertiaryBackground],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 5, height: CGFloat.random(in: 12...25))
                    }
                }
            }
            
            Spacer()
            
            // Decorative element
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.theme.primaryAccent.opacity(0.2),
                                themeManager.theme.secondaryAccent.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(themeManager.theme.primaryAccent)
            }
        }
        .padding(16)
        .frame(height: 120)
        .background(
            ZStack {
            Group {
                if themeManager.theme.hasGlassEffect {
                    // Enhanced liquid glass effect for iOS 26+
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius, style: .continuous)
                            .glassEffect(.clear, in: .rect(cornerRadius: themeManager.theme.cardCornerRadius))
                    } else {
                        // Fallback for older iOS versions
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                } else {
                    // Standard background for light/dark themes
                    themeManager.theme.secondaryBackground
                }
                }

                // Darkness gradient overlay (right side darker)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(themeManager.theme.cardCornerRadius)
    }
    
    // MARK: - Surahs Progress Banner
    private var surahsProgressBanner: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundColor(themeManager.theme.accentGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surahs Completed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                        Text("\(audioPlayerService.completedSurahNumbers.count) of 114")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(themeManager.theme.primaryText)
                    }
                }
                
                // Progress bar - fixed height
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.theme.tertiaryBackground)
                        .frame(height: 8)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.theme.accentGreen, themeManager.theme.primaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * (Double(audioPlayerService.completedSurahNumbers.count) / 114.0), height: 8)
                            .animation(.spring(), value: audioPlayerService.completedSurahNumbers.count)
                    }
                }
                .frame(height: 8)
                
                Text("\(Int((Double(audioPlayerService.completedSurahNumbers.count) / 114.0) * 100))% Complete")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.theme.secondaryText)
                
                // Add spacer to fill remaining height
                Spacer(minLength: 0)
            }
            
            Spacer()
            
            // Visual indicator
            ZStack {
                Circle()
                    .stroke(themeManager.theme.tertiaryBackground, lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: Double(audioPlayerService.completedSurahNumbers.count) / 114.0)
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.theme.accentGreen, themeManager.theme.primaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: audioPlayerService.completedSurahNumbers.count)

                Text("\(audioPlayerService.completedSurahNumbers.count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(themeManager.theme.primaryText)
            }
        }
        .padding(16)
        .frame(height: 120)
        .background(
            ZStack {
            Group {
                if themeManager.theme.hasGlassEffect {
                    // Enhanced liquid glass effect for iOS 26+
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius, style: .continuous)
                            .glassEffect(.clear, in: .rect(cornerRadius: themeManager.theme.cardCornerRadius))
                    } else {
                        // Fallback for older iOS versions
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                } else {
                    // Standard background for light/dark themes
                    themeManager.theme.secondaryBackground
                }
                }

                // Darkness gradient overlay (right side darker)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(themeManager.theme.cardCornerRadius)
    }
    
    // MARK: - Most Listened To Banner
    private var mostListenedToBanner: some View {
        HStack(spacing: 16) {
            if let mostListenedReciter = getMostListenedReciter() {
                // Reciter avatar with automatic fallback
                ReciterArtworkImage(
                    artworkURL: mostListenedReciter.artworkURL,
                    reciterName: mostListenedReciter.name,
                    size: 50
                )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [themeManager.theme.accentTeal, themeManager.theme.primaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )

                // Info section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Listened To")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text(getMostListenedReciterName())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Text("\(getListenCountForReciter(mostListenedReciter)) plays")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)

                        if let country = mostListenedReciter.country {
                            Text(countryFlag(for: country) + " " + country)
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.theme.secondaryText)
                        }
                    }
                }

                Spacer()
            } else {
                // Empty state
                VStack(alignment: .leading, spacing: 4) {
                    Text("Most Listened To")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text("Start listening")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Play surahs to track your favorites")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()
            }
        }
        .padding(16)
        .frame(height: 120)
        .background(
            ZStack {
            Group {
                if themeManager.theme.hasGlassEffect {
                    // Enhanced liquid glass effect for iOS 26+
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius, style: .continuous)
                            .glassEffect(.clear, in: .rect(cornerRadius: themeManager.theme.cardCornerRadius))
                    } else {
                        // Fallback for older iOS versions
                        RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                } else {
                    // Standard background for light/dark themes
                    themeManager.theme.secondaryBackground
                }
                }

                // Darkness gradient overlay (right side darker)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(themeManager.theme.cardCornerRadius)
    }
    
    // MARK: - Early Unlock Section
    private var earlyUnlockSection: some View {
        Group {
            if !blockingState.isStrictModeEnabled && blockingState.appsActuallyBlocked && !blockingState.isEarlyUnlockedActive {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 4, height: 24)

                        Text("Early Unlock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)

                        Spacer()
                    }
                    
                    let remaining = blockingState.timeUntilEarlyUnlock()
                    if remaining > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "hourglass")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Available Soon")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.theme.primaryText)

                        Text("You can unlock apps in")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.theme.secondaryText)
                                }

                                Spacer()
                            }

                        HStack {
                            Text(remaining.formattedForCountdown)
                                    .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.orange)
                                    .monospacedDigit()

                            Spacer()
                        }

                            HStack(spacing: 8) {
                                Image(systemName: "hourglass")
                                    .font(.system(size: 14))
                                Text("Countdown in progress...")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(themeManager.theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: "lock.open.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.orange)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ready to Unlock")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeManager.theme.primaryText)

                                    Text("You can now unlock apps early")
                                        .font(.system(size: 13))
                                        .foregroundColor(themeManager.theme.secondaryText)
                                }

                                Spacer()
                            }

                        Button(action: {
                            blockingState.earlyUnlockCurrentInterval()
                        }) {
                                HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 16))
                                Text("Unlock Apps Now")
                                        .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.orange.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                    Group {
                            if themeManager.theme.hasGlassEffect {
                                // Enhanced liquid glass effect for iOS 26+
                                if #available(iOS 26.0, *) {
                                    RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius, style: .continuous)
                                        .glassEffect(.clear, in: .rect(cornerRadius: themeManager.theme.cardCornerRadius))
                        } else {
                                    // Fallback for older iOS versions
                                    RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.3)
                                }
                            } else {
                                // Standard background for light/dark themes
                            themeManager.theme.cardBackground
                        }
                    }

                        // Darkness gradient overlay (right side darker)
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                )
                .cornerRadius(themeManager.theme.cardCornerRadius)
            }
        }
    }

    // MARK: - Compact Early Unlock Banner (Home only)
    private struct EarlyUnlockCompactBannerHome: View {
        @StateObject private var blocking = BlockingStateService.shared
        @ObservedObject private var themeManager = ThemeManager.shared

        var body: some View {
            let remaining = blocking.timeUntilEarlyUnlock()

            HStack(spacing: 12) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: remaining > 0 ? "hourglass" : "lock.open.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                // Notification Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("DHIKR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeManager.theme.secondaryText)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.theme.secondaryText.opacity(0.5))

                        Text("now")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.theme.secondaryText)

                        Spacer()
                    }

                if remaining > 0 {
                        Text("Early Unlock Available Soon")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Unlock in \(remaining.formattedForCountdown)")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                } else {
                        Text("Early Unlock Ready")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        Text("Tap to unlock apps now")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Action Button
                if remaining <= 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Group {
                    if themeManager.theme.hasGlassEffect {
                        // Enhanced liquid glass effect for iOS 26+
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .glassEffect(.clear, in: .rect(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                        } else {
                            // Fallback for older iOS versions
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                        }
                    } else if themeManager.currentTheme == .dark {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
                            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        themeManager.theme.hasGlassEffect ?
                        Color.white.opacity(0.2) :
                        Color.clear,
                        lineWidth: 1
                    )
            )
            .onTapGesture {
                if remaining <= 0 {
                    blocking.earlyUnlockCurrentInterval()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatListeningTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
    
    // MARK: - Slideshow Timer Functions
    private func startSlideshowTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                advanceToNextSlide()
            }
        }
    }
    
    private func stopSlideshowTimer() {
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
    
    // MARK: - Infinite Scroll Helper Functions
    private func advanceToNextSlide() {
        if currentStatPage >= 5 { // At last main slide, jump to first main slide
            currentStatPage = 3
        } else {
            currentStatPage += 1
        }
    }
    
    private func handlePageChange(_ newPage: Int) {
        // Reset timer only for manual changes
        if abs(newPage - currentStatPage) != 1 {
            startSlideshowTimer()
        }
        
        // Handle infinite scroll wraparound for manual swipes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if newPage <= 2 { // Swiped to beginning duplicates, jump to end of main section
                self.currentStatPage = newPage + 3
            } else if newPage >= 6 { // Swiped to end duplicates, jump to beginning of main section
                self.currentStatPage = newPage - 3
            }
        }
    }
    
    private func getActualPageIndex() -> Int {
        // Map the current page to the actual page index (0, 1, 2)
        switch currentStatPage {
        case 0, 3, 6: return 0 // Listening Time
        case 1, 4, 7: return 1 // Surahs Progress
        case 2, 5, 8: return 2 // Most Listened To
        default: return 0
        }
    }
    
    // MARK: - Most Listened To Functions
    private func getMostListenedReciter() -> Reciter? {
        let reciterCounts = Dictionary(grouping: RecentsManager.shared.recentItems, by: { $0.reciter.identifier })
            .mapValues { $0.count }
        
        guard let mostPlayedIdentifier = reciterCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }
        
        return quranAPIService.reciters.first { $0.identifier == mostPlayedIdentifier }
    }
    
    private func getMostListenedReciterName() -> String {
        if let reciter = getMostListenedReciter() {
            return reciter.englishName
        }
        return "No plays yet"
    }
    
    private func getListenCountForReciter(_ reciter: Reciter) -> Int {
        return RecentsManager.shared.recentItems.filter { $0.reciter.identifier == reciter.identifier }.count
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private func countryFlag(for country: String) -> String {
        let flags: [String: String] = [
            "Saudi Arabia": "🇸🇦",
            "Egypt": "🇪🇬",
            "Kuwait": "🇰🇼",
            "UAE": "🇦🇪",
            "Jordan": "🇯🇴",
            "Yemen": "🇾🇪",
            "Sudan": "🇸🇩",
            "Pakistan": "🇵🇰",
            "India": "🇮🇳",
            "Indonesia": "🇮🇩",
            "Malaysia": "🇲🇾",
            "Turkey": "🇹🇷",
            "Iran": "🇮🇷",
            "Morocco": "🇲🇦",
            "Algeria": "🇩🇿",
            "Tunisia": "🇹🇳"
        ]
        return flags[country] ?? "🌍"
    }

    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = authService.isAuthenticated ? (authService.currentUser?.displayName ?? "there") : "there"

        switch hour {
        case 0..<12:
            return "Good morning, \(name)"
        case 12..<17:
            return "Good afternoon, \(name)"
        default:
            return "Good evening, \(name)"
        }
    }

    private func getPrayerNameInArabic(_ englishName: String) -> String {
        let arabicNames: [String: String] = [
            "Fajr": "الفجر",
            "Sunrise": "الشروق",
            "Dhuhr": "الظهر",
            "Asr": "العصر",
            "Maghrib": "المغرب",
            "Isha": "العشاء"
        ]
        return arabicNames[englishName] ?? ""
    }
    
    // MARK: - Hero Banner (keeping for compatibility)
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let reciter = featuredReciter {
                ZStack(alignment: .bottomLeading) {
                    // Background Image
                    KFImage(reciter.artworkURL)
                        .placeholder {
                            ReciterPlaceholder(iconSize: 60)
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(16)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Featured Reciter")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            if let country = reciter.country {
                                Text(country)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }
                        }

                        Text(reciter.englishName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if let dialect = reciter.dialect {
                            Text(dialect.uppercased())
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // Play Button
                        Button(action: {
                            Task {
                                await playRandomSurah(for: reciter)
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Listen Now")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(20)
                        }
                    }
                    .padding(20)
                }
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Dhikr Counter
                NavigationLink(destination:
                    DhikrWidgetView()
                        .environmentObject(dhikrService)
                        .environmentObject(bluetoothService)
                ) {
                    QuickActionCard(
                        title: "Dhikr",
                        subtitle: "\(dhikrService.getTodayStats().total) today",
                        icon: "heart.fill",
                        color: .green
                    )
                }
                
                // Continue Listening
                Button(action: {
                    _ = audioPlayerService.continueLastPlayed()
                }) {
                    QuickActionCard(
                        title: "Continue",
                        subtitle: getContinueSubtitle(),
                        icon: "play.fill",
                        color: .blue
                    )
                }
                
                // Liked
                NavigationLink(destination: LikedSurahsView()) {
                    QuickActionCard(
                        title: "Liked",
                        subtitle: "\(audioPlayerService.likedItems.count) tracks",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                // Most Recent Played
                Button(action: {
                    showingRecents = true
                }) {
                    QuickActionCard(
                        title: "Recent",
                        subtitle: getRecentSubtitle(),
                        icon: "clock.fill",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Category Rows
    private var categoryRows: some View {
        VStack(spacing: 24) {
            // Popular Reciters
            CategoryRow(
                title: "Most Popular Reciters",
                items: popularReciters,
                itemView: { reciter in
                    ReciterCard(reciter: reciter)
                        .onTapGesture {
                            Task {
                                await playRandomSurah(for: reciter)
                            }
                        }
                }
            )
            
            // Soothing Reciters
            CategoryRow(
                title: "Most Soothing Reciters",
                items: soothingReciters,
                itemView: { reciter in
                    ReciterCard(reciter: reciter)
                        .onTapGesture {
                            Task {
                                await playRandomSurah(for: reciter)
                            }
                        }
                }
            )
            
            // Favorite Reciters
            if !favoritesManager.favoriteReciters.isEmpty {
                // Sort favorite items by date, then map to full Reciter objects
                let sortedFavoriteIdentifiers = favoritesManager.favoriteReciters
                    .sorted { $0.dateAdded > $1.dateAdded }
                    .map { $0.identifier }

                // Create a dictionary for quick lookups
                let reciterDict = Dictionary(uniqueKeysWithValues: quranAPIService.reciters.map { ($0.identifier, $0) })
                
                // Map the sorted identifiers to reciter objects
                let favoriteReciters = sortedFavoriteIdentifiers.compactMap { reciterDict[$0] }
                
                CategoryRow(
                    title: "Favorite Reciters",
                    items: favoriteReciters,
                    itemView: { reciter in
                        NavigationLink(destination: ReciterDetailView(reciter: reciter)) {
                            ReciterCard(reciter: reciter)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                )
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        print("🏠 [HomeView] Starting data loading...")

        // Load verse of the day
        loadVerseOfTheDay()
        
        // Check if reciters are already available from the service
        if !quranAPIService.reciters.isEmpty {
            print("🏠 [HomeView] Using already loaded reciters from service: \(quranAPIService.reciters.count)")
            processReciters(quranAPIService.reciters)
            return
        }
        
        // Check if service is currently loading
        if quranAPIService.isLoadingReciters {
            print("🏠 [HomeView] Service is loading, waiting...")
        }
        
        Task {
            do {
                print("🏠 [HomeView] Fetching reciters...")
                let reciters = try await quranAPIService.fetchReciters()
                print("🏠 [HomeView] Successfully fetched \(reciters.count) reciters")

                await MainActor.run {
                    processReciters(reciters)
                }
            } catch QuranAPIError.loadingInProgress {
                // Global loading is in progress - UI will update via publisher
                print("🔄 [HomeView] Global loading in progress, waiting for publisher update")
                // Keep loading state, onReceive will handle the update
            } catch {
                print("❌ [HomeView] Failed to load data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func processReciters(_ reciters: [Reciter]) {
        print("🏠 [HomeView] Processing \(reciters.count) reciters...")
                
        // Filter reciters by English name
                        self.popularReciters = Array(reciters.filter { popularReciterNames.contains($0.englishName) }.prefix(10))
                        self.soothingReciters = Array(reciters.filter { soothingReciterNames.contains($0.englishName) }.prefix(10))

        // Randomly select featured reciters from popular list
        let shuffledPopular = self.popularReciters.shuffled()
        self.featuredReciter = shuffledPopular.first ?? reciters.randomElement()
        self.secondReciter = shuffledPopular.dropFirst().first ?? reciters.randomElement()
        self.thirdReciter = shuffledPopular.dropFirst(2).first ?? reciters.randomElement()
                    
                    self.isLoading = false
        print("✅ [HomeView] Data loaded and UI updated. Popular: \(popularReciters.count), Soothing: \(soothingReciters.count), Featured: \(featuredReciter?.englishName ?? "none"), #2: \(secondReciter?.englishName ?? "none"), #3: \(thirdReciter?.englishName ?? "none")")
    }

    private func loadVerseOfTheDay() {
        // A collection of meaningful verses
        let verses: [(arabic: String, translation: String, reference: String)] = [
            (
                arabic: "وَمَن يَتَّقِ ٱللَّهَ يَجْعَل لَّهُۥ مَخْرَجًا",
                translation: "And whoever fears Allah - He will make for him a way out.",
                reference: "Surah At-Talaq (65:2)"
            ),
            (
                arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
                translation: "For indeed, with hardship [will be] ease.",
                reference: "Surah Ash-Sharh (94:5)"
            ),
            (
                arabic: "وَلَا تَيْأَسُوا۟ مِن رَّوْحِ ٱللَّهِ",
                translation: "And never despair of the mercy of Allah.",
                reference: "Surah Yusuf (12:87)"
            ),
            (
                arabic: "إِنَّ ٱللَّهَ مَعَ ٱلصَّٰبِرِينَ",
                translation: "Indeed, Allah is with the patient.",
                reference: "Surah Al-Baqarah (2:153)"
            ),
            (
                arabic: "رَبَّنَا وَلَا تُحَمِّلْنَا مَا لَا طَاقَةَ لَنَا بِهِ",
                translation: "Our Lord, and burden us not with that which we have no ability to bear.",
                reference: "Surah Al-Baqarah (2:286)"
            ),
            (
                arabic: "وَٱذْكُر رَّبَّكَ إِذَا نَسِيتَ",
                translation: "And remember your Lord when you forget.",
                reference: "Surah Al-Kahf (18:24)"
            ),
            (
                arabic: "إِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
                translation: "Verily, with hardship comes ease.",
                reference: "Surah Ash-Sharh (94:6)"
            ),
            (
                arabic: "وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ",
                translation: "And He is with you wherever you are.",
                reference: "Surah Al-Hadid (57:4)"
            )
        ]

        // Use day of year to select a verse (changes daily)
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let selectedVerse = verses[dayOfYear % verses.count]

        verseOfTheDay = selectedVerse
    }
    
    private func playRandomSurah(for reciter: Reciter) async {
        Task {
            do {
                let allSurahs = try await quranAPIService.fetchSurahs()
                let surahToPlay = allSurahs.randomElement()

                if let surah = surahToPlay {
                    await MainActor.run {
                        audioPlayerService.load(surah: surah, reciter: reciter)
                    }
                }
            } catch {
                print("❌ [HomeView] Could not play random surah: \(error)")
            }
        }
    }
    
    private func getContinueSubtitle() -> String {
        if let surah = audioPlayerService.currentSurah {
            return "Surah \(surah.englishName)"
        }
        return "Nothing playing"
    }
    
    private func getLikedCount() -> Int {
        return audioPlayerService.likedItems.count
    }
    
    private func getRecentSubtitle() -> String {
        if let mostRecent = RecentsManager.shared.recentItems.first {
            return "Last: \(mostRecent.surah.englishName)"
        }
        return "No tracks played"
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Group {
                if themeManager.currentTheme == .liquidGlass {
                    Color.clear
                } else if themeManager.currentTheme == .dark {
                    Color(red: 0.15, green: 0.17, blue: 0.20)
                } else {
                    Color(.secondarySystemBackground)
                }
            }
        )
        .cornerRadius(12)
    }
}

// MARK: - Category Row
struct CategoryRow<Item: Identifiable, ItemView: View>: View {
    let title: String
    let items: [Item]
    let itemView: (Item) -> ItemView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        itemView(item)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Reciter Card
struct ReciterCard: View {
    let reciter: Reciter
    
    var body: some View {
        VStack {
            ReciterArtworkImage(
                artworkURL: reciter.artworkURL,
                reciterName: reciter.name,
                size: 120
            )
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))

            Text(reciter.englishName)
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
        }
    }
}

// MARK: - Surah Card
struct SurahCard: View {
    let surah: Surah
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    
    var body: some View {
        Button(action: {
            // Get the first available reciter and play the surah
            Task {
                do {
                    let reciters = try await quranAPIService.fetchReciters()
                    // Use any available reciter since we now support verse-by-verse audio for all
                    if let firstReciter = reciters.first {
                        await MainActor.run {
                            audioPlayerService.load(surah: surah, reciter: firstReciter)
                        }
                    } else {
                        print("❌ [SurahCard] No reciters available")
                    }
                } catch {
                    print("❌ [SurahCard] Failed to fetch reciters: \(error)")
                }
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Surah Art
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("\(surah.number)")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    )
                
                // Surah Info
                Text(surah.englishName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(surah.numberOfAyahs) Ayahs")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Reciter Placeholder
struct ReciterPlaceholder: View {
    var size: CGFloat? = nil
    var iconSize: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "0B1420") : Color(hex: "ECECEC"))
            Image(systemName: "person.circle.fill")
                .font(.system(size: iconSize))
                .foregroundColor(colorScheme == .dark ? Color(hex: "78909C") : Color(hex: "CECECE"))
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HomeView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
        .environmentObject(DhikrService.shared)
} 