import Foundation
import FamilyControls

@MainActor
class ScreenTimeAuthorizationService: ObservableObject {
    static let shared = ScreenTimeAuthorizationService()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case approved
    }
    
    private init() {
        updateAuthorizationStatus()
    }
    
    /// Request Screen Time authorization from the user
    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        updateAuthorizationStatus()
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
    
    /// Request authorization if not already approved
    func requestAuthorizationIfNeeded() async throws {
        updateAuthorizationStatus()
        
        if authorizationStatus != .approved {
            try await requestAuthorization()
        }
    }
}