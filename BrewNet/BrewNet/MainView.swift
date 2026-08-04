import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 1 // 默认落在 Talent Scout(agent 入口),滑卡浏览降级为第二位
    @State private var profilesPreloaded = false // 标记是否已预加载
    @State private var unreadMessageCount = 0 // 未读消息总数
    @State private var chatListRefreshTimer: Timer? // 用于刷新未读消息数
    @State private var pendingRequestCount = 0 // 待处理的请求总数
    @State private var requestRefreshTimer: Timer? // 用于刷新请求数
    
    init() {
        configureTabBarBadgeAppearance()
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Talent Scout(首位:告诉 agent 你要谁,它去找并给出理由)
            ExploreView()
                .tabItem {
                    Image(systemName: "sparkle.magnifyingglass")
                    Text("Brew")
                }
                .tag(1)

            // Matches(滑卡浏览,降级为第二位)
            NavigationStack {
                MatchesView()
            }
                .tabItem {
                    Image(systemName: "cup.and.saucer.fill")
                    Text("Browse")
                }
                .tag(0)
            
            // Requests
            RequestsView()
                .tabItem {
                    Image(systemName: "person.badge.plus.fill")
                    Text("Requests")
                }
                .tag(2)
                .badge(pendingRequestCount > 0 ? pendingRequestCount : 0)

            // Chat
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("Chats")
            }
            .tag(3)
            .badge(unreadMessageCount > 0 ? unreadMessageCount : 0)

            // Profile
            NavigationStack {
                ProfileView()
            }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Me")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.4, green: 0.2, blue: 0.1)) // Dark brown theme color
        .onAppear {
            // 应用启动时预加载第一个 tab 的数据
            preloadMatchesData()
            // 开始刷新未读消息数
            startUnreadMessageCountRefresh()
            // 开始刷新请求数
            startRequestCountRefresh()
        }
        .onDisappear {
            stopUnreadMessageCountRefresh()
            stopRequestCountRefresh()
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToMatches"))) { _ in
            // 当收到导航到 Matches 的通知时，切换到 Matches tab
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConnectionRequestAccepted"))) { _ in
            // 当请求被接受时，刷新请求数
            Task {
                await updatePendingRequestCount()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ConnectionRequestRejected"))) { _ in
            // 当请求被拒绝时，刷新请求数
            Task {
                await updatePendingRequestCount()
            }
        }
    }
    
    // 预加载 Matches 数据
    private func preloadMatchesData() {
        guard !profilesPreloaded else { return }
        guard let currentUser = authManager.currentUser else { return }

        // 在后台预加载推荐用户和行为量化指标
        Task {
            do {
                // 并行执行推荐数据预加载（行为指标计算已禁用）
                async let recommendationsTask = supabaseService.getRecommendedProfiles(
                    userId: currentUser.id,
                    limit: 20,
                    offset: 0
                )

                // 注：BehavioralMetricsService 因兼容性问题暂时禁用
                // async let behavioralMetricsTask = databaseManager.behavioralMetricsService.calculateAllActiveUsersBehavioralMetrics()

                // 等待推荐数据加载完成
                let (profiles, _, _) = try await recommendationsTask
                // let behavioralResult = try await behavioralMetricsTask

                // 数据加载成功，标记为已预加载
                // 实际的数据会在 MatchesView 的 onAppear 中使用缓存
                await MainActor.run {
                    profilesPreloaded = true
                    print("✅ Preloaded \(profiles.count) profiles for Matches tab")
                    // print("✅ Behavioral metrics calculated for active users")
                }
            } catch {
                print("⚠️ Failed to preload profiles: \(error.localizedDescription)")
                // 即使预加载失败，也要设置预加载标志以避免阻塞UI
                await MainActor.run {
                    profilesPreloaded = true
                    print("⚠️ Profiles preload failed but continuing")
                }
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
        
        // ⚡️ 每 20 秒刷新未读数(原 5 秒过于激进;切 tab/通知仍即时刷新)
        chatListRefreshTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { _ in
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
        
        // 获取 hidden 用户 ID 列表（从 UserDefaults 读取）
        let hiddenUsersKey = "hidden_chat_users_\(currentUser.id)"
        let hiddenUserIds = Set(UserDefaults.standard.stringArray(forKey: hiddenUsersKey) ?? [])
        
        do {
            // ⚡️ 性能修复(2026-08):原实现每 5 秒做 1+N 次请求(每个 match 拉全部历史消息)
            // 现在一条查询取全部未读消息的 sender_id,客户端过滤 hidden 后计数
            struct UnreadRow: Decodable { let senderId: String
                enum CodingKeys: String, CodingKey { case senderId = "sender_id" } }
            let response = try await supabaseService.supabase
                .from("messages")
                .select("sender_id")
                .eq("receiver_id", value: currentUser.id)
                .eq("is_read", value: false)
                .execute()
            let rows = try JSONDecoder().decode([UnreadRow].self, from: response.data)
            let totalUnread = rows.filter { !hiddenUserIds.contains($0.senderId) }.count

            unreadMessageCount = totalUnread
            print("✅ Updated unread message count: \(totalUnread) (1 query, excluded \(hiddenUserIds.count) hidden chats)")
        } catch {
            print("⚠️ Failed to update unread message count: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Count Refresh
    private func startRequestCountRefresh() {
        stopRequestCountRefresh()
        
        // 立即刷新一次
        Task {
            await updatePendingRequestCount()
        }
        
        // ⚡️ 每 20 秒刷新请求数(接受/拒绝事件另有通知即时刷新)
        requestRefreshTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { _ in
            Task {
                await updatePendingRequestCount()
            }
        }
    }
    
    private func stopRequestCountRefresh() {
        requestRefreshTimer?.invalidate()
        requestRefreshTimer = nil
    }
    
    private func configureTabBarBadgeAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        let badgeColor = UIColor(red: 0.95, green: 0.26, blue: 0.29, alpha: 1.0)
        let badgeFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        
        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.badgeBackgroundColor = badgeColor
            itemAppearance.selected.badgeBackgroundColor = badgeColor
            itemAppearance.normal.badgeTextAttributes = [.font: badgeFont]
            itemAppearance.selected.badgeTextAttributes = [.font: badgeFont]
            itemAppearance.normal.badgePositionAdjustment = UIOffset(horizontal: 0, vertical: 5)
            itemAppearance.selected.badgePositionAdjustment = UIOffset(horizontal: 0, vertical: 5)
        }
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    @MainActor
    private func updatePendingRequestCount() async {
        guard let currentUser = authManager.currentUser else {
            pendingRequestCount = 0
            return
        }
        
        do {
            #if DEBUG
            // 🔬 诊断:查询时刻的 auth session 状态
            if let s = try? await SupabaseConfig.shared.client.auth.session {
                print("🔑 [DIAG] session uid=\(s.user.id.uuidString.lowercased()) expires=\(s.expiresAt)")
            } else {
                print("🔑 [DIAG] NO auth session at query time — queries run as anon!")
            }
            #endif
            // 获取所有待处理的邀请
            let pendingInvitations = try await supabaseService.getPendingInvitations(userId: currentUser.id)
            
            // 获取所有已匹配的用户ID，用于过滤
            var matchedUserIds: Set<String> = []
            do {
                let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                for match in matches {
                    if match.userId == currentUser.id {
                        matchedUserIds.insert(match.matchedUserId)
                    } else if match.matchedUserId == currentUser.id {
                        matchedUserIds.insert(match.userId)
                    }
                }
            } catch {
                print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
            }
            
            // 过滤掉已经匹配的邀请
            let filteredInvitations = pendingInvitations.filter { invitation in
                !matchedUserIds.contains(invitation.senderId)
            }
            
            pendingRequestCount = filteredInvitations.count
            print("✅ Updated pending request count: \(pendingRequestCount)")
        } catch {
            print("⚠️ Failed to update pending request count: \(error.localizedDescription)")
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
    @State private var shouldHideTabBar = false
    
    var body: some View {
        ChatInterfaceView()
            .toolbar(shouldHideTabBar ? .hidden : .visible, for: .tabBar)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideTabBar"))) { notification in
                if let shouldHide = notification.userInfo?["shouldHide"] as? Bool {
                    print("📱 ChatView received HideTabBar notification: shouldHide = \(shouldHide)")
                    withAnimation(.easeInOut(duration: 0.3)) {
                        shouldHideTabBar = shouldHide
                    }
                }
            }
            .onAppear {
                // 确保初始状态正确
                shouldHideTabBar = false
            }
    }
}

// MARK: - Explore View
// Stage 1(AI-native):Scout Tab = 与 Brew 的对话;经典表单作为降级/手动切换保留
struct ExploreView: View {
    var body: some View {
        BrewAgentView()
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
