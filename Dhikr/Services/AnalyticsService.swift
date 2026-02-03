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

    /// 1. First launch after install
    func trackAppOpened() {
        trackOnce("Funnel.appOpened")
    }

    /// 2. Location permission granted - completed onboarding
    func trackLocationGranted() {
        trackOnce("Funnel.locationGranted")
    }

    /// 3. Location permission denied - losing people here
    func trackLocationDenied() {
        trackOnce("Funnel.locationDenied")
    }

    // MARK: - Feature Events

    /// 4. Tapped into Focus feature (first time only)
    func trackFocusBlockingViewed() {
        trackOnce("Feature.focusViewed")
    }

    /// 5. Set up blocking with apps selected
    func trackFocusBlockingEnabled() {
        trackOnce("Feature.focusEnabled")
    }

    /// 6. Haya mode enabled - sticky feature
    func trackHayaModeEnabled() {
        trackOnce("Feature.hayaModeEnabled")
    }

    /// 8. Notification permission granted - will they come back
    func trackNotificationEnabled() {
        trackOnce("Feature.notificationsEnabled")
    }

    // MARK: - Engagement Events

    /// 7. Quran audio played - engagement signal (tracks each play)
    func trackQuranAudioPlayed() {
        TelemetryDeck.signal("Engagement.quranPlayed")
    }

    /// 9 & 10. Day 1 and Day 3 returns - habit forming
    private func trackDayReturns() {
        guard let installDate = defaults.object(forKey: "analytics_install_date") as? Date else {
            // First time - set install date
            defaults.set(Date(), forKey: "analytics_install_date")
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let daysSinceInstall = calendar.dateComponents([.day], from: installDate, to: now).day ?? 0

        // Day 1 return (opened app on day after install)
        if daysSinceInstall >= 1 {
            trackOnce("Retention.day1Return")
        }

        // Day 3 return (opened app 3+ days after install)
        if daysSinceInstall >= 3 {
            trackOnce("Retention.day3Return")
        }

        // Day 7 return
        if daysSinceInstall >= 7 {
            trackOnce("Retention.day7Return")
        }
    }

    // MARK: - Conversion Events

    /// 11. Paywall viewed - reached end of trial
    func trackPaywallViewed() {
        TelemetryDeck.signal("Conversion.paywallViewed")
    }

    /// 12. Trial started
    func trackTrialStarted() {
        trackOnce("Conversion.trialStarted")
    }

    /// 13. Subscription started - converted
    func trackSubscriptionStarted(productId: String) {
        trackOnce("Conversion.subscriptionStarted")
    }

    /// 14. Subscription cancelled
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
