//
//  AnalyticsService.swift
//  Dhikr
//
//  Privacy-focused analytics using TelemetryDeck
//

import Foundation
import TelemetryDeck

final class AnalyticsService {
    static let shared = AnalyticsService()

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Configuration

    func configure() {
        var config = TelemetryDeck.Config(appID: "DE4D115F-4906-4D0C-AAD8-91583E6CFAEC")
        #if DEBUG
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)

        // Track day returns on configure (app open)
        trackDayReturns()
    }

    // MARK: - Funnel Events (Onboarding)

    /// First launch after install
    func trackAppOpened() {
        trackOnce("Funnel.appOpened")
    }

    /// Location permission granted - completed onboarding
    func trackLocationGranted() {
        trackOnce("Funnel.locationGranted")
    }

    /// Location permission denied
    func trackLocationDenied() {
        trackOnce("Funnel.locationDenied")
    }

    // MARK: - Feature Events

    /// Tapped into Focus feature
    func trackFocusBlockingViewed() {
        trackOnce("Feature.focusViewed")
    }

    /// Set up blocking with apps selected
    func trackFocusBlockingEnabled() {
        trackOnce("Feature.focusEnabled")
    }

    /// Haya mode enabled
    func trackHayaModeEnabled() {
        trackOnce("Feature.hayaModeEnabled")
    }

    /// Notification permission granted
    func trackNotificationEnabled() {
        trackOnce("Feature.notificationsEnabled")
    }

    /// Quran audio played
    func trackQuranAudioPlayed() {
        trackOnce("Engagement.quranPlayed")
    }

    /// Shared the app via referral
    func trackAppShared() {
        trackOnce("Engagement.appShared")
    }

    /// Used a referral code
    func trackReferralCodeUsed() {
        trackOnce("Engagement.referralCodeUsed")
    }

    // MARK: - Retention Events

    /// Day 1, 3, 7 returns - habit forming
    private func trackDayReturns() {
        guard let installDate = defaults.object(forKey: "analytics_install_date") as? Date else {
            // First time - set install date
            defaults.set(Date(), forKey: "analytics_install_date")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let daysSinceInstall = calendar.dateComponents([.day], from: installDate, to: now).day ?? 0

        if daysSinceInstall >= 1 {
            trackOnce("Retention.day1Return")
        }

        if daysSinceInstall >= 3 {
            trackOnce("Retention.day3Return")
        }

        if daysSinceInstall >= 7 {
            trackOnce("Retention.day7Return")
        }
    }

    // MARK: - Conversion Events

    /// Paywall viewed
    func trackPaywallViewed() {
        TelemetryDeck.signal("Conversion.paywallViewed")
    }

    /// Subscription started
    func trackSubscriptionStarted(productId: String) {
        trackOnce("Conversion.subscriptionStarted")
    }

    /// Subscription cancelled
    func trackSubscriptionCancelled() {
        TelemetryDeck.signal("Conversion.subscriptionCancelled")
    }

    // MARK: - Helper

    /// Track an event only once per user
    private func trackOnce(_ event: String) {
        let key = "analytics_\(event)_tracked"
        guard !defaults.bool(forKey: key) else { return }
        TelemetryDeck.signal(event)
        defaults.set(true, forKey: key)
    }
}
