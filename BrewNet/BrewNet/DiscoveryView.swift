import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var searchText = ""
    @State private var posts: [AppPost] = []
    @State private var showingCreatePost = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(25)
                
                Button(action: {
                    showingCreatePost = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Posts Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(posts) { post in
                        PostCardView(post: post)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
                .environmentObject(databaseManager)
                .environmentObject(authManager)
        }
        .onAppear {
            print("🔄 DiscoveryView appeared")
            loadPosts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PostCreated"))) { notification in
            print("📨 Received PostCreated notification")
            if let postId = notification.userInfo?["postId"] as? String {
                print("  New post ID: \(postId)")
            }
            // Delay to ensure data is saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                loadPosts()
            }
        }
    }
    
    private func loadPosts() {
        print("📚 Loading posts from Supabase...")
        isLoading = true
        
        Task {
            do {
                // Get all posts from Supabase
                let supabasePosts = try await supabaseService.getAllPosts()
                print("✅ Retrieved \(supabasePosts.count) posts from Supabase")
                
                // Convert to AppPost
                let appPosts = supabasePosts.map { supabasePost in
                    AppPost(
                        id: supabasePost.id,
                        title: supabasePost.title,
                        content: supabasePost.content ?? "",
                        question: supabasePost.question ?? "",
                        tag: supabasePost.tag,
                        tagColor: supabasePost.tagColor,
                        backgroundColor: supabasePost.backgroundColor,
                        authorId: supabasePost.authorId,
                        authorName: supabasePost.authorName,
                        likeCount: supabasePost.likeCount,
                        commentCount: 0, // TODO: Implement comment count
                        viewCount: supabasePost.viewCount,
                        createdAt: ISO8601DateFormatter().date(from: supabasePost.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: supabasePost.updatedAt) ?? Date()
                    )
                }.sorted { $0.createdAt > $1.createdAt } // Sort by creation time descending
                
                // Update UI
                await MainActor.run {
                    posts = appPosts
                    isLoading = false
                    print("✅ Posts loaded, displaying \(posts.count) posts")
                    print("📋 Post list: \(posts.map { $0.title })")
                }
                
            } catch {
                print("❌ Failed to load posts from Supabase: \(error)")
                print("🔄 Falling back to local data")
                
                // Fallback to local data on failure
                await MainActor.run {
                    loadLocalPosts()
                    isLoading = false
                }
            }
        }
    }
    
    // Backup: Load from local (only used when Supabase fails)
    private func loadLocalPosts() {
        print("📚 Loading posts from local database...")
        let postEntities = databaseManager.getAllPosts()
        print("✅ Found \(postEntities.count) local posts")
        
        posts = postEntities.map { entity in
            AppPost(
                id: entity.id ?? UUID().uuidString.lowercased(),
                title: entity.title ?? "Untitled",
                content: entity.content ?? "",
                question: entity.question ?? "",
                tag: entity.tag ?? "General",
                tagColor: entity.tagColor ?? "gray",
                backgroundColor: entity.backgroundColor ?? "white",
                authorId: entity.authorId ?? "",
                authorName: entity.authorName ?? "Unknown",
                likeCount: Int(entity.likeCount),
                commentCount: 0,
                viewCount: Int(entity.viewCount),
                createdAt: entity.createdAt ?? Date(),
                updatedAt: entity.updatedAt ?? Date()
            )
        }.sorted { $0.createdAt > $1.createdAt }
        
        print("✅ Local posts loaded, displaying \(posts.count) posts")
    }
}

// MARK: - Post Card View
struct PostCardView: View {
    let post: AppPost
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeCount: Int
    
    init(post: AppPost) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
    }
    
    var body: some View {
        NavigationLink(destination: PostDetailView(post: post)) {
        VStack(alignment: .leading, spacing: 12) {
            // Post Title
            Text(post.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Post Content
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            
            // Question
            if !post.question.isEmpty {
                Text(post.question)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            // Bottom section with tag and actions
            VStack(spacing: 8) {
                // Tag
                HStack {
                    Text(post.tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(post.tagUIColor)
                        .cornerRadius(8)
                    
                    Spacer()
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    // Like button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLiked.toggle()
                            if isLiked {
                                likeCount += 1
                            } else {
                                likeCount -= 1
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundColor(isLiked ? .red : .gray)
                                .font(.system(size: 14))
                            
                            Text("\(likeCount)")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Save button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSaved.toggle()
                        }
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isSaved ? Color(red: 0.4, green: 0.2, blue: 0.1) : .gray)
                            .font(.system(size: 14))
                    }
                    
                    Spacer()
                    
                    // Share button
                    Button(action: {
                        // Share action
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .padding(16)
        .background(post.backgroundUIColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Post Model
struct AppPost: Identifiable {
    let id: String
    let title: String
    let content: String
    let question: String
    let tag: String
    let tagColor: String
    let backgroundColor: String
    let authorId: String
    let authorName: String
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    // 计算属性：转换颜色字符串为 Color
    var tagUIColor: Color {
        colorFromString(tagColor)
    }
    
    var backgroundUIColor: Color {
        colorFromString(backgroundColor)
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        case "cyan": return .cyan
        case "white": return .white
        default: return .gray
        }
    }
}

// MARK: - Sample Data (Removed - now loading from database)

// MARK: - Preview
struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
    }
}
