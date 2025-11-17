//
//  BrewNetApp.swift
//  BrewNet
//
//  Created by Justin_Yuan11 on 9/28/25.
//

import SwiftUI

@main
struct BrewNetApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = AuthManager()
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var supabaseService = SupabaseService.shared
    
    init() {
        print("🚀 =========================================")
        print("🚀 BrewNetApp initialized")
        print("🚀 =========================================")
        print("TEST TEST TEST - 如果你看到这条消息，说明应用正在运行")
        print("TEST TEST TEST - 如果你看到这条消息，说明应用正在运行")
        print("TEST TEST TEST - 如果你看到这条消息，说明应用正在运行")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
                .onAppear {
                    setupDependencies()
                }
        }
    }
    
    // 在视图出现后设置依赖
    private func setupDependencies() {
        print("🔧 =========================================")
        print("🔧 setupDependencies() 被调用")
        print("🔧 =========================================")
        print("🔧 设置依赖关系...")
        
        // 设置依赖关系
        print("🔧 1. 设置 SupabaseService 依赖...")
        supabaseService.setDependencies(databaseManager: databaseManager)
        print("🔧 2. 设置 AuthManager 依赖...")
        authManager.setDependencies(databaseManager: databaseManager, supabaseService: supabaseService)
        print("🔧 3. 设置 BehavioralMetricsService 依赖...")
        databaseManager.behavioralMetricsService.setDependencies(supabaseService: supabaseService)
        
        print("✅ 依赖关系设置完成")
        print("📊 DatabaseManager: \(databaseManager)")
        print("📊 SupabaseService: \(supabaseService)")
        
        // 启用混合模式（云端 + 本地缓存）进行 Supabase 测试
        databaseManager.enableHybridMode()
        print("🔄 混合模式已启用 - 云端 + 本地缓存（测试 Supabase 功能）")
        
        // Initialize database with sample data
        databaseManager.createSampleData()
        
        print("✅ =========================================")
        print("✅ 应用初始化完成")
        print("✅ =========================================")
    }
}
