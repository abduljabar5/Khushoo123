//
//  PanicModeService.swift
//  Dhikr
//
//  Powers the Lower Gaze feature: a one-tap, durational app block users invoke
//  when they feel tempted by social media content that slips past Haya Mode's
//  web filter. Strict by design — there is no public method to cancel an
//  active session before the timer expires.
//
//  Uses a NAMED ManagedSettingsStore distinct from the prayer-time store, so
//  Lower Gaze and Focus Mode shields stack without fighting each other.
//

import Foundation
import ManagedSettings
import FamilyControls
import Combine

@available(iOS 15.0, *)
@MainActor
class PanicModeService: ObservableObject {
    static let shared = PanicModeService()

    @Published private(set) var isActive: Bool = false
    @Published private(set) var endTime: Date?
    @Published private(set) var blockedAppCount: Int = 0

    private let store = ManagedSettingsStore(named: ManagedSettingsStore.Name("panic"))
    private let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

    private let endTimeKey = "panicModeEndTime"

    /// Periodic ticker so the banner countdown updates and we auto-clean
    /// once the deadline passes.
    private var tickTimer: Timer?

    private init() {
        restoreIfNeeded()
    }

    // MARK: - Computed

    var timeRemaining: TimeInterval {
        guard let endTime = endTime else { return 0 }
        return max(0, endTime.timeIntervalSince(Date()))
    }

    var formattedTimeRemaining: String {
        let total = Int(timeRemaining)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Lifecycle

    /// Apply shields to PanicAppSelectionModel.shared.selection for `duration`
    /// seconds. Caller should ensure a non-empty selection exists; if empty,
    /// returns false without doing anything.
    @discardableResult
    func start(duration: TimeInterval) -> Bool {
        let selection = PanicAppSelectionModel.shared.selection
        let isEmpty = selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
        guard !isEmpty else { return false }

        let end = Date().addingTimeInterval(duration)
        endTime = end
        isActive = true
        blockedAppCount = selection.applicationTokens.count + selection.categoryTokens.count

        // Apply shields via the dedicated panic store so we don't disturb the
        // prayer-time store's state.
        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
            store.shield.webDomainCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }

        // Persist deadline so a force-quit + relaunch resumes the lock.
        groupDefaults?.set(end.timeIntervalSince1970, forKey: endTimeKey)
        groupDefaults?.synchronize()

        startTicker()
        return true
    }

    /// Called automatically when the deadline is reached. NOT exposed publicly
    /// during an active session — the whole point is "can't stop yourself."
    private func clear() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        store.shield.webDomains = nil

        groupDefaults?.removeObject(forKey: endTimeKey)
        groupDefaults?.synchronize()

        endTime = nil
        isActive = false
        blockedAppCount = 0
        stopTicker()
    }

    /// Restore active session if the app was relaunched while a panic block
    /// was running. If the deadline has already passed, clear cleanly.
    private func restoreIfNeeded() {
        guard let timestamp = groupDefaults?.object(forKey: endTimeKey) as? TimeInterval else {
            return
        }
        let savedEnd = Date(timeIntervalSince1970: timestamp)
        if savedEnd > Date() {
            // Re-apply shields to the saved selection — the named store may have
            // been cleared by iOS between sessions.
            endTime = savedEnd
            isActive = true
            let selection = PanicAppSelectionModel.shared.selection
            blockedAppCount = selection.applicationTokens.count + selection.categoryTokens.count
            if !selection.applicationTokens.isEmpty {
                store.shield.applications = selection.applicationTokens
            }
            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
                store.shield.webDomainCategories = .specific(selection.categoryTokens)
            }
            if !selection.webDomainTokens.isEmpty {
                store.shield.webDomains = selection.webDomainTokens
            }
            startTicker()
        } else {
            clear()
        }
    }

    // MARK: - Ticker

    private func startTicker() {
        stopTicker()
        // 1Hz tick for the banner countdown. Lightweight — single bool publish.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.objectWillChange.send()
                if self.timeRemaining <= 0 {
                    self.clear()
                }
            }
        }
    }

    private func stopTicker() {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}
