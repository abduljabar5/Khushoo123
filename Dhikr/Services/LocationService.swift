import Foundation
import CoreLocation

class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        print("📍 [LocationService] Initialized with status: \(authorizationStatus.rawValue)")
    }
    
    func requestLocationPermission() {
        print("📍 [LocationService] Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        print("📍 [LocationService] Requesting a one-time location update...")
        locationManager.requestLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("📍 [LocationService] Authorization status changed to: \(manager.authorizationStatus.rawValue)")
        self.authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            print("📍 [LocationService] Authorized. Requesting location...")
            manager.requestLocation()
        } else {
            print("📍 [LocationService] Not authorized. Status: \(authorizationStatus.rawValue)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.first {
            self.location = newLocation
            print("📍 [LocationService] Successfully updated location: \(newLocation.coordinate)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [LocationService] Failed to get user's location: \(error.localizedDescription)")
    }
} 