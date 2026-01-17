//
//  AuthenticationService.swift
//  Dhikr
//
//  Backend service for Firebase Authentication
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import AuthenticationServices
import CryptoKit

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .userNotFound:
            return "No account found with this email"
        case .wrongPassword:
            return "Incorrect password"
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknown(let message):
            return message
        }
    }
}

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authError: AuthError?
    @Published var isLoading = false

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // Apple Sign In
    var currentNonce: String?

    init() {
        // Listen to auth state changes
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            if let firebaseUser = firebaseUser {
                Task {
                    await self?.fetchUserData(uid: firebaseUser.uid)
                }
            } else {
                self?.isAuthenticated = false
                self?.currentUser = nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async throws {
        guard !email.isEmpty else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }
        guard !displayName.isEmpty else { throw AuthError.unknown("Please enter your name") }

        await MainActor.run { isLoading = true }

        do {
            let result = try await auth.createUser(withEmail: email, password: password)

            // Capitalize the name before saving
            let capitalizedName = capitalizeName(displayName)

            // Create user profile in Firestore
            let newUser = User(
                id: result.user.uid,
                email: email,
                displayName: capitalizedName,
                joinDate: Date(),
                isPremium: false,
                hasGrantedAccess: false,
                grantReason: ""
            )

            try await saveUserToFirestore(user: newUser)

            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
                self.isLoading = false
            }

        } catch let error as NSError {
            await MainActor.run { isLoading = false }
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        guard !email.isEmpty else { throw AuthError.invalidEmail }
        guard !password.isEmpty else { throw AuthError.weakPassword }

        await MainActor.run { isLoading = true }

        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await fetchUserData(uid: result.user.uid)
            await MainActor.run { isLoading = false }

        } catch let error as NSError {
            await MainActor.run { isLoading = false }
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign Out
    func signOut() throws {
        do {

            // 1. Sign out from Firebase Auth
            try auth.signOut()

            // 2. Clear local state
            isAuthenticated = false
            currentUser = nil

            // 3. Clear subscription status (will be handled by SubscriptionService auth listener)
            // The SubscriptionService automatically clears premium status when auth state changes

            // 4. Clear any cached user data from UserDefaults
            clearUserCache()

        } catch {
            throw AuthError.unknown("Failed to sign out")
        }
    }

    // MARK: - Update Display Name
    func updateDisplayName(newName: String) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.unknown("No user is currently signed in")
        }

        let capitalizedName = capitalizeName(newName)

        // Update Firestore
        try await db.collection("users").document(userId).updateData([
            "displayName": capitalizedName
        ])

        // Refresh user data to update local state
        await fetchUserData(uid: userId)

    }

    // MARK: - Clear User Cache
    private func clearUserCache() {
        let defaults = UserDefaults.standard

        // List of keys to clear (add any app-specific user data keys here)
        let keysToRemove = [
            "lastLoggedInUserID",
            "userPreferences",
            // Add any other user-specific keys you're storing
        ]

        keysToRemove.forEach { key in
            defaults.removeObject(forKey: key)
        }

        defaults.synchronize()

    }

    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        guard !email.isEmpty else { throw AuthError.invalidEmail }

        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.unknown("No user is currently signed in")
        }


        do {
            // 1. Delete user document from Firestore
            try await db.collection("users").document(user.uid).delete()

            // 2. Delete any user-related subcollections (if any exist)
            // For example: favorites, history, etc.
            // Add here if you have subcollections

            // 3. Delete Firebase Auth account
            try await user.delete()

            // 4. Clear local state
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }

            // 5. Clear user cache
            clearUserCache()


        } catch let error as NSError {

            // Re-throw with more context
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                // Requires recent authentication
                throw AuthError.unknown("This operation requires recent authentication. Please sign out and sign back in, then try again.")
            } else {
                throw AuthError.unknown("Failed to delete account: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Apple Sign In
    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.unknown("Invalid Apple ID Credential")
        }

        guard let nonce = currentNonce else {
            throw AuthError.unknown("Invalid state: A login callback was received, but no login request was sent.")
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.unknown("Unable to fetch identity token")
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.unknown("Unable to serialize token string from data")
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)

        await MainActor.run { isLoading = true }

        do {
            let result = try await auth.signIn(with: credential)

            // Get name from Apple (only available on first sign-in)
            let appleDisplayName = [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            // Get name from onboarding
            let onboardingName = UserDefaults.standard.string(forKey: "userDisplayName") ?? ""

            // Check if user document exists
            let userDoc = try await db.collection("users").document(result.user.uid).getDocument()

            if !userDoc.exists {
                // NEW USER: Create user profile with best available name

                // Priority: Apple name > Onboarding name > Default
                let finalName: String
                if !appleDisplayName.isEmpty {
                    finalName = capitalizeName(appleDisplayName)
                } else if !onboardingName.isEmpty {
                    finalName = capitalizeName(onboardingName)
                } else {
                    finalName = "Apple User"
                }

                let newUser = User(
                    id: result.user.uid,
                    email: result.user.email ?? "No email provided",
                    displayName: finalName,
                    joinDate: Date(),
                    isPremium: false,
                    hasGrantedAccess: false,
                    grantReason: ""
                )

                try await saveUserToFirestore(user: newUser)
            } else {
                // EXISTING USER: Check if we should update their name
                if let existingUser = try? userDoc.data(as: User.self) {
                    let currentName = existingUser.displayName

                    // Update name if it's currently a default name AND we have a better name available
                    let isDefaultName = currentName == "Apple User" || currentName.isEmpty
                    let hasBetterName = !appleDisplayName.isEmpty || !onboardingName.isEmpty

                    if isDefaultName && hasBetterName {
                        let updatedName: String
                        if !appleDisplayName.isEmpty {
                            updatedName = capitalizeName(appleDisplayName)
                        } else {
                            updatedName = capitalizeName(onboardingName)
                        }

                        // Update Firestore with new name
                        try await db.collection("users").document(result.user.uid).updateData([
                            "displayName": updatedName
                        ])
                    } else {
                    }
                }
            }

            await fetchUserData(uid: result.user.uid)
            await MainActor.run { isLoading = false }

        } catch let error as NSError {
            await MainActor.run { isLoading = false }
            throw mapFirebaseError(error)
        }
    }


    // MARK: - Email Continue (Unified Sign In/Sign Up)
    func continueWithEmail(email: String, password: String, displayName: String? = nil) async throws {
        guard !email.isEmpty else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }

        await MainActor.run { isLoading = true }

        // New approach: Try to create account first, then sign in if exists

        do {
            // Try to create account first
            guard let displayName = displayName, !displayName.isEmpty else {
                await MainActor.run { isLoading = false }
                throw AuthError.unknown("Please enter your name to create an account")
            }

            let result = try await auth.createUser(withEmail: email, password: password)

            // Capitalize the name before saving
            let capitalizedName = capitalizeName(displayName)

            let newUser = User(
                id: result.user.uid,
                email: email,
                displayName: capitalizedName,
                joinDate: Date(),
                isPremium: false,
                hasGrantedAccess: false,
                grantReason: ""
            )

            try await saveUserToFirestore(user: newUser)

            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
                self.isLoading = false
            }

        } catch let error as NSError {

            // Check if account already exists
            if let authError = AuthErrorCode(_bridgedNSError: error), authError.code == .emailAlreadyInUse {

                // Account exists, try to sign in
                do {
                    let result = try await auth.signIn(withEmail: email, password: password)
                    await fetchUserData(uid: result.user.uid)
                    await MainActor.run { isLoading = false }

                } catch let signInError as NSError {
                    await MainActor.run { isLoading = false }
                    throw mapFirebaseError(signInError)
                }
            } else {
                // Other error
                await MainActor.run { isLoading = false }
                throw mapFirebaseError(error)
            }
        }
    }

    // MARK: - Helper: Capitalize Name
    private func capitalizeName(_ name: String) -> String {
        // Split by spaces to handle first and last names
        let components = name.components(separatedBy: " ")
        let capitalizedComponents = components.map { component in
            guard !component.isEmpty else { return component }
            return component.prefix(1).uppercased() + component.dropFirst().lowercased()
        }
        return capitalizedComponents.joined(separator: " ")
    }

    // MARK: - Helper: Generate Nonce for Apple Sign In
    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback to UUID-based nonce if SecRandomCopyBytes fails
            // This is extremely rare but we handle it gracefully
            return UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    // MARK: - Private Helpers
    private func fetchUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()

            if document.exists {
                let user = try document.data(as: User.self)
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            }
        } catch {
        }
    }

    private func saveUserToFirestore(user: User) async throws {
        guard let uid = user.id else { return }
        try db.collection("users").document(uid).setData(from: user)
    }

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode(_bridgedNSError: error) else {
            return .unknown(error.localizedDescription)
        }

        switch errorCode.code {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .networkError:
            return .networkError
        case .invalidCredential:
            return .unknown("Invalid credentials. Please check your email and password.")
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
