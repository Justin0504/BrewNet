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
    @State private var refreshID = UUID()
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                // 加载界面
                LoadingView()
            case .authenticated(let user):
                // 已登录，显示主界面
                MainView()
                    .onAppear {
                        print("🏠 主界面已显示，用户: \(user.name)")
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
        .onReceive(authManager.$authState) { newState in
            print("🔄 ContentView 收到状态变化通知: \(newState)")
            switch newState {
            case .loading:
                print("🔄 ContentView 认证状态变化: loading")
            case .authenticated(let user):
                print("🔄 ContentView 认证状态变化: authenticated - \(user.name) (游客: \(user.isGuest))")
                // 强制刷新界面，确保立即跳转到主界面
                self.refreshID = UUID()
                print("🔄 ContentView 强制刷新界面，跳转到主界面")
            case .unauthenticated:
                print("🔄 ContentView 认证状态变化: unauthenticated")
                // 强制刷新界面，确保立即跳转到登录页面
                self.refreshID = UUID()
                print("🔄 ContentView 强制刷新界面，跳转到登录界面")
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
