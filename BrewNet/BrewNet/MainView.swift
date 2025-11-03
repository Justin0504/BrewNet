import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 0
    @State private var profilesPreloaded = false // 标记是否已预加载
    @State private var unreadMessageCount = 0 // 未读消息总数
    @State private var chatListRefreshTimer: Timer? // 用于刷新未读消息数
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Matches
            NavigationStack {
                MatchesView()
            }
                .tabItem {
                    Image(systemName: "cup.and.saucer.fill")
                }
                .tag(0)
            
            // Explore
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                }
                .tag(1)
            
            // Requests
            RequestsView()
                .tabItem {
                    Image(systemName: "person.badge.plus.fill")
                }
                .tag(2)
            
            // Chat
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Image(systemName: "message.fill")
            }
            .tag(3)
            .badge(unreadMessageCount > 0 ? unreadMessageCount : 0)
            
            // Profile
            NavigationStack {
                ProfileView()
            }
                .tabItem {
                    Image(systemName: "person.fill")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.4, green: 0.2, blue: 0.1)) // Dark brown theme color
        .onAppear {
            // 应用启动时预加载第一个 tab 的数据
            preloadMatchesData()
            // 开始刷新未读消息数
            startUnreadMessageCountRefresh()
        }
        .onDisappear {
            stopUnreadMessageCountRefresh()
        }
        .onChange(of: selectedTab) { newTab in
            // 切换到第一个 tab 时，如果还没预加载，则预加载
            if newTab == 0 && !profilesPreloaded {
                preloadMatchesData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToChat"))) { _ in
            // 当收到导航到 Chat 的通知时，切换到 Chat tab
            selectedTab = 3
        }
    }
    
    // 预加载 Matches 数据
    private func preloadMatchesData() {
        guard !profilesPreloaded else { return }
        guard let currentUser = authManager.currentUser else { return }
        
        // 在后台预加载推荐用户
        Task {
            do {
                let (profiles, _, _) = try await supabaseService.getRecommendedProfiles(
                    userId: currentUser.id,
                    limit: 20,
                    offset: 0
                )
                // 数据加载成功，标记为已预加载
                // 实际的数据会在 MatchesView 的 onAppear 中使用缓存
                await MainActor.run {
                    profilesPreloaded = true
                    print("✅ Preloaded \(profiles.count) profiles for Matches tab")
                }
            } catch {
                print("⚠️ Failed to preload profiles: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Unread Message Count Refresh
    private func startUnreadMessageCountRefresh() {
        stopUnreadMessageCountRefresh()
        
        // 立即刷新一次
        Task {
            await updateUnreadMessageCount()
        }
        
        // 每5秒刷新一次未读消息数
        chatListRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await updateUnreadMessageCount()
            }
        }
    }
    
    private func stopUnreadMessageCountRefresh() {
        chatListRefreshTimer?.invalidate()
        chatListRefreshTimer = nil
    }
    
    @MainActor
    private func updateUnreadMessageCount() async {
        guard let currentUser = authManager.currentUser else {
            unreadMessageCount = 0
            return
        }
        
        do {
            // 获取所有活跃的匹配
            let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
            
            var totalUnread = 0
            
            // 对每个匹配，获取未读消息数
            for match in matches {
                let otherUserId = match.userId == currentUser.id ? match.matchedUserId : match.userId
                
                // 获取该用户的所有消息
                let messages = try await supabaseService.getMessages(
                    userId1: currentUser.id,
                    userId2: otherUserId
                )
                
                // 计算未读消息数（接收者是自己且未读）
                let unread = messages.filter { message in
                    message.receiverId == currentUser.id && !message.isRead
                }.count
                
                totalUnread += unread
            }
            
            unreadMessageCount = totalUnread
        } catch {
            print("⚠️ Failed to update unread message count: \(error.localizedDescription)")
        }
    }
}

// MARK: - Matches View
struct MatchesView: View {
    var body: some View {
        BrewNetMatchesView()
    }
}

// MARK: - Chat View
struct ChatView: View {
    var body: some View {
        ChatInterfaceView()
    }
}

// MARK: - Explore View
struct ExploreView: View {
    var body: some View {
        ExploreMainView()
    }
}

// MARK: - Requests View
struct RequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        ConnectionRequestsView()
            .environmentObject(authManager)
            .environmentObject(databaseManager)
            .environmentObject(supabaseService)
    }
}

// MARK: - Profile View (Now using the new ProfileView from ProfileView.swift)

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
