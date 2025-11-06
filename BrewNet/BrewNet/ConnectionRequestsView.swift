import SwiftUI

// MARK: - Connection Requests View
struct ConnectionRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var requests: [ConnectionRequest] = []
    @State private var isLoading = true
    @State private var selectedRequest: ConnectionRequest?
    @State private var showingSentInvitations = false
    @State private var sentInvitations: [SupabaseInvitation] = []
    @State private var isLoadingSentInvitations = false
    @State private var showingTemporaryChats = false
    @State private var showingTemporaryChatDetail = false
    @State private var selectedTemporaryChatRequest: ConnectionRequest?
    @State private var totalUnreadTemporaryMessagesCount: Int = 0
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BrewTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    topBarView()
                    
                    // Main Content
                    if isLoading {
                        loadingView()
                    } else if requests.isEmpty {
                        noMoreRequestsView()
                    } else {
                        // List View
                        listView()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSentInvitations) {
                NavigationStack {
                    SentInvitationsListView(invitations: sentInvitations, isLoading: isLoadingSentInvitations)
                        .environmentObject(authManager)
                        .environmentObject(supabaseService)
                }
            }
            .sheet(isPresented: $showingTemporaryChats) {
                NavigationStack {
                    TemporaryChatsView(requests: requests)
                        .environmentObject(authManager)
                        .environmentObject(databaseManager)
                        .environmentObject(supabaseService)
                }
            }
            .sheet(isPresented: $showingTemporaryChatDetail) {
                if let request = selectedTemporaryChatRequest {
                    TemporaryChatDetailView(
                        request: request,
                        onDismiss: {
                            showingTemporaryChatDetail = false
                            selectedTemporaryChatRequest = nil
                            // 刷新连接请求列表和未读消息数（消息可能已被标记为已读）
                            Task {
                                loadConnectionRequests()
                                // 延迟一点刷新，确保数据库更新完成
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                                await MainActor.run {
                                    loadConnectionRequests()
                                }
                                await updateUnreadTemporaryMessagesCount()
                            }
                        }
                    )
                    .environmentObject(authManager)
                    .environmentObject(databaseManager)
                    .environmentObject(supabaseService)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TemporaryMessagesRead"))) { notification in
                // 当消息被标记为已读时，刷新连接请求列表和未读数
                Task {
                    // 延迟一点刷新，确保数据库更新完成
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    await MainActor.run {
                        loadConnectionRequests()
                    }
                    await updateUnreadTemporaryMessagesCount()
                }
            }
            .fullScreenCover(item: $selectedRequest) { request in
                ConnectionRequestDetailView(
                    request: request,
                    onDismiss: { selectedRequest = nil },
                    onAccept: { request in
                        handleAccept(request: request)
                        selectedRequest = nil
                    },
                    onReject: { request in
                        handleReject(request: request)
                        selectedRequest = nil
                    },
                    onMessage: { request in
                        // Handle message action
                        selectedRequest = nil
                    }
                )
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
            }
            .onAppear {
                loadConnectionRequests()
                loadSentInvitations()
                Task {
                    await updateUnreadTemporaryMessagesCount()
                }
            }
        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder
    private func topBarView() -> some View {
        HStack {
            // Temporary Chats Button (左上角)
            Button(action: {
                showingTemporaryChats = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 20))
                        .foregroundColor(themeBrown)
                    
                    // 未读消息徽章
                    if totalUnreadTemporaryMessagesCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 18, height: 18)
                            
                            Text("\(totalUnreadTemporaryMessagesCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 8, y: -8)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 18))
                    .foregroundColor(BrewTheme.accentColor)
                
                Text("Connection Requests (\(requests.count))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeBrown)
            }
            
            Spacer()
            
            // Sent Invitations Icon
            Button(action: {
                showingSentInvitations = true
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeBrown)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Loading View
    @ViewBuilder
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeBrownLight))
                .scaleEffect(1.2)
            
            Text("Loading connection requests...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List View
    @ViewBuilder
    private func listView() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(requests) { request in
                    CompactRequestCard(
                        request: request,
                        currentUserId: authManager.currentUser?.id,
                        onTap: {
                            // 点击卡片：如果有临时消息，直接跳转到临时聊天界面
                            if request.latestTemporaryMessage != nil {
                                selectedTemporaryChatRequest = request
                                showingTemporaryChatDetail = true
                            } else {
                                // 否则打开详情页面
                                selectedRequest = request
                            }
                        },
                        onArrowTap: {
                            // 点击箭头：总是跳转到详情页面（同意/不同意match界面）
                            selectedRequest = request
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - No More Requests View
    @ViewBuilder
    private func noMoreRequestsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(themeBrownLight)
            
            Text("All Done!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(themeBrown)
            
            Text("You've reviewed all connection requests.\nCheck back later for new requests!")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Actions
    private func handleReject(request: ConnectionRequest) {
        guard let currentUser = authManager.currentUser else { return }
        
        // Remove from list
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests.remove(at: index)
        }
        
        Task {
            do {
                // 拒绝邀请（更新状态为 rejected）
                _ = try await supabaseService.rejectInvitation(
                    invitationId: request.id,
                    userId: currentUser.id
                )
                
                print("✅ Rejected invitation from \(request.requesterProfile.name)")
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ConnectionRequestRejected"),
                        object: nil,
                        userInfo: ["request": request]
                    )
                }
            } catch {
                print("❌ Failed to reject invitation: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleAccept(request: ConnectionRequest) {
        guard let currentUser = authManager.currentUser else { return }
        
        // 保存索引以便失败时恢复
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else { return }
        
        // Remove from list
        requests.remove(at: index)
        
        Task {
            do {
                // 接受邀请（这会自动创建匹配记录，因为数据库有触发器）
                _ = try await supabaseService.acceptInvitation(
                    invitationId: request.id,
                    userId: currentUser.id
                )
                
                print("✅ Accepted invitation from \(request.requesterProfile.name)")
                
                // 同时保存到本地数据库
                await MainActor.run {
                    _ = databaseManager.createMatchEntity(
                        userId: currentUser.id,
                        matchedUserId: request.requesterId,
                        matchedUserName: request.requesterProfile.name,
                        matchType: "invitation_based"
                    )
                    
                    // 发送通知：邀请已接受
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ConnectionRequestAccepted"),
                        object: nil,
                        userInfo: ["request": request]
                    )
                    
                    // 发送通知：导航到 Chat 界面
                    // 延迟一点时间确保匹配记录已创建
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToChat"),
                            object: nil,
                            userInfo: ["matchedUserId": request.requesterId]
                        )
                    }
                }
            } catch {
                print("❌ Failed to accept invitation: \(error.localizedDescription)")
                await MainActor.run {
                    // 如果失败，恢复列表
                    requests.insert(request, at: min(index, requests.count))
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadConnectionRequests() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        isLoading = true
        Task {
            do {
                // 从 Supabase 获取收到的待处理邀请
                let supabaseInvitations = try await supabaseService.getPendingInvitations(userId: currentUser.id)
                
                // 获取所有已匹配的用户ID，用于过滤
                var matchedUserIds: Set<String> = []
                do {
                    let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                    for match in matches {
                        if match.userId == currentUser.id {
                            matchedUserIds.insert(match.matchedUserId)
                        } else if match.matchedUserId == currentUser.id {
                            matchedUserIds.insert(match.userId)
                        }
                    }
                } catch {
                    print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
                }
                
                // 过滤掉已经匹配的邀请
                let filteredInvitations = supabaseInvitations.filter { invitation in
                    !matchedUserIds.contains(invitation.senderId)
                }
                
                print("📊 Filtered connection requests: \(filteredInvitations.count) remaining (removed \(supabaseInvitations.count - filteredInvitations.count) already matched)")
                
                // 转换为 ConnectionRequest 模型
                var convertedRequests: [ConnectionRequest] = []
                
                for invitation in filteredInvitations {
                    // 获取发送者的 profile 信息
                    var requesterProfile = ConnectionRequestProfile(
                        profilePhoto: nil,
                        name: "Unknown",
                        jobTitle: "",
                        company: "",
                        location: "",
                        bio: "",
                        expertise: [],
                        backgroundImage: nil
                    )
                    
                    // 从 senderProfile JSONB 中提取信息
                    if let senderProfile = invitation.senderProfile {
                        requesterProfile = ConnectionRequestProfile(
                            profilePhoto: senderProfile.profileImage,
                            name: senderProfile.name,
                            jobTitle: senderProfile.jobTitle ?? "",
                            company: senderProfile.company ?? "",
                            location: senderProfile.location ?? "",
                            bio: senderProfile.bio ?? "",
                            expertise: senderProfile.expertise ?? [],
                            backgroundImage: nil
                        )
                    } else {
                        // 如果没有 senderProfile，尝试从 profile 表获取
                        if let senderProfile = try? await supabaseService.getProfile(userId: invitation.senderId) {
                            let brewNetProfile = senderProfile.toBrewNetProfile()
                            requesterProfile = ConnectionRequestProfile(
                                profilePhoto: brewNetProfile.coreIdentity.profileImage,
                                name: brewNetProfile.coreIdentity.name,
                                jobTitle: brewNetProfile.professionalBackground.jobTitle ?? "",
                                company: brewNetProfile.professionalBackground.currentCompany ?? "",
                                location: brewNetProfile.coreIdentity.location ?? "",
                                bio: brewNetProfile.coreIdentity.bio ?? "",
                                expertise: brewNetProfile.professionalBackground.skills,
                                backgroundImage: nil
                            )
                        }
                    }
                    
                    // 解析创建时间
                    let dateFormatter = ISO8601DateFormatter()
                    let createdAt = dateFormatter.date(from: invitation.createdAt) ?? Date()
                    
                    // 加载该请求的临时消息
                    var temporaryMessages: [TemporaryMessage] = []
                    do {
                        let messages = try await supabaseService.getTemporaryMessagesFromSender(
                            receiverId: currentUser.id,
                            senderId: invitation.senderId
                        )
                        var tempMessages = messages.map { TemporaryMessage(from: $0) }
                        
                        // 限制最多10条消息（保留最新的10条）
                        if tempMessages.count > 10 {
                            tempMessages.sort(by: { $0.timestamp < $1.timestamp })
                            tempMessages = Array(tempMessages.suffix(10))
                        }
                        
                        temporaryMessages = tempMessages
                        print("✅ [请求页面] 从 \(requesterProfile.name) 加载了 \(temporaryMessages.count) 条临时消息")
                        if temporaryMessages.count > 0 {
                            print("📝 [请求页面] 最新消息: \(temporaryMessages.last?.content.prefix(50) ?? "无")")
                        }
                    } catch {
                        print("⚠️ [请求页面] 加载临时消息失败: \(error.localizedDescription)")
                    }
                    
                    var connectionRequest = ConnectionRequest(
                        id: invitation.id,
                        requesterId: invitation.senderId,
                        requesterName: requesterProfile.name,
                        requesterProfile: requesterProfile,
                        reasonForInterest: invitation.reasonForInterest,
                        createdAt: createdAt,
                        isFeatured: false // 可以根据需要设置
                    )
                    connectionRequest.temporaryMessages = temporaryMessages
                    
                    convertedRequests.append(connectionRequest)
                }
                
                await MainActor.run {
                    self.requests = convertedRequests
                    self.isLoading = false
                    print("✅ Loaded \(convertedRequests.count) connection requests from database")
                }
                
                // 更新未读临时消息数
                await updateUnreadTemporaryMessagesCount()
                
            } catch {
                print("❌ Failed to load connection requests: \(error.localizedDescription)")
                await MainActor.run {
                    self.requests = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Load Sent Invitations
    private func loadSentInvitations() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingSentInvitations = true
        Task {
            do {
                let fetchedInvitations = try await supabaseService.getSentInvitations(userId: currentUser.id)
                await MainActor.run {
                    sentInvitations = fetchedInvitations
                    isLoadingSentInvitations = false
                    print("✅ Loaded \(fetchedInvitations.count) sent invitations")
                }
            } catch {
                print("❌ Failed to load sent invitations: \(error.localizedDescription)")
                await MainActor.run {
                    sentInvitations = []
                    isLoadingSentInvitations = false
                }
            }
        }
    }
    
    // MARK: - Update Unread Temporary Messages Count
    private func updateUnreadTemporaryMessagesCount() async {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                totalUnreadTemporaryMessagesCount = 0
            }
            return
        }
        
        do {
            // 获取所有发送给我的临时消息（包括虚拟请求的用户）
            let allTemporaryMessages = try await supabaseService.getTemporaryMessages(receiverId: currentUser.id)
            
            // 统计未读消息数（只统计对方发送给我的未读消息）
            let unreadCount = allTemporaryMessages.filter { message in
                !message.isRead && message.senderId != currentUser.id
            }.count
            
            await MainActor.run {
                totalUnreadTemporaryMessagesCount = unreadCount
                print("📊 [临时消息] 更新未读消息数: \(unreadCount)")
            }
        } catch {
            print("⚠️ Failed to update unread temporary messages count: \(error.localizedDescription)")
            await MainActor.run {
                // 如果获取失败，使用 requests 中的消息计算（作为后备方案）
                totalUnreadTemporaryMessagesCount = requests.reduce(0) { $0 + $1.unreadTemporaryMessageCount(currentUserId: currentUser.id) }
            }
        }
    }
}

// MARK: - Temporary Message Bubble
struct TemporaryMessageBubble: View {
    let message: TemporaryMessage
    let unreadCount: Int
    let currentUserId: String?
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    // 只显示对方发送给我的未读消息的红点
    private var shouldShowUnreadDot: Bool {
        guard let currentUserId = currentUserId else { return false }
        return !message.isRead && message.senderId != currentUserId
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Message bubble icon
            Image(systemName: "message.fill")
                .font(.system(size: 12))
                .foregroundColor(themeBrown)
            
            // Message content
            Text(message.content)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(themeBrown)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Unread indicator (只显示对方发送给我的未读消息)
            if shouldShowUnreadDot {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(themeBrownLight.opacity(0.2))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeBrown.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Compact Request Card
struct CompactRequestCard: View {
    let request: ConnectionRequest
    let currentUserId: String?
    let onTap: () -> Void
    let onArrowTap: () -> Void
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Photo - 加载真实的用户头像
            ZStack(alignment: .topTrailing) {
                Group {
                    if let profileImageURL = request.requesterProfile.profilePhoto, !profileImageURL.isEmpty {
                        AsyncImage(url: URL(string: profileImageURL)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 70, height: 70)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 70, height: 70)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            case .failure(_):
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(BrewTheme.secondaryBrown)
                            @unknown default:
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(BrewTheme.secondaryBrown)
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 70))
                            .foregroundColor(BrewTheme.secondaryBrown)
                    }
                }
                
                // Verified badge if featured
                if request.isFeatured {
                    Circle()
                        .fill(BrewTheme.accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 5, y: -5)
                }
            }
            
            // Profile Info
            VStack(alignment: .leading, spacing: 6) {
                // Name
                Text(request.requesterProfile.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeBrown)
                
                // Temporary Message Bubble (if exists)
                if let latestMessage = request.latestTemporaryMessage {
                    TemporaryMessageBubble(
                        message: latestMessage,
                        unreadCount: request.unreadTemporaryMessageCount,
                        currentUserId: currentUserId
                    )
                    .padding(.top, 2)
                }
                
                // Reason for interest (only show if no message)
                if request.latestTemporaryMessage == nil, let reason = request.reasonForInterest {
                    Text(reason)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Company and Location
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(request.requesterProfile.company)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                // Time ago
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(request.timeAgo)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Chevron (独立点击处理，跳转到详情页面)
            Button(action: {
                onArrowTap()
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Connection Request Detail View
struct ConnectionRequestDetailView: View {
    let request: ConnectionRequest
    let onDismiss: () -> Void
    let onAccept: (ConnectionRequest) -> Void
    let onReject: (ConnectionRequest) -> Void
    let onMessage: (ConnectionRequest) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var showMessageSheet = false
    @State private var requesterProfile: BrewNetProfile?
    @State private var isLoadingProfile = true
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isLoadingProfile {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let profile = requesterProfile {
                        // Reason for Interest Section (if exists) - shown at top
                        if let reason = request.reasonForInterest {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(BrewTheme.accentColor)
                                    Text("Reason for Interest")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(themeBrown)
                                }
                                
                                Text(reason)
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                            .frame(minHeight: 100)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                        
                        // Use unified PublicProfileCardView
                        PublicProfileCardView(profile: profile)
                            .padding(.top, request.reasonForInterest != nil ? 16 : 0)
                        
                        // Add padding at bottom for action buttons
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Bottom Action Buttons
                VStack {
                    Spacer()
                    bottomActionButtons()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeBrown)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
            .sheet(isPresented: $showMessageSheet) {
                LeaveMessageView(
                    request: request,
                    onDismiss: { showMessageSheet = false },
                    onSend: { message in
                        handleSendMessage(message: message)
                        showMessageSheet = false
                        onMessage(request)
                    }
                )
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
            }
            .onAppear {
                loadRequesterProfile()
            }
        }
    }
    
    
    // Load requester's full profile
    private func loadRequesterProfile() {
        isLoadingProfile = true
        Task {
            do {
                if let profile = try await supabaseService.getProfile(userId: request.requesterId) {
                    await MainActor.run {
                        requesterProfile = profile.toBrewNetProfile()
                        isLoadingProfile = false
                        print("✅ Loaded requester profile: \(profile.coreIdentity.name)")
                    }
                } else {
                    await MainActor.run {
                        isLoadingProfile = false
                        print("⚠️ Failed to load requester profile")
                    }
                }
            } catch {
                print("❌ Failed to load requester profile: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }
    
    private func handleSendMessage(message: String) {
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        print("💬 Sending temporary message to \(request.requesterProfile.name): \(message)")
        
        Task {
            do {
                // 发送临时消息到 Supabase
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: request.requesterId,
                    content: message,
                    messageType: "temporary" // 标记为临时消息
                )
                print("✅ Temporary message sent successfully")
            } catch {
                print("❌ Failed to send temporary message: \(error.localizedDescription)")
            }
        }
    }
    
    @ViewBuilder
    private func bottomActionButtons() -> some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                Spacer()
                
                // Decline Button
                Button(action: {
                    onReject(request)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Message Button
                Button(action: {
                    showMessageSheet = true
                }) {
                    Image(systemName: "message")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeBrown)
                        .frame(width: 58, height: 58)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(themeBrown, lineWidth: 2)
                        )
                }
                
                Spacer()
                
                // Accept Button
                Button(action: {
                    onAccept(request)
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(BrewTheme.gradientPrimary())
                        .clipShape(Circle())
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
}

// MARK: - Leave Message View
struct LeaveMessageView: View {
    let request: ConnectionRequest
    let onDismiss: () -> Void
    let onSend: (String) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    private let maxMessageLength = 200
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top instruction area
                VStack(spacing: 16) {
                    // Profile info
                    VStack(spacing: 8) {
                        Group {
                            if let profileImageURL = request.requesterProfile.profilePhoto, !profileImageURL.isEmpty {
                                AsyncImage(url: URL(string: profileImageURL)) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 60, height: 60)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                    case .failure(_):
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(themeBrownLight)
                                    @unknown default:
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(themeBrownLight)
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeBrownLight)
                            }
                        }
                        
                        Text("Leave a message for \(request.requesterProfile.name)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeBrown)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Text("You're not connected yet. This is your first step to reach out")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Info box
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(BrewTheme.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message Info")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeBrown)
                            Text("You can send each other messages up to \(maxMessageLength) characters")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(themeBrownLight.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                
                Divider()
                
                // Message input area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Write your message")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeBrown)
                        .padding(.horizontal, 20)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextFieldFocused ? themeBrown : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .frame(height: 150)
                        
                        TextEditor(text: $messageText)
                            .font(.system(size: 16))
                            .padding(8)
                            .frame(height: 140)
                            .scrollContentBackground(.hidden)
                            .focused($isTextFieldFocused)
                            .onChange(of: messageText) { newValue in
                                if newValue.count > maxMessageLength {
                                    messageText = String(newValue.prefix(maxMessageLength))
                                }
                            }
                        
                        // Character counter overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(messageText.count)/\(maxMessageLength)")
                                    .font(.system(size: 12))
                                    .foregroundColor(messageText.count > maxMessageLength * 90 / 100 ? .orange : .gray)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14))
                                .foregroundColor(BrewTheme.accentColor)
                            Text("Tips:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeBrown)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TipRow(text: "Introduce yourself and your professional background")
                            TipRow(text: "Explain why you share common interests")
                            TipRow(text: "Express your interest in collaboration or networking")
                        }
                        .padding(.leading, 22)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                
                Spacer()
                
                // Send button
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: {
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend(messageText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Send Message")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(
                            Group {
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Color.gray.opacity(0.5)
                                } else {
                                    BrewTheme.gradientPrimary()
                                }
                            }
                        )
                        .cornerRadius(12)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.white)
            }
            .background(BrewTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeBrown)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BrewTheme.primaryBrown.opacity(0.3))
                .frame(width: 5, height: 5)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Temporary Chats View
struct TemporaryChatsView: View {
    let requests: [ConnectionRequest]
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedRequest: ConnectionRequest?
    @State private var showingChatDetail = false
    @State private var refreshedRequests: [ConnectionRequest] = []
    @State private var isLoading = false
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    // 过滤出有临时消息的请求
    private var requestsWithMessages: [ConnectionRequest] {
        let requestsToUse = refreshedRequests.isEmpty ? requests : refreshedRequests
        return requestsToUse.filter { !$0.temporaryMessages.isEmpty }
    }
    
    var body: some View {
        ZStack {
            BrewTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                topBarView()
                
                // Content
                if requestsWithMessages.isEmpty {
                    emptyStateView()
                } else {
                    messagesListView()
                }
            }
        }
        .navigationBarHidden(true)
        .refreshable {
            await refreshMessages()
        }
        .onAppear {
            Task {
                await refreshMessages()
            }
        }
        .sheet(isPresented: $showingChatDetail) {
            if let request = selectedRequest {
                TemporaryChatDetailView(
                    request: request,
                    onDismiss: {
                        showingChatDetail = false
                        selectedRequest = nil
                        // 刷新消息列表（消息可能已被标记为已读）
                        Task {
                            await refreshMessages()
                            // 延迟一点刷新，确保数据库更新完成
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                            await refreshMessages()
                        }
                    }
                )
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TemporaryMessagesRead"))) { notification in
            // 当消息被标记为已读时，刷新列表
            Task {
                await refreshMessages()
            }
        }
    }
    
    // MARK: - Refresh Messages
    private func refreshMessages() async {
        guard let currentUser = authManager.currentUser else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // 并行获取所有消息
            async let receivedMessagesTask = supabaseService.getTemporaryMessages(receiverId: currentUser.id)
            async let sentMessagesTask = supabaseService.getSentTemporaryMessages(senderId: currentUser.id)
            
            let (receivedTemporaryMessages, sentTemporaryMessages) = try await (receivedMessagesTask, sentMessagesTask)
            print("🔍 [临时聊天] 查询到 \(receivedTemporaryMessages.count) 条发送给我的临时消息，\(sentTemporaryMessages.count) 条我发送的临时消息")
            
            // 按对方用户ID分组
            var messagesByOtherUser: [String: [SupabaseMessage]] = [:]
            
            // 处理发送给我的消息
            for message in receivedTemporaryMessages {
                let otherUserId = message.senderId
                if messagesByOtherUser[otherUserId] == nil {
                    messagesByOtherUser[otherUserId] = []
                }
                messagesByOtherUser[otherUserId]?.append(message)
            }
            
            // 处理我发送的消息
            for message in sentTemporaryMessages {
                let otherUserId = message.receiverId
                if messagesByOtherUser[otherUserId] == nil {
                    messagesByOtherUser[otherUserId] = []
                }
                messagesByOtherUser[otherUserId]?.append(message)
            }
            
            print("🔍 [临时聊天] 共有 \(messagesByOtherUser.count) 个用户有临时消息")
            
            // 收集所有需要处理的用户ID
            var allUserIds: Set<String> = []
            for request in requests {
                allUserIds.insert(request.requesterId)
            }
            for (userId, _) in messagesByOtherUser {
                allUserIds.insert(userId)
            }
            
            // 批量并行获取所有用户的消息和 profile
            var messagesMap: [String: [SupabaseMessage]] = [:]
            var profilesMap: [String: BrewNetProfile] = [:]
            
            await withTaskGroup(of: Void.self) { group in
                // 并行获取所有用户的消息
                for userId in allUserIds {
                    group.addTask {
                        do {
                            let messages = try await supabaseService.getTemporaryMessagesFromSender(
                                receiverId: currentUser.id,
                                senderId: userId
                            )
                            await MainActor.run {
                                messagesMap[userId] = messages
                            }
                        } catch {
                            print("⚠️ Failed to get messages for \(userId): \(error.localizedDescription)")
                        }
                    }
                }

                // 并行获取所有用户的 profile（只获取虚拟请求需要的）
                let virtualUserIds = messagesByOtherUser.keys.filter { userId in
                    !requests.contains { $0.requesterId == userId }
                }
                for userId in virtualUserIds {
                    group.addTask {
                        if let profile = try? await supabaseService.getProfile(userId: userId) {
                            await MainActor.run {
                                profilesMap[userId] = profile.toBrewNetProfile()
                            }
                        }
                    }
                }
            }
            
            // 处理已有请求的消息
            var updatedRequests: [ConnectionRequest] = []
            for request in requests {
                let messages = messagesMap[request.requesterId] ?? []
                var temporaryMessages = messages.map { TemporaryMessage(from: $0) }
                
                // 限制最多10条消息（保留最新的10条）
                if temporaryMessages.count > 10 {
                    temporaryMessages.sort(by: { $0.timestamp < $1.timestamp })
                    temporaryMessages = Array(temporaryMessages.suffix(10))
                }
                
                var updatedRequest = request
                updatedRequest.temporaryMessages = temporaryMessages
                updatedRequests.append(updatedRequest)
            }
            
            // 为没有连接请求但有临时消息的用户创建虚拟请求
            for (otherUserId, _) in messagesByOtherUser {
                // 检查是否已经有对应的请求
                let hasRequest = updatedRequests.contains { $0.requesterId == otherUserId }
                
                if !hasRequest, let profile = profilesMap[otherUserId] {
                    let messages = messagesMap[otherUserId] ?? []
                    var temporaryMessages = messages.map { TemporaryMessage(from: $0) }
                    
                    // 限制最多10条消息（保留最新的10条）
                    if temporaryMessages.count > 10 {
                        temporaryMessages.sort(by: { $0.timestamp < $1.timestamp })
                        temporaryMessages = Array(temporaryMessages.suffix(10))
                    }
                    
                    let requesterProfile = ConnectionRequestProfile(
                        profilePhoto: profile.coreIdentity.profileImage,
                        name: profile.coreIdentity.name,
                        jobTitle: profile.professionalBackground.jobTitle ?? "",
                        company: profile.professionalBackground.currentCompany ?? "",
                        location: profile.coreIdentity.location ?? "",
                        bio: profile.coreIdentity.bio ?? "",
                        expertise: profile.professionalBackground.skills,
                        backgroundImage: nil
                    )
                    
                    let virtualRequest = ConnectionRequest(
                        id: UUID().uuidString,
                        requesterId: otherUserId,
                        requesterName: requesterProfile.name,
                        requesterProfile: requesterProfile,
                        reasonForInterest: nil,
                        createdAt: temporaryMessages.first?.timestamp ?? Date(),
                        isFeatured: false
                    )
                    var mutableRequest = virtualRequest
                    mutableRequest.temporaryMessages = temporaryMessages
                    updatedRequests.append(mutableRequest)
                    
                    print("✅ [临时聊天] 为用户 \(requesterProfile.name) 创建虚拟请求，包含 \(temporaryMessages.count) 条消息")
                }
            }
            
            await MainActor.run {
                refreshedRequests = updatedRequests
                isLoading = false
                print("✅ Refreshed temporary messages for \(updatedRequests.count) requests (including virtual requests)")
            }
        } catch {
            print("❌ Failed to refresh messages: \(error.localizedDescription)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder
    private func topBarView() -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeBrown)
            }
            
            Spacer()
            
            Text("Temporary Chats")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeBrown)
            
            Spacer()
            
            // 占位符保持对称
            Color.clear
                .frame(width: 18, height: 18)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .font(.system(size: 60))
                .foregroundColor(themeBrownLight)
            
            Text("No Temporary Messages")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(themeBrown)
            
            Text("When you receive temporary messages\nfor connection requests, they will appear here")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Messages List
    @ViewBuilder
    private func messagesListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(requestsWithMessages) { request in
                    TemporaryChatCard(request: request)
                        .environmentObject(authManager)
                        .onTapGesture {
                            selectedRequest = request
                            showingChatDetail = true
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Temporary Chat Card
struct TemporaryChatCard: View {
    let request: ConnectionRequest
    @EnvironmentObject var authManager: AuthManager
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    // 计算未读消息数量（只统计对方发送给我的）
    private var unreadCount: Int {
        guard let currentUser = authManager.currentUser else { return 0 }
        return request.unreadTemporaryMessageCount(currentUserId: currentUser.id)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Avatar - 加载真实的用户头像
            Group {
                if let profileImageURL = request.requesterProfile.profilePhoto, !profileImageURL.isEmpty {
                    AsyncImage(url: URL(string: profileImageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                        case .failure(_):
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(themeBrownLight)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(themeBrownLight)
                        }
                    }
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(themeBrownLight)
                }
            }
            
            // Message Info
            VStack(alignment: .leading, spacing: 6) {
                // Name and Unread Badge
                HStack(spacing: 8) {
                    Text(request.requesterProfile.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeBrown)
                    
                    if unreadCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Latest Message Preview
                if let latestMessage = request.latestTemporaryMessage {
                    Text(latestMessage.content)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Time
                if let latestMessage = request.latestTemporaryMessage {
                    Text(timeAgoString(from: latestMessage.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Unread Count Badge
            if unreadCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    
                    Text("\(unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Temporary Chat Detail View
struct TemporaryChatDetailView: View {
    let request: ConnectionRequest
    let onDismiss: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var messages: [TemporaryMessage] = []
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    private let maxMessageLength = 200
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrewTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    TemporaryMessageBubbleView(message: message, isFromUser: message.senderId == authManager.currentUser?.id)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .onAppear {
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: messages.count) { _ in
                            if let lastMessage = messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    messageInputView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeBrown)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(request.requesterProfile.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeBrown)
                        
                        Text("Temporary Chat")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                loadMessages()
                // 延迟一点标记已读，确保消息已加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    markAllMessagesAsRead()
                }
            }
            .refreshable {
                await refreshMessages()
            }
        }
    }
    
    // MARK: - Message Input View
    @ViewBuilder
    private func messageInputView() -> some View {
        VStack(spacing: 0) {
            // Message Count Indicator
            if messages.count > 0 {
                HStack {
                    Spacer()
                    Text("\(messages.count)/10 messages")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                // Text Field
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeBrownLight.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                    .disabled(messages.count >= 10) // 达到10条时禁用输入
                    .onChange(of: messageText) { newValue in
                        if newValue.count > maxMessageLength {
                            messageText = String(newValue.prefix(maxMessageLength))
                        }
                    }
                
                // Send Button
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Group {
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messages.count >= 10 {
                                    Color.gray.opacity(0.5)
                                } else {
                                    BrewTheme.gradientPrimary()
                                }
                            }
                        )
                        .clipShape(Circle())
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || messages.count >= 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }
    
    // MARK: - Load Messages
    private func loadMessages() {
        Task {
            await refreshMessages()
        }
    }
    
    // MARK: - Refresh Messages
    private func refreshMessages() async {
        guard let currentUser = authManager.currentUser else { return }
        
        do {
            // 重新从数据库加载最新的临时消息
            let latestMessages = try await supabaseService.getTemporaryMessagesFromSender(
                receiverId: currentUser.id,
                senderId: request.requesterId
            )
            
            let temporaryMessages = latestMessages.map { TemporaryMessage(from: $0) }
            
            await MainActor.run {
                var sortedMessages = temporaryMessages.sorted(by: { $0.timestamp < $1.timestamp })
                
                // 限制最多10条消息（保留最新的10条）
                if sortedMessages.count > 10 {
                    sortedMessages = Array(sortedMessages.suffix(10))
                    print("⚠️ [临时聊天] 消息数量超过10条，已保留最新的10条")
                }
                
                messages = sortedMessages
                print("✅ Refreshed \(messages.count) messages in chat detail")
            }
        } catch {
            print("⚠️ Failed to refresh messages: \(error.localizedDescription)")
            // 如果刷新失败，使用原来的消息列表
            await MainActor.run {
                var sortedMessages = request.temporaryMessages.sorted(by: { $0.timestamp < $1.timestamp })
                // 即使使用原有消息，也限制为10条
                if sortedMessages.count > 10 {
                    sortedMessages = Array(sortedMessages.suffix(10))
                }
                messages = sortedMessages
            }
        }
    }
    
    // MARK: - Mark All Messages As Read
    private func markAllMessagesAsRead() {
        guard let currentUser = authManager.currentUser else { return }
        
        Task {
            // 等待消息加载完成
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 找到所有未读的消息（对方发送给我的）
            let unreadMessages = messages.filter { message in
                !message.isRead && message.senderId != currentUser.id
            }
            
            if !unreadMessages.isEmpty {
                print("📖 [临时聊天] 标记 \(unreadMessages.count) 条消息为已读")
                
                // 批量标记为已读
                for message in unreadMessages {
                    do {
                        try await supabaseService.markMessageAsRead(messageId: message.id)
                        print("✅ [临时聊天] 已标记消息 \(message.id) 为已读")
                    } catch {
                        print("⚠️ Failed to mark message \(message.id) as read: \(error.localizedDescription)")
                    }
                }
                
                // 先刷新消息列表（从数据库重新加载已更新的状态）
                await refreshMessages()
                
                // 刷新临时聊天列表（通知父视图更新）
                NotificationCenter.default.post(
                    name: NSNotification.Name("TemporaryMessagesRead"),
                    object: nil,
                    userInfo: ["requesterId": request.requesterId]
                )
            } else {
                print("ℹ️ [临时聊天] 没有未读消息需要标记")
            }
        }
    }
    
    // MARK: - Send Message
    private func sendMessage() {
        guard let currentUser = authManager.currentUser,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // 检查消息数量限制（最多10条）
        let currentMessageCount = messages.count
        if currentMessageCount >= 10 {
            print("⚠️ [临时聊天] 消息数量已达上限（10条），无法发送新消息")
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        
        Task {
            do {
                let sentMessage = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: request.requesterId,
                    content: content,
                    messageType: "temporary"
                )
                
                // 创建本地消息对象
                let newMessage = TemporaryMessage(from: sentMessage)
                
                await MainActor.run {
                    messages.append(newMessage)
                    messages = messages.sorted(by: { $0.timestamp < $1.timestamp })
                    
                    // 如果超过10条，只保留最新的10条
                    if messages.count > 10 {
                        messages = Array(messages.suffix(10))
                        print("⚠️ [临时聊天] 消息数量超过10条，已保留最新的10条")
                    }
                }
                
                print("✅ Temporary message sent successfully")
                
                // 刷新消息列表以确保显示最新消息
                await refreshMessages()
            } catch {
                print("❌ Failed to send temporary message: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Temporary Message Bubble View
struct TemporaryMessageBubbleView: View {
    let message: TemporaryMessage
    let isFromUser: Bool
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        HStack {
            if isFromUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isFromUser ? .white : themeBrown)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isFromUser {
                                BrewTheme.gradientPrimary()
                            } else {
                                themeBrownLight.opacity(0.15)
                            }
                        }
                    )
                    .cornerRadius(18)
                
                Text(timeAgoString(from: message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !isFromUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ConnectionRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRequestsView()
            .environmentObject(AuthManager())
            .environmentObject(DatabaseManager.shared)
            .environmentObject(SupabaseService.shared)
    }
}

