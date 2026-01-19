import SwiftUI
import CoreLocation
import Combine

// MARK: - Compass Manager
class CompassManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var qiblaDirection: Double = 0
    @Published var locationAuthorized = false
    @Published var userLocation: CLLocation?
    @Published var distance: Double = 0
    @Published var cityName: String = "Loading..."
    @Published var isRefreshing = false
    @Published var canRefresh = true

    private let locationManager = CLLocationManager()
    private var refreshCooldownTimer: Timer?

    // Kaaba coordinates
    private let kaabaLatitude = 21.4225
    private let kaabaLongitude = 39.826206

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }

        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationAuthorized = true
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            locationAuthorized = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        calculateQiblaDirection(from: location)
        calculateDistance(from: location)
        fetchCityName(from: location)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorizationStatus()
    }

    private func calculateQiblaDirection(from location: CLLocation) {
        let userLat = location.coordinate.latitude * .pi / 180
        let userLon = location.coordinate.longitude * .pi / 180
        let kaabaLat = kaabaLatitude * .pi / 180
        let kaabaLon = kaabaLongitude * .pi / 180

        let dLon = kaabaLon - userLon

        let y = sin(dLon) * cos(kaabaLat)
        let x = cos(userLat) * sin(kaabaLat) - sin(userLat) * cos(kaabaLat) * cos(dLon)

        var bearing = atan2(y, x)
        bearing = bearing * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        qiblaDirection = bearing
    }

    private func calculateDistance(from location: CLLocation) {
        let kaabaLocation = CLLocation(latitude: kaabaLatitude, longitude: kaabaLongitude)
        distance = location.distance(from: kaabaLocation) / 1000 // Convert to km
    }

    private func fetchCityName(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                DispatchQueue.main.async {
                    self?.isRefreshing = false
                }
                return
            }
            DispatchQueue.main.async {
                self?.cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                self?.isRefreshing = false
            }
        }
    }

    func refreshLocation() {
        guard canRefresh, locationAuthorized else { return }

        isRefreshing = true
        canRefresh = false
        cityName = "Updating..."

        // Request new location
        locationManager.requestLocation()

        // Start cooldown timer
        refreshCooldownTimer?.invalidate()
        refreshCooldownTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.canRefresh = true
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRefreshing = false
        }
    }
}

// MARK: - Sacred Minimalism Colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

