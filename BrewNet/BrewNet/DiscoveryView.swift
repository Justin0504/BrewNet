import SwiftUI

struct DiscoveryView: View {
    @State private var searchText = ""
    @State private var posts: [Post] = samplePosts
    @State private var showingCreatePost = false
    
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
        }
    }
}

// MARK: - Post Card View
struct PostCardView: View {
    let post: Post
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var likeCount = Int.random(in: 5...50)
    
    var body: some View {
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
                        .background(post.tagColor)
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
        .background(post.backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Post Model
struct Post: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let question: String
    let tag: String
    let tagColor: Color
    let backgroundColor: Color
}

// MARK: - Sample Data
let samplePosts = [
    Post(
        title: "After leading people in big companies, I found that this kind of 'junior' is destined not to be promoted",
        content: "",
        question: "What kind of talent can be promoted in big companies?",
        tag: "Experience Sharing",
        tagColor: .green,
        backgroundColor: Color.white.opacity(0.8)
    ),
    Post(
        title: "◆◆ Standard Process ◆◆",
        content: "1. Thank him for his time\n2. Introduce yourself\n3. Then the other party will usually take the lead to introduce their experience\n4. Thank him for his introduction",
        question: "How to do a coffee chat?",
        tag: "Experience Sharing",
        tagColor: .green,
        backgroundColor: Color.white.opacity(0.8)
    ),
    Post(
        title: "First wave of employees replaced by AI recount personal experience of mass layoffs",
        content: "\"Always be prepared to leave your employer, because they are prepared to leave you.\" Brothers, this is it. I was just informed by my boss and HR that my entire career has been replaced by AI.",
        question: "AIGC layoff wave?",
        tag: "Trend Direction",
        tagColor: .blue,
        backgroundColor: Color.white
    ),
    Post(
        title: "5 Workplace efficiency improvement small tools",
        content: "",
        question: "What tools can improve workplace efficiency?!",
        tag: "Resource Library",
        tagColor: .purple,
        backgroundColor: Color.white
    ),
    Post(
        title: "Many advertising companies facing layoffs",
        content: "",
        question: "",
        tag: "Industry News",
        tagColor: .orange,
        backgroundColor: Color.white
    ),
    Post(
        title: "Coffee Chat Tips",
        content: "Learn how to network effectively through coffee meetings and build meaningful professional relationships.",
        question: "How to make the most of coffee chats?",
        tag: "Networking",
        tagColor: Color(red: 0.4, green: 0.2, blue: 0.1),
        backgroundColor: Color.white
    )
]

// MARK: - Preview
struct DiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveryView()
    }
}
