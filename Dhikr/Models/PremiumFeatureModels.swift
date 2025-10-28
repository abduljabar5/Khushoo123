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
    case reciterSearch = "Reciter Search"
    case prayerSelection = "Prayer Selection"

    var icon: String {
        switch self {
        case .focus:
            return "moon.stars.fill"
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
        case .reciterSearch:
            return "Search and discover new reciters"
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
