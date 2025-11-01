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
        print("🚀 BrewNetApp initialized")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
                .accentColor(BrewTheme.primaryBrown)
                .background(BrewTheme.background)
                .onAppear {
                    setupDependencies()
                }
        }
    }
    
    // 在视图出现后设置依赖
    private func setupDependencies() {
        print("🔧 设置依赖关系...")
        
        // 设置依赖关系
        supabaseService.setDependencies(databaseManager: databaseManager)
        authManager.setDependencies(databaseManager: databaseManager, supabaseService: supabaseService)
        
        print("✅ 依赖关系设置完成")
        print("📊 DatabaseManager: \(databaseManager)")
        print("📊 SupabaseService: \(supabaseService)")
        
        // 启用混合模式（云端 + 本地缓存）进行 Supabase 测试
        databaseManager.enableHybridMode()
        print("🔄 混合模式已启用 - 云端 + 本地缓存（测试 Supabase 功能）")
        
        // Initialize database with sample data
        databaseManager.createSampleData()
        
        print("✅ 应用初始化完成")
    }
}
