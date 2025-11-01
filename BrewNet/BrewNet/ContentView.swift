//
//  ContentView.swift
//  BrewNet
//
//  Created by Justin_Yuan11 on 9/28/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var refreshID = UUID()
    @State private var showDatabaseSetup = false
    @State private var isCheckingProfile = false
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                // 加载界面
                LoadingView()
            case .authenticated(let user):
                // 已登录，检查是否需要完成资料设置
                if isCheckingProfile {
                    // 正在检查 profile 状态
                    VStack(spacing: 24) {
                        Spacer()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: BrewTheme.secondaryBrown))
                            .scaleEffect(1.2)
                        
                        Text("Checking profile status...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .onAppear {
                        checkProfileStatus(for: user)
                    }
                } else if user.profileSetupCompleted {
                    MainView()
                        .onAppear {
                            print("🏠 主界面已显示，用户: \(user.name)")
                        }
                } else {
                    ProfileSetupView()
                        .onAppear {
                            print("📝 资料设置界面已显示，用户: \(user.name)")
                        }
                }
            case .unauthenticated:
                // 未登录，显示登录界面
                LoginView()
                    .onAppear {
                        print("🔐 登录界面已显示")
                    }
            }
        }
        .id(refreshID) // 添加强制刷新ID
        .sheet(isPresented: $showDatabaseSetup) {
            DatabaseSetupView()
                .environmentObject(SupabaseService.shared)
        }
        .onReceive(authManager.$authState) { newState in
            print("🔄 ContentView 收到状态变化通知: \(newState)")
            switch newState {
            case .loading:
                print("🔄 ContentView 认证状态变化: loading")
            case .authenticated(let user):
                print("🔄 ContentView 认证状态变化: authenticated - \(user.name) (游客: \(user.isGuest))")
                
                // 如果用户没有标记为已完成 profile 设置，进行额外检查
                if !user.profileSetupCompleted {
                    print("🔍 用户未标记为已完成 profile 设置，开始检查...")
                    isCheckingProfile = true
                }
                
                // 强制刷新界面，确保立即跳转到主界面
                self.refreshID = UUID()
                print("🔄 ContentView 强制刷新界面，跳转到主界面")
            case .unauthenticated:
                print("🔄 ContentView 认证状态变化: unauthenticated")
                print("🔄 ContentView 跳转到登录界面")
            }
        }
    }
    
    // MARK: - Profile Status Check
    private func checkProfileStatus(for user: AppUser) {
        print("🔍 开始检查用户 profile 状态: \(user.name)")
        
        Task {
            do {
                // 检查用户是否有 profile 数据
                let hasProfile = try await supabaseService.getProfile(userId: user.id) != nil
                
                print("🔍 Profile 检查结果: hasProfile = \(hasProfile)")
                
                await MainActor.run {
                    if hasProfile && !user.profileSetupCompleted {
                        // 用户有 profile 数据但状态不正确，更新状态
                        print("🔄 更新用户 profile 状态: \(user.name)")
                        authManager.updateProfileSetupCompleted(true)
                    }
                    
                    // 检查完成，隐藏检查界面
                    isCheckingProfile = false
                }
                
            } catch {
                print("❌ Profile 检查失败: \(error.localizedDescription)")
                
                await MainActor.run {
                    // 检查失败，隐藏检查界面，让用户继续正常流程
                    isCheckingProfile = false
                }
            }
        }
    }
}

// MARK: - 加载界面
struct LoadingView: View {
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    BrewTheme.background,
                    Color.white
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo - 使用AppIcon中的图片
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.brown.opacity(0.3), radius: 15, x: 0, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white, lineWidth: 3)
                    )
                
                // 应用名称
                Text("BrewNet")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                // 加载指示器
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: BrewTheme.primaryBrown))
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .environmentObject(SupabaseService.shared)
}
