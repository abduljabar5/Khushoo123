//
//  SurahCompleteBloom.swift
//  Dhikr
//
//  A brief gold particle bloom emitted from the album art when a surah
//  finishes playing. Calm and reverent — calibrated for a religious app
//  rather than a game (no confetti, no bouncy springs, no loud color).
//

import SwiftUI

struct SurahCompleteBloom: View {
    /// Trigger token. Each new value (e.g. surah identifier or UUID) starts a
    /// fresh bloom. Pass nil to render nothing.
    let trigger: AnyHashable?

    @State private var particles: [Particle] = []
    @State private var currentTriggerHash: Int?

    private struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var opacity: Double = 1
        var scale: CGFloat = 1
    }

    private let goldColor = Color(red: 0.77, green: 0.65, blue: 0.46)

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(goldColor)
                    .frame(width: 6, height: 6)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(x: particle.x, y: particle.y)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger?.hashValue) { newValue in
            guard newValue != nil, newValue != currentTriggerHash else { return }
            currentTriggerHash = newValue
            emitBloom()
        }
    }

    private func emitBloom() {
        // Generate 12 particles distributed in a ring around the artwork.
        var newParticles: [Particle] = []
        for i in 0..<12 {
            let angle = (Double(i) / 12.0) * 2 * .pi
            // Add a small random jitter so the ring doesn't look mechanical.
            let jitter = Double.random(in: -0.1...0.1)
            let radians = angle + jitter
            newParticles.append(
                Particle(
                    x: 0, y: 0,
                    opacity: 1,
                    scale: 1
                )
            )
            _ = radians  // silence unused-warning before assignment in animation block
        }
        particles = newParticles

        // Animate each particle outward to a final position on a 120pt radius
        // ring with fade and slight scale-down. ~1.2s total.
        for index in particles.indices {
            let angle = (Double(index) / 12.0) * 2 * .pi + Double.random(in: -0.1...0.1)
            let distance: CGFloat = CGFloat.random(in: 90...130)
            let dx = CGFloat(cos(angle)) * distance
            let dy = CGFloat(sin(angle)) * distance

            // Stagger particles slightly so the bloom feels natural.
            let delay = Double(index) * 0.012
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 1.1)) {
                    particles[index].x = dx
                    particles[index].y = dy
                    particles[index].opacity = 0
                    particles[index].scale = 0.5
                }
            }
        }

        // Clear after animation finishes so we don't accumulate hidden particles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            particles = []
        }
    }
}
