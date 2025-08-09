import Foundation
import UserNotifications
import ManagedSettings

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // No-op for early stop; keep for future notifications if needed
        
        // Don't show the notification UI since this is internal
        completionHandler([])
    }
    
    // Handle notification when app is in background/closed
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        // No-op for early stop; keep for future notifications if needed
        
        completionHandler()
    }
    
    // Early stop notification handling removed
}