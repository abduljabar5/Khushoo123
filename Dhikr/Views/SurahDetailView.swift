//
//  SurahDetailView.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import SwiftUI

struct SurahDetailView: View {
    let surah: Surah
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Surah Info
                surahInfoSection
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(surah.englishName)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("\(surah.number)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.accentColor)
                .frame(width: 120, height: 120)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(spacing: 8) {
                Text(surah.englishName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(surah.name)
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text(surah.englishNameTranslation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(.top)
    }
    
    // MARK: - Surah Info Section
    private var surahInfoSection: some View {
        HStack {
            InfoItem(
                title: "Ayahs",
                value: "\(surah.numberOfAyahs)"
            )
            InfoItem(
                title: "Revelation Type",
                value: surah.revelationType
            )
        }
        .padding()
    }
}

// MARK: - Supporting Views
struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        SurahDetailView(surah: Surah(
            number: 1,
            name: "سُورَةُ ٱلْفَاتِحَةِ",
            englishName: "Al-Fatiha",
            englishNameTranslation: "The Opening",
            numberOfAyahs: 7,
            revelationType: "Meccan"
        ))
    }
} 