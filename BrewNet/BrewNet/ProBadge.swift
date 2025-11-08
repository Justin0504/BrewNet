import SwiftUI

// MARK: - Pro Badge Component
/// A reusable golden Pro badge to display next to user names
struct ProBadge: View {
    var size: BadgeSize = .medium
    
    enum BadgeSize {
        case small, medium, large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8)
            case .medium: return EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12)
            case .large: return EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
            }
        }
    }
    
    var body: some View {
        Text("Pro")
            .font(.system(size: size.fontSize, weight: .bold))
            .foregroundColor(.white)
            .padding(size.padding)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1.0, green: 0.84, blue: 0.0),  // Gold
                        Color(red: 1.0, green: 0.65, blue: 0.0)   // Darker gold
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(6)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .padding(.leading, 4)
    }
}

// MARK: - Preview
struct ProBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack {
                Text("John Doe")
                    .font(.title2)
                ProBadge(size: .large)
            }
            
            HStack {
                Text("Jane Smith")
                    .font(.headline)
                ProBadge(size: .medium)
            }
            
            HStack {
                Text("Bob Johnson")
                    .font(.subheadline)
                ProBadge(size: .small)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

