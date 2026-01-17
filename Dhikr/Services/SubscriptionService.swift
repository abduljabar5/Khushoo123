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
    @Published private(set) var hasGrantedAccess: Bool = false  // Manually granted access (influencers, gifts, etc.)
    @Published private(set) var subscriptionStatus: Product.SubscriptionInfo.Status?
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    /// Combined check: user has premium access if they have a subscription OR granted access
    var hasPremiumAccess: Bool {
        return isPremium || hasGrantedAccess
    }

    private var updateListenerTask: Task<Void, Error>?
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    private var isInitialSync: Bool = true  // Track if this is the first sync to avoid false "became premium" triggers
    private var productsLoaded: Bool = false  // Track if products have been loaded
    private var hasCompletedSuccessfulCheck: Bool = false  // Track if we've done a successful StoreKit check

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
        // FIX: Read cached premium status immediately on startup
        // This prevents the UI from showing "not premium" while we verify with StoreKit
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            let cachedPremium = groupDefaults.bool(forKey: "isPremiumUser")
            if cachedPremium {
                self.isPremium = true
                print("✅ [SubscriptionService] Loaded cached premium status: true")
            }

            // Load cached granted access status
            let cachedGrantedAccess = groupDefaults.bool(forKey: "hasGrantedAccess")
            if cachedGrantedAccess {
                self.hasGrantedAccess = true
                print("✅ [SubscriptionService] Loaded cached granted access: true")
            }
        }

        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check subscription status
        // IMPORTANT: Auth listener is set up AFTER this task starts to avoid race condition
        Task { @MainActor in
            await loadProducts()
            await syncSubscriptionStatus()

            // Only set up auth listener AFTER initial sync completes
            // This prevents the auth listener from calling syncSubscriptionStatus before products load
            self.setupAuthListener()
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
                    await self.syncSubscriptionStatus()
                } else {
                    // Don't clear premium status - check StoreKit for local purchases
                    await self.syncSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Load Products
    func loadProducts() async {
        do {
            let productIDs = SubscriptionProductID.allCases.map { $0.rawValue }

            let products = try await Product.products(for: productIDs)

            // Sort by price (monthly first, then yearly)
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
                self.productsLoaded = !products.isEmpty
                print("✅ [SubscriptionService] Loaded \(products.count) products")
            }
        } catch {
            print("❌ [SubscriptionService] Failed to load products: \(error)")
        }
    }

    // MARK: - Sync Subscription Status (StoreKit + Firebase)
    func syncSubscriptionStatus() async {
        var isPremiumActive = false
        var latestTransaction: StoreKit.Transaction?
        var foundEntitlement = false  // Track if we found any entitlement (even if we can't verify status)
        var successfulCheck = false   // Track if we completed a full check successfully

        print("🔄 [SubscriptionService] Starting subscription status sync...")

        // STEP 1: Check StoreKit for active subscriptions (works without login)
        // Users can purchase and use premium without account, then sync later
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if this is one of our premium products
                if SubscriptionProductID.allCases.map({ $0.rawValue }).contains(transaction.productID) {
                    foundEntitlement = true
                    print("✅ [SubscriptionService] Found entitlement for product: \(transaction.productID)")

                    // FIX: Try to get subscription status, but don't fail silently if products aren't loaded
                    if let subscription = availableProducts.first(where: { $0.id == transaction.productID })?.subscription {
                        let status = try await subscription.status.first
                        self.subscriptionStatus = status

                        // Check if subscription is active
                        switch status?.state {
                        case .subscribed, .inGracePeriod:
                            isPremiumActive = true
                            latestTransaction = transaction
                            successfulCheck = true
                            print("✅ [SubscriptionService] Subscription is active (state: \(String(describing: status?.state)))")
                        case .inBillingRetryPeriod:
                            // Still consider premium during billing retry
                            isPremiumActive = true
                            latestTransaction = transaction
                            successfulCheck = true
                            print("⚠️ [SubscriptionService] Subscription in billing retry period - still premium")
                        case .revoked, .expired:
                            isPremiumActive = false
                            successfulCheck = true
                            print("❌ [SubscriptionService] Subscription revoked/expired")
                        case .none:
                            // FIX: If we have an entitlement but can't get status, assume premium
                            // This handles edge cases where StoreKit returns entitlement but status check fails
                            isPremiumActive = true
                            latestTransaction = transaction
                            print("⚠️ [SubscriptionService] Status is nil but entitlement exists - assuming premium")
                        @unknown default:
                            isPremiumActive = false
                            successfulCheck = true
                        }
                    } else {
                        // FIX: Products not loaded yet - if we have an entitlement, assume premium
                        // This fixes the race condition where auth listener fires before products load
                        print("⚠️ [SubscriptionService] Products not loaded, but entitlement exists - assuming premium")
                        isPremiumActive = true
                        latestTransaction = transaction
                        // Don't mark as successful check since we couldn't verify status
                    }

                    await transaction.finish()
                }
            } catch {
                print("❌ [SubscriptionService] Error checking transaction: \(error)")
            }
        }

        // STEP 2: Sync to Firebase if user is signed in (optional)
        if let userId = currentUserId {
            // Always fetch granted access status (influencers, gifts, etc.)
            await fetchGrantedAccessFromFirebase(userId: userId)

            if isPremiumActive, let transaction = latestTransaction {
                // Active subscription from StoreKit - sync to Firebase
                await syncSubscriptionToFirebase(transaction: transaction, isActive: true)
                successfulCheck = true
            } else if !foundEntitlement {
                // No entitlements from StoreKit at all
                // Check Firebase for subscription (user might have purchased on another device)
                let firebaseStatus = await loadSubscriptionFromFirebase(userId: userId)
                if firebaseStatus {
                    isPremiumActive = true
                    print("✅ [SubscriptionService] Premium restored from Firebase")
                } else {
                    // Only mark as inactive if we did a successful check and found nothing
                    if successfulCheck || productsLoaded {
                        await markSubscriptionInactive(userId: userId)
                        successfulCheck = true
                    }
                }
            }
        } else {
            // User signed out - clear granted access (it's tied to their account)
            self.hasGrantedAccess = false
            if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                groupDefaults.set(false, forKey: "hasGrantedAccess")
                groupDefaults.synchronize()
            }
            print("ℹ️ [SubscriptionService] User signed out - cleared granted access")
        }

        let wasPremium = self.isPremium

        // FIX: Only update premium status if we're certain about the result
        // Don't downgrade to false if we couldn't complete a proper check
        if isPremiumActive {
            // Always upgrade to premium if we found active subscription
            self.isPremium = true
            hasCompletedSuccessfulCheck = true
        } else if successfulCheck || (productsLoaded && !foundEntitlement) {
            // Only downgrade to false if:
            // 1. We completed a successful check and found no active subscription, OR
            // 2. Products are loaded and we found no entitlements at all
            self.isPremium = false
            hasCompletedSuccessfulCheck = true
            print("ℹ️ [SubscriptionService] Setting premium to false (successful check, no subscription)")
        } else {
            // Uncertain state - keep existing value (from cache)
            print("⚠️ [SubscriptionService] Uncertain state - keeping cached premium: \(self.isPremium)")
        }

        // FIX: Only sync to UserDefaults if we're certain about the result
        // This prevents overwriting a valid cached "true" with "false" due to race conditions
        if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
            if isPremiumActive || hasCompletedSuccessfulCheck {
                groupDefaults.set(self.isPremium, forKey: "isPremiumUser")
                groupDefaults.synchronize()
                print("💾 [SubscriptionService] Saved premium status to cache: \(self.isPremium)")
            }
        }

        // Only trigger state change notifications after the initial sync AND if we're certain
        if !isInitialSync && hasCompletedSuccessfulCheck {
            // If user just became premium, trigger background data fetch
            if self.isPremium && !wasPremium {
                print("🎉 [SubscriptionService] User became premium - posting notification")
                NotificationCenter.default.post(name: NSNotification.Name("UserBecamePremium"), object: nil)
            }

            // FIX: Only fire UserLostPremium if we're CERTAIN the user lost premium
            // (successful check confirmed no subscription)
            if !self.isPremium && wasPremium && successfulCheck {
                print("😢 [SubscriptionService] User lost premium - posting notification")
                NotificationCenter.default.post(name: NSNotification.Name("UserLostPremium"), object: nil)
            }
        } else {
            isInitialSync = false
        }

        print("✅ [SubscriptionService] Sync complete - isPremium: \(self.isPremium), hasGrantedAccess: \(self.hasGrantedAccess), hasPremiumAccess: \(self.hasPremiumAccess)")
    }

    // MARK: - Firebase Sync Methods
    private func syncSubscriptionToFirebase(transaction: StoreKit.Transaction, isActive: Bool) async {
        guard let userId = currentUserId else {
            return
        }


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
        } catch {
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
                        await markSubscriptionInactive(userId: userId)
                        return false
                    }
                }

                // Check isActive flag
                if let isActive = subscriptionDict["isActive"] as? Bool, !isActive {
                    return false
                }

                return isPremium
            }

            return false
        } catch {
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
            } else {
                // Just update isPremium if no subscription exists
                try await db.collection("users").document(userId).updateData([
                    "isPremium": false
                ])
            }
        } catch {
        }
    }

    /// Fetch granted access status from Firebase (for influencers, gifts, etc.)
    /// This is separate from subscription status and is manually managed
    private func fetchGrantedAccessFromFirebase(userId: String) async {
        do {
            let document = try await db.collection("users").document(userId).getDocument()

            if let data = document.data(),
               let grantedAccess = data["hasGrantedAccess"] as? Bool {
                self.hasGrantedAccess = grantedAccess

                // Cache the granted access status
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(grantedAccess, forKey: "hasGrantedAccess")
                    groupDefaults.synchronize()
                }

                if grantedAccess {
                    let reason = data["grantReason"] as? String ?? "unknown"
                    print("✅ [SubscriptionService] User has granted access (reason: \(reason))")
                }
            } else {
                // No granted access field found - default to false
                self.hasGrantedAccess = false
                if let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr") {
                    groupDefaults.set(false, forKey: "hasGrantedAccess")
                    groupDefaults.synchronize()
                }
            }
        } catch {
            print("❌ [SubscriptionService] Error fetching granted access: \(error)")
        }
    }

    // MARK: - Purchase Product
    func purchase(_ product: Product) async {
        // Allow purchases without login (will sync to Firebase when user logs in)
        if currentUserId == nil {
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
                }

                // Update subscription status (works locally via StoreKit)
                await syncSubscriptionStatus()

                // Finish the transaction
                await transaction.finish()

                purchaseState = .success

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error)
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await syncSubscriptionStatus()
        } catch {
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
        // Combined check: subscription OR granted access (influencers, gifts, etc.)
        return hasPremiumAccess
    }

    var monthlyProduct: Product? {
        return availableProducts.first { $0.id == SubscriptionProductID.monthly.rawValue }
    }

    var yearlyProduct: Product? {
        return availableProducts.first { $0.id == SubscriptionProductID.yearly.rawValue }
    }
}
