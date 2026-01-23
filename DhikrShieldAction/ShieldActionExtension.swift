//
//  ShieldActionExtension.swift
//  DhikrShieldAction
//
//  Created by Abduljabar Nur on 8/31/25.
//

import ManagedSettings
import Foundation
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action: action, completionHandler: completionHandler)
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action: action, completionHandler: completionHandler)
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action: action, completionHandler: completionHandler)
    }
    
    private func handleAction(action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let isStrictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false
        
        switch action {
        case .primaryButtonPressed:
            if isStrictMode {
                notifyUserToOpenApp()
                completionHandler(.defer)
            } else {
                attemptUnblock(completionHandler: completionHandler)
            }
        case .secondaryButtonPressed:
            // "Wait" or "Cancel" button - just keep shield
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }
    
    private func attemptUnblock(completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            completionHandler(.defer)
            return
        }

        // Check if early unlock is available (5 min after prayer time)
        if let availableAtTimestamp = groupDefaults.object(forKey: "earlyUnlockAvailableAt") as? TimeInterval {
            let availableAt = Date(timeIntervalSince1970: availableAtTimestamp)
            let now = Date()

            if now < availableAt {
                // Still waiting - show remaining time
                let remaining = Int(availableAt.timeIntervalSince(now))
                let minutes = remaining / 60
                let seconds = remaining % 60
                let timeStr = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"

                notifyUserWait(timeRemaining: timeStr)
                completionHandler(.defer) // Keep shield
                return
            }
        }

        // Early unlock is available - direct user to open app
        // Note: Extensions cannot clear ManagedSettings; must be done from main app
        notifyUserToOpenAppForUnlock()
        completionHandler(.defer)
    }

    private func notifyUserToOpenAppForUnlock() {
        let content = UNMutableNotificationContent()
        content.title = "Early Unlock Available"
        content.body = "Open Khushoo to unlock your apps."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyUserWait(timeRemaining: String) {
        let content = UNMutableNotificationContent()
        content.title = "⏳ Please Wait"
        content.body = "Apps will be available in \(timeRemaining). Take this time to pray."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyUserToOpenApp() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }

        groupDefaults.set(true, forKey: "userRequestedVoiceUnlock")
        groupDefaults.set(Date().timeIntervalSince1970, forKey: "lastVoiceUnlockRequest")

        let content = UNMutableNotificationContent()
        content.title = "Voice Unlock Required"
        content.body = "Open Khushoo and say \"Wallahi I prayed\" to unlock."
        content.sound = .default
        content.userInfo = ["action": "voice_unlock_required"]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
