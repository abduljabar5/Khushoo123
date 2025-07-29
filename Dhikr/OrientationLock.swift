//
//  OrientationLock.swift
//  Dhikr
//
//  Created by Performance Optimization
//

import UIKit

// MARK: - AppDelegate for Orientation Lock
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    /// Forces the app to only support portrait orientation.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
} 