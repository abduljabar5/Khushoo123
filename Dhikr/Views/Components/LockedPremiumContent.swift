//
//  LockedPremiumContent.swift
//  Dhikr
//
//  View modifier for premium-gated controls. When isLocked is true, dims the
//  wrapped content, shows a small lock badge in the top-right, blocks all
//  interaction with the underlying content, and routes any tap to the
//  generic .requestPaywall notification.
//
//  Used to make premium-only sections of the Focus tab visible-but-locked for
//  free users instead of hiding them entirely.
//

import SwiftUI

struct LockedPremiumContent<Content: View>: View {
    let isLocked: Bool
    @ViewBuilder let content: () -> Content

    private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .opacity(isLocked ? 0.4 : 1.0)
                .allowsHitTesting(!isLocked)

            if isLocked {
                // Tap layer — covers the whole content area so any tap on a
                // locked control fires the paywall. Sits below the badge in
                // z-order but above the content's own hit-testing (which is
                // disabled).
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticManager.shared.impact(.light)
                        NotificationCenter.default.post(name: .requestPaywall, object: nil)
                    }

                // Lock badge — small gold pill in the corner so users can see
                // at a glance which sections are premium.
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .medium))
                    Text("PREMIUM")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(sacredGold)
                )
                .padding(10)
                .allowsHitTesting(false)
            }
        }
    }
}
