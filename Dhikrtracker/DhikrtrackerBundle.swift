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
        Dhikrtracker()
        PrayerWidget()
        UnblockWidget()
        DhikrtrackerControl()
        DhikrtrackerLiveActivity()
    }
}
