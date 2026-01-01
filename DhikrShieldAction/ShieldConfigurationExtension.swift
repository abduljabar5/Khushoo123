//
//  ShieldConfigurationExtension.swift
//  DhikrShieldAction
//
//  Created by Abduljabar Nur on 8/31/25.
//

import ManagedSettingsUI
import ManagedSettings
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func iconForPrayer(_ prayerName: String) -> String {
        switch prayerName {
        case "Fajr":
            return "sunrise.fill"
        case "Dhuhr":
            return "sun.max.fill"
        case "Asr":
            return "sun.dust.fill"
        case "Maghrib":
            return "sunset.fill"
        case "Isha":
            return "moon.stars.fill"
        default:
            return "moon.stars.fill"
        }
    }

    private func createConfiguration() -> ShieldConfiguration {
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let isStrictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false

        // Get context
        let currentPrayerName = groupDefaults?.string(forKey: "currentPrayerName") ?? "Prayer"
        let prayerTitle = currentPrayerName.isEmpty ? "Prayer Time" : "\(currentPrayerName) Prayer Time"

        // Get duration setting (in minutes)
        let durationMinutes = groupDefaults?.double(forKey: "focusBlockingDuration") ?? 15

        // Calculate early unlock time (50% of duration)
        let earlyUnlockMinutes = Int(durationMinutes * 0.5)

        // Calculate unlock times
        var subtitleText = "Take a moment to pray 🤲"
        var earlyUnlockText = ""

        if let startTimestamp = groupDefaults?.object(forKey: "blockingStartTime") as? TimeInterval {
            let startTime = Date(timeIntervalSince1970: startTimestamp)
            let fullUnlockTime = startTime.addingTimeInterval(durationMinutes * 60)
            let earlyUnlockTime = startTime.addingTimeInterval(Double(earlyUnlockMinutes) * 60)

            let formatter = DateFormatter()
            formatter.timeStyle = .short

            let now = Date()

            // Check if early unlock is available
            if now >= earlyUnlockTime {
                subtitleText = "Early unlock is now available"
                earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
            } else {
                let timeUntilEarly = Int(earlyUnlockTime.timeIntervalSince(now) / 60) + 1
                subtitleText = "Early unlock in \(timeUntilEarly) min"
                earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
            }
        }

        // Theme-aware colors
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        let primaryColor: UIColor
        let iconColor: UIColor

        if isDarkMode {
            primaryColor = UIColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0) // Bright teal for dark mode
            iconColor = UIColor(red: 0.3, green: 0.85, blue: 0.75, alpha: 1.0)
        } else {
            primaryColor = UIColor(red: 0.1, green: 0.6, blue: 0.5, alpha: 1.0) // Darker teal for light mode
            iconColor = UIColor(red: 0.15, green: 0.65, blue: 0.55, alpha: 1.0)
        }

        let fullSubtitle = subtitleText + earlyUnlockText

        // Get prayer-specific icon
        let prayerIconName = iconForPrayer(currentPrayerName)

        if isStrictMode {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: prayerIconName)?.withTintColor(iconColor, renderingMode: .alwaysOriginal),
                title: ShieldConfiguration.Label(text: "🕌 \(prayerTitle)", color: .label),
                subtitle: ShieldConfiguration.Label(text: "Open the app and say 'Wallahi I prayed' to unlock", color: .secondaryLabel),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Open Dhikr App", color: .white),
                primaryButtonBackgroundColor: primaryColor,
                secondaryButtonLabel: nil
            )
        } else {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: prayerIconName)?.withTintColor(iconColor, renderingMode: .alwaysOriginal),
                title: ShieldConfiguration.Label(text: "🕌 \(prayerTitle)", color: .label),
                subtitle: ShieldConfiguration.Label(text: fullSubtitle, color: .secondaryLabel),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Unlock Early", color: .white),
                primaryButtonBackgroundColor: primaryColor,
                secondaryButtonLabel: nil
            )
        }
    }
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return createConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return createConfiguration()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return createConfiguration()
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return createConfiguration()
    }
}