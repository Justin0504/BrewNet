import SwiftUI

struct AnonymousZoneView: View {
    @State private var searchText = ""
    @State private var posts: [AnonymousPost] = sampleAnonymousPosts
    @State private var showingCreatePost = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search anonymous posts", text: $searchText)
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
            
            // Anonymous Zone Header
            HStack {
                Image(systemName: "eye.slash.fill")
                    .foregroundColor(.orange)
                Text("Anonymous Zone")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                Spacer()
                Text("Your identity is protected")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Posts Feed
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(posts) { post in
                        AnonymousPostCardView(post: post)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .sheet(isPresented: $showingCreatePost) {
            CreateAnonymousPostView()
        }
    }
}

// MARK: - Anonymous Post Card View
struct AnonymousPostCardView: View {
    let post: AnonymousPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Anonymous User Info
            HStack {
                // Anonymous Avatar
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anonymous User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    Text(post.timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Anonymous indicator
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("Anonymous")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
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

// MARK: - Create Anonymous Post View
struct CreateAnonymousPostView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var content = ""
    @State private var question = ""
    @State private var selectedTag = "General"
    
    let tags = ["General", "Career", "Workplace", "Tech", "Personal", "Advice"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Anonymous Notice
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.orange)
                    Text("Your post will be completely anonymous")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Form
                VStack(spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        TextField("Enter post title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        TextField("Share your thoughts...", text: $content, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(5...10)
                    }
                    
                    // Question
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Question (Optional)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        TextField("Ask a question to engage others", text: $question)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Tag Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Picker("Category", selection: $selectedTag) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag).tag(tag)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Create Anonymous Post")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Post") {
                    // Post action
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

// MARK: - Anonymous Post Model
struct AnonymousPost: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let question: String
    let tag: String
    let tagColor: Color
    let imageName: String?
    let likes: Int
    let comments: Int
    let shares: Int
    let timeAgo: String
}

// MARK: - Sample Anonymous Posts
let sampleAnonymousPosts = [
    AnonymousPost(
        title: "My manager is toxic but I need this job",
        content: "I've been dealing with a really difficult manager for 6 months. They constantly criticize my work in front of others and take credit for my ideas. I need this job for financial reasons but it's affecting my mental health.",
        question: "How do you deal with toxic managers?",
        tag: "Workplace",
        tagColor: .red,
        imageName: nil,
        likes: 45,
        comments: 23,
        shares: 8,
        timeAgo: "3 hours ago"
    ),
    AnonymousPost(
        title: "Should I quit my stable job to start a business?",
        content: "I have a good salary and benefits, but I'm not passionate about my work. I have a business idea that I'm excited about, but I'm scared of the financial risk.",
        question: "What would you do in my situation?",
        tag: "Career",
        tagColor: .blue,
        imageName: nil,
        likes: 32,
        comments: 18,
        shares: 12,
        timeAgo: "6 hours ago"
    ),
    AnonymousPost(
        title: "I feel like I'm falling behind in tech",
        content: "New technologies are coming out so fast. I feel like I can't keep up with all the changes. My colleagues seem to know everything and I'm struggling to stay current.",
        question: "How do you stay updated with tech trends?",
        tag: "Tech",
        tagColor: .purple,
        imageName: nil,
        likes: 28,
        comments: 15,
        shares: 6,
        timeAgo: "1 day ago"
    ),
    AnonymousPost(
        title: "Workplace discrimination - what should I do?",
        content: "I've been experiencing subtle discrimination at work based on my background. It's not overt, but I notice I'm treated differently than my colleagues. I'm not sure if I should speak up or just try to ignore it.",
        question: "Has anyone dealt with similar situations?",
        tag: "Personal",
        tagColor: .orange,
        imageName: nil,
        likes: 67,
        comments: 34,
        shares: 19,
        timeAgo: "2 days ago"
    )
]

// MARK: - Preview
struct AnonymousZoneView_Previews: PreviewProvider {
    static var previews: some View {
        AnonymousZoneView()
    }
}
