//
//  HomeView.swift
//  Dhikr
//
//  Sacred Minimalism redesign - contemplative, refined, spiritually appropriate
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

    // Sacred color palette
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

    private var mutedPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65)
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
    @State private var spotlightReciter: Reciter?
    @State private var popularReciters: [Reciter] = []
    @State private var soothingReciters: [Reciter] = []
    @State private var isLoading = true
    @State private var showingRecents = false
    @State private var showingAllPopular = false
    @State private var showingAllSoothing = false
    @State private var showingProfile = false
    @State private var selectedReciter: Reciter?
    @State private var verseOfTheDay: (arabic: String, translation: String, reference: String)?
    @State private var showingQiblaCompass = false
    @State private var currentStatPage = 0
    @State private var sectionAppeared: [Bool] = Array(repeating: false, count: 12)

    private let popularReciterNames = [
        "Maher Al Meaqli", "Abdulbasit Abdulsamad", "Mishary Alafasi",
        "Saud Al-Shuraim", "Abdulrahman Alsudaes", "Ahmad Al-Ajmy",
        "Fares Abbad", "Yasser Al-Dosari", "Mohammed Ayyub", "Idrees Abkr"
    ]

    private let soothingReciterNames = [
        "Maher Al Meaqli", "Mishary Alafasi", "Saad Al-Ghamdi",
        "Abdulbasit Abdulsamad", "Yasser Al-Dosari", "Idrees Abkr",
        "Nasser Alqatami", "Ahmad Al-Ajmy", "Abdullah Al-Johany",
        "Mohammed Siddiq Al-Minshawi"
    ]

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    headerSection
                        .opacity(sectionAppeared[0] ? 1 : 0)
                        .offset(y: sectionAppeared[0] ? 0 : 20)

                    continueListeningSection
                        .opacity(sectionAppeared[1] ? 1 : 0)
                        .offset(y: sectionAppeared[1] ? 0 : 20)

                    prayerTimeSection
                        .opacity(sectionAppeared[2] ? 1 : 0)
                        .offset(y: sectionAppeared[2] ? 0 : 20)

                    quickActionsSection
                        .opacity(sectionAppeared[3] ? 1 : 0)
                        .offset(y: sectionAppeared[3] ? 0 : 20)

                    favoritesSection
                        .opacity(sectionAppeared[4] ? 1 : 0)
                        .offset(y: sectionAppeared[4] ? 0 : 20)

                    spotlightSection
                        .opacity(sectionAppeared[5] ? 1 : 0)
                        .offset(y: sectionAppeared[5] ? 0 : 20)

                    popularRecitersSection
                        .opacity(sectionAppeared[6] ? 1 : 0)
                        .offset(y: sectionAppeared[6] ? 0 : 20)

                    verseOfTheDaySection
                        .opacity(sectionAppeared[7] ? 1 : 0)
                        .offset(y: sectionAppeared[7] ? 0 : 20)

                    soothingRecitersSection
                        .opacity(sectionAppeared[8] ? 1 : 0)
                        .offset(y: sectionAppeared[8] ? 0 : 20)

                    journeyStatsSection
                        .opacity(sectionAppeared[9] ? 1 : 0)
                        .offset(y: sectionAppeared[9] ? 0 : 20)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, audioPlayerService.currentSurah != nil ? 140 : 100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
        .onAppear {
            loadData()
            animateEntrance()
        }
        .onReceive(quranAPIService.$reciters) { reciters in
            if !reciters.isEmpty && (spotlightReciter == nil || popularReciters.isEmpty) {
                processReciters(reciters)
            }
        }
        .sheet(isPresented: $showingRecents) {
            RecentsView().environmentObject(audioPlayerService)
        }
        .sheet(isPresented: $showingAllPopular) {
            SacredAllRecitersSheet(
                title: "Popular Reciters",
                reciters: popularReciters,
                isPresented: $showingAllPopular,
                onPlayRandom: { reciter in await playRandomSurah(for: reciter) }
            )
            .environmentObject(audioPlayerService)
            .environmentObject(quranAPIService)
        }
        .sheet(isPresented: $showingAllSoothing) {
            SacredAllRecitersSheet(
                title: "Soothing Voices",
                reciters: soothingReciters,
                isPresented: $showingAllSoothing,
                onPlayRandom: { reciter in await playRandomSurah(for: reciter) }
            )
            .environmentObject(audioPlayerService)
            .environmentObject(quranAPIService)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationView {
                ProfileView()
                    .environmentObject(dhikrService)
                    .environmentObject(audioPlayerService)
                    .environmentObject(bluetoothService)
                    .environmentObject(authService)
            }
        }
        .sheet(item: $selectedReciter) { reciter in
            NavigationView {
                ReciterDetailView(reciter: reciter)
                    .environmentObject(audioPlayerService)
                    .environmentObject(quranAPIService)
            }
        }
        .sheet(isPresented: $showingQiblaCompass) {
            SacredQiblaCompassModal()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("السلام عليكم")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundColor(sacredGold)

                Text(getGreeting())
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            Spacer()

            Button(action: { showingProfile = true }) {
                Circle()
                    .fill(sacredGold.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(sacredGold)
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Continue Listening
    @ViewBuilder
    private var continueListeningSection: some View {
        if let currentSurah = audioPlayerService.currentSurah,
           let currentReciter = audioPlayerService.currentReciter {
            SacredContinueCard(
                surahName: currentSurah.englishName,
                reciterName: currentReciter.englishName,
                time: audioPlayerService.currentTime,
                isPlaying: audioPlayerService.isPlaying,
                accentColor: sacredGold,
                action: {
                    HapticManager.shared.impact(.medium)
                    if !audioPlayerService.isPlaying { audioPlayerService.play() }
                }
            )
        } else if let lastPlayed = audioPlayerService.getLastPlayedInfo() {
            SacredContinueCard(
                surahName: lastPlayed.surah.englishName,
                reciterName: lastPlayed.reciter.englishName,
                time: lastPlayed.time,
                isPlaying: false,
                accentColor: sacredGold,
                action: {
                    HapticManager.shared.impact(.medium)
                    _ = audioPlayerService.continueLastPlayed()
                }
            )
        } else {
            SacredEmptyListeningCard(accentColor: sacredGold)
        }
    }

    // MARK: - Prayer Time
    private var prayerTimeSection: some View {
        Group {
            if let nextPrayer = prayerViewModel.nextPrayer {
                SacredPrayerCard(
                    prayerName: nextPrayer.name,
                    prayerNameArabic: getPrayerNameInArabic(nextPrayer.name),
                    time: nextPrayer.time,
                    timeUntil: prayerViewModel.timeUntilNextPrayer,
                    locationName: prayerViewModel.locationName,
                    currentPrayer: getCurrentPrayerLabel(),
                    progress: getCurrentPrayerProgress(),
                    accentColor: sacredGold
                )
            } else {
                SacredPrayerCardPlaceholder()
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sacredSectionHeader(title: "QUICK ACCESS")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                SacredQuickAction(icon: "clock", label: "Recent", color: warmGray) {
                    HapticManager.shared.impact(.light)
                    showingRecents = true
                }

                NavigationLink(destination: LikedSurahsView()) {
                    SacredQuickActionContent(icon: "heart", label: "Liked", color: mutedPurple)
                }
                .buttonStyle(PlainButtonStyle())

                SacredQuickAction(icon: "shuffle", label: "Discover", color: softGreen) {
                    HapticManager.shared.impact(.medium)
                    Task { await playDiscoverTrack() }
                }

                SacredQuickAction(icon: "location.north", label: "Qibla", color: sacredGold) {
                    HapticManager.shared.impact(.light)
                    showingQiblaCompass = true
                }
            }
        }
    }

    // MARK: - Favorites
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sacredSectionHeader(title: "FAVORITES")

            if !favoritesManager.favoriteReciters.isEmpty {
                let sortedFavorites = favoritesManager.favoriteReciters
                    .sorted { $0.dateAdded > $1.dateAdded }
                    .map { $0.identifier }
                let reciterDict = Dictionary(uniqueKeysWithValues: quranAPIService.reciters.map { ($0.identifier, $0) })
                let favoriteReciters = sortedFavorites.compactMap { reciterDict[$0] }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(favoriteReciters.prefix(8)), id: \.identifier) { reciter in
                            SacredReciterCard(reciter: reciter, accentColor: sacredGold) {
                                HapticManager.shared.impact(.light)
                                selectedReciter = reciter
                            } onPlay: {
                                HapticManager.shared.impact(.medium)
                                Task { await playRandomSurah(for: reciter) }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(.horizontal, -24)
                .padding(.leading, 24)
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(themeManager.theme.secondaryText.opacity(0.1)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No favorites yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Bookmark reciters to save them here")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                    Spacer()
                }
                .padding(20)
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

    // MARK: - Spotlight
    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sacredSectionHeader(title: "SPOTLIGHT")
                Spacer()
                Text("weekly")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            if let reciter = spotlightReciter {
                SacredSpotlightCard(reciter: reciter, accentColor: sacredGold) {
                    HapticManager.shared.impact(.light)
                    selectedReciter = reciter
                } onPlay: {
                    HapticManager.shared.impact(.medium)
                    Task { await playRandomSurah(for: reciter) }
                }
            } else {
                SacredSpotlightPlaceholder()
            }
        }
    }

    // MARK: - Popular Reciters
    private var popularRecitersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sacredSectionHeader(title: "POPULAR")
                Spacer()
                Button(action: { showingAllPopular = true }) {
                    Text("See all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if popularReciters.isEmpty {
                        ForEach(0..<4, id: \.self) { _ in SacredReciterSkeleton() }
                    } else {
                        ForEach(Array(popularReciters.prefix(8)), id: \.identifier) { reciter in
                            SacredReciterCard(reciter: reciter, accentColor: sacredGold) {
                                HapticManager.shared.impact(.light)
                                selectedReciter = reciter
                            } onPlay: {
                                HapticManager.shared.impact(.medium)
                                Task { await playRandomSurah(for: reciter) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, -24)
            .padding(.leading, 24)
        }
    }

    // MARK: - Verse of the Day
    private var verseOfTheDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sacredSectionHeader(title: "VERSE OF THE DAY")

            if let verse = verseOfTheDay {
                SacredVerseCard(
                    arabic: verse.arabic,
                    translation: verse.translation,
                    reference: verse.reference,
                    accentColor: sacredGold
                )
            } else {
                SacredVersePlaceholder()
            }
        }
    }

    // MARK: - Soothing Reciters
    private var soothingRecitersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sacredSectionHeader(title: "SOOTHING VOICES")
                Spacer()
                Button(action: { showingAllSoothing = true }) {
                    Text("See all")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    if soothingReciters.isEmpty {
                        ForEach(0..<4, id: \.self) { _ in SacredReciterSkeleton() }
                    } else {
                        ForEach(Array(soothingReciters.prefix(8)), id: \.identifier) { reciter in
                            SacredReciterCard(reciter: reciter, accentColor: softGreen) {
                                HapticManager.shared.impact(.light)
                                selectedReciter = reciter
                            } onPlay: {
                                HapticManager.shared.impact(.medium)
                                Task { await playRandomSurah(for: reciter) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, -24)
            .padding(.leading, 24)
        }
    }

    // MARK: - Journey Stats
    private var journeyStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sacredSectionHeader(title: "YOUR JOURNEY")
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(currentStatPage == index ? sacredGold : themeManager.theme.secondaryText.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            TabView(selection: $currentStatPage) {
                SacredListeningStatCard(
                    time: formatListeningTime(audioPlayerService.totalListeningTime),
                    accentColor: sacredGold
                ).tag(0)

                SacredSurahProgressCard(
                    completed: audioPlayerService.completedSurahNumbers.count,
                    accentColor: softGreen
                ).tag(1)

                SacredMostListenedCard(
                    reciter: getMostListenedReciter(),
                    playCount: getMostListenedReciter().map { getListenCountForReciter($0) } ?? 0,
                    accentColor: sacredGold
                ).tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 120)
        }
    }

    // MARK: - Section Header
    private func sacredSectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .tracking(2)
            .foregroundColor(themeManager.theme.secondaryText)
    }


    // MARK: - Animation
    private func animateEntrance() {
        for index in 0..<sectionAppeared.count {
            withAnimation(.easeOut(duration: 0.5).delay(Double(index) * 0.08)) {
                sectionAppeared[index] = true
            }
        }
    }

    // MARK: - Helper Methods
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name: String
        if authService.isAuthenticated {
            name = authService.currentUser?.displayName ?? "there"
        } else if let storedName = UserDefaults.standard.string(forKey: "userDisplayName"), !storedName.isEmpty {
            name = storedName
        } else {
            name = "there"
        }

        switch hour {
        case 0..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }

    private func getPrayerNameInArabic(_ name: String) -> String {
        ["Fajr": "الفجر", "Sunrise": "الشروق", "Dhuhr": "الظهر",
         "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء"][name] ?? ""
    }

    private func getCurrentPrayerProgress() -> CGFloat {
        guard let current = prayerViewModel.currentPrayer?.name else { return 0 }
        return ["Fajr": 0.2, "Sunrise": 0.2, "Dhuhr": 0.4, "Asr": 0.6, "Maghrib": 0.8, "Isha": 1.0][current] ?? 0
    }

    private func getCurrentPrayerLabel() -> String {
        guard let current = prayerViewModel.currentPrayer?.name else { return "—" }
        return current == "Sunrise" ? "Fajr" : current
    }

    private func formatListeningTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return minutes > 0 ? "\(minutes)m" : "0m"
    }

    private func getMostListenedReciter() -> Reciter? {
        let counts = Dictionary(grouping: RecentsManager.shared.recentItems, by: { $0.reciter.identifier })
            .mapValues { $0.count }
        guard let id = counts.max(by: { $0.value < $1.value })?.key else { return nil }
        return quranAPIService.reciters.first { $0.identifier == id }
    }

    private func getListenCountForReciter(_ reciter: Reciter) -> Int {
        RecentsManager.shared.recentItems.filter { $0.reciter.identifier == reciter.identifier }.count
    }

    private func loadData() {
        loadVerseOfTheDay()
        if !quranAPIService.reciters.isEmpty {
            processReciters(quranAPIService.reciters)
            return
        }
        Task {
            do {
                let reciters = try await quranAPIService.fetchReciters()
                await MainActor.run { processReciters(reciters) }
            } catch { await MainActor.run { isLoading = false } }
        }
    }

    private func processReciters(_ reciters: [Reciter]) {
        popularReciters = Array(reciters.filter { popularReciterNames.contains($0.englishName) }.prefix(10))
        soothingReciters = Array(reciters.filter { soothingReciterNames.contains($0.englishName) }.prefix(10))
        spotlightReciter = getWeeklySpotlightReciter(from: popularReciters, fallback: reciters)
        isLoading = false
    }

    private func getWeeklySpotlightReciter(from popular: [Reciter], fallback: [Reciter]) -> Reciter? {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let now = Date()

        if let savedID = defaults.string(forKey: "weeklySpotlightReciterID"),
           let savedDate = defaults.object(forKey: "weeklySpotlightDate") as? Date,
           calendar.component(.weekOfYear, from: savedDate) == calendar.component(.weekOfYear, from: now),
           calendar.component(.year, from: savedDate) == calendar.component(.year, from: now),
           let reciter = popular.first(where: { $0.identifier == savedID }) ?? fallback.first(where: { $0.identifier == savedID }) {
            return reciter
        }

        let newSpotlight = popular.randomElement() ?? fallback.randomElement()
        if let spotlight = newSpotlight {
            defaults.set(spotlight.identifier, forKey: "weeklySpotlightReciterID")
            defaults.set(now, forKey: "weeklySpotlightDate")
        }
        return newSpotlight
    }

    private func loadVerseOfTheDay() {
        let verses: [(arabic: String, translation: String, reference: String)] = [
            ("وَمَن يَتَّقِ ٱللَّهَ يَجْعَل لَّهُۥ مَخْرَجًا", "And whoever fears Allah - He will make for him a way out.", "Surah At-Talaq 65:2"),
            ("فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا", "For indeed, with hardship [will be] ease.", "Surah Ash-Sharh 94:5"),
            ("وَلَا تَيْأَسُوا۟ مِن رَّوْحِ ٱللَّهِ", "And never despair of the mercy of Allah.", "Surah Yusuf 12:87"),
            ("إِنَّ ٱللَّهَ مَعَ ٱلصَّٰبِرِينَ", "Indeed, Allah is with the patient.", "Surah Al-Baqarah 2:153"),
            ("وَٱذْكُر رَّبَّكَ إِذَا نَسِيتَ", "And remember your Lord when you forget.", "Surah Al-Kahf 18:24"),
            ("وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ", "And He is with you wherever you are.", "Surah Al-Hadid 57:4")
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        verseOfTheDay = verses[dayOfYear % verses.count]
    }

    private func playRandomSurah(for reciter: Reciter) async {
        do {
            let surahs = try await quranAPIService.fetchSurahs()
            if let surah = surahs.randomElement() {
                await MainActor.run { audioPlayerService.load(surah: surah, reciter: reciter) }
            }
        } catch {}
    }

    private func playDiscoverTrack() async {
        do {
            let allReciters = quranAPIService.reciters
            let allSurahs = try await quranAPIService.fetchSurahs()
            guard let reciter = allReciters.randomElement() else { return }
            let available = allSurahs.filter { reciter.hasSurah($0.number) }
            guard let surah = available.randomElement() else { return }
            await MainActor.run { audioPlayerService.load(surah: surah, reciter: reciter) }
        } catch {}
    }
}

// MARK: - Sacred Components

struct SacredContinueCard: View {
    let surahName: String
    let reciterName: String
    let time: TimeInterval
    let isPlaying: Bool
    let accentColor: Color
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(isPlaying ? "NOW PLAYING" : "CONTINUE")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(accentColor)

                    Text(surahName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    HStack(spacing: 6) {
                        Text(reciterName)
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)

                        Text("•")
                            .foregroundColor(themeManager.theme.secondaryText)

                        Text(formatTime(time))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SacredButtonStyle())
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct SacredEmptyListeningCard: View {
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(themeManager.theme.secondaryText.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "headphones")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.theme.secondaryText)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Begin Your Journey")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)

                Text("Choose a reciter below")
                    .font(.system(size: 13, weight: .light))
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
                        .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct SacredPrayerCard: View {
    let prayerName: String
    let prayerNameArabic: String
    let time: String
    let timeUntil: String
    let locationName: String
    let currentPrayer: String
    let progress: CGFloat
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT PRAYER")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(themeManager.theme.secondaryText)

                    HStack(spacing: 8) {
                        Text(prayerNameArabic)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("•")
                            .foregroundColor(themeManager.theme.secondaryText)

                        Text(prayerName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 10))
                    Text(locationName)
                        .font(.system(size: 11))
                }
                .foregroundColor(themeManager.theme.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(time)
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(accentColor)

                Text("in \(timeUntil)")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }

            // Prayer progress bar
            HStack(spacing: 8) {
                Text(currentPrayer)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(accentColor)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)

                Text("of day")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SacredPrayerCardPlaceholder: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 4).fill(themeManager.theme.secondaryText.opacity(0.15)).frame(width: 100, height: 12)
            RoundedRectangle(cornerRadius: 4).fill(themeManager.theme.secondaryText.opacity(0.15)).frame(width: 150, height: 32)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBackground))
    }
}

