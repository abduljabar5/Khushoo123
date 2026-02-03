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
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let previousStatus = self.authorizationStatus
        self.authorizationStatus = manager.authorizationStatus

        // Track permission changes (only when transitioning from notDetermined)
        if previousStatus == .notDetermined {
            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                AnalyticsService.shared.trackLocationGranted()
            } else if authorizationStatus == .denied {
                AnalyticsService.shared.trackLocationDenied()
            }
        }

        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.first {
            self.location = newLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
} 