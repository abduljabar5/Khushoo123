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

    /// The UI surface that triggered the most recent paywall display. Set by
    /// each paywall-trigger path so subsequent paywallViewed and
    /// subscriptionStarted events carry attribution. Reset to nil when the
    /// paywall is explicitly dismissed without conversion (optional).
    private var currentPaywallSource: String?

    private init() {}

    // MARK: - Paywall Source Attribution

    /// Call this from any code path that opens the paywall, BEFORE showing it.
    /// Common sources: "focusTabLocked", "reciterPreview", "hayaEnable",
    /// "lowerGazeUpgrade", "lockedFeatureTap".
    func setPaywallSource(_ source: String) {
        currentPaywallSource = source
    }

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

    /// Quran audio played (lifetime once)
    func trackQuranAudioPlayed() {
        trackOnce("Engagement.quranPlayed")
    }

    /// Lower Gaze panic session started. Fires every time, with duration
    /// (seconds) as a parameter so we can see which presets are most popular.
    func trackLowerGazeStarted(durationSeconds: TimeInterval) {
        TelemetryDeck.signal(
            "Feature.lowerGazeStarted",
            parameters: ["durationSeconds": String(Int(durationSeconds))]
        )
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

    // MARK: - Feedback Events

    /// User submitted feedback via in-app form
    func trackFeedbackSubmitted() {
        TelemetryDeck.signal("Engagement.feedbackSubmitted")
    }

    // MARK: - Conversion Events

    /// Paywall viewed. Includes the source surface that triggered it, set
    /// via setPaywallSource before display.
    func trackPaywallViewed() {
        var params: [String: String] = [:]
        if let source = currentPaywallSource {
            params["source"] = source
        }
        TelemetryDeck.signal("Conversion.paywallViewed", parameters: params)
    }

    /// Free user saw a locked feature overlay
    func trackFeatureLocked(feature: String) {
        TelemetryDeck.signal("Conversion.featureLocked", parameters: ["feature": feature])
    }

    /// Free user crossed the 60-second preview cap on a premium reciter.
    /// High-intent moment — the paywall fires immediately after this.
    func trackPreviewCapHit(reciter: String) {
        TelemetryDeck.signal(
            "Conversion.previewCapHit",
            parameters: ["reciter": reciter]
        )
    }

    /// Subscription started. NOT trackOnce — we want every conversion logged
    /// with its own source attribution. Source is the UI surface that led
    /// to the paywall (focusTabLocked, reciterPreview, hayaEnable, etc.).
    func trackSubscriptionStarted(productId: String) {
        var params: [String: String] = ["productId": productId]
        if let source = currentPaywallSource {
            params["source"] = source
        }
        TelemetryDeck.signal("Conversion.subscriptionStarted", parameters: params)
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