struct SacredQuickAction: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SacredQuickActionContent(icon: icon, label: label, color: color)
        }
        .buttonStyle(SacredButtonStyle())
    }
}

struct SacredQuickActionContent: View {
    let icon: String
    let label: String
    let color: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                )

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeManager.theme.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(themeManager.theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct SacredReciterCard: View {
    let reciter: Reciter
    let accentColor: Color
    let onTap: () -> Void
    let onPlay: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                KFImage(reciter.artworkURL)
                    .placeholder { SacredReciterPlaceholder(size: 120, iconSize: 40) }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: onPlay) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        )
                }
                .offset(x: -6, y: -6)
            }

            VStack(spacing: 2) {
                Text(reciter.englishName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(1)

                if let country = reciter.country {
                    Text(country)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }
            .frame(width: 120)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct SacredReciterSkeleton: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.theme.secondaryText.opacity(0.1))
                .frame(width: 120, height: 120)

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 3).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 80, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 50, height: 8)
            }
        }
        .frame(width: 120)
    }
}

struct SacredSpotlightCard: View {
    let reciter: Reciter
    let accentColor: Color
    let onTap: () -> Void
    let onPlay: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                KFImage(reciter.artworkURL)
                    .placeholder { SacredReciterPlaceholder(size: 80, iconSize: 30) }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(reciter.englishName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)

