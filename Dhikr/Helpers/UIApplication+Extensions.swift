//
//  UIApplication+Extensions.swift
//  Dhikr
//
//  Adapted from AppleMusicStylePlayer by Alexey Vorobyov
//

import UIKit

extension UIApplication {
    static var keyWindow: UIWindow? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow
    }
}
