//
//  ReciterDirectoryView.swift
//  Dhikr
//
//  Sacred Minimalism redesign of Reciters Directory
//

import SwiftUI
import Kingfisher

struct ReciterDirectoryView: View {
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared
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

    private let batchSize = 20

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
            pageBackground.ignoresSafeArea()

            // Background NavigationLink
            if let reciter = selectedReciter {
                NavigationLink(
                    destination: ReciterDetailView(reciter: reciter),
                    isActive: isReciterSelectedBinding,
                    label: { EmptyView() }
                )
                .hidden()
            }

            // Main Content
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(sacredGold)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Text("RECITERS")
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(3)
                                    .foregroundColor(warmGray)

                                Text("Discover Voices")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(themeManager.theme.primaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 8)

                            if shouldShowRecentReciters {
                                SacredRecentlySearchedView(
                                    reciters: recentReciters,
                                    onReciterTapped: handleReciterTap,
                                    onClearAll: clearRecents
                                )
                            }

                            SacredAllRecitersView(
                                reciters: displayedReciters,
                                onReciterTapped: handleReciterTap,
                                onLoadMore: loadMoreReciters,
                                favoritesCache: favoritesCache,
                                hasMore: displayedReciters.count < filteredReciters.count
                            )
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .blur(radius: subscriptionService.hasPremiumAccess ? 0 : 10)

            // Premium lock overlay
            if !subscriptionService.hasPremiumAccess {
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
            loadInitialBatch()
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search reciters..."))
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    // MARK: - Helper Methods

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
        guard subscriptionService.hasPremiumAccess else {
            isLoading = false
            return
        }

        self.recentReciters = RecentRecitersManager.shared.loadRecentReciters()
        loadFavoritesCache()

        if !quranAPIService.reciters.isEmpty {
            self.allReciters = quranAPIService.reciters
            self.filteredReciters = quranAPIService.reciters
            self.loadInitialBatch()
            self.isLoading = false
            return
        }

        if quranAPIService.isLoadingReciters {
            self.isLoading = true
            return
        }

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
                // Global loading is in progress
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
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
            let currentReciters = allReciters
            // Fetch QC reciters for search (lazy-loaded, cached after first call)
            let qcReciters = await QuranCentralService.shared.fetchReciters()

            let filtered = await Task.detached {
                let lowercasedQuery = query.lowercased()

                // Search MP3Quran reciters
                let mp3Results = currentReciters.filter { reciter in
                    reciter.englishName.lowercased().contains(lowercasedQuery)
                }

                // Search Quran Central reciters (exclude duplicates already in MP3Quran)
                let mp3Names = Set(currentReciters.map { $0.englishName.lowercased() })
                let qcResults = qcReciters.filter { reciter in
                    reciter.englishName.lowercased().contains(lowercasedQuery)
                        && !mp3Names.contains(reciter.englishName.lowercased())
                }

                return mp3Results + qcResults
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
        guard displayedReciters.count < filteredReciters.count else { return }

        let startIndex = displayedReciters.count
        let endIndex = min(startIndex + batchSize, filteredReciters.count)
        let newReciters = Array(filteredReciters[startIndex..<endIndex])

        displayedReciters.append(contentsOf: newReciters)
    }
}

// MARK: - Sacred Recently Searched View

private struct SacredRecentlySearchedView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    let onClearAll: () -> Void

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(warmGray)

                Spacer()

                Button(action: onClearAll) {
                    Text("Clear")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(reciters) { reciter in
                        Button(action: { onReciterTapped(reciter) }) {
                            SacredRecentReciterItem(reciter: reciter)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Sacred Recent Reciter Item

private struct SacredRecentReciterItem: View {
    let reciter: Reciter
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    var body: some View {
        VStack(spacing: 10) {
            KFImage(reciter.artworkURL)
                .placeholder {
                    SacredReciterPlaceholder(size: 64, iconSize: 24)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                )

            Text(reciter.englishName.components(separatedBy: " ").first ?? "")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(themeManager.theme.primaryText)
                .frame(width: 70)
                .lineLimit(1)
        }
    }
}

// MARK: - Sacred All Reciters View

private struct SacredAllRecitersView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    let onLoadMore: () -> Void
    let favoritesCache: Set<String>
    let hasMore: Bool

    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ALL RECITERS")
                .font(.system(size: 11, weight: .medium))
                .tracking(2)
                .foregroundColor(warmGray)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 10) {
                ForEach(reciters) { reciter in
                    Button(action: { onReciterTapped(reciter) }) {
                        SacredReciterRow(reciter: reciter, favoritesCache: favoritesCache)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        if reciter.id == reciters.suffix(3).first?.id && hasMore {
                            onLoadMore()
                        }
                    }
                }

                if hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(sacredGold)
                            .padding()
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Sacred Reciter Row

private struct SacredReciterRow: View {
    let reciter: Reciter
    let favoritesCache: Set<String>
    @State private var isSaved: Bool
    @StateObject private var themeManager = ThemeManager.shared

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

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    init(reciter: Reciter, favoritesCache: Set<String>) {
        self.reciter = reciter
        self.favoritesCache = favoritesCache
        _isSaved = State(initialValue: favoritesCache.contains(reciter.identifier))
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            KFImage(reciter.artworkURL)
                .placeholder {
                    SacredReciterPlaceholder(size: 52, iconSize: 20)
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(sacredGold.opacity(0.15), lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(reciter.englishName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let country = reciter.country {
                        SacredTag(text: country, color: softGreen)
                    }
                    if let dialect = reciter.dialect {
                        SacredTag(text: dialect, color: sacredGold)
                    }
                }
            }

            Spacer()

            // Bookmark
            Button(action: {
                FavoritesManager.shared.toggleFavorite(reciter: reciter)
                isSaved.toggle()
            }) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(isSaved ? sacredGold : warmGray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sacredGold.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred Tag

private struct SacredTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    ReciterDirectoryView()
        .environmentObject(QuranAPIService.shared)
        .environmentObject(AudioPlayerService.shared)
}
