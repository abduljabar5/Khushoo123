//
//  LowerGazeStartRipple.swift
//  Dhikr
//
//  A single gold ring that expands from screen center and fades the moment a
//  Lower Gaze session begins. Visual marker for "I just made a real choice"
//  — reinforces the commitment in a physical way without being loud.
//

import SwiftUI

struct LowerGazeStartRipple: View {
    let trigger: Int

    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: Double = 0
    @State private var lastTrigger: Int = -1

    private let goldColor = Color(red: 0.77, green: 0.65, blue: 0.46)

    var body: some View {
        Circle()
            .stroke(goldColor, lineWidth: 2)
            .frame(width: 280, height: 280)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
            .allowsHitTesting(false)
            .onChange(of: trigger) { newValue in
                guard newValue > 0, newValue != lastTrigger else { return }
                lastTrigger = newValue
                playRipple()
            }
    }

    private func playRipple() {
        ringScale = 0.2
        ringOpacity = 0.8
        withAnimation(.easeOut(duration: 0.7)) {
            ringScale = 2.4
            ringOpacity = 0
        }
    }
}
