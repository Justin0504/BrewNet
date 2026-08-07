import SwiftUI
import UIKit

// MARK: - Brew Design Tokens(2026-08 设计系统)
//
// 全 app 的单一视觉事实源。语义命名 + 深浅色自适应。
// 使用:Brew.brand / Brew.bg / Brew.surface / Brew.gold …
// 字阶:Brew.Font.title;间距:Brew.Space.md;圆角:Brew.Radius.md
// 迁移策略:新代码一律用 tokens;旧屏(表单/滑卡系)渐进替换。
// 底部保留旧 BrewTheme struct(46 处遗留引用),其成员已改指向新 tokens。

enum Brew {

    // MARK: 色彩(light ↔ dark)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// 品牌主色:文字/图标/描边(深咖 ↔ 拿铁)
    static let brand = adaptive(
        light: UIColor(red: 0.40, green: 0.20, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.85, green: 0.68, blue: 0.50, alpha: 1)
    )

    /// 品牌填充色:实心按钮/用户气泡(白字在其上)
    static let brandFill = adaptive(
        light: UIColor(red: 0.40, green: 0.20, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.52, green: 0.33, blue: 0.18, alpha: 1)
    )

    /// 页面背景(米色 ↔ 暖黑)
    static let bg = adaptive(
        light: UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)
    )

    /// 卡片/气泡表面(白 ↔ 暖深灰)
    static let surface = adaptive(
        light: UIColor.white,
        dark: UIColor(red: 0.17, green: 0.155, blue: 0.14, alpha: 1)
    )

    /// 表面上的浅一层(草稿框内底等)
    static let surfaceRaised = adaptive(
        light: UIColor(red: 0.99, green: 0.985, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.20, blue: 0.185, alpha: 1)
    )

    /// 主文字 / 次要文字(系统自适应)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    /// Weekly Brew 金
    static let gold = adaptive(
        light: UIColor(red: 0.85, green: 0.60, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 1)
    )
    static let goldDeep = adaptive(
        light: UIColor(red: 0.65, green: 0.42, blue: 0.12, alpha: 1),
        dark: UIColor(red: 0.80, green: 0.58, blue: 0.25, alpha: 1)
    )
    static let goldSoftBg = adaptive(
        light: UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.24, blue: 0.12, alpha: 1)
    )

    /// 白字实心按钮专用(双模式固定深色,保证对比度)
    static let goldFill = Color(red: 0.85, green: 0.60, blue: 0.10)
    static let goldFillDeep = Color(red: 0.62, green: 0.40, blue: 0.11)
    static let tealFill = Color(red: 0.10, green: 0.48, blue: 0.43)

    /// Handshake teal
    static let teal = adaptive(
        light: UIColor(red: 0.10, green: 0.50, blue: 0.45, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.72, blue: 0.65, alpha: 1)
    )

    /// 共同点 chip 绿
    static let chipGreenText = adaptive(
        light: UIColor(red: 0.15, green: 0.45, blue: 0.25, alpha: 1),
        dark: UIColor(red: 0.55, green: 0.85, blue: 0.62, alpha: 1)
    )
    static let chipGreenBg = adaptive(
        light: UIColor(red: 0.88, green: 0.96, blue: 0.90, alpha: 1),
        dark: UIColor(red: 0.12, green: 0.25, blue: 0.15, alpha: 1)
    )

    // MARK: 字阶

    enum Font {
        static let display = SwiftUI.Font.system(size: 32, weight: .bold)
        static let title = SwiftUI.Font.system(size: 20, weight: .bold)
        static let headline = SwiftUI.Font.system(size: 16, weight: .bold)
        static let body = SwiftUI.Font.system(size: 15)
        static let bodyMedium = SwiftUI.Font.system(size: 14, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 12)
        static let captionBold = SwiftUI.Font.system(size: 12, weight: .bold)
        static let micro = SwiftUI.Font.system(size: 10, weight: .semibold)
    }

    // MARK: 间距 & 圆角

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
    }
}

// MARK: - Legacy BrewTheme(兼容层:46 处旧引用,成员已指向新 tokens)

struct BrewTheme {
    static let primaryBrown = Brew.brand
    static let secondaryBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    static let accentColor = Color(red: 0.85, green: 0.6, blue: 0.4)
    static let background = Brew.bg

    static func gradientPrimary() -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [primaryBrown, secondaryBrown]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
