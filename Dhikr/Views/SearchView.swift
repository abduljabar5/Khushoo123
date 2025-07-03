//
//  SearchView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var quranAPIService: QuranAPIService
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @State private var showingFullScreenPlayer = false
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    Text("Search Coming Soon")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("The ability to search for reciters and surahs will be added in a future update.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationTitle("Search")
            }
            
            if audioPlayerService.currentSurah != nil {
                VStack {
                    Spacer()
                    MiniPlayerBar(showingFullScreenPlayer: $showingFullScreenPlayer)
                        .padding(.bottom, 0)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            FullScreenPlayerView(onMinimize: { showingFullScreenPlayer = false })
                .environmentObject(audioPlayerService)
        }
    }
}

#Preview {
    SearchView()
} 