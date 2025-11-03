import SwiftUI

// MARK: - Splash Screen Wrapper View
// 这个视图负责在启动画面和主界面之间切换
struct SplashScreenWrapperView: View {
    let user: AppUser
    @Binding var isCheckingProfile: Bool
    let onProfileCheck: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @State private var showSplash = true
    @State private var hasLoaded = false
    
    var body: some View {
        Group {
            if showSplash && !hasLoaded {
                // 显示启动画面
                SplashScreenView()
                    .onAppear {
                        // 启动画面显示完成后，检查 profile 状态
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
            } else if user.profileSetupCompleted {
                // 显示主界面
                MainView()
                    .onAppear {
                        print("🏠 主界面已显示，用户: \(user.name)")
                    }
            } else {
                // 显示资料设置界面
                ProfileSetupView()
                    .onAppear {
                        print("📝 资料设置界面已显示，用户: \(user.name)")
                    }
            }
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
