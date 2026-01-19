import SwiftUI

struct DhikrGoalsView: View {
    @EnvironmentObject var dhikrService: DhikrService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var editingGoal: DhikrType?

    // Sacred colors
    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var softGreen: Color {
        Color(red: 0.55, green: 0.68, blue: 0.55)
    }

    private var forgivenessPurple: Color {
        Color(red: 0.55, green: 0.45, blue: 0.65)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Set a daily goal for each dhikr")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                // Goals
                VStack(spacing: 12) {
                    SacredGoalRow(
                        type: .astaghfirullah,
                        arabicName: "أَسْتَغْفِرُ ٱللَّٰهَ",
                        goal: dhikrService.goal.astaghfirullah,
                        accentColor: forgivenessPurple
                    ) {
                        editingGoal = .astaghfirullah
                    }

                    SacredGoalRow(
                        type: .alhamdulillah,
                        arabicName: "ٱلْحَمْدُ لِلَّٰهِ",
                        goal: dhikrService.goal.alhamdulillah,
                        accentColor: softGreen
                    ) {
                        editingGoal = .alhamdulillah
                    }

                    SacredGoalRow(
                        type: .subhanAllah,
                        arabicName: "سُبْحَانَ ٱللَّٰهِ",
                        goal: dhikrService.goal.subhanAllah,
                        accentColor: sacredGold
                    ) {
                        editingGoal = .subhanAllah
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("Dhikr Goals")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingGoal) { goalType in
            SacredEditGoalView(goalType: goalType, dhikrService: dhikrService)
        }
    }
}

// MARK: - Sacred Goal Row
struct SacredGoalRow: View {
    let type: DhikrType
    let arabicName: String
    let goal: Int
    let accentColor: Color
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "target")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(accentColor)
                    )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(arabicName)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text(type.rawValue)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }

                Spacer()

                // Goal value
                HStack(spacing: 8) {
                    Text("\(goal)")
                        .font(.system(size: 20, weight: .ultraLight))
                        .foregroundColor(accentColor)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(accentColor.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sacred Edit Goal View
struct SacredEditGoalView: View {
    @Environment(\.dismiss) var dismiss
    let goalType: DhikrType
    @ObservedObject var dhikrService: DhikrService
    @StateObject private var themeManager = ThemeManager.shared

    @State private var newGoal: String = ""

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var pageBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.08, green: 0.09, blue: 0.11)
            : Color(red: 0.96, green: 0.95, blue: 0.93)
    }

    private var cardBackground: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.15)
            : Color.white
    }

    private var arabicName: String {
        switch goalType {
        case .astaghfirullah: return "أَسْتَغْفِرُ ٱللَّٰهَ"
        case .alhamdulillah: return "ٱلْحَمْدُ لِلَّٰهِ"
        case .subhanAllah: return "سُبْحَانَ ٱللَّٰهِ"
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Text(arabicName)
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .foregroundColor(themeManager.theme.primaryText)

                    Text(goalType.rawValue)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.theme.secondaryText)
                }
                .padding(.top, 20)

                // Input
                VStack(spacing: 12) {
                    Text("DAILY GOAL")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(themeManager.theme.secondaryText)

                    TextField("", text: $newGoal)
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(sacredGold)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(sacredGold.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 40)
                }

                Spacer()
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.theme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveGoal() }
                        .foregroundColor(sacredGold)
                        .fontWeight(.medium)
                        .disabled(newGoal.isEmpty)
                }
            }
            .onAppear {
                self.newGoal = "\(currentGoal)"
            }
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
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
