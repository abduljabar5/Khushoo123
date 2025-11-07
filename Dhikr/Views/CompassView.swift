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

// MARK: - Compass View (Trigger Button)
struct CompassView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var showingCompass = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Button(action: {
            showingCompass = true
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentGreen, theme.primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: theme.primaryAccent.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "location.north.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("Qibla")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primaryText)
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

// MARK: - Qibla Compass Modal (Aesthetic Design)
struct QiblaCompassModal: View {
    @StateObject private var compassManager = CompassManager()
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showContent = false
    @State private var pulseAnimation = false
    @State private var lastAlignedState = false
    @State private var lastProximityZone: Int = 0
    @State private var hapticTimer: Timer?

    private var theme: AppTheme { themeManager.theme }

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
            // Gradient Background
            LinearGradient(
                colors: [
                    theme.primaryBackground,
                    theme.secondaryBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated Stars Background (only in dark mode or glass effect)
            if themeManager.currentTheme == .dark || theme.hasGlassEffect {
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
                    .scaleEffect(showContent ? 1 : 0.8)

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
            // Trigger immediate haptic when entering a new zone
            if newZone > 0 && newZone != oldZone {
                triggerHaptic(for: newZone)
            }

            // Stop existing timer
            hapticTimer?.invalidate()
            hapticTimer = nil

            // Start repeating haptics based on proximity
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
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        dismiss()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(theme.tertiaryBackground.opacity(0.5))
                            .frame(width: 44, height: 44)

                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                    }
                }

                Spacer()
            }

            Text("Qibla Compass")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.primaryText, theme.secondaryText],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if compassManager.locationAuthorized {
                Button(action: {
                    if compassManager.canRefresh {
                        compassManager.refreshLocation()
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: compassManager.isRefreshing ? "location.fill" : "location.fill")
                            .font(.system(size: 12))

                        Text(compassManager.cityName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))

                        if !compassManager.canRefresh && !compassManager.isRefreshing {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundColor(compassManager.canRefresh ? theme.primaryAccent : theme.secondaryText)
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
                    LinearGradient(
                        colors: isAligned ? [
                            theme.accentGreen.opacity(0.5),
                            theme.primaryAccent.opacity(0.3)
                        ] : [
                            theme.primaryAccent.opacity(0.3),
                            theme.accentGold.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 40
                )
                .frame(width: 300, height: 300)
                .blur(radius: 20)
                .opacity(pulseAnimation ? 0.6 : 0.3)

            // Rotating Compass Ring
            compassRingView
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(-compassManager.heading))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

            // Center Glass Circle
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                theme.tertiaryBackground.opacity(0.3),
                                theme.tertiaryBackground.opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle()
                            .stroke(theme.primaryText.opacity(0.2), lineWidth: 1)
                    )

                // Qibla Arrow
                qiblaArrowView
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(relativeQiblaDirection))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: compassManager.heading)

                // Center Dot
                Circle()
                    .fill(
                        isAligned ?
                        LinearGradient(
                            colors: [theme.accentGreen, theme.primaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [theme.primaryAccent, theme.accentGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 16, height: 16)
                    .shadow(color: theme.primaryAccent.opacity(0.5), radius: 8)
            }
        }
    }

    // MARK: - Compass Ring with Markers
    private var compassRingView: some View {
        ZStack {
            // Degree Markers
            ForEach(0..<72) { index in
                Rectangle()
                    .fill(index % 6 == 0 ? theme.primaryText.opacity(0.6) : theme.primaryText.opacity(0.3))
                    .frame(
                        width: index % 6 == 0 ? 2 : 1,
                        height: index % 6 == 0 ? 20 : 10
                    )
                    .offset(y: -140)
                    .rotationEffect(.degrees(Double(index) * 5))
            }

            // Cardinal Directions (positioned above the markers with spacing)
            ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                Text(direction)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(direction == "N" ? theme.accentGreen : theme.primaryText.opacity(0.7))
                    .shadow(color: direction == "N" ? theme.accentGreen.opacity(0.5) : .clear, radius: 8)
                    .offset(y: -165)
                    .rotationEffect(.degrees(rotationForDirection(direction)))
            }
        }
    }

    // MARK: - Qibla Arrow
    private var qiblaArrowView: some View {
        VStack(spacing: 0) {
            // Arrow Head (Triangle)
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: isAligned ? [
                            theme.accentGreen,
                            theme.primaryAccent
                        ] : [
                            theme.primaryAccent,
                            theme.accentGold
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: theme.primaryAccent.opacity(0.5), radius: 10)

            // Arrow Body
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: isAligned ? [
                            theme.accentGreen.opacity(0.8),
                            theme.primaryAccent.opacity(0.6)
                        ] : [
                            theme.primaryAccent.opacity(0.8),
                            theme.accentGold.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: 60)

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
                        icon: "compass.fill",
                        title: "Direction",
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.primaryAccent, theme.accentGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryText)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.primaryText)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Location Permission Card
    private var locationPermissionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 32))
                .foregroundColor(theme.secondaryText)

            Text("Location Access Required")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(theme.primaryText)

            Text("Enable location services to find the Qibla direction from your current position")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Alignment Card
    private var alignmentCard: some View {
        VStack(spacing: 8) {
            Image(systemName: isAligned ? "checkmark.circle.fill" : "circle.dotted")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: isAligned ? [theme.accentGreen, theme.primaryAccent] : [theme.secondaryText, theme.tertiaryText],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Alignment")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(theme.secondaryText)

            Text(isAligned ? "Aligned" : proximityText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(isAligned ? theme.accentGreen : theme.primaryText)

            Text(isAligned ? "with Qibla" : "Keep turning")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isAligned ? theme.accentGreen.opacity(0.1) : theme.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isAligned ? theme.accentGreen.opacity(0.3) : theme.primaryAccent.opacity(0.2), lineWidth: 1)
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
                ForEach(0..<50, id: \.self) { index in
                    Circle()
                        .fill(theme.primaryText.opacity(Double.random(in: 0.2...0.5)))
                        .frame(width: CGFloat.random(in: 1...3))
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
        case 4: // Perfect alignment - Success notification
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        case 3: // Very close - Heavy impact
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred(intensity: 1.0)

        case 2: // Close - Medium impact
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred(intensity: 0.8)

        case 1: // Getting close - Light impact
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.6)

        default:
            break
        }
    }

    private func hapticInterval(for zone: Int) -> TimeInterval {
        switch zone {
        case 4: // Perfect alignment - Very fast pulse (0.3s)
            return 0.3
        case 3: // Very close - Fast pulse (0.5s)
            return 0.5
        case 2: // Close - Medium pulse (0.8s)
            return 0.8
        case 1: // Getting close - Slow pulse (1.2s)
            return 1.2
        default:
            return 2.0
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

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        Button(action: {
            showingCompass = true
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accentGreen.opacity(0.2), theme.primaryAccent.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.accentGreen, theme.primaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Find Qibla Direction")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primaryText)

                    Text("Open compass to locate Mecca")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(theme.primaryAccent.opacity(0.6))
            }
            .padding(18)
            .background(
                Group {
                    if theme.hasGlassEffect {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                            .shadow(color: theme.shadowColor.opacity(0.3), radius: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.cardBackground)
                            .shadow(color: theme.shadowColor.opacity(0.3), radius: 8)
                    }
                }
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
