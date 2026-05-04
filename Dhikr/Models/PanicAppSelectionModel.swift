//
//  PanicAppSelectionModel.swift
//  Dhikr
//
//  Separate FamilyActivitySelection for the Lower Gaze (panic) feature.
//  Kept distinct from AppSelectionModel (used by Focus Mode) so users can
//  configure different apps for the two contexts — prayer-time blocking
//  often targets work-distraction apps, while Lower Gaze targets social
//  feeds where suggestive content slips past the Haya web filter.
//

import Foundation
import FamilyControls
import Combine

@available(iOS 15.0, *)
@MainActor
class PanicAppSelectionModel: ObservableObject {
    @Published var selection = FamilyActivitySelection() {
        didSet {
            saveDebouncedSelection()
        }
    }

    private var saveCancellable: AnyCancellable?

    private let userDefaultsKey = "PanicAppSelection"
    private let userDefaults = UserDefaults(suiteName: "group.fm.mrc.Dhikr")

    static let shared = PanicAppSelectionModel()

    init() {
        loadSelection()
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    private func saveDebouncedSelection() {
        saveCancellable?.cancel()
        saveCancellable = Just(())
            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveSelection() }
    }

    func forceSave() {
        saveCancellable?.cancel()
        saveSelection()
    }

    private func saveSelection() {
        let currentSelection = selection
        let key = userDefaultsKey
        let defaults = userDefaults

        DispatchQueue.global(qos: .utility).async {
            guard let defaults = defaults else { return }
            if let encoded = try? JSONEncoder().encode(currentSelection) {
                defaults.set(encoded, forKey: key)
                defaults.synchronize()
            }
        }
    }

    private func loadSelection() {
        guard let userDefaults = self.userDefaults,
              let savedData = userDefaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: savedData) else {
            return
        }
        saveCancellable?.cancel()
        selection = decoded
    }
}