                    if let country = reciter.country {
                        Text(country)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }

                    Text(reciter.hasCompleteQuran ? "Complete Quran" : "\(reciter.availableSurahs.count) Surahs")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Button(action: onPlay) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .offset(x: 1)
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SacredButtonStyle())
    }
}

struct SacredSpotlightPlaceholder: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 3).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
    }
}

struct SacredVerseCard: View {
    let arabic: String
    let translation: String
    let reference: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(arabic)
                .font(.system(size: 26, weight: .regular, design: .serif))
                .foregroundColor(themeManager.theme.primaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(10)

            Rectangle()
                .fill(accentColor.opacity(0.4))
                .frame(width: 40, height: 1)

            Text(translation)
                .font(.system(size: 15, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

            Text(reference)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
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

struct SacredVersePlaceholder: View {
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 4).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(height: 40)
            RoundedRectangle(cornerRadius: 4).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(height: 24)
            RoundedRectangle(cornerRadius: 4).fill(themeManager.theme.secondaryText.opacity(0.1)).frame(width: 100, height: 12)
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 20).fill(cardBackground))
    }
}

struct SacredReciterListRow: View {
    let reciter: Reciter
    let rank: Int
    let accentColor: Color
    let onTap: () -> Void
    let onPlay: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    KFImage(reciter.artworkURL)
                        .placeholder { SacredReciterPlaceholder(size: 90, iconSize: 30) }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .clipped()

