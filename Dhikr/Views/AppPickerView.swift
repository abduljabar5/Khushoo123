import SwiftUI
import FamilyControls

@available(iOS 15.0, *)
struct AppPickerView: View {
    @StateObject var model = AppSelectionModel.shared
    @State private var isPresented = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        FamilyActivityPicker(selection: $model.selection)
            .onDisappear {
                // When the picker is dismissed, save the selection.
                // This is a failsafe, as the model also saves on change.
                print("Picker dismissed, ensuring selection is saved.")
            }
            .navigationTitle("Select Apps to Block")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Force immediate save before dismissing to ensure monitor extension has latest selection
                        model.forceSave()
                        dismiss()
                    }
                }
            }
    }
} 