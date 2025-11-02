import SwiftUI

struct ChatInterfaceView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @StateObject private var aiService = GeminiAIService.shared
    @State private var chatSessions: [ChatSession] = []
    @State private var selectedSession: ChatSession?
    @State private var messageText = ""
    @State private var showingAISuggestions = false
    @State private var currentAISuggestions: [AISuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var isLoadingMatches = true
    
    var body: some View {
        VStack(spacing: 0) {
            if let session = selectedSession {
                chatView(for: session)
            } else {
                chatListView
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("AI Assistant") {
                    showingAISuggestions.toggle()
                }
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
        .onAppear {
            loadChatSessions()
        }
        .refreshable {
            await loadChatSessionsFromDatabase()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToChat"))) { notification in
            // 当收到导航到 Chat 的通知时，刷新匹配列表并自动选择匹配的用户
            Task {
                // 重新加载匹配列表
                await loadChatSessionsFromDatabase()
                
                // 如果有 matchedUserId，自动打开与该用户的聊天
                if let userInfo = notification.userInfo,
                   let matchedUserId = userInfo["matchedUserId"] as? String {
                    
                    // 等待数据加载完成后再选择会话
                    await MainActor.run {
                        // 由于我们按时间排序，新匹配的会话应该在第一位
                        // 或者通过用户名匹配（match.matchedUserName 应该对应 ChatUser.name）
                        if let matchedSession = chatSessions.first {
                            // 选择最新的匹配（第一个）
                            selectedSession = matchedSession
                            loadAISuggestions(for: matchedSession.user)
                            print("✅ Auto-selected chat session with \(matchedSession.user.name)")
                        } else {
                            // 如果仍然没找到，可能数据还没加载完，延迟再试一次
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                Task {
                                    await loadChatSessionsFromDatabase()
                                    await MainActor.run {
                                        if !chatSessions.isEmpty {
                                            selectedSession = chatSessions.first
                                            if let firstSession = chatSessions.first {
                                                loadAISuggestions(for: firstSession.user)
                                                print("✅ Auto-selected first chat session after reload: \(firstSession.user.name)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // 如果没有 matchedUserId，只是刷新列表
                    await MainActor.run {
                        if !chatSessions.isEmpty && selectedSession == nil {
                            selectedSession = chatSessions.first
                            if let firstSession = chatSessions.first {
                                loadAISuggestions(for: firstSession.user)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAISuggestions) {
            if let session = selectedSession {
                AISuggestionsView(
                    user: session.user,
                    suggestions: currentAISuggestions,
                    isLoading: isLoadingSuggestions,
                    onSuggestionSelected: { suggestion in
                        sendMessage(suggestion.content)
                        showingAISuggestions = false
                    },
                    onRefresh: {
                        loadAISuggestions(for: session.user)
                    }
                )
            }
        }
    }
    
    private var chatListView: some View {
        VStack {
            if isLoadingMatches {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chatSessions.isEmpty {
                emptyStateView
            } else {
                List(chatSessions) { session in
                    ChatSessionRowView(session: session) {
                        selectedSession = session
                        loadAISuggestions(for: session.user)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text("No Chats Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("Start swiping to find your perfect match and begin chatting!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Start Matching") {
                // Navigate to matches
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color(red: 0.4, green: 0.2, blue: 0.1))
            .cornerRadius(25)
        }
        .padding(40)
    }
    
    private func chatView(for session: ChatSession) -> some View {
        VStack(spacing: 0) {
            // Chat Header
            chatHeaderView(session: session)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(session.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: session.messages.count) { _ in
                    if let lastMessage = session.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // AI Suggestions Bar
            if !currentAISuggestions.isEmpty {
                aiSuggestionsBar
            }
            
            // Message Input
            messageInputView
        }
    }
    
    private func chatHeaderView(session: ChatSession) -> some View {
        HStack {
            Button(action: {
                selectedSession = nil
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            // User Info with match indicator
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: session.user.avatar)
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    // Match indicator
                    if session.user.isMatched {
                        ZStack {
                            Circle()
                                .fill(session.user.matchType.gradient)
                                .frame(width: 16, height: 16)
                            
                            Image(systemName: session.user.matchType.icon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 3, y: 3)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(session.user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        // Match type indicator
                        if session.user.isMatched {
                            HStack(spacing: 4) {
                                Image(systemName: session.user.matchType.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(session.user.matchType.color)
                                
                                Text(session.user.matchType.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(session.user.matchType.color)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(session.user.matchType.color.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(session.user.isOnline ? .green : .gray)
                            .frame(width: 8, height: 8)
                        
                        Text(session.user.isOnline ? "Online" : "Offline")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        // Match date
                        if session.user.isMatched, let matchDate = session.user.matchDate {
                            Text("• Matched on \(formatMatchDate(matchDate))")
                                .font(.system(size: 12))
                                .foregroundColor(session.user.matchType.color)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                loadAISuggestions(for: session.user)
                showingAISuggestions = true
            }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    private func formatMatchDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
    
    private var aiSuggestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(currentAISuggestions.prefix(3)) { suggestion in
                    Button(action: {
                        sendMessage(suggestion.content)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: suggestion.category.icon)
                                .font(.system(size: 12))
                                .foregroundColor(suggestion.category.color)
                            
                            Text(suggestion.content)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(suggestion.category.color)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(suggestion.category.color.opacity(0.1))
                        .cornerRadius(15)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
    
    private var messageInputView: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
            
            Button(action: {
                sendMessage(messageText)
                messageText = ""
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(messageText.isEmpty ? Color.gray : Color(red: 0.4, green: 0.2, blue: 0.1))
                    .clipShape(Circle())
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    private func loadChatSessions() {
        Task {
            await loadChatSessionsFromDatabase()
        }
    }
    
    @MainActor
    private func loadChatSessionsFromDatabase() async {
        guard let currentUser = authManager.currentUser else {
            isLoadingMatches = false
            chatSessions = []
            return
        }
        
        isLoadingMatches = true
        
        do {
            // 从 Supabase 获取活跃的匹配
            let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
            
            var sessions: [ChatSession] = []
            
            for match in matches {
                // 确定对方用户ID（当前用户可能是 user_id 也可能是 matched_user_id）
                let matchedUserId: String
                let matchedUserName: String
                
                if match.userId == currentUser.id {
                    matchedUserId = match.matchedUserId
                    matchedUserName = match.matchedUserName
                } else {
                    matchedUserId = match.userId
                    // 如果当前用户是 matched_user_id，需要获取对方的姓名
                    if let profile = try? await supabaseService.getProfile(userId: match.userId) {
                        matchedUserName = profile.coreIdentity.name
                    } else {
                        matchedUserName = "Unknown User"
                    }
                }
                
                var matchedUserProfile: BrewNetProfile? = nil
                if let profile = try? await supabaseService.getProfile(userId: matchedUserId) {
                    matchedUserProfile = profile.toBrewNetProfile()
                }
                
                // 解析匹配时间
                let dateFormatter = ISO8601DateFormatter()
                let matchDate = dateFormatter.date(from: match.createdAt)
                
                // 创建 ChatUser（使用系统图标作为 avatar 的占位符，实际应使用图片 URL）
                let avatarIcon: String
                if let profileImage = matchedUserProfile?.coreIdentity.profileImage, !profileImage.isEmpty {
                    // 如果有图片 URL，暂时仍使用系统图标（可以后续实现图片加载）
                    avatarIcon = "person.circle.fill"
                } else {
                    avatarIcon = "person.circle.fill"
                }
                
                let chatUser = ChatUser(
                    name: matchedUserName,
                    avatar: avatarIcon,
                    isOnline: false, // 可以根据需要实现在线状态检查
                    lastSeen: matchDate ?? Date(),
                    interests: matchedUserProfile?.personalitySocial.hobbies ?? [],
                    bio: matchedUserProfile?.coreIdentity.bio ?? "",
                    isMatched: true,
                    matchDate: matchDate,
                    matchType: .mutual // invitation_based 对应 mutual
                )
                
                // 创建 ChatSession（暂时使用空消息列表，后续可以从 messages 表加载）
                let session = ChatSession(
                    user: chatUser,
                    messages: [], // 可以从数据库加载历史消息
                    aiSuggestions: sampleAISuggestions
                )
                
                sessions.append(session)
            }
            
            chatSessions = sessions
            isLoadingMatches = false
            print("✅ Loaded \(sessions.count) matched users for chat")
            
        } catch {
            print("❌ Failed to load matches: \(error.localizedDescription)")
            isLoadingMatches = false
            chatSessions = []
        }
    }
    
    private func generateSampleMessages(for user: ChatUser) -> [ChatMessage] {
        return [
            ChatMessage(
                content: "Hello! Nice to meet you!",
                isFromUser: false,
                senderName: user.name
            ),
            ChatMessage(
                content: "Hello! Nice to meet you too!",
                isFromUser: true
            ),
            ChatMessage(
                content: "I noticed you also like \(user.interests.first ?? "technology")!",
                isFromUser: false,
                senderName: user.name
            )
        ]
    }
    
    private func loadAISuggestions(for user: ChatUser) {
        isLoadingSuggestions = true
        
        Task {
            let suggestions = await aiService.generateIceBreakerTopics(for: user)
            
            await MainActor.run {
                currentAISuggestions = suggestions
                isLoadingSuggestions = false
            }
        }
    }
    
    private func sendMessage(_ content: String) {
        guard !content.isEmpty, let session = selectedSession else { return }
        
        let message = ChatMessage(
            content: content,
            isFromUser: true
        )
        
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            chatSessions[index].addMessage(message)
            selectedSession = chatSessions[index]
        }
        
        // Simulate other party's reply
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            simulateReply(for: session)
        }
    }
    
    private func simulateReply(for session: ChatSession) {
        let replies = [
            "That's interesting! Can you tell me more?",
            "I think so too!",
            "That sounds great!",
            "I'm very interested!",
            "That reminds me of...",
            "You're absolutely right!",
            "I've had similar experiences!"
        ]
        
        let reply = ChatMessage(
            content: replies.randomElement() ?? "That's interesting!",
            isFromUser: false,
            senderName: session.user.name
        )
        
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            chatSessions[index].addMessage(reply)
            selectedSession = chatSessions[index]
        }
    }
}

// MARK: - Chat Session Row View
struct ChatSessionRowView: View {
    let session: ChatSession
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with match indicator
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: session.user.avatar)
                        .font(.system(size: 50))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    // Match indicator
                    if session.user.isMatched {
                        ZStack {
                            Circle()
                                .fill(session.user.matchType.gradient)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: session.user.matchType.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 5, y: 5)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        // Match type badge
                        if session.user.isMatched {
                            matchTypeBadge
                        }
                        
                        Spacer()
                        
                        Text(formatTime(session.lastMessageAt))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Text(session.messages.last?.content ?? "Start chatting...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    HStack {
                        Circle()
                            .fill(session.user.isOnline ? .green : .gray)
                            .frame(width: 8, height: 8)
                        
                        Text(session.user.isOnline ? "Online" : "Offline")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        // Match date
                        if session.user.isMatched, let matchDate = session.user.matchDate {
                            Text("• Matched on \(formatMatchDate(matchDate))")
                                .font(.system(size: 12))
                                .foregroundColor(session.user.matchType.color)
                        }
                        
                        Spacer()
                        
                        if !session.messages.isEmpty {
                            Text("\(session.messages.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(session.user.isMatched ? session.user.matchType.color : Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var matchTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: session.user.matchType.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            
            Text(session.user.matchType.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(session.user.matchType.gradient)
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatMatchDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Message Bubble View
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
                messageBubble
            } else {
                messageBubble
                Spacer()
            }
        }
    }
    
    private var messageBubble: some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
            if !message.isFromUser, let senderName = message.senderName {
                Text(senderName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
            }
            
            Text(message.content)
                .font(.system(size: 16))
                .foregroundColor(message.isFromUser ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    message.isFromUser
                        ? Color(red: 0.4, green: 0.2, blue: 0.1)
                        : Color.gray.opacity(0.1)
                )
                .cornerRadius(20, corners: message.isFromUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            Text(formatTime(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - AI Suggestions View
struct AISuggestionsView: View {
    let user: ChatUser
    let suggestions: [AISuggestion]
    let isLoading: Bool
    let onSuggestionSelected: (AISuggestion) -> Void
    let onRefresh: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("AI Ice Breaker")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Spacer()
                    
                    Button("Refresh") {
                        onRefresh()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                
                // Suggestions
                if isLoading {
                    loadingView
                } else {
                    suggestionsView
                }
            }
            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.1)))
                .scaleEffect(1.2)
            
            Text("AI is generating ice breaker topics...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var suggestionsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(SuggestionCategory.allCases, id: \.self) { category in
                    let categorySuggestions = suggestions.filter { $0.category == category }
                    
                    if !categorySuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                    .font(.system(size: 16))
                                
                                Text(category.displayName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                Spacer()
                            }
                            
                            ForEach(categorySuggestions) { suggestion in
                                suggestionCard(suggestion)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
    
    private func suggestionCard(_ suggestion: AISuggestion) -> some View {
        Button(action: {
            onSuggestionSelected(suggestion)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(suggestion.content)
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Image(systemName: suggestion.category.icon)
                            .font(.system(size: 12))
                            .foregroundColor(suggestion.category.color)
                        
                        Text(suggestion.category.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(suggestion.category.color)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(suggestion.category.color)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct ChatInterfaceView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInterfaceView()
    }
}
