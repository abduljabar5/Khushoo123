import Foundation
import Combine
import SwiftUI
import DeviceActivity
import FamilyControls

@MainActor
class FocusSettingsManager: ObservableObject {
    static let shared = FocusSettingsManager()
    
    // MARK: - Published Settings (Bound to UI)
    @Published var blockingDuration: Double {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var selectedFajr: Bool {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var selectedDhuhr: Bool {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var selectedAsr: Bool {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var selectedMaghrib: Bool {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var selectedIsha: Bool {
        didSet { 
            dirtySchedule = true
            subject.send() 
        }
    }
    @Published var strictMode: Bool {
        didSet { 
            dirtyMetadata = true
            subject.send() 
        }
    }
    @Published var prayerRemindersEnabled: Bool {
        didSet {
            dirtyNotifications = true
            subject.send()
        }
    }

    // App selection state (for UI to know if prayers should be disabled)
    @Published var hasAppsSelected: Bool = false

    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<Void, Never>()
    private let prayerTimeService = PrayerTimeService()
    private var appSelectionCancellable: AnyCancellable?

    // Dirty flags to track what changed
    private var dirtySchedule = false
    private var dirtyNotifications = false
    private var dirtyMetadata = false

    // Loading state for UI feedback
    @Published var isUpdating = false
    
    private init() {
        // Load initial values from UserDefaults (standard + group)
        let defaults = UserDefaults.standard
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        
        // Calculate initial values locally
        var initialDuration = groupDefaults?.double(forKey: "focusBlockingDuration") ?? defaults.double(forKey: "focusBlockingDuration")
        if initialDuration == 0 { initialDuration = 15 } // Default
        if initialDuration < 15 { initialDuration = 15 } // iOS minimum requirement

        self.blockingDuration = initialDuration
        self.selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? defaults.bool(forKey: "focusSelectedFajr")
        self.selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? defaults.bool(forKey: "focusSelectedDhuhr")
        self.selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? defaults.bool(forKey: "focusSelectedAsr")
        self.selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? defaults.bool(forKey: "focusSelectedMaghrib")
        self.selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? defaults.bool(forKey: "focusSelectedIsha")
        
        self.strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? defaults.bool(forKey: "focusStrictMode")
        self.prayerRemindersEnabled = groupDefaults?.bool(forKey: "prayerRemindersEnabled") ?? defaults.bool(forKey: "prayerRemindersEnabled")

        // Check initial app selection state
        refreshAppSelection()

        setupDebouncePipeline()
        setupAppSelectionObserver()
    }
    
    private func setupDebouncePipeline() {
        subject
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main) // Wait 1s after last change
            .sink { [weak self] _ in
                self?.performUpdate()
            }
            .store(in: &cancellables)
    }

    private func setupAppSelectionObserver() {
        // Observe changes to app selection
        appSelectionCancellable = AppSelectionModel.shared.$selection
            .sink { [weak self] selection in
                Task { @MainActor [weak self] in
                    await self?.handleAppSelectionChange(selection)
                }
            }
    }

    private func handleAppSelectionChange(_ selection: FamilyActivitySelection) async {
        let hasApps = !selection.applicationTokens.isEmpty ||
                     !selection.categoryTokens.isEmpty ||
                     !selection.webDomainTokens.isEmpty

        hasAppsSelected = hasApps

        // Don't auto-disable prayers - let the UI handle this.
        // The DeviceActivityService will check for apps before scheduling.
        // This prevents accidentally clearing prayer selections during app selection changes.
        if !hasApps {
        }
    }

    func refreshAppSelection() {
        let selection = AppSelectionModel.shared.selection
        let hasApps = !selection.applicationTokens.isEmpty ||
                     !selection.categoryTokens.isEmpty ||
                     !selection.webDomainTokens.isEmpty

        hasAppsSelected = hasApps

    }
    
    // MARK: - Public Methods
    
    /// Called when app selection changes (no debounce needed, immediate update)
    func appSelectionChanged() {
        // Only force reschedule if we are currently blocking to refresh the shield
        if BlockingStateService.shared.isCurrentlyBlocking {
            performUpdate(forceReschedule: true)
        } else {
            // Just sync to UserDefaults so extension picks it up next time
            syncToUserDefaults()
        }
    }
    
    // MARK: - Update Logic
    
    private func performUpdate(forceReschedule: Bool = false) {
        guard !isUpdating else { return }
        isUpdating = true

        // Capture dirty state
        let needsScheduleUpdate = dirtySchedule || forceReschedule
        let needsNotificationUpdate = dirtyNotifications

        // Reset flags
        dirtySchedule = false
        dirtyNotifications = false
        dirtyMetadata = false


        // 1. Sync to UserDefaults (Main + Group) - Always do this first
        syncToUserDefaults()

        // 2. Trigger Background Update
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // Update Schedule only if needed
            if needsScheduleUpdate {
                // Fetch current prayer times from storage
                let storage = self.prayerTimeService.loadStorage()

                guard let storage = storage else {
                    await MainActor.run {
                        self.isUpdating = false
                    }
                    return
                }

                let duration = await self.blockingDuration
                let selected = await self.getSelectedPrayers()

                if forceReschedule {
                    // Convert StoredPrayerTime to PrayerTime
                    let prayerTimes = self.parsePrayerTimes(from: storage)

                    DeviceActivityService.shared.forceCompleteReschedule(
                        prayerTimes: prayerTimes,
                        duration: duration,
                        selectedPrayers: selected
                    )
                } else {
                    DeviceActivityService.shared.scheduleRollingWindow(
                        from: storage,
                        duration: duration,
                        selectedPrayers: selected
                    )
                }
            } else {
            }
            
            // Update Notifications only if needed
            if needsNotificationUpdate {
                if await self.prayerRemindersEnabled {
                    // Schedule pre-prayer notifications
                    let storage = self.prayerTimeService.loadStorage()
                    if let storage = storage {
                        let prayerTimes = self.parsePrayerTimes(from: storage)
                        let selected = await self.getSelectedPrayers()
                        PrayerNotificationService.shared.schedulePrePrayerNotifications(
                            prayerTimes: prayerTimes,
                            selectedPrayers: selected,
                            isEnabled: true,
                            minutesBefore: 5
                        )
                    }
                } else {
                    PrayerNotificationService.shared.clearPrePrayerNotifications()
                }
            }
            
            await MainActor.run {
                self.isUpdating = false
            }
        }
    }
    
    private func syncToUserDefaults() {
        let defaults = UserDefaults.standard
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        
        // Helper to set both
        func setBoth(_ value: Any?, forKey key: String) {
            defaults.set(value, forKey: key)
            groupDefaults?.set(value, forKey: key)
        }
        
        setBoth(blockingDuration, forKey: "focusBlockingDuration")
        setBoth(selectedFajr, forKey: "focusSelectedFajr")
        setBoth(selectedDhuhr, forKey: "focusSelectedDhuhr")
        setBoth(selectedAsr, forKey: "focusSelectedAsr")
        setBoth(selectedMaghrib, forKey: "focusSelectedMaghrib")
        setBoth(selectedIsha, forKey: "focusSelectedIsha")
        setBoth(strictMode, forKey: "focusStrictMode")
        setBoth(prayerRemindersEnabled, forKey: "prayerRemindersEnabled")
        
        groupDefaults?.synchronize()
    }
    
    func getSelectedPrayers() -> Set<String> {
        var selected: Set<String> = []
        if selectedFajr { selected.insert("Fajr") }
        if selectedDhuhr { selected.insert("Dhuhr") }
        if selectedAsr { selected.insert("Asr") }
        if selectedMaghrib { selected.insert("Maghrib") }
        if selectedIsha { selected.insert("Isha") }
        return selected
    }
    
    nonisolated func parsePrayerTimesPublic(from storage: PrayerTimeStorage) -> [PrayerTime] {
        return parsePrayerTimes(from: storage)
    }

    nonisolated private func parsePrayerTimes(from storage: PrayerTimeStorage) -> [PrayerTime] {
        var prayerTimes: [PrayerTime] = []
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        
        // Optimization: Only parse next 3 days to avoid processing 6 months of data
        let now = Date()
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        
        let relevantStoredTimes = storage.prayerTimes.filter { 
            $0.date >= calendar.startOfDay(for: now) && $0.date <= threeDaysLater 
        }
        
        for stored in relevantStoredTimes {
            let timings = [
                ("Fajr", stored.fajr),
                ("Dhuhr", stored.dhuhr),
                ("Asr", stored.asr),
                ("Maghrib", stored.maghrib),
                ("Isha", stored.isha)
            ]
            
            for (name, timeStr) in timings {
                let cleanTime = timeStr.components(separatedBy: " ").first ?? timeStr
                if let timeDate = dateFormatter.date(from: cleanTime),
                   let prayerDate = calendar.date(bySettingHour: calendar.component(.hour, from: timeDate),
                                                minute: calendar.component(.minute, from: timeDate),
                                                second: 0,
                                                of: stored.date) {
                    prayerTimes.append(PrayerTime(name: name, date: prayerDate))
                }
            }
        }
        return prayerTimes.sorted { $0.date < $1.date }
    }
}
