import Foundation
import Combine
import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings

@MainActor
class FocusSettingsManager: ObservableObject {
    static let shared = FocusSettingsManager()
    
    // MARK: - Published Settings (Bound to UI)
    @Published var blockingDuration: Double {
        didSet {
            dirtySchedule = true
            dirtyNotifications = true
            subject.send()
        }
    }
    /// Pre-Prayer Focus buffer time in minutes (0, 10, 15, 20)
    /// This starts blocking BEFORE the actual prayer time
    @Published var prePrayerBuffer: Double {
        didSet {
            dirtySchedule = true
            dirtyNotifications = true
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

    /// Haya Mode - blocks adult content when enabled (persists until turned off)
    /// Note: Do not set this directly for disabling - use requestHayaModeDisable() instead
    @Published var hayaMode: Bool {
        didSet {
            dirtyMetadata = true
            if hayaMode {
                // Enabling - apply immediately and clear any pending disable
                hayaModeDisableRequestedAt = nil
                applyHayaModeFilter(true)
                // Track Haya mode enabled
                AnalyticsService.shared.trackHayaModeEnabled()
            }
            // Note: Disabling is handled by completeHayaModeDisable() after 48-hour delay
            subject.send()
        }
    }

    /// Timestamp when user requested to disable Haya Mode (48-hour delay)
    @Published var hayaModeDisableRequestedAt: Date? {
        didSet {
            syncHayaModeDisableRequest()
        }
    }

    /// Whether a disable request is pending (waiting for 48 hours)
    var hayaModeDisablePending: Bool {
        return hayaModeDisableRequestedAt != nil
    }

    /// Time remaining until Haya Mode can be disabled (in seconds)
    var hayaModeTimeUntilDisable: TimeInterval {
        guard let requestedAt = hayaModeDisableRequestedAt else { return 0 }
        let disableTime = requestedAt.addingTimeInterval(48 * 60 * 60) // 48 hours
        return max(0, disableTime.timeIntervalSince(Date()))
    }

    /// Formatted time remaining (e.g., "47h 32m")
    var hayaModeTimeUntilDisableFormatted: String {
        let remaining = hayaModeTimeUntilDisable
        if remaining <= 0 { return "Ready" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Request to disable Haya Mode (starts 48-hour countdown)
    func requestHayaModeDisable() {
        hayaModeDisableRequestedAt = Date()
        print("🛡️ Haya Mode: Disable requested - 48 hour countdown started")
    }

    /// Cancel a pending disable request
    func cancelHayaModeDisableRequest() {
        hayaModeDisableRequestedAt = nil
        print("🛡️ Haya Mode: Disable request cancelled")
    }

    /// Complete the disable if 48 hours have passed
    /// Returns true if disable was completed, false if still waiting
    @discardableResult
    func completeHayaModeDisableIfReady() -> Bool {
        guard hayaModeDisableRequestedAt != nil else { return false }

        if hayaModeTimeUntilDisable <= 0 {
            // 48 hours have passed - actually disable
            hayaModeDisableRequestedAt = nil
            hayaMode = false
            applyHayaModeFilter(false)
            print("🛡️ Haya Mode: 48 hours passed - filter DISABLED")
            return true
        }
        return false
    }

    private func syncHayaModeDisableRequest() {
        let defaults = UserDefaults.standard
        let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

        if let timestamp = hayaModeDisableRequestedAt?.timeIntervalSince1970 {
            defaults.set(timestamp, forKey: "hayaModeDisableRequestedAt")
            groupDefaults?.set(timestamp, forKey: "hayaModeDisableRequestedAt")
        } else {
            defaults.removeObject(forKey: "hayaModeDisableRequestedAt")
            groupDefaults?.removeObject(forKey: "hayaModeDisableRequestedAt")
        }
        groupDefaults?.synchronize()
    }

    /// Apply or remove the adult content filter based on Haya Mode state
    private func applyHayaModeFilter(_ enabled: Bool) {
        let store = ManagedSettingsStore()
        if enabled {
            store.webContent.blockedByFilter = .auto()
            print("🛡️ Haya Mode: Adult content filter ENABLED")
        } else {
            store.webContent.blockedByFilter = nil
            print("🛡️ Haya Mode: Adult content filter DISABLED")
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

        // Pre-prayer buffer (default: 0 = no buffer)
        let initialBuffer = groupDefaults?.double(forKey: "focusPrePrayerBuffer") ?? defaults.double(forKey: "focusPrePrayerBuffer")

        self.blockingDuration = initialDuration
        self.prePrayerBuffer = initialBuffer
        self.selectedFajr = groupDefaults?.bool(forKey: "focusSelectedFajr") ?? defaults.bool(forKey: "focusSelectedFajr")
        self.selectedDhuhr = groupDefaults?.bool(forKey: "focusSelectedDhuhr") ?? defaults.bool(forKey: "focusSelectedDhuhr")
        self.selectedAsr = groupDefaults?.bool(forKey: "focusSelectedAsr") ?? defaults.bool(forKey: "focusSelectedAsr")
        self.selectedMaghrib = groupDefaults?.bool(forKey: "focusSelectedMaghrib") ?? defaults.bool(forKey: "focusSelectedMaghrib")
        self.selectedIsha = groupDefaults?.bool(forKey: "focusSelectedIsha") ?? defaults.bool(forKey: "focusSelectedIsha")

        self.strictMode = groupDefaults?.bool(forKey: "focusStrictMode") ?? defaults.bool(forKey: "focusStrictMode")
        self.prayerRemindersEnabled = groupDefaults?.bool(forKey: "prayerRemindersEnabled") ?? defaults.bool(forKey: "prayerRemindersEnabled")
        self.hayaMode = groupDefaults?.bool(forKey: "focusHayaMode") ?? defaults.bool(forKey: "focusHayaMode")

        // Load pending disable request timestamp
        if let disableTimestamp = groupDefaults?.double(forKey: "hayaModeDisableRequestedAt"), disableTimestamp > 0 {
            self.hayaModeDisableRequestedAt = Date(timeIntervalSince1970: disableTimestamp)
        }

        // Re-apply Haya Mode filter on app launch if it was enabled
        if self.hayaMode {
            applyHayaModeFilter(true)
            // Check if 48 hours have passed while app was closed
            completeHayaModeDisableIfReady()
        }

        // Failsafe: if toggle says ON but the actual filter isn't active, sync toggle to OFF.
        // This catches cases where the filter was cleared in the background (e.g. premium expired)
        // but the UI flag wasn't updated.
        verifyHayaModeConsistency()

        // Check initial app selection state
        refreshAppSelection()

        setupDebouncePipeline()
        setupAppSelectionObserver()
        setupPremiumLostObserver()
        setupPremiumCheckObserver()
    }

    private func setupPremiumLostObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserLostPremium"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.disableHayaModeForLostPremium()
            }
        }
    }

    /// Wait for SubscriptionService to confirm premium status before checking
    private func setupPremiumCheckObserver() {
        guard hayaMode else { return }

        // Observe when SubscriptionService completes its check
        SubscriptionService.shared.$hasCompletedSuccessfulCheck
            .filter { $0 } // Only proceed when check is complete
            .first() // Only need to check once
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAndDisableHayaModeIfNotPremium()
            }
            .store(in: &cancellables)
    }

    /// Check if user lost premium while app was closed (trial expired, subscription lapsed)
    private func checkAndDisableHayaModeIfNotPremium() {
        guard hayaMode else { return }

        // Wait for SubscriptionService to confirm - use its hasPremiumAccess which checks all conditions
        let subscriptionService = SubscriptionService.shared

        // Only check if the service has completed a successful verification
        guard subscriptionService.hasCompletedSuccessfulCheck else {
            print("🛡️ Haya Mode: Waiting for premium status confirmation...")
            return
        }

        if subscriptionService.hasPremiumAccess {
            print("🛡️ Haya Mode: User has premium access, keeping enabled")
            return
        }

        // User is not premium - disable Haya mode
        disableHayaModeForLostPremium()
    }

    /// Disable Haya mode when user loses premium access
    private func disableHayaModeForLostPremium() {
        guard hayaMode else { return }

        print("🛡️ Haya Mode: Disabling due to lost premium access")
        hayaModeDisableRequestedAt = nil
        hayaMode = false
        applyHayaModeFilter(false)
        syncToUserDefaults()
    }

    /// Failsafe: ensure toggle matches actual ManagedSettings filter state.
    /// If the filter was cleared in the background (premium expired, clearAllSettings)
    /// but the toggle flag wasn't updated, sync the toggle to OFF.
    private func verifyHayaModeConsistency() {
        guard hayaMode else { return }

        let store = ManagedSettingsStore()
        let filterActive = store.webContent.blockedByFilter != nil

        if !filterActive {
            print("🛡️ Haya Mode: Toggle ON but filter not active — syncing to OFF")
            hayaModeDisableRequestedAt = nil
            hayaMode = false
            syncToUserDefaults()
        }
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
                let buffer = await self.prePrayerBuffer
                let selected = await self.getSelectedPrayers()

                if forceReschedule {
                    // Convert StoredPrayerTime to PrayerTime
                    let prayerTimes = self.parsePrayerTimes(from: storage)

                    DeviceActivityService.shared.forceCompleteReschedule(
                        prayerTimes: prayerTimes,
                        duration: duration,
                        selectedPrayers: selected,
                        prePrayerBuffer: buffer
                    )
                } else {
                    DeviceActivityService.shared.scheduleRollingWindow(
                        from: storage,
                        duration: duration,
                        selectedPrayers: selected,
                        prePrayerBuffer: buffer
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
        setBoth(prePrayerBuffer, forKey: "focusPrePrayerBuffer")
        setBoth(selectedFajr, forKey: "focusSelectedFajr")
        setBoth(selectedDhuhr, forKey: "focusSelectedDhuhr")
        setBoth(selectedAsr, forKey: "focusSelectedAsr")
        setBoth(selectedMaghrib, forKey: "focusSelectedMaghrib")
        setBoth(selectedIsha, forKey: "focusSelectedIsha")
        setBoth(strictMode, forKey: "focusStrictMode")
        setBoth(prayerRemindersEnabled, forKey: "prayerRemindersEnabled")
        setBoth(hayaMode, forKey: "focusHayaMode")

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

    // MARK: - Initial Scheduling

    /// Ensure blocking is scheduled if all conditions are met
    /// Call this when the Focus tab appears to handle post-onboarding scenarios
    func ensureInitialSchedulingIfNeeded() {
        // Check if we need to schedule (no recent successful schedule)
        guard DeviceActivityService.shared.needsRollingWindowUpdate() else {
            print("✅ [FocusSettings] Rolling window is up to date - no initial scheduling needed")
            return
        }

        // Check if we have apps selected
        guard hasAppsSelected else {
            print("⚠️ [FocusSettings] No apps selected - skipping initial scheduling")
            return
        }

        // Check if we have prayers selected
        let selectedPrayers = getSelectedPrayers()
        guard !selectedPrayers.isEmpty else {
            print("⚠️ [FocusSettings] No prayers selected - skipping initial scheduling")
            return
        }

        // Check if we have prayer times in storage
        guard let storage = prayerTimeService.loadStorage() else {
            print("⚠️ [FocusSettings] No prayer times in storage - skipping initial scheduling")
            return
        }

        print("🚀 [FocusSettings] Triggering initial scheduling (conditions met, no recent schedule)")

        // Schedule the blocking
        let success = DeviceActivityService.shared.scheduleRollingWindow(
            from: storage,
            duration: blockingDuration,
            selectedPrayers: selectedPrayers
        )

        if success {
            print("✅ [FocusSettings] Initial scheduling completed successfully")
        } else {
            print("⚠️ [FocusSettings] Initial scheduling failed")
        }
    }
}
