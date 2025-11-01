import SwiftUI

struct BrewTheme {
    // Core palette
    static let primaryBrown = Color(red: 0.40, green: 0.20, blue: 0.10)
    static let secondaryBrown = Color(red: 0.60, green: 0.40, blue: 0.20)
    static let background = Color(red: 0.98, green: 0.97, blue: 0.95) // off-white
    static let backgroundCard = Color.white
    static let accentColor = Color(red: 1.0, green: 0.5, blue: 0.0) // Orange accent
    
    // Helpers
    static func gradientPrimary() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [secondaryBrown, primaryBrown.opacity(0.9)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
