//
//  SubscriptionService.swift
//  Dhikr
//
//  Premium subscription management using StoreKit 2 + Firebase sync
//

import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Subscription Product IDs
enum SubscriptionProductID: String, CaseIterable {
    case monthly = "khushoo.monthly"
    case yearly = "khushoo.yearly"
}

// MARK: - Subscription Service
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var subscriptionStatus: Product.SubscriptionInfo.Status?
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published var showPostPurchaseSignInPrompt: Bool = false

    private var updateListenerTask: Task<Void, Error>?
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    private var isInitialSync: Bool = true  // Track if this is the first sync to avoid false "became premium" triggers

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(Error)

        static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.purchasing, .purchasing), (.success, .success):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }

    private init() {
        // Start listening to auth state changes
        setupAuthListener()

        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check subscription status
        Task { @MainActor in
            print("🛒 [SubscriptionService] Initializing...")
            await loadProducts()
            await syncSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth Listener
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.currentUserId = user?.uid

                if user != nil {
                    print("👤 [SubscriptionService] User signed in, syncing subscription...")
                    await self.syncSubscriptionStatus()
                } else {
                    print("👤 [SubscriptionService] User signed out, re-checking local subscription...")
                    // Don't clear premium status - check StoreKit for local purchases
                    await self.syncSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        print("🛒 [SubscriptionService] Loading products...")
        do {
            let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }
            print("🛒 [SubscriptionService] Product IDs: \(productIDs)")

            let products = try await Product.products(for: productIDs)

            // Sort by price (monthly first, then yearly)
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
                print("✅ [SubscriptionService] Loaded \(products.count) products")
                for product in products {
                    print("   - \(product.displayName): \(product.displayPrice)")
                }
            }
        } catch {
            print("❌ [SubscriptionService] Failed to load products: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Subscription Status (StoreKit + Firebase)
    func syncSubscriptionStatus() async {
        var isPremiumActive = false
        var latestTransaction: StoreKit.Transaction?

        // STEP 1: Check StoreKit for active subscriptions (works without login)
        // Users can purchase and use premium without account, then sync later
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if this is one of our premium products
                if SubscriptionProductID.allCases.map({ $0.rawValue }).contains(transaction.productID) {
                    // Get subscription status
                    if let subscription = availableProducts.first(where: { $0.id == transaction.productID })?.subscription {
                        let status = try await subscription.status.first
                        self.subscriptionStatus = status

                        // Check if subscription is active
                        switch status?.state {
                        case .subscribed, .inGracePeriod:
                            isPremiumActive = true
                            latestTransaction = transaction
                        case .inBillingRetryPeriod, .revoked, .expired, .none:
                            isPremiumActive = false
                        @unknown default:
                            isPremiumActive = false
                        }
                    }

                    await transaction.finish()
                }
            } catch {
                print("❌ [SubscriptionService] Failed to verify transaction: \(error)")
            }
        }

        // STEP 2: Sync to Firebase if user is signed in (optional)
        if let userId = currentUserId {
            if isPremiumActive, let transaction = latestTransaction {
                // Active subscription from StoreKit - sync to Firebase
                await syncSubscriptionToFirebase(transaction: transaction, isActive: true)
            } else {
                // No active subscription from StoreKit
                // Check Firebase for subscription (user might have purchased on another device)
                let firebaseStatus = await loadSubscriptionFromFirebase(userId: userId)
                if firebaseStatus {
                    isPremiumActive = true
                    print("✅ [SubscriptionService] Premium status loaded from Firebase")
                } else {
                    // No active subscription anywhere - mark as cancelled in Firebase
                    await markSubscriptionInactive(userId: userId)
                }
            }
        } else {
            // User not logged in - premium still works via StoreKit
            if isPremiumActive {
                print("ℹ️ [SubscriptionService] Premium active locally (not synced to Firebase yet)")
            }
        }

        let wasPremium = self.isPremium
        self.isPremium = isPremiumActive
        print("✅ [SubscriptionService] Final premium status: \(isPremiumActive)")

        // Sync premium status to App Group UserDefaults for monitor extension
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            groupDefaults.set(isPremiumActive, forKey: "isPremiumUser")
            groupDefaults.synchronize()
            print("📝 [SubscriptionService] Synced premium status to App Group: \(isPremiumActive)")
        }

        // Only trigger state change notifications after the initial sync
        if !isInitialSync {
            // If user just became premium, trigger background data fetch
            if isPremiumActive && !wasPremium {
                print("🎉 [SubscriptionService] User just became premium! Triggering background fetch...")
                NotificationCenter.default.post(name: NSNotification.Name("UserBecamePremium"), object: nil)
            }

            // If user lost premium status, turn off app blocking
            if !isPremiumActive && wasPremium {
                print("⚠️ [SubscriptionService] User lost premium status - disabling app blocking")
                NotificationCenter.default.post(name: NSNotification.Name("UserLostPremium"), object: nil)
            }
        } else {
            print("ℹ️ [SubscriptionService] Initial sync complete - skipping state change notifications")
            isInitialSync = false
        }
    }

    // MARK: - Firebase Sync Methods
    private func syncSubscriptionToFirebase(transaction: StoreKit.Transaction, isActive: Bool) async {
        guard let userId = currentUserId else {
            print("⚠️ [SubscriptionService] No user signed in, skipping Firebase sync")
            return
        }

        print("📤 [SubscriptionService] Syncing subscription to Firebase...")

        let subscriptionData = SubscriptionData(
            productId: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            isActive: isActive,
            autoRenewStatus: true,
            originalTransactionId: String(transaction.originalID),
            lastVerified: Date(),
            environment: transaction.environment.rawValue
        )

        do {
            try await db.collection("users").document(userId).updateData([
                "isPremium": isActive,
                "subscription": try Firestore.Encoder().encode(subscriptionData)
            ])
            print("✅ [SubscriptionService] Subscription synced to Firebase")
        } catch {
            print("❌ [SubscriptionService] Failed to sync to Firebase: \(error)")
        }
    }

    private func loadSubscriptionFromFirebase(userId: String) async -> Bool {
        do {
            let document = try await db.collection("users").document(userId).getDocument()

            if let data = document.data(),
               let isPremium = data["isPremium"] as? Bool,
               let subscriptionDict = data["subscription"] as? [String: Any] {

                // Check if subscription is still valid
                if let expirationDateTimestamp = subscriptionDict["expirationDate"] as? Timestamp {
                    let expirationDate = expirationDateTimestamp.dateValue()
                    if expirationDate < Date() {
                        print("⚠️ [SubscriptionService] Firebase subscription expired, marking as inactive")
                        await markSubscriptionInactive(userId: userId)
                        return false
                    }
                }

                // Check isActive flag
                if let isActive = subscriptionDict["isActive"] as? Bool, !isActive {
                    print("⚠️ [SubscriptionService] Subscription marked as inactive in Firebase")
                    return false
                }

                return isPremium
            }

            return false
        } catch {
            print("❌ [SubscriptionService] Failed to load from Firebase: \(error)")
            return false
        }
    }

    private func markSubscriptionInactive(userId: String) async {
        do {
            // Check if there's an existing subscription to update
            let document = try await db.collection("users").document(userId).getDocument()

            if let data = document.data(),
               var subscriptionDict = data["subscription"] as? [String: Any] {
                // Update existing subscription as inactive
                subscriptionDict["isActive"] = false
                subscriptionDict["lastVerified"] = Timestamp(date: Date())

                try await db.collection("users").document(userId).updateData([
                    "isPremium": false,
                    "subscription": subscriptionDict
                ])
                print("✅ [SubscriptionService] Subscription marked as inactive in Firebase")
            } else {
                // Just update isPremium if no subscription exists
                try await db.collection("users").document(userId).updateData([
                    "isPremium": false
                ])
                print("✅ [SubscriptionService] Premium status set to false in Firebase")
            }
        } catch {
            print("❌ [SubscriptionService] Failed to mark subscription inactive: \(error)")
        }
    }

    // MARK: - Purchase Product
    func purchase(_ product: Product) async {
        // Allow purchases without login (will sync to Firebase when user logs in)
        if currentUserId == nil {
            print("ℹ️ [SubscriptionService] Purchasing without login - will sync when user creates account")
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Sync to Firebase if user is logged in
                if currentUserId != nil {
                    await syncSubscriptionToFirebase(transaction: transaction, isActive: true)
                } else {
                    print("ℹ️ [SubscriptionService] Purchase successful - will sync to Firebase when user logs in")
                    // Show post-purchase sign-in prompt to encourage account creation
                    showPostPurchaseSignInPrompt = true
                }

                // Update subscription status (works locally via StoreKit)
                await syncSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                purchaseState = .success
                print("✅ [SubscriptionService] Purchase successful: \(product.id)")

            case .userCancelled:
                purchaseState = .idle
                print("ℹ️ [SubscriptionService] User cancelled purchase")

            case .pending:
                purchaseState = .idle
                print("⏳ [SubscriptionService] Purchase pending approval")

            @unknown default:
                purchaseState = .idle
                print("⚠️ [SubscriptionService] Unknown purchase result")
            }
        } catch {
            purchaseState = .failed(error)
            print("❌ [SubscriptionService] Purchase failed: \(error)")
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await syncSubscriptionStatus()
            print("✅ [SubscriptionService] Purchases restored and synced")
        } catch {
            print("❌ [SubscriptionService] Failed to restore purchases: \(error)")
        }
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self = self else { continue }

                await MainActor.run {
                    do {
                        let transaction = try self.checkVerified(result)

                        Task {
                            await self.syncSubscriptionStatus()
                            await transaction.finish()
                        }
                    } catch {
                        print("❌ [SubscriptionService] Transaction verification failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Verify Transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Clear Subscription Data
    private func clearSubscriptionData() {
        // Clear all subscription-related state
        isPremium = false
        subscriptionStatus = nil
        purchaseState = .idle
        currentUserId = nil

        print("🧹 [SubscriptionService] Subscription data cleared")
    }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
    case userNotSignedIn
}

// MARK: - Convenience Extensions
extension SubscriptionService {
    var hasPremium: Bool {
        // Premium is based on StoreKit verification (tied to Apple ID)
        // Works regardless of Firebase auth status
        return isPremium
    }

    var monthlyProduct: Product? {
        return availableProducts.first { $0.id == SubscriptionProductID.monthly.rawValue }
    }

    var yearlyProduct: Product? {
        return availableProducts.first { $0.id == SubscriptionProductID.yearly.rawValue }
    }
}
