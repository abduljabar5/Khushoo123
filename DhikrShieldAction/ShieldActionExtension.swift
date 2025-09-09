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
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let isStrictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? false
        
        switch action {
        case .primaryButtonPressed:
            if isStrictMode {
                // In strict mode, primary button says "Open Dhikr App"
                // We can't actually open the app, but we can notify the user
                notifyUserToOpenApp()
                completionHandler(.defer)
            } else {
                handlePrayerComplete()
                completionHandler(.close)
            }
        case .secondaryButtonPressed:
            if isStrictMode {
                // In strict mode, secondary button shows voice requirement info
                completionHandler(.defer)
            } else {
                handleRemindLater()
                completionHandler(.defer)
            }
        @unknown default:
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            handlePrayerComplete()
            completionHandler(.close)
        case .secondaryButtonPressed:
            handleRemindLater()
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }
    
    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            handlePrayerComplete()
            completionHandler(.close)
        case .secondaryButtonPressed:
            handleRemindLater()
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }
    
    private func handlePrayerComplete() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let timestamp = Date().timeIntervalSince1970
        groupDefaults.set(timestamp, forKey: "lastPrayerCompleted")
        
        let isStrictMode = groupDefaults.bool(forKey: "focusStrictMode")
        if !isStrictMode {
            groupDefaults.set(false, forKey: "appsActuallyBlocked")
            let store = ManagedSettingsStore()
            store.clearAllSettings()
        }
        
        print("🤲 [ShieldAction] User indicated prayer completed")
    }
    
    private func handleRemindLater() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        let timestamp = Date().timeIntervalSince1970
        groupDefaults.set(timestamp, forKey: "lastPrayerReminder")
        
        print("⏰ [ShieldAction] User requested reminder for later")
    }
    
    private func notifyUserToOpenApp() {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else { return }
        
        // Set a flag that the main app can check
        groupDefaults.set(true, forKey: "userRequestedVoiceUnlock")
        groupDefaults.set(Date().timeIntervalSince1970, forKey: "lastVoiceUnlockRequest")
        
        // Send a helpful notification
        let content = UNMutableNotificationContent()
        content.title = "🔒 Prayer Blocking Active"
        content.body = "Please manually open the Dhikr app from your home screen and say \"Wallahi I prayed\" to unlock"
        content.sound = .default
        content.categoryIdentifier = "VOICE_UNLOCK"
        
        // Add custom data so main app knows why it was opened
        content.userInfo = ["action": "voice_unlock_required"]
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "voice_unlock_\(Date().timeIntervalSince1970)", 
                                           content: content, 
                                           trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [ShieldAction] Failed to send notification: \(error)")
            } else {
                print("🎤 [ShieldAction] Notification sent to guide user to main app")
            }
        }
        
        print("🎤 [ShieldAction] User needs to open main app for voice unlock")
    }
}
