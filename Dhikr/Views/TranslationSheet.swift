//
//  TranslationSheet.swift
//  Dhikr
//
//  Slide-up sheet on the player that shows the current surah's text:
//  Arabic right-aligned + Sahih International translation below each verse.
//  Reciter-agnostic — works for every reciter regardless of audio source.
//

import SwiftUI

struct TranslationSheet: View {
    let surahNumber: Int
    let surahEnglishName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @State private var translation: SurahTranslation?
    @State private var isLoading = true
    @State private var loadError = false

    private var sacredGold: Color { Color(red: 0.77, green: 0.65, blue: 0.46) }
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
    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(sacredGold)
                        Text("Loading translation...")
                            .font(.system(size: 13))
                            .foregroundColor(warmGray)
                    }
                } else if loadError || translation == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(warmGray)
                        Text("Couldn't load translation")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.theme.primaryText)
                        Text("Check your connection and try again.")
                            .font(.system(size: 12))
                            .foregroundColor(warmGray)
                    }
                    .padding()
                } else if let translation = translation {
                    versesScroll(for: translation)
                }
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(warmGray.opacity(0.6))
                    }
                }
            }
            .task(id: surahNumber) {
                await load()
            }
        }
    }

    private func versesScroll(for surah: SurahTranslation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Text(surah.arabicName)
                        .font(.custom("Amiri Quran", size: 28, relativeTo: .title2))
                        .foregroundColor(themeManager.theme.primaryText)
                    Text(surah.englishName)
                        .font(.system(size: 13))
                        .tracking(1)
                        .foregroundColor(warmGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ForEach(surah.verses) { verse in
                    verseCard(verse)
                }

                // Translation source attribution
                Text("Translation: Sahih International")
                    .font(.system(size: 11))
                    .foregroundColor(warmGray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
        }
    }

    private func verseCard(_ verse: TranslatedVerse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Verse number + Arabic. Amiri Quran is a Naskh-script typeface
            // designed for Quranic typesetting — falls back to system serif if
            // the bundled font fails to register at app launch.
            HStack(alignment: .top, spacing: 12) {
                Text("\(verse.number)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(sacredGold)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                    )

                Text(verse.arabic)
                    .font(.custom("Amiri Quran", size: 24, relativeTo: .title3))
                    .foregroundColor(themeManager.theme.primaryText)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineSpacing(14)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            // Translation
            Text(verse.translation)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.theme.secondaryText)
                .lineSpacing(4)
                .padding(.leading, 40)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(sacredGold.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func load() async {
        isLoading = true
        loadError = false

        let result = await TranslationService.shared.fetchSurah(number: surahNumber)

        await MainActor.run {
            self.translation = result
            self.loadError = (result == nil)
            self.isLoading = false
        }
    }
}
