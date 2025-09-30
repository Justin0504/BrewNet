import SwiftUI
import CoreData

struct DatabaseTestView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var authManager: AuthManager
    @State private var posts: [PostEntity] = []
    @State private var users: [UserEntity] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Database Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                // Test Buttons
                VStack(spacing: 15) {
                    Button("Load All Posts") {
                        loadPosts()
                    }
                    .buttonStyle(TestButtonStyle())
                    
                    Button("Load All Users") {
                        loadUsers()
                    }
                    .buttonStyle(TestButtonStyle())
                    
                    Button("Create Sample Data") {
                        createSampleData()
                    }
                    .buttonStyle(TestButtonStyle())
                    
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .buttonStyle(TestButtonStyle())
                    
                    Button("Test Like/Unlike") {
                        testLikeFunctionality()
                    }
                    .buttonStyle(TestButtonStyle())
                }
                
                // Data Display
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Posts (\(posts.count))")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(posts, id: \.id) { post in
                            PostTestCard(post: post)
                        }
                        
                        Text("Users (\(users.count))")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        ForEach(users, id: \.id) { user in
                            UserTestCard(user: user)
                        }
                    }
                }
            }
            .navigationTitle("Database Test")
            .alert("Database Test", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadPosts() {
        posts = databaseManager.getAllPosts()
        showAlert(message: "Loaded \(posts.count) posts")
    }
    
    private func loadUsers() {
        // This would need to be implemented in DatabaseManager
        showAlert(message: "User loading not implemented yet")
    }
    
    private func createSampleData() {
        databaseManager.createSampleData()
        loadPosts()
        showAlert(message: "Sample data created successfully")
    }
    
    private func clearAllData() {
        databaseManager.clearAllData()
        posts = []
        users = []
        showAlert(message: "All data cleared")
    }
    
    private func testLikeFunctionality() {
        guard let currentUser = authManager.currentUser,
              let firstPost = posts.first else {
            showAlert(message: "No user logged in or no posts available")
            return
        }
        
        let success = databaseManager.likePost(userId: currentUser.id, postId: firstPost.id ?? "")
        showAlert(message: success ? "Post liked successfully" : "Failed to like post")
        loadPosts() // Refresh to show updated like count
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct PostTestCard: View {
    let post: PostEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.title ?? "No Title")
                    .font(.headline)
                Spacer()
                Text("Likes: \(post.likeCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(post.tag ?? "No Tag")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                
                Spacer()
                
                Text(post.authorName ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct UserTestCard: View {
    let user: UserEntity
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(user.name ?? "Unknown")
                    .font(.headline)
                Text(user.email ?? "No Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if user.isGuest {
                Text("Guest")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct TestButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DatabaseTestView_Previews: PreviewProvider {
    static var previews: some View {
        DatabaseTestView()
            .environmentObject(DatabaseManager.shared)
            .environmentObject(AuthManager())
    }
}
