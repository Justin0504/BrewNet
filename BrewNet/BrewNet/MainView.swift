import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Matches
            MatchesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Matches")
                }
                .tag(0)
            
            // Chat
            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
                .tag(1)
            
            // Profile
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(2)
        }
        .accentColor(Color(red: 0.4, green: 0.2, blue: 0.1)) // Dark brown theme color
    }
}

// MARK: - Matches View
struct MatchesView: View {
    var body: some View {
        TinderMatchesView()
    }
}

// MARK: - Chat View
struct ChatView: View {
    var body: some View {
        ChatInterfaceView()
    }
}

// MARK: - Profile View (Now using the new ProfileView from ProfileView.swift)

// MARK: - Preview
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
