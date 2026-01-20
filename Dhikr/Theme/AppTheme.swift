import SwiftUI

// MARK: - Responsive Sizing System
struct ResponsiveSize {
    static let shared = ResponsiveSize()

    // Base reference width (iPhone 14/15 standard)
    private let baseWidth: CGFloat = 393

    var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    var isSmallScreen: Bool {
        screenWidth <= 375
    }

    var isMiniScreen: Bool {
        screenWidth <= 360
    }

    var isLargeScreen: Bool {
        screenWidth >= 414
    }

    // Scale factor relative to base width (clamped to prevent extremes)
    var scaleFactor: CGFloat {
        let factor = screenWidth / baseWidth
        return min(max(factor, 0.85), 1.12)
    }

    // Font scaling (slightly more conservative to maintain readability)
    func fontSize(_ size: CGFloat) -> CGFloat {
        let scaled = size * scaleFactor
        return max(scaled, size * 0.82)
    }

    // Dimension scaling for UI elements
    func dimension(_ size: CGFloat) -> CGFloat {
        size * scaleFactor
    }

    // Padding/spacing scaling
    func spacing(_ size: CGFloat) -> CGFloat {
        let scaled = size * scaleFactor
        return max(scaled, size * 0.78)
    }

    // Icon size scaling
    func iconSize(_ size: CGFloat) -> CGFloat {
        let scaled = size * scaleFactor
        return max(scaled, size * 0.82)
    }

    // Card/Image dimensions (with minimum constraints)
    func cardSize(_ size: CGFloat, minimum: CGFloat? = nil) -> CGFloat {
        let scaled = size * scaleFactor
        if let min = minimum {
            return max(scaled, min)
        }
        return max(scaled, size * 0.78)
    }

    // Horizontal padding that adapts to screen width
    var horizontalPadding: CGFloat {
        if isMiniScreen { return 16 }
        if isSmallScreen { return 18 }
        if isLargeScreen { return 24 }
        return 20
    }

    // Section spacing
    var sectionSpacing: CGFloat {
        if isMiniScreen { return 24 }
        if isSmallScreen { return 28 }
        return 32
    }

    // Corner radius scaling
    func cornerRadius(_ size: CGFloat) -> CGFloat {
        let scaled = size * scaleFactor
        return max(scaled, 8)
    }
}

// Global accessor for convenience
let RS = ResponsiveSize.shared

// View extension for responsive modifiers
extension View {
    func responsiveFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.font(.system(size: RS.fontSize(size), weight: weight, design: design))
    }

    func responsivePadding(_ edges: Edge.Set = .all, _ length: CGFloat) -> some View {
        self.padding(edges, RS.spacing(length))
    }

    func responsiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.frame(
            width: width.map { RS.dimension($0) },
            height: height.map { RS.dimension($0) }
        )
    }
}

enum AppThemeStyle: String, CaseIterable {
    case auto = "Auto"
    case light = "Light"
    case dark = "Dark"

    var displayName: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var isPremium: Bool {
        return false
    }
}


class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppThemeStyle {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppThemeStyle.auto.rawValue
        self.currentTheme = AppThemeStyle(rawValue: savedTheme) ?? .auto
    }

    var theme: AppTheme {
        switch currentTheme {
        case .auto:
            // Detect system color scheme
            let systemScheme = UITraitCollection.current.userInterfaceStyle
            return systemScheme == .dark ? DarkTheme() : LightTheme()
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        }
    }

    // Helper to get the effective theme style (resolves .auto to actual theme)
    var effectiveTheme: AppThemeStyle {
        if currentTheme == .auto {
            let systemScheme = UITraitCollection.current.userInterfaceStyle
            return systemScheme == .dark ? .dark : .light
        }
        return currentTheme
    }
}

protocol AppTheme {
    // Main Colors
    var primaryBackground: Color { get }
    var secondaryBackground: Color { get }
    var tertiaryBackground: Color { get }
    var cardBackground: Color { get }
    
    // Text Colors
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var tertiaryText: Color { get }
    
    // Accent Colors
    var primaryAccent: Color { get }
    var secondaryAccent: Color { get }
    var accentGreen: Color { get }
    var accentGold: Color { get }
    var accentTeal: Color { get }
    
    // Prayer Card
    var prayerGradientStart: Color { get }
    var prayerGradientEnd: Color { get }
    
    // Featured Reciter Card
    var featuredGradientStart: Color { get }
    var featuredGradientEnd: Color { get }
    
    // Effects
    var shadowColor: Color { get }
    var shadowRadius: CGFloat { get }
    var cardCornerRadius: CGFloat { get }
    var hasGlassEffect: Bool { get }
    var glassBlurRadius: CGFloat { get }
    var glassOpacity: Double { get }
}

struct LightTheme: AppTheme {
    // Main Colors
    let primaryBackground = Color(hex: "F8F9FA")
    let secondaryBackground = Color.white
    let tertiaryBackground = Color(hex: "ECECEC")
    let cardBackground = Color.white

    // Text Colors
    let primaryText = Color(hex: "2C3E50")
    let secondaryText = Color(hex: "7F8C8D")
    let tertiaryText = Color(hex: "CECECE")
    
    // Accent Colors
    let primaryAccent = Color(hex: "1A9B8A")
    let secondaryAccent = Color(hex: "D4A574")
    let accentGreen = Color(hex: "27AE60")
    let accentGold = Color(hex: "F39C12")
    let accentTeal = Color(hex: "16A085")
    
    // Prayer Card
    let prayerGradientStart = Color(hex: "1A9B8A")
    let prayerGradientEnd = Color(hex: "15756A")
    
    // Featured Reciter Card
    let featuredGradientStart = Color(hex: "F0E6D2")
    let featuredGradientEnd = Color(hex: "E8D5B7")
    
    // Effects
    let shadowColor = Color.black.opacity(0.08)
    let shadowRadius: CGFloat = 10
    let cardCornerRadius: CGFloat = 16
    let hasGlassEffect = false
    let glassBlurRadius: CGFloat = 0
    let glassOpacity: Double = 1.0
}

struct DarkTheme: AppTheme {
    // Main Colors
    let primaryBackground = Color(hex: "0A1628")
    let secondaryBackground = Color(hex: "0D1A2D")
    let tertiaryBackground = Color(hex: "0B1420")
    let cardBackground = Color(hex: "0D1A2D")

    // Text Colors
    let primaryText = Color.white
    let secondaryText = Color(hex: "B0BEC5")
    let tertiaryText = Color(hex: "78909C")

    // Accent Colors
    let primaryAccent = Color(hex: "00D9FF")
    let secondaryAccent = Color(hex: "FFD700")
    let accentGreen = Color(hex: "00FF88")
    let accentGold = Color(hex: "FFD700")
    let accentTeal = Color(hex: "00CED1")

    // Prayer Card
    let prayerGradientStart = Color(hex: "0F1F35")
    let prayerGradientEnd = Color(hex: "0A1628")

    // Featured Reciter Card
    let featuredGradientStart = Color(hex: "0E1D32")
    let featuredGradientEnd = Color(hex: "0C1624")

    // Effects
    let shadowColor = Color(hex: "FFD700").opacity(0.2)
    let shadowRadius: CGFloat = 15
    let cardCornerRadius: CGFloat = 20
    let hasGlassEffect = false
    let glassBlurRadius: CGFloat = 0
    let glassOpacity: Double = 1.0
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}



extension View {
    func glassCard(theme: AppTheme) -> some View {
        self
            .background(theme.cardBackground)
            .cornerRadius(theme.cardCornerRadius)
            .shadow(color: theme.shadowColor, radius: theme.shadowRadius, x: 0, y: 4)
    }

    func shimmer() -> some View {
        self
            .modifier(ShimmerEffect())
    }
}

struct ShimmerEffect: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
                .clipped()
            )
            .onAppear {
                isAnimating = true
            }
    }
}