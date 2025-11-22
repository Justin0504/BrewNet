import SwiftUI

// MARK: - 评分徽章组件

struct RatingBadgeView: View {
    let rating: Double
    let size: BadgeSize
    
    enum BadgeSize {
        case small
        case medium
        case large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 14
            case .large: return 16
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
    }
    
    private var ratingColor: Color {
        switch rating {
        case 4.5...5.0: return .green
        case 4.0..<4.5: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case 3.5..<4.0: return .blue
        case 3.0..<3.5: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case 2.5..<3.0: return .orange
        case 2.0..<2.5: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(ratingColor)
            
            Text(String(format: "%.1f", rating))
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundColor(ratingColor)
        }
        .padding(.horizontal, size.padding)
        .padding(.vertical, size.padding - 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ratingColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct RatingBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                RatingBadgeView(rating: 4.8, size: .small)
                RatingBadgeView(rating: 4.5, size: .medium)
                RatingBadgeView(rating: 4.0, size: .large)
            }
            
            HStack(spacing: 20) {
                RatingBadgeView(rating: 3.5, size: .small)
                RatingBadgeView(rating: 3.0, size: .medium)
                RatingBadgeView(rating: 2.5, size: .large)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

