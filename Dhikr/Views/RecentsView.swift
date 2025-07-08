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
        }
        .padding(.vertical, 8)
    }
}

struct RecentsView_Previews: PreviewProvider {
    static var previews: some View {
        RecentsView()
            .environmentObject(AudioPlayerService.shared)
    }
} 