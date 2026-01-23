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

        // Calculate unlock times
        var subtitleText = "Take a moment to pray 🤲"
        var earlyUnlockText = ""

        let now = Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        // Get early unlock time (set by monitor extension as prayer time + 5 min)
        if let earlyUnlockTimestamp = groupDefaults?.object(forKey: "earlyUnlockAvailableAt") as? TimeInterval {
            let earlyUnlockTime = Date(timeIntervalSince1970: earlyUnlockTimestamp)

            // Get prayer time if available (for full unlock calculation)
            let prayerTimestamp = groupDefaults?.object(forKey: "currentPrayerTime") as? TimeInterval
            let fullUnlockTime: Date
            if let prayerTs = prayerTimestamp {
                fullUnlockTime = Date(timeIntervalSince1970: prayerTs).addingTimeInterval(durationMinutes * 60)
            } else {
                // Fallback: early unlock + duration - 5 min
                fullUnlockTime = earlyUnlockTime.addingTimeInterval((durationMinutes - 5) * 60)
            }

            // Check if we're in the pre-prayer buffer period
            if let prayerTs = prayerTimestamp {
                let prayerTime = Date(timeIntervalSince1970: prayerTs)
                if now < prayerTime {
                    // In buffer period - prayer time hasn't arrived yet
                    let timeUntilPrayer = Int(prayerTime.timeIntervalSince(now) / 60) + 1
                    if timeUntilPrayer == 1 {
                        subtitleText = "Prayer time in less than 1 min"
                    } else {
                        subtitleText = "Prayer time in \(timeUntilPrayer) min"
                    }
                    earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
                } else if now >= earlyUnlockTime {
                    // Early unlock is now available
                    subtitleText = "Open app to unlock early"
                    earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
                } else {
                    // After prayer time but before early unlock
                    let timeUntilEarly = Int(earlyUnlockTime.timeIntervalSince(now) / 60) + 1
                    subtitleText = "Early unlock in \(timeUntilEarly) min"
                    earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
                }
            } else if now >= earlyUnlockTime {
                subtitleText = "Open app to unlock early"
                earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
            } else {
                let timeUntilEarly = Int(earlyUnlockTime.timeIntervalSince(now) / 60) + 1
                subtitleText = "Early unlock in \(timeUntilEarly) min"
                earlyUnlockText = " • Full unlock at \(formatter.string(from: fullUnlockTime))"
            }
        }

        // Sacred Minimalism colors - always dark mode for consistency
        let sacredGold = UIColor(red: 0.77, green: 0.65, blue: 0.46, alpha: 1.0)
        let softGreen = UIColor(red: 0.55, green: 0.68, blue: 0.55, alpha: 1.0)
        let backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
        let titleColor = UIColor.white
        let subtitleColor = UIColor(white: 0.5, alpha: 1.0)

        let fullSubtitle = subtitleText + earlyUnlockText

        // Get prayer-specific icon
        let prayerIconName = iconForPrayer(currentPrayerName)

        if isStrictMode {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: backgroundColor,
                icon: UIImage(systemName: prayerIconName)?.withTintColor(sacredGold, renderingMode: .alwaysOriginal),
                title: ShieldConfiguration.Label(text: prayerTitle, color: titleColor),
                subtitle: ShieldConfiguration.Label(text: "Open the app and say 'Wallahi I prayed' to unlock", color: subtitleColor),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Open Khushoo", color: .white),
                primaryButtonBackgroundColor: sacredGold,
                secondaryButtonLabel: nil
            )
        } else {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: backgroundColor,
                icon: UIImage(systemName: prayerIconName)?.withTintColor(sacredGold, renderingMode: .alwaysOriginal),
                title: ShieldConfiguration.Label(text: prayerTitle, color: titleColor),
                subtitle: ShieldConfiguration.Label(text: fullSubtitle, color: subtitleColor),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Open Khushoo", color: .white),
                primaryButtonBackgroundColor: softGreen,
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