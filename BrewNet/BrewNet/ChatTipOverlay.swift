//
//  ChatTipOverlay.swift
//  BrewNet
//
//  Chat AI suggestion tip overlay
//

import SwiftUI

// MARK: - Chat Tip Overlay
struct ChatTipOverlay: View {
    @Binding var isVisible: Bool
    @State private var overlayOpacity: Double = 0
    @State private var showChatInterface = false
    @State private var showMessages = false
    @State private var showAIButton = false
    @State private var aiButtonScale: CGFloat = 1.0
    @State private var showSuggestions = false
    @State private var suggestionOffsets: [CGFloat] = [200, 200, 200]
    @State private var suggestionOpacities: [Double] = [0, 0, 0]
    
    private let themeColor = Color(red: 0.4, green: 0.2, blue: 0.1)
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(overlayOpacity * 0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTip()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 标题和说明
                VStack(spacing: 12) {
                    Text("AI Chat Assistant")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Get conversation suggestions")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 40)
                
                // 模拟聊天界面框架
                if showChatInterface {
                    VStack(spacing: 0) {
                        // 聊天头部
                        HStack(spacing: 12) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.6, green: 0.4, blue: 0.2),
                                            Color(red: 0.4, green: 0.2, blue: 0.1)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alex Johnson")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(themeColor)
                                
                                Text("Product Manager")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeColor.opacity(0.6))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20, corners: [.topLeft, .topRight])
                        
                        // 聊天消息区域
                        VStack(spacing: 0) {
                            if showMessages {
                                VStack(spacing: 12) {
                                    // 对方消息
                                    HStack {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(themeColor)
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            Text("Hey! Great to meet you!")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(themeColor)
                                                .cornerRadius(16)
                                        }
                                        Spacer()
                                    }
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                    
                                    // 你的消息
                                    HStack {
                                        Spacer()
                                        Text("Hi Alex! Nice to connect!")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .cornerRadius(16)
                                    }
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                                .padding()
                            }
                            
                            Spacer()
                            
                            // AI 按钮
                            if showAIButton {
                                HStack {
                                    Spacer()
                                    
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [
                                                            Color.yellow,
                                                            Color.orange
                                                        ]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)
                                                .shadow(color: Color.orange.opacity(0.5), radius: 15, x: 0, y: 8)
                                            
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .scaleEffect(aiButtonScale)
                                        
                                        Text("Tap for AI help")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(themeColor.opacity(0.8))
                                    }
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 16)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // AI 建议
                            if showSuggestions {
                                VStack(spacing: 10) {
                                    ForEach(0..<3) { index in
                                        HStack {
                                            Spacer()
                                            
                                            HStack(spacing: 8) {
                                                Image(systemName: "lightbulb.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.yellow)
                                                
                                                Text(suggestionTexts[index])
                                                    .font(.system(size: 13))
                                                    .foregroundColor(themeColor)
                                                    .lineLimit(2)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                            )
                                            .offset(x: suggestionOffsets[index])
                                            .opacity(suggestionOpacities[index])
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                            
                            // 输入框
                            HStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeColor.opacity(0.4))
                                    
                                    Text("Type a message...")
                                        .font(.system(size: 15))
                                        .foregroundColor(themeColor.opacity(0.3))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color(white: 0.95))
                                .cornerRadius(24)
                                
                                Circle()
                                    .fill(themeColor.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .padding()
                        }
                        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
                        .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
                    }
                    .frame(height: 420)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Spacer()
                        .frame(height: 420)
                }
                
                Spacer()
                
                // "Got it" 按钮
                Button(action: {
                    dismissTip()
                }) {
                    Text("Got it!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                overlayOpacity = 1
            }
            startAnimation()
        }
    }
    
    private let suggestionTexts = [
        "Tell me about your work!",
        "What inspired you to...",
        "I'd love to hear about..."
    ]
    
    private func startAnimation() {
        // 显示聊天界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showChatInterface = true
            }
            
            // 显示消息
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showMessages = true
                }
                
                // 显示 AI 按钮
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        showAIButton = true
                    }
                    
                    // AI 按钮脉冲动画
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        aiButtonScale = 1.15
                    }
                    
                    // 点击 AI 按钮后显示建议
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showAISuggestions()
                    }
                }
            }
        }
    }
    
    private func showAISuggestions() {
        // 隐藏 AI 按钮
        withAnimation(.easeOut(duration: 0.3)) {
            showAIButton = false
        }
        
        // 显示建议
        showSuggestions = true
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    suggestionOffsets[i] = 0
                    suggestionOpacities[i] = 1
                }
            }
        }
        
        // 3秒后重置
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            resetAnimation()
        }
    }
    
    private func resetAnimation() {
        // 重置所有状态
        withAnimation(.easeOut(duration: 0.3)) {
            showSuggestions = false
            suggestionOffsets = [200, 200, 200]
            suggestionOpacities = [0, 0, 0]
        }
        
        // 重新开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                showAIButton = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showAISuggestions()
            }
        }
    }
    
    private func dismissTip() {
        OnboardingManager.shared.markChatTipAsSeen()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            overlayOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
        }
    }
}
