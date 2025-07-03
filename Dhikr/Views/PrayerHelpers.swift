import SwiftUI

// MARK: - Animated Background
struct AnimatedGradientBackground: View {
    @State private var startPoint = UnitPoint(x: 0, y: -0.5)
    @State private var endPoint = UnitPoint(x: 1, y: 1.5)
    
    let colors = [
        Color.green.opacity(0.5),
        Color.green.opacity(0.2),
        Color.black
    ]
    
    var body: some View {
        LinearGradient(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
            .blur(radius: 50)
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    startPoint = UnitPoint(x: 1, y: 1)
                    endPoint = UnitPoint(x: 0, y: 0)
                }
            }
    }
}

// MARK: - Helper Extension
extension TimeInterval {
    var formattedForCountdown: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
} 