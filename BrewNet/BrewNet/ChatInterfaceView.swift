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
    @State private var messageRefreshTimer: Timer?
    @State private var cachedChatSessions: [ChatSession] = [] // 缓存数据
    @State private var lastChatLoadTime: Date? = nil // 记录上次加载时间
    @State private var userIdToFullProfileMap: [String: BrewNetProfile] = [:] // 存储完整的 profile 数据
    @State private var avatarRefreshVersions: [String: Int] = [:] // 头像刷新版本号，用于强制刷新
    @State private var showingUnmatchConfirmAlert = false
    @State private var sessionToUnmatch: ChatSession? = nil
    @State private var scrollToBottomId: UUID? = nil // 用于触发滚动到底部
    @State private var isAtBottom: Bool = true // 跟踪用户是否在聊天底部
    @State private var scrollViewHeight: CGFloat = 0 // ScrollView 高度
    @State private var contentHeight: CGFloat = 0 // 内容高度
    @State private var scrollOffset: CGFloat = 0 // 滚动偏移量
    @State private var isYourTurnExpanded: Bool = true // Your Turn 分类展开状态
    @State private var isTheirTurnExpanded: Bool = true // Their Turn 分类展开状态
    @State private var isHiddenExpanded: Bool = false // Hidden 分类展开状态
    @State private var showingCoffeeInviteAlert = false // 显示发送咖啡邀请的确认对话框
    @State private var showingCoffeeInviteAnimation = false // 显示发送动画
    @State private var showingCoffeeChatSchedule = false // 显示咖啡聊天日程列表
    @State private var textAnimationState: (line1: Bool, line2: Bool, question: Bool) = (false, false, false) // 文字动画状态
    
    var body: some View {
        mainContent
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onAppear {
                loadChatSessions()
                startMessageRefreshTimer()
            }
            .onDisappear {
            stopMessageRefreshTimer()
            // 先尝试从持久化缓存加载
            loadCachedChatSessionsFromStorage()
            
            // 如果有缓存数据且距离上次加载不到5分钟，先显示缓存，然后后台刷新
            if !cachedChatSessions.isEmpty, let lastLoad = lastChatLoadTime, Date().timeIntervalSince(lastLoad) < 300 {
                // 验证缓存数据：过滤掉可能有问题的会话
                guard let currentUser = authManager.currentUser else {
                    loadChatSessions()
                    return
                }
                
                let validCachedSessions = cachedChatSessions.filter { session in
                    // 确保不是自己的会话
                    if let userId = session.user.userId, userId == currentUser.id {
                        return false
                    }
                    return true
                }
                
                // 显示缓存数据（立即显示，无延迟）
                chatSessions = validCachedSessions
                isLoadingMatches = false
                print("✅ Using cached chat sessions: \(validCachedSessions.count) valid sessions (filtered from \(cachedChatSessions.count))")
                // 后台静默刷新
                Task {
                    await refreshChatSessionsSilently()
                }
            } else {
                // 首次加载或缓存过期，正常加载
                loadChatSessions()
            }
        }
        .refreshable {
            // 下拉刷新时，保持现有聊天列表显示，后台更新数据
            // 不会清空 chatSessions，避免显示空状态
            await loadChatSessionsFromDatabase()
        }
        .onChange(of: selectedSession?.id) { newSessionId in
            // 当会话切换时，重置滚动状态
            scrollToBottomId = nil
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
                        // 通过 userId 匹配会话，如果没有找到则选择最新的匹配
                        if let matchedSession = chatSessions.first(where: { $0.user.userId == matchedUserId }) {
                            // 选择匹配的会话
                            selectedSession = matchedSession
                            loadAISuggestions(for: matchedSession.user)
                            print("✅ Auto-selected chat session with \(matchedSession.user.name) (matchedUserId: \(matchedUserId))")
                        } else if let firstSession = chatSessions.first {
                            // 如果没有找到精确匹配，选择最新的匹配（第一个）
                            selectedSession = firstSession
                            loadAISuggestions(for: firstSession.user)
                            print("✅ Auto-selected first chat session: \(firstSession.user.name) (requested matchedUserId: \(matchedUserId))")
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
                let isAnalysisMode = !session.messages.isEmpty && session.messages.count >= 3
                AISuggestionsView(
                    user: session.user,
                    suggestions: currentAISuggestions,
                    isLoading: isLoadingSuggestions,
                    isAnalysisMode: isAnalysisMode,
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
        .alert("Unmatch", isPresented: $showingUnmatchConfirmAlert) {
            Button("Cancel", role: .cancel) {
                sessionToUnmatch = nil
            }
            Button("Unmatch", role: .destructive) {
                if let session = sessionToUnmatch {
                    performUnmatch(session: session)
                }
                sessionToUnmatch = nil
            }
        } message: {
            if let session = sessionToUnmatch {
                Text("Are you sure you want to unmatch with \(session.user.name)? This action cannot be undone.")
            }
        }
        .overlay {
            // Custom Coffee Chat Invitation Alert
            if showingCoffeeInviteAlert {
                customCoffeeInviteAlert
            }
        }
        .overlay {
            // Coffee Chat Invitation Animation
            if showingCoffeeInviteAnimation {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .scaleEffect(showingCoffeeInviteAnimation ? 1.2 : 0.8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6).repeatCount(2, autoreverses: true), value: showingCoffeeInviteAnimation)
                        
                        Text("Invitation Sent!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    .padding(40)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                // 暂时不添加任何功能
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            // Background - 与其他板块保持一致
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let session = selectedSession {
                    chatView(for: session)
                } else {
                    chatListView
                }
            }
        }
    }
    
    // MARK: - Custom Coffee Invite Alert
    private var customCoffeeInviteAlert: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showingCoffeeInviteAlert = false
                    }
                }
            
            // 自定义Alert卡片
            ZStack(alignment: .topTrailing) {
                // 主内容
                VStack(spacing: 0) {
                    // 渐变背景区域（包含slogan）
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.9, blue: 0.85),
                                Color(red: 0.98, green: 0.96, blue: 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // 艺术字 Slogan
                        VStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("BrewNet brings us together,")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    .opacity(textAnimationState.line1 ? 1.0 : 0.0)
                                    .offset(y: textAnimationState.line1 ? 0 : 10)
                                
                                Text("Conversation makes it better.")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.25))
                                    .opacity(textAnimationState.line2 ? 1.0 : 0.0)
                                    .offset(y: textAnimationState.line2 ? 0 : 10)
                            }
                            
                            if let session = selectedSession {
                                Text("Do you want to invite \(session.user.name) to a coffee chat?")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                    .multilineTextAlignment(.center)
                                    .opacity(textAnimationState.question ? 1.0 : 0.0)
                                    .offset(y: textAnimationState.question ? 0 : 10)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 20)
                        .onAppear {
                            // 重置动画状态
                            textAnimationState = (false, false, false)
                            
                            // 依次触发动画
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                    textAnimationState.line1 = true
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                    textAnimationState.line2 = true
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                    textAnimationState.question = true
                                }
                            }
                        }
                        .onChange(of: showingCoffeeInviteAlert) { newValue in
                            if !newValue {
                                // 对话框关闭时重置动画状态
                                textAnimationState = (false, false, false)
                            }
                        }
                    }
                    
                    // 按钮区域
                    HStack(spacing: 10) {
                        // Cancel 按钮
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingCoffeeInviteAlert = false
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.98, green: 0.96, blue: 0.94),
                                            Color(red: 0.95, green: 0.92, blue: 0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.8, green: 0.7, blue: 0.6),
                                                    Color(red: 0.7, green: 0.6, blue: 0.5)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        
                        // Send 按钮
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showingCoffeeInviteAlert = false
                            }
                            sendCoffeeChatInvitation()
                        }) {
                            Text("Send")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.6, green: 0.4, blue: 0.2),
                                            Color(red: 0.4, green: 0.2, blue: 0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
                .frame(width: 320)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5),
                                    Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .opacity(showingCoffeeInviteAlert ? 1.0 : 0.0)
                
                // 右上角咖啡图标装饰
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.6))
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    .opacity(showingCoffeeInviteAlert ? 1.0 : 0.0)
            }
        }
    }
    
    // MARK: - 分类计算属性
    /// Your Turn: 最后一条消息是对方发送的（用户还没回复）
    private var yourTurnSessions: [ChatSession] {
        chatSessions.filter { session in
            !session.isHidden && !session.lastMessageIsFromUser
        }
    }
    
    /// Their Turn: 最后一条消息是用户发送的（对方还没回复）
    private var theirTurnSessions: [ChatSession] {
        chatSessions.filter { session in
            !session.isHidden && session.lastMessageIsFromUser
        }
    }
    
    /// Hidden: 被归档的聊天
    private var hiddenSessions: [ChatSession] {
        chatSessions.filter { session in
            session.isHidden
        }
    }
    
    // MARK: - 未读消息总数（排除 Hidden）
    private var totalUnreadCount: Int {
        chatSessions.filter { !$0.isHidden }.reduce(0) { $0 + $1.unreadCount }
    }
    
    private var chatListView: some View {
        VStack {
            if isLoadingMatches && chatSessions.isEmpty {
                // 只有在首次加载且没有聊天时才显示加载动画
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if chatSessions.isEmpty && !isLoadingMatches {
                // 只有在确实没有任何聊天且不在加载状态时才显示空状态
                emptyStateView
            } else {
                // 有聊天记录时，显示分类列表
                List {
                    // Your Turn 分类
                    if !yourTurnSessions.isEmpty {
                        categorySection(
                            title: "Your Turn",
                            count: yourTurnSessions.count,
                            isExpanded: $isYourTurnExpanded,
                            sessions: yourTurnSessions
                        )
                    }
                    
                    // Their Turn 分类
                    if !theirTurnSessions.isEmpty {
                        categorySection(
                            title: "Their Turn",
                            count: theirTurnSessions.count,
                            isExpanded: $isTheirTurnExpanded,
                            sessions: theirTurnSessions
                        )
                    }
                    
                    // Hidden 分类
                    if !hiddenSessions.isEmpty {
                        categorySection(
                            title: "Hidden",
                            count: hiddenSessions.count,
                            isExpanded: $isHiddenExpanded,
                            sessions: hiddenSessions,
                            isHiddenCategory: true
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 分类章节视图
    private func categorySection(
        title: String,
        count: Int,
        isExpanded: Binding<Bool>,
        sessions: [ChatSession],
        isHiddenCategory: Bool = false
    ) -> some View {
        Section {
            // 聊天列表（展开时显示）
            if isExpanded.wrappedValue {
                ForEach(sessions) { session in
                    ChatSessionRowView(
                        session: session,
                        onTap: {
                            selectSession(session)
                        },
                        onUnmatch: {
                            handleUnmatchForSession(session)
                        },
                        onHide: isHiddenCategory ? nil : {
                            handleHideSession(session)
                        },
                        onUnhide: isHiddenCategory ? {
                            handleUnhideSession(session)
                        } : nil
                    )
                    .listRowBackground(Color.clear)
                }
            }
        } header: {
            // 分类标题（可点击展开/收起）
            Button(action: {
                withAnimation {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text("\(title) (\(count))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
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
                // 发送通知切换到 Matches tab
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToMatches"),
                    object: nil
                )
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
                            MessageBubbleView(message: message, session: session)
                                .environmentObject(authManager)
                                .environmentObject(supabaseService)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        GeometryReader { contentGeometry in
                            Color.clear
                                .preference(key: ScrollOffsetPreferenceKey.self, 
                                          value: contentGeometry.frame(in: .named("scroll")).minY)
                                .preference(key: ContentHeightPreferenceKey.self, 
                                          value: contentGeometry.size.height)
                        }
                    )
                    .onAppear {
                        // 在内容出现时立即滚动到底部，避免闪现顶部
                        if let lastMessage = session.messages.last {
                            // 立即尝试滚动，不等待
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            // 设置初始状态为在底部
                            isAtBottom = true
                        }
                    }
                }
                .coordinateSpace(name: "scroll")
                .background(
                    GeometryReader { scrollGeometry in
                        Color.clear
                            .preference(key: ScrollViewHeightPreferenceKey.self, 
                                      value: scrollGeometry.size.height)
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = -value
                    checkIfAtBottom()
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                    contentHeight = value
                    // 延迟检查以确保布局完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        checkIfAtBottom()
                    }
                }
                .onPreferenceChange(ScrollViewHeightPreferenceKey.self) { value in
                    scrollViewHeight = value
                    checkIfAtBottom()
                }
                .task {
                    // 使用 task 在视图出现之前就开始滚动，避免闪现顶部
                    if let lastMessage = session.messages.last {
                        // 立即尝试滚动（无延迟）
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    // 视图出现时再次确保滚动到底部（作为保险）
                    if let lastMessage = session.messages.last {
                        // 使用极短的延迟，确保视图已渲染
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        // 双重保险
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: session.id) { _ in
                    // 当会话切换时，立即滚动到底部
                    if let lastMessage = session.messages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollToBottomId) { newId in
                    // 当需要滚动时（由sendMessage或refreshMessages触发）
                    if let messageId = newId {
                        // 检查这条消息是否是自己发送的
                        let isUserMessage = session.messages.first(where: { $0.id == messageId })?.isFromUser ?? false
                        
                        // 延迟滚动，确保消息已渲染到视图
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                            // 滚动完成后，清空scrollToBottomId，避免重复触发
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                scrollToBottomId = nil
                            }
                        }
                        // 双重保险，确保滚动成功
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: session.messages.count) { newCount in
                    // 如果scrollToBottomId已设置，且最后一条消息是自己发送的，则滚动
                    if let scrollId = scrollToBottomId,
                       let lastMessage = session.messages.last,
                       lastMessage.isFromUser,
                       lastMessage.id == scrollId {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(scrollId, anchor: .bottom)
                            }
                        }
                    } else if let lastMessage = session.messages.last,
                              !lastMessage.isFromUser {
                        // 如果是别人发送的消息，且用户在底部，则自动滚动
                        if isAtBottom {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .onChange(of: session.messages.last?.id) { newMessageId in
                    // 监听最后一条消息ID的变化
                    if let lastMessage = session.messages.last,
                       !lastMessage.isFromUser,
                       let messageId = newMessageId,
                       isAtBottom {
                        // 如果是别人发送的新消息，且用户在底部，则自动滚动
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                    }
                }
                .onChange(of: selectedSession?.messages.count) { newCount in
                    // 监听消息数量变化（用于刷新消息后的滚动）
                    if let session = selectedSession,
                       let lastMessage = session.messages.last,
                       !lastMessage.isFromUser,
                       isAtBottom {
                        // 如果是别人发送的新消息，且用户在底部，则自动滚动
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
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
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.88),
                                    Color(red: 0.9, green: 0.85, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .padding(.trailing, 4)
            
            // User Info with match indicator - Clickable
            Button(action: {
                print("🔘 Button tapped for user: \(session.user.name)")
                loadProfile(for: session.user)
            }) {
                HStack(spacing: 14) {
                    // 使用实时头像（如果profile map中有更新）
                    let currentAvatar = getCurrentAvatarForUser(session.user)
                    let avatarVersion = session.user.userId.flatMap { avatarRefreshVersions[$0] } ?? 0
                    
                    // 头像带渐变边框
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.9, green: 0.85, blue: 0.8),
                                        Color(red: 0.85, green: 0.8, blue: 0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        AvatarView(avatarString: currentAvatar, size: 40)
                            .id("avatar-\(session.user.id)-\(currentAvatar)-v\(avatarVersion)") // 强制刷新当头像URL或版本号变化时
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.user.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        HStack(spacing: 4) {
                            // Match date
                            // if session.user.isMatched, let matchDate = session.user.matchDate {
                            //     Circle()
                            //         .fill(Color.red)
                            //         .frame(width: 4, height: 4)
                                
                            //     Text("Matched on \(formatMatchDate(matchDate))")
                            //         .font(.system(size: 12))
                            //         .foregroundColor(.red)
                            // }
                        }
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle()) // Make entire area tappable
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Coffee Chat Invitation Button
            Button(action: {
                showingCoffeeInviteAlert = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.88),
                                    Color(red: 0.9, green: 0.85, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .padding(.trailing, 6)
            
            // AI Suggestions Button
            Button(action: {
                loadAISuggestions(for: session.user)
                showingAISuggestions = true
            }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.88),
                                    Color(red: 0.9, green: 0.85, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // 主背景
                Color.white
                
                // 顶部渐变边框效果
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95).opacity(0.5),
                        Color.white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            // 底部细线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3),
                            Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .offset(y: 0.5),
            alignment: .bottom
        )
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
                .background(Color(red: 0.95, green: 0.92, blue: 0.88))
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
    
    /// 获取用户当前最新的头像（优先使用 profile map 中的最新头像）
    private func getCurrentAvatarForUser(_ user: ChatUser) -> String {
        if let userId = user.userId,
           let profile = userIdToFullProfileMap[userId],
           let newAvatar = profile.coreIdentity.profileImage,
           !newAvatar.isEmpty {
            return newAvatar
        }
        return user.avatar
    }
    
    /// 更新聊天会话的头像（当头像更新时调用）
    private func updateChatSessionsWithAvatars() {
        // 由于 ChatSession 的 user 是 let，需要重新创建整个会话
        var updatedSessions: [ChatSession] = []
        for session in chatSessions {
            if let userId = session.user.userId {
                // 获取最新的头像（从 profile map 中获取）
                var avatar = session.user.avatar
                let oldAvatar = avatar
                if let profile = userIdToFullProfileMap[userId],
                   let newAvatar = profile.coreIdentity.profileImage,
                   !newAvatar.isEmpty {
                    // 即使 URL 相同也要更新（确保显示最新数据）
                    avatar = newAvatar
                    
                    // 如果头像URL变化了，清除旧头像的缓存
                    if oldAvatar != newAvatar && (oldAvatar.hasPrefix("http://") || oldAvatar.hasPrefix("https://")) {
                        ImageCacheManager.shared.removeImage(for: oldAvatar)
                        print("   🗑️ [头像更新] 已清除旧头像缓存: \(oldAvatar)")
                    }
                    
                    // 即使 URL 相同，也清除缓存以确保显示最新图片
                    if oldAvatar == newAvatar && (newAvatar.hasPrefix("http://") || newAvatar.hasPrefix("https://")) {
                        ImageCacheManager.shared.removeImage(for: newAvatar)
                        // 增加刷新版本号，强制刷新视图
                        avatarRefreshVersions[userId] = (avatarRefreshVersions[userId] ?? 0) + 1
                        print("   🔄 [头像更新] 头像URL相同但强制刷新缓存: \(newAvatar) (版本: \(avatarRefreshVersions[userId] ?? 0))")
                    } else if oldAvatar != newAvatar {
                        // URL 变化时也更新版本号
                        avatarRefreshVersions[userId] = (avatarRefreshVersions[userId] ?? 0) + 1
                    }
                    
                    print("   ✅ [头像更新] 用户 \(userId) 头像: \(oldAvatar) -> \(newAvatar)")
                }
                
                // 创建更新后的 ChatUser
                let updatedChatUser = ChatUser(
                    name: session.user.name,
                    avatar: avatar,
                    interests: session.user.interests,
                    bio: session.user.bio,
                    isMatched: session.user.isMatched,
                    matchDate: session.user.matchDate,
                    matchType: session.user.matchType,
                    userId: session.user.userId
                )
                // 创建新的 ChatSession
                var updatedSession = ChatSession(
                    user: updatedChatUser,
                    messages: session.messages,
                    aiSuggestions: session.aiSuggestions,
                    isActive: session.isActive,
                    isHidden: session.isHidden
                )
                updatedSession.lastMessageAt = session.lastMessageAt
                updatedSessions.append(updatedSession)
            } else {
                // 如果没有 userId，保留原会话
                updatedSessions.append(session)
            }
        }
        chatSessions = updatedSessions
    }
    
    private func loadChatSessions() {
        // 如果有缓存，先显示缓存（提供即时反馈）
        if !cachedChatSessions.isEmpty {
            chatSessions = cachedChatSessions
            isLoadingMatches = false
            print("✅ Displaying cached chat sessions immediately: \(cachedChatSessions.count) sessions")
        } else {
            isLoadingMatches = true
            chatSessions = []
        }
        
        Task {
            await loadChatSessionsFromDatabase()
        }
    }
    
    // 后台静默刷新，不显示加载状态
    private func refreshChatSessionsSilently() async {
        await loadChatSessionsFromDatabase()
    }
    
    // 从持久化存储加载缓存
    private func loadCachedChatSessionsFromStorage() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "chat_sessions_cache_\(currentUser.id)"
        let timeKey = "chat_sessions_cache_time_\(currentUser.id)"
        
        // 从 UserDefaults 加载缓存
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: timeKey) as? Date,
           Date().timeIntervalSince(timestamp) < 300 { // 5分钟内有效
            
            do {
                let decoder = JSONDecoder()
                let cachedSessionsData = try decoder.decode([ChatSession].self, from: data)
                cachedChatSessions = cachedSessionsData
                lastChatLoadTime = timestamp
                print("✅ Loaded \(cachedChatSessions.count) chat sessions from persistent cache")
            } catch {
                print("⚠️ Failed to decode cached chat sessions: \(error)")
            }
        }
    }
    
    // 保存缓存到持久化存储
    private func saveCachedChatSessionsToStorage() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "chat_sessions_cache_\(currentUser.id)"
        let timeKey = "chat_sessions_cache_time_\(currentUser.id)"
        let hiddenUsersKey = "hidden_chat_users_\(currentUser.id)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(chatSessions)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            lastChatLoadTime = Date()
            cachedChatSessions = chatSessions
            
            // 保存 hidden 用户 ID 列表，供 MainView 使用
            let hiddenUserIds = chatSessions.filter { $0.isHidden }.compactMap { $0.user.userId }
            UserDefaults.standard.set(hiddenUserIds, forKey: hiddenUsersKey)
            
            print("✅ Saved \(chatSessions.count) chat sessions to persistent cache (hidden: \(hiddenUserIds.count))")
        } catch {
            print("⚠️ Failed to save cached chat sessions: \(error)")
        }
    }
    
    @MainActor
    private func loadChatSessionsFromDatabase() async {
        guard let currentUser = authManager.currentUser else {
            isLoadingMatches = false
            // 只有在确实没有任何聊天时才清空
            if chatSessions.isEmpty {
                chatSessions = []
            }
            return
        }
        
        // 保存当前聊天列表，避免刷新时显示空状态
        let previousSessions = chatSessions
        // 保存当前 hidden 会话的 userId 列表，以便在刷新后恢复 hidden 状态
        let hiddenUserIds = Set(previousSessions.filter { $0.isHidden }.compactMap { $0.user.userId })
        // 只有在首次加载（没有现有聊天记录）时才显示加载状态
        // 如果有现有聊天记录，刷新时不显示加载状态，保持列表显示
        if previousSessions.isEmpty {
            isLoadingMatches = true
        }
        
        do {
            // 从 Supabase 获取活跃的匹配
            let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
            
            print("📊 Loaded \(matches.count) matches from database for user: \(currentUser.id)")
            print("📊 Current user name: \(currentUser.name)")
            
            var sessions: [ChatSession] = []
            var processedUserIds = Set<String>() // 用于去重，确保每个匹配用户只显示一次
            
            // 第一步：快速构建基本会话信息
            // 注意：需要区分两种情况：
            // 1. match.userId == currentUser.id: 对方是 matchedUserId，名字是 matchedUserName
            // 2. match.userId != currentUser.id: 对方是 userId，需要从 profile 获取名字（matchedUserName 是当前用户自己的名字）
            var basicSessionData: [(match: SupabaseMatch, matchedUserId: String, matchedUserName: String)] = []
            
            // 先收集所有需要获取 profile 的用户 ID
            var userIdsToFetch: [String] = []
            
            for match in matches {
                let matchedUserId: String
                
                if match.userId == currentUser.id {
                    // 当前用户是 user_id，对方是 matched_user_id
                    matchedUserId = match.matchedUserId
                    
                    // 严格过滤：确保不是自己
                    if matchedUserId == currentUser.id {
                        print("⚠️ Skipping self match: \(matchedUserId) == \(currentUser.id)")
                        continue
                    }
                    
                    // 去重
                    if processedUserIds.contains(matchedUserId) {
                        print("⚠️ Skipping duplicate match for user: \(matchedUserId)")
                        continue
                    }
                    processedUserIds.insert(matchedUserId)
                    
                    // 记录需要获取 profile 的用户 ID（不使用 matchedUserName 因为可能过期）
                    if !userIdsToFetch.contains(matchedUserId) {
                        userIdsToFetch.append(matchedUserId)
                    }
                    print("✅ Match 1: Current user is user_id, matched with: \(matchedUserId) (will fetch name)")
                    basicSessionData.append((match, matchedUserId, "Loading..."))
                } else if match.matchedUserId == currentUser.id {
                    // 当前用户是 matched_user_id，对方是 user_id
                    matchedUserId = match.userId
                    
                    // 严格过滤：确保不是自己
                    if matchedUserId == currentUser.id {
                        print("⚠️ Skipping self match: \(matchedUserId) == \(currentUser.id)")
                        continue
                    }
                    
                    // 去重
                    if processedUserIds.contains(matchedUserId) {
                        print("⚠️ Skipping duplicate match for user: \(matchedUserId)")
                        continue
                    }
                    processedUserIds.insert(matchedUserId)
                    
                    // 记录需要获取 profile 的用户 ID（因为 matchedUserName 是当前用户的名字，不能用）
                    if !userIdsToFetch.contains(matchedUserId) {
                        userIdsToFetch.append(matchedUserId)
                    }
                    // 暂时使用 "Loading..." 作为占位符，后续会更新
                    print("✅ Match 2: Current user is matched_user_id, matched with: \(match.userId) (will fetch name)")
                    basicSessionData.append((match, matchedUserId, "Loading..."))
                } else {
                    // 这个 match 既不是以当前用户为 user_id，也不是以当前用户为 matched_user_id
                    // 这不应该发生，但为了安全起见，跳过它
                    print("⚠️ Skipping invalid match: user_id=\(match.userId), matched_user_id=\(match.matchedUserId), current_user=\(currentUser.id)")
                    continue
                }
            }
            
            // 并发获取所有需要的 profile（包括名字、头像、兴趣、bio）
            if !userIdsToFetch.isEmpty {
                let profileTasks = userIdsToFetch.map { userId -> Task<BrewNetProfile?, Never> in
                    Task {
                        if let supabaseProfile = try? await supabaseService.getProfile(userId: userId) {
                            return supabaseProfile.toBrewNetProfile()
                        }
                        return nil
                    }
                }
                
                // 等待所有 profile 加载完成
                var userIdToProfile: [String: BrewNetProfile] = [:]
                for (index, task) in profileTasks.enumerated() {
                    let userId = userIdsToFetch[index]
                    if let profile = await task.value {
                        userIdToProfile[userId] = profile
                    }
                }
                
                // 更新 basicSessionData 中的名字
                for (index, data) in basicSessionData.enumerated() {
                    if data.matchedUserName == "Loading..." {
                        if let profile = userIdToProfile[data.matchedUserId] {
                            basicSessionData[index] = (data.match, data.matchedUserId, profile.coreIdentity.name)
                        }
                    }
                }
                
                // 保存完整 profile 映射
                userIdToFullProfileMap = userIdToProfile
            }
            
            // 第二步：并发加载在线状态和消息（加速加载）
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            // 并发获取所有会话的消息
            let messageTasks = basicSessionData.map { data -> Task<(userId: String, messages: [ChatMessage], lastMessageTime: Date, matchDate: Date), Never> in
                Task {
                    var messages: [ChatMessage] = []
                    
                    // 正确解析匹配时间（来自 Supabase 的 created_at）
                    var matchDate = Date()
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    if let parsedDate = formatter.date(from: data.match.createdAt) {
                        matchDate = parsedDate
                        print("✅ Parsed match date: \(data.match.createdAt) -> \(matchDate)")
                    } else {
                        // 如果解析失败，尝试不带小数秒的格式
                        formatter.formatOptions = [.withInternetDateTime]
                        if let parsedDate = formatter.date(from: data.match.createdAt) {
                            matchDate = parsedDate
                            print("✅ Parsed match date (no fractional): \(data.match.createdAt) -> \(matchDate)")
                        } else {
                            print("⚠️ Failed to parse match date: \(data.match.createdAt), using current time")
                        }
                    }
                    
                    do {
                        let supabaseMessages = try await supabaseService.getMessages(
                            userId1: currentUser.id,
                            userId2: data.matchedUserId
                        )
                        
                        // 转换为 ChatMessage
                        messages = supabaseMessages.map { supabaseMessage in
                            supabaseMessage.toChatMessage(currentUserId: currentUser.id)
                        }
                    } catch {
                        print("⚠️ Failed to load messages: \(error.localizedDescription)")
                    }
                    
                    let lastMessageTime = messages.last?.timestamp ?? matchDate
                    return (data.matchedUserId, messages, lastMessageTime, matchDate)
                }
            }
            
            // 等待所有任务完成
            var userIdToMessages: [String: (messages: [ChatMessage], lastMessageTime: Date, matchDate: Date)] = [:]
            for task in messageTasks {
                let result = await task.value
                userIdToMessages[result.userId] = (result.messages, result.lastMessageTime, result.matchDate)
            }
            
            // 快速创建会话列表（使用已加载的数据）
            for data in basicSessionData {
                let match = data.match
                let matchedUserId = data.matchedUserId
                let matchedUserName = data.matchedUserName
                
                // 使用从消息任务中解析的正确匹配时间
                let messageData = userIdToMessages[matchedUserId] ?? ([], Date(), Date())
                let matchDate = messageData.matchDate // 使用正确解析的匹配时间
                
                let profile = userIdToFullProfileMap[matchedUserId]
                let avatarString = profile?.coreIdentity.profileImage ?? "person.circle.fill"
                
                let chatUser = ChatUser(
                    name: matchedUserName,
                    avatar: avatarString,
                    interests: profile?.personalitySocial.hobbies ?? [],
                    bio: profile?.coreIdentity.bio ?? "",
                    isMatched: true,
                    matchDate: matchDate, // 使用正确解析的匹配时间
                    matchType: .mutual,
                    userId: matchedUserId
                )
                
                // 检查该用户之前的会话是否是 hidden 的
                let wasHidden = hiddenUserIds.contains(matchedUserId)
                
                var session = ChatSession(
                    user: chatUser,
                    messages: messageData.messages,
                    aiSuggestions: [],
                    isActive: true,
                    isHidden: wasHidden // 保留之前的 hidden 状态
                )
                session.lastMessageAt = messageData.lastMessageTime
                
                print("✅ Created session for \(matchedUserName): matchDate=\(matchDate), isHidden=\(wasHidden)")
                
                sessions.append(session)
            }
            
            // 按最新消息时间排序，最新的在前面
            // 有消息的按最后消息时间排序，没有消息的按匹配时间排序放在后面
            sessions.sort { session1, session2 in
                let hasMessages1 = !session1.messages.isEmpty
                let hasMessages2 = !session2.messages.isEmpty
                
                // 如果两个都有消息，按最后消息时间排序
                if hasMessages1 && hasMessages2 {
                    return session1.lastMessageAt > session2.lastMessageAt
                }
                // 如果有消息的排在前面
                if hasMessages1 && !hasMessages2 {
                    return true
                }
                if !hasMessages1 && hasMessages2 {
                    return false
                }
                // 两个都没有消息，按匹配时间排序
                let date1 = session1.user.matchDate ?? Date.distantPast
                let date2 = session2.user.matchDate ?? Date.distantPast
                return date1 > date2
            }
            
            // 最终验证：确保没有自己的会话
            let filteredSessions = sessions.filter { session in
                if let userId = session.user.userId, userId == currentUser.id {
                    print("⚠️ Filtering out session with self user ID: \(userId)")
                    return false
                }
                return true
            }
            
            // 在线状态功能已移除
            
            // 显示会话列表（所有数据已加载完成）
            // 只有在成功加载后才更新 chatSessions，确保不会在刷新时清空现有列表
            chatSessions = filteredSessions
            isLoadingMatches = false
            print("✅ Loaded \(filteredSessions.count) matched users for chat (完整信息)")
            print("📋 Matched users: \(filteredSessions.map { $0.user.name }.joined(separator: ", "))")
            
            // 保存缓存
            saveCachedChatSessionsToStorage()
            
        } catch {
            print("❌ Failed to load matches: \(error.localizedDescription)")
            isLoadingMatches = false
            // 只有在确实没有任何匹配时才清空，否则保持现有列表
            // 如果加载失败但有之前的聊天记录，保留它们
            if previousSessions.isEmpty {
                chatSessions = []
            } else {
                // 保持现有聊天列表，不因刷新失败而清空
                chatSessions = previousSessions
            }
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
            var suggestions: [AISuggestion] = []
            
            // 检查是否有聊天历史
            if let session = selectedSession, !session.messages.isEmpty {
                // 如果有聊天历史（>= 3条消息），使用对话分析功能
                if session.messages.count >= 3 {
                    print("📊 Analyzing conversation (\(session.messages.count) messages) to generate smart suggestions...")
                    
                    // 获取当前用户的兴趣列表（可选，用于更好的分析）
                    var userInterests: [String] = []
                    if let currentUser = authManager.currentUser,
                       let currentUserProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                        let brewNetProfile = currentUserProfile.toBrewNetProfile()
                        userInterests = brewNetProfile.personalitySocial.hobbies
                    }
                    
                    // 使用对话分析功能
                    suggestions = await aiService.analyzeConversationAndSuggest(
                        for: user,
                        messages: session.messages,
                        userInterests: userInterests
                    )
                } else {
                    // 如果消息较少（< 3条），仍然使用 ice breaker
                    print("💬 Using ice breaker (few messages: \(session.messages.count))")
                    suggestions = await aiService.generateIceBreakerTopics(for: user)
                }
            } else {
                // 没有聊天历史，使用 ice breaker
                print("💬 Using ice breaker (no conversation history)")
                suggestions = await aiService.generateIceBreakerTopics(for: user)
            }
            
            await MainActor.run {
                currentAISuggestions = suggestions
                isLoadingSuggestions = false
            }
        }
    }
    
    private func sendCoffeeChatInvitation() {
        guard let session = selectedSession,
              let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else {
            return
        }
        
        // 创建邀请消息
        let invitationMessage = ChatMessage(
            content: "Coffee chat invitation",
            isFromUser: true,
            messageType: .coffeeChatInvitation,
            senderName: currentUser.name
        )
        
        // 先更新本地UI（乐观更新）
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            chatSessions[index].addMessage(invitationMessage)
            chatSessions[index].lastMessageAt = invitationMessage.timestamp
            selectedSession = chatSessions[index]
            scrollToBottomId = invitationMessage.id
            
            // 重新排序列表
            chatSessions.sort { session1, session2 in
                let hasMessages1 = !session1.messages.isEmpty
                let hasMessages2 = !session2.messages.isEmpty
                
                if hasMessages1 && hasMessages2 {
                    return session1.lastMessageAt > session2.lastMessageAt
                }
                if hasMessages1 && !hasMessages2 {
                    return true
                }
                if !hasMessages1 && hasMessages2 {
                    return false
                }
                let date1 = session1.user.matchDate ?? Date.distantPast
                let date2 = session2.user.matchDate ?? Date.distantPast
                return date1 > date2
            }
        }
        
        // 显示发送动画
        showingCoffeeInviteAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingCoffeeInviteAnimation = false
        }
        
        // 发送到数据库
        Task {
            do {
                // 获取接收者名称
                var receiverName = session.user.name
                if let receiverProfile = try? await supabaseService.getProfile(userId: receiverUserId) {
                    receiverName = receiverProfile.coreIdentity.name
                }
                
                // 创建邀请记录
                let invitationId = try await supabaseService.createCoffeeChatInvitation(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    senderName: currentUser.name,
                    receiverName: receiverName
                )
                
                // 发送消息
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    content: invitationMessage.content,
                    messageType: "coffee_chat_invitation"
                )
                print("✅ Coffee chat invitation sent to database: \(invitationId)")
            } catch {
                print("❌ Failed to send coffee chat invitation: \(error.localizedDescription)")
                // 如果发送失败，移除本地消息
                await MainActor.run {
                    if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
                        chatSessions[index].messages.removeAll { $0.id == invitationMessage.id }
                        selectedSession = chatSessions[index]
                    }
                }
            }
        }
    }
    
    private func sendMessage(_ content: String) {
        guard !content.isEmpty, 
              let session = selectedSession,
              let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else { 
            return 
        }
        
        // 创建本地消息对象
        let message = ChatMessage(
            content: content,
            isFromUser: true
        )
        
        // 先更新本地UI（乐观更新）
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            chatSessions[index].addMessage(message)
            // 更新最后消息时间
            chatSessions[index].lastMessageAt = message.timestamp
            selectedSession = chatSessions[index]
            // 设置需要滚动到的消息ID（触发滚动）
            scrollToBottomId = message.id
            
            // 重新排序列表（按最新消息时间）
            chatSessions.sort { session1, session2 in
                let hasMessages1 = !session1.messages.isEmpty
                let hasMessages2 = !session2.messages.isEmpty
                
                if hasMessages1 && hasMessages2 {
                    return session1.lastMessageAt > session2.lastMessageAt
                }
                if hasMessages1 && !hasMessages2 {
                    return true
                }
                if !hasMessages1 && hasMessages2 {
                    return false
                }
                let date1 = session1.user.matchDate ?? Date.distantPast
                let date2 = session2.user.matchDate ?? Date.distantPast
                return date1 > date2
            }
        }
        
        // 发送到数据库
        Task {
            do {
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    content: content,
                    messageType: "text"
                )
                print("✅ Message saved to database")
            } catch {
                print("❌ Failed to send message: \(error.localizedDescription)")
                // 如果发送失败，可以显示错误提示或回滚本地消息
                await MainActor.run {
                    if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
                        // 移除失败的消息
                        chatSessions[index].messages.removeAll { $0.id == message.id }
                        selectedSession = chatSessions[index]
                    }
                }
            }
        }
        
        // 移除自动回复功能 - 删除以下代码：
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        //     simulateReply(for: session)
        // }
    }
    
    // 删除 simulateReply 函数
    // private func simulateReply(for session: ChatSession) { ... }
    
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
                timeZone: TimeZone.current.identifier
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
    
    // 添加定时刷新方法
    private func startMessageRefreshTimer() {
        stopMessageRefreshTimer() // 先停止现有的定时器
        
        // 注意：ChatInterfaceView 是 struct，不能使用 weak
        // 在 SwiftUI 中，可以直接调用方法，不需要捕获 self
        messageRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                // 如果当前有选中的会话，刷新该会话的消息
                if selectedSession != nil {
                    await refreshMessagesForCurrentSession()
                } else {
                    // 如果没有选中的会话（在聊天列表页面），刷新整个列表以更新未读消息数
                    await refreshChatSessionsMessages()
                }
            }
        }
    }
    
    // 刷新所有会话的消息（用于更新未读消息数）
    @MainActor
    private func refreshChatSessionsMessages() async {
        guard let currentUser = authManager.currentUser else {
            return
        }
        
        // 只刷新有未读消息的会话，或者最近有消息的会话
        // 注意：hidden 的会话也会刷新消息，但不会自动取消 hidden 状态
        for index in chatSessions.indices {
            let session = chatSessions[index]
            guard let receiverUserId = session.user.userId else { continue }
            
            // 保存当前的 hidden 状态
            let wasHidden = session.isHidden
            
            do {
                let supabaseMessages = try await supabaseService.getMessages(
                    userId1: currentUser.id,
                    userId2: receiverUserId
                )
                
                let messages = supabaseMessages.map { supabaseMessage in
                    supabaseMessage.toChatMessage(currentUserId: currentUser.id)
                }
                
                // 去重
                var uniqueMessages: [ChatMessage] = []
                var seenMessageIds = Set<UUID>()
                for message in messages {
                    if !seenMessageIds.contains(message.id) {
                        uniqueMessages.append(message)
                        seenMessageIds.insert(message.id)
                    }
                }
                
                // 更新会话消息，但保留 hidden 状态
                // hidden 的会话即使收到新消息，也保持 hidden 状态
                chatSessions[index].messages = uniqueMessages
                if let lastMessage = uniqueMessages.last {
                    chatSessions[index].lastMessageAt = lastMessage.timestamp
                }
                // 确保 hidden 状态不会被改变
                if wasHidden {
                    // 如果原来是 hidden，创建一个新的 session 保持 hidden 状态
                    let updatedSession = ChatSession(
                        user: chatSessions[index].user,
                        messages: chatSessions[index].messages,
                        aiSuggestions: chatSessions[index].aiSuggestions,
                        isActive: chatSessions[index].isActive,
                        isHidden: true
                    )
                    var sessionWithHidden = updatedSession
                    sessionWithHidden.lastMessageAt = chatSessions[index].lastMessageAt
                    chatSessions[index] = sessionWithHidden
                }
            } catch {
                print("⚠️ Failed to refresh messages for session \(session.user.name): \(error.localizedDescription)")
            }
        }
        
        // 重新排序
        chatSessions.sort { session1, session2 in
            let hasMessages1 = !session1.messages.isEmpty
            let hasMessages2 = !session2.messages.isEmpty
            
            if hasMessages1 && hasMessages2 {
                return session1.lastMessageAt > session2.lastMessageAt
            }
            if hasMessages1 && !hasMessages2 {
                return true
            }
            if !hasMessages1 && hasMessages2 {
                return false
            }
            let date1 = session1.user.matchDate ?? Date.distantPast
            let date2 = session2.user.matchDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func stopMessageRefreshTimer() {
        messageRefreshTimer?.invalidate()
        messageRefreshTimer = nil
    }
    
    // MARK: - Avatar Sync (头像同步功能已移除，保留代码结构以便将来扩展)
    
    @MainActor
    private func refreshMessagesForCurrentSession() async {
        guard let session = selectedSession,
              let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else {
            return
        }
        
        // 保存当前消息数量，用于检测是否有新消息
        let previousMessageCount = session.messages.count
        let previousLastMessageId = session.messages.last?.id
        
        do {
            let supabaseMessages = try await supabaseService.getMessages(
                userId1: currentUser.id,
                userId2: receiverUserId
            )
            
            let messages = supabaseMessages.map { supabaseMessage in
                supabaseMessage.toChatMessage(currentUserId: currentUser.id)
            }
            
            // 去重：基于消息 ID 去重，确保不会有重复消息
            var uniqueMessages: [ChatMessage] = []
            var seenMessageIds = Set<UUID>()
            for message in messages {
                if !seenMessageIds.contains(message.id) {
                    uniqueMessages.append(message)
                    seenMessageIds.insert(message.id)
                }
            }
            
            // 检查是否有新消息（来自对方）
            let hasNewMessageFromOther = uniqueMessages.count > previousMessageCount && 
                                         uniqueMessages.last?.isFromUser == false &&
                                         uniqueMessages.last?.id != previousLastMessageId
            
            // 更新会话消息（使用去重后的消息）
            if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
                // 保存当前的 hidden 状态
                let wasHidden = chatSessions[index].isHidden
                
                chatSessions[index].messages = uniqueMessages
                // 更新最后消息时间
                if let lastMessage = uniqueMessages.last {
                    chatSessions[index].lastMessageAt = lastMessage.timestamp
                }
                
                // 确保 hidden 状态不会被改变
                if wasHidden {
                    let updatedSession = ChatSession(
                        user: chatSessions[index].user,
                        messages: chatSessions[index].messages,
                        aiSuggestions: chatSessions[index].aiSuggestions,
                        isActive: chatSessions[index].isActive,
                        isHidden: true
                    )
                    var sessionWithHidden = updatedSession
                    sessionWithHidden.lastMessageAt = chatSessions[index].lastMessageAt
                    chatSessions[index] = sessionWithHidden
                }
                
                // 更新选中会话（用于聊天视图）
                selectedSession = chatSessions[index]
                
                // 重新排序（确保列表按最新消息时间排序）
                chatSessions.sort { session1, session2 in
                    let hasMessages1 = !session1.messages.isEmpty
                    let hasMessages2 = !session2.messages.isEmpty
                    
                    if hasMessages1 && hasMessages2 {
                        return session1.lastMessageAt > session2.lastMessageAt
                    }
                    if hasMessages1 && !hasMessages2 {
                        return true
                    }
                    if !hasMessages1 && hasMessages2 {
                        return false
                    }
                    let date1 = session1.user.matchDate ?? Date.distantPast
                    let date2 = session2.user.matchDate ?? Date.distantPast
                    return date1 > date2
                }
                
                // 如果有新消息且用户在底部，标记需要滚动
                if hasNewMessageFromOther, isAtBottom, let lastMessage = uniqueMessages.last {
                    // 通过设置 scrollToBottomId 触发滚动（会在 onChange 中处理）
                    scrollToBottomId = lastMessage.id
                }
            }
        } catch {
            print("⚠️ Failed to refresh messages: \(error.localizedDescription)")
        }
    }
    
    // 检查用户是否在聊天底部
    private func checkIfAtBottom() {
        guard contentHeight > 0 && scrollViewHeight > 0 else {
            return
        }
        
        // 计算可滚动的高度
        let scrollableHeight = contentHeight - scrollViewHeight
        
        // 如果内容不需要滚动（内容高度小于等于视图高度），认为在底部
        if scrollableHeight <= 10 {
            isAtBottom = true
            return
        }
        
        // 检查是否滚动到底部（使用50pt的容差）
        let threshold = 50.0
        isAtBottom = scrollOffset >= scrollableHeight - threshold
    }
    
    // 在选择会话时标记消息为已读
    private func selectSession(_ session: ChatSession) {
        selectedSession = session
        scrollToBottomId = nil // 重置滚动状态
        isAtBottom = true // 切换会话时，默认认为在底部
        loadAISuggestions(for: session.user)
        
        // 标记来自对方的未读消息为已读
        Task {
            await markMessagesAsRead(for: session)
        }
    }
    
    @MainActor
    private func markMessagesAsRead(for session: ChatSession) async {
        guard let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else {
            return
        }
        
        // 找到所有未读且来自对方的消息
        let unreadMessages = session.messages.filter { !$0.isFromUser && !$0.isRead }
        
        // 批量标记为已读
        for message in unreadMessages {
            if let messageId = UUID(uuidString: message.id.uuidString)?.uuidString {
                do {
                    try await supabaseService.markMessageAsRead(messageId: messageId)
                    print("✅ Marked message \(messageId) as read")
                } catch {
                    print("⚠️ Failed to mark message as read: \(error.localizedDescription)")
                }
            }
        }
        
        // 刷新消息列表以更新未读状态
        await refreshMessagesForCurrentSession()
    }
    
    // MARK: - Action Handlers
    /// 处理从聊天列表左滑的unmatch操作（显示确认对话框）
    private func handleUnmatchForSession(_ session: ChatSession) {
        sessionToUnmatch = session
        showingUnmatchConfirmAlert = true
    }
    
    /// 处理隐藏聊天（归档到 Hidden）
    private func handleHideSession(_ session: ChatSession) {
        // 找到对应的会话并更新 isHidden 状态
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            var updatedSession = chatSessions[index]
            // 由于 ChatSession 的 isHidden 是 var，我们需要创建一个新的会话
            let newSession = ChatSession(
                user: updatedSession.user,
                messages: updatedSession.messages,
                aiSuggestions: updatedSession.aiSuggestions,
                isActive: updatedSession.isActive,
                isHidden: true
            )
            chatSessions[index] = newSession
            
            // 如果当前正在查看这个会话，先关闭它
            if selectedSession?.id == session.id {
                selectedSession = nil
            }
            
            // 更新缓存
            saveCachedChatSessionsToStorage()
            
            print("✅ Session with \(session.user.name) has been hidden")
        }
    }
    
    /// 处理取消隐藏聊天（从 Hidden 移回对应分类）
    private func handleUnhideSession(_ session: ChatSession) {
        // 找到对应的会话并更新 isHidden 状态
        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
            var updatedSession = chatSessions[index]
            // 创建新的会话，isHidden 设为 false
            let newSession = ChatSession(
                user: updatedSession.user,
                messages: updatedSession.messages,
                aiSuggestions: updatedSession.aiSuggestions,
                isActive: updatedSession.isActive,
                isHidden: false
            )
            chatSessions[index] = newSession
            
            // 更新缓存
            saveCachedChatSessionsToStorage()
            
            print("✅ Session with \(session.user.name) has been unhidden")
        }
    }
    
    /// 实际执行取消匹配操作
    private func performUnmatch(session: ChatSession) {
        guard let currentUser = authManager.currentUser,
              let matchedUserId = session.user.userId else {
            print("❌ Cannot unmatch: missing user info")
            return
        }
        
        Task {
            do {
                // 查找匹配ID
                let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                let match = matches.first { match in
                    (match.userId == currentUser.id && match.matchedUserId == matchedUserId) ||
                    (match.matchedUserId == currentUser.id && match.userId == matchedUserId)
                }
                
                if let matchId = match?.id {
                    // 取消匹配
                    _ = try await supabaseService.deactivateMatch(matchId: matchId, userId: currentUser.id)
                    print("✅ Successfully unmatched with \(session.user.name)")
                    
                    // 从列表中移除该会话
                    await MainActor.run {
                        // 如果当前正在查看这个会话，先关闭它
                        if selectedSession?.id == session.id {
                            selectedSession = nil
                        }
                        // 从列表中移除
                        chatSessions.removeAll { $0.id == session.id }
                        // 更新缓存
                        saveCachedChatSessionsToStorage()
                    }
                } else {
                    print("⚠️ Match not found for unmatch")
                    // 即使找不到匹配，也从列表中移除（可能是数据不一致）
                    await MainActor.run {
                        if selectedSession?.id == session.id {
                            selectedSession = nil
                        }
                        chatSessions.removeAll { $0.id == session.id }
                        saveCachedChatSessionsToStorage()
                    }
                }
            } catch {
                print("❌ Failed to unmatch: \(error.localizedDescription)")
                // 即使失败，也从UI中移除（提供即时反馈）
                await MainActor.run {
                    if selectedSession?.id == session.id {
                        selectedSession = nil
                    }
                    chatSessions.removeAll { $0.id == session.id }
                    saveCachedChatSessionsToStorage()
                }
            }
        }
    }
}

// MARK: - Chat Session Row View
struct ChatSessionRowView: View {
    let session: ChatSession
    let onTap: () -> Void
    let onUnmatch: () -> Void
    let onHide: (() -> Void)? // 可选的 Hide 操作
    let onUnhide: (() -> Void)? // 可选的 Unhide 操作
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar - 使用时间戳确保刷新
                let timestamp = Date().timeIntervalSince1970
                AvatarView(avatarString: session.user.avatar, size: 50)
                    .id("avatar-\(session.user.id)-\(session.user.avatar)-\(Int(timestamp / 10))") // 每10秒刷新一次
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.user.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Spacer()
                        
                        // 显示最新消息时间（如果有消息）
                        if !session.messages.isEmpty {
                            Text(formatLastMessageTime(session.lastMessageAt))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 显示未读的最新消息（如果有），否则显示最后一条消息
                    let unreadMessages = session.messages.filter { !$0.isFromUser && !$0.isRead }
                    let displayMessage = unreadMessages.last ?? session.messages.last
                    Text(displayMessage?.content ?? "Start chatting...")
                        .font(.system(size: 14))
                        .foregroundColor(unreadMessages.isEmpty ? .gray : Color(red: 0.4, green: 0.2, blue: 0.1))
                        .fontWeight(unreadMessages.isEmpty ? .regular : .semibold)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        // 在线状态功能已移除
                        
                        Spacer()
                        
                        // 显示未读消息数（Hidden 的会话不显示未读消息数）
                        if !session.isHidden {
                            let unreadCount = session.unreadCount
                            if unreadCount > 0 {
                                Text("\(unreadCount)")
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
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // 如果是 Hidden 分类，显示 Unhide 和 Unmatch
            if session.isHidden {
                if let onUnhide = onUnhide {
                    Button {
                        onUnhide()
                    } label: {
                        Label("Unhide", systemImage: "eye.fill")
                    }
                    .tint(.blue)
                }
                
                Button(role: .destructive) {
                    onUnmatch()
                } label: {
                    Label("Unmatch", systemImage: "xmark.circle.fill")
                }
                .tint(.red)
            } else {
                // 如果是 Your Turn 或 Their Turn，显示 Hide 和 Unmatch
                if let onHide = onHide {
                    Button {
                        onHide()
                    } label: {
                        Label("Hide", systemImage: "eye.slash.fill")
                    }
                    .tint(.gray)
                }
                
                Button(role: .destructive) {
                    onUnmatch()
                } label: {
                    Label("Unmatch", systemImage: "xmark.circle.fill")
                }
                .tint(.red)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatLastMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            // 今天：显示时间
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // 昨天：显示"昨天"
            return "Yesterday"
        } else {
            // 更早：显示日期 MM/dd
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
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
    let session: ChatSession
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var invitationStatus: CoffeeChatInvitation.InvitationStatus? = nil
    @State private var showingAcceptSheet = false
    @State private var selectedDate = Date()
    @State private var locationText = ""
    @State private var notesText = ""
    
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
        Group {
            if message.messageType == .coffeeChatInvitation {
                coffeeChatInvitationBubble
            } else {
                regularMessageBubble
            }
        }
    }
    
    private var regularMessageBubble: some View {
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
                        ? Color(red: 0.7, green: 0.55, blue: 0.45)
                        : Color(red: 0.95, green: 0.92, blue: 0.88)
                )
                .cornerRadius(20, corners: message.isFromUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            
            Text(formatTime(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
        }
    }
    
    private var coffeeChatInvitationBubble: some View {
        Group {
            if !message.isFromUser {
                // 接收者：两行布局
                VStack(alignment: .leading, spacing: 14) {
                    // 第一行：信封图标 + 文字
                    HStack(alignment: .center, spacing: 12) {
                        // 小信封图标
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.9, green: 0.85, blue: 0.8),
                                            Color(red: 0.85, green: 0.8, blue: 0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.15), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        }
                        
                        // 邀请文字（显示发送者名字）
                        Text("\(session.user.name) invited you to a coffee chat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    
                    // 第二行：两个按钮并排
                    HStack(spacing: 10) {
                        Button(action: {
                            showingAcceptSheet = true
                        }) {
                            Text("Accept")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.7, green: 0.55, blue: 0.4),
                                            Color(red: 0.6, green: 0.45, blue: 0.3)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                                .shadow(color: Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.4), radius: 5, x: 0, y: 2)
                        }
                        
                        Button(action: {
                            let invitationId = getInvitationId()
                            rejectCoffeeChatInvitation(invitationId: invitationId)
                        }) {
                            Text("Decline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.98, green: 0.96, blue: 0.94),
                                            Color(red: 0.95, green: 0.92, blue: 0.88)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.8, green: 0.7, blue: 0.6),
                                                    Color(red: 0.7, green: 0.6, blue: 0.5)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
            } else {
                // 发送者：一行布局
                HStack(alignment: .center, spacing: 12) {
                    // 小信封图标
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.9, green: 0.85, blue: 0.8),
                                        Color(red: 0.85, green: 0.8, blue: 0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.15), radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    
                    // 邀请文字
                    Text("Coffee chat invitation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Spacer()
                    
                    // 状态文字
                    if let status = invitationStatus {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: status == .accepted ? [
                                            Color(red: 0.7, green: 0.55, blue: 0.4),
                                            Color(red: 0.6, green: 0.45, blue: 0.3)
                                        ] : [
                                            Color(red: 0.6, green: 0.5, blue: 0.4),
                                            Color(red: 0.5, green: 0.4, blue: 0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 8, height: 8)
                            
                            Text(status == .accepted ? "Accepted" : status == .rejected ? "Declined" : "Pending")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.96, blue: 0.94),
                                    Color(red: 0.95, green: 0.92, blue: 0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5),
                                            Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .padding(28)
        .background(
            ZStack {
                // 主背景
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.99, green: 0.98, blue: 0.97)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // 内阴影效果
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.6),
                                Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.15), radius: 12, x: 0, y: 6)
        .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingAcceptSheet) {
            AcceptInvitationSheet(
                selectedDate: $selectedDate,
                locationText: $locationText,
                notesText: $notesText,
                onAccept: {
                    let invitationId = getInvitationId()
                    acceptCoffeeChatInvitation(invitationId: invitationId)
                },
                onCancel: {
                    showingAcceptSheet = false
                }
            )
        }
    }
    
    private func acceptCoffeeChatInvitation(invitationId: String) {
        Task {
            do {
                try await supabaseService.acceptCoffeeChatInvitation(
                    invitationId: invitationId,
                    scheduledDate: selectedDate,
                    location: locationText.isEmpty ? "To be determined" : locationText,
                    notes: notesText.isEmpty ? nil : notesText
                )
                await MainActor.run {
                    invitationStatus = .accepted
                    showingAcceptSheet = false
                }
                print("✅ Coffee chat invitation accepted")
            } catch {
                print("❌ Failed to accept invitation: \(error.localizedDescription)")
            }
        }
    }
    
    private func rejectCoffeeChatInvitation(invitationId: String) {
        Task {
            do {
                try await supabaseService.rejectCoffeeChatInvitation(invitationId: invitationId)
                await MainActor.run {
                    invitationStatus = .rejected
                }
                print("✅ Coffee chat invitation rejected")
            } catch {
                print("❌ Failed to reject invitation: \(error.localizedDescription)")
            }
        }
    }
    
    // 从消息中提取邀请ID（临时方案：从消息内容或其他方式获取）
    private func getInvitationId() -> String {
        // TODO: 从消息元数据或数据库中查找对应的邀请ID
        // 暂时返回消息ID作为临时方案
        return message.id.uuidString
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Accept Invitation Sheet
struct AcceptInvitationSheet: View {
    @Binding var selectedDate: Date
    @Binding var locationText: String
    @Binding var notesText: String
    let onAccept: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部装饰图标
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.9, green: 0.85, blue: 0.8),
                                                Color(red: 0.85, green: 0.8, blue: 0.75)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 35, weight: .medium))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            }
                            
                            Text("Schedule Your Coffee Chat")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .padding(.top, 20)
                        
                        // 表单卡片
                        VStack(alignment: .leading, spacing: 20) {
                            // Date & Time
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    
                                    Text("Date & Time")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                                
                                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.98, green: 0.96, blue: 0.94))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5),
                                                        Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            
                            // Location
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    
                                    Text("Location")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                                
                                TextField("Enter location", text: $locationText)
                                    .font(.system(size: 16))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.98, green: 0.96, blue: 0.94))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5),
                                                        Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            
                            // Notes
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    
                                    Text("Notes (Optional)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                                
                                TextField("Add any notes...", text: $notesText, axis: .vertical)
                                    .font(.system(size: 16))
                                    .lineLimit(3...6)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.98, green: 0.96, blue: 0.94))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5),
                                                        Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            Color(red: 0.99, green: 0.98, blue: 0.97)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.12), radius: 12, x: 0, y: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.6),
                                            Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Accept Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                    .font(.system(size: 16, weight: .medium))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Accept") {
                        onAccept()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
        }
    }
}