// MARK: - Compass View (Trigger Button)
struct CompassView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showingCompass = false

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: {
            showingCompass = true
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cardBackground)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(sacredGold.opacity(0.4), lineWidth: 1)
                        )

                    Image(systemName: "location.north.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(sacredGold)
                }

                Text("Qibla")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.theme.primaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCompass) {
            QiblaCompassModal()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Qibla Compass Modal (Sacred Minimalism)
struct QiblaCompassModal: View {
    @StateObject private var compassManager = CompassManager()
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var pulseAnimation = false
    @State private var lastAlignedState = false
    @State private var lastProximityZone: Int = 0
    @State private var hapticTimer: Timer?

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    private var relativeQiblaDirection: Double {
        compassManager.qiblaDirection - compassManager.heading
    }

    private var isAligned: Bool {
        let diff = abs(relativeQiblaDirection)
        return diff < 5 || diff > 355
    }

    private var proximityZone: Int {
        let diff = abs(relativeQiblaDirection)
        if diff < 5 || diff > 355 {
            return 4 // Perfect alignment
        } else if diff < 10 || diff > 350 {
            return 3 // Very close
        } else if diff < 20 || diff > 340 {
            return 2 // Close
        } else if diff < 30 || diff > 330 {
            return 1 // Getting close
        } else {
            return 0 // Not close
        }
    }

    var body: some View {
        ZStack {
            pageBackground.ignoresSafeArea()

            // Subtle stars for dark mode
            if themeManager.effectiveTheme == .dark {
                starsBackground
            }

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 50)
                    .padding(.horizontal, 24)

                Spacer()

                // Main Compass Area
                mainCompassView
                    .padding(.vertical, 40)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)

                Spacer()

                // Bottom Info Cards
                bottomInfoView
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: proximityZone) { oldZone, newZone in
            if newZone > 0 && newZone != oldZone {
                triggerHaptic(for: newZone)
            }

            hapticTimer?.invalidate()
            hapticTimer = nil

            if newZone > 0 {
                let interval = hapticInterval(for: newZone)
                hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    triggerHaptic(for: newZone)
                }
            }

            lastProximityZone = newZone
        }
        .onChange(of: isAligned) { oldValue, newValue in
            lastAlignedState = newValue
        }
        .onDisappear {
            hapticTimer?.invalidate()
            hapticTimer = nil
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    withAnimation {
                        dismiss()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(cardBackground)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(subtleText)
                    }
                }

                Spacer()
            }

            VStack(spacing: 8) {
                Text("QIBLA")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(3)
                    .foregroundColor(subtleText)

                Text("Find Direction")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.theme.primaryText)
            }

            if compassManager.locationAuthorized {
                Button(action: {
                    if compassManager.canRefresh {
                        compassManager.refreshLocation()
                        HapticManager.shared.impact(.light)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))

                        Text(compassManager.cityName)
                            .font(.system(size: 13))

                        if !compassManager.canRefresh && !compassManager.isRefreshing {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(compassManager.canRefresh ? sacredGold : subtleText)
                }
                .disabled(!compassManager.canRefresh)
            }
        }
    }

    // MARK: - Main Compass View
    private var mainCompassView: some View {
        ZStack {
            // Outer Glow Ring
            Circle()
                .stroke(
                    isAligned ? softGreen.opacity(0.3) : sacredGold.opacity(0.2),
                    lineWidth: 30
                )
                .frame(width: 300, height: 300)
                .blur(radius: 15)
                .opacity(pulseAnimation ? 0.5 : 0.2)

            // Rotating Compass Ring
            compassRingView
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(-compassManager.heading))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

            // Center Circle
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle()
                            .stroke(isAligned ? softGreen.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    )

                // Qibla Arrow
                qiblaArrowView
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(relativeQiblaDirection))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

                // Center Dot
                Circle()
                    .fill(isAligned ? softGreen : sacredGold)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - Compass Ring with Markers
    private var compassRingView: some View {
        ZStack {
            // Degree Markers
            ForEach(0..<72) { index in
                Rectangle()
                    .fill(index % 6 == 0 ? themeManager.theme.primaryText.opacity(0.5) : themeManager.theme.primaryText.opacity(0.2))
                    .frame(
                        width: index % 6 == 0 ? 2 : 1,
                        height: index % 6 == 0 ? 16 : 8
                    )
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            // Cardinal Directions
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(direction == "N" ? softGreen : subtleText)
                    .offset(y: -165)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
            }
        }
    }

    // MARK: - Qibla Arrow
    private var qiblaArrowView: some View {
        VStack(spacing: 0) {
            // Arrow Head
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 32))
                .foregroundColor(isAligned ? softGreen : sacredGold)

            // Arrow Body
            RoundedRectangle(cornerRadius: 2)
                .fill(isAligned ? softGreen.opacity(0.7) : sacredGold.opacity(0.7))
                .frame(width: 4, height: 50)

            Spacer()
        }
        .frame(height: 200)
    }

    // MARK: - Bottom Info View
    private var bottomInfoView: some View {
        VStack(spacing: 16) {
            if !compassManager.locationAuthorized {
                locationPermissionCard
            } else {
                HStack(spacing: 12) {
                    infoCard(
                        icon: "compass",
                        title: "DIRECTION",
                        value: "\(Int(compassManager.qiblaDirection))°",
                        subtitle: headingToCardinal(compassManager.qiblaDirection)
                    )

                    alignmentCard
                }
            }
        }
    }

    // MARK: - Info Card
    private func infoCard(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(sacredGold)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtleText)

            Text(value)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(themeManager.theme.primaryText)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(subtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Location Permission Card
    private var locationPermissionCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(cardBackground)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: "location.slash")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(subtleText)
            }

            Text("LOCATION REQUIRED")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtleText)

            Text("Enable location services to find the Qibla direction")
                .font(.system(size: 13))
                .foregroundColor(subtleText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Alignment Card
    private var alignmentCard: some View {
        VStack(spacing: 10) {
            Image(systemName: isAligned ? "checkmark.circle" : "circle.dotted")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(isAligned ? softGreen : subtleText)

            Text("ALIGNMENT")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(subtleText)

            Text(isAligned ? "Aligned" : proximityText)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(isAligned ? softGreen : themeManager.theme.primaryText)

            Text(isAligned ? "with Qibla" : "Keep turning")
                .font(.system(size: 11))
                .foregroundColor(subtleText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isAligned ? softGreen.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var proximityText: String {
        switch proximityZone {
        case 3: return "Very Close"
        case 2: return "Close"
        case 1: return "Getting Close"
        default: return "Not Aligned"
        }
    }

    // MARK: - Stars Background
    private var starsBackground: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<40, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat(index * 17 + 23).truncatingRemainder(dividingBy: geometry.size.width),
                            y: CGFloat(index * 29 + 41).truncatingRemainder(dividingBy: geometry.size.height)
                        )
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func triggerHaptic(for zone: Int) {
        switch zone {
        case 4:
            HapticManager.shared.notification(.success)
        case 3:
            HapticManager.shared.impact(.heavy)
        case 2:
            HapticManager.shared.impact(.medium)
        case 1:
            HapticManager.shared.impact(.light)
        default:
            break
        }
    }

    private func hapticInterval(for zone: Int) -> TimeInterval {
        switch zone {
        case 4: return 0.3
        case 3: return 0.5
        case 2: return 0.8
        case 1: return 1.2
        default: return 2.0
        }
    }

    private func rotationForDirection(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func headingToCardinal(_ heading: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5) / 45) % 8
        return directions[index]
    }
}

// MARK: - Compact Qibla Indicator (for prayer time page)
struct CompactQiblaIndicator: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showingCompass = false

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    var body: some View {
        Button(action: {
            showingCompass = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(sacredGold.opacity(0.12))
                        .frame(width: 50, height: 50)

                    Image(systemName: "location.north.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(sacredGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Find Qibla Direction")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text("Open compass to locate Mecca")
                        .font(.system(size: 13))
                        .foregroundColor(subtleText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(subtleText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingCompass) {
            QiblaCompassModal()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Preview
struct CompassView_Previews: PreviewProvider {
    static var previews: some View {
        CompassView()
    }
}
