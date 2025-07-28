import SwiftUI

struct DhikrGoalsView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @State private var editingGoal: DhikrType?
    
    var body: some View {
        Form {
            Section(header: Text("Daily Dhikr Goals"), footer: Text("Set a daily goal for each dhikr to track your progress.")) {
                GoalRow(type: .subhanAllah, goal: dhikrService.goal.subhanAllah) {
                    editingGoal = .subhanAllah
                }
                
                GoalRow(type: .alhamdulillah, goal: dhikrService.goal.alhamdulillah) {
                    editingGoal = .alhamdulillah
                }
                
                GoalRow(type: .astaghfirullah, goal: dhikrService.goal.astaghfirullah) {
                    editingGoal = .astaghfirullah
                }
            }
        }
        .navigationTitle("Dhikr Goals")
        .sheet(item: $editingGoal) { goalType in
            EditGoalView(goalType: goalType, dhikrService: dhikrService)
        }
    }
}

// MARK: - Goal Row
struct GoalRow: View {
    let type: DhikrType
    let goal: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(type.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(goal)")
                    .foregroundColor(.secondary)
                Image(systemName: "pencil")
                    .foregroundColor(.blue)
            }
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Edit Goal View
struct EditGoalView: View {
    @Environment(\.dismiss) var dismiss
    let goalType: DhikrType
    @ObservedObject var dhikrService: DhikrService
    
    @State private var newGoal: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Goal for \(goalType.rawValue)")) {
                    TextField("Enter new goal", text: $newGoal)
                        .keyboardType(.numberPad)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Dismiss keyboard when tapping outside text fields
                hideKeyboard()
            }
            .navigationTitle("Edit Goal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveGoal() }
                        .disabled(newGoal.isEmpty)
                }
            }
            .onAppear {
                self.newGoal = "\(currentGoal)"
            }
        }
    }
    
    private var currentGoal: Int {
        switch goalType {
        case .subhanAllah: return dhikrService.goal.subhanAllah
        case .alhamdulillah: return dhikrService.goal.alhamdulillah
        case .astaghfirullah: return dhikrService.goal.astaghfirullah
        }
    }
    
    private func saveGoal() {
        guard let goalValue = Int(newGoal) else { return }
        
        switch goalType {
        case .subhanAllah: dhikrService.goal.subhanAllah = goalValue
        case .alhamdulillah: dhikrService.goal.alhamdulillah = goalValue
        case .astaghfirullah: dhikrService.goal.astaghfirullah = goalValue
        }
        
        dismiss()
    }
}

extension DhikrType: Identifiable {
    public var id: String { self.rawValue }
}

// MARK: - Helper Functions
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

#if DEBUG
struct DhikrGoalsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DhikrGoalsView()
                .environmentObject(DhikrService.shared)
        }
    }
}
#endif 