                    Text("\(rank)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .offset(x: 6, y: 6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(reciter.englishName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)

                    if let country = reciter.country {
                        Text(country)
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }

                    Text(reciter.hasCompleteQuran ? "114 Surahs" : "\(reciter.availableSurahs.count) Surahs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(accentColor)
                }
                .padding(.horizontal, 12)

                Spacer()

                Button(action: onPlay) {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "shuffle")
                                .font(.system(size: 12))
                                .foregroundColor(accentColor)
                        )
                }
                .padding(.trailing, 12)
            }
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SacredListeningStatCard: View {
    let time: String
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("LISTENING TIME")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(themeManager.theme.secondaryText)

                Text(time)
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(accentColor)

                Text("total time spent")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
            Spacer()

            Image(systemName: "headphones")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(accentColor.opacity(0.5))
        }
        .padding(20)
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

struct SacredSurahProgressCard: View {
    let completed: Int
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("SURAHS COMPLETED")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(themeManager.theme.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(completed)")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(accentColor)

                    Text("/ 114")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Text("\(Int((Double(completed) / 114.0) * 100))% complete")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.theme.secondaryText)
            }
            Spacer()

            ZStack {
                Circle()
                    .stroke(accentColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: Double(completed) / 114.0)
                    .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(20)
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

struct SacredMostListenedCard: View {
    let reciter: Reciter?
    let playCount: Int
    let accentColor: Color
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            if let reciter = reciter {
                KFImage(reciter.artworkURL)
                    .placeholder { SacredReciterPlaceholder(size: 44, iconSize: 18) }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("MOST LISTENED")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text(reciter.englishName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)
                        .lineLimit(1)

                    Text("\(playCount) plays")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(accentColor)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOST LISTENED")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(themeManager.theme.secondaryText)

                    Text("Start listening")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Play surahs to track")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(20)
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

// MARK: - Sacred Reciter Placeholder
struct SacredReciterPlaceholder: View {
    var size: CGFloat? = nil
    var iconSize: CGFloat
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var backgroundColor: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color(red: 0.94, green: 0.93, blue: 0.91)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
            Image(systemName: "person.circle")
                .font(.system(size: iconSize, weight: .ultraLight))
                .foregroundColor(sacredGold.opacity(0.5))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sacred All Reciters Sheet (with internal navigation)
struct SacredAllRecitersSheet: View {
    let title: String
    let reciters: [Reciter]
    @Binding var isPresented: Bool
    let onPlayRandom: (Reciter) async -> Void

    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @StateObject private var themeManager = ThemeManager.shared

    @State private var navigationPath = NavigationPath()

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(reciters.enumerated()), id: \.element.identifier) { index, reciter in
                            SacredReciterListRowNavigable(
                                reciter: reciter,
                                rank: index + 1,
                                accentColor: sacredGold,
                                onPlay: {
                                    HapticManager.shared.impact(.medium)
                                    Task { await onPlayRandom(reciter) }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(title.uppercased())
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.5)
                            .foregroundColor(warmGray)

                        Text("\(reciters.count) reciters")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.theme.secondaryText)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.secondaryText)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(themeManager.theme.secondaryText.opacity(0.1))
                            )
                    }
                }
            }
            .navigationDestination(for: Reciter.self) { reciter in
                ReciterDetailView(reciter: reciter)
                    .environmentObject(audioPlayerService)
                    .environmentObject(quranAPIService)
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }
}

