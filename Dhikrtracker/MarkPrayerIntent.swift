//
//  MarkPrayerIntent.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import AppIntents
import WidgetKit
import ManagedSettings
import Foundation

struct MarkPrayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Prayer as Completed"
    static var description = IntentDescription("Marks a prayer as completed and unblocks apps.")
    
    @Parameter(title: "Prayer Name")
    var prayerName: String
    
    init() {}
    
    init(prayerName: String) {
        self.prayerName = prayerName
    }
    
    func perform() async throws -> some IntentResult {
        guard let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") else {
            return .result()
        }
        
        let now = Date()
        
        // 1. Check Cooldown
        let cooldownKey = "lastMarkedTime_\(prayerName)"
        if let lastMarked = groupDefaults.object(forKey: cooldownKey) as? Date {
            if now.timeIntervalSince(lastMarked) < 300 { // 5 minutes
                // Still in cooldown
                return .result()
            }
        }
        
        // 2. Mark as Completed
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayKey = dateFormatter.string(from: now)
        let completedKey = "completed_\(todayKey)"
        
        var completed = groupDefaults.array(forKey: completedKey) as? [String] ?? []
        if !completed.contains(prayerName) {
            completed.append(prayerName)
            groupDefaults.set(completed, forKey: completedKey)
        }
        
        // 3. Update Blocking State (Early Unlock Logic) - REMOVED
        // Unblocking is now handled by UnblockAppIntent in a separate widget.
        // We only mark the prayer as completed here.
        
        // 4. Set Cooldown
        groupDefaults.set(now, forKey: cooldownKey)
        
        // 5. Refresh Widget
        // WidgetCenter.shared.reloadAllTimelines() // Automatically handled by system usually, but good to be explicit if needed.
        // Returning .result() triggers reload.
        
        return .result()
    }
}
