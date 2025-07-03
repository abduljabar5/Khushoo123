//
//  AppIntent.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("This is an example widget.")
}
