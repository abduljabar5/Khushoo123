import Foundation
import FamilyControls
import Combine

@available(iOS 15.0, *)
@MainActor
class AppSelectionModel: ObservableObject {
    @Published var selection = FamilyActivitySelection() {
        didSet {
            // Debounce saves to avoid excessive writes
            saveDebouncedSelection()
        }
    }

    private var saveCancellable: AnyCancellable?

    private let userDefaultsKey = "DhikrAppSelection"
    // Use App Group UserDefaults to share data with the extension
    private let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

    init() {
        loadSelection()
    }

    private func saveDebouncedSelection() {
        // Cancel any pending save
        saveCancellable?.cancel()

        // Schedule new save after 500ms delay
        saveCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSelection()
            }
    }

    /// Force immediate save without debouncing (use when timing is critical)
    func forceSave() {
        // Cancel any pending debounced save
        saveCancellable?.cancel()
        // Save immediately
        saveSelection()
    }

    private func saveSelection() {
        // Capture values to avoid accessing @MainActor properties from background thread
        let currentSelection = selection
        let key = userDefaultsKey
        let defaults = userDefaults

        // Perform the save operation on a background queue to avoid blocking UI
        DispatchQueue.global(qos: .utility).async {
            let encoder = JSONEncoder()
            guard let defaults = defaults else {
                print("❌ Could not access UserDefaults for App Group - blocking will not work")
                return
            }

            if let encoded = try? encoder.encode(currentSelection) {
                defaults.set(encoded, forKey: key)
                defaults.synchronize() // Force immediate write to disk for monitor extension
                print("✅ [AppSelection] Saved \(currentSelection.applicationTokens.count) apps, \(currentSelection.categoryTokens.count) categories to App Group")
            }
        }
    }

    private func loadSelection() {
        guard let userDefaults = self.userDefaults else {
            return
        }

        if let savedData = userDefaults.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(FamilyActivitySelection.self, from: savedData) {
                // Load directly since we're already @MainActor
                // Cancel any pending saves to avoid overwriting what we just loaded
                saveCancellable?.cancel()
                selection = decoded
                return
            }
        }

        // Load empty selection if nothing saved
        saveCancellable?.cancel()
        selection = FamilyActivitySelection()
    }

    static let shared = AppSelectionModel()

    /// Get the current selection without triggering UI updates - safe for background threads
    /// This method is nonisolated so it can be called from DeviceActivityMonitor extension
    nonisolated static func getCurrentSelection() -> FamilyActivitySelection {
        let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")
        let userDefaultsKey = "DhikrAppSelection"

        guard let userDefaults = userDefaults,
              let savedData = userDefaults.data(forKey: userDefaultsKey) else {
            return FamilyActivitySelection()
        }

        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode(FamilyActivitySelection.self, from: savedData) {
            return decoded
        } else {
            return FamilyActivitySelection()
        }
    }
} 