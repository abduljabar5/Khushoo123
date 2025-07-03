//
//  DhikrCount.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import Foundation

// MARK: - Dhikr Count Model
struct DhikrCount: Codable {
    var subhanAllah: Int
    var alhamdulillah: Int
    var astaghfirullah: Int
    var lastUpdated: Date
    var streak: Int
    var lastResetDate: Date
    
    // Computed property for total count
    var totalCount: Int {
        subhanAllah + alhamdulillah + astaghfirullah
    }
    
    // Initialize with default values
    init() {
        self.subhanAllah = 0
        self.alhamdulillah = 0
        self.astaghfirullah = 0
        self.lastUpdated = Date()
        self.streak = 0
        self.lastResetDate = Date()
    }
    
    // Check if we need to reset for a new day
    var shouldReset: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastReset = calendar.startOfDay(for: lastResetDate)
        return today > lastReset
    }
    
    // Reset counts for new day
    mutating func resetForNewDay() {
        if shouldReset {
            // Check if user had any dhikr yesterday to maintain streak
            let hadDhikrYesterday = totalCount > 0
            
            // Reset counts
            subhanAllah = 0
            alhamdulillah = 0
            astaghfirullah = 0
            lastUpdated = Date()
            lastResetDate = Date()
            
            // Update streak
            if hadDhikrYesterday {
                streak += 1
            } else {
                streak = 0
            }
        }
    }
    
    // Increment specific dhikr count
    mutating func increment(_ type: DhikrType) {
        resetForNewDay() // Check for reset first
        
        switch type {
        case .subhanAllah:
            subhanAllah += 1
        case .alhamdulillah:
            alhamdulillah += 1
        case .astaghfirullah:
            astaghfirullah += 1
        }
        
        lastUpdated = Date()
    }
    
    // Set specific dhikr count
    mutating func setCount(_ type: DhikrType, count: Int) {
        resetForNewDay() // Check for reset first
        
        switch type {
        case .subhanAllah:
            subhanAllah = max(0, count)
        case .alhamdulillah:
            alhamdulillah = max(0, count)
        case .astaghfirullah:
            astaghfirullah = max(0, count)
        }
        
        lastUpdated = Date()
    }
    
    // Get motivational message based on streak
    var motivationalMessage: String {
        switch streak {
        case 0:
            return "Start your dhikr journey today!"
        case 1:
            return "Great start! Keep it up!"
        case 2...6:
            return "You're building a beautiful habit!"
        case 7...13:
            return "One week strong! MashaAllah!"
        case 14...29:
            return "Two weeks! You're amazing!"
        case 30...:
            return "A month of consistency! SubhanAllah!"
        default:
            return "Keep going, every dhikr counts!"
        }
    }
    
    // Get count for a specific dhikr type
    func count(for type: DhikrType) -> Int {
        switch type {
        case .subhanAllah:
            return subhanAllah
        case .alhamdulillah:
            return alhamdulillah
        case .astaghfirullah:
            return astaghfirullah
        }
    }
}

// MARK: - Dhikr Type Enum
enum DhikrType: String, CaseIterable, Hashable {
    case subhanAllah = "SubhanAllah"
    case alhamdulillah = "Alhamdulillah"
    case astaghfirullah = "Astaghfirullah"
    
    var arabicText: String {
        switch self {
        case .subhanAllah:
            return "سبحان الله"
        case .alhamdulillah:
            return "الحمد لله"
        case .astaghfirullah:
            return "أستغفر الله"
        }
    }
    
    var meaning: String {
        switch self {
        case .subhanAllah:
            return "Glory be to Allah"
        case .alhamdulillah:
            return "Praise be to Allah"
        case .astaghfirullah:
            return "I seek forgiveness from Allah"
        }
    }
    
    var color: String {
        switch self {
        case .subhanAllah:
            return "blue"
        case .alhamdulillah:
            return "green"
        case .astaghfirullah:
            return "purple"
        }
    }
} 