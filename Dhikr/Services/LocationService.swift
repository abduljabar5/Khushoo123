import Foundation
import CoreLocation

class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let locationManager = CLLocationManager()
    private let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var manualLocationName: String?

    // Keys for manual location storage
    private let manualLatKey = "manualLocationLatitude"
    private let manualLonKey = "manualLocationLongitude"
    private let manualNameKey = "manualLocationName"

    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        loadManualLocation()
    }

    // MARK: - Effective Location (GPS or Manual)

    /// Returns the effective location - GPS location if available, otherwise manual location
    var effectiveLocation: CLLocation? {
        // Prefer GPS location if we have permission and a location
        if hasLocationPermission, let gpsLocation = location {
            return gpsLocation
        }
        // Fall back to manual location
        return manualLocation
    }

    /// Whether we have any usable location (GPS or manual)
    var hasAnyLocation: Bool {
        return effectiveLocation != nil
    }

    /// Whether GPS location permission is granted
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Whether a manual location has been set
    var hasManualLocation: Bool {
        return manualLocation != nil
    }

    /// The manually set location (if any)
    var manualLocation: CLLocation? {
        guard let lat = groupDefaults?.double(forKey: manualLatKey),
              let lon = groupDefaults?.double(forKey: manualLonKey),
              lat != 0, lon != 0 else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // MARK: - Manual Location Management

    /// Set a manual location (for users who deny GPS permission)
    func setManualLocation(latitude: Double, longitude: Double, name: String) {
        groupDefaults?.set(latitude, forKey: manualLatKey)
        groupDefaults?.set(longitude, forKey: manualLonKey)
        groupDefaults?.set(name, forKey: manualNameKey)
        groupDefaults?.synchronize()

        manualLocationName = name

        // Create a CLLocation for immediate use
        let manualLoc = CLLocation(latitude: latitude, longitude: longitude)

        // If no GPS location, update the location property
        if !hasLocationPermission || location == nil {
            location = manualLoc
        }

        print("📍 [LocationService] Manual location set: \(name) (\(latitude), \(longitude))")
    }

    /// Clear the manual location
    func clearManualLocation() {
        groupDefaults?.removeObject(forKey: manualLatKey)
        groupDefaults?.removeObject(forKey: manualLonKey)
        groupDefaults?.removeObject(forKey: manualNameKey)
        groupDefaults?.synchronize()
        manualLocationName = nil
        print("📍 [LocationService] Manual location cleared")
    }

    /// Load manual location name from storage
    private func loadManualLocation() {
        manualLocationName = groupDefaults?.string(forKey: manualNameKey)

        // If we have a manual location but no GPS permission, set it as current location
        if !hasLocationPermission, let manual = manualLocation {
            location = manual
        }
    }

    // MARK: - GPS Location

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
        print("📍 [LocationService] Location error: \(error.localizedDescription)")
        // If GPS fails but we have manual location, use that
        if let manual = manualLocation {
            self.location = manual
        }
    }
} 