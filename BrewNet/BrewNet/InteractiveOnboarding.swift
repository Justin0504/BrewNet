//
//  InteractiveOnboarding.swift
//  BrewNet
//
//  Created for interactive step-by-step onboarding
//

import SwiftUI

// MARK: - Interactive Spotlight Overlay
/// 高亮某个 UI 元素并显示操作指导
struct SpotlightOverlay: View {
    let targetFrame: CGRect
    let message: String
    let arrowDirection: ArrowDirection
    @Binding var isVisible: Bool
    
    enum ArrowDirection {
        case up, down, left, right
    }
    
    @State private var pulseAnimation = false
    @State private var messageAnimation = false
    
    var body: some View {
        if isVisible {
            ZStack {
                // 半透明遮罩 + 挖空高亮区域
                Color.black.opacity(0.75)
                    .mask(
                        GeometryReader { geometry in
                            Path { path in
                                // 填充整个屏幕
                                path.addRect(CGRect(origin: .zero, size: geometry.size))
                                
                                // 挖空高亮区域（圆形或圆角矩形）
                                let highlightPath = Path(roundedRect: targetFrame.insetBy(dx: -8, dy: -8), cornerRadius: 20)
                                path.addPath(highlightPath)
                            }
                            .fill(style: FillStyle(eoFill: true))
                        }
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false) // 允许点击穿透
                
                // 高亮边框动画
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: targetFrame.width + 16, height: targetFrame.height + 16)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .opacity(pulseAnimation ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // 指示箭头 + 提示消息
                VStack(spacing: 16) {
                    if arrowDirection == .down {
                        arrowView
                    }
                    
                    messageBox
                    
                    if arrowDirection == .up {
                        arrowView.rotationEffect(.degrees(180))
                    }
                }
                .position(messagePosition)
                .opacity(messageAnimation ? 1 : 0)
                .offset(y: messageAnimation ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: messageAnimation)
            }
            .onAppear {
                pulseAnimation = true
                messageAnimation = true
            }
        }
    }
    
    private var arrowView: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 24))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private var messageBox: some View {
        Text(message)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var messagePosition: CGPoint {
        switch arrowDirection {
        case .down:
            return CGPoint(x: UIScreen.main.bounds.width / 2, y: targetFrame.minY - 100)
        case .up:
            return CGPoint(x: UIScreen.main.bounds.width / 2, y: targetFrame.maxY + 100)
        case .left, .right:
            return CGPoint(x: UIScreen.main.bounds.width / 2, y: targetFrame.maxY + 80)
        }
    }
}

// MARK: - Animated Swipe Gesture Guide
/// 滑动手势动画指导
struct SwipeGestureGuide: View {
    let targetFrame: CGRect
    @Binding var isVisible: Bool
    var onSwipeCompleted: (() -> Void)?
    
    @State private var handOffset: CGFloat = 0
    @State private var showHand = true
    
    var body: some View {
        if isVisible {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // 手势动画
                VStack(spacing: 40) {
                    Text("Try swiping the card!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    ZStack {
                        // 卡片示意（简化版）
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .frame(width: targetFrame.width * 0.8, height: targetFrame.height * 0.6)
                            .overlay(
                                VStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    Text("Swipe Right →")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                            )
                        
                        // 手势图标
                        if showHand {
                            Image(systemName: "hand.point.up.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                                .offset(x: handOffset)
                        }
                    }
                    .position(x: UIScreen.main.bounds.width / 2, y: targetFrame.midY)
                }
            }
            .onAppear {
                startHandAnimation()
            }
        }
    }
    
    private func startHandAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            handOffset = 150
        }
        
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showHand = false
                isVisible = false
            }
        }
    }
}

// MARK: - Interactive Button Highlight
/// 高亮按钮并引导点击
struct ButtonHighlight: View {
    let targetFrame: CGRect
    let message: String
    @Binding var isVisible: Bool
    
    @State private var pulseAnimation = false
    @State private var glowAnimation = false
    
    var body: some View {
        if isVisible {
            ZStack {
                // 半透明遮罩
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // 发光效果
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: glowAnimation ? 80 : 60
                        )
                    )
                    .frame(width: 160, height: 160)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .opacity(glowAnimation ? 0.3 : 0.6)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowAnimation)
                
                // 圆形高亮边框
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: targetFrame.width + 20, height: targetFrame.height + 20)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // 提示消息
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                        )
                }
                .position(x: UIScreen.main.bounds.width / 2, y: targetFrame.maxY + 120)
            }
            .onAppear {
                pulseAnimation = true
                glowAnimation = true
            }
        }
    }
}

// MARK: - Preview
struct InteractiveOnboarding_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            ButtonHighlight(
                targetFrame: CGRect(x: 100, y: 200, width: 60, height: 60),
                message: "Tap here to start a temporary chat",
                isVisible: .constant(true)
            )
        }
    }
}