// MARK: - Sacred Reciter List Row (Navigable version)
struct SacredReciterListRowNavigable: View {
    let reciter: Reciter
    let rank: Int
    let accentColor: Color
    let onPlay: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        HStack(spacing: 0) {
            // Navigation area - tapping here opens reciter profile
            NavigationLink(value: reciter) {
                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        KFImage(reciter.artworkURL)
                            .placeholder { SacredReciterPlaceholder(size: 90, iconSize: 30) }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipped()

                        Text("\(rank)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                            .offset(x: 6, y: 6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(reciter.englishName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)
                            .lineLimit(1)

                        if let country = reciter.country {
                            Text(country)
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(themeManager.theme.secondaryText)
                        }

                        Text(reciter.hasCompleteQuran ? "114 Surahs" : "\(reciter.availableSurahs.count) Surahs")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(accentColor)
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Shuffle button - separate from navigation
            Button(action: onPlay) {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 12)
        }
        .frame(height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.theme.secondaryText.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    let locationService = LocationService()
    return HomeView()
        .environmentObject(AudioPlayerService.shared)
        .environmentObject(QuranAPIService.shared)
        .environmentObject(DhikrService.shared)
        .environmentObject(BluetoothService())
        .environmentObject(AuthenticationService.shared)
        .environmentObject(PrayerTimeViewModel(locationService: locationService))
}
