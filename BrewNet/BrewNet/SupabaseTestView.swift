import SwiftUI

// MARK: - Supabase Test View
struct SupabaseTestView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @StateObject private var networkDiagnostics = NetworkDiagnostics.shared
    @State private var syncStatus = ""
    @State private var isSyncing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 状态信息卡片
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("同步状态")
                                .font(.headline)
                        }
                        
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Circle()
                                .fill(databaseManager.isOnline ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(databaseManager.isOnline ? "在线" : "离线")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 同步模式选择
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gear.circle.fill")
                                .foregroundColor(.orange)
                            Text("同步模式")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Button("测试模式") {
                                    databaseManager.enableTestMode()
                                    updateSyncStatus()
                                }
                                .buttonStyle(.bordered)
                                .disabled(databaseManager.syncMode == .localOnly)
                                
                                Button("混合模式") {
                                    databaseManager.enableHybridMode()
                                    updateSyncStatus()
                                }
                                .buttonStyle(.bordered)
                                .disabled(databaseManager.syncMode == .hybrid)
                                
                                Spacer()
                            }
                            
                            Text(databaseManager.syncMode == .localOnly ? 
                                 "🧪 测试模式：仅使用本地存储" : 
                                 "🔄 混合模式：云端 + 本地缓存")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 同步操作按钮
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(.green)
                            Text("同步操作")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await syncToCloud()
                                }
                            }) {
                                HStack {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "icloud.and.arrow.up")
                                    }
                                    Text("同步到云端")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!databaseManager.isOnline || databaseManager.syncMode == .localOnly)
                            
                            Button(action: {
                                Task {
                                    await syncFromCloud()
                                }
                            }) {
                                HStack {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "icloud.and.arrow.down")
                                    }
                                    Text("从云端同步")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!databaseManager.isOnline || databaseManager.syncMode == .localOnly)
                            
                            Button(action: {
                                Task {
                                    await bidirectionalSync()
                                }
                            }) {
                                HStack {
                                    if isSyncing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }
                                    Text("双向同步")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!databaseManager.isOnline || databaseManager.syncMode != .hybrid)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 测试数据操作
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "testtube.2")
                                .foregroundColor(.purple)
                            Text("测试数据")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 8) {
                            Button("创建测试帖子") {
                                createTestPost()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("创建测试用户") {
                                createTestUser()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("清空所有数据") {
                                clearAllData()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Supabase 配置信息
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "externaldrive.connected.to.line.below.fill")
                                .foregroundColor(.blue)
                            Text("Supabase 配置")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("URL: https://jcxvdolcdifdghaibspy.supabase.co")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("状态: \(databaseManager.isOnline ? "已连接" : "未连接")")
                                .font(.caption)
                                .foregroundColor(databaseManager.isOnline ? .green : .red)
                            
                            Text("✅ Supabase SDK 已成功集成")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("网络状态: \(networkDiagnostics.isConnected ? "已连接" : "未连接") (\(networkDiagnostics.connectionType))")
                                .font(.caption)
                                .foregroundColor(networkDiagnostics.isConnected ? .green : .red)
                            
                            if !databaseManager.isOnline {
                                Text("⚠️ 连接失败，请检查网络或 Supabase 配置")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            HStack {
                                Button("测试连接") {
                                    Task {
                                        let success = await supabaseService.testSupabaseConnection()
                                        print(success ? "✅ 连接测试成功" : "❌ 连接测试失败")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button("网络诊断") {
                                    Task {
                                        let (success, details) = await networkDiagnostics.testSupabaseConnectivity()
                                        print("网络诊断: \(success ? "成功" : "失败") - \(details)")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Supabase 测试")
            .onAppear {
                updateSyncStatus()
            }
            .alert("操作结果", isPresented: $showingAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSyncStatus() {
        syncStatus = databaseManager.getSyncStatus()
    }
    
    private func syncToCloud() async {
        isSyncing = true
        await databaseManager.syncToCloud()
        isSyncing = false
        updateSyncStatus()
        showAlert("数据已同步到云端")
    }
    
    private func syncFromCloud() async {
        isSyncing = true
        await databaseManager.syncFromCloud()
        isSyncing = false
        updateSyncStatus()
        showAlert("已从云端同步数据")
    }
    
    private func bidirectionalSync() async {
        isSyncing = true
        await databaseManager.bidirectionalSync()
        isSyncing = false
        updateSyncStatus()
        showAlert("双向同步完成")
    }
    
    private func createTestPost() {
        let testPost = databaseManager.createPost(
            id: UUID().uuidString,
            title: "测试帖子 - \(Date().formatted())",
            content: "这是一个测试帖子，用于验证 Supabase 集成功能。",
            question: "这个功能工作正常吗？",
            tag: "测试",
            tagColor: "blue",
            backgroundColor: "white",
            authorId: "test_user",
            authorName: "测试用户"
        )
        
        if testPost != nil {
            showAlert("测试帖子创建成功")
        } else {
            showAlert("测试帖子创建失败")
        }
    }
    
    private func createTestUser() {
        let testUser = databaseManager.createUser(
            id: UUID().uuidString,
            email: "test@example.com",
            name: "测试用户",
            isGuest: false
        )
        
        if testUser != nil {
            showAlert("测试用户创建成功")
        } else {
            showAlert("测试用户创建失败")
        }
    }
    
    private func clearAllData() {
        databaseManager.clearAllData()
        showAlert("所有数据已清空")
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Preview
struct SupabaseTestView_Previews: PreviewProvider {
    static var previews: some View {
        SupabaseTestView()
            // 依赖关系通过环境对象传递，不需要直接引用
            .environmentObject(AuthManager())
    }
}
