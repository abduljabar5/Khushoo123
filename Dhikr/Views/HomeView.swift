//
//  HomeView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var dhikrService: DhikrService
    @EnvironmentObject var bluetoothService: BluetoothService
    
    @State private var featuredReciter: Reciter?
    @State private var popularReciters: [Reciter] = []
    @State private var recentSurahs: [Surah] = []
    @State private var isLoading = true
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
        ZStack {
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
                    .padding(.bottom, 80)
                }
                .navigationTitle("QariVerse")
                .navigationBarTitleDisplayMode(.large)
                .background(Color(.systemBackground))
                .onAppear {
                    loadData()
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
    }
    
    // MARK: - Hero Banner
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let reciter = featuredReciter {
                ZStack(alignment: .bottomLeading) {
                    // Background Image
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Featured Reciter")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(reciter.englishName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(reciter.language.uppercased())
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        // Play Button
                        Button(action: {
                            // Play a random surah with this reciter
                            if let randomSurah = recentSurahs.randomElement() {
                                audioPlayerService.load(surah: randomSurah, reciter: reciter)
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
                
                // Favorites
                NavigationLink(destination: FavoritesView()) {
                    QuickActionCard(
                        title: "Favorites",
                        subtitle: "\(getLikedSurahsCount()) surahs",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                // Most Recent Played
                Button(action: {
                    _ = audioPlayerService.continueLastPlayed()
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
                title: "Popular Reciters",
                items: popularReciters,
                itemView: { reciter in
                    ReciterCard(reciter: reciter)
                }
            )
            
            // Recent Surahs
            CategoryRow(
                title: "Recent Surahs",
                items: recentSurahs,
                itemView: { surah in
                    SurahCard(surah: surah)
                }
            )
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
                
                print("🏠 [HomeView] Fetching surahs...")
                let surahs = try await quranAPIService.fetchSurahs()
                print("🏠 [HomeView] Successfully fetched \(surahs.count) surahs")
                
                await MainActor.run {
                    // Randomize featured reciter
                    self.featuredReciter = reciters.randomElement()
                    self.popularReciters = Array(reciters.prefix(6))
                    self.recentSurahs = Array(surahs.prefix(6))
                    self.isLoading = false
                    
                    // Load all surahs into AudioPlayerService for navigation
                    audioPlayerService.loadAllSurahs(surahs)
                    
                    print("🏠 [HomeView] Data loading completed successfully")
                }
            } catch {
                print("❌ [HomeView] Error loading data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getContinueSubtitle() -> String {
        if let lastPlayed = audioPlayerService.getLastPlayedInfo() {
            return "\(lastPlayed.surah.englishName) • \(lastPlayed.reciter.englishName)"
        } else if !recentSurahs.isEmpty && !popularReciters.isEmpty {
            return "Start listening"
        } else {
            return "No content"
        }
    }
    
    private func getLikedSurahsCount() -> Int {
        let likedSurahs = Set(UserDefaults.standard.array(forKey: "likedSurahs") as? [Int] ?? [])
        return likedSurahs.count
    }
    
    private func getRecentSubtitle() -> String {
        if let lastPlayed = audioPlayerService.getLastPlayedInfo() {
            return "\(lastPlayed.surah.englishName)"
        } else {
            return "No recent played"
        }
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
        NavigationLink(destination: ReciterDetailView(reciter: reciter)) {
            VStack(alignment: .leading, spacing: 8) {
                // Reciter Image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    )
                
                // Reciter Info
                Text(reciter.englishName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(reciter.language.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
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