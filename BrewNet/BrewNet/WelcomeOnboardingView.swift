//
//  WelcomeOnboardingView.swift
//  BrewNet
//
//  Created for onboarding new users
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let themeColor = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "cup.and.saucer.fill",
            iconGradient: [Color(red: 0.4, green: 0.2, blue: 0.1), Color(red: 0.5, green: 0.3, blue: 0.15)],
            title: "Welcome to BrewNet",
            subtitle: "Connect with professionals through meaningful coffee chats",
            description: "Build your network one coffee at a time. Find people who share your interests, goals, and passion for growth."
        ),
        OnboardingPage(
            icon: "sparkles",
            iconGradient: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
            title: "Discover Your Matches",
            subtitle: "AI-powered recommendations just for you",
            description: "Swipe through personalized recommendations based on your interests, industry, and networking goals. Swipe right to connect, left to pass.",
            animationType: .swipeCards
        ),
        OnboardingPage(
            icon: "sparkle.magnifyingglass",
            iconGradient: [Color(red: 0.6, green: 0.4, blue: 0.2), Color(red: 0.4, green: 0.2, blue: 0.1)],
            title: "Talent Scout",
            subtitle: "Search by natural language",
            description: "Describe exactly who you want to meet. For example: 'alumni from Stanford working in product management'. Our AI will find the perfect matches.",
            animationType: .talentScout
        ),
        OnboardingPage(
            icon: "message.fill",
            iconGradient: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.2, green: 0.4, blue: 0.8)],
            title: "Chat Before You Connect",
            subtitle: "Try temporary chat first",
            description: "Send a temporary message to break the ice. Chat briefly before deciding to accept the connection. No pressure, just genuine conversation.",
            animationType: .chatBubbles
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconGradient: [Color(red: 0.2, green: 0.7, blue: 0.3), Color(red: 0.15, green: 0.5, blue: 0.25)],
            title: "Meet for Coffee",
            subtitle: "Turn connections into real relationships",
            description: "Once connected, schedule a coffee chat to meet in person. Choose a time and place that works for both of you.",
            animationType: .coffeeSchedule
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.97, blue: 0.95),
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        completeOnboarding()
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeColor.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                
                // Content pages
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
            }
        }
    }
    
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // Previous button (only show if not on first page)
            if currentPage > 0 {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentPage -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Previous")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(themeColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeColor.opacity(0.3), lineWidth: 1.5)
                    )
                }
            }
            
            // Next/Get Started button
            Button(action: {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            }) {
                HStack {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .bold))
                    if currentPage < pages.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeColor,
                            Color(red: 0.5, green: 0.3, blue: 0.15)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
    }
    
    private func completeOnboarding() {
        OnboardingManager.shared.markWelcomeOnboardingAsSeen()
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Onboarding Page Model
struct OnboardingPage {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let subtitle: String
    let description: String
    var animationType: AnimationType = .none
    
    enum AnimationType {
        case none
        case swipeCards
        case talentScout
        case chatBubbles
        case coffeeSchedule
    }
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    private let themeColor = Color(red: 0.4, green: 0.2, blue: 0.1)
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon and Animation
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                page.iconGradient[0].opacity(0.2),
                                page.iconGradient[0].opacity(0.0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                    .opacity(isAnimating ? 1 : 0)
                
                // Animation based on page type
                if page.animationType != .none {
                    animationView(for: page.animationType)
                        .opacity(isAnimating ? 1 : 0)
                } else {
                    // Icon background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white,
                                    Color(red: 0.98, green: 0.97, blue: 0.95)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .scaleEffect(isAnimating ? 1 : 0.8)
                    
                    // Icon
                    Image(systemName: page.icon)
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: page.iconGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1 : 0.5)
                }
            }
            .padding(.top, 40)
            .frame(height: 200)
            
            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeColor,
                                Color(red: 0.5, green: 0.3, blue: 0.15)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text(page.subtitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Animation Views
    @ViewBuilder
    private func animationView(for type: OnboardingPage.AnimationType) -> some View {
        switch type {
        case .swipeCards:
            SwipeCardsAnimation()
        case .talentScout:
            TalentScoutAnimation()
        case .chatBubbles:
            ChatBubblesAnimation()
        case .coffeeSchedule:
            CoffeeScheduleAnimation()
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Talent Scout Animation
struct TalentScoutAnimation: View {
    @State private var searchText = ""
    @State private var showResults = false
    @State private var animationCycle = 0
    @State private var currentCycle = 0 // 追踪当前动画周期
    
    private let fullText = "alumni from Stanford"
    private let animationDuration: Double = 4.0 // 总循环时长
    
    var body: some View {
        VStack(spacing: 20) {
            // Search bar
            HStack {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    .font(.system(size: 16))
                
                Text(searchText.isEmpty ? "Describe who you want..." : searchText)
                    .font(.system(size: 13))
                    .foregroundColor(searchText.isEmpty ? .gray : Color(red: 0.4, green: 0.2, blue: 0.1))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .frame(width: 200)
            
            // Results
            if showResults {
                VStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        HStack(spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.2))
                                .frame(width: 35, height: 35)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // Name bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 80, height: 10)
                                // Info bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 8)
                            }
                            
                            Spacer()
                            
                            // Star badge
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                        .opacity(Double(index + 1) * 0.33)
                        .scaleEffect(1 - Double(index) * 0.05)
                    }
                }
                .frame(width: 200)
            }
        }
        .onAppear {
            startSearchAnimation()
        }
        .id(animationCycle) // 强制重新渲染
    }
    
    private func startSearchAnimation() {
        // 重置状态
        searchText = ""
        showResults = false
        currentCycle += 1
        let thisCycle = currentCycle // 捕获当前周期编号
        
        // Type out the text character by character
        let characters = Array(fullText)
        for (index, character) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                // 只有在当前周期才添加字符
                guard thisCycle == self.currentCycle else { return }
                self.searchText.append(character)
            }
        }
        
        // Show results after typing
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(characters.count) * 0.08 + 0.3) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self.showResults = true
            }
        }
        
        // 循环：在动画结束后重新开始
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            guard thisCycle == self.currentCycle else { return }
            self.animationCycle += 1
            self.startSearchAnimation()
        }
    }
}

// MARK: - Swipe Cards Animation
struct SwipeCardsAnimation: View {
    @State private var cardOffset: CGFloat = 0
    @State private var showHeart = false
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background cards
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 140, height: 180)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .offset(x: CGFloat(index * 3), y: CGFloat(index * 3))
                    .scaleEffect(1 - CGFloat(index) * 0.05)
                    .opacity(1 - Double(index) * 0.2)
            }
            
            // Top card with animation
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 140, height: 180)
                    .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 12)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 10)
                            }
                        }
                    )
                
                // Heart icon when swiping right
                if showHeart {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                        .scaleEffect(showHeart ? 1.2 : 0.5)
                        .opacity(showHeart ? 1 : 0)
                }
            }
            .offset(x: cardOffset)
            .rotationEffect(.degrees(Double(cardOffset) / 10))
        }
        .onAppear {
            startSwipeAnimation()
        }
    }
    
    private func startSwipeAnimation() {
        // 卡片滑动动画（循环）
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            cardOffset = 80
        }
        
        // 爱心显示/隐藏（循环）
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showHeart = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showHeart = false
                }
            }
        }
        
        // 首次触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showHeart = true
            }
        }
    }
}

// MARK: - Chat Bubbles Animation
struct ChatBubblesAnimation: View {
    @State private var showBubble1 = false
    @State private var showBubble2 = false
    @State private var showBubble3 = false
    @State private var animationCycle = 0
    @State private var currentCycle = 0
    
    var body: some View {
        VStack(spacing: 12) {
            // Message bubble 1 (received)
            HStack {
                messageBubble(text: "Hi! 👋", color: Color.white, isReceived: true)
                    .opacity(showBubble1 ? 1 : 0)
                    .offset(x: showBubble1 ? 0 : -30)
                Spacer()
            }
            
            // Message bubble 2 (sent)
            HStack {
                Spacer()
                messageBubble(text: "Hello! Coffee?", color: Color(red: 0.4, green: 0.2, blue: 0.1), isReceived: false)
                    .opacity(showBubble2 ? 1 : 0)
                    .offset(x: showBubble2 ? 0 : 30)
            }
            
            // Message bubble 3 (received)
            HStack {
                messageBubble(text: "Sure! ☕", color: Color.white, isReceived: true)
                    .opacity(showBubble3 ? 1 : 0)
                    .offset(x: showBubble3 ? 0 : -30)
                Spacer()
            }
        }
        .frame(width: 200)
        .onAppear {
            startChatAnimation()
        }
        .id(animationCycle)
    }
    
    private func messageBubble(text: String, color: Color, isReceived: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isReceived ? Color(red: 0.4, green: 0.2, blue: 0.1) : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func startChatAnimation() {
        // 重置状态
        showBubble1 = false
        showBubble2 = false
        showBubble3 = false
        currentCycle += 1
        let thisCycle = currentCycle
        
        // 气泡依次出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.showBubble1 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.showBubble2 = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                self.showBubble3 = true
            }
        }
        
        // 循环：3秒后重新开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard thisCycle == self.currentCycle else { return }
            self.animationCycle += 1
            self.startChatAnimation()
        }
    }
}

// MARK: - Coffee Schedule Animation
struct CoffeeScheduleAnimation: View {
    @State private var showCalendar = false
    @State private var showCheckmark = false
    @State private var showCoffee = false
    @State private var animationCycle = 0
    @State private var currentCycle = 0
    
    var body: some View {
        ZStack {
            // Calendar icon
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .frame(width: 120, height: 140)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .overlay(
                    VStack(spacing: 8) {
                        // Calendar header
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.3))
                            .frame(height: 30)
                        
                        // Calendar grid
                        VStack(spacing: 6) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 6) {
                                    ForEach(0..<4) { col in
                                        Circle()
                                            .fill(row == 1 && col == 2 ? Color(red: 0.2, green: 0.7, blue: 0.3) : Color.gray.opacity(0.2))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(8)
                )
                .scaleEffect(showCalendar ? 1 : 0.5)
                .opacity(showCalendar ? 1 : 0)
            
            // Checkmark
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1 : 0)
                    .offset(x: 60, y: -60)
            }
            
            // Coffee cup
            if showCoffee {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 35))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .offset(y: 80)
                    .scaleEffect(showCoffee ? 1 : 0)
            }
        }
        .onAppear {
            startScheduleAnimation()
        }
        .id(animationCycle)
    }
    
    private func startScheduleAnimation() {
        // 重置状态
        showCalendar = false
        showCheckmark = false
        showCoffee = false
        currentCycle += 1
        let thisCycle = currentCycle
        
        // 日历出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self.showCalendar = true
            }
        }
        
        // 打勾出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                self.showCheckmark = true
            }
        }
        
        // 咖啡杯出现
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard thisCycle == self.currentCycle else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                self.showCoffee = true
            }
        }
        
        // 循环：3秒后重新开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard thisCycle == self.currentCycle else { return }
            self.animationCycle += 1
            self.startScheduleAnimation()
        }
    }
}

// MARK: - Preview
struct WelcomeOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeOnboardingView(isPresented: .constant(true))
    }
}

