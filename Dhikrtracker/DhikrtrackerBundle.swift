//
//  DhikrtrackerBundle.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import WidgetKit
import SwiftUI

@main
struct DhikrtrackerBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widgets
        Dhikrtracker()
        PrayerWidget()

        // Lock Screen Widgets - Prayer (first for visibility)
        PrayerRectangularWidget()  // Prayer Status - most useful
        PrayerCircularWidget()
        PrayerInlineWidget()

        // Lock Screen Widgets - Dhikr
        DhikrCircularWidget()
        DhikrRectangularWidget()
        DhikrInlineWidget()
    }
}
