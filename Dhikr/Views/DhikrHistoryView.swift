import SwiftUI

// Sacred colors
private let sacredGold = Color(red: 0.77, green: 0.65, blue: 0.46)
private let softGreen = Color(red: 0.55, green: 0.68, blue: 0.55)

struct DhikrHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dhikrService: DhikrService
    @StateObject private var themeManager = ThemeManager.shared

    @State private var allStats: [DailyDhikrStats] = []
    @State private var selectedStat: DailyDhikrStats?

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

    private var subtleText: Color {
        themeManager.effectiveTheme == .dark
            ? Color(white: 0.5)
            : Color(white: 0.45)
    }

    var body: some View {
        NavigationView {
            ZStack {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with selected stats
                    SacredStatDetailView(
                        stat: selectedStat,
                        primaryText: themeManager.theme.primaryText,
                        subtleText: subtleText,
                        cardBackground: cardBackground
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)

                    // List of all historical dhikr days
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(allStats, id: \.date) { stat in
                                SacredHistoryRow(
                                    stat: stat,
                                    isSelected: selectedStat?.date == stat.date,
                                    primaryText: themeManager.theme.primaryText,
                                    subtleText: subtleText,
                                    cardBackground: cardBackground
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        self.selectedStat = stat
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Dhikr History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(sacredGold)
                }
            }
            .onAppear {
                self.allStats = dhikrService.getAllDhikrStats()
                if selectedStat == nil {
                    self.selectedStat = self.allStats.first
                }
            }
        }
    }
}

// MARK: - Sacred Stat Detail View (Header)
struct SacredStatDetailView: View {
    let stat: DailyDhikrStats?
    let primaryText: Color
    let subtleText: Color
    let cardBackground: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let stat = stat {
                HStack {
                    Text(stat.isToday ? "TODAY'S SUMMARY" : stat.formattedDate.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundColor(subtleText)

                    Spacer()

                    if stat.total > 0 {
                        Text("\(stat.total)")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(sacredGold)
                        + Text(" total")
                            .font(.system(size: 12))
                            .foregroundColor(subtleText)
                    }
                }

                if stat.total > 0 {
                    VStack(spacing: 10) {
                        SacredDhikrProgressRow(
                            type: .subhanAllah,
                            count: stat.subhanAllah,
                            total: stat.total,
                            primaryText: primaryText,
                            subtleText: subtleText
                        )
                        SacredDhikrProgressRow(
                            type: .alhamdulillah,
                            count: stat.alhamdulillah,
                            total: stat.total,
                            primaryText: primaryText,
                            subtleText: subtleText
                        )
                        SacredDhikrProgressRow(
                            type: .astaghfirullah,
                            count: stat.astaghfirullah,
                            total: stat.total,
                            primaryText: primaryText,
                            subtleText: subtleText
                        )
                    }
                } else {
                    Text("No dhikr recorded on this day.")
                        .font(.system(size: 13))
                        .foregroundColor(subtleText)
                        .frame(height: 60)
                }
            } else {
                Text("Select a day to see details")
                    .font(.system(size: 13))
                    .foregroundColor(subtleText)
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred History Row (List Item)
struct SacredHistoryRow: View {
    let stat: DailyDhikrStats
    let isSelected: Bool
    let primaryText: Color
    let subtleText: Color
    let cardBackground: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.formattedDate)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(primaryText)
                Text("Total: \(stat.total)")
                    .font(.system(size: 13))
                    .foregroundColor(subtleText)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(isSelected ? softGreen : subtleText.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? softGreen.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sacred Dhikr Progress Row
struct SacredDhikrProgressRow: View {
    let type: DhikrType
    let count: Int
    let total: Int
    let primaryText: Color
    let subtleText: Color

    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    private var color: Color {
        switch type {
        case .subhanAllah: return sacredGold
        case .alhamdulillah: return softGreen
        case .astaghfirullah: return Color(red: 0.6, green: 0.55, blue: 0.7)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(type.rawValue)
                    .font(.system(size: 13))
                    .foregroundColor(primaryText)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(subtleText.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

#if DEBUG
struct DhikrHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let service = DhikrService.shared

        DhikrHistoryView()
            .environmentObject(service)
    }
}
#endif
