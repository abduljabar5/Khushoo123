//
//  PrayerCalculationSettings.swift
//  Dhikr
//
//  Prayer time calculation method and Asr juristic settings
//

import Foundation
import Combine

// MARK: - Calculation Method Enum
enum CalculationMethod: Int, CaseIterable, Codable, Identifiable {
    case isna = 2           // Islamic Society of North America
    case mwl = 3            // Muslim World League
    case ummAlQura = 4      // Umm Al-Qura University, Makkah
    case egyptian = 5       // Egyptian General Authority of Survey
    case karachi = 1        // University of Islamic Sciences, Karachi
    case dubai = 16         // Dubai

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .isna: return "ISNA"
        case .mwl: return "Muslim World League"
        case .ummAlQura: return "Umm Al-Qura"
        case .egyptian: return "Egyptian"
        case .karachi: return "Karachi"
        case .dubai: return "Dubai"
        }
    }

    var fullName: String {
        switch self {
        case .isna: return "Islamic Society of North America"
        case .mwl: return "Muslim World League"
        case .ummAlQura: return "Umm Al-Qura University, Makkah"
        case .egyptian: return "Egyptian General Authority"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .dubai: return "Dubai"
        }
    }

    var angles: String {
        switch self {
        case .isna: return "Fajr 15° / Isha 15°"
        case .mwl: return "Fajr 18° / Isha 17°"
        case .ummAlQura: return "Fajr 18.5° / Isha 90 min"
        case .egyptian: return "Fajr 19.5° / Isha 17.5°"
        case .karachi: return "Fajr 18° / Isha 18°"
        case .dubai: return "Fajr 18.2° / Isha 18.2°"
        }
    }

    var regions: String {
        switch self {
        case .isna: return "North America"
        case .mwl: return "Europe, Far East"
        case .ummAlQura: return "Saudi Arabia, Gulf"
        case .egyptian: return "Egypt, Africa, Middle East"
        case .karachi: return "Pakistan, India, Bangladesh"
        case .dubai: return "UAE"
        }
    }

    var icon: String {
        switch self {
        case .isna: return "building.columns"
        case .mwl: return "globe.europe.africa"
        case .ummAlQura: return "building.2"
        case .egyptian: return "pyramid"
        case .karachi: return "building"
        case .dubai: return "building.2.crop.circle"
        }
    }

    // Ordered list for display (most common first)
    static var orderedCases: [CalculationMethod] {
        [.isna, .mwl, .ummAlQura, .egyptian, .karachi, .dubai]
    }
}

// MARK: - Asr Juristic Method Enum
enum AsrJuristicMethod: Int, CaseIterable, Codable, Identifiable {
    case standard = 0   // Shafi'i, Maliki, Hanbali (shadow = 1x object)
    case hanafi = 1     // Hanafi (shadow = 2x object)

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .standard: return "Standard"
        case .hanafi: return "Hanafi"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Shafi'i, Maliki, Hanbali"
        case .hanafi: return "Hanafi school"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "Earlier Asr time"
        case .hanafi: return "Later Asr time"
        }
    }
}

// MARK: - Prayer Calculation Settings Manager
class PrayerCalculationSettingsManager: ObservableObject {
    static let shared = PrayerCalculationSettingsManager()

    private let calculationMethodKey = "selectedCalculationMethod"
    private let asrMethodKey = "selectedAsrMethod"
    private let hasSetInitialMethodKey = "hasSetInitialCalculationMethod"

    @Published var calculationMethod: CalculationMethod {
        didSet {
            saveSettings()
        }
    }

    @Published var asrMethod: AsrJuristicMethod {
        didSet {
            saveSettings()
        }
    }

    @Published var isRefreshing: Bool = false

    // Callback when settings change (for triggering refresh)
    var onSettingsChanged: (() -> Void)?

    private var groupDefaults: UserDefaults {
        UserDefaults(suiteName: "group.fm.mrc.Dhikr") ?? .standard
    }

    private init() {
        // Use local reference to avoid 'self' access before init
        let defaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") ?? .standard

        // Load saved settings or use defaults
        if let savedMethod = defaults.object(forKey: calculationMethodKey) as? Int,
           let method = CalculationMethod(rawValue: savedMethod) {
            self.calculationMethod = method
        } else {
            self.calculationMethod = .isna // Default
        }

        if let savedAsr = defaults.object(forKey: asrMethodKey) as? Int,
           let asr = AsrJuristicMethod(rawValue: savedAsr) {
            self.asrMethod = asr
        } else {
            self.asrMethod = .standard // Default
        }
    }

    // MARK: - Location-Based Recommendation
    func recommendedMethod(for country: String) -> CalculationMethod {
        let lowercased = country.lowercased()

        // North America
        if lowercased.contains("united states") || lowercased.contains("usa") ||
           lowercased.contains("canada") || lowercased.contains("mexico") {
            return .isna
        }

        // Saudi Arabia
        if lowercased.contains("saudi") {
            return .ummAlQura
        }

        // UAE
        if lowercased.contains("emirates") || lowercased.contains("uae") {
            return .dubai
        }

        // Gulf States (use Umm Al-Qura)
        if lowercased.contains("kuwait") || lowercased.contains("qatar") ||
           lowercased.contains("bahrain") || lowercased.contains("oman") {
            return .ummAlQura
        }

        // South Asia (Karachi method)
        if lowercased.contains("pakistan") || lowercased.contains("india") ||
           lowercased.contains("bangladesh") || lowercased.contains("afghanistan") ||
           lowercased.contains("sri lanka") || lowercased.contains("nepal") {
            return .karachi
        }

        // Egypt and nearby
        if lowercased.contains("egypt") || lowercased.contains("libya") ||
           lowercased.contains("sudan") || lowercased.contains("jordan") ||
           lowercased.contains("palestine") || lowercased.contains("iraq") ||
           lowercased.contains("syria") || lowercased.contains("lebanon") {
            return .egyptian
        }

        // North Africa (Egyptian method is common)
        if lowercased.contains("morocco") || lowercased.contains("algeria") ||
           lowercased.contains("tunisia") {
            return .egyptian
        }

        // Europe and rest of world - MWL is most universal
        return .mwl
    }

    var hasSetInitialMethod: Bool {
        get { groupDefaults.bool(forKey: hasSetInitialMethodKey) }
        set { groupDefaults.set(newValue, forKey: hasSetInitialMethodKey) }
    }

    func setInitialMethodBasedOnLocation(_ country: String) {
        guard !hasSetInitialMethod else { return }

        let recommended = recommendedMethod(for: country)
        calculationMethod = recommended
        hasSetInitialMethod = true
    }

    // MARK: - Save/Load
    private func saveSettings() {
        groupDefaults.set(calculationMethod.rawValue, forKey: calculationMethodKey)
        groupDefaults.set(asrMethod.rawValue, forKey: asrMethodKey)
        groupDefaults.synchronize()
    }

    // MARK: - Update Settings with Refresh
    func updateCalculationMethod(_ method: CalculationMethod, triggerRefresh: Bool = true) {
        guard method != calculationMethod else { return }
        calculationMethod = method
        if triggerRefresh {
            onSettingsChanged?()
        }
    }

    func updateAsrMethod(_ method: AsrJuristicMethod, triggerRefresh: Bool = true) {
        guard method != asrMethod else { return }
        asrMethod = method
        if triggerRefresh {
            onSettingsChanged?()
        }
    }
}
