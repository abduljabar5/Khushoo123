//
//  ReciterDirectoryView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct ReciterDirectoryView: View {
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var reciters: [Reciter] = []
    @State private var filteredReciters: [Reciter] = []
    @State private var searchText = ""
    @State private var selectedLanguage = "All"
    @State private var availableLanguages: [String] = ["All"]
    @State private var isLoading = true
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 0) {
                    // Search and Filters
                    searchAndFiltersSection
                    
                    // Reciters Grid
                    if isLoading {
                        loadingView
                    } else {
                        recitersGrid
                    }
                }
                .navigationTitle("Reciters")
                .navigationBarTitleDisplayMode(.large)
                .background(Color(.systemBackground))
                .onAppear(perform: loadReciters)
                .onChange(of: searchText) { _ in applyFilters() }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
    }
    
    // MARK: - Search and Filters
    private var searchAndFiltersSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search reciters by name...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            
            // Language Filter
            HStack {
                Menu {
                    ForEach(availableLanguages, id: \.self) { language in
                        Button(language.uppercased()) {
                            selectedLanguage = language
                            applyFilters()
                        }
                    }
                } label: {
                    HStack {
                        Text("Language: \(selectedLanguage.uppercased())")
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading Reciters...")
                .scaleEffect(1.5)
            Spacer()
        }
    }
    
    // MARK: - Reciters Grid
    private var recitersGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(filteredReciters) { reciter in
                    NavigationLink(destination: ReciterDetailView(reciter: reciter)) {
                        ReciterGridCard(reciter: reciter)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Data Loading
    private func loadReciters() {
        isLoading = true
        Task {
            do {
                let fetchedReciters = try await quranAPIService.fetchReciters()
                
                print("📊 [ReciterDirectoryView] Total reciters fetched: \(fetchedReciters.count)")
                print("📊 [ReciterDirectoryView] All reciters are now supported with verse-by-verse audio")
                
                await MainActor.run {
                    self.reciters = fetchedReciters
                    self.filteredReciters = fetchedReciters
                    let languages = Set(fetchedReciters.map { $0.language })
                    self.availableLanguages = ["All"] + Array(languages).sorted()
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
    
    // MARK: - Filtering
    private func applyFilters() {
        filteredReciters = reciters.filter { reciter in
            let matchesSearch = searchText.isEmpty ||
                reciter.name.localizedCaseInsensitiveContains(searchText) ||
                reciter.englishName.localizedCaseInsensitiveContains(searchText)
            
            let matchesLanguage = selectedLanguage == "All" ||
                reciter.language == selectedLanguage
            
            return matchesSearch && matchesLanguage
        }
    }
}

// MARK: - Reciter Grid Card
struct ReciterGridCard: View {
    let reciter: Reciter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text(reciter.englishName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                Text(reciter.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack {
                Text(reciter.language.uppercased())
                    .font(.caption)
                    .fontWeight(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minHeight: 150, alignment: .topLeading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ReciterDirectoryView()
        .environmentObject(QuranAPIService.shared)
        .environmentObject(AudioPlayerService.shared)
} 