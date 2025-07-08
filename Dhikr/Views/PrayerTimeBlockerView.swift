import SwiftUI
import CoreLocationUI

// MARK: - Main View
struct PrayerTimeBlockerView: View {
    @StateObject private var viewModel = PrayerTimeViewModel()
    @State private var isPulsing = false
    @EnvironmentObject var audioPlayerService: AudioPlayerService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AnimatedGradientBackground().ignoresSafeArea()

            // Content Area
        VStack {
            if viewModel.isLoading {
                ProgressView("Fetching Prayer Times...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                } else {
                    HeaderView()
                    
                    // The main card now displays either the current or next prayer
                    if let prayer = viewModel.currentPrayer ?? viewModel.nextPrayer {
                        CurrentPrayerCard(
                            prayer: prayer,
                            timeValue: viewModel.timeValue,
                            displayState: viewModel.displayState,
                            glowColor: viewModel.glowColor,
                            glowOpacity: viewModel.glowOpacity,
                            countdownColor: viewModel.countdownColor,
                            isPulsing: $isPulsing
                        )
                        .shadow(color: viewModel.glowColor.opacity(viewModel.glowOpacity), radius: isPulsing ? 30 : 20)
                        .scaleEffect(isPulsing ? viewModel.glowScale : 1.0)
                    } else {
                         Text("Fetching prayer times...")
                            .font(.headline)
                            .padding()
                    }
                    
                    UpcomingPrayersList(prayers: viewModel.prayerTimes, displayedPrayer: viewModel.currentPrayer ?? viewModel.nextPrayer)
                }
            }
            .padding(.bottom, audioPlayerService.currentSurah != nil ? 90 : 0)
        }
        .foregroundColor(.white)
        .onAppear {
            viewModel.start()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Reusable Components

struct HeaderView: View {
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 4) {
            Text("Prayer Times")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(Self.dateFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
    }
}

struct CurrentPrayerCard: View {
    let prayer: PrayerTime
    let timeValue: TimeInterval
    let displayState: PrayerTimeViewModel.DisplayState
    let glowColor: Color
    let glowOpacity: Double
    let countdownColor: Color
    @Binding var isPulsing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(.black.opacity(0.4))
                .background(
                    Image("mosque-bg")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))

            VStack(alignment: .leading, spacing: 12) {
                Text(prayer.name)
                    .font(.system(size: 40, weight: .bold))
                
                Text(prayer.timeString)
                    .font(.system(size: 28, weight: .semibold))
                
                // Display changes based on the state (countdown vs. time since)
                HStack {
                    if displayState == .withinCurrentPrayer {
                        Text("Time Since:")
                            .font(.system(size: 20, weight: .medium))
                    }
                    Text(timeValue.formattedForCountdown)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(countdownColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.2))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 250)
        .padding()
        .animation(.easeInOut(duration: 1.0), value: glowColor)
        .animation(.easeInOut(duration: 1.5), value: isPulsing)
    }
}

struct UpcomingPrayersList: View {
    let prayers: [PrayerTime]
    let displayedPrayer: PrayerTime?

    var body: some View {
        List {
            if let displayedPrayer = displayedPrayer,
               let startIndex = prayers.firstIndex(where: { $0.id == displayedPrayer.id }) {
                
                let upcoming = prayers.suffix(from: startIndex + 1)
                
                // Separate prayers by day
                let todayPrayers = upcoming.filter { Calendar.current.isDateInToday($0.date) }
                let tomorrowPrayers = upcoming.filter { Calendar.current.isDateInTomorrow($0.date) }

                // Display today's remaining prayers
                ForEach(todayPrayers) { prayer in
                    PrayerRow(prayer: prayer)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                // If there are prayers for tomorrow, show a section header
                if !tomorrowPrayers.isEmpty {
                    Section(header:
                        Text("Tomorrow")
                            .font(.title3)
                .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .textCase(nil) // Prevent automatic uppercasing
                    ) {
                        ForEach(tomorrowPrayers) { prayer in
                            PrayerRow(prayer: prayer)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
    }
}
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
}

struct PrayerRow: View {
    let prayer: PrayerTime

    var body: some View {
        HStack {
            Text(prayer.name)
                .font(.headline)
            Spacer()
            Text(prayer.timeString)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Previews
struct PrayerTimeBlockerView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerTimeBlockerView()
    }
}