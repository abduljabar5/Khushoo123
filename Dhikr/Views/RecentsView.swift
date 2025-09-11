import SwiftUI

struct RecentsView: View {
    @ObservedObject private var recentsManager = RecentsManager.shared
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if recentsManager.recentItems.isEmpty {
                    Text("No recent tracks")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List {
                        ForEach(recentsManager.recentItems) { item in
                            Button(action: {
                                audioPlayerService.load(surah: item.surah, reciter: item.reciter)
                                dismiss()
                            }) {
                                RecentItemRow(item: item)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Recently Played")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct RecentItemRow: View {
    let item: RecentItem
    
    // Update relative time once per minute instead of constantly
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.surah.englishName)
                    .font(.headline)
                Text(item.reciter.englishName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(item.playedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
                .id(currentTime) // Force refresh when currentTime updates
        }
        .padding(.vertical, 8)
        .onReceive(timer) { _ in
            currentTime = Date() // Update once per minute
        }
    }
}

struct RecentsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentsView()
            .environmentObject(AudioPlayerService.shared)
    }
} 