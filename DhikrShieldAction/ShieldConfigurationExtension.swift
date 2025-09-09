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
        
        let countdownText = getCountdownText()
        
        // Customize based on strict mode
        if isStrictMode {
            return ShieldConfiguration(
                backgroundBlurStyle: UIBlurEffect.Style.systemMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: "lock.fill"),
                title: ShieldConfiguration.Label(text: "🔒 Voice Required", color: UIColor.label),
                subtitle: ShieldConfiguration.Label(text: countdownText, color: UIColor.secondaryLabel),
                primaryButtonLabel: ShieldConfiguration.Label(text: "1. Close this → 2. Open Dhikr", color: UIColor.white),
                primaryButtonBackgroundColor: UIColor.systemOrange,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "Cancel", color: UIColor.systemGray)
            )
        } else {
            return ShieldConfiguration(
                backgroundBlurStyle: UIBlurEffect.Style.systemMaterial,
                backgroundColor: UIColor.systemBackground,
                icon: UIImage(systemName: "moon.fill"),
                title: ShieldConfiguration.Label(text: "🤲 Prayer Time", color: UIColor.label),
                subtitle: ShieldConfiguration.Label(text: countdownText, color: UIColor.secondaryLabel),
                primaryButtonLabel: ShieldConfiguration.Label(text: "I've Prayed", color: UIColor.systemBlue),
                primaryButtonBackgroundColor: UIColor.systemBlue,
                secondaryButtonLabel: ShieldConfiguration.Label(text: "Remind Later", color: UIColor.systemGray)
            )
        }
    }
    
    private func getCountdownText() -> String {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return "Take a moment to pray"
        }
        
        let isStrictMode = groupDefaults.bool(forKey: "focusStrictMode")
        
        // Get current prayer name for context
        let currentPrayerName = groupDefaults.string(forKey: "currentPrayerName") ?? ""
        let prayerContext = currentPrayerName.isEmpty ? "" : "(\(currentPrayerName)) "
        
        // Try to get blocking end time
        if let blockingEndTimestamp = groupDefaults.object(forKey: "blockingEndTime") as? TimeInterval {
            let endTime = Date(timeIntervalSince1970: blockingEndTimestamp)
            let now = Date()
            
            if endTime > now {
                let remaining = endTime.timeIntervalSince(now)
                let minutes = Int(remaining / 60)
                let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
                
                var timeText = ""
                if minutes > 0 {
                    timeText = "\(prayerContext)Blocked for \(minutes)m \(seconds)s"
                } else {
                    timeText = "\(prayerContext)Blocked for \(seconds)s"
                }
                
                if isStrictMode {
                    return "\(timeText)\nClose this → Open Dhikr → Say \"Wallahi I prayed\""
                } else {
                    return "\(timeText) more"
                }
            }
        }
        
        // Fallback: calculate from start time + duration
        if let startTimestamp = groupDefaults.object(forKey: "blockingStartTime") as? TimeInterval {
            let startTime = Date(timeIntervalSince1970: startTimestamp)
            let duration = groupDefaults.object(forKey: "focusBlockingDuration") as? Double ?? 15.0
            let endTime = startTime.addingTimeInterval(duration * 60)
            let now = Date()
            
            if endTime > now {
                let remaining = endTime.timeIntervalSince(now)
                let minutes = Int(remaining / 60)
                let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
                
                var timeText = ""
                if minutes > 0 {
                    timeText = "\(prayerContext)Blocked for \(minutes)m \(seconds)s"
                } else {
                    timeText = "\(prayerContext)Blocked for \(seconds)s"
                }
                
                if isStrictMode {
                    return "\(timeText)\nClose this → Open Dhikr → Say \"Wallahi I prayed\""
                } else {
                    return "\(timeText) more"
                }
            }
        }
        
        // Default fallback with prayer context if available
        if isStrictMode {
            return "Close this → Open Dhikr → Say \"Wallahi I prayed\""
        } else if !currentPrayerName.isEmpty {
            return "\(prayerContext)Take a moment to pray"
        }
        return "Take a moment to pray"
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