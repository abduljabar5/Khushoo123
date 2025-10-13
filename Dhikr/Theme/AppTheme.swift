import SwiftUI

enum AppThemeStyle: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case liquidGlass = "Liquid Glass"
    
    var displayName: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .liquidGlass: return "sparkles"
        }
    }
    
    var isPremium: Bool {
        switch self {
        case .liquidGlass: return false // Temporarily unlocked for testing
        default: return false
        }
    }
}


class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppThemeStyle {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    @Published var selectedWallpaper: String? {
        didSet {
            if let wallpaper = selectedWallpaper {
                UserDefaults.standard.set(wallpaper, forKey: "selectedWallpaper")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedWallpaper")
            }
        }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppThemeStyle.light.rawValue
        self.currentTheme = AppThemeStyle(rawValue: savedTheme) ?? .light
        self.selectedWallpaper = UserDefaults.standard.string(forKey: "selectedWallpaper")
    }

    // Available wallpapers
    static let availableWallpapers = [
        "papers.co-mi29-antelope-canyon-bw-black-mountain-rock-nature-41-iphone-wallpaper.jpg",
        "wp12645728.jpg",
        "31eebcd90bee7f3ca440a1c12cdccae0.jpg"
    ]
    
    var theme: AppTheme {
        switch currentTheme {
        case .light:
            return LightTheme()
        case .dark:
            return DarkTheme()
        case .liquidGlass:
            return LiquidGlassTheme()
        }
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
    let tertiaryBackground = Color(hex: "F0F2F5")
    let cardBackground = Color.white
    
    // Text Colors
    let primaryText = Color(hex: "2C3E50")
    let secondaryText = Color(hex: "7F8C8D")
    let tertiaryText = Color(hex: "95A5A6")
    
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
    let secondaryBackground = Color(hex: "1E3A5F")
    let tertiaryBackground = Color(hex: "162544")
    let cardBackground = Color(hex: "1E3A5F")
    
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
    let prayerGradientStart = Color(hex: "1E3A5F")
    let prayerGradientEnd = Color(hex: "0A1628")

    // Featured Reciter Card
    let featuredGradientStart = Color(hex: "2C5282")
    let featuredGradientEnd = Color(hex: "1E3A5F")
    
    // Effects
    let shadowColor = Color(hex: "FFD700").opacity(0.2)
    let shadowRadius: CGFloat = 15
    let cardCornerRadius: CGFloat = 20
    let hasGlassEffect = false
    let glassBlurRadius: CGFloat = 0
    let glassOpacity: Double = 1.0
}

struct LiquidGlassTheme: AppTheme {
    // Main Colors - Clear for true glass effect
    let primaryBackground = Color.clear
    let secondaryBackground = Color.white.opacity(0.15)
    let tertiaryBackground = Color.white.opacity(0.1)
    let cardBackground = Color.white.opacity(0.15)
    
    // Text Colors - High contrast for readability on glass
    let primaryText = Color(hex: "FFFFFF")
    let secondaryText = Color(hex: "FFFFFF").opacity(0.8)
    let tertiaryText = Color(hex: "FFFFFF").opacity(0.6)
    
    // Accent Colors - Vibrant and glowing
    let primaryAccent = Color(hex: "00E5FF")
    let secondaryAccent = Color(hex: "E91E63")
    let accentGreen = Color(hex: "00E676")
    let accentGold = Color(hex: "FFD700")
    let accentTeal = Color(hex: "1DE9B6")
    
    // Prayer Card - Vibrant gradient for glass
    let prayerGradientStart = Color(hex: "667EEA")
    let prayerGradientEnd = Color(hex: "764BA2")
    
    // Featured Reciter Card - Iridescent gradient
    let featuredGradientStart = Color(hex: "FF6B6B")
    let featuredGradientEnd = Color(hex: "4ECDC4")
    
    // Effects - Authentic glass morphism
    let shadowColor = Color.black.opacity(0.3)
    let shadowRadius: CGFloat = 30
    let cardCornerRadius: CGFloat = 20
    let hasGlassEffect = true
    let glassBlurRadius: CGFloat = 20
    let glassOpacity: Double = 0.2
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

// Enhanced Liquid Glass view modifier - only applies glass when theme is liquid glass
struct LiquidGlassMorphism: ViewModifier {
    let theme: AppTheme
    
    func body(content: Content) -> some View {
        if theme.hasGlassEffect {
            // Only use glass effect for liquid glass theme
            content
                .background(
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.2)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        } else {
            // Solid background for light/dark themes
            content
                .background(theme.cardBackground)
                .cornerRadius(theme.cardCornerRadius)
                .shadow(color: theme.shadowColor, radius: theme.shadowRadius, x: 0, y: 4)
        }
    }
}

// Simple static liquid glass background with optional wallpaper support
struct LiquidGlassBackgroundView: View {
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Default gradient background
            LinearGradient(
                colors: [
                    Color(hex: "667EEA"),  // Deep blue
                    Color(hex: "764BA2"),  // Purple
                    Color(hex: "F093FB"),  // Pink
                    Color(hex: "F5576C")   // Coral
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Load the selected wallpaper or a default one
            if let wallpaperImage = loadWallpaper() {
                Image(uiImage: wallpaperImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.7) // Make it subtle so the glass effect still works
            }
        }
    }

    private func loadWallpaper() -> UIImage? {
        // Use selected wallpaper or pick the first one as default
        let wallpaperName = themeManager.selectedWallpaper ?? ThemeManager.availableWallpapers.first ?? ""

        // Try to load from bundle with wallpapers/ prefix
        if let path = Bundle.main.path(forResource: "wallpapers/\(wallpaperName)", ofType: nil),
           let image = UIImage(contentsOfFile: path) {
            return image
        }

        // Try without wallpapers/ prefix (in case they're at bundle root)
        if let image = UIImage(named: wallpaperName) {
            return image
        }

        // Fallback: try to load from source directory for development
        let currentDirectory = FileManager.default.currentDirectoryPath
        let sourcePath = "\(currentDirectory)/Dhikr/wallpapers/\(wallpaperName)"
        if let image = UIImage(contentsOfFile: sourcePath) {
            return image
        }

        return nil
    }
}


extension View {
    func glassCard(theme: AppTheme) -> some View {
        self
            .modifier(LiquidGlassMorphism(theme: theme))
            .cornerRadius(theme.cardCornerRadius)
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