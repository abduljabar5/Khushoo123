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
    
    @State private var allReciters: [Reciter] = []
    @State private var filteredReciters: [Reciter] = []
    @State private var recentReciters: [Reciter] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var selectedReciter: Reciter?
    
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
                    // Custom Header
                    ReciterDirectoryHeaderView()
                    
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.bottom, 12)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                if !recentReciters.isEmpty && searchText.isEmpty {
                                    RecentlySearchedView(
                                        reciters: recentReciters,
                                        onReciterTapped: handleReciterTap,
                                        onClearAll: clearRecents
                                    )
                                }
                                
                                AllRecitersView(
                                    reciters: filteredReciters,
                                    onReciterTapped: handleReciterTap
                                )
            }
                            .padding(.top, 20)
                        }
                    }
                }
                .background(Color.black.edgesIgnoringSafeArea(.all))
                .onAppear(perform: loadData)
                .onChange(of: searchText, perform: applyFilters)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
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

    private func loadData() {
        self.recentReciters = RecentRecitersManager.shared.loadRecentReciters()
        isLoading = true
        Task {
            do {
                let fetchedReciters = try await quranAPIService.fetchReciters()
                await MainActor.run {
                    self.allReciters = fetchedReciters
                    self.filteredReciters = fetchedReciters
                    self.isLoading = false
                }
            } catch {
                print("Error loading reciters: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func applyFilters(query: String) {
        if query.isEmpty {
            filteredReciters = allReciters
        } else {
            filteredReciters = allReciters.filter {
                $0.englishName.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

// MARK: - Header
private struct ReciterDirectoryHeaderView: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
                    .opacity(0) // Hidden but keeps spacing
            }
            Spacer()
            Text("Reciters")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            Button(action: {}) {
                Image(systemName: "heart")
                    .font(.title2)
                    .foregroundColor(.white)
                    .opacity(0) // Hidden but keeps spacing
            }
        }
        .padding()
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search reciters...", text: $text)
                .foregroundColor(.white)
                .accentColor(.white)
            if !text.isEmpty {
                Button(action: { self.text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Recently Searched
struct RecentlySearchedView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("RECENTLY SEARCHED")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear All") {
                    onClearAll()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(reciters) { reciter in
                        Button(action: { onReciterTapped(reciter) }) {
                            VStack {
                                KFImage(reciter.artworkURL)
                                    .resizable()
                                    .placeholder {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.gray)
                                    }
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                
                                Text(reciter.englishName.components(separatedBy: " ").first ?? "")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 70)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - All Reciters
struct AllRecitersView: View {
    let reciters: [Reciter]
    let onReciterTapped: (Reciter) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ALL RECITERS")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                ForEach(reciters) { reciter in
                    Button(action: { onReciterTapped(reciter) }) {
                        ReciterRow(reciter: reciter)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Reciter Row
struct ReciterRow: View {
    let reciter: Reciter
    @State private var isSaved: Bool
    
    init(reciter: Reciter) {
        self.reciter = reciter
        _isSaved = State(initialValue: FavoritesManager.shared.isFavorite(reciter: reciter))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            KFImage(reciter.artworkURL)
                .resizable()
                .placeholder {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.gray)
                }
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(reciter.englishName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack {
                    if let country = reciter.country {
                        TagView(text: country, color: .green)
                    }
                    if let dialect = reciter.dialect {
                        TagView(text: dialect, color: .blue)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                FavoritesManager.shared.toggleFavorite(reciter: reciter)
                isSaved.toggle()
            }) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isSaved ? .accentColor : .white)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.black) // To make the whole row tappable
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(12)
    }
}

struct ReciterDirectoryView_Previews: PreviewProvider {
    static var previews: some View {
    ReciterDirectoryView()
        .environmentObject(QuranAPIService.shared)
        .environmentObject(AudioPlayerService.shared)
    }
} 