// MARK: - AI Suggestions View
struct AISuggestionsView: View {
    let user: ChatUser
    let suggestions: [AISuggestion]
    let isLoading: Bool
    let isAnalysisMode: Bool // 是否处于对话分析模式
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
                    
                    Text(isAnalysisMode ? "AI Conversation Analysis" : "AI Ice Breaker")
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
            
            Text(isAnalysisMode ? "AI is analyzing conversation and generating suggestions..." : "AI is generating ice breaker topics...")
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
                        
                        // 如果有风格标签，显示风格
                        if let style = suggestion.style {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text(style.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
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
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var currentUserLocation: String?
    
    // Since this is shown in chat, the users are connected/matched
    private let isConnection = true
    
    // Verify privacy settings are loaded from database
    private var privacySettings: VisibilitySettings {
        let settings = profile.privacyTrust.visibilitySettings
        // Log privacy settings for debugging
        print("🔒 Chat Profile Privacy Settings for \(profile.coreIdentity.name):")
        print("   - company: \(settings.company.rawValue) -> visible: \(settings.company.isVisible(isConnection: true))")
        print("   - skills: \(settings.skills.rawValue) -> visible: \(settings.skills.isVisible(isConnection: true))")
        print("   - interests: \(settings.interests.rawValue) -> visible: \(settings.interests.isVisible(isConnection: true))")
        print("   - location: \(settings.location.rawValue) -> visible: \(settings.location.isVisible(isConnection: true))")
        print("   - timeslot: \(settings.timeslot.rawValue) -> visible: \(settings.timeslot.isVisible(isConnection: true))")
        return settings
    }
    
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
                        
                        // Available Timeslot Grid (moved to bottom)
                        if shouldShowTimeslot {
                            VStack(alignment: .leading, spacing: 0) {
                                Divider()
                                AvailableTimeslotDisplayView(timeslot: profile.networkingPreferences.availableTimeslot)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .padding(.bottom, 30)
                                    .background(Color.white)
                            }
                        }
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
        .onAppear {
            loadCurrentUserLocation()
        }
    }
    
    // MARK: - Load Current User Location
    private func loadCurrentUserLocation() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [ChatProfileCard] 没有当前用户，无法加载位置")
            return
        }
        
