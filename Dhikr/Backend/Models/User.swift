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

    // User preferences
    var selectedAppsToBlock: [String]?
    var prayerSettings: PrayerSettings?
    var locationData: LocationData?

    init(id: String? = nil, email: String, displayName: String, photoURL: String? = nil, joinDate: Date = Date(), isPremium: Bool = false) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.joinDate = joinDate
        self.isPremium = isPremium
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
