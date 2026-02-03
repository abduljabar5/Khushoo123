//
//  PremiumFeatureModels.swift
//  Dhikr
//
//  Models for premium features and access control
//

import Foundation

// MARK: - Premium Features
enum PremiumFeature: String, CaseIterable {
    case focus = "Focus Mode"
    case hayaMode = "Haya Mode"
    case widgets = "Home & Lock Screen Widgets"
    case reciterSearch = "Reciter Search"
    case prayerSelection = "Prayer Selection"

    var icon: String {
        switch self {
        case .focus:
            return "moon.stars.fill"
        case .hayaMode:
            return "eye.slash.fill"
        case .widgets:
            return "square.grid.2x2"
        case .reciterSearch:
            return "magnifyingglass"
        case .prayerSelection:
            return "checkmark.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .focus:
            return "Block apps during prayer times to stay focused"
        case .hayaMode:
            return "Block adult content to protect your spiritual wellbeing"
        case .widgets:
            return "Prayer times, dhikr counter, and Qibla on your home screen"
        case .reciterSearch:
            return "Access to 200+ reciters to discover and explore"
        case .prayerSelection:
            return "Track your daily prayer completion"
        }
    }
}

// MARK: - Premium Access Helper
struct PremiumAccess {
    @MainActor
    static func hasAccess(to feature: PremiumFeature) -> Bool {
        // Check subscription status from SubscriptionService
        return SubscriptionService.shared.hasPremium
    }

    @MainActor
    static var isPremium: Bool {
        return SubscriptionService.shared.hasPremium
    }
}
