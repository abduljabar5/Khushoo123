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
    
    @State private var featuredReciter: Reciter?
    @State private var popularReciters: [Reciter] = []
    @State private var soothingReciters: [Reciter] = []
    @State private var recentSurahs: [Surah] = []
    @State private var isLoading = true
    @State private var showingFullScreenPlayer = false
    @State private var showingRecents = false
    
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
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Banner
                    heroBanner
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Category Rows
                    categoryRows
                }
                .padding(.horizontal, 16)
                .padding(.bottom, audioPlayerService.currentSurah != nil ? 130 : 80)
            }
            .navigationTitle("QariVerse")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .onAppear {
                loadData()
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
    
    // MARK: - Hero Banner
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
                        subtitle: "\(audioPlayerService.getLikedItems().count) tracks",
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
            if !favoritesManager.favoriteReciterIdentifiers.isEmpty {
                let favoriteReciters = quranAPIService.reciters.filter {
                    favoritesManager.favoriteReciterIdentifiers.contains($0.identifier)
                }
                
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
        Task {
            do {
                print("🏠 [HomeView] Fetching reciters...")
                let reciters = try await quranAPIService.fetchReciters()
                print("🏠 [HomeView] Successfully fetched \(reciters.count) reciters")
                
                // Use Quran Central reciters for the curated lists if possible
                let quranCentralReciters = reciters.filter { $0.identifier.hasPrefix("qurancentral_") }
                
                await MainActor.run {
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
                    print("✅ [HomeView] Data loaded and UI updated.")
                }
            } catch {
                print("❌ [HomeView] Failed to load data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
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
    
    private func getLikedSurahsCount() -> Int {
        // This function is no longer accurate as we count items, not just surah numbers.
        // It's better to get the count directly from the service.
        return audioPlayerService.getLikedItems().count
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