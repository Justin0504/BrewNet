import SwiftUI

struct FollowingView: View {
    @State private var searchText = ""
    @State private var posts: [FollowingPost] = sampleFollowingPosts
    @State private var showingCreatePost = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search friends' posts", text: $searchText)
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
            
            // Posts Feed
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(posts) { post in
                        FollowingPostCardView(post: post)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
        }
    }
}

// MARK: - Following Post Card View
struct FollowingPostCardView: View {
    let post: FollowingPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            HStack {
                // User Avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.authorName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    
                    Text(post.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Follow status
                if post.isFollowing {
                    Button("Following") {
                        // Unfollow action
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.1))
                    .cornerRadius(15)
                } else {
                    Button("Follow") {
                        // Follow action
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .cornerRadius(15)
                }
            }
            
            // Post Content
            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                if !post.content.isEmpty {
                    Text(post.content)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(6)
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
            }
            
            // Post Image (if any)
            if let imageName = post.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 200)
                    .clipped()
                    .cornerRadius(8)
            }
            
            // Engagement Stats
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 14))
                    Text("\(post.likes)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("\(post.comments)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                    Text("\(post.shares)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Tag
                Text(post.tag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(post.tagColor)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Following Post Model
struct FollowingPost: Identifiable {
    let id = UUID()
    let authorName: String
    let timeAgo: String
    let title: String
    let content: String
    let question: String
    let tag: String
    let tagColor: Color
    let imageName: String?
    let likes: Int
    let comments: Int
    let shares: Int
    let isFollowing: Bool
}

// MARK: - Sample Following Posts
let sampleFollowingPosts = [
    FollowingPost(
        authorName: "Sarah Chen",
        timeAgo: "2 hours ago",
        title: "Just finished an amazing coffee chat with a senior engineer at Google!",
        content: "We discussed career growth, technical challenges, and the future of AI in software development. The key takeaway: always be curious and never stop learning.",
        question: "What's your best coffee chat experience?",
        tag: "Networking",
        tagColor: Color(red: 0.4, green: 0.2, blue: 0.1),
        imageName: nil,
        likes: 24,
        comments: 8,
        shares: 3,
        isFollowing: true
    ),
    FollowingPost(
        authorName: "Mike Rodriguez",
        timeAgo: "5 hours ago",
        title: "5 productivity tools that changed my work life",
        content: "1. Notion for project management\n2. Calendly for scheduling\n3. Grammarly for writing\n4. Loom for screen recording\n5. Slack for team communication",
        question: "What tools do you use to stay productive?",
        tag: "Productivity",
        tagColor: .purple,
        imageName: nil,
        likes: 18,
        comments: 12,
        shares: 7,
        isFollowing: true
    ),
    FollowingPost(
        authorName: "Emma Wilson",
        timeAgo: "1 day ago",
        title: "The importance of work-life balance in tech",
        content: "After burning out last year, I've learned that sustainable success comes from balance. Here's what I do: set boundaries, take breaks, and prioritize mental health.",
        question: "How do you maintain work-life balance?",
        tag: "Wellness",
        tagColor: .green,
        imageName: nil,
        likes: 32,
        comments: 15,
        shares: 9,
        isFollowing: true
    ),
    FollowingPost(
        authorName: "Alex Kim",
        timeAgo: "2 days ago",
        title: "Remote work tips from 3 years of experience",
        content: "Create a dedicated workspace, maintain regular hours, over-communicate with your team, and don't forget to take breaks. Remote work can be amazing if done right!",
        question: "What's your biggest remote work challenge?",
        tag: "Remote Work",
        tagColor: .blue,
        imageName: nil,
        likes: 41,
        comments: 22,
        shares: 11,
        isFollowing: false
    )
]

// MARK: - Preview
struct FollowingView_Previews: PreviewProvider {
    static var previews: some View {
        FollowingView()
    }
}
