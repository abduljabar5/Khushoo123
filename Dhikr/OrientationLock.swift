//
//  OrientationLock.swift
//  Dhikr
//
//  AppDelegate for Orientation Lock + Firebase Cloud Messaging
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

// MARK: - AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("🚀 [AppDelegate] Application did finish launching")

        // Firebase is configured in DhikrApp.swift, so we don't configure it here

        // Setup Firebase Cloud Messaging
        setupFirebaseMessaging(application)

        // Setup background refresh
        BackgroundRefreshService.shared.scheduleBackgroundRefresh()

        return true
    }

    /// Forces the app to only support portrait orientation.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    /// Handles early stop when app is about to terminate
    func applicationWillTerminate(_ application: UIApplication) {
        // Perform final early stop check when app is about to close
        Task { @MainActor in
            BlockingStateService.shared.forceCheck()
        }
    }

    // MARK: - Firebase Cloud Messaging Setup

    private func setupFirebaseMessaging(_ application: UIApplication) {
        print("📱 [FCM] Setting up Firebase Cloud Messaging")

        // Set FCM messaging delegate
        Messaging.messaging().delegate = BackgroundRefreshService.shared

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

        print("✅ [FCM] Firebase Cloud Messaging setup complete")
    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("📱 [FCM] Did register for remote notifications")

        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 [FCM] APNS Token: \(tokenString)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ [FCM] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Silent Notifications

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📱 [AppDelegate] Received remote notification")
        print("📱 [AppDelegate] User info: \(userInfo)")

        // Check if it's a silent notification
        if let contentAvailable = userInfo["content-available"] as? Int, contentAvailable == 1 {
            print("🔄 [AppDelegate] Silent notification received - triggering background refresh")

            Task {
                let result = await BackgroundRefreshService.shared.handleSilentNotification(userInfo: userInfo)
                completionHandler(result)
            }
        } else {
            print("ℹ️ [AppDelegate] Regular notification received")
            completionHandler(.noData)
        }
    }

    // MARK: - Notification Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📱 [AppDelegate] Will present notification: \(notification.request.identifier)")

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📱 [AppDelegate] Did receive notification response: \(response.notification.request.identifier)")

        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap
        if let refreshType = userInfo["refreshType"] as? String, refreshType == "prayerTimeUpdate" {
            print("🔄 [AppDelegate] User tapped prayer time notification")

            // Trigger foreground refresh
            Task {
                await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Notification Tap")
            }
        }

        completionHandler()
    }

    // MARK: - Application State

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📲 [AppDelegate] Application entered background")

        // Schedule background refresh
        BackgroundRefreshService.shared.scheduleBackgroundRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📲 [AppDelegate] Application will enter foreground")

        // Check if rolling window needs update (prayer time fetch happens in SearchView)
        Task {
            let storage = PrayerTimeService().loadStorage()

            if storage?.shouldRefresh == true {
                print("ℹ️ [AppDelegate] Prayer times need refresh - will be handled by SearchView when user opens app")
            } else if let storage = storage {
                // Only check rolling window if storage is valid
                if DeviceActivityService.shared.needsRollingWindowUpdate() {
                    print("🔄 [AppDelegate] Rolling window needs update on foreground")
                    await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Rolling Window Update")
                }
            }
        }
    }
} 