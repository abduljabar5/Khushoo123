//
//  HapticManager.swift
//  Dhikr
//
//  Centralized haptic feedback manager that reuses generators
//  to prevent CHHapticEngine startup timeouts
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()

    // Pre-initialized generators for each style
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        // Prepare all generators at init to reduce latency
        prepareAll()
    }

    /// Prepare all generators (call when app becomes active)
    func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Trigger impact feedback
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightGenerator.impactOccurred()
            lightGenerator.prepare()
        case .medium:
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        case .heavy:
            heavyGenerator.impactOccurred()
            heavyGenerator.prepare()
        case .soft:
            lightGenerator.impactOccurred(intensity: 0.5)
            lightGenerator.prepare()
        case .rigid:
            heavyGenerator.impactOccurred(intensity: 0.8)
            heavyGenerator.prepare()
        @unknown default:
            mediumGenerator.impactOccurred()
            mediumGenerator.prepare()
        }
    }

    /// Trigger selection feedback (for UI selections)
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Trigger notification feedback
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
}
