//
//  DhikrtrackerLiveActivity.swift
//  Dhikrtracker
//
//  Created by Abduljabar Nur on 6/21/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DhikrtrackerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DhikrtrackerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DhikrtrackerAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension DhikrtrackerAttributes {
    fileprivate static var preview: DhikrtrackerAttributes {
        DhikrtrackerAttributes(name: "World")
    }
}

extension DhikrtrackerAttributes.ContentState {
    fileprivate static var smiley: DhikrtrackerAttributes.ContentState {
        DhikrtrackerAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DhikrtrackerAttributes.ContentState {
         DhikrtrackerAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DhikrtrackerAttributes.preview) {
   DhikrtrackerLiveActivity()
} contentStates: {
    DhikrtrackerAttributes.ContentState.smiley
    DhikrtrackerAttributes.ContentState.starEyes
}
