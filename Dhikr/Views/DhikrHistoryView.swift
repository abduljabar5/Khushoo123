import SwiftUI

struct DhikrHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dhikrService: DhikrService
    
    @State private var allStats: [DailyDhikrStats] = []
    @State private var selectedStat: DailyDhikrStats?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with selected stats
                    StatDetailView(stat: selectedStat)
                        .padding(.horizontal)
                        .padding(.vertical, 20)
                        .background(.ultraThinMaterial)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    
                    // List of all historical dhikr days
                    List {
                        ForEach(allStats, id: \.date) { stat in
                            HistoryRow(stat: stat, isSelected: selectedStat?.date == stat.date)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        self.selectedStat = stat
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                }
            }
            .navigationTitle("Dhikr History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
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

// MARK: - Stat Detail View (Header)
struct StatDetailView: View {
    let stat: DailyDhikrStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let stat = stat {
                Text(stat.isToday ? "Today's Summary" : stat.formattedDate)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                if stat.total > 0 {
                    VStack(spacing: 12) {
                        DhikrProgressRow(type: .subhanAllah, count: stat.subhanAllah, total: stat.total)
                        DhikrProgressRow(type: .alhamdulillah, count: stat.alhamdulillah, total: stat.total)
                        DhikrProgressRow(type: .astaghfirullah, count: stat.astaghfirullah, total: stat.total)
                    }
                } else {
                    Text("No dhikr recorded on this day.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(height: 100)
                }
            } else {
                Text("Select a day to see details")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - History Row (List Item)
struct HistoryRow: View {
    let stat: DailyDhikrStats
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.formattedDate)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Total Dhikr: \(stat.total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .green : .secondary.opacity(0.4))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.green.opacity(0.2) : Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.green : Color.gray.opacity(0.2), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(isSelected ? 0.1 : 0.05), radius: 5, y: 3)
    }
}


// MARK: - Dhikr Progress Row
struct DhikrProgressRow: View {
    let type: DhikrType
    let count: Int
    let total: Int
    
    private var percentage: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }
    
    private var color: Color {
        switch type {
        case .subhanAllah: return .blue
        case .alhamdulillah: return .green
        case .astaghfirullah: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(type.rawValue)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(count)")
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
        .font(.subheadline)
    }
}


#if DEBUG
struct DhikrHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let service = DhikrService.shared
        // Add some dummy data for preview
        
        DhikrHistoryView()
            .environmentObject(service)
    }
}
#endif 