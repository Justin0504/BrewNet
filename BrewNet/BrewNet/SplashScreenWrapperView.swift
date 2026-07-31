import SwiftUI

// MARK: - Splash Screen Wrapper View
// 这个视图负责在启动画面和主界面之间切换
struct SplashScreenWrapperView: View {
    let user: AppUser
    @Binding var isCheckingProfile: Bool
    let onProfileCheck: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showSplash = true
    @State private var hasLoaded = false
    @State private var shouldShowSplashAgain = false // 用于重新显示启动画面
    @State private var showOnboarding = false // 用于显示新用户引导
    
    var body: some View {
        Group {
            if (showSplash && !hasLoaded) || shouldShowSplashAgain {
                // 显示启动画面
                SplashScreenView()
                    .onAppear {
                        // 启动画面显示完成后，检查 profile 状态
                        if shouldShowSplashAgain {
                            // 如果是重新显示的启动画面，重置状态并开始导航
                            shouldShowSplashAgain = false
                            hasLoaded = false
                            showSplash = true
                        }
                        checkProfileAndNavigate()
                    }
            } else if isCheckingProfile {
                // 正在检查 profile 状态
                VStack(spacing: 24) {
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                        .scaleEffect(1.2)
                    
                    Text("Checking profile status...")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .onAppear {
                    onProfileCheck()
                }
            } else if user.profileSetupCompleted || authManager.currentUser?.profileSetupCompleted == true {
                // 显示主界面或新用户引导
                let shouldShowOnboarding = showOnboarding || !onboardingManager.hasSeenWelcomeOnboarding
                let _ = print("🔍 [Onboarding Check] showOnboarding: \(showOnboarding), hasSeenWelcomeOnboarding: \(onboardingManager.hasSeenWelcomeOnboarding), shouldShowOnboarding: \(shouldShowOnboarding)")
                
                if shouldShowOnboarding {
                    // 显示新用户引导
                    WelcomeOnboardingView(isPresented: $showOnboarding)
                        .onAppear {
                            showOnboarding = true
                            print("👋 新用户引导已显示")
                        }
                } else {
                    // 使用 authManager.currentUser 作为源，因为它在编辑 profile 后会更新
                    MainView()
                        .onAppear {
                            print("🏠 主界面已显示，用户: \(user.name)")
                        }
                }
            } else {
                // 首次建档:默认走 Brew 对话式 onboarding(内含"Use form instead"回退到经典表单)
                BrewOnboardingView()
                    .onAppear {
                        print("📝 Brew 对话式建档已显示，用户: \(user.name)")
                    }
            }
        }
        .overlay {
            #if DEBUG
            // 仅 Debug:环境变量强制预览 onboarding UI(模拟器验收用,不落库路径)
            if ProcessInfo.processInfo.environment["BREWNET_PREVIEW_ONBOARDING"] == "1" {
                BrewOnboardingView()
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSplashScreen"))) { _ in
            // 收到显示启动画面的通知，重置状态并显示启动画面
            print("🎬 收到显示启动画面通知，重新显示启动画面...")
            shouldShowSplashAgain = true
            hasLoaded = false
            showSplash = true
        }
    }
    
    private func checkProfileAndNavigate() {
        // 等待启动画面显示足够的时间（至少2秒）以确保用户能看到启动画面
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            
            await MainActor.run {
                hasLoaded = true
                
                // 如果用户没有标记为已完成 profile 设置，进行额外检查
                if !user.profileSetupCompleted {
                    print("🔍 用户未标记为已完成 profile 设置，开始检查...")
                    isCheckingProfile = true
                    // 隐藏启动画面，显示 profile 检查界面
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                } else {
                    // 延迟一点再隐藏启动画面，让用户看到完成状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplash = false
                        }
                    }
                }
            }
        }
    }
}
