import Foundation
import FamilyControls
import Combine

@available(iOS 15.0, *)
class AppSelectionModel: ObservableObject {
    @Published var selection = FamilyActivitySelection() {
        didSet {
            // Only save if this is a real change, not during initialization
            if hasFinishedLoading {
                saveSelection()
            }
        }
    }
    
    private var hasFinishedLoading = false

    private let userDefaultsKey = "DhikrAppSelection"
    // Use App Group UserDefaults to share data with the extension
    private let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

    init() {
        loadSelection()
    }

    private func saveSelection() {
        // Perform the save operation on a background queue to avoid blocking UI
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            guard let userDefaults = self.userDefaults else {
                print("❌ Could not access UserDefaults for App Group - blocking will not work")
                return
            }
            
            if let encoded = try? encoder.encode(self.selection) {
                userDefaults.set(encoded, forKey: self.userDefaultsKey)
            }
        }
    }

    private func loadSelection() {
        guard let userDefaults = self.userDefaults else {
            hasFinishedLoading = true
            return
        }

        if let savedData = userDefaults.data(forKey: userDefaultsKey) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode(FamilyActivitySelection.self, from: savedData) {
                // Ensure UI updates happen on the main thread
                DispatchQueue.main.async {
                    self.selection = decoded
                    self.hasFinishedLoading = true
                }
                return
            }
        }
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            self.selection = FamilyActivitySelection()
            self.hasFinishedLoading = true
        }
    }

    static let shared = AppSelectionModel()
    
    /// Get the current selection without triggering UI updates - safe for background threads
    static func getCurrentSelection() -> FamilyActivitySelection {
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