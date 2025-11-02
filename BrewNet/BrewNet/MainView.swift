import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Matches
            NavigationStack {
                MatchesView()
            }
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Matches")
                }
                .tag(0)
            
            // Explore
            ExploreView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("Explore")
                }
                .tag(1)
            
            // Requests
            RequestsView()
                .tabItem {
                    Image(systemName: "person.badge.plus.fill")
                    Text("Requests")
                }
                .tag(2)
            
            // Chat
            NavigationStack {
                ChatView()
            }
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
                .tag(3)
            
            // Profile
            NavigationStack {
                ProfileView()
            }
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.4, green: 0.2, blue: 0.1)) // Dark brown theme color
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
