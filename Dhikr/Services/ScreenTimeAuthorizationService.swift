import Foundation
import FamilyControls

@MainActor
class ScreenTimeAuthorizationService: ObservableObject {
    static let shared = ScreenTimeAuthorizationService()

    @Published var isAuthorized = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var lastError: ScreenTimeError?
    @Published var showErrorAlert = false

    enum AuthorizationStatus {
        case notDetermined
        case denied
        case approved
    }

    enum ScreenTimeError: LocalizedError {
        case restricted
        case unavailable
        case cancelled
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .restricted:
                return "Screen Time is restricted on this device. This may be due to parental controls or device management settings."
            case .unavailable:
                return "Screen Time features are not available on this device."
            case .cancelled:
                return "Screen Time authorization was cancelled."
            case .unknown(let message):
                return "Screen Time authorization failed: \(message)"
            }
        }

        var recoverySuggestion: String {
            switch self {
            case .restricted:
                return "Check your device's Screen Time settings or contact your device administrator."
            case .unavailable:
                return "This feature requires Screen Time to be available on your device."
            case .cancelled:
                return "You can try again or skip this step and enable it later in Settings."
            case .unknown:
                return "Please try again or skip this step and enable it later in Settings."
            }
        }
    }

    private init() {
        updateAuthorizationStatus()
    }

    /// Request Screen Time authorization from the user
    /// Returns true if successful, false otherwise
    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        updateAuthorizationStatus()
    }

    /// Request Screen Time authorization with error handling
    /// Returns true if successful, sets lastError and returns false on failure
    func requestAuthorizationWithErrorHandling() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            updateAuthorizationStatus()
            lastError = nil
            return isAuthorized
        } catch {
            updateAuthorizationStatus()

            // Parse the error
            let errorMessage = error.localizedDescription.lowercased()

            if errorMessage.contains("restrict") || errorMessage.contains("not allowed") {
                lastError = .restricted
            } else if errorMessage.contains("unavailable") || errorMessage.contains("not available") {
                lastError = .unavailable
            } else if errorMessage.contains("cancel") {
                lastError = .cancelled
            } else {
                lastError = .unknown(error.localizedDescription)
            }

            // Only show alert for actual errors, not cancellation
            if case .cancelled = lastError {
                // User cancelled - don't show alert
            } else {
                showErrorAlert = true
            }

            return false
        }
    }

    /// Check and update the current authorization status
    func updateAuthorizationStatus() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
            isAuthorized = false
        case .denied:
            authorizationStatus = .denied
            isAuthorized = false
        case .approved:
            authorizationStatus = .approved
            isAuthorized = true
        @unknown default:
            authorizationStatus = .notDetermined
            isAuthorized = false
        }
    }

    /// Request authorization if not already approved (with error handling)
    func requestAuthorizationIfNeeded() async throws {
        updateAuthorizationStatus()

        if authorizationStatus != .approved {
            try await requestAuthorization()
        }
    }

    /// Request authorization if not already approved (with error handling, returns success)
    func requestAuthorizationIfNeededWithErrorHandling() async -> Bool {
        updateAuthorizationStatus()

        if authorizationStatus == .approved {
            return true
        }

        return await requestAuthorizationWithErrorHandling()
    }

    /// Clear the error state
    func clearError() {
        lastError = nil
        showErrorAlert = false
    }
}
