import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 0
    @State private var profilesPreloaded = false // 标记是否已预加载
    
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
        }
        .onChange(of: selectedTab) { newTab in
            // 切换到第一个 tab 时，如果还没预加载，则预加载
            if newTab == 0 && !profilesPreloaded {
                preloadMatchesData()
            }
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
