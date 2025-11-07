//
//  FamilyActivitySelectionStore.swift
//  Dhikr
//
//  Utility to encode/decode and persist FamilyActivitySelection
//  Uses the same storage as AppSelectionModel for compatibility
//

import Foundation
import FamilyControls

class FamilyActivitySelectionStore {
    static let shared = FamilyActivitySelectionStore()

    private let groupDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
    private let selectionKey = "DhikrAppSelection" // Same key as AppSelectionModel

    private init() {}

    /// Save the selection to App Group UserDefaults (compatible with AppSelectionModel)
    func saveSelection(_ selection: FamilyActivitySelection) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(selection)
            groupDefaults?.set(data, forKey: selectionKey)
            groupDefaults?.synchronize()

            print("[FamilyActivityStore] Saved selection - Apps: \(selection.applicationTokens.count), Categories: \(selection.categoryTokens.count), Domains: \(selection.webDomainTokens.count)")
        } catch {
            print("❌ [FamilyActivityStore] Failed to save selection: \(error)")
        }
    }

    /// Load the selection from App Group UserDefaults (compatible with AppSelectionModel)
    func loadSelection() -> FamilyActivitySelection? {
        guard let data = groupDefaults?.data(forKey: selectionKey) else {
            print("[FamilyActivityStore] No saved selection found")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)

            print("[FamilyActivityStore] Loaded selection - Apps: \(selection.applicationTokens.count), Categories: \(selection.categoryTokens.count), Domains: \(selection.webDomainTokens.count)")

            return selection
        } catch {
            print("❌ [FamilyActivityStore] Failed to load selection: \(error)")
            return nil
        }
    }

    /// Clear the saved selection
    func clearSelection() {
        groupDefaults?.removeObject(forKey: selectionKey)
        groupDefaults?.synchronize()
        print("[FamilyActivityStore] Cleared selection")
    }
}
