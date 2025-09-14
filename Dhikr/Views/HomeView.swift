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
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var blockingState = BlockingStateService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var prayerViewModel = PrayerTimeViewModel()
    @State private var earlyUnlockTickHome = 0
    
    @State private var featuredReciter: Reciter?
    @State private var popularReciters: [Reciter] = []
    @State private var soothingReciters: [Reciter] = []
    @State private var recentSurahs: [Surah] = []
    @State private var isLoading = true
    @State private var showingFullScreenPlayer = false
    @State private var showingRecents = false
    // Early-unlock countdown tick to drive UI updates
    @State private var earlyUnlockTick = 0
    // Statistics slideshow current page
    @State private var currentStatPage = 3 // Start at middle position for infinite scroll
    // Timer for auto-switching slideshow
    @State private var slideshowTimer: Timer?
    
    // Static lists of reciter names
    private let popularReciterNames = [
        "Abdur Rahman As-Sudais",
        "Mishary Rashid Alafasy",
        "Saad al-Ghamdi",
        "Saud Al-Shuraim",
        "Ahmed Al Ajmi",
        "Muhammad Siddiq al-Minshawi",
        "Abu Bakr al-Shatri",
        "Nasser Al Qatami",
        "Bandar Baleela",
        "Yasser Al Dossari"
    ]

    private let soothingReciterNames = [
        "Islam Sobhi",
        "Omar Hisham Al Arabi",
        "Hazza Al Balushi",
        "Noreen Muhammad Siddique",
        "Raad Muhammad Al-Kurdi",
        "Salman Al-Utaybi",
        "Wadee Hammadi Al Yamani",
        "Abdul Wadood Haneef",
        "Abdul-Kareem Al Hazmi",
        "Mahmoud Ali Al Banna"
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background for themes
                if themeManager.currentTheme == .liquidGlass {
                    LiquidGlassBackgroundView(
                        backgroundType: themeManager.liquidGlassBackground,
                        backgroundImageURL: themeManager.selectedBackgroundImageURL
                    )
                } else {
                    themeManager.theme.primaryBackground
                        .ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Add top spacing
                        Spacer()
                            .frame(height: 20)
                        
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
                    .padding(.bottom, audioPlayerService.currentSurah != nil ? 130 : 80)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
            .onAppear {
                loadData()
                prayerViewModel.start()
                // Double-check blocking state on first appearance of Home
                BlockingStateService.shared.forceCheck()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                    BlockingStateService.shared.forceCheck()
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
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
        .sheet(isPresented: $showingRecents) {
            RecentsView()
                .environmentObject(audioPlayerService)
        }
    }
    
    // MARK: - Prayer Time Card
    private var prayerTimeCard: some View {
        Group {
            if let nextPrayer = prayerViewModel.nextPrayer {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextPrayer.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text(nextPrayer.timeString)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Starts in")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text(formatTimeInterval(prayerViewModel.timeValue))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                .background(
                    themeManager.currentTheme == .liquidGlass ?
                    AnyView(Color.clear) :
                    AnyView(
                        LinearGradient(
                            colors: [themeManager.theme.prayerGradientStart, themeManager.theme.prayerGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .glassCard(theme: themeManager.theme)
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
        VStack(spacing: 0) {
            if let reciter = featuredReciter {
                ZStack(alignment: .bottom) {
                    // Background with reciter image
                    KFImage(reciter.artworkURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0),
                                    Color.black.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Content overlay
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Featured Reciter")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                        
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reciter.englishName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 8) {
                                    if let country = reciter.country {
                                        Text(countryFlag(for: country))
                                            .font(.system(size: 18))
                                    }
                                    Text("Surah Al-Fatihah")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await playRandomSurah(for: reciter)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                    Text("Listen")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(themeManager.theme.primaryText)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    themeManager.currentTheme == .liquidGlass ?
                                    AnyView(
                                        Group {
                                            if #available(iOS 26, *) {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(Color.white.opacity(0.2))
                                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                                            } else {
                                                ZStack {
                                                    Color.clear
                                                    Rectangle()
                                                        .fill(.ultraThinMaterial)
                                                        .opacity(0.4)
                                                }
                                            }
                                        }
                                    ) :
                                    AnyView(Color.white)
                                )
                                .cornerRadius(20)
                            }
                        }
                        
                        // Audio waveform visualization
                        HStack(spacing: 3) {
                            ForEach(0..<35) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        audioPlayerService.currentReciter?.identifier == reciter.identifier && audioPlayerService.isPlaying ?
                                        Color.white : Color.white.opacity(0.3)
                                    )
                                    .frame(width: 3, height: CGFloat.random(in: 8...25))
                                    .animation(
                                        audioPlayerService.isPlaying ?
                                        Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.05) :
                                        .default,
                                        value: audioPlayerService.isPlaying
                                    )
                            }
                        }
                        .frame(height: 25)
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .glassCard(theme: themeManager.theme)
            } else {
                // Loading state
                RoundedRectangle(cornerRadius: themeManager.theme.cardCornerRadius)
                    .fill(themeManager.theme.secondaryBackground)
                    .frame(height: 220)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
                    .glassCard(theme: themeManager.theme)
            }
        }
    }
    
    // MARK: - Quick Actions Row
    private var quickActionsRow: some View {
        HStack(spacing: 15) {
            NavigationLink(destination: 
                DhikrWidgetView()
                    .environmentObject(dhikrService)
                    .environmentObject(bluetoothService)
            ) {
                QuickActionButtonView(
                    icon: "sparkles",
                    label: "Dhikr",
                    value: "\(dhikrService.getTodayStats().total)",
                    theme: themeManager.theme
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            QuickActionButton(
                icon: "play.circle.fill",
                label: "Continue",
                value: audioPlayerService.currentSurah != nil ? "Playing" : "Resume",
                theme: themeManager.theme,
                action: {
                    _ = audioPlayerService.continueLastPlayed()
                }
            )
            
            NavigationLink(destination: LikedSurahsView()) {
                QuickActionButtonView(
                    icon: "heart.fill",
                    label: "Liked",
                    value: "\(audioPlayerService.likedItems.count)",
                    theme: themeManager.theme
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            QuickActionButton(
                icon: "clock.fill",
                label: "Recent",
                value: "\(RecentsManager.shared.recentItems.count)",
                theme: themeManager.theme,
                action: {
                    showingRecents = true
                }
            )
        }
    }
    
    // MARK: - Reciter Sections
    private var reciterSections: some View {
        VStack(spacing: 24) {
            ReciterCarousel(
                title: "Most Popular Reciters",
                reciters: popularReciters,
                theme: themeManager.theme,
                onReciterTap: { reciter in
                    Task {
                        await playRandomSurah(for: reciter)
                    }
                }
            )
            
            ReciterCarousel(
                title: "Soothing Reciters",
                reciters: soothingReciters,
                theme: themeManager.theme,
                onReciterTap: { reciter in
                    Task {
                        await playRandomSurah(for: reciter)
                    }
                }
            )
            
            if !favoritesManager.favoriteReciters.isEmpty {
                let sortedFavoriteIdentifiers = favoritesManager.favoriteReciters
                    .sorted { $0.dateAdded > $1.dateAdded }
                    .map { $0.identifier }
                let reciterDict = Dictionary(uniqueKeysWithValues: quranAPIService.reciters.map { ($0.identifier, $0) })
                let favoriteReciters = sortedFavoriteIdentifiers.compactMap { reciterDict[$0] }
                
                ReciterCarousel(
                    title: "Your Favorite Reciters",
                    reciters: favoriteReciters,
                    theme: themeManager.theme,
                    onReciterTap: { reciter in
                        Task {
                            await playRandomSurah(for: reciter)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Statistics Slideshow
    private var statisticsSlideshow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
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
                    .frame(minHeight: 140, maxHeight: 140)
                
                listeningTimeBanner
                    .tag(1)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                surahsProgressBanner
                    .tag(2)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                // Main slides
                listeningTimeBanner
                    .tag(3)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                surahsProgressBanner
                    .tag(4)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                mostListenedToBanner
                    .tag(5)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                // Beginning slides (duplicates)
                listeningTimeBanner
                    .tag(6)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                surahsProgressBanner
                    .tag(7)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
                
                mostListenedToBanner
                    .tag(8)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 140, maxHeight: 140)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 160)
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
                HStack(spacing: 4) {
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
                            .frame(width: 6, height: CGFloat.random(in: 15...40))
                    }
                }
                .padding(.top, 8)
                
                Text("Keep up the great progress!")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.theme.secondaryText)
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
                    .frame(width: 80, height: 80)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.theme.primaryAccent)
            }
        }
        .padding(20)
        .background(themeManager.theme.secondaryBackground)
        .cornerRadius(themeManager.theme.cardCornerRadius)
        .glassCard(theme: themeManager.theme)
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
                    .stroke(themeManager.theme.tertiaryBackground, lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: Double(audioPlayerService.completedSurahNumbers.count) / 114.0)
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.theme.accentGreen, themeManager.theme.primaryAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: audioPlayerService.completedSurahNumbers.count)
                
                Text("\(audioPlayerService.completedSurahNumbers.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.theme.primaryText)
            }
        }
        .padding(20)
        .background(themeManager.theme.secondaryBackground)
        .cornerRadius(themeManager.theme.cardCornerRadius)
        .glassCard(theme: themeManager.theme)
    }
    
    // MARK: - Most Listened To Banner
    private var mostListenedToBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.theme.accentTeal)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Most Listened To")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.theme.secondaryText)
                    Text(getMostListenedReciterName())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            if let mostListenedReciter = getMostListenedReciter() {
                HStack(spacing: 16) {
                    // Reciter avatar
                    KFImage(mostListenedReciter.artworkURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(getListenCountForReciter(mostListenedReciter)) plays")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.theme.primaryText)
                        
                        if let country = mostListenedReciter.country {
                            Text(countryFlag(for: country) + " " + country)
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.theme.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
            } else {
                Text("Start listening to see your most played reciter")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.theme.secondaryText)
                    .padding(.top, 8)
            }
        }
        .padding(20)
        .background(themeManager.theme.secondaryBackground)
        .cornerRadius(themeManager.theme.cardCornerRadius)
        .glassCard(theme: themeManager.theme)
    }
    
    // MARK: - Early Unlock Section
    private var earlyUnlockSection: some View {
        Group {
            if !blockingState.isStrictModeEnabled && blockingState.appsActuallyBlocked && !blockingState.isEarlyUnlockedActive {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.orange)
                        Text("Early Unlock Available Soon")
                            .font(.headline)
                    }
                    .padding(.bottom, 4)
                    
                    let remaining = blockingState.timeUntilEarlyUnlock()
                    if remaining > 0 {
                        Text("You can unlock apps in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(remaining.formattedForCountdown)
                                .font(.title3).monospacedDigit()
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "hourglass")
                                Text("Unlock after countdown")
                            }
                        }
                        .disabled(true)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                    } else {
                        Text("You can now unlock apps early.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            blockingState.earlyUnlockCurrentInterval()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Unlock Apps Now")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Compact Early Unlock Banner (Home only)
    private struct EarlyUnlockCompactBannerHome: View {
        @StateObject private var blocking = BlockingStateService.shared
        var body: some View {
            let remaining = blocking.timeUntilEarlyUnlock()
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.18))
                    Image(systemName: remaining > 0 ? "hourglass" : "lock.open.fill")
                        .foregroundColor(.orange)
                }
                .frame(width: 26, height: 26)
                
                if remaining > 0 {
                    Text("Early unlock in \(remaining.formattedForCountdown)")
                        .font(.caption).monospacedDigit()
                        .foregroundColor(.primary)
                } else {
                    Button(action: { blocking.earlyUnlockCurrentInterval() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Unlock Now")
                                .font(.caption).fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
    
    // MARK: - Hero Banner (keeping for compatibility)
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let reciter = featuredReciter {
                ZStack(alignment: .bottomLeading) {
                    // Background Image
                    KFImage(reciter.artworkURL)
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
                
                // Use Quran Central reciters for the curated lists if possible
                let quranCentralReciters = reciters.filter { $0.identifier.hasPrefix("qurancentral_") }
                
                    self.popularReciters = Array(quranCentralReciters.filter { popularReciterNames.contains($0.englishName) }.prefix(10))
                    self.soothingReciters = Array(quranCentralReciters.filter { soothingReciterNames.contains($0.englishName) }.prefix(10))
                    
                    // Fallback to any reciter if the curated list is empty
                    if self.popularReciters.isEmpty {
                        self.popularReciters = Array(reciters.filter { popularReciterNames.contains($0.englishName) }.prefix(10))
                    }
                    if self.soothingReciters.isEmpty {
                        self.soothingReciters = Array(reciters.filter { soothingReciterNames.contains($0.englishName) }.prefix(10))
                    }
                    
                    // Assign a featured reciter from the popular list
                    self.featuredReciter = self.popularReciters.randomElement() ?? reciters.randomElement()
                    
                    self.isLoading = false
        print("✅ [HomeView] Data loaded and UI updated. Popular: \(popularReciters.count), Soothing: \(soothingReciters.count), Featured: \(featuredReciter?.englishName ?? "none")")
    }
    
    private func playRandomSurah(for reciter: Reciter) async {
        Task {
            do {
                let allSurahs = try await quranAPIService.fetchSurahs()
                var surahToPlay: Surah?

                let quranCentralPrefix = "qurancentral_"
                if reciter.identifier.hasPrefix(quranCentralPrefix) {
                    // It's a Quran Central reciter; we must fetch their specific list.
                    let slug = String(reciter.identifier.dropFirst(quranCentralPrefix.count))
                    let availableNumbers = try await QuranCentralService.shared.fetchAvailableSurahNumbers(for: slug)
                    let availableSurahs = allSurahs.filter { availableNumbers.contains($0.number) }
                    surahToPlay = availableSurahs.randomElement()
                } else {
                    // It's an MP3Quran reciter; any surah is fine.
                    surahToPlay = allSurahs.randomElement()
                }

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
        .background(Color(.secondarySystemBackground))
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
            KFImage(reciter.artworkURL)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
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

#Preview {
    HomeView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
        .environmentObject(DhikrService.shared)
} 