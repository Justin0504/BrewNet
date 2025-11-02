import SwiftUI

// MARK: - Brew Theme
// Centralized theme for BrewNet app
struct BrewTheme {
    // MARK: - Colors
    static let primaryBrown = Color(red: 0.4, green: 0.2, blue: 0.1)
    static let secondaryBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    static let accentColor = Color(red: 0.85, green: 0.6, blue: 0.4)
    static let background = Color(red: 0.98, green: 0.97, blue: 0.95)
    
    // MARK: - Gradients
    static func gradientPrimary() -> LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [primaryBrown, secondaryBrown]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

