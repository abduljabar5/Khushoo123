//
//  ShareReferralCard.swift
//  Dhikr
//
//  Share Khushoo to unlock 7-day trial - Sacred Minimalism
//

import SwiftUI
import UIKit

struct ShareReferralCard: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingShareSheet = false
    @State private var showingSuccessAlert = false
    @State private var showingPaywall = false

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        if subscriptionService.canEarnReferralAccess && !subscriptionService.hasPremiumAccess {
            Button(action: {
                showingShareSheet = true
            }) {
                HStack(spacing: 16) {
                    // Gift icon
                    ZStack {
                        Circle()
                            .fill(sacredGold.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: "gift.fill")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(sacredGold)
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Share Khushoo")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.theme.primaryText)

                        Text("Unlock 7-day free trial")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(softGreen)
                    }

                    Spacer()

                    // Arrow
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(sacredGold)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(sacredGold.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(
                    activityItems: [shareMessage, shareURL].compactMap { $0 },
                    onComplete: { _, isValidShare in
                        if isValidShare {
                            AnalyticsService.shared.trackAppShared()
                            subscriptionService.claimReferralAccess()
                            showingSuccessAlert = true
                        }
                    }
                )
            }
            .alert("7-Day Trial Unlocked!", isPresented: $showingSuccessAlert) {
                Button("View Offer") {
                    showingPaywall = true
                }
                Button("Later", role: .cancel) { }
            } message: {
                Text("Thank you for sharing! You've unlocked access to our 7-day free trial.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var shareMessage: String {
        "I'm using Khushoo to stay focused during prayer times and strengthen my connection with Allah. Try it free!"
    }

    private var shareURL: URL? {
        URL(string: "https://apps.apple.com/us/app/khushoo/id6748625242")
    }
}

// MARK: - Share Sheet with Completion Handler
struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: (UIActivity.ActivityType?, Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            // Only count as successful if:
            // 1. User completed the action
            // 2. Activity type exists
            // 3. NOT just copying to clipboard
            let isValidShare = completed &&
                               activityType != nil &&
                               activityType != .copyToPasteboard
            onComplete(activityType, isValidShare)
        }

        // Exclude activities that don't count as "sharing"
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .print,
            .saveToCameraRoll,
            .copyToPasteboard  // Also hide copy option entirely
        ]

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ShareReferralCard()
        .padding()
}
