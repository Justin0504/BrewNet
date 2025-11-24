//
//  ContextualTip.swift
//  BrewNet
//
//  Created for contextual onboarding tips
//

import SwiftUI

/// 上下文提示组件 - 在用户首次使用某功能时显示
struct ContextualTip: View {
    let message: String
    let icon: String
    @Binding var isVisible: Bool
    var backgroundColor: Color = Color.orange.opacity(0.1)
    var foregroundColor: Color = Color.orange
    
    @State private var isAnimating = false
    
    private let themeColor = Color(red: 0.4, green: 0.2, blue: 0.1)
    
    var body: some View {
        if isVisible {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon with animation
                    ZStack {
                        Circle()
                            .fill(foregroundColor.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0 : 1)
                        
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(foregroundColor)
                    }
                    
                    // Message
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeColor)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 30) // 为关闭按钮留空间
                }
                .padding(14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            backgroundColor,
                            backgroundColor.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(foregroundColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                
                // Close button - 绝对定位在右上角
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.gray.opacity(0.5))
                }
                .padding(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
        }
    }
}

// MARK: - Preset Tip Styles
extension ContextualTip {
    /// Matches 滑动提示
    static func matchesSwipeTip(isVisible: Binding<Bool>) -> some View {
        ContextualTip(
            message: "Swipe right to connect, left to pass. Tap the card to view full profile.",
            icon: "hand.draw.fill",
            isVisible: isVisible,
            backgroundColor: Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.1),
            foregroundColor: Color(red: 0.4, green: 0.2, blue: 0.1)
        )
    }
    
    /// Requests 临时聊天提示
    static func requestsTemporaryChatTip(isVisible: Binding<Bool>) -> some View {
        ContextualTip(
            message: "Tap the message icon to start a temporary chat before deciding. Get to know them first!",
            icon: "message.badge.fill",
            isVisible: isVisible,
            backgroundColor: Color.blue.opacity(0.1),
            foregroundColor: Color.blue
        )
    }
    
    /// Chat AI 建议提示
    static func chatAISuggestionTip(isVisible: Binding<Bool>) -> some View {
        ContextualTip(
            message: "Tap the sparkles icon to get AI-powered conversation suggestions and ice breakers.",
            icon: "sparkles",
            isVisible: isVisible,
            backgroundColor: Color.purple.opacity(0.1),
            foregroundColor: Color.purple
        )
    }
    
    /// Talent Scout 搜索提示
    static func talentScoutTip(isVisible: Binding<Bool>) -> some View {
        ContextualTip(
            message: "Describe the person you want to meet in natural language. For example: 'alumni from Stanford working in product management'.",
            icon: "sparkle.magnifyingglass",
            isVisible: isVisible,
            backgroundColor: Color.orange.opacity(0.1),
            foregroundColor: Color.orange
        )
    }
}

// MARK: - Preview
struct ContextualTip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ContextualTip.matchesSwipeTip(isVisible: .constant(true))
            ContextualTip.requestsTemporaryChatTip(isVisible: .constant(true))
            ContextualTip.chatAISuggestionTip(isVisible: .constant(true))
            ContextualTip.talentScoutTip(isVisible: .constant(true))
        }
        .padding()
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}

