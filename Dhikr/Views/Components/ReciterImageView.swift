import SwiftUI
import Kingfisher

// MARK: - Reciter Image View with Background Removal
struct ReciterImageView: View {
    let url: URL?
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        if let url = url {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                // Remove white-ish background using blend mode
                .background(
                    Color.black
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
                .compositingGroup()
                .blendMode(.multiply)
                .background(
                    // Add a subtle gradient background instead
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.3),
                            Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                )
        } else {
            // Placeholder when no image
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(.gray)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Simple Background Removal Modifier
extension View {
    func removeWhiteBackground() -> some View {
        self
            .background(Color.black)
            .compositingGroup()
            .blendMode(.multiply)
    }
}

// MARK: - Alternative Cleaner Version (less aggressive)
struct CleanReciterImageView: View {
    let url: URL?
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 12
    
    var body: some View {
        if let url = url {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                // Apply subtle color correction to reduce white tint
                .colorMultiply(Color(white: 0.95)) // Slightly darken whites
                .saturation(1.1) // Boost colors slightly
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    // Add subtle vignette to blend edges
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                )
        } else {
            // Placeholder
            Image(systemName: "person.circle.fill")
                .font(.system(size: size * 0.8))
                .foregroundColor(.gray)
                .frame(width: size, height: size)
        }
    }
}