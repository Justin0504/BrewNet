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
    @State private var showingProfileCard = false
    @State private var displayedProfile: BrewNetProfile?
    @State private var isLoadingProfile = false
    
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
        .sheet(isPresented: $showingProfileCard) {
            if isLoadingProfile {
                NavigationView {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.1)))
                            .scaleEffect(1.2)
                        Text("Loading profile...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                showingProfileCard = false
                            }
                        }
                    }
                }
            } else if let profile = displayedProfile {
                ProfileCardSheetView(profile: profile)
            } else {
                NavigationView {
                    VStack(spacing: 20) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Profile not available")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        Text("Unable to load profile information")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingProfileCard = false
                            }
                        }
                    }
                }
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
            
            // User Info with match indicator - Clickable
            Button(action: {
                print("🔘 Button tapped for user: \(session.user.name)")
                loadProfile(for: session.user)
            }) {
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
                    
                    Spacer()
                }
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(PlainButtonStyle())
            
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
            var processedUserIds = Set<String>() // 用于去重，确保每个匹配用户只显示一次
            
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
                        matchedUserName = match.matchedUserName
                    }
                }
                
                // 过滤掉自己：确保匹配的用户不是当前用户
                if matchedUserId == currentUser.id {
                    print("⚠️ Skipping self match: \(matchedUserId)")
                    continue
                }
                
                // 去重：如果这个用户已经在列表中，跳过
                if processedUserIds.contains(matchedUserId) {
                    print("⚠️ Skipping duplicate match for user: \(matchedUserId)")
                    continue
                }
                processedUserIds.insert(matchedUserId)
                
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
            
            // 按匹配时间排序，最新的在前面
            sessions.sort { session1, session2 in
                let date1 = session1.user.matchDate ?? Date.distantPast
                let date2 = session2.user.matchDate ?? Date.distantPast
                return date1 > date2
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
    
    private func loadProfile(for user: ChatUser) {
        print("👆 Profile card clicked for user: \(user.name)")
        
        // If no userId, try to find user by name or show a default profile for testing
        if let userId = user.userId {
            print("📋 Loading profile for userId: \(userId)")
            isLoadingProfile = true
            showingProfileCard = true
            
            Task {
                do {
                    if let supabaseProfile = try await supabaseService.getProfile(userId: userId) {
                        let brewNetProfile = supabaseProfile.toBrewNetProfile()
                        
                        await MainActor.run {
                            displayedProfile = brewNetProfile
                            isLoadingProfile = false
                            print("✅ Profile loaded successfully")
                        }
                    } else {
                        await MainActor.run {
                            isLoadingProfile = false
                            showingProfileCard = false
                            print("ℹ️ No profile found for user: \(userId)")
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoadingProfile = false
                        showingProfileCard = false
                        print("❌ Failed to load profile: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // No userId - create a test profile for demo purposes
            print("⚠️ No userId available for user: \(user.name), creating demo profile")
            let demoProfile = createDemoProfile(for: user)
            displayedProfile = demoProfile
            showingProfileCard = true
        }
    }
    
    // Create a demo profile for users without userId (for testing)
    private func createDemoProfile(for user: ChatUser) -> BrewNetProfile {
        let now = ISO8601DateFormatter().string(from: Date())
        let demoUserId = UUID().uuidString
        
        return BrewNetProfile(
            id: UUID().uuidString,
            userId: demoUserId,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: user.name,
                email: "\(user.name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
                phoneNumber: nil,
                profileImage: nil,
                bio: user.bio.isEmpty ? "Welcome to my profile!" : user.bio,
                pronouns: nil,
                location: nil,
                personalWebsite: nil,
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: TimeZone.current.identifier,
                availableTimeslot: AvailableTimeslot.createDefault()
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: nil,
                jobTitle: nil,
                industry: user.interests.first ?? "Technology",
                experienceLevel: .mid,
                education: nil,
                yearsOfExperience: 3.0,
                careerStage: .midLevel,
                skills: user.interests,
                certifications: [],
                languagesSpoken: ["English"],
                workExperiences: []
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .connectShare,
                selectedSubIntentions: [],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .either,
                availableTimeslot: AvailableTimeslot.createDefault(),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: ["Innovation", "Collaboration"],
                hobbies: user.interests,
                preferredMeetingVibe: .casual,
                selfIntroduction: user.bio.isEmpty ? "Hi! I'm \(user.name). Let's connect!" : user.bio
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .unverified,
                dataSharingConsent: false,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
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

// MARK: - Profile Card Sheet View
struct ProfileCardSheetView: View {
    let profile: BrewNetProfile
    @Environment(\.presentationMode) var presentationMode
    
    // Since this is shown in chat, the users are connected/matched
    private let isConnection = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                // Profile Card Content (non-swipeable version)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Level 1: Core Information Area
                        level1CoreInfoView
                        
                        // Level 2: Matching Clues
                        level2MatchingCluesView
                        
                        // Level 3: Deep Understanding
                        level3DeepUnderstandingView
                    }
                }
            }
            .navigationTitle(profile.coreIdentity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
        }
    }
    
    // MARK: - Level 1: Core Information Area
    private var level1CoreInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Image and Name Section
            HStack(alignment: .top, spacing: 16) {
                // Profile Image
                profileImageView
                
                // Name and Pronouns
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .lineLimit(nil)
                    
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                    }
                }
                
                Spacer()
            }
            
            // Professional Info
            if shouldShowCompany {
                HStack(spacing: 8) {
                    if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                        Text(jobTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                        
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            Text("@")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            // Industry and Experience Level
            HStack(spacing: 8) {
                if let industry = profile.professionalBackground.industry, !industry.isEmpty {
                    Text(industry)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(nil)
                    
                    if profile.professionalBackground.experienceLevel != .entry {
                        Text("·")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text(profile.professionalBackground.experienceLevel.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Networking Intention Badge
            NetworkingIntentionBadgeView(intention: profile.networkingIntention.selectedIntention)
            
            // Preferred Chat Format and Time Slot Summary
            if shouldShowTimeslot {
                HStack(spacing: 8) {
                    Image(systemName: chatFormatIcon)
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text(profile.networkingPreferences.preferredChatFormat.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text("|")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Text(profile.networkingPreferences.availableTimeslot.formattedSummary())
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    private var profileImageView: some View {
        ZStack {
            if let imageUrl = profile.coreIdentity.profileImage, !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderImageView
                    @unknown default:
                        placeholderImageView
                    }
                }
            } else {
                placeholderImageView
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 2)
        )
    }
    
    private var placeholderImageView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.4, blue: 0.2),
                Color(red: 0.4, green: 0.2, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        )
    }
    
    private var chatFormatIcon: String {
        switch profile.networkingPreferences.preferredChatFormat {
        case .virtual:
            return "video.fill"
        case .inPerson:
            return "person.2.fill"
        case .either:
            return "arrow.left.right"
        }
    }
    
    // MARK: - Level 2: Matching Clues
    private var level2MatchingCluesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // Sub-Intentions
            if !profile.networkingIntention.selectedSubIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("What I'm Looking For")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.selectedSubIntentions, id: \.self) { subIntention in
                            Text(subIntention.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Skills
            if shouldShowSkills && !profile.professionalBackground.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Skills & Expertise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Values
            if !profile.personalitySocial.valuesTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Vibe & Values")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.personalitySocial.valuesTags, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Hobbies & Interests
            if shouldShowInterests && !profile.personalitySocial.hobbies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Interests")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.personalitySocial.hobbies, id: \.self) { hobby in
                                Text(hobby)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            
            // Preferred Meeting Vibe
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Meeting Vibe:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    Text(profile.personalitySocial.preferredMeetingVibe.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Level 3: Deep Understanding
    private var level3DeepUnderstandingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // Self Introduction
            if let selfIntro = profile.personalitySocial.selfIntroduction, !selfIntro.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("About Me")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    Text(selfIntro)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            
            // Education
            if let education = profile.professionalBackground.education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Education")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    Text(education)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            
            // Work Experience (summary)
            if !profile.professionalBackground.workExperiences.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Experience")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ForEach(profile.professionalBackground.workExperiences.prefix(3), id: \.id) { workExp in
                        WorkExperienceRowView(workExp: workExp)
                    }
                    
                    if let yearsOfExp = profile.professionalBackground.yearsOfExperience {
                        Text("Total: \(String(format: "%.1f", yearsOfExp)) years of experience")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            }
            
            // Personal Website
            if let website = profile.coreIdentity.personalWebsite, !website.isEmpty,
               let websiteUrl = URL(string: website) {
                Link(destination: websiteUrl) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("View Portfolio")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Location
            if shouldShowLocation, let location = profile.coreIdentity.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Text(location)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 30)
        .background(Color.white)
    }
    
    // MARK: - Privacy Visibility Checks
    private var shouldShowCompany: Bool {
        profile.privacyTrust.visibilitySettings.company.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowSkills: Bool {
        profile.privacyTrust.visibilitySettings.skills.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowInterests: Bool {
        profile.privacyTrust.visibilitySettings.interests.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowLocation: Bool {
        profile.privacyTrust.visibilitySettings.location.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowTimeslot: Bool {
        profile.privacyTrust.visibilitySettings.timeslot.isVisible(isConnection: isConnection)
    }
}

// MARK: - Preview
struct ChatInterfaceView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInterfaceView()
    }
}
