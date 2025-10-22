import SwiftUI

// MARK: - Post Detail View
struct PostDetailView: View {
    let post: AppPost
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeCount: Int
    @State private var commentText = ""
    @State private var comments: [PostComment] = []
    @State private var showingCommentInput = false
    
    init(post: AppPost) {
        self.post = post
        _likeCount = State(initialValue: post.likeCount)
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Post header
                        postHeader
                        
                        // Post content
                        postContent
                        
                        // Post actions
                        postActions
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Comments section
                        commentsSection
                    }
                    .padding()
                    .padding(.bottom, showingCommentInput ? 80 : 0)
                }
                
                // Comment input bar
                if showingCommentInput {
                    commentInputBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                },
                trailing: HStack {
                    Button(action: {
                        // Share action
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                }
            )
        }
        .onAppear {
            loadComments()
        }
    }
    
    // MARK: - Post Header
    private var postHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // Author avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 24))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(post.authorName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                
                Text(timeAgoString(from: post.createdAt))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Tag
            Text(post.tag)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(post.tagUIColor)
                .cornerRadius(12)
        }
    }
    
    // MARK: - Post Content
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(post.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            
            // Content
            if !post.content.isEmpty {
                Text(post.content)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .lineSpacing(6)
            }
            
            // Question
            if !post.question.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        Text("Question")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    Text(post.question)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Post Actions
    private var postActions: some View {
        HStack(spacing: 24) {
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
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .gray)
                        .font(.system(size: 20))
                    
                    Text("\(likeCount)")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            
            // Comment button
            Button(action: {
                showingCommentInput.toggle()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "message")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    
                    Text("\(comments.count)")
                        .font(.system(size: 15))
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
                    .font(.system(size: 20))
            }
            
            Spacer()
            
            // View count
            HStack(spacing: 4) {
                Image(systemName: "eye")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Text("\(post.viewCount)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Comments")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                
                Spacer()
                
                Text("\(comments.count)")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
            }
            
            if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No comments yet")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    
                    Text("Be the first to share your thoughts")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(comments) { comment in
                    CommentRowView(comment: comment)
                }
            }
        }
    }
    
    // MARK: - Comment Input Bar
    private var commentInputBar: some View {
        HStack(spacing: 12) {
            TextField("Write a comment...", text: $commentText)
                .font(.system(size: 15))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            
            Button(action: {
                postComment()
            }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                    .frame(width: 40, height: 40)
                    .background(
                        commentText.isEmpty ? Color.gray.opacity(0.5) : Color(red: 0.4, green: 0.2, blue: 0.1)
                    )
                    .clipShape(Circle())
            }
            .disabled(commentText.isEmpty)
        }
        .padding()
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
    
    // MARK: - Helper Methods
    private func loadComments() {
        // TODO: 从数据库加载评论
        // 暂时使用示例数据
        comments = []
    }
    
    private func postComment() {
        guard !commentText.isEmpty, let currentUser = authManager.currentUser else {
            return
        }
        
        let newComment = PostComment(
            id: UUID().uuidString,
            postId: post.id,
            authorId: currentUser.id,
            authorName: currentUser.name,
            content: commentText,
            createdAt: Date()
        )
        
        comments.append(newComment)
        commentText = ""
        
        print("✅ 评论已发布: \(newComment.content)")
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Comment Row View
struct CommentRowView: View {
    let comment: PostComment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.authorName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        
                        Text("•")
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(timeAgoString(from: comment.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Text(comment.content)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Post Comment Model
struct PostComment: Identifiable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let content: String
    let createdAt: Date
}

// MARK: - Preview
struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PostDetailView(post: AppPost(
            id: "1",
            title: "Sample Post Title",
            content: "This is a sample post content.",
            question: "What do you think about this?",
            tag: "Tech",
            tagColor: "purple",
            backgroundColor: "white",
            authorId: "user1",
            authorName: "John Doe",
            likeCount: 42,
            commentCount: 5,
            viewCount: 123,
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environmentObject(DatabaseManager.shared)
        .environmentObject(AuthManager())
    }
}

