import SwiftUI
import Kingfisher

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

enum LiquidGlassBackground: String, CaseIterable {
    case orbs = "Orbs"
    case coverImage = "Cover Image"
    
    var displayName: String {
        return self.rawValue
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppThemeStyle {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    @Published var liquidGlassBackground: LiquidGlassBackground {
        didSet {
            UserDefaults.standard.set(liquidGlassBackground.rawValue, forKey: "liquidGlassBackground")
        }
    }
    
    @Published var selectedBackgroundImageURL: String? {
        didSet {
            if let url = selectedBackgroundImageURL {
                UserDefaults.standard.set(url, forKey: "selectedBackgroundImageURL")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedBackgroundImageURL")
            }
        }
    }
    
    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppThemeStyle.light.rawValue
        self.currentTheme = AppThemeStyle(rawValue: savedTheme) ?? .light
        
        let savedBackground = UserDefaults.standard.string(forKey: "liquidGlassBackground") ?? LiquidGlassBackground.orbs.rawValue
        self.liquidGlassBackground = LiquidGlassBackground(rawValue: savedBackground) ?? .orbs
        
        self.selectedBackgroundImageURL = UserDefaults.standard.string(forKey: "selectedBackgroundImageURL")
    }
    
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
    
    // Get available background images from cached artwork URLs
    func getAvailableBackgroundImages() -> [String] {
        guard let savedCache = UserDefaults.standard.dictionary(forKey: "artworkURLPersistentCache_Unsplash") as? [String: String] else {
            return []
        }
        return Array(savedCache.values)
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

// Enhanced background for liquid glass theme with customizable options
struct LiquidGlassBackgroundView: View {
    let backgroundType: LiquidGlassBackground
    let backgroundImageURL: String?
    @State private var animateGradient = false
    
    var body: some View {
        ZStack {
            switch backgroundType {
            case .orbs:
                orbsBackground
            case .coverImage:
                if let imageURL = backgroundImageURL, let url = URL(string: imageURL) {
                    coverImageBackground(url: url)
                } else {
                    orbsBackground // Fallback to orbs if no image selected
                }
            }
        }
        .onAppear {
            animateGradient = true
        }
    }
    
    private var orbsBackground: some View {
        ZStack {
            // Multi-layered animated background - teal/cyan gradient matching Prayer card
            LinearGradient(
                colors: [
                    Color(hex: "004D4D"),  // Dark teal
                    Color(hex: "006B6B"),  // Medium teal
                    Color(hex: "008B8B"),  // Dark cyan
                    Color(hex: "00A5A5")   // Lighter teal
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(
                Animation.easeInOut(duration: 8)
                    .repeatForever(autoreverses: true),
                value: animateGradient
            )

            // Floating orbs for depth - matching teal/cyan color palette
            GeometryReader { geometry in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "00CED1").opacity(0.4),  // Dark turquoise
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: animateGradient ? -100 : geometry.size.width - 100,
                        y: animateGradient ? -50 : 300
                    )
                    .blur(radius: 40)
                    .animation(
                        Animation.easeInOut(duration: 10)
                            .repeatForever(autoreverses: true),
                        value: animateGradient
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "20B2AA").opacity(0.3),  // Light sea green
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: animateGradient ? geometry.size.width - 50 : -150,
                        y: animateGradient ? 200 : 50
                    )
                    .blur(radius: 30)
                    .animation(
                        Animation.easeInOut(duration: 12)
                            .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
            }
        }
    }
    
    private func coverImageBackground(url: URL) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Cover image with proper scaling - no blur for crisp appearance
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Subtle floating orbs for extra depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(
                        x: animateGradient ? -50 : geometry.size.width - 150,
                        y: animateGradient ? 100 : 250
                    )
                    .blur(radius: 20)
                    .animation(
                        Animation.easeInOut(duration: 15)
                            .repeatForever(autoreverses: true),
                        value: animateGradient
                    )
            }
        }
        .ignoresSafeArea()
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