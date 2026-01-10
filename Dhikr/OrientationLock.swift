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
        // Save last played info before termination
        AudioPlayerService.shared.saveLastPlayed()

        // Perform final early stop check when app is about to close
        Task { @MainActor in
            BlockingStateService.shared.forceCheck()
        }
    }

    // MARK: - Firebase Cloud Messaging Setup

    private func setupFirebaseMessaging(_ application: UIApplication) {

        // Set FCM messaging delegate
        Messaging.messaging().delegate = BackgroundRefreshService.shared

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications
        application.registerForRemoteNotifications()

    }

    // MARK: - Remote Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {

        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken

        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
    }

    // MARK: - Silent Notifications

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {

        // Check if it's a silent notification
        if let contentAvailable = userInfo["content-available"] as? Int, contentAvailable == 1 {

            Task {
                let result = await BackgroundRefreshService.shared.handleSilentNotification(userInfo: userInfo)
                completionHandler(result)
            }
        } else {
            completionHandler(.noData)
        }
    }

    // MARK: - Notification Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {

        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap
        if let refreshType = userInfo["refreshType"] as? String, refreshType == "prayerTimeUpdate" {

            // Trigger foreground refresh
            Task {
                await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Notification Tap")
            }
        }

        completionHandler()
    }

    // MARK: - Application State

    func applicationDidEnterBackground(_ application: UIApplication) {

        // Schedule background refresh
        BackgroundRefreshService.shared.scheduleBackgroundRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {

        // Check if rolling window needs update (prayer time fetch happens in SearchView)
        Task {
            let storage = PrayerTimeService().loadStorage()

            if storage?.shouldRefresh == true {
            } else if let storage = storage {
                // Only check rolling window if storage is valid
                if DeviceActivityService.shared.needsRollingWindowUpdate() {
                    await BackgroundRefreshService.shared.triggerManualRefresh(reason: "Rolling Window Update")
                }
            }
        }
    }
} 