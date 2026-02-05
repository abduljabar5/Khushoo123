//
//  ManualLocationView.swift
//  Dhikr
//
//  City search view for users who don't grant location permission
//

import SwiftUI
import CoreLocation

struct ManualLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var locationService = LocationService()

    @State private var searchText = ""
    @State private var searchResults: [LocationResult] = []
    @State private var isSearching = false
    @State private var selectedLocation: LocationResult?

    var onLocationSelected: ((Double, Double, String) -> Void)?

    private let geocoder = CLGeocoder()

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

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(warmGray)

                        TextField("Search for your city...", text: $searchText)
                            .foregroundColor(themeManager.theme.primaryText)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { newValue in
                                searchCities(query: newValue)
                            }

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(warmGray)
                            }
                        }
                    }
                    .padding(16)
                    .background(cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Results List
                    if isSearching {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: sacredGold))
                        Spacer()
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(warmGray)
                            Text("No cities found")
                                .font(.system(size: 15, weight: .light))
                                .foregroundColor(warmGray)
                        }
                        Spacer()
                    } else if searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "globe")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundColor(sacredGold.opacity(0.5))

                            Text("Enter your city name")
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(themeManager.theme.primaryText)

                            Text("We'll use it to calculate accurate prayer times")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(warmGray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(searchResults) { result in
                                    CityResultRow(
                                        result: result,
                                        isSelected: selectedLocation?.id == result.id,
                                        sacredGold: sacredGold,
                                        softGreen: softGreen,
                                        warmGray: warmGray,
                                        cardBackground: cardBackground,
                                        primaryText: themeManager.theme.primaryText
                                    ) {
                                        selectLocation(result)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        }
                    }
                }
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(sacredGold)
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme == .auto ? nil : (themeManager.effectiveTheme == .dark ? .dark : .light))
    }

    private func searchCities(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true

        // Debounce the search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard self.searchText == query else { return }

            geocoder.cancelGeocode()
            geocoder.geocodeAddressString(query) { placemarks, error in
                DispatchQueue.main.async {
                    self.isSearching = false

                    if let error = error {
                        print("Geocoding error: \(error.localizedDescription)")
                        self.searchResults = []
                        return
                    }

                    self.searchResults = (placemarks ?? []).compactMap { placemark in
                        guard let location = placemark.location,
                              let city = placemark.locality ?? placemark.name else {
                            return nil
                        }

                        let country = placemark.country ?? ""
                        let state = placemark.administrativeArea

                        var displayName = city
                        if let state = state, !state.isEmpty, state != city {
                            displayName += ", \(state)"
                        }
                        if !country.isEmpty {
                            displayName += ", \(country)"
                        }

                        return LocationResult(
                            id: UUID().uuidString,
                            cityName: city,
                            displayName: displayName,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                    }
                }
            }
        }
    }

    private func selectLocation(_ result: LocationResult) {
        selectedLocation = result

        // Save to LocationService
        locationService.setManualLocation(
            latitude: result.latitude,
            longitude: result.longitude,
            name: result.cityName
        )

        // Callback
        onLocationSelected?(result.latitude, result.longitude, result.cityName)

        // Dismiss after a brief delay to show selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Supporting Types

struct LocationResult: Identifiable {
    let id: String
    let cityName: String
    let displayName: String
    let latitude: Double
    let longitude: Double
}

struct CityResultRow: View {
    let result: LocationResult
    let isSelected: Bool
    let sacredGold: Color
    let softGreen: Color
    let warmGray: Color
    let cardBackground: Color
    let primaryText: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? softGreen.opacity(0.15) : sacredGold.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "mappin.circle")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(isSelected ? softGreen : sacredGold)
                }

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.cityName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryText)

                    Text(result.displayName)
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(warmGray)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(softGreen)
                }
            }
            .padding(14)
            .background(cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? softGreen.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ManualLocationView()
}
