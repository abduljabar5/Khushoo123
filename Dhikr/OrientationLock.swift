//
//  OrientationLock.swift
//  Dhikr
//
//  AppDelegate for Orientation Lock + Notifications
//

import UIKit
import UserNotifications

// MARK: - AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

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
        completionHandler()
    }

    // MARK: - Application State

    func applicationDidEnterBackground(_ application: UIApplication) {

        // Schedule background refresh
        BackgroundRefreshService.shared.scheduleBackgroundRefresh()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {

        // Check if rolling window needs update
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