        print("📍 [ChatProfileCard] 开始加载当前用户位置...")
        print("   - 当前用户 ID: \(currentUser.id)")
        
        Task {
            do {
                if let currentProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let rawLocation = currentProfile.coreIdentity.location
                    print("   - [原始数据] coreIdentity.location: \(rawLocation ?? "nil")")
                    
                    let brewNetProfile = currentProfile.toBrewNetProfile()
                    await MainActor.run {
                        currentUserLocation = brewNetProfile.coreIdentity.location
                        print("✅ [ChatProfileCard] 已加载当前用户位置: \(brewNetProfile.coreIdentity.location ?? "nil")")
                        if brewNetProfile.coreIdentity.location == nil || brewNetProfile.coreIdentity.location?.isEmpty == true {
                            print("⚠️ [ChatProfileCard] 当前用户没有设置位置信息")
                        }
                    }
                } else {
                    print("⚠️ [ChatProfileCard] 无法获取当前用户 profile")
                }
            } catch {
                print("⚠️ [ChatProfileCard] 加载当前用户位置失败: \(error.localizedDescription)")
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
            
            // Preferred Chat Format
            HStack(spacing: 8) {
                Image(systemName: chatFormatIcon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Text(profile.networkingPreferences.preferredChatFormat.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Spacer()
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
            return "repeat"
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        Text(location)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    // Distance display (组件内部会等待 currentUserLocation 加载)
                    // 使用 id 修饰符确保在 currentUserLocation 变化时重新创建视图
                    DistanceDisplayView(
                        otherUserLocation: location,
                        currentUserLocation: currentUserLocation
                    )
                    .id("distance-\(location)-\(currentUserLocation ?? "nil")")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 30)
        .background(Color.white)
    }
    
    // MARK: - Privacy Visibility Checks (strictly follows database privacy_trust.visibility_settings)
    // Shows fields marked as "public" or "connections_only" when isConnection is true
    private var shouldShowCompany: Bool {
        let settings = privacySettings
        let visible = settings.company.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Company hidden: \(settings.company.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowSkills: Bool {
        let settings = privacySettings
        let visible = settings.skills.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Skills hidden: \(settings.skills.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowInterests: Bool {
        let settings = privacySettings
        let visible = settings.interests.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Interests hidden: \(settings.interests.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowLocation: Bool {
        let settings = privacySettings
        let visible = settings.location.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Location hidden: \(settings.location.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowTimeslot: Bool {
        let settings = privacySettings
        let visible = settings.timeslot.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Timeslot hidden: \(settings.timeslot.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
}

// MARK: - Preference Keys for Scroll Detection
// Note: ScrollOffsetPreferenceKey and ContentHeightPreferenceKey are defined in ProfileSetupView.swift
struct ScrollViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
struct ChatInterfaceView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInterfaceView()
    }
}

// MARK: - Avatar View Helper
struct AvatarView: View {
    let avatarString: String
    let size: CGFloat
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    @State private var currentAvatarString: String = "" // 跟踪当前头像URL
    
    init(avatarString: String, size: CGFloat = 50) {
        self.avatarString = avatarString
        self.size = size
        _currentAvatarString = State(initialValue: avatarString)
        
        // 在初始化时立即尝试从缓存加载（同步）
        if avatarString.hasPrefix("http://") || avatarString.hasPrefix("https://"),
           let cached = ImageCacheManager.shared.loadImage(from: avatarString) {
            // 注意：这里不能直接设置 @State，需要在 body 中处理
            // 但我们可以通过 _cachedImage 来设置初始值
            _cachedImage = State(initialValue: cached)
        }
    }
    
    var body: some View {
        // 判断是 URL 还是 SF Symbol
        if avatarString.hasPrefix("http://") || avatarString.hasPrefix("https://") {
            // 如果是 URL，先尝试从缓存加载
            Group {
                if let cachedImage = cachedImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // 占位符，同时触发加载
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: size))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .onAppear {
                // 视图出现时立即尝试加载
                loadImage()
            }
            .onChange(of: avatarString) { newValue in
                // 当头像URL变化时，清除缓存并重新加载
                if newValue != currentAvatarString {
                    print("🔄 [AvatarView] 头像URL变化: \(currentAvatarString) -> \(newValue)")
                    currentAvatarString = newValue
                    cachedImage = nil // 清除旧图片
                    // 清除缓存
                    if newValue.hasPrefix("http://") || newValue.hasPrefix("https://") {
                        ImageCacheManager.shared.removeImage(for: newValue)
                    }
                    loadImage() // 重新加载新图片
                }
                // 注意：如果 URL 相同，不在 onChange 中处理，避免循环刷新
                // 缓存清除由同步逻辑在外部处理
            }
        } else {
            // 如果是 SF Symbol
            Image(systemName: avatarString)
                .font(.system(size: size))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
        }
    }
    
    private func loadImage() {
        // 如果当前头像URL与缓存中的URL不匹配，清除缓存
        if cachedImage != nil && currentAvatarString != avatarString {
            cachedImage = nil
        }
        
        // 如果已经有缓存图片且URL匹配，不再重复加载
        if cachedImage != nil && currentAvatarString == avatarString {
            return
        }
        
        // 先尝试从缓存加载（同步，立即返回）
        if let cached = ImageCacheManager.shared.loadImage(from: avatarString) {
            self.cachedImage = cached
            self.currentAvatarString = avatarString
            return
        }
        
        // 缓存中没有，从网络加载
        isLoading = true
        
        guard let url = URL(string: avatarString) else {
            isLoading = false
            return
        }
        
        print("🔄 [AvatarView] 开始加载头像: \(avatarString)")
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let image = UIImage(data: data) {
                        // 保存到缓存
                        ImageCacheManager.shared.saveImage(image, for: avatarString)
                        self.cachedImage = image
                        self.currentAvatarString = avatarString
                        print("✅ [AvatarView] 头像加载成功: \(avatarString)")
                    }
                    self.isLoading = false
                }
            } catch {
                print("⚠️ [AvatarView] 头像加载失败: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

