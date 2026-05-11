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

        // Lower Gaze sessions use a different named ManagedSettingsStore but
        // the system still calls into this single shield extension for any
        // blocked app. Detect Lower Gaze by checking the saved endTime — if
        // it's in the future, this block was triggered by Lower Gaze, not by
        // prayer-time scheduling. Render a different shield for that context.
        if let lowerGazeEndTs = groupDefaults?.object(forKey: "panicModeEndTime") as? TimeInterval {
            let endTime = Date(timeIntervalSince1970: lowerGazeEndTs)
            if endTime > Date() {
                return makeLowerGazeConfiguration(endTime: endTime)
            }
        }

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
                subtitle: ShieldConfiguration.Label(text: "Open the app and say 'Wallahi' (والله) to unlock", color: subtitleColor),
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

    /// Shield variant shown to users who hit a blocked app during an active
    /// Lower Gaze (panic) session. Reframes the block as a self-imposed
    /// commitment rather than a prayer-time interruption — the user chose
    /// this lockout knowingly and can't end it early, so the copy stays
    /// supportive instead of asking them to "open Khushoo and pray."
    private func makeLowerGazeConfiguration(endTime: Date) -> ShieldConfiguration {
        let sacredGold = UIColor(red: 0.77, green: 0.65, blue: 0.46, alpha: 1.0)
        let backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0)
        let titleColor = UIColor.white
        let subtitleColor = UIColor(white: 0.7, alpha: 1.0)

        // Time-remaining string. Show hours+minutes if >= 60 min remain,
        // minutes otherwise.
        let remaining = max(0, endTime.timeIntervalSince(Date()))
        let totalMinutes = Int(remaining / 60)
        let timeString: String
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            timeString = minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            timeString = "\(max(1, totalMinutes))m"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let unlockAt = formatter.string(from: endTime)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: backgroundColor,
            icon: UIImage(systemName: "eye.slash.fill")?.withTintColor(sacredGold, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "Lower Gaze", color: titleColor),
            subtitle: ShieldConfiguration.Label(
                text: "You chose to step away. \(timeString) remaining · unlocks at \(unlockAt).",
                color: subtitleColor
            ),
            // No primary button — Lower Gaze cannot be ended early. The shield
            // is a soft wall; iOS provides the dismiss gesture but no unlock.
            primaryButtonLabel: nil,
            primaryButtonBackgroundColor: nil,
            secondaryButtonLabel: nil
        )
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