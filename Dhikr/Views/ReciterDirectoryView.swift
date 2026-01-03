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
    @StateObject private var subscriptionService = SubscriptionService.shared

    @State private var allReciters: [Reciter] = []
    @State private var filteredReciters: [Reciter] = []
    @State private var displayedReciters: [Reciter] = []
    @State private var recentReciters: [Reciter] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedReciter: Reciter?
    @State private var searchTask: Task<Void, Never>?
    @State private var favoritesCache: Set<String> = []
    @State private var currentBatchIndex = 0

    private let batchSize = 20 // Load 20 reciters at a time

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

            // Main Content (always show for blur effect)
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(theme.primaryAccent)
                        Spacer()
                    }
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
                                reciters: displayedReciters,
                                onReciterTapped: handleReciterTap,
                                onLoadMore: loadMoreReciters,
                                theme: theme,
                                favoritesCache: favoritesCache,
                                hasMore: displayedReciters.count < filteredReciters.count
                            )
                        }
                    }
                }
            }
            .blur(radius: subscriptionService.isPremium ? 0 : 10)

            // Premium lock overlay
            if !subscriptionService.isPremium {
                PremiumLockedView(feature: .reciterSearch)
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
                self.allReciters = reciters
                self.filteredReciters = reciters
                self.loadInitialBatch()
                self.isLoading = false
            }
        }
        .onChange(of: searchText) { newValue in
            performDebouncedSearch(query: newValue)
        }
        .onChange(of: filteredReciters) { _ in
            // Reset and load initial batch when filtered list changes
            loadInitialBatch()
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search reciters..."))
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    // MARK: - Background View
    private var backgroundView: some View {
        Group {
            if themeManager.effectiveTheme == .dark {
                // Dark background matching Focus page
                Color(red: 0.11, green: 0.13, blue: 0.16).ignoresSafeArea()
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
        // Skip loading if not premium (they can't see the content anyway)
        guard subscriptionService.isPremium else {
            isLoading = false
            return
        }

        self.recentReciters = RecentRecitersManager.shared.loadRecentReciters()
        loadFavoritesCache()

        // Check if reciters are already available from the global service
        if !quranAPIService.reciters.isEmpty {
            self.allReciters = quranAPIService.reciters
            self.filteredReciters = quranAPIService.reciters
            self.loadInitialBatch()
            self.isLoading = false
            return
        }

        // If global loading is in progress, show loading state but don't fetch again
        if quranAPIService.isLoadingReciters {
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
                    self.loadInitialBatch()
                    self.isLoading = false
                }
            } catch QuranAPIError.loadingInProgress {
                // Global loading is in progress - UI will update via publisher
                // Keep loading state, onReceive will handle the update
            } catch {
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
                return currentReciters.filter { reciter in
                    // Search for reciters whose name contains the query
                    let lowercasedQuery = query.lowercased()
                    let lowercasedName = reciter.englishName.lowercased()

                    // Simple contains search - shows all reciters whose name contains the search query
                    return lowercasedName.contains(lowercasedQuery)
                }
            }.value

            filteredReciters = filtered
        }
    }

    private func loadFavoritesCache() {
        favoritesCache = Set(FavoritesManager.shared.favoriteReciters.map { $0.identifier })
    }

    private func loadInitialBatch() {
        currentBatchIndex = 0
        let endIndex = min(batchSize, filteredReciters.count)
        displayedReciters = Array(filteredReciters[0..<endIndex])
    }

    private func loadMoreReciters() {
        guard displayedReciters.count < filteredReciters.count else {
            return
        }

        let startIndex = displayedReciters.count
        let endIndex = min(startIndex + batchSize, filteredReciters.count)
        let newReciters = Array(filteredReciters[startIndex..<endIndex])

        displayedReciters.append(contentsOf: newReciters)
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
                } else if ThemeManager.shared.currentTheme == .dark {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
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
                                ReciterArtworkImage(
                                    artworkURL: reciter.artworkURL,
                                    reciterName: reciter.name,
                                    size: 60
                                )
                                
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
    let onLoadMore: () -> Void
    let theme: AppTheme
    let favoritesCache: Set<String>
    let hasMore: Bool

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
                    .onAppear {
                        // Load more when we reach the last few items
                        if reciter.id == reciters.suffix(3).first?.id && hasMore {
                            onLoadMore()
                        }
                    }
                }

                // Loading indicator at the bottom when more items are available
                if hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
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
            ReciterArtworkImage(
                artworkURL: reciter.artworkURL,
                reciterName: reciter.name,
                size: 50
            )
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
                } else if ThemeManager.shared.currentTheme == .dark {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.15, green: 0.17, blue: 0.20))
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