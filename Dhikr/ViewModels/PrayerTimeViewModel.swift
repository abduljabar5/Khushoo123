import Foundation
import CoreLocation
import Combine
import SwiftUI

// A model representing a single prayer time, making it easier to work with.
struct PrayerTime: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let date: Date
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@MainActor
class PrayerTimeViewModel: ObservableObject {
    
    // Represents the two main states of the prayer time screen
    enum DisplayState {
        case countingDownToNext
        case withinCurrentPrayer
    }
    
    // MARK: - Published Properties for UI
    @Published var prayerTimes: [PrayerTime] = []
    @Published var nextPrayer: PrayerTime?
    @Published var currentPrayer: PrayerTime?
    @Published var timeValue: TimeInterval = 0 // Can be time *until* or time *since* a prayer
    @Published var displayState: DisplayState = .countingDownToNext
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationAuthorizationStatus: CLAuthorizationStatus

    // Animation-driving properties
    @Published var glowOpacity: Double = 0.0
    @Published var glowScale: CGFloat = 1.0
    @Published var glowColor: Color = .green
    @Published var countdownColor: Color = .white
    
    // MARK: - Private Properties
    private let locationService = LocationService()
    private let prayerTimeService = PrayerTimeService()
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    init() {
        self.locationAuthorizationStatus = locationService.authorizationStatus
        
        // Subscribe to location updates
        locationService.$location
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.fetchAllRequiredPrayerTimes(for: location)
            }
            .store(in: &cancellables)
            
        // Subscribe to authorization status changes
        locationService.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.locationAuthorizationStatus = status
            }
            .store(in: &cancellables)
    }
    
    deinit {
        updateTimer?.invalidate()
    }

    func requestLocationPermission() {
        locationService.requestLocationPermission()
    }
    
    /// Fetches prayer times for today and tomorrow to ensure a continuous list.
    private func fetchAllRequiredPrayerTimes(for location: CLLocation) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Fetch today's and tomorrow's prayer times in parallel for efficiency.
                async let todayTimingsTask = prayerTimeService.fetchPrayerTimes(for: location, on: Date())
                
                let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                async let tomorrowTimingsTask = prayerTimeService.fetchPrayerTimes(for: location, on: tomorrowDate)
                
                // Await both results
                let todayParsed = parse(timings: try await todayTimingsTask, for: Date())
                let tomorrowParsed = parse(timings: try await tomorrowTimingsTask, for: tomorrowDate)
                
                // Combine them into a single chronological list.
                self.prayerTimes = todayParsed + tomorrowParsed
                
                // Start the timer to update the UI every second.
                self.startUpdateTimer()
                
            } catch {
                self.errorMessage = "Failed to fetch prayer times: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updatePrayerState() // Run once immediately to set the initial state
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updatePrayerState()
        }
    }

    private func updatePrayerState() {
        let now = Date()
        
        let lastPrayer = prayerTimes.last { $0.date <= now }
        let upcomingPrayer = prayerTimes.first { $0.date > now }
        self.nextPrayer = upcomingPrayer

        if let last = lastPrayer, now.timeIntervalSince(last.date) < 3600 {
            // STATE: Within the current prayer's active one-hour window.
            self.displayState = .withinCurrentPrayer
            self.currentPrayer = last
            self.timeValue = now.timeIntervalSince(last.date)
            updateWithinPrayerAnimation()
        } else {
            // STATE: Counting down to the next prayer.
            self.displayState = .countingDownToNext
            self.currentPrayer = nil
            
            if let next = upcomingPrayer {
                self.timeValue = next.date.timeIntervalSince(now)
                updateCountdownAnimation()
            } else {
                // This case should now only happen if the full 2-day fetch fails.
                timeValue = 0
            }
        }
    }

    private func updateCountdownAnimation() {
        let remaining = timeValue
        glowColor = .green

        if remaining <= 600 { // Under 10 minutes
            glowOpacity = 0.7
            glowScale = 1.05
        } else if remaining <= 1800 { // Under 30 minutes
            glowOpacity = 0.4
            glowScale = 1.02
        } else { // More than 30 minutes
            glowOpacity = 0.0 // Starts with no glow
            glowScale = 1.0
        }
        countdownColor = .white
    }
    
    private func updateWithinPrayerAnimation() {
        let timeSince = timeValue
        let progress = min(timeSince / 3600, 1.0)
        
        let redValue = min(progress * 2, 1.0)
        let greenValue = 1.0 - (max(progress - 0.5, 0.0) * 2)
        
        glowColor = Color(red: redValue, green: greenValue, blue: 0)
        glowOpacity = 1.0 - (progress * 0.7)
        glowScale = 1.0
        countdownColor = glowColor
    }
    
    private func parse(timings: Timings, for date: Date) -> [PrayerTime] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        let dayOfPrayer = calendar.startOfDay(for: date)
        
        var parsedTimes: [PrayerTime] = []
        let prayerData: [(String, String)] = [
            ("Fajr", timings.Fajr),
            ("Dhuhr", timings.Dhuhr),
            ("Asr", timings.Asr),
            ("Maghrib", timings.Maghrib),
            ("Isha", timings.Isha)
        ]
        
        for (name, timeString) in prayerData {
            if let time = dateFormatter.date(from: timeString),
               let timeComponents = calendar.dateComponents([.hour, .minute], from: time) as DateComponents?,
               let prayerDate = calendar.date(byAdding: timeComponents, to: dayOfPrayer) {
                parsedTimes.append(PrayerTime(name: name, date: prayerDate))
            }
        }
        return parsedTimes.sorted { $0.date < $1.date }
    }
} 