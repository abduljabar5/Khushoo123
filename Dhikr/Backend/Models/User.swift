//
//  User.swift
//  Dhikr
//
//  Created by Claude Code
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var photoURL: String?
    var joinDate: Date
    var isPremium: Bool
    var subscription: SubscriptionData?

    // User preferences
    var selectedAppsToBlock: [String]?
    var prayerSettings: PrayerSettings?
    var locationData: LocationData?

    init(id: String? = nil, email: String, displayName: String, photoURL: String? = nil, joinDate: Date = Date(), isPremium: Bool = false, subscription: SubscriptionData? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.joinDate = joinDate
        self.isPremium = isPremium
        self.subscription = subscription
    }
}

struct SubscriptionData: Codable {
    var productId: String              // "com.dhikr.premium.monthly" or "com.dhikr.premium.yearly"
    var purchaseDate: Date             // When subscription started
    var expirationDate: Date?          // When it expires (nil if active)
    var isActive: Bool                 // Current status
    var autoRenewStatus: Bool          // Is auto-renew enabled
    var originalTransactionId: String  // Apple's original transaction ID
    var lastVerified: Date             // Last time we verified with Apple
    var environment: String            // "Xcode", "Sandbox", "Production"

    init(productId: String, purchaseDate: Date, expirationDate: Date? = nil, isActive: Bool = true, autoRenewStatus: Bool = true, originalTransactionId: String, lastVerified: Date = Date(), environment: String = "Production") {
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isActive = isActive
        self.autoRenewStatus = autoRenewStatus
        self.originalTransactionId = originalTransactionId
        self.lastVerified = lastVerified
        self.environment = environment
    }
}

struct PrayerSettings: Codable {
    var enabledPrayers: [String] // ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
    var notificationOffset: Int // minutes before prayer time
    var calculationMethod: String
}

struct LocationData: Codable {
    var city: String
    var coordinates: Coordinates
    var lastUpdated: Date
}

struct Coordinates: Codable {
    var latitude: Double
    var longitude: Double
}
