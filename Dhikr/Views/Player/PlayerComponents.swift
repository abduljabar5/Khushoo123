//
//  PlayerComponents.swift
//  Dhikr
//
//  Extracted shared player components
//

import SwiftUI

// MARK: - Sacred Player Button Style

struct SacredPlayerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Sacred Slider

struct SacredSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let accentColor: Color

    @State private var isDragging = false
    @StateObject private var themeManager = ThemeManager.shared

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let progress = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let clampedProgress = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(warmGray.opacity(0.2))
                    .frame(height: 4)

                Capsule()
                    .fill(accentColor)
                    .frame(width: width * clampedProgress, height: 4)

                Circle()
                    .fill(accentColor)
                    .frame(width: isDragging ? 16 : 10, height: isDragging ? 16 : 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: isDragging ? 2 : 0)
                    )
                    .offset(x: (width * clampedProgress) - (isDragging ? 8 : 5))
                    .animation(.spring(response: 0.2), value: isDragging)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newProgress = gesture.location.x / width
                        let clampedNewProgress = min(max(newProgress, 0), 1)
                        let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * clampedNewProgress
                        value = newValue
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
}

// MARK: - Sacred Sleep Timer Sheet

struct SacredSleepTimerSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @StateObject private var themeManager = ThemeManager.shared

    private var sacredGold: Color {
        Color(red: 0.77, green: 0.65, blue: 0.46)
    }

    private var warmGray: Color {
        themeManager.effectiveTheme == .dark
            ? Color(red: 0.4, green: 0.4, blue: 0.42)
            : Color(red: 0.6, green: 0.58, blue: 0.55)
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
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(sacredGold)

                        Text("SLEEP TIMER")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(2)
                            .foregroundColor(warmGray)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 8) {
                        ForEach([5, 10, 15, 30, 45, 60], id: \.self) { minutes in
                            sleepTimerButton(minutes: minutes)
                        }
                    }
                    .padding(.horizontal, 20)

                    if audioPlayerService.sleepTimeRemaining != nil {
                        Button(action: {
                            audioPlayerService.cancelSleepTimer()
                            isPresented = false
                        }) {
                            Text("Cancel Timer")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 20)
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(sacredGold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func sleepTimerButton(minutes: Int) -> some View {
        let isSelected = isTimerSelected(minutes: minutes)

        return Button(action: {
            audioPlayerService.setSleepTimer(minutes: Double(minutes))
            isPresented = false
        }) {
            HStack {
                Text("\(minutes) minutes")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(themeManager.theme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(sacredGold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? sacredGold.opacity(0.3) : sacredGold.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }

    private func isTimerSelected(minutes: Int) -> Bool {
        guard let remaining = audioPlayerService.sleepTimeRemaining else { return false }
        return Int(remaining / 60) == minutes
    }
}
