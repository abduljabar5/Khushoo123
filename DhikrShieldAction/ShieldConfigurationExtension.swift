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
    
    private func createConfiguration() -> ShieldConfiguration {
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let isStrictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false
        
        // Get context
        let currentPrayerName = groupDefaults?.string(forKey: "currentPrayerName") ?? "Prayer"
        let prayerTitle = currentPrayerName.isEmpty ? "Prayer Time" : "\(currentPrayerName) Time"
        
        // Calculate unlock time (5 minutes after start)
        var unlockTimeText = "Take a moment to pray"
        if let startTimestamp = groupDefaults?.object(forKey: "blockingStartTime") as? TimeInterval {
            let startTime = Date(timeIntervalSince1970: startTimestamp)
            let unlockTime = startTime.addingTimeInterval(300) // 5 minutes
            
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: unlockTime)
            
            unlockTimeText = "Apps available at \(timeString)"
        }
        
        // Colors & Style
        let primaryColor = UIColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 1.0) // Islamic Green-ish
        let secondaryColor = UIColor.secondaryLabel
        
        if isStrictMode {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThickMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: "lock.shield.fill"),
                title: ShieldConfiguration.Label(text: "Voice Unlock Required", color: .label),
                subtitle: ShieldConfiguration.Label(text: "Open Dhikr app and say 'Wallahi I prayed' to unlock.", color: secondaryColor),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Open Dhikr App", color: .white),
                primaryButtonBackgroundColor: primaryColor,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "Emergency", color: .systemGray)
            )
        } else {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemThickMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: "hands.sparkles.fill"), // More aesthetic icon
                title: ShieldConfiguration.Label(text: prayerTitle, color: .label),
                subtitle: ShieldConfiguration.Label(text: unlockTimeText, color: secondaryColor),
                primaryButtonLabel: ShieldConfiguration.Label(text: "Unblock Apps", color: .white),
                primaryButtonBackgroundColor: primaryColor,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "Wait", color: .systemGray)
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