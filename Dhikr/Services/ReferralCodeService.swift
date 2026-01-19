//
//  ReferralCodeService.swift
//  Dhikr
//
//  Validates referral codes and tracks usage for influencer commissions
//

import Foundation
import FirebaseFirestore

struct ReferralCode: Codable {
    let influencerId: String
    let influencerName: String
    let isActive: Bool
    let createdAt: Date
    var usageCount: Int
}

@MainActor
class ReferralCodeService: ObservableObject {
    static let shared = ReferralCodeService()

    @Published private(set) var validatedCode: String?
    @Published private(set) var isValidating: Bool = false
    @Published private(set) var validationError: String?

    /// UUID token to attach to purchase for commission tracking
    /// This links the App Store transaction back to the referral code
    private(set) var appAccountToken: UUID?

    private let db = Firestore.firestore()

    /// Check if user has a valid referral code applied
    var hasValidReferralCode: Bool {
        return validatedCode != nil
    }

    private init() {
        // Load any previously validated code from this session
        // We don't persist across app launches - user needs to re-enter
    }

    /// Validate a referral code against Firebase
    /// Returns true if valid, false otherwise
    func validateCode(_ code: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedCode.isEmpty else {
            validationError = "Please enter a code"
            return false
        }

        isValidating = true
        validationError = nil

        do {
            let document = try await db.collection("referralCodes").document(trimmedCode).getDocument()

            guard document.exists else {
                isValidating = false
                validationError = "Invalid code"
                return false
            }

            guard let data = document.data(),
                  let isActive = data["isActive"] as? Bool else {
                isValidating = false
                validationError = "Invalid code"
                return false
            }

            guard isActive else {
                isValidating = false
                validationError = "This code is no longer active"
                return false
            }

            // Code is valid - generate appAccountToken for commission tracking
            let token = UUID()

            // Store the mapping in Firestore so webhook can look it up later
            try await db.collection("pendingCommissions").document(token.uuidString).setData([
                "referralCode": trimmedCode,
                "influencerId": data["influencerId"] as? String ?? "",
                "createdAt": Timestamp(date: Date()),
                "status": "pending"
            ])

            // Store locally
            validatedCode = trimmedCode
            appAccountToken = token
            isValidating = false
            validationError = nil

            print("✅ [ReferralCode] Validated code: \(trimmedCode), token: \(token.uuidString)")
            return true

        } catch {
            print("❌ [ReferralCode] Error validating code: \(error)")
            isValidating = false
            validationError = "Unable to verify code. Please try again."
            return false
        }
    }

    /// Record that a referral code was used for a purchase
    /// Call this after successful subscription purchase
    func recordCodeUsage(transactionId: String) async {
        guard let code = validatedCode else { return }

        do {
            let docRef = db.collection("referralCodes").document(code)

            // Increment usage count
            try await docRef.updateData([
                "usageCount": FieldValue.increment(Int64(1))
            ])

            // Also record the specific usage in a subcollection for tracking
            try await docRef.collection("usages").addDocument(data: [
                "transactionId": transactionId,
                "usedAt": Timestamp(date: Date()),
                "platform": "iOS"
            ])

            print("✅ [ReferralCode] Recorded usage for code: \(code)")

        } catch {
            print("❌ [ReferralCode] Error recording usage: \(error)")
        }
    }

    /// Clear the validated code (e.g., after purchase or if user cancels)
    func clearCode() {
        validatedCode = nil
        validationError = nil
        appAccountToken = nil
    }
}
