import SwiftUI
import Kingfisher

// MARK: - Quick Action Button (for actions)
struct QuickActionButton: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            QuickActionButtonContent(
                icon: icon,
                label: label,
                value: value,
                theme: theme
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Action Button View (for NavigationLinks)
struct QuickActionButtonView: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme
    
    var body: some View {
        QuickActionButtonContent(
            icon: icon,
            label: label,
            value: value,
            theme: theme
        )
    }
}

// MARK: - Quick Action Button Content (shared)
struct QuickActionButtonContent: View {
    let icon: String
    let label: String
    let value: String
    let theme: AppTheme
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(theme.primaryAccent.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                if theme.hasGlassEffect {
                    if #available(iOS 26, *) {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .glassEffect(.regular, in: Circle())
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(0.2)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        Color.white.opacity(0.3),
                                        lineWidth: 0.5
                                    )
                            )
                    }
                }
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.primaryAccent)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.primaryText)
            
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(theme.secondaryText)
        }
    }
}

// MARK: - Reciter Carousel
struct ReciterCarousel: View {
    let title: String
    let reciters: [Reciter]
    let theme: AppTheme
    let onReciterTap: (Reciter) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryAccent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(reciters) { reciter in
                        ReciterCardModern(
                            reciter: reciter,
                            theme: theme,
                            onTap: { onReciterTap(reciter) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Modern Reciter Card
struct ReciterCardModern: View {
    let reciter: Reciter
    let theme: AppTheme
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    if theme.hasGlassEffect {
                        if #available(iOS 26, *) {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 85, height: 85)
                                .glassEffect(.regular, in: Circle())
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.25)
                                .frame(width: 85, height: 85)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    theme.primaryAccent.opacity(0.5),
                                                    Color.white.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        }
                    } else {
                        Circle()
                            .fill(theme.secondaryBackground)
                            .frame(width: 85, height: 85)
                            .overlay(
                                Circle()
                                    .stroke(theme.primaryAccent.opacity(0.2), lineWidth: 2)
                            )
                    }
                    
                    KFImage(reciter.artworkURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 75, height: 75)
                        .clipShape(Circle())
                }
                .shadow(color: theme.shadowColor, radius: theme.shadowRadius / 2, x: 0, y: 2)
                
                Text(reciter.englishName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 85)
                
                if let country = reciter.country {
                    Text(countryFlag(for: country))
                        .font(.system(size: 14))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func countryFlag(for country: String) -> String {
        let flags: [String: String] = [
            "Saudi Arabia": "🇸🇦",
            "Egypt": "🇪🇬",
            "Kuwait": "🇰🇼",
            "UAE": "🇦🇪",
            "Jordan": "🇯🇴",
            "Yemen": "🇾🇪",
            "Sudan": "🇸🇩",
            "Pakistan": "🇵🇰",
            "India": "🇮🇳",
            "Indonesia": "🇮🇩",
            "Malaysia": "🇲🇾",
            "Turkey": "🇹🇷",
            "Iran": "🇮🇷",
            "Morocco": "🇲🇦",
            "Algeria": "🇩🇿",
            "Tunisia": "🇹🇳"
        ]
        return flags[country] ?? "🌍"
    }
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: AppThemeStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Mini preview of the theme
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .overlay(
                            getPreviewBackground(for: theme)
                        )
                        .frame(height: 120)
                    
                    VStack(spacing: 8) {
                        // Mini prayer card
                        RoundedRectangle(cornerRadius: 6)
                            .overlay(
                                getAccentGradient(for: theme)
                            )
                            .frame(width: 80, height: 20)
                        
                        // Mini cards row
                        HStack(spacing: 4) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(getCardBackground(for: theme))
                                    .frame(width: 20, height: 20)
                            }
                        }
                    }
                    
                    if theme.isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
                
                HStack(spacing: 6) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 14))
                    Text(theme.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(isSelected ? .blue : .primary)
                
                if theme.isPremium {
                    Text("PRO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func getPreviewBackground(for theme: AppThemeStyle) -> some View {
        switch theme {
        case .light:
            Color(hex: "F8F9FA")
        case .dark:
            Color(hex: "0A1628")
        case .liquidGlass:
            LinearGradient(
                colors: [
                    Color(hex: "E0F2FE").opacity(0.8),
                    Color(hex: "E0E7FF").opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    @ViewBuilder
    private func getAccentGradient(for theme: AppThemeStyle) -> some View {
        switch theme {
        case .light:
            LinearGradient(
                colors: [Color(hex: "1A9B8A"), Color(hex: "15756A")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .dark:
            LinearGradient(
                colors: [Color(hex: "00D9FF"), Color(hex: "FFD700")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .liquidGlass:
            LinearGradient(
                colors: [Color(hex: "7C3AED"), Color(hex: "06B6D4")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private func getCardBackground(for theme: AppThemeStyle) -> Color {
        switch theme {
        case .light:
            return Color.white
        case .dark:
            return Color(hex: "1E3A5F")
        case .liquidGlass:
            return Color.white.opacity(0.3)
        }
    }
}

