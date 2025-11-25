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
    @State private var showingSendInvitationSheet = false // 显示发送邀请表单
    @State private var sendInvitationDate = Date().addingTimeInterval(86400) // 默认明天
    @State private var sendInvitationLocation = "" // 发送者填写的地点
    @State private var sendInvitationNotes = "" // 发送者填写的备注
    @State private var invitationStatusCache: [String: CoffeeChatInvitation.InvitationStatus] = [:] // 邀请状态缓存，key: "senderId-receiverId"
    @State private var currentInvitationInfo: [String: (status: CoffeeChatInvitation.InvitationStatus?, scheduledDate: Date?, location: String?, invitationId: String?, isSentByMe: Bool)] = [:] // 当前会话的邀请信息，key: "sessionId"
    @State private var showingInvitationErrorAlert = false // 显示邀请错误提示
    @State private var invitationErrorMessage = "" // 邀请错误消息
    @State private var showingLocationErrorAlert = false // 显示地点错误提示
    @State private var cancelledInvitationIds: Set<String> = [] // 已取消的邀请ID集合，防止重新加载
    private let cancelledInvitationIdsKey = "cancelled_coffee_chat_invitation_ids" // UserDefaults key
    
    var body: some View {
        mainContent
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedSession == nil {
                    // Custom logo and title
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Image("Logo")
                                .resizable()
                                .renderingMode(.original)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                            
                            Text("BrewNet")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.18))
                        }
                    }
                    
                    toolbarContent
                } else {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EmptyView()
                    }
                }
            }
            .toolbar(selectedSession != nil ? .hidden : .visible, for: .navigationBar)
            .onAppear {
                loadChatSessions()
                startMessageRefreshTimer()
                // 确保初始状态正确
                updateTabBarVisibility()
                // 加载当前用户的 profile，确保头像能正确显示
                Task {
                    await loadCurrentUserProfile()
                }
                
                // 从 UserDefaults 加载已取消的邀请ID
                loadCancelledInvitationIds()
                
                // 监听邀请被接受的通知
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CoffeeChatInvitationAccepted"),
                    object: nil,
                    queue: .main
                ) { notification in
                    handleInvitationAccepted(notification: notification)
                }
                
                // 监听邀请被取消的通知
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CoffeeChatInvitationCancelled"),
                    object: nil,
                    queue: .main
                ) { notification in
                    handleInvitationCancelled(notification: notification)
                }
                
                // 监听邀请被拒绝的通知
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CoffeeChatInvitationRejected"),
                    object: nil,
                    queue: .main
                ) { notification in
                    handleInvitationRejected(notification: notification)
                }
                
                // 监听消息刷新通知
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("RefreshMessages"),
                    object: nil,
                    queue: .main
                ) { _ in
                    Task {
                        await refreshMessagesForCurrentSession()
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CoffeeChatInvitationAccepted"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CoffeeChatInvitationCancelled"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CoffeeChatInvitationRejected"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshMessages"), object: nil)
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
            // 更新 TabBar 可见性
            updateTabBarVisibility()
        }
        .alert("Notice", isPresented: $showingInvitationErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(invitationErrorMessage)
        }
        .alert("Notice", isPresented: $showingLocationErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Location cannot be empty. Please enter a location.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileUpdated"))) { _ in
            // 当 profile 更新时，重新加载所有用户的 profile 并更新头像
            print("🔄 [头像更新] 收到 ProfileUpdated 通知，开始刷新头像")
            Task {
                await refreshAllUserProfiles()
                await MainActor.run {
                    updateChatSessionsWithAvatars()
                    // 强制刷新当前选中的会话，确保头像更新
                    if let currentSession = selectedSession {
                        selectedSession = nil
                        // 延迟一帧后重新选择，确保头像刷新
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedSession = chatSessions.first(where: { $0.id == currentSession.id })
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToChat"))) { notification in
            // 当收到导航到 Chat 的通知时，刷新匹配列表并自动选择匹配的用户
            Task {
                // 重新加载匹配列表
                await loadChatSessionsFromDatabase()
                
                // 支持两种键名：userId（从 View Match 发送）和 matchedUserId（从其他地方发送）
                if let userInfo = notification.userInfo,
                   let matchedUserId = (userInfo["matchedUserId"] as? String) ?? (userInfo["userId"] as? String) {
                    
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
    
    // MARK: - TabBar Visibility Helper
    private func updateTabBarVisibility() {
        let shouldHide = selectedSession != nil
        print("🔔 Updating TabBar visibility: shouldHide = \(shouldHide)")
        NotificationCenter.default.post(
            name: NSNotification.Name("HideTabBar"),
            object: nil,
            userInfo: ["shouldHide": shouldHide]
        )
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
        .sheet(isPresented: $showingSendInvitationSheet) {
            SendInvitationSheet(
                selectedDate: $sendInvitationDate,
                locationText: $sendInvitationLocation,
                notesText: $sendInvitationNotes,
                onSend: {
                    showingSendInvitationSheet = false
                    sendCoffeeChatInvitation()
                },
                onCancel: {
                    showingSendInvitationSheet = false
                }
            )
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
                            // 打开发送邀请表单
                            showingSendInvitationSheet = true
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
        VStack(spacing: 0) {
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
                .padding(.top, -8)
                .environment(\.defaultMinListHeaderHeight, 0)
            }
        }
        .padding(.top, 0)
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
                        getCurrentAvatar: { user in
                            getCurrentAvatarForUser(user)
                        },
                        avatarVersion: session.user.userId.flatMap { avatarRefreshVersions[$0] } ?? 0,
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
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
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
                .padding(.top, -8)
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
            
            // Coffee Chat Invitation Banner (置顶区域)
            // 只显示：1) 自己发送的邀请（pending或accepted） 2) 已接受的邀请（双方都显示）
            if let invitationInfo = currentInvitationInfo[session.id.uuidString],
               let status = invitationInfo.status,
               (invitationInfo.isSentByMe || status == .accepted) {
                coffeeChatInvitationBanner(session: session, invitationInfo: invitationInfo)
            }
            
            // Messages
            ScrollViewReader { proxy in
                // 只过滤掉自己发送的coffee_chat_invitation消息，保留收到的邀请消息（在聊天框内显示）
                // 但是，如果邀请已被拒绝（有拒绝系统消息），邀请者这边不应该显示任何邀请消息
                // 注意：这个检查只对邀请者有效（因为拒绝消息是发给邀请者的）
                let hasRejectionMessage = session.messages.contains { msg in
                    msg.messageType == .system && 
                    msg.content.contains("declined your coffee chat invitation") &&
                    msg.isFromUser == false // 只有收到的系统消息才可能是拒绝消息
                }
                
                let filteredMessages = session.messages.filter { message in
                    if message.messageType == .coffeeChatInvitation {
                        // 如果已经有拒绝消息，且这是邀请者看到的（自己发送的邀请），过滤掉所有邀请消息
                        // 对于被邀请方，不应该过滤掉邀请消息
                        if hasRejectionMessage && message.isFromUser {
                            return false
                        }
                        // 保留收到的邀请消息（在聊天框内显示），过滤掉自己发送的
                        return !message.isFromUser
                    }
                    return true
                }
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredMessages) { message in
                            MessageBubbleView(
                                message: message,
                                session: session,
                                invitationStatusCache: $invitationStatusCache
                            )
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
                        // 在内容出现时滚动到底部，确保邀请消息可见
                        if let lastMessage = filteredMessages.last {
                            // 延迟滚动，确保所有消息（包括邀请消息）都已渲染
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
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
                    if let lastMessage = filteredMessages.last {
                        // 立即尝试滚动（无延迟）
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
                .onAppear {
                    // 视图出现时再次确保滚动到底部（作为保险）
                    if let lastMessage = filteredMessages.last {
                        // 使用稍长的延迟，确保视图和消息都已渲染
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        // 双重保险
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: session.id) { _ in
                    // 当会话切换时，立即滚动到底部
                    // 重新计算filteredMessages（因为session已更新）
                    let currentFilteredMessages = session.messages.filter { message in
                        if message.messageType == .coffeeChatInvitation {
                            // 保留收到的邀请消息（在聊天框内显示），过滤掉自己发送的
                            return !message.isFromUser
                        }
                        return true
                    }
                    if let lastMessage = currentFilteredMessages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
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
    
    /// 更新聊天会话的头像和名字（当 profile 更新时调用）
    private func updateChatSessionsWithAvatars() {
        // 由于 ChatSession 的 user 是 let，需要重新创建整个会话
        var updatedSessions: [ChatSession] = []
        for session in chatSessions {
            if let userId = session.user.userId {
                // 获取最新的头像和名字（从 profile map 中获取）
                var avatar = session.user.avatar
                var name = session.user.name
                let oldAvatar = avatar
                
                if let profile = userIdToFullProfileMap[userId] {
                    // 更新名字（使用 profile 中可修改的名字）
                    name = profile.coreIdentity.name
                    
                    // 更新头像
                    if let newAvatar = profile.coreIdentity.profileImage,
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
                    
                    // 如果名字变化了，打印日志
                    if name != session.user.name {
                        print("   🔄 [名字更新] 名字已更新: \(session.user.name) -> \(name)")
                    }
                }
                
                // 创建更新后的 ChatUser（更新头像和名字）
                let updatedChatUser = ChatUser(
                    name: name, // 使用 profile 中的名字
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
    
    /// 刷新所有用户的 profile（当 profile 更新时调用）
    @MainActor
    private func refreshAllUserProfiles() async {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [头像更新] 当前用户为空，无法刷新 profile")
            return
        }
        
        print("🔄 [头像更新] 开始刷新所有用户的 profile")
        
        // 收集所有需要刷新的用户 ID（包括当前用户和所有聊天对象）
        var userIdsToRefresh: Set<String> = [currentUser.id]
        
        // 添加所有聊天对象的 userId
        for session in chatSessions {
            if let userId = session.user.userId {
                userIdsToRefresh.insert(userId)
            }
        }
        
        // 并发获取所有用户的 profile
        var updatedProfileMap: [String: BrewNetProfile] = [:]
        
        await withTaskGroup(of: (String, BrewNetProfile?).self) { group in
            for userId in userIdsToRefresh {
                group.addTask {
                    if let supabaseProfile = try? await supabaseService.getProfile(userId: userId) {
                        return (userId, supabaseProfile.toBrewNetProfile())
                    }
                    return (userId, nil)
                }
            }
            
            for await (userId, profile) in group {
                if let profile = profile {
                    updatedProfileMap[userId] = profile
                    print("✅ [头像更新] 已刷新用户 \(userId) 的 profile")
                }
            }
        }
        
        // 更新 profile map
        userIdToFullProfileMap.merge(updatedProfileMap) { (_, new) in new }
        
        // 清除所有用户的头像缓存，强制刷新
        for (userId, profile) in updatedProfileMap {
            if let avatarURL = profile.coreIdentity.profileImage,
               !avatarURL.isEmpty,
               avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                ImageCacheManager.shared.removeImage(for: avatarURL)
                // 增加刷新版本号
                avatarRefreshVersions[userId] = (avatarRefreshVersions[userId] ?? 0) + 1
                print("🔄 [头像更新] 已清除用户 \(userId) 的头像缓存，版本: \(avatarRefreshVersions[userId] ?? 0)")
            }
        }
        
        print("✅ [头像更新] 完成刷新，共更新 \(updatedProfileMap.count) 个用户的 profile")
    }
    
    /// 加载当前用户的 profile（用于显示最新头像）
    @MainActor
    private func loadCurrentUserProfile() async {
        guard let currentUser = authManager.currentUser else {
            return
        }
        
        do {
            if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = supabaseProfile.toBrewNetProfile()
                userIdToFullProfileMap[currentUser.id] = brewNetProfile
                print("✅ [头像更新] 已加载当前用户的 profile，头像: \(brewNetProfile.coreIdentity.profileImage ?? "nil")")
            }
        } catch {
            print("⚠️ [头像更新] 加载当前用户 profile 失败: \(error.localizedDescription)")
        }
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
            // 同时也要加载当前用户的 profile，以便显示最新头像
            var allUserIdsToFetch = userIdsToFetch
            if !allUserIdsToFetch.contains(currentUser.id) {
                allUserIdsToFetch.append(currentUser.id)
            }
            
            if !allUserIdsToFetch.isEmpty {
                let profileTasks = allUserIdsToFetch.map { userId -> Task<BrewNetProfile?, Never> in
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
                    let userId = allUserIdsToFetch[index]
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
                
                // 保存完整 profile 映射（包括当前用户）
                userIdToFullProfileMap.merge(userIdToProfile) { (_, new) in new }
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
                
                // 使用从消息任务中解析的正确匹配时间
                let messageData = userIdToMessages[matchedUserId] ?? ([], Date(), Date())
                let matchDate = messageData.matchDate // 使用正确解析的匹配时间
                
                let profile = userIdToFullProfileMap[matchedUserId]
                let avatarString = profile?.coreIdentity.profileImage ?? "person.circle.fill"
                
                // 优先使用 profile 中的名字，确保使用可修改的名字
                let matchedUserName = profile?.coreIdentity.name ?? data.matchedUserName
                
                let chatUser = ChatUser(
                    name: matchedUserName, // 使用 profile 中的名字
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
        
        // 检查是否已经发送过邀请或已有约定
        Task {
            do {
                // 检查自己是否已经发送过pending的邀请
                let sentInvitation = try await supabaseService.getCoffeeChatInvitationInfo(
                    senderId: currentUser.id,
                    receiverId: receiverUserId
                )
                
                // 检查是否已经有accepted的邀请（双方都不能再发送）
                let receivedInvitation = try await supabaseService.getCoffeeChatInvitationInfo(
                    senderId: receiverUserId,
                    receiverId: currentUser.id
                )
                
                await MainActor.run {
                    // 检查邀请ID是否在已取消列表中
                    let sentInvitationId = sentInvitation.invitationId
                    let receivedInvitationId = receivedInvitation.invitationId
                    
                    // 如果自己已经发送过pending的邀请，且未被取消
                    if let sentStatus = sentInvitation.status,
                       sentStatus == .pending,
                       let sentId = sentInvitationId,
                       !cancelledInvitationIds.contains(sentId) {
                        // 显示提示：你已经发送过一个了
                        showingCoffeeInviteAlert = false
                        invitationErrorMessage = "You have already sent a coffee chat invitation"
                        showingInvitationErrorAlert = true
                        return
                    }
                    
                    // 如果已经有accepted的邀请（双方都不能再发送），且未被取消
                    // 需要检查对应的 schedule 是否已经 met
                    if let sentStatus = sentInvitation.status,
                       sentStatus == .accepted,
                       let sentId = sentInvitationId,
                       !cancelledInvitationIds.contains(sentId),
                       let scheduledDate = sentInvitation.scheduledDate,
                       let location = sentInvitation.location {
                        // 检查 schedule 是否已经 met
                        Task {
                            do {
                                let hasMet = try await supabaseService.checkCoffeeChatScheduleMet(
                                    userId: currentUser.id,
                                    participantId: receiverUserId,
                                    scheduledDate: scheduledDate,
                                    location: location
                                )
                                
                                await MainActor.run {
                                    if !hasMet {
                                        // 如果未 met，显示提示
                                        showingCoffeeInviteAlert = false
                                        invitationErrorMessage = "You already have a coffee chat scheduled"
                                        showingInvitationErrorAlert = true
                                    } else {
                                        // 如果已 met，允许发送新邀请
                                        performSendCoffeeChatInvitation(session: session, currentUser: currentUser, receiverUserId: receiverUserId)
                                    }
                                }
                            } catch {
                                print("❌ [检查 schedule met] 失败: \(error.localizedDescription)")
                                // 如果检查失败，保守处理：不允许发送
                                await MainActor.run {
                                    showingCoffeeInviteAlert = false
                                    invitationErrorMessage = "You already have a coffee chat scheduled"
                                    showingInvitationErrorAlert = true
                                }
                            }
                        }
                        return
                    }
                    
                    if let receivedStatus = receivedInvitation.status,
                       receivedStatus == .accepted,
                       let receivedId = receivedInvitationId,
                       !cancelledInvitationIds.contains(receivedId),
                       let scheduledDate = receivedInvitation.scheduledDate,
                       let location = receivedInvitation.location {
                        // 检查 schedule 是否已经 met
                        Task {
                            do {
                                let hasMet = try await supabaseService.checkCoffeeChatScheduleMet(
                                    userId: receiverUserId,
                                    participantId: currentUser.id,
                                    scheduledDate: scheduledDate,
                                    location: location
                                )
                                
                                await MainActor.run {
                                    if !hasMet {
                                        // 如果未 met，显示提示
                                        showingCoffeeInviteAlert = false
                                        invitationErrorMessage = "You already have a coffee chat scheduled"
                                        showingInvitationErrorAlert = true
                                    } else {
                                        // 如果已 met，允许发送新邀请
                                        performSendCoffeeChatInvitation(session: session, currentUser: currentUser, receiverUserId: receiverUserId)
                                    }
                                }
                            } catch {
                                print("❌ [检查 schedule met] 失败: \(error.localizedDescription)")
                                // 如果检查失败，保守处理：不允许发送
                                await MainActor.run {
                                    showingCoffeeInviteAlert = false
                                    invitationErrorMessage = "You already have a coffee chat scheduled"
                                    showingInvitationErrorAlert = true
                                }
                            }
                        }
                        return
                    }
                    
                    // 可以发送邀请
                    performSendCoffeeChatInvitation(session: session, currentUser: currentUser, receiverUserId: receiverUserId)
                }
            } catch {
                print("❌ [检查邀请] 失败: \(error.localizedDescription)")
                // 如果检查失败，仍然尝试发送（避免因为检查失败而阻止发送）
                await MainActor.run {
                    performSendCoffeeChatInvitation(session: session, currentUser: currentUser, receiverUserId: receiverUserId)
                }
            }
        }
    }
    
    private func performSendCoffeeChatInvitation(session: ChatSession, currentUser: AppUser, receiverUserId: String) {
        // 验证必填字段
        guard !sendInvitationLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ [发送邀请] 地点不能为空")
            // TODO: 显示错误提示给用户
            return
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
                
                // 获取发送者名称（使用 profile 中可修改的名字）
                var senderName = currentUser.name
                if let senderProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                    senderName = senderProfile.coreIdentity.name
                }
                
                // 创建邀请记录（包含发送者填写的信息）
                let invitationId = try await supabaseService.createCoffeeChatInvitation(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    senderName: senderName, // 使用 profile 中的名字
                    receiverName: receiverName,
                    scheduledDate: sendInvitationDate,
                    location: sendInvitationLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: sendInvitationNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sendInvitationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // 为接收方创建新的邀请消息（这样每次新邀请都会显示新的消息）
                // 发送邀请消息到数据库，让接收方能够看到新的邀请
                let invitationMessageContent = "\(senderName) invited you to a coffee chat" // 使用 profile 中的名字
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    content: invitationMessageContent,
                    messageType: "coffee_chat_invitation"
                )
                
                // 不发送消息到消息列表，只更新邀请信息
                await MainActor.run {
                    // 更新邀请信息
                    let sessionId = session.id.uuidString
                    currentInvitationInfo[sessionId] = (
                        status: .pending,
                        scheduledDate: nil,
                        location: nil,
                        invitationId: invitationId,
                        isSentByMe: true
                    )
                    
                    // 触发消息刷新，让接收方看到新的邀请消息
                    Task {
                        await refreshMessagesForCurrentSession()
                    }
                }
                
                print("✅ Coffee chat invitation sent to database: \(invitationId)")
            } catch {
                print("❌ Failed to send coffee chat invitation: \(error.localizedDescription)")
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
                educations: nil,
                yearsOfExperience: 3.0,
                careerStage: .midLevel,
                skills: user.interests,
                certifications: [],
                languagesSpoken: ["English"],
                workExperiences: []
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .connectShare,
                additionalIntentions: [],
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
                preferredMeetingVibes: [.casual],
                selfIntroduction: user.bio.isEmpty ? "Hi! I'm \(user.name). Let's connect!" : user.bio
            ),
            workPhotos: nil,
            lifestylePhotos: nil,
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
                
                // 保留本地的系统消息和已处理的coffee chat邀请消息（这些消息不会在数据库中，需要保留）
                let localSystemMessages = chatSessions[index].messages.filter { $0.messageType == .system }
                for systemMessage in localSystemMessages {
                    if !seenMessageIds.contains(systemMessage.id) {
                        uniqueMessages.append(systemMessage)
                        seenMessageIds.insert(systemMessage.id)
                    }
                }
                
                // 保留本地的已处理的coffee chat邀请消息（accepted或rejected状态）
                // 这些消息的状态不应该被新的pending邀请覆盖
                let localProcessedInvitations = chatSessions[index].messages.filter { message in
                    message.messageType == .coffeeChatInvitation && !message.isFromUser
                }
                for invitationMessage in localProcessedInvitations {
                    if !seenMessageIds.contains(invitationMessage.id) {
                        uniqueMessages.append(invitationMessage)
                        seenMessageIds.insert(invitationMessage.id)
                    }
                }
                
                // 按时间戳排序
                uniqueMessages.sort { $0.timestamp < $1.timestamp }
                
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
            
            // 保留本地的系统消息和已处理的coffee chat邀请消息（这些消息不会在数据库中，需要保留）
            let localSystemMessages = session.messages.filter { $0.messageType == .system }
            for systemMessage in localSystemMessages {
                if !seenMessageIds.contains(systemMessage.id) {
                    uniqueMessages.append(systemMessage)
                    seenMessageIds.insert(systemMessage.id)
                }
            }
            
            // 保留本地的已处理的coffee chat邀请消息（accepted或rejected状态）
            // 这些消息的状态不应该被新的pending邀请覆盖
            let localProcessedInvitations = session.messages.filter { message in
                message.messageType == .coffeeChatInvitation && !message.isFromUser
            }
            for invitationMessage in localProcessedInvitations {
                if !seenMessageIds.contains(invitationMessage.id) {
                    uniqueMessages.append(invitationMessage)
                    seenMessageIds.insert(invitationMessage.id)
                }
            }
            
            // 按时间戳排序
            uniqueMessages.sort { $0.timestamp < $1.timestamp }
            
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
                
                // 更新消息后，重新检查邀请状态（可能邀请已被拒绝）
                loadInvitationInfo(for: chatSessions[index])
                
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
                
                // 检查是否有新的邀请消息（来自对方）
                let previousInvitationMessages = session.messages.filter { $0.messageType == .coffeeChatInvitation && !$0.isFromUser }
                let newInvitationMessages = uniqueMessages.filter { $0.messageType == .coffeeChatInvitation && !$0.isFromUser }
                
                // 如果有新的邀请消息，确保滚动到它
                if newInvitationMessages.count > previousInvitationMessages.count,
                   let newInvitationMessage = newInvitationMessages.last {
                    // 延迟滚动，确保消息已渲染
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottomId = newInvitationMessage.id
                    }
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
        
        // 加载邀请信息
        loadInvitationInfo(for: session)
        
        // 标记来自对方的未读消息为已读
        Task {
            await markMessagesAsRead(for: session)
        }
    }
    
    // 加载邀请信息
    private func loadInvitationInfo(for session: ChatSession) {
        guard let currentUser = authManager.currentUser,
              let otherUserId = session.user.userId else {
            return
        }
        
        let sessionId = session.id.uuidString
        
        Task {
            do {
                // 检查是否有自己发送的邀请
                let sentInvitation = try await supabaseService.getCoffeeChatInvitationInfo(
                    senderId: currentUser.id,
                    receiverId: otherUserId
                )
                
                // 检查是否有对方发送的邀请
                let receivedInvitation = try await supabaseService.getCoffeeChatInvitationInfo(
                    senderId: otherUserId,
                    receiverId: currentUser.id
                )
                
                await MainActor.run {
                    // 检查邀请ID是否在已取消列表中
                    let sentInvitationId = sentInvitation.invitationId
                    let receivedInvitationId = receivedInvitation.invitationId
                    
                    // 如果邀请已被取消，不再显示
                    if let sentId = sentInvitationId, cancelledInvitationIds.contains(sentId) {
                        currentInvitationInfo.removeValue(forKey: sessionId)
                        return
                    }
                    
                    if let receivedId = receivedInvitationId, cancelledInvitationIds.contains(receivedId) {
                        currentInvitationInfo.removeValue(forKey: sessionId)
                        return
                    }
                    
                    // 检查自己发送的邀请是否被拒绝
                    if let sentStatus = sentInvitation.status,
                       sentStatus == .rejected,
                       let sentId = sentInvitationId,
                       !cancelledInvitationIds.contains(sentId) {
                        // 找到最新的会话数据
                        if let index = chatSessions.firstIndex(where: { $0.id == session.id }) {
                            let currentSession = chatSessions[index]
                            
                            // 如果邀请被拒绝，添加系统消息（如果还没有）
                            let hasRejectionMessage = currentSession.messages.contains { msg in
                                msg.messageType == .system && 
                                msg.content.contains("declined your coffee chat invitation")
                            }
                            
                            if !hasRejectionMessage {
                                // 获取接收者名称
                                let receiverName = currentSession.user.name
                                
                                // 添加系统消息：对方拒绝了你的邀请
                                let rejectionMessage = ChatMessage(
                                    content: "\(receiverName) declined your coffee chat invitation",
                                    isFromUser: false,
                                    messageType: .system
                                )
                                
                                chatSessions[index].addMessage(rejectionMessage)
                                chatSessions[index].lastMessageAt = rejectionMessage.timestamp
                                
                                if selectedSession?.id == session.id {
                                    selectedSession = chatSessions[index]
                                    scrollToBottomId = rejectionMessage.id
                                }
                            }
                        }
                        
                        // 不显示在置顶区域
                        currentInvitationInfo.removeValue(forKey: sessionId)
                        return
                    }
                    
                    // 优先显示自己发送的邀请，如果没有则显示收到的邀请
                    // 只显示pending或accepted状态的邀请，且未被取消
                    if let sentStatus = sentInvitation.status,
                       (sentStatus == .pending || sentStatus == .accepted),
                       let sentId = sentInvitationId,
                       !cancelledInvitationIds.contains(sentId) {
                        // 如果是 accepted 状态，需要检查是否已经 met
                        if sentStatus == .accepted,
                           let scheduledDate = sentInvitation.scheduledDate,
                           let location = sentInvitation.location {
                            // 异步检查 met 状态
                            Task {
                                do {
                                    let hasMet = try await supabaseService.checkCoffeeChatScheduleMet(
                                        userId: currentUser.id,
                                        participantId: otherUserId,
                                        scheduledDate: scheduledDate,
                                        location: location
                                    )
                                    
                                    await MainActor.run {
                                        // 如果已 met，不显示在置顶区域
                                        if hasMet {
                                            currentInvitationInfo.removeValue(forKey: sessionId)
                                        } else {
                                            currentInvitationInfo[sessionId] = (
                                                status: sentStatus,
                                                scheduledDate: scheduledDate,
                                                location: location,
                                                invitationId: sentId,
                                                isSentByMe: true
                                            )
                                        }
                                    }
                                } catch {
                                    print("❌ [加载邀请信息] 检查 met 状态失败: \(error.localizedDescription)")
                                    // 如果检查失败，保守处理：显示邀请
                                    await MainActor.run {
                                        currentInvitationInfo[sessionId] = (
                                            status: sentStatus,
                                            scheduledDate: scheduledDate,
                                            location: location,
                                            invitationId: sentId,
                                            isSentByMe: true
                                        )
                                    }
                                }
                            }
                        } else {
                            // pending 状态，直接显示
                            currentInvitationInfo[sessionId] = (
                                status: sentStatus,
                                scheduledDate: sentInvitation.scheduledDate,
                                location: sentInvitation.location,
                                invitationId: sentId,
                                isSentByMe: true
                            )
                        }
                    } else if let receivedStatus = receivedInvitation.status {
                        // 收到的邀请：如果是pending，不在置顶显示（在聊天框内显示）
                        // 如果是accepted，在置顶显示，但需要检查是否已 met
                        if receivedStatus == .accepted {
                            // 如果已经有 currentInvitationInfo（比如刚接受邀请时设置的），保留它
                            let existingInfo = currentInvitationInfo[sessionId]
                            
                            // 如果有 invitationId 且未被取消，检查 met 状态
                            if let receivedId = receivedInvitationId,
                               !cancelledInvitationIds.contains(receivedId),
                               let scheduledDate = receivedInvitation.scheduledDate,
                               let location = receivedInvitation.location {
                                // 异步检查 met 状态
                                Task {
                                    do {
                                        let hasMet = try await supabaseService.checkCoffeeChatScheduleMet(
                                            userId: otherUserId,
                                            participantId: currentUser.id,
                                            scheduledDate: scheduledDate,
                                            location: location
                                        )
                                        
                                        await MainActor.run {
                                            // 如果已 met，不显示在置顶区域
                                            if hasMet {
                                                currentInvitationInfo.removeValue(forKey: sessionId)
                                            } else {
                                                // 更新邀请信息，保留已有的信息（如果有）
                                                currentInvitationInfo[sessionId] = (
                                                    status: receivedStatus,
                                                    scheduledDate: scheduledDate,
                                                    location: location,
                                                    invitationId: receivedId,
                                                    isSentByMe: false
                                                )
                                            }
                                        }
                                    } catch {
                                        print("❌ [加载邀请信息] 检查 met 状态失败: \(error.localizedDescription)")
                                        // 如果检查失败，保守处理：显示邀请
                                        await MainActor.run {
                                            currentInvitationInfo[sessionId] = (
                                                status: receivedStatus,
                                                scheduledDate: scheduledDate,
                                                location: location,
                                                invitationId: receivedId,
                                                isSentByMe: false
                                            )
                                        }
                                    }
                                }
                            } else if let existingInfo = existingInfo,
                                      existingInfo.status == .accepted,
                                      existingInfo.scheduledDate != nil,
                                      existingInfo.location != nil {
                                // 如果 invitationId 为空（刚接受邀请时），但已有 accepted 状态的信息，保留它
                                // 不执行任何操作，保持现有的 currentInvitationInfo
                                print("✅ [加载邀请信息] 保留已有的 accepted 邀请信息（等待 invitationId 更新）")
                            } else {
                                // 如果没有 invitationId，但 receivedStatus 是 accepted，且没有 existingInfo
                                // 可能是数据库还没完全更新，尝试使用 receivedInvitation 的信息
                                if let scheduledDate = receivedInvitation.scheduledDate,
                                   let location = receivedInvitation.location {
                                    // 即使没有 invitationId，也显示 accepted 状态的邀请
                                    currentInvitationInfo[sessionId] = (
                                        status: receivedStatus,
                                        scheduledDate: scheduledDate,
                                        location: location,
                                        invitationId: receivedInvitationId,
                                        isSentByMe: false
                                    )
                                    print("✅ [加载邀请信息] 使用 receivedInvitation 的信息显示 accepted 邀请")
                                } else {
                                    // pending状态的收到邀请不在置顶显示，在聊天框内显示
                                    currentInvitationInfo.removeValue(forKey: sessionId)
                                }
                            }
                        } else {
                            // pending状态的收到邀请不在置顶显示，在聊天框内显示
                            // 但如果已有 accepted 状态的 existingInfo，保留它
                            if let existingInfo = currentInvitationInfo[sessionId],
                               existingInfo.status == .accepted,
                               existingInfo.scheduledDate != nil,
                               existingInfo.location != nil {
                                print("✅ [加载邀请信息] 保留已有的 accepted 邀请信息（数据库可能还在更新）")
                            } else {
                                currentInvitationInfo.removeValue(forKey: sessionId)
                            }
                        }
                    } else {
                        // 如果没有有效的邀请，确保移除
                        currentInvitationInfo.removeValue(forKey: sessionId)
                    }
                }
            } catch {
                print("❌ [加载邀请信息] 失败: \(error.localizedDescription)")
            }
        }
    }
    
    // Coffee Chat Invitation Banner (置顶区域)
    private func coffeeChatInvitationBanner(session: ChatSession, invitationInfo: (status: CoffeeChatInvitation.InvitationStatus?, scheduledDate: Date?, location: String?, invitationId: String?, isSentByMe: Bool)) -> some View {
        let isSentByMe = invitationInfo.isSentByMe
        
        return AnyView(
            HStack(spacing: 12) {
                // 信封图标
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
                
                // 内容区域
                VStack(alignment: .leading, spacing: 4) {
                    if invitationInfo.status == .accepted, let scheduledDate = invitationInfo.scheduledDate, let location = invitationInfo.location {
                        // 已接受：显示时间和地点
                        Text("Coffee chat scheduled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text(formatDate(scheduledDate))
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                            
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text(location)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                .lineLimit(1)
                        }
                    } else if invitationInfo.status == .pending {
                        // 待处理：显示已发送邀请或收到邀请
                        if isSentByMe {
                            Text("Coffee chat invitation sent")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        } else {
                            Text("\(session.user.name) invited you to a coffee chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                    } else {
                        Text("Coffee chat invitation")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                }
                
                Spacer()
                
                // 取消按钮
                if let invitationId = invitationInfo.invitationId {
                    // pending状态且是自己发送的邀请，或者accepted状态（双方都可以取消）
                    if (invitationInfo.status == .pending && isSentByMe) || invitationInfo.status == .accepted {
                        Button(action: {
                            if invitationInfo.status == .accepted {
                                cancelAcceptedCoffeeChat(invitationId: invitationId, session: session)
                            } else {
                                cancelInvitation(invitationId: invitationId, session: session)
                            }
                        }) {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.98, green: 0.96, blue: 0.94))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.8, green: 0.7, blue: 0.6), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.99, green: 0.98, blue: 0.97),
                        Color(red: 0.98, green: 0.96, blue: 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.5)),
                alignment: .bottom
            )
        )
    }
    
    // 格式化日期和时间
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
    
    // 取消邀请（pending状态）
    private func cancelInvitation(invitationId: String, session: ChatSession) {
        let sessionId = session.id.uuidString
        guard let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else { return }
        
        // 立即移除邀请信息，避免UI闪烁
        currentInvitationInfo.removeValue(forKey: sessionId)
        // 标记为已取消，防止重新加载（持久化保存）
        cancelledInvitationIds.insert(invitationId)
        saveCancelledInvitationIds()
        
        Task {
            do {
                // 1. 删除b那边的邀请消息（从数据库删除，不留痕迹）
                try await supabaseService.deleteMessagesByType(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    messageType: "coffee_chat_invitation"
                )
                
                // 2. 删除邀请记录
                try await supabaseService.cancelCoffeeChatInvitation(invitationId: invitationId)
                
                await MainActor.run {
                    // 确保邀请信息已移除
                    currentInvitationInfo.removeValue(forKey: sessionId)
                    
                    // 刷新消息，确保b那边的邀请消息消失
                    Task {
                        await refreshMessagesForCurrentSession()
                    }
                    
                    // 发送通知，触发刷新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoffeeChatInvitationCancelled"),
                        object: nil,
                        userInfo: [
                            "sessionId": sessionId,
                            "invitationId": invitationId,
                            "cancelledByName": currentUser.name
                        ]
                    )
                    
                    print("✅ [取消邀请] 邀请已取消，b那边的消息已删除")
                }
            } catch {
                print("❌ [取消邀请] 失败: \(error.localizedDescription)")
                // 即使失败也确保UI更新
                await MainActor.run {
                    // 确保邀请信息已移除（即使删除失败，UI也应该更新）
                    currentInvitationInfo.removeValue(forKey: sessionId)
                }
            }
        }
    }
    
    // 取消已接受的coffee chat
    private func cancelAcceptedCoffeeChat(invitationId: String, session: ChatSession) {
        let sessionId = session.id.uuidString
        guard let currentUser = authManager.currentUser,
              let receiverUserId = session.user.userId else { return }
        
        // 立即移除邀请信息，避免UI闪烁
        currentInvitationInfo.removeValue(forKey: sessionId)
        // 标记为已取消，防止重新加载（持久化保存）
        cancelledInvitationIds.insert(invitationId)
        saveCancelledInvitationIds()
        
        Task {
            do {
                // receiverUserId就是对方用户ID（session中的对方）
                // 在数据库中保存系统消息给对方："谁取消了这个约定"
                let cancelMessageContent = "\(currentUser.name) cancelled this coffee chat"
                
                // 发送给对方（系统消息会显示在双方的聊天记录中）
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: receiverUserId,
                    content: cancelMessageContent,
                    messageType: "system"
                )
                
                // 删除邀请和日程记录
                try await supabaseService.cancelAcceptedCoffeeChat(invitationId: invitationId)
                
                await MainActor.run {
                    // 确保邀请信息已移除
                    currentInvitationInfo.removeValue(forKey: sessionId)
                    
                    // 发送通知触发消息刷新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
                    
                    // 发送通知，触发刷新（通知对方也更新）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoffeeChatInvitationCancelled"),
                        object: nil,
                        userInfo: [
                            "sessionId": sessionId,
                            "invitationId": invitationId,
                            "cancelledByName": currentUser.name
                        ]
                    )
                    NotificationCenter.default.post(name: NSNotification.Name("CoffeeChatScheduleUpdated"), object: nil)
                    
                    print("✅ [取消已接受的coffee chat] 已取消，系统消息已保存到数据库")
                }
                print("✅ [取消已接受的coffee chat] 数据库删除成功")
            } catch {
                print("❌ [取消已接受的coffee chat] 失败: \(error.localizedDescription)")
                // 即使失败也确保UI更新
                await MainActor.run {
                    // 确保邀请信息已移除（即使删除失败，UI也应该更新）
                    currentInvitationInfo.removeValue(forKey: sessionId)
                }
            }
        }
    }
    
    // 处理邀请被取消的通知
    private func handleInvitationCancelled(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let sessionId = userInfo["sessionId"] as? String,
              let invitationId = userInfo["invitationId"] as? String,
              let cancelledByName = userInfo["cancelledByName"] as? String,
              let session = chatSessions.first(where: { $0.id.uuidString == sessionId }),
              let currentUser = authManager.currentUser else {
            return
        }
        
        // 标记为已取消（持久化保存）
        cancelledInvitationIds.insert(invitationId)
        saveCancelledInvitationIds()
        
        // 立即移除邀请信息
        currentInvitationInfo.removeValue(forKey: sessionId)
        
        // 系统消息已经在cancelAcceptedCoffeeChat中保存到数据库
        // 发送通知触发消息刷新
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
        
        // 不重新加载，因为已经标记为已取消
    }
    
    // 处理邀请被拒绝的通知
    private func handleInvitationRejected(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let senderId = userInfo["senderId"] as? String,
              let receiverId = userInfo["receiverId"] as? String,
              let receiverName = userInfo["receiverName"] as? String,
              let currentUser = authManager.currentUser else {
            return
        }
        
        // 检查是否是自己发送的邀请被拒绝（自己是发送者）
        if senderId == currentUser.id {
            // 系统消息已经在rejectCoffeeChatInvitation中保存到数据库
            // 发送通知触发消息刷新
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
        }
    }
    
    // 从 UserDefaults 加载已取消的邀请ID
    private func loadCancelledInvitationIds() {
        if let savedIds = UserDefaults.standard.array(forKey: cancelledInvitationIdsKey) as? [String] {
            cancelledInvitationIds = Set(savedIds)
            print("✅ [加载已取消邀请] 从 UserDefaults 加载了 \(cancelledInvitationIds.count) 个已取消的邀请ID")
        }
    }
    
    // 保存已取消的邀请ID到 UserDefaults
    private func saveCancelledInvitationIds() {
        UserDefaults.standard.set(Array(cancelledInvitationIds), forKey: cancelledInvitationIdsKey)
        print("✅ [保存已取消邀请] 保存了 \(cancelledInvitationIds.count) 个已取消的邀请ID")
    }
    
    // 处理邀请被接受的通知
    private func handleInvitationAccepted(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let senderId = userInfo["senderId"] as? String,
              let receiverId = userInfo["receiverId"] as? String,
              let scheduledDate = userInfo["scheduledDate"] as? Date,
              let location = userInfo["location"] as? String,
              let currentUser = authManager.currentUser else {
            return
        }
        
        // 检查是否是自己的邀请被接受（自己是发送者）
        if senderId == currentUser.id {
            // 清除缓存，强制重新加载以确保使用最新的 profile 名字
            Task {
                // 清除持久化缓存
                await MainActor.run {
                    if let currentUser = authManager.currentUser {
                        let cacheKey = "chat_sessions_cache_\(currentUser.id)"
                        let timeKey = "chat_sessions_cache_time_\(currentUser.id)"
                        UserDefaults.standard.removeObject(forKey: cacheKey)
                        UserDefaults.standard.removeObject(forKey: timeKey)
                        cachedChatSessions = []
                        lastChatLoadTime = nil
                        print("🗑️ [接受邀请] 清除缓存，强制重新加载")
                    }
                }
                
                // 重新加载会话列表，确保使用最新的 profile 名字
                await loadChatSessionsFromDatabase()
                
                // 找到对应的会话
                await MainActor.run {
                    if let session = chatSessions.first(where: { $0.user.userId == receiverId }) {
                        let sessionId = session.id.uuidString
                        
                        // 更新邀请信息
                        currentInvitationInfo[sessionId] = (
                            status: .accepted,
                            scheduledDate: scheduledDate,
                            location: location,
                            invitationId: nil, // 需要重新加载获取
                            isSentByMe: true
                        )
                        
                        // 重新加载邀请信息以获取invitationId
                        loadInvitationInfo(for: session)
                        
                        // 系统消息已经在acceptCoffeeChatInvitation中保存到数据库
                        // 发送通知触发消息刷新
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
                    }
                }
            }
        } else if receiverId == currentUser.id {
            // 自己接受了对方的邀请，更新邀请信息
            if let session = chatSessions.first(where: { $0.user.userId == senderId }) {
                let sessionId = session.id.uuidString
                
                // 更新邀请信息
                currentInvitationInfo[sessionId] = (
                    status: .accepted,
                    scheduledDate: scheduledDate,
                    location: location,
                    invitationId: nil, // 需要重新加载获取
                    isSentByMe: false
                )
                
                // 延迟重新加载邀请信息以获取invitationId（确保数据库已更新）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadInvitationInfo(for: session)
                }
            }
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
    let getCurrentAvatar: (ChatUser) -> String // 获取最新头像的函数
    let avatarVersion: Int // 头像刷新版本号
    let onTap: () -> Void
    let onUnmatch: () -> Void
    let onHide: (() -> Void)? // 可选的 Hide 操作
    let onUnhide: (() -> Void)? // 可选的 Unhide 操作
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        Button(action: onTap) {
            // 计算变量
            let currentAvatar = getCurrentAvatar(session.user)
            let unreadCount = session.unreadCount
            let shouldShowUnreadBadge = unreadCount > 0 && !session.isHidden
            
            HStack(alignment: .top, spacing: 12) {
                // Avatar - 使用最新头像和版本号确保刷新
                AvatarView(avatarString: currentAvatar, size: 50)
                    .id("avatar-\(session.user.id)-\(currentAvatar)-v\(avatarVersion)") // 使用版本号强制刷新
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.user.name)
                            .font(.system(size: 18, weight: .semibold))
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
                    
                    HStack(alignment: .center, spacing: 8) {
                        Text(displayMessage?.content ?? "Start chatting...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if shouldShowUnreadBadge {
                            Text("\(unreadCount)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(session.user.isMatched ? session.user.matchType.color : Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(10)
                        }
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
    @Binding var invitationStatusCache: [String: CoffeeChatInvitation.InvitationStatus]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var invitationStatus: CoffeeChatInvitation.InvitationStatus? = nil
    @State private var showingAcceptSheet = false
    @State private var selectedDate = Date()
    @State private var locationText = ""
    @State private var notesText = ""
    @State private var isLoadingStatus = false
    @State private var processedInvitationId: String? = nil // 记录已处理的邀请ID，防止被新邀请覆盖
    
    var body: some View {
        Group {
            // 系统消息居中显示
            if message.messageType == .system {
                HStack {
                    Spacer()
                    messageBubble
                    Spacer()
                }
            } else {
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
        }
        .onAppear {
            if message.messageType == .coffeeChatInvitation && invitationStatus == nil {
                loadInvitationStatus()
            }
        }
    }
    
    private var messageBubble: some View {
        Group {
            if message.messageType == .coffeeChatInvitation {
                coffeeChatInvitationBubble
            } else if message.messageType == .system {
                systemMessageBubble
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
    
    // System message bubble (更窄的确认消息框，居中显示，固定宽度)
    private var systemMessageBubble: some View {
                    HStack(alignment: .center, spacing: 12) {
            // 信封图标
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
                    .frame(width: 32, height: 32)
                                .shadow(color: Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.15), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        }
                        
            // 文字（居中对齐）
            Text(message.content)
                .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(2)
                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 280) // 固定宽度，确保所有系统消息大小一致
                                .background(
                                    LinearGradient(
                                        colors: [
                    Color(red: 0.99, green: 0.98, blue: 0.97),
                    Color(red: 0.98, green: 0.96, blue: 0.94)
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
                            Color(red: 0.95, green: 0.92, blue: 0.88).opacity(0.6),
                            Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    private var coffeeChatInvitationBubble: some View {
        Group {
            if !message.isFromUser {
                // 接收者：如果已接受或拒绝，直接消失（不显示邀请框）
                if invitationStatus == .accepted || invitationStatus == .rejected {
                    EmptyView()
                } else {
                    // 接收者：两行布局（只有pending状态才显示）
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
                        
                        // 第二行：显示 Accept 和 Decline 按钮（只有pending状态）
                        HStack(spacing: 10) {
                            Button(action: {
                                // 从邀请中获取发送者填写的信息并预填充
                                Task {
                                    guard let currentUser = authManager.currentUser,
                                          let otherUserId = session.user.userId else {
                                        return
                                    }
                                    
                                    // 确定 senderId 和 receiverId（别人发送的邀请）
                                    let senderId = otherUserId
                                    let receiverId = currentUser.id
                                    
                                    do {
                                        let invitationInfo = try await supabaseService.getCoffeeChatInvitationInfo(
                                            senderId: senderId,
                                            receiverId: receiverId
                                        )
                                        
                                        await MainActor.run {
                                            // 如果发送者已经填写了信息，预填充表单
                                            if let scheduledDate = invitationInfo.scheduledDate {
                                                selectedDate = scheduledDate
                                            }
                                            if let location = invitationInfo.location, !location.isEmpty {
                                                locationText = location
                                            }
                                            if let notes = invitationInfo.notes, !notes.isEmpty {
                                                notesText = notes
                                            }
                                            showingAcceptSheet = true
                                        }
                                    } catch {
                                        print("❌ [获取邀请信息] 失败: \(error.localizedDescription)")
                                        await MainActor.run {
                                            showingAcceptSheet = true
                                        }
                                    }
                                }
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
                                Task {
                                    guard let invitationId = await getInvitationId() else {
                                        print("❌ [拒绝邀请] 无法获取邀请ID")
                                        return
                                    }
                                    rejectCoffeeChatInvitation(invitationId: invitationId)
                                }
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
                    
                    // 状态显示：✅ 或 ❌（带背景框）
                    if let status = invitationStatus {
                        if status == .accepted {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.6, green: 0.45, blue: 0.3))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        } else if status == .rejected {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.6, green: 0.45, blue: 0.3))
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
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
                    // 验证已经在AcceptInvitationSheet中完成，这里直接执行
                    Task {
                        guard let invitationId = await getInvitationId() else {
                            print("❌ [接受邀请] 无法获取邀请ID")
                            await MainActor.run {
                                showingAcceptSheet = false
                                // 可以显示错误提示
                            }
                            return
                        }
                        acceptCoffeeChatInvitation(invitationId: invitationId)
                    }
                },
                onCancel: {
                    showingAcceptSheet = false
                }
            )
        }
    }
    
    private func acceptCoffeeChatInvitation(invitationId: String) {
        // 验证必填字段
        guard !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ [接受邀请] 地点不能为空")
            // TODO: 显示错误提示给用户
            return
        }
        
        guard let currentUser = authManager.currentUser,
              let otherUserId = session.user.userId else {
            return
        }
        
        // 确定 senderId 和 receiverId（别人发送的邀请）
        let senderId = otherUserId
        let receiverId = currentUser.id
        let cacheKey = getCacheKey(senderId: senderId, receiverId: receiverId)
        
        Task {
            do {
                print("🔄 [接受邀请] 开始接受邀请，invitationId: \(invitationId)")
                print("🔄 [接受邀请] scheduledDate: \(selectedDate)")
                print("🔄 [接受邀请] location: \(locationText)")
                print("🔄 [接受邀请] notes: \(notesText)")
                
                try await supabaseService.acceptCoffeeChatInvitation(
                    invitationId: invitationId,
                    scheduledDate: selectedDate,
                    location: locationText.trimmingCharacters(in: .whitespacesAndNewlines),
                    notes: notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                
                // 获取当前用户（接受者）的 profile，使用 profile 中可修改的用户名
                var receiverName = currentUser.name // 默认使用 currentUser.name
                if let currentUserProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                    receiverName = currentUserProfile.coreIdentity.name
                }
                
                // 在数据库中保存系统消息给发送者："接受者名字 accepted your coffee chat invitation"
                // 注意：这里的 receiverName 是接受邀请的人（当前用户）的名字
                let acceptMessageContent = "\(receiverName) accepted your coffee chat invitation"
                let _ = try await supabaseService.sendMessage(
                    senderId: receiverId, // 接受者发送给发送者
                    receiverId: senderId,
                    content: acceptMessageContent,
                    messageType: "system"
                )
                
                await MainActor.run {
                    invitationStatus = .accepted
                    processedInvitationId = invitationId // 记录已处理的邀请ID
                    // 更新缓存
                    invitationStatusCache[cacheKey] = .accepted
                    showingAcceptSheet = false
                    
                    // 发送通知，触发日程列表刷新和邀请信息更新
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoffeeChatInvitationAccepted"),
                        object: nil,
                        userInfo: [
                            "senderId": senderId,
                            "receiverId": receiverId,
                            "scheduledDate": selectedDate,
                            "location": locationText.trimmingCharacters(in: .whitespacesAndNewlines)
                        ]
                    )
                    NotificationCenter.default.post(name: NSNotification.Name("CoffeeChatScheduleUpdated"), object: nil)
                    
                    // 发送通知触发消息刷新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
                    
                    print("✅ [接受邀请] 已发送系统消息到数据库，已更新缓存")
                }
                
                print("✅ [接受邀请] Coffee chat invitation accepted successfully")
            } catch {
                print("❌ [接受邀请] Failed to accept invitation: \(error.localizedDescription)")
                print("❌ [接受邀请] 错误详情: \(error)")
                
                await MainActor.run {
                    // TODO: 显示错误提示给用户
                    // 可以添加一个 @State 变量来显示错误消息
                }
            }
        }
    }
    
    private func rejectCoffeeChatInvitation(invitationId: String) {
        guard let currentUser = authManager.currentUser,
              let otherUserId = session.user.userId else {
            return
        }
        
        // 确定 senderId 和 receiverId（别人发送的邀请）
        let senderId = otherUserId
        let receiverId = currentUser.id
        let cacheKey = getCacheKey(senderId: senderId, receiverId: receiverId)
        
        Task {
            do {
                try await supabaseService.rejectCoffeeChatInvitation(invitationId: invitationId)
                
                // 在数据库中保存系统消息给a："b declined your coffee chat invitation"
                let rejectMessageContent = "\(currentUser.name) declined your coffee chat invitation"
                let _ = try await supabaseService.sendMessage(
                    senderId: receiverId, // b发送给a
                    receiverId: senderId,
                    content: rejectMessageContent,
                    messageType: "system"
                )
                
                await MainActor.run {
                    invitationStatus = .rejected
                    processedInvitationId = invitationId // 记录已处理的邀请ID
                    // 更新缓存
                    invitationStatusCache[cacheKey] = .rejected
                    print("✅ [拒绝邀请] 已发送系统消息到数据库，已更新缓存")
                    
                    // 发送通知触发消息刷新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMessages"), object: nil)
                    
                    // 发送通知给邀请者，告知邀请被拒绝
                    NotificationCenter.default.post(
                        name: NSNotification.Name("CoffeeChatInvitationRejected"),
                        object: nil,
                        userInfo: [
                            "senderId": senderId,
                            "receiverId": receiverId,
                            "receiverName": currentUser.name
                        ]
                    )
                }
                print("✅ Coffee chat invitation rejected")
            } catch {
                print("❌ Failed to reject invitation: \(error.localizedDescription)")
            }
        }
    }
    
    // 获取缓存键（使用消息ID确保每个消息有独立的状态）
    private func getCacheKey(senderId: String, receiverId: String) -> String {
        // 使用消息ID作为缓存key的一部分，确保每个消息都有独立的状态
        return "\(message.id.uuidString)-\(senderId)-\(receiverId)"
    }
    
    // 加载邀请状态（带缓存）
    private func loadInvitationStatus() {
        guard !isLoadingStatus else { return }
        
        guard let currentUser = authManager.currentUser else {
            print("❌ [加载邀请状态] 当前用户为空")
            return
        }
        
        // 从 session 中获取对方的 userId
        guard let otherUserId = session.user.userId else {
            print("❌ [加载邀请状态] 无法获取对方的 userId")
            return
        }
        
        let senderId: String
        let receiverId: String
        
        if message.isFromUser {
            // 自己发送的邀请：senderId 是自己，receiverId 是对方
            senderId = currentUser.id
            receiverId = otherUserId
        } else {
            // 别人发送的邀请：senderId 是对方，receiverId 是自己
            senderId = otherUserId
            receiverId = currentUser.id
        }
        
        let cacheKey = getCacheKey(senderId: senderId, receiverId: receiverId)
        
        // 如果当前状态已经是 accepted 或 rejected，不再更新（保持原样）
        // 这是最重要的检查：确保已经处理过的邀请消息不会被新的pending邀请覆盖
        if let currentStatus = invitationStatus,
           (currentStatus == .accepted || currentStatus == .rejected) {
            print("✅ [加载邀请状态] 当前状态已是 \(currentStatus.rawValue)，保持原样（不查询数据库）")
            return
        }
        
        // 先从缓存读取
        // 注意：缓存键已经包含了消息ID，所以每个消息都有独立的缓存
        // 但是，我们需要先查询数据库，确保缓存的状态与数据库一致
        // 如果缓存中有状态，但数据库中没有匹配的邀请，说明可能是新邀请，应该重新查询
        if let cachedStatus = invitationStatusCache[cacheKey] {
            // 如果缓存的状态是accepted或rejected，且当前状态也是accepted或rejected，直接使用缓存
            // 这是为了保持已处理状态（即使邀请已被取消）
            if (cachedStatus == .accepted || cachedStatus == .rejected) &&
               (invitationStatus == .accepted || invitationStatus == .rejected) {
                invitationStatus = cachedStatus
                print("✅ [加载邀请状态] 从缓存恢复已处理状态: \(cachedStatus.rawValue)（即使邀请已被取消也保持）")
                return
            }
            // 如果缓存的状态是pending，且当前状态是nil，先查询数据库确认
            // 不直接使用缓存，因为可能是新邀请
            if cachedStatus == .pending && invitationStatus == nil {
                print("🔄 [加载邀请状态] 缓存中有pending状态，但需要查询数据库确认")
                // 继续执行，查询数据库
            } else {
                // 其他情况，使用缓存
            invitationStatus = cachedStatus
            print("✅ [加载邀请状态] 从缓存读取: \(cachedStatus.rawValue)")
            return
            }
        }
        
        // 缓存中没有，从数据库加载
        isLoadingStatus = true
        
        Task {
            do {
                // 根据消息时间戳查找对应的邀请（而不是总是查询最新的）
                let (matchedInvitationId, matchedStatus) = try await supabaseService.findInvitationByMessageTimestamp(
                    senderId: senderId,
                    receiverId: receiverId,
                    messageTimestamp: message.timestamp
                )
                
                // 如果找到了匹配的邀请
                if let invitationId = matchedInvitationId, let status = matchedStatus {
                await MainActor.run {
                        // 如果当前状态已经是 accepted 或 rejected，即使数据库返回其他状态，也保持原样
                        // 这是关键：一旦接受或拒绝，状态就永远不变，即使后来被取消
                        if let currentStatus = invitationStatus,
                           (currentStatus == .accepted || currentStatus == .rejected) {
                            print("✅ [加载邀请状态] 当前状态已是 \(currentStatus.rawValue)，保持原样（忽略数据库返回的状态）")
                            isLoadingStatus = false
                            return
                        }
                        
                        // 更新状态和邀请ID
                    invitationStatus = status
                        invitationStatusCache[cacheKey] = status
                        // 如果状态是accepted或rejected，记录邀请ID
                        if status == .accepted || status == .rejected {
                            processedInvitationId = invitationId
                    }
                        print("✅ [加载邀请状态] 已更新为: \(status.rawValue) (邀请ID: \(invitationId))")
                    isLoadingStatus = false
                    }
                    return
                }
                
                // 如果没有找到匹配的邀请（可能已被删除），但当前状态是 accepted 或 rejected，保持原样
                await MainActor.run {
                    if let currentStatus = invitationStatus,
                       (currentStatus == .accepted || currentStatus == .rejected) {
                        print("✅ [加载邀请状态] 未找到匹配的邀请，但当前状态已是 \(currentStatus.rawValue)，保持原样（邀请可能已被取消）")
                        isLoadingStatus = false
                        return
                    }
                }
                
                // 如果没有找到匹配的邀请，尝试查找最新的pending邀请（用于新消息）
                let latestInvitationId = try await supabaseService.findPendingInvitationId(
                    senderId: senderId,
                    receiverId: receiverId
                )
                
                // 如果当前消息已经处理过（有processedInvitationId），且新的邀请ID不同，说明是新邀请
                // 此时不应该更新当前消息的状态，应该保持原样
                if let processedId = processedInvitationId,
                   let latestId = latestInvitationId,
                   processedId != latestId {
                    print("✅ [加载邀请状态] 检测到新邀请（\(latestId)），但当前消息已处理过（\(processedId)），保持原样")
                    await MainActor.run {
                        isLoadingStatus = false
                    }
                    return
                }
                
                let status = try await supabaseService.getCoffeeChatInvitationStatus(
                    senderId: senderId,
                    receiverId: receiverId
                )
                
                await MainActor.run {
                    // 如果当前状态已经是 accepted 或 rejected，即使数据库返回 nil 或其他状态，也保持原样
                    // 这是为了确保已经处理过的邀请消息不会被新的pending邀请覆盖
                    if let currentStatus = invitationStatus,
                       (currentStatus == .accepted || currentStatus == .rejected) {
                        print("✅ [加载邀请状态] 当前状态已是 \(currentStatus.rawValue)，保持原样（忽略数据库返回的状态）")
                        isLoadingStatus = false
                        return
                    }
                    
                    // 只有当状态是 nil 或 pending 时，才更新状态
                    // 如果数据库返回的是 pending，说明有新的邀请，应该更新
                    // 但如果当前消息已经处理过（accepted/rejected），不应该被新邀请覆盖
                    if let newStatus = status {
                        // 只有当新状态是 pending 时，才更新（说明有新的邀请）
                        // 如果新状态是 accepted 或 rejected，也更新（可能是状态变化）
                        invitationStatus = newStatus
                        invitationStatusCache[cacheKey] = newStatus
                        // 如果状态是accepted或rejected，记录邀请ID
                        if newStatus == .accepted || newStatus == .rejected,
                           let latestId = latestInvitationId {
                            processedInvitationId = latestId
                        }
                        print("✅ [加载邀请状态] 已更新为: \(newStatus.rawValue)")
                    } else {
                        // 如果数据库返回 nil，说明没有pending的邀请
                        // 但如果当前状态已经是 accepted 或 rejected，保持原样
                        // 如果当前状态是 nil 或 pending，也保持 nil（没有邀请）
                        if invitationStatus == nil {
                            print("✅ [加载邀请状态] 没有找到邀请，保持 nil")
                        }
                    }
                    isLoadingStatus = false
                    print("✅ [加载邀请状态] 最终状态: \(invitationStatus?.rawValue ?? "nil")")
                }
            } catch {
                print("❌ [加载邀请状态] 失败: \(error.localizedDescription)")
                await MainActor.run {
                    // 如果加载失败，但当前状态已经是 accepted 或 rejected，保持原样
                    if let currentStatus = invitationStatus,
                       (currentStatus == .accepted || currentStatus == .rejected) {
                        print("✅ [加载邀请状态] 加载失败，但当前状态已是 \(currentStatus.rawValue)，保持原样")
                    }
                    isLoadingStatus = false
                }
            }
        }
    }
    
    // 从消息中提取邀请ID
    private func getInvitationId() async -> String? {
        guard let currentUser = authManager.currentUser else {
            print("❌ [接受邀请] 当前用户为空")
            return nil
        }
        
        // 从 session 中获取对方的 userId
        guard let receiverUserId = session.user.userId else {
            print("❌ [接受邀请] 无法获取对方的 userId")
            return nil
        }
        
        // 使用 findPendingInvitationId 查找对应的邀请ID
        do {
            let invitationId = try await supabaseService.findPendingInvitationId(
                senderId: receiverUserId, // 对方是发送者
                receiverId: currentUser.id // 当前用户是接收者
            )
            print("✅ [接受邀请] 找到邀请ID: \(invitationId ?? "nil")")
            return invitationId
        } catch {
            print("❌ [接受邀请] 查找邀请ID失败: \(error.localizedDescription)")
            return nil
        }
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
    @State private var showingLocationError = false
    
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
                            
                            Text("Review & Confirm")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            Text("You can modify the details below")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
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
                        // 验证必填字段
                        if locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            showingLocationError = true
                        } else {
                        onAccept()
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .alert("Notice", isPresented: $showingLocationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Location cannot be empty. Please enter a location.")
            }
        }
    }
}

// MARK: - Send Invitation Sheet
struct SendInvitationSheet: View {
    @Binding var selectedDate: Date
    @Binding var locationText: String
    @Binding var notesText: String
    let onSend: () -> Void
    let onCancel: () -> Void
    @State private var showingLocationError = false
    
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
                            
                            Text("Schedule Coffee Chat")
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
            .navigationTitle("Send Invitation")
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
                    Button("Send") {
                        // 验证必填字段
                        if locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            showingLocationError = true
                        } else {
                            onSend()
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .alert("Notice", isPresented: $showingLocationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Location cannot be empty. Please enter a location.")
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
    @State private var resolvedProStatus: Bool?
    @State private var resolvedVerifiedStatus: Bool?
    @State private var credibilityScore: CredibilityScore?
    @State private var selectedWorkExperience: WorkExperience?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    ProfileCardContentView(
                        profile: profile,
                        isConnection: isConnection,
                        isProUser: resolvedProStatus ?? false,
                    isVerified: resolvedVerifiedStatus,
                        currentUserLocation: currentUserLocation,
                        showDistance: true,
                        credibilityScore: credibilityScore,
                        onWorkExperienceTap: { workExp in
                            selectedWorkExperience = workExp
                        }
                    )
                    .background(Color.white)
                    .cornerRadius(28)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
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
            resolveProStatusIfNeeded()
            resolveVerifiedStatusIfNeeded()
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CredibilityScoreUpdated"))) { _ in
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedIn"))) { _ in
            loadCredibilityScore()
        }
        .sheet(item: $selectedWorkExperience) { workExp in
            WorkExperienceDetailSheet(
                workExperience: workExp,
                allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                industry: profile.professionalBackground.industry
            )
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
    
    private func resolveProStatusIfNeeded() {
        guard resolvedProStatus == nil else { return }
        
        Task {
            do {
                let proIds = try await supabaseService.getProUserIds(from: [profile.userId])
                await MainActor.run {
                    resolvedProStatus = proIds.contains(profile.userId)
                }
            } catch {
                print("⚠️ [ChatProfileCard] Failed to load Pro status: \(error.localizedDescription)")
            }
        }
    }
    
    private func resolveVerifiedStatusIfNeeded() {
        guard resolvedVerifiedStatus == nil else { return }
        
        Task {
            do {
                let verifiedIds = try await supabaseService.getVerifiedUserIds(from: [profile.userId])
                await MainActor.run {
                    resolvedVerifiedStatus = verifiedIds.contains(profile.userId)
                }
            } catch {
                print("⚠️ [ChatProfileCard] Failed to load verification status: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadCredibilityScore() {
        print("🔄 [ChatProfileCard] 开始加载信誉评分，userId: \(profile.userId)")
        Task {
            do {
                // 尝试从缓存加载
                if let cachedScore = CredibilityScoreCache.shared.getScore(for: profile.userId) {
                    print("✅ [ChatProfileCard] 从缓存加载信誉评分: \(cachedScore.averageRating)")
                    await MainActor.run {
                        credibilityScore = cachedScore
                    }
                    // 并在后台刷新缓存
                    Task { await refreshCredibilityScore(for: profile.userId) }
                    return
                }

                // 强制使用小写格式查询，确保与数据库一致
                if let score = try await supabaseService.getCredibilityScore(userId: profile.userId.lowercased()) {
                    print("✅ [ChatProfileCard] 成功加载信誉评分: \(score.averageRating)")
                    await MainActor.run {
                        credibilityScore = score
                        CredibilityScoreCache.shared.setScore(score, for: profile.userId)
                    }
                } else {
                    print("⚠️ [ChatProfileCard] 未找到评分记录，尝试使用原始 userId 查询...")
                    if let score = try? await supabaseService.getCredibilityScore(userId: profile.userId) {
                        print("✅ [ChatProfileCard] 使用原始格式查询成功: \(score.averageRating)")
                        await MainActor.run {
                            credibilityScore = score
                            CredibilityScoreCache.shared.setScore(score, for: profile.userId)
                        }
                    } else {
                        print("⚠️ [ChatProfileCard] 未找到评分记录，使用默认值")
                        await MainActor.run {
                            let defaultScore = CredibilityScore(userId: profile.userId)
                            credibilityScore = defaultScore
                            CredibilityScoreCache.shared.setScore(defaultScore, for: profile.userId)
                        }
                    }
                }
            } catch {
                print("❌ [ChatProfileCard] 无法加载信誉评分: \(error.localizedDescription)")
                await MainActor.run {
                    let defaultScore = CredibilityScore(userId: profile.userId)
                    credibilityScore = defaultScore
                    CredibilityScoreCache.shared.setScore(defaultScore, for: profile.userId)
                }
            }
        }
    }
    
    private func refreshCredibilityScore(for userId: String) async {
        do {
            if let score = try await supabaseService.getCredibilityScore(userId: userId.lowercased()) {
                await MainActor.run {
                    credibilityScore = score
                    CredibilityScoreCache.shared.setScore(score, for: userId)
                }
            }
        } catch {
            print("⚠️ [ChatProfileCard] 刷新信誉评分失败: \(error.localizedDescription)")
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
    private var privacySettings: VisibilitySettings {
        profile.privacyTrust.visibilitySettings
    }
    
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
}

// MARK: - Preference Keys for Scroll Detection
// Note: ScrollOffsetPreferenceKey and ContentHeightPreferenceKey are defined in ProfileSetupView.swift
struct ScrollViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preference Key for Hiding Tab Bar
struct HideTabBarPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
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
        
        // 在初始化时立即尝试从缓存加载（同步，仅检查内存缓存）
        if avatarString.hasPrefix("http://") || avatarString.hasPrefix("https://"),
           let cached = ImageCacheManager.shared.getCachedImage(from: avatarString) {
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
                .frame(width: size, height: size)
                .clipShape(Circle())
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
        
        // 先尝试从缓存加载（同步，仅检查内存缓存）
        if let cached = ImageCacheManager.shared.getCachedImage(from: avatarString) {
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

