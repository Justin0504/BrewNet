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
                // 已登录，显示启动画面并加载数据
                SplashScreenWrapperView(
                    user: user,
                    isCheckingProfile: $isCheckingProfile,
                    onProfileCheck: {
                        checkProfileStatus(for: user)
                    }
                )
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
                
                // 强制刷新界面
                self.refreshID = UUID()
                print("🔄 ContentView 强制刷新界面，显示启动画面")
            case .unauthenticated:
                print("🔄 ContentView 认证状态变化: unauthenticated")
                // 强制刷新界面，确保立即跳转到登录页面
                self.refreshID = UUID()
                print("🔄 ContentView 强制刷新界面，跳转到登录界面")
            }
        }
    }
    
    // MARK: - Profile Status Check
    private func checkProfileStatus(for user: AppUser) {
        print("🔍 开始检查用户 profile 状态: \(user.name)")
        
        Task {
            do {
            // 1. 检查并更新 Pro 过期状态（应用启动时自动检测）
            do {
                let proExpired = try await supabaseService.checkAndUpdateProExpiration(userId: user.id)
                if proExpired {
                    print("⚠️ [App启动] 检测到 Pro 已过期，已自动更新为 is_pro=false, likes_remaining=6")
                    // 刷新用户数据以同步最新状态
                    await authManager.refreshUser()
                } else {
                    print("✅ [App启动] Pro 状态正常或用户非 Pro")
                }
            } catch {
                print("❌ [App启动] Pro 过期检测失败: \(error.localizedDescription)")
            }
            
            // 2. 检查并重置普通用户的点赞次数（如果已过24小时）
            do {
                try await supabaseService.checkAndResetUserLikesIfNeeded(userId: user.id)
                print("✅ [App启动] 点赞次数检查完成")
            } catch {
                print("❌ [App启动] 点赞重置检测失败: \(error.localizedDescription)")
            }
                
            // 3. 检查用户是否有 profile 数据
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
                    Color(red: 0.98, green: 0.97, blue: 0.95),
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                // 加载指示器
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.1)))
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
