//
//  ReviewService.swift
//  Dhikr
//
//  Prompts App Store review after positive user experiences
//

import StoreKit
import UIKit

enum ReviewService {
    private static let defaults = UserDefaults.standard

    private static let actionCountKey = "review_actionCount"
    private static let lastReviewedVersionKey = "review_lastVersion"
    private static let threshold = 5

    /// Call after a positive user action (e.g., marking a prayer complete)
    static func recordPositiveAction() {
        let count = defaults.integer(forKey: actionCountKey) + 1
        defaults.set(count, forKey: actionCountKey)

        if count >= threshold {
            requestReviewIfNeeded()
        }
    }

    private static func requestReviewIfNeeded() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastReviewed = defaults.string(forKey: lastReviewedVersionKey) ?? ""

        // Only ask once per version
        guard currentVersion != lastReviewed else { return }

        defaults.set(currentVersion, forKey: lastReviewedVersionKey)
        // Reset count for next version
        defaults.set(0, forKey: actionCountKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
