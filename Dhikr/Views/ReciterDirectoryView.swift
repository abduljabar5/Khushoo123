//
//  ReciterDirectoryView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI
import Kingfisher

struct ReciterDirectoryView: View {
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @ObservedObject var themeManager = ThemeManager.shared

    @State private var allReciters: [Reciter] = []
    @State private var filteredReciters: [Reciter] = []
    @State private var recentReciters: [Reciter] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedReciter: Reciter?
    @State private var searchTask: Task<Void, Never>?
    @State private var favoritesCache: Set<String> = []

    private var theme: AppTheme { themeManager.theme }

    // Memoized computation - only updates when search text or reciters change
    private var shouldShowRecentReciters: Bool {
        !recentReciters.isEmpty && searchText.isEmpty
    }
    
    private var isReciterSelectedBinding: Binding<Bool> {
        Binding(
            get: { selectedReciter != nil },
            set: { isActive in
                if !isActive { selectedReciter = nil }
            }
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView

                // Background NavigationLink for programmatic presentation
                if let reciter = selectedReciter {
                    NavigationLink(
                        destination: ReciterDetailView(reciter: reciter),
                        isActive: isReciterSelectedBinding,
                        label: { EmptyView() }
                    )
                    .hidden()
                }

                // Main Content
                VStack(spacing: 0) {
                    // Status bar spacer
                    Color.clear
                        .frame(height: 60)

                    // Search Bar
                    SearchBar(text: $searchText, theme: theme)
                        .padding(.bottom, 12)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(theme.primaryAccent)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if shouldShowRecentReciters {
                                    RecentlySearchedView(
                                        reciters: recentReciters,
                                        onReciterTapped: handleReciterTap,
                                        onClearAll: clearRecents,
                                        theme: theme
                                    )
                                }

                                AllRecitersView(
                                    reciters: filteredReciters,
                                    onReciterTapped: handleReciterTap,
                                    theme: theme,
                                    favoritesCache: favoritesCache
                                )
            }
                            .padding(.top, 20)
                        }
                    }
                }
                .onAppear {
                    loadData()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    updateFavoritesCache()
                }
                .onReceive(quranAPIService.$reciters) { reciters in
                    // Update when global reciters are loaded
                    if !reciters.isEmpty && self.allReciters.isEmpty {
                        print("🔄 [ReciterDirectoryView] Global reciters loaded, updating UI")
                        self.allReciters = reciters
                        self.filteredReciters = reciters
                        self.isLoading = false
                    }
                }
                .onChange(of: searchText) { newValue in
                    performDebouncedSearch(query: newValue)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
    }

    // MARK: - Background View
    private var backgroundView: some View {
        Group {
            if themeManager.currentTheme == .liquidGlass {
                LiquidGlassBackgroundView()
            } else {
                theme.primaryBackground
                    .ignoresSafeArea()
            }
        }
    }
    
    private func clearRecents() {
        RecentRecitersManager.shared.clearAllReciters()
        self.recentReciters = []
    }

    private func handleReciterTap(_ reciter: Reciter) {
        RecentRecitersManager.shared.addReciter(reciter)
        self.recentReciters = RecentRecitersManager.shared.loadRecentReciters()
        self.selectedReciter = reciter
    }

    private func updateFavoritesCache() {
        favoritesCache = Set(FavoritesManager.shared.favoriteReciters.map { $0.identifier })
    }

    private func loadData() {
        self.recentReciters = RecentRecitersManager.shared.loadRecentReciters()
        loadFavoritesCache()

        // Check if reciters are already available from the global service
        if !quranAPIService.reciters.isEmpty {
            print("✅ [ReciterDirectoryView] Using already loaded reciters (\(quranAPIService.reciters.count))")
            self.allReciters = quranAPIService.reciters
            self.filteredReciters = quranAPIService.reciters
            self.isLoading = false
            return
        }

        // If global loading is in progress, show loading state but don't fetch again
        if quranAPIService.isLoadingReciters {
            print("⏳ [ReciterDirectoryView] Global loading in progress, waiting...")
            self.isLoading = true
            return
        }

        // Show loading state and fetch if not available
        isLoading = true
        Task {
            do {
                let fetchedReciters = try await quranAPIService.fetchReciters()
                await MainActor.run {
                    self.allReciters = fetchedReciters
                    self.filteredReciters = fetchedReciters
                    self.isLoading = false
                }
            } catch QuranAPIError.loadingInProgress {
                // Global loading is in progress - UI will update via publisher
                print("🔄 [ReciterDirectoryView] Global loading in progress, waiting for publisher update")
                // Keep loading state, onReceive will handle the update
            } catch {
                print("Error loading reciters: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func performDebouncedSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        // Create new search task with debounce
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            if !Task.isCancelled {
                await applyFilters(query: query)
            }
        }
    }

    @MainActor
    private func applyFilters(query: String) async {
        if query.isEmpty {
            filteredReciters = allReciters
        } else {
            // Perform filtering on background queue
            let currentReciters = allReciters
            let filtered = await Task.detached {
                return currentReciters.filter {
                    $0.englishName.localizedCaseInsensitiveContains(query)
                }
            }.value

            filteredReciters = filtered
        }
    }

    private func loadFavoritesCache() {
        favoritesCache = Set(FavoritesManager.shared.favoriteReciters.map { $0.identifier })
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    let theme: AppTheme

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(theme.secondaryText)
            TextField("Search reciters...", text: $text)
                .foregroundColor(theme.primaryText)
                .accentColor(theme.primaryAccent)
            if !text.isEmpty {
                Button(action: { self.text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .padding(12)
        .background(
            Group {
                if theme.hasGlassEffect {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor.opacity(0.1), radius: 5)
                }
            }
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Recently Searched
struct RecentlySearchedView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    let onClearAll: () -> Void
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RECENTLY SEARCHED")
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                Spacer()
                Button("Clear All") {
                    onClearAll()
                }
                .font(.caption)
                .foregroundColor(theme.primaryAccent)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(reciters) { reciter in
                        Button(action: { onReciterTapped(reciter) }) {
                            VStack {
                                KFImage(reciter.artworkURL)
                                    .resizable()
                                    .loadDiskFileSynchronously()
                                    .diskCacheExpiration(.never)
                                    .fade(duration: 0.1)
                                    .placeholder {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(theme.tertiaryText)
                                    }
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                
                                Text(reciter.englishName.components(separatedBy: " ").first ?? "")
                                    .font(.caption)
                                    .foregroundColor(theme.primaryText)
                                    .frame(width: 70)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - All Reciters
struct AllRecitersView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    let theme: AppTheme
    let favoritesCache: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ALL RECITERS")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 8) {
                ForEach(reciters) { reciter in
                    Button(action: { onReciterTapped(reciter) }) {
                        ReciterRow(reciter: reciter, theme: theme, favoritesCache: favoritesCache)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Reciter Row
struct ReciterRow: View {
    let reciter: Reciter
    let theme: AppTheme
    let favoritesCache: Set<String>
    @State private var isSaved: Bool

    init(reciter: Reciter, theme: AppTheme, favoritesCache: Set<String>) {
        self.reciter = reciter
        self.theme = theme
        self.favoritesCache = favoritesCache
        _isSaved = State(initialValue: favoritesCache.contains(reciter.identifier))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            KFImage(reciter.artworkURL)
                .resizable()
                .loadDiskFileSynchronously()
                .diskCacheExpiration(.never)
                .fade(duration: 0.1)
                .placeholder {
                    Circle()
                        .fill(theme.tertiaryBackground)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24))
                                .foregroundColor(theme.tertiaryText)
                        )
                }
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(theme.hasGlassEffect ? theme.primaryAccent.opacity(0.2) : .clear, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(reciter.englishName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let country = reciter.country {
                        TagView(text: country, color: theme.accentGreen, theme: theme)
                    }
                    if let dialect = reciter.dialect {
                        TagView(text: dialect, color: theme.primaryAccent, theme: theme)
                    }
                }
            }

            Spacer()

            Button(action: {
                FavoritesManager.shared.toggleFavorite(reciter: reciter)
                isSaved.toggle()
                // Note: Parent view should update cache, but this handles immediate UI response
            }) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? theme.accentGold : theme.tertiaryText)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Group {
                if theme.hasGlassEffect {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.6)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                        .shadow(color: theme.shadowColor.opacity(0.1), radius: 5)
                }
            }
        )
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    let theme: AppTheme

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(theme.hasGlassEffect ? 0.3 : 0.15))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.5), lineWidth: 0.5)
                    )
            )
            .foregroundColor(color)
    }
}

struct ReciterDirectoryView_Previews: PreviewProvider {
    static var previews: some View {
    ReciterDirectoryView()
        .environmentObject(QuranAPIService.shared)
        .environmentObject(AudioPlayerService.shared)
    }
} 