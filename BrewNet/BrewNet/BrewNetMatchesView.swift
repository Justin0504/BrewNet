import SwiftUI
import CoreLocation
import Supabase

// MARK: - BrewNet Matches View (New implementation with BrewNetProfile)
struct BrewNetMatchesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var profiles: [BrewNetProfile] = []
    @State private var cachedProfiles: [BrewNetProfile] = [] // 缓存数据
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle = 0.0
    @State private var showingMatchAlert = false
    @State private var matchedProfile: BrewNetProfile?
    @State private var likedProfiles: [BrewNetProfile] = []
    @State private var passedProfiles: [BrewNetProfile] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var isRefreshing = false // 后台刷新标识
    @State private var hasMoreProfiles = true
    // For main matching page, isConnection is always false (only show public fields)
    private let isConnection: Bool = false
    @State private var errorMessage: String?
    @State private var totalFetched = 0
    @State private var totalFiltered = 0
    @State private var lastLoadTime: Date? = nil // 记录上次加载时间
    @State private var isCacheFromRecommendation = false // 标记缓存是否来自推荐系统
    @State private var savedFirstProfile: BrewNetProfile? = nil // 保存切换前的第一个profile
    @State private var hasAppearedBefore = false // 标记是否已经显示过
    @State private var shouldForceRefresh = false // 标记是否强制刷新（忽略缓存）
    @State private var showingTemporaryChat = false
    @State private var selectedProfileForChat: BrewNetProfile?
    @State private var showingMatchFilter = false
    @State private var showingIncreaseExposure = false
    @State private var currentFilter: MatchFilter? = nil
    @State private var showSubscriptionPayment = false
    @State private var showInviteLimitAlert = false
    @State private var proUsers: Set<String> = []
    @State private var verifiedUsers: Set<String> = []
    @State private var isProcessingLike = false
    @State private var isTransitioning = false // 标记是否正在过渡
    @State private var nextProfileOffset: CGFloat = 0 // 下一个 profile 的偏移量
    @State private var showAddMessagePrompt = false // 显示添加消息提示弹窗
    @State private var profilePendingInvitation: BrewNetProfile? = nil // 待发送邀请的profile
    @State private var currentUserIsPro: Bool? = nil // 缓存当前用户的 Pro 状态
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    private let recommendationService = RecommendationService.shared
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Buttons - 放在卡片上方
                HStack {
                    // 左上角按钮 - Match Filter
                    Button(action: {
                        showingMatchFilter = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 35) // 避免状态栏重叠
                    
                    Spacer()
                    
                    // 右上角按钮 - 星星图标
                    Button(action: {
                        showingIncreaseExposure = true
                    }) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 35) // 避免状态栏重叠
                }
                .padding(.bottom, 0) // 与卡片之间的间距
                
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .frame(height: screenHeight * 0.6)
                }
                // Cards Stack（确保 profiles 不为空且当前索引有效）
                else if !profiles.isEmpty && currentIndex < profiles.count {
                    ZStack {
                        // Next card (background) - 平滑过渡，添加跟随效果
                        if currentIndex + 1 < profiles.count {
                            UserProfileCardView(
                                profile: profiles[currentIndex + 1],
                                dragOffset: .constant(.zero),
                                rotationAngle: .constant(0),
                                onSwipe: { _ in },
                                isConnection: isConnection,
                                isPro: proUsers.contains(profiles[currentIndex + 1].userId),
                                isVerified: verifiedUsers.contains(profiles[currentIndex + 1].userId),
                                showsOuterFrame: false,
                                cardWidth: screenWidth - 4
                            )
                            .scaleEffect(isTransitioning ? 1.0 : (0.95 + min(abs(dragOffset.width) / (screenWidth * 2), 0.05)))
                            .offset(y: isTransitioning ? 0 : (10 - min(abs(dragOffset.width) / 20, 5)))
                            .offset(x: nextProfileOffset)
                            .opacity(isTransitioning ? 1.0 : (0.8 + min(abs(dragOffset.width) / (screenWidth * 2), 0.2)))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTransitioning)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: nextProfileOffset)
                            .animation(.easeOut(duration: 0.1), value: dragOffset.width)
                        }
                        
                        // Current card (foreground)
                        if !isTransitioning {
                            UserProfileCardView(
                                profile: profiles[currentIndex],
                                dragOffset: $dragOffset,
                                rotationAngle: $rotationAngle,
                                onSwipe: handleSwipe,
                                isConnection: isConnection,
                                isPro: proUsers.contains(profiles[currentIndex].userId),
                                isVerified: verifiedUsers.contains(profiles[currentIndex].userId),
                                showsOuterFrame: false,
                                cardWidth: screenWidth - 4
                            )
                            .opacity(1.0)
                        }
                    }
                    .frame(height: screenHeight * 0.8)
                } else {
                    // No more profiles
                    noMoreProfilesView
                }
                
                // Loading more indicator
                if isLoadingMore {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading more profiles...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 20)
                }
                
                Spacer()
            }
            
            // Error message
            if let errorMessage = errorMessage {
                VStack {
                    Spacer()
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
            }
            
            // Action Buttons - 保持在卡片上层（只在有卡片时显示）
            if !isLoading && currentIndex < profiles.count {
                VStack {
                    Spacer()
                    actionButtonsView
                        .padding(.bottom, 55) // 放在底部，距离底部一点距离，避免与导航栏重叠
                        .zIndex(100) // 确保按钮在最上层
                }
            }
        }
        .sheet(isPresented: $showingTemporaryChat) {
            if let profile = selectedProfileForChat {
                TemporaryChatFromProfileView(
                    profile: profile,
                    onDismiss: {
                        showingTemporaryChat = false
                        selectedProfileForChat = nil
                    },
                    onSend: { message in
                        handleTemporaryChatSend(message: message, profile: profile)
                    }
                )
                .environmentObject(authManager)
                .environmentObject(supabaseService)
            }
        }
        .sheet(isPresented: $showingMatchFilter) {
            MatchFilterView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showingIncreaseExposure) {
            IncreaseExposureView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showSubscriptionPayment) {
            if let userId = authManager.currentUser?.id {
                SubscriptionPaymentView(currentUserId: userId) {
                    Task {
                        // 刷新用户信息
                        await authManager.refreshUser()
                        // 清除 Pro 状态缓存，强制重新检查
                        await MainActor.run {
                            currentUserIsPro = nil
                        }
                        // 重新加载 Pro 状态
                        preloadCurrentUserProStatus()
                    }
                }
            }
        }
        .onChange(of: authManager.currentUser?.isProActive) { isPro in
            // 当用户的 Pro 状态变化时，更新缓存
            if let isPro = isPro {
                currentUserIsPro = isPro
                print("✅ [临时聊天] Pro 状态已更新: \(isPro ? "Pro用户" : "普通用户")")
            }
        }
        .onChange(of: currentIndex) { _ in
            // 当索引改变时，预加载下一个卡片的头像
            preloadProfileImages()
        }
        .onChange(of: profiles.count) { _ in
            // 当 profiles 加载完成时，预加载头像
            if !profiles.isEmpty {
                preloadProfileImages()
            }
        }
        .alert("No Connects Left", isPresented: $showInviteLimitAlert) {
            Button("Subscribe to Pro") {
                showInviteLimitAlert = false
                showSubscriptionPayment = true
            }
            Button("Cancel", role: .cancel) {
                showInviteLimitAlert = false
            }
        } message: {
            Text("You've used all 6 connects for today. Upgrade to BrewNet Pro for unlimited connections and more exclusive features.")
        }
        .overlay {
            if showAddMessagePrompt {
                addMessagePromptView
            }
        }
        .onAppear {
            // 预加载当前用户的 Pro 状态，优化临时聊天打开速度
            preloadCurrentUserProStatus()
            
            // 加载保存的filter
            loadSavedFilter()
            
            // 先尝试从持久化缓存加载（包括索引）
            loadCachedProfilesFromStorage()
            
            // 预加载当前和下一个卡片的头像
            preloadProfileImages()
            
            // 如果有缓存数据且来自推荐系统，且距离上次加载不到5分钟
            if !cachedProfiles.isEmpty && isCacheFromRecommendation, let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 {
                // 如果之前已经显示过（切换tab回来），恢复上次切走时的索引
                if hasAppearedBefore {
                    // 先显示缓存，但立即启动异步验证过滤
                    profiles = cachedProfiles
                    currentIndex = restoreCurrentIndex() // 恢复切换tab时的索引
                    
                    // 确保索引有效
                    if currentIndex >= profiles.count && !profiles.isEmpty {
                        currentIndex = 0
                    }
                    
                    isLoading = false
                    
                    // 立即进行快速验证和过滤（异步，但会尽快更新显示）
                    Task {
                        await quickValidateAndFilterCache()
                    }
                    
                    // 后台完整验证并更新（会进一步过滤并更新缓存）
                    Task {
                        await validateAndDisplayCache()
                    }
                } else {
                    // 首次加载（登录时），如果 SplashScreen 已经预热完成，直接显示缓存
                    // 如果缓存来自 SplashScreen 预热（推荐系统），直接显示，无需加载状态
                    if isCacheFromRecommendation && !cachedProfiles.isEmpty {
                        // SplashScreen 已经预热完成，直接显示缓存
                        profiles = cachedProfiles
                        isLoading = false
                        print("✅ Displaying pre-warmed profiles from SplashScreen (\(cachedProfiles.count) profiles)")
                        
                        // 后台进行验证和过滤（不影响显示）
                        Task {
                            await quickValidateAndFilterCache()
                            await validateAndDisplayCache()
                        }
                    } else {
                        // 缓存为空或不是来自推荐系统，显示加载状态
                    isLoading = true
                        
                        // 如果缓存为空，直接加载新数据
                        if cachedProfiles.isEmpty {
                            loadProfiles()
                        } else {
                            // 立即进行快速验证和过滤（等待完成后再显示，避免显示错误的用户）
                            Task {
                                await quickValidateAndFilterCache()
                                
                                // 快速验证完成后，检查是否还有有效数据
                                await MainActor.run {
                                    if profiles.isEmpty && cachedProfiles.isEmpty {
                                        // 如果过滤后没有数据，加载新数据
                                        print("⚠️ No valid profiles after quick filter, loading new profiles...")
                                        loadProfiles()
                                    } else {
                                        // 有有效数据，更新显示
                                        isLoading = false
                    if currentIndex < profiles.count {
                        let profile = profiles[currentIndex]
                                            print("⚡ Display after quick validation: showing profile at index \(currentIndex) (\(profile.coreIdentity.name)) from last session")
                                        } else if !profiles.isEmpty {
                                            currentIndex = 0
                                            isLoading = false
                                        }
                                    }
                    }
                    
                                // 后台完整验证并更新（会进一步过滤并更新缓存）
                        await validateAndDisplayCache()
                            }
                        }
                    }
                }
            } else {
                // 首次加载、缓存过期或缓存不是来自推荐系统，清除并重新加载
                if !cachedProfiles.isEmpty {
                    print("⚠️ Clearing invalid cache (not from recommendation system or expired)")
                    clearInvalidCache()
                }
                loadProfiles()
            }
            
            // 标记已显示过
            hasAppearedBefore = true
        }
        .onDisappear {
            // 保存当前索引（用于切换tab或退出登录时恢复）
            saveCurrentIndex()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplyMatchFilter"))) { notification in
            if let filter = notification.userInfo?["filter"] as? MatchFilter {
                applyFilter(filter)
            }
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
            Button("Keep Swiping") {
                showingMatchAlert = false
            }
            Button("View Match") {
                // 导航到聊天页面并选中匹配的用户
                if let profile = matchedProfile {
                    // 发送通知，包含匹配的用户ID，并切换到聊天 tab
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToChat"),
                        object: nil,
                        userInfo: ["userId": profile.userId]
                    )
                }
                showingMatchAlert = false
            }
        } message: {
            if let profile = matchedProfile {
                Text("You and \(profile.coreIdentity.name) liked each other!")
            }
        }
    }
    
    private var noMoreProfilesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text(hasMoreProfiles ? "Loading More..." : "No More Profiles")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            if hasMoreProfiles {
                Text("You've seen \(profiles.count) profiles.\nLoading more from database...")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                if profiles.count == 0 {
                    VStack(spacing: 8) {
                        Text("No New Recommendations Available")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Text("Possible reasons:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                        Text("• All users have already been interacted with\n• No more users in the database\n• Please try again later or refresh")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
            } else {
                Text("You've seen all available profiles!\n\(profiles.count) profiles loaded.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                }
            }
            
            if totalFiltered > 0 {
                Text("Note: \(totalFiltered) profiles were filtered due to incomplete data")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if hasMoreProfiles {
                Button("Load More") {
                    loadMoreProfiles()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                .cornerRadius(25)
            } else {
                Button("Refresh") {
                    refreshProfiles()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                .cornerRadius(25)
            }
        }
        .padding(40)
        .frame(height: screenHeight * 0.6)
        .onAppear {
            // 自动加载更多（如果还有数据）
            if hasMoreProfiles && !isLoadingMore {
                loadMoreProfiles()
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 30) {
            // Pass button
            Button(action: {
                swipeLeft()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .disabled(currentIndex >= profiles.count)
            
            // Temporary Chat button (新增)
            Button(action: {
                openTemporaryChat()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .disabled(currentIndex >= profiles.count)
            
            // Like button
            Button(action: {
                Task {
                    await likeProfile(triggeredByButton: true)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
            .disabled(currentIndex >= profiles.count || isProcessingLike)
        }
    }
    
    private func openTemporaryChat() {
        guard currentIndex < profiles.count else { return }
        guard let currentUser = authManager.currentUser else { return }
        
        let profile = profiles[currentIndex]
        selectedProfileForChat = profile
        
        // 如果已经缓存了 Pro 状态，立即显示界面
        if let isPro = currentUserIsPro {
            if isPro {
                showingTemporaryChat = true
            } else {
                showSubscriptionPayment = true
            }
            return
        }
        
        // 立即显示界面，在后台检查 Pro 状态
        showingTemporaryChat = true
        
        // 在后台检查 Pro 状态
        Task {
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                await MainActor.run {
                    // 缓存 Pro 状态
                    currentUserIsPro = canChat
                    
                    // 如果不是 Pro 用户，关闭临时聊天界面并显示订阅页面
                    if !canChat {
                        showingTemporaryChat = false
                        showSubscriptionPayment = true
                    }
                }
            } catch {
                print("❌ Failed to check Pro status: \(error.localizedDescription)")
                // 如果检查失败，假设是 Pro 用户，保持界面打开
            }
        }
    }
    
    // MARK: - Check Pro Status and Open Chat (for Add Message button)
    private func checkProStatusAndOpenChat(profile: BrewNetProfile) {
        guard let currentUser = authManager.currentUser else { return }
        
        selectedProfileForChat = profile
        
        // 如果已经缓存了 Pro 状态，直接决定
        if let isPro = currentUserIsPro {
            if isPro {
                showingTemporaryChat = true
            } else {
                showSubscriptionPayment = true
            }
            return
        }
        
        // 检查 Pro 状态
        Task {
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                await MainActor.run {
                    // 缓存 Pro 状态
                    currentUserIsPro = canChat
                    
                    if canChat {
                        // Pro 用户，打开临时聊天界面
                        showingTemporaryChat = true
                    } else {
                        // 普通用户，显示订阅窗口
                        showSubscriptionPayment = true
                    }
                }
            } catch {
                print("❌ Failed to check Pro status: \(error.localizedDescription)")
                // 如果检查失败，显示订阅窗口（更安全的选择）
                await MainActor.run {
                    showSubscriptionPayment = true
                }
            }
        }
    }
    
    private func handleTemporaryChatSend(message: String, profile: BrewNetProfile) {
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        // 关闭聊天界面
        showingTemporaryChat = false
        selectedProfileForChat = nil
        
        // 发送临时消息并创建 connection request
        Task {
            do {
                // Check invitation quota first
                let canInvite = try await supabaseService.decrementUserLikes(userId: currentUser.id)
                if !canInvite {
                    await MainActor.run {
                        showInviteLimitAlert = true
                    }
                    return
                }
                
                // 1. 发送临时消息
                let _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: profile.userId,
                    content: message,
                    messageType: "temporary"
                )
                print("✅ Temporary message sent successfully")
                
                // 2. 创建 connection request (invitation)
                var senderProfile: InvitationProfile? = nil
                if let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let brewNetProfile = currentUserProfile.toBrewNetProfile()
                    senderProfile = brewNetProfile.toInvitationProfile()
                }
                
                let invitation = try await supabaseService.sendInvitation(
                    senderId: currentUser.id,
                    receiverId: profile.userId,
                    reasonForInterest: nil,
                    senderProfile: senderProfile
                )
                
                print("✅ Connection request created: \(invitation.id)")
                
                // 3. 记录 Like 交互（因为发送临时消息相当于表达兴趣）
                await recommendationService.recordLike(
                    userId: currentUser.id,
                    targetUserId: profile.userId
                )
                
                // 4. 跳到下一个 profile
                await MainActor.run {
                    moveToNextProfile()
                }
                
            } catch {
                print("❌ Failed to send temporary chat: \(error.localizedDescription)")
                // 即使失败也跳到下一个 profile
                await MainActor.run {
                    moveToNextProfile()
                }
            }
        }
    }
    
    private func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            passProfile()
        case .right:
            Task {
                await likeProfile(triggeredByButton: false)
            }
        case .none:
            break
        }
    }

    private func swipeLeft() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = CGSize(width: -screenWidth * 1.5, height: 0)
            rotationAngle = -20
        }
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            passProfile()
        }
    }
    
    private func passProfile() {
        guard currentIndex < profiles.count else { return }
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        let profile = profiles[currentIndex]
        passedProfiles.append(profile)
        
        // 开始平滑过渡
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isTransitioning = true
            nextProfileOffset = 0
        }
        
        // 等待过渡动画完成后再更新索引和移除 profile
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 从列表中移除已拒绝的 profile
            // 注意：移除后，后面的元素会自动前移，所以当前索引会指向下一个 profile
            proUsers.remove(profile.userId)
            verifiedUsers.remove(profile.userId)
            profiles.remove(at: currentIndex)
            
            // 同时从缓存中移除，确保切换 tab 后不会再次显示
            cachedProfiles.removeAll { $0.userId == profile.userId }
            
            // 如果移除后当前索引超出范围，调整索引
            // 如果索引超出范围，应该保持在最后一个有效索引，而不是重置为 0
            if currentIndex >= profiles.count && !profiles.isEmpty {
                currentIndex = profiles.count - 1
            } else if profiles.isEmpty {
                // 如果列表为空，尝试加载更多
                if hasMoreProfiles {
                    loadMoreProfiles()
                }
            }
            // 如果 currentIndex < profiles.count，说明索引仍然有效，不需要改变
            // 因为移除后，原来索引 currentIndex+1 的 profile 现在在索引 currentIndex 的位置
            
            // 重置动画状态
            dragOffset = .zero
            rotationAngle = 0
            isTransitioning = false
            nextProfileOffset = 0
            
            // 立即更新持久化缓存，确保切换 tab 后不会显示已拒绝的用户
            saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
            
            // 记录 Pass 交互（异步，不阻塞UI）
            Task {
                await recommendationService.recordPass(
                    userId: currentUser.id,
                    targetUserId: profile.userId
                )
            }
            
            print("❌ Passed profile: \(profile.coreIdentity.name), new index: \(currentIndex), profiles count: \(profiles.count)")
        }
    }
    
    private func likeProfile(triggeredByButton: Bool) async {
        guard !isProcessingLike else { return }
        guard currentIndex < profiles.count else { return }
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }

        isProcessingLike = true
        defer { isProcessingLike = false }

        let profile = profiles[currentIndex]

        do {
            let canLike = try await supabaseService.decrementUserLikes(userId: currentUser.id)
            if !canLike {
                await MainActor.run {
                    print("⚠️ No likes remaining, showing alert")
                    showInviteLimitAlert = true
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = .zero
                        rotationAngle = 0
                    }
                }
                return
            }

            // Check if this is the first like today - show prompt only on first like
            let isFirstLike = try await supabaseService.isFirstLikeToday(userId: currentUser.id)
            if isFirstLike {
                // Update the first_like_today to current date
                try await supabaseService.updateFirstLikeToday(userId: currentUser.id)
                
                await MainActor.run {
                    profilePendingInvitation = profile
                    showAddMessagePrompt = true
                    // Reset animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        dragOffset = .zero
                        rotationAngle = 0
                    }
                }
                return // Stop here and wait for user action
            }

            if triggeredByButton {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = CGSize(width: screenWidth * 1.5, height: 0)
                        rotationAngle = 20
                    }
                    // 触觉反馈
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                // Allow animation to complete
                try? await Task.sleep(nanoseconds: 250_000_000)
            }

            await MainActor.run {
                likedProfiles.append(profile)
            }

            await recommendationService.recordLike(
                userId: currentUser.id,
                targetUserId: profile.userId
            )

            var senderProfile: InvitationProfile? = nil
            if let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = currentUserProfile.toBrewNetProfile()
                senderProfile = brewNetProfile.toInvitationProfile()
            }

            let invitation = try await supabaseService.sendInvitation(
                senderId: currentUser.id,
                receiverId: profile.userId,
                reasonForInterest: nil,
                senderProfile: senderProfile
            )
            print("✅ Invitation sent successfully: \(invitation.id)")

            await MainActor.run {
                // 开始平滑过渡
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTransitioning = true
                    nextProfileOffset = 0
                }
                
                // 等待过渡动画完成后再更新数据
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    // 从列表中移除已邀请的 profile
                    // 注意：移除后，后面的元素会自动前移，所以当前索引会指向下一个 profile
                    let removedIndex = profiles.firstIndex { $0.userId == profile.userId }
                    if let index = removedIndex {
                        profiles.remove(at: index)
                        // 如果移除的索引小于等于当前索引，索引会自动指向下一个（因为数组前移）
                        // 如果移除的索引大于当前索引，当前索引不变
                        if index < currentIndex {
                            // 移除的元素在当前索引之前，当前索引需要减1
                            currentIndex -= 1
                        } else if index == currentIndex {
                            // 移除的就是当前索引的元素，索引保持不变（因为后面的元素会前移）
                            // currentIndex 不变，因为它现在指向原来索引 currentIndex+1 的元素
                        }
                        // 如果 index > currentIndex，当前索引不变
                    }
                    
                    cachedProfiles.removeAll { $0.userId == profile.userId }
                    proUsers.remove(profile.userId)
                    verifiedUsers.remove(profile.userId)

                    if !cachedProfiles.isEmpty {
                        saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
                        print("✅ Updated cache after sending invitation (removed \(profile.coreIdentity.name))")
                    } else {
                        if let currentUser = authManager.currentUser {
                            let cacheKey = "matches_cache_\(currentUser.id)"
                            let timeKey = "matches_cache_time_\(currentUser.id)"
                            let sourceKey = "matches_cache_source_\(currentUser.id)"
                            UserDefaults.standard.removeObject(forKey: cacheKey)
                            UserDefaults.standard.removeObject(forKey: timeKey)
                            UserDefaults.standard.removeObject(forKey: sourceKey)
                        }
                        isCacheFromRecommendation = false
                        print("🗑️ Cleared local cache (empty after removing invited user)")
                    }

                    // 如果移除后当前索引超出范围，调整索引
                    if currentIndex >= profiles.count && !profiles.isEmpty {
                        currentIndex = profiles.count - 1
                    } else if profiles.isEmpty {
                        currentIndex = 0
                        if hasMoreProfiles {
                            loadMoreProfiles()
                        }
                    }
                    
                    // 重置动画状态
                    dragOffset = .zero
                    rotationAngle = 0
                    isTransitioning = false
                    nextProfileOffset = 0
                    
                    // 每次移动到下一个时保存索引
                    saveCurrentIndex()
                    
                    print("✅ Liked profile: \(profile.coreIdentity.name), new index: \(currentIndex), profiles count: \(profiles.count)")
                }
            }

            Task {
                do {
                    try await supabaseService.clearRecommendationCache(userId: currentUser.id)
                    print("🗑️ Cleared server-side recommendation cache")
                } catch {
                    print("⚠️ Failed to clear server-side cache: \(error.localizedDescription)")
                }
            }

            let receivedInvitations = try? await supabaseService.getPendingInvitations(userId: currentUser.id)
            let existingInvitationFromThem = receivedInvitations?.first { $0.senderId == profile.userId }

            if let theirInvitation = existingInvitationFromThem {
                print("💚 Mutual invitation detected! Auto-creating match...")
                do {
                    _ = try await supabaseService.acceptInvitation(
                        invitationId: theirInvitation.id,
                        userId: currentUser.id
                    )
                    print("✅ Accepted their invitation - match created via trigger")
                } catch {
                    print("⚠️ Failed to accept their invitation: \(error.localizedDescription)")
                }

                do {
                    _ = try await supabaseService.acceptInvitation(
                        invitationId: invitation.id,
                        userId: currentUser.id
                    )
                    print("✅ Accepted my invitation")
                } catch {
                    print("⚠️ Failed to accept my invitation (match may already exist): \(error.localizedDescription)")
                }

                await recommendationService.recordMatch(
                    userId: currentUser.id,
                    targetUserId: profile.userId
                )

                await MainActor.run {
                    matchedProfile = profile
                    showingMatchAlert = true
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UserMatched"),
                        object: nil,
                        userInfo: ["profile": profile]
                    )
                }
            }

            // 注意：不需要再调用 moveToNextProfile()，因为上面已经处理了过渡和索引更新
            // moveToNextProfile() 会增加索引，但我们已经移除了 profile 并调整了索引

            Task {
                await authManager.refreshUser()
            }
        } catch {
            print("❌ Failed to process like: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to send invitation: \(error.localizedDescription)"
                withAnimation(.spring()) {
                    dragOffset = .zero
                    rotationAngle = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    errorMessage = nil
                }
            }
        }
    }
    
    private func sendInvitationWithoutMessage(profile: BrewNetProfile) async {
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        do {
            await MainActor.run {
                likedProfiles.append(profile)
            }

            await recommendationService.recordLike(
                userId: currentUser.id,
                targetUserId: profile.userId
            )

            var senderProfile: InvitationProfile? = nil
            if let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = currentUserProfile.toBrewNetProfile()
                senderProfile = brewNetProfile.toInvitationProfile()
            }

            let invitation = try await supabaseService.sendInvitation(
                senderId: currentUser.id,
                receiverId: profile.userId,
                reasonForInterest: nil,
                senderProfile: senderProfile
            )
            print("✅ Invitation sent successfully (without message): \(invitation.id)")

            await MainActor.run {
                // 开始平滑过渡
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTransitioning = true
                    nextProfileOffset = 0
                }
                
                // 等待过渡动画完成后再更新数据
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    let removedIndex = profiles.firstIndex { $0.userId == profile.userId }
                    if let index = removedIndex {
                        profiles.remove(at: index)
                        if index < currentIndex {
                            currentIndex -= 1
                        }
                    }
                    
                    cachedProfiles.removeAll { $0.userId == profile.userId }
                    proUsers.remove(profile.userId)
                    verifiedUsers.remove(profile.userId)

                    if !cachedProfiles.isEmpty {
                        saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
                    } else {
                        if let currentUser = authManager.currentUser {
                            let cacheKey = "matches_cache_\(currentUser.id)"
                            let timeKey = "matches_cache_time_\(currentUser.id)"
                            let sourceKey = "matches_cache_source_\(currentUser.id)"
                            UserDefaults.standard.removeObject(forKey: cacheKey)
                            UserDefaults.standard.removeObject(forKey: timeKey)
                            UserDefaults.standard.removeObject(forKey: sourceKey)
                        }
                        isCacheFromRecommendation = false
                    }

                    if currentIndex >= profiles.count && !profiles.isEmpty {
                        currentIndex = profiles.count - 1
                    } else if profiles.isEmpty {
                        currentIndex = 0
                        if hasMoreProfiles {
                            loadMoreProfiles()
                        }
                    }
                    
                    dragOffset = .zero
                    rotationAngle = 0
                    isTransitioning = false
                    nextProfileOffset = 0
                    
                    saveCurrentIndex()
                    profilePendingInvitation = nil
                }
            }

            Task {
                do {
                    try await supabaseService.clearRecommendationCache(userId: currentUser.id)
                } catch {
                    print("⚠️ Failed to clear server-side cache: \(error.localizedDescription)")
                }
            }

            let receivedInvitations = try? await supabaseService.getPendingInvitations(userId: currentUser.id)
            let existingInvitationFromThem = receivedInvitations?.first { $0.senderId == profile.userId }

            if let theirInvitation = existingInvitationFromThem {
                do {
                    _ = try await supabaseService.acceptInvitation(
                        invitationId: theirInvitation.id,
                        userId: currentUser.id
                    )
                    _ = try await supabaseService.acceptInvitation(
                        invitationId: invitation.id,
                        userId: currentUser.id
                    )

                    await recommendationService.recordMatch(
                        userId: currentUser.id,
                        targetUserId: profile.userId
                    )

                    await MainActor.run {
                        matchedProfile = profile
                        showingMatchAlert = true
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UserMatched"),
                            object: nil,
                            userInfo: ["profile": profile]
                        )
                    }
                } catch {
                    print("⚠️ Failed to accept invitations: \(error.localizedDescription)")
                }
            }

            Task {
                await authManager.refreshUser()
            }
        } catch {
            print("❌ Failed to send invitation: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to send invitation: \(error.localizedDescription)"
                profilePendingInvitation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    errorMessage = nil
                }
            }
        }
    }
    
    private func moveToNextProfile() {
        // 在切换前，确保下一个卡片的头像已经预加载完成
        let nextIndex = currentIndex + 1
        if nextIndex < profiles.count {
            if let imageUrl = profiles[nextIndex].coreIdentity.profileImage,
               !imageUrl.isEmpty,
               imageUrl.hasPrefix("http") {
                // 如果缓存中没有，立即开始预加载
                if ImageCacheManager.shared.getCachedImage(from: imageUrl) == nil {
                    Task {
                        // 等待预加载完成（最多等待0.2秒）
                        _ = await ImageCacheManager.shared.loadImage(from: imageUrl)
                    }
                }
            }
        }
        
        // 开始平滑过渡
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isTransitioning = true
            nextProfileOffset = 0
        }
        
        // 等待过渡动画完成后再更新索引
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            currentIndex += 1
            dragOffset = .zero
            rotationAngle = 0
            isTransitioning = false
            nextProfileOffset = 0
            
            // 每次移动到下一个时保存索引
            saveCurrentIndex()
            
            // 预加载下一个卡片的头像（为下次切换做准备）
            preloadProfileImages()
            
            // 如果已经到达最后一个，检查是否需要加载更多
            if currentIndex >= profiles.count {
                print("📄 Reached end of profiles, may need to load more")
            }
        }
    }
    
    private func loadProfiles() {
        errorMessage = nil
        // 不重置索引，保持恢复的索引（如果已恢复）
        // 只有在没有缓存时才重置为0
        if cachedProfiles.isEmpty {
            currentIndex = 0
        }
        
        // 注意：不再从本地缓存加载，因为缓存加载已在 onAppear 中处理
        // 这里直接显示加载状态，然后从推荐系统加载
        isLoading = true
        profiles.removeAll()
        proUsers.removeAll()
        verifiedUsers.removeAll()
        totalFetched = 0
        totalFiltered = 0
        
        Task {
            await loadProfilesBatch(offset: 0, limit: 20, isInitial: true) // 先加载少量数据（20个）快速显示
        }
    }
    
    // 后台静默刷新，不显示加载状态（只使用推荐系统）
    private func refreshProfilesSilently() async {
        guard let currentUser = authManager.currentUser else { return }
        
        isRefreshing = true
        
        do {
            // 只使用推荐系统刷新，确保数据一致性
            // 增加推荐数量，提高过滤后仍有足够用户的概率
            // 静默刷新时也强制刷新，确保获取最新推荐
            let filter = await MainActor.run { currentFilter }
            
            // 获取当前用户的位置信息（用于距离过滤）
            var userLocation: String? = nil
            if let filter = filter, filter.maxDistance != nil {
                // 只有在设置了距离过滤时才获取位置
                if let userProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                    userLocation = userProfile.coreIdentity.location
                }
            }
            
            let recommendations = try await recommendationService.getRecommendations(
                for: currentUser.id,
                limit: 50,  // 从 20 增加到 50，增加成功率
                forceRefresh: true,  // 静默刷新时也强制刷新
                maxDistance: filter?.maxDistance,
                userLocation: userLocation
            )
            
            // 获取需要排除的用户ID集合
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            
            // 确保按照推荐分数排序（从高到低）
            let sortedRecommendations = recommendations.sorted { $0.score > $1.score }
            
            // 过滤掉已交互的用户和无效测试用户
            var validRecommendations = sortedRecommendations.filter { rec in
                !excludedUserIds.contains(rec.userId) &&
                !passedProfiles.contains(where: { $0.userId == rec.userId }) &&
                !likedProfiles.contains(where: { $0.userId == rec.userId }) &&
                isValidProfileName(rec.profile.coreIdentity.name) // 排除无效测试用户
            }
            
            // 应用用户设置的filter（非距离过滤，距离过滤已在推荐系统中处理）
            if let filter = filter {
                validRecommendations = validRecommendations.filter { filter.matches($0.profile) }
            }
            
            let brewNetProfiles = validRecommendations.map { $0.profile }
            
            await MainActor.run {
                // 更新 profiles 和缓存（只保留推荐系统的结果）
                profiles = brewNetProfiles
                cachedProfiles = brewNetProfiles
                lastLoadTime = Date()
                saveCachedProfilesToStorage(isFromRecommendation: true) // 标记为来自推荐系统
                
                // 如果当前索引超出范围，重置
                // 只有在非过渡状态下才调整索引，避免在过渡期间重置索引
                if !isTransitioning && currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = profiles.count - 1
                    print("⚠️ Adjusted index to \(currentIndex) after loading profiles")
                }
                
                print("✅ Silently refreshed recommendations: \(brewNetProfiles.count) profiles (filtered from \(recommendations.count))")
            }
        } catch {
            print("⚠️ Failed to silently refresh profiles: \(error.localizedDescription)")
        }
        
        isRefreshing = false
    }
    
    // 从持久化存储加载缓存
    private func loadCachedProfilesFromStorage() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "matches_cache_\(currentUser.id)"
        let timeKey = "matches_cache_time_\(currentUser.id)"
        let sourceKey = "matches_cache_source_\(currentUser.id)" // 缓存来源标识
        let indexKey = "matches_current_index_\(currentUser.id)" // 当前索引
        
        // 从 UserDefaults 加载缓存
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: timeKey) as? Date,
           Date().timeIntervalSince(timestamp) < 300 { // 5分钟内有效
            
            do {
                let decoder = JSONDecoder()
                let cachedProfilesData = try decoder.decode([BrewNetProfile].self, from: data)
                cachedProfiles = cachedProfilesData
                lastLoadTime = timestamp
                
                // 检查缓存来源（是否来自推荐系统）
                isCacheFromRecommendation = UserDefaults.standard.bool(forKey: sourceKey)
                
                // 恢复上次的索引位置（登录时恢复上次退出时的位置）
                let savedIndex = UserDefaults.standard.integer(forKey: indexKey)
                if savedIndex >= 0 && savedIndex < cachedProfilesData.count {
                    currentIndex = savedIndex
                    print("✅ Restored last index: \(savedIndex) from previous session")
                } else {
                    currentIndex = 0
                }
                
                print("✅ Loaded \(cachedProfiles.count) profiles from persistent cache (from recommendation: \(isCacheFromRecommendation), index: \(currentIndex))")
            } catch {
                print("⚠️ Failed to decode cached profiles: \(error)")
                cachedProfiles = []
                isCacheFromRecommendation = false
                currentIndex = 0
            }
        } else {
            cachedProfiles = []
            isCacheFromRecommendation = false
            currentIndex = 0
        }
    }
    
    // 快速验证和过滤缓存（用于切换 tab 回来时立即过滤）
    private func quickValidateAndFilterCache() async {
        guard let currentUser = authManager.currentUser else { return }
        
        // 保存原始缓存数量（用于日志）
        let originalCount = await MainActor.run { cachedProfiles.count }
        
        // 快速获取已排除的用户ID（包括已 pass 的用户）
        do {
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            
            // 立即过滤掉已排除的用户
            let filteredProfiles = await MainActor.run {
                cachedProfiles.filter { profile in
                    !excludedUserIds.contains(profile.userId) &&
                    isValidProfileName(profile.coreIdentity.name)
                }
            }
            
            await MainActor.run {
                // 如果过滤后还有数据，立即更新显示
                if !filteredProfiles.isEmpty {
                    let previousIndex = currentIndex
                    let previousProfileId = currentIndex < profiles.count ? profiles[currentIndex].userId : nil
                    
                    profiles = filteredProfiles
                    cachedProfiles = filteredProfiles
                    
                    // 尝试保持当前索引（如果对应的profile仍然有效）
                    if let previousId = previousProfileId, let newIndex = filteredProfiles.firstIndex(where: { $0.userId == previousId }) {
                        currentIndex = newIndex
                    } else if previousIndex < filteredProfiles.count {
                        currentIndex = previousIndex
                    } else {
                        currentIndex = 0
                    }
                    
                    // 如果当前显示的用户在排除列表中，切换到下一个有效的
                    if currentIndex < profiles.count {
                        let currentProfile = profiles[currentIndex]
                        if excludedUserIds.contains(currentProfile.userId) {
                            if let nextValidIndex = filteredProfiles.firstIndex(where: { !excludedUserIds.contains($0.userId) }) {
                                currentIndex = nextValidIndex
                            } else {
                                currentIndex = 0
                            }
                        }
                    }
                    
                    // 保存过滤后的缓存到持久化存储，确保已排除的用户不会再次出现
                    saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
                    
                    print("⚡ Quick filtered cache: \(filteredProfiles.count)/\(originalCount) profiles remain, showing at index \(currentIndex)")
                } else {
                    // 如果过滤后没有数据，清空 profiles 和 cachedProfiles，然后重新加载
                    profiles = []
                    cachedProfiles = []
                    currentIndex = 0
                    // 清除持久化缓存，确保下次加载时不会再次出现已排除的用户
                    clearInvalidCache()
                    print("⚠️ Quick filter removed all profiles (from \(originalCount)), reloading...")
                    
                    // 立即重新加载，避免显示"No More Profiles"
                    loadProfiles()
                }
            }
        } catch {
            print("⚠️ Failed to quick validate cache: \(error.localizedDescription)")
            // 失败时，如果有缓存数据，先显示缓存（稍后完整验证会修正）
            // 如果失败且没有缓存，等待完整验证或重新加载
            await MainActor.run {
                if cachedProfiles.isEmpty {
                    profiles = []
                }
            }
        }
    }
    
    // 验证并显示缓存（过滤掉已交互的用户）
    private func validateAndDisplayCache() async {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                isLoading = false
                loadProfiles()
            }
            return
        }
        
        // 获取需要排除的用户ID集合
        do {
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            print("🔍 Validating cache: excluding \(excludedUserIds.count) users")
            
            // 获取已匹配的用户（额外防御）
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
                print("⚠️ Failed to fetch matches for validation: \(error.localizedDescription)")
            }
            
            // 合并所有需要排除的用户ID
            let allExcludedUserIds = excludedUserIds.union(matchedUserIds)
            
            // 过滤掉已交互的用户（多重检查）和无效测试用户
            let validProfiles = cachedProfiles.filter { profile in
                !allExcludedUserIds.contains(profile.userId) &&
                !passedProfiles.contains(where: { $0.userId == profile.userId }) &&
                !likedProfiles.contains(where: { $0.userId == profile.userId }) &&
                isValidProfileName(profile.coreIdentity.name) // 排除无效测试用户
            }
            
            print("✅ Cache validation: \(validProfiles.count)/\(cachedProfiles.count) profiles remain valid")
            print("   - Excluded by getExcludedUserIds: \(excludedUserIds.count)")
            print("   - Excluded by matches: \(matchedUserIds.count)")
            print("   - Total excluded: \(allExcludedUserIds.count)")
            
            await MainActor.run {
                if validProfiles.count >= 3 {
                    // 如果还有足够多的有效用户，更新缓存
                    let previousIndex = currentIndex
                    let previousProfileId = currentIndex < profiles.count ? profiles[currentIndex].userId : nil
                    
                    profiles = validProfiles
                    cachedProfiles = validProfiles
                    isLoading = false
                    
                    // 尝试保持当前索引（如果对应的profile仍然有效）
                    if let previousId = previousProfileId, let newIndex = validProfiles.firstIndex(where: { $0.userId == previousId }) {
                        currentIndex = newIndex
                        print("✅ Validated cache: \(validProfiles.count) profiles, kept profile at index \(newIndex)")
                    } else if previousIndex < validProfiles.count {
                        // 如果之前的索引仍然有效，保持它
                        currentIndex = previousIndex
                        print("✅ Validated cache: \(validProfiles.count) profiles, kept index \(previousIndex)")
                    } else {
                        // 否则使用保存的索引或0
                        currentIndex = restoreCurrentIndex()
                        if currentIndex >= validProfiles.count {
                            currentIndex = 0
                        }
                        print("✅ Validated cache: \(validProfiles.count) profiles, restored to index \(currentIndex)")
                    }
                    
                    // 保存当前状态
                    saveCachedProfilesToStorage(isFromRecommendation: true)
                    
                    // 实时检查：如果当前显示的用户在排除列表中，切换到下一个有效的
                    if !profiles.isEmpty && currentIndex < profiles.count {
                        let currentProfile = profiles[currentIndex]
                        if allExcludedUserIds.contains(currentProfile.userId) {
                            print("⚠️ Current profile is excluded, switching to next valid...")
                            // 找到下一个有效的profile
                            if let nextValidIndex = validProfiles.firstIndex(where: { !allExcludedUserIds.contains($0.userId) }) {
                                currentIndex = nextValidIndex
                                print("✅ Switched to valid profile at index \(nextValidIndex)")
                            } else {
                                // 如果没有有效的profile，重新加载
                                print("⚠️ No valid profiles found, reloading...")
                                clearInvalidCache()
                                loadProfiles()
                                return
                            }
                        }
                    }
                } else {
                    // 如果有效用户太少，清除缓存并重新加载
                    print("⚠️ Too few valid profiles in cache (\(validProfiles.count)), clearing and reloading")
                    clearInvalidCache()
                    loadProfiles()
                    return
                }
            }
            
            // 后台静默刷新（使用推荐系统，确保数据一致）
            await refreshProfilesSilently()
        } catch {
            print("⚠️ Failed to validate cache: \(error.localizedDescription)")
            // 验证失败，清除缓存并重新加载
            await MainActor.run {
                clearInvalidCache()
                loadProfiles()
            }
        }
    }
    
    // 清除无效缓存
    private func clearInvalidCache() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "matches_cache_\(currentUser.id)"
        let timeKey = "matches_cache_time_\(currentUser.id)"
        let sourceKey = "matches_cache_source_\(currentUser.id)"
        let indexKey = "matches_current_index_\(currentUser.id)"
        
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: timeKey)
        UserDefaults.standard.removeObject(forKey: sourceKey)
        UserDefaults.standard.removeObject(forKey: indexKey) // 清除索引
        
        cachedProfiles = []
        profiles = []
        isCacheFromRecommendation = false
        lastLoadTime = nil
        savedFirstProfile = nil
        currentIndex = 0
        
        print("🗑️ Cleared invalid cache")
    }
    
    // 保存缓存到持久化存储
    private func saveCachedProfilesToStorage(isFromRecommendation: Bool = false) {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "matches_cache_\(currentUser.id)"
        let timeKey = "matches_cache_time_\(currentUser.id)"
        let sourceKey = "matches_cache_source_\(currentUser.id)"
        let indexKey = "matches_current_index_\(currentUser.id)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cachedProfiles)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            UserDefaults.standard.set(isFromRecommendation, forKey: sourceKey)
            UserDefaults.standard.set(currentIndex, forKey: indexKey) // 保存当前索引
            isCacheFromRecommendation = isFromRecommendation
            print("✅ Saved \(cachedProfiles.count) profiles to persistent cache (from recommendation: \(isFromRecommendation), index: \(currentIndex))")
        } catch {
            print("⚠️ Failed to save cached profiles: \(error)")
        }
    }
    
    // 保存当前索引（用于切换tab时恢复）
    private func saveCurrentIndex() {
        guard let currentUser = authManager.currentUser else { return }
        let indexKey = "matches_current_index_\(currentUser.id)"
        UserDefaults.standard.set(currentIndex, forKey: indexKey)
        print("💾 Saved current index: \(currentIndex) for tab switch")
    }
    
    // 恢复当前索引（用于切换tab回来时恢复）
    private func restoreCurrentIndex() -> Int {
        guard let currentUser = authManager.currentUser else { return 0 }
        let indexKey = "matches_current_index_\(currentUser.id)"
        let savedIndex = UserDefaults.standard.integer(forKey: indexKey)
        if savedIndex >= 0 && savedIndex < profiles.count {
            print("📌 Restored index from tab switch: \(savedIndex)")
            return savedIndex
        }
        return 0
    }
    
    private func loadMoreProfiles() {
        guard !isLoadingMore && hasMoreProfiles else { return }
        
        isLoadingMore = true
        
        Task {
            await loadProfilesBatch(offset: profiles.count, limit: 200, isInitial: false)
        }
    }
    
    private func loadProfilesBatch(offset: Int, limit: Int, isInitial: Bool) async {
        do {
            // Get current user ID
            guard let currentUser = authManager.currentUser else {
                await MainActor.run {
                    errorMessage = "Please log in to view profiles"
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }
            
            // 获取已匹配的用户ID集合（防御性过滤，确保已匹配用户不会出现）
            var excludedMatchedUserIds: Set<String> = []
            do {
                let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                for match in matches {
                    if match.userId == currentUser.id {
                        excludedMatchedUserIds.insert(match.matchedUserId)
                    } else if match.matchedUserId == currentUser.id {
                        excludedMatchedUserIds.insert(match.userId)
                    }
                }
                if !excludedMatchedUserIds.isEmpty {
                    print("🔍 BrewNetMatchesView: Excluding \(excludedMatchedUserIds.count) matched users (defensive filtering)")
                }
            } catch {
                print("⚠️ Failed to fetch matches for defensive filtering: \(error.localizedDescription)")
            }
            
            // 获取已pass的用户ID集合（用于过滤）
            let passedUserIds = Set(passedProfiles.map { $0.userId })
            let likedUserIds = Set(likedProfiles.map { $0.userId })
            
            // Load actual profiles from Supabase with offset and limit
            // ========== Two-Tower 推荐模式 ==========
            if offset == 0 && isInitial {
                // 使用 Two-Tower 推荐引擎
                print("🚀 Using Two-Tower recommendation engine")
                // 增加推荐数量，提高过滤后仍有足够用户的概率
                // 如果 shouldForceRefresh 为 true，强制刷新忽略缓存
                let forceRefresh = await MainActor.run { shouldForceRefresh }
                let filter = await MainActor.run { currentFilter }
                
                // 获取当前用户的位置信息（用于距离过滤）
                var userLocation: String? = nil
                if let filter = filter, filter.maxDistance != nil {
                    // 只有在设置了距离过滤时才获取位置
                    if let userProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                        userLocation = userProfile.coreIdentity.location
                    }
                }
                
                let recommendations = try await recommendationService.getRecommendations(
                    for: currentUser.id,
                    limit: 50,  // 从 20 增加到 50，增加成功率
                    forceRefresh: forceRefresh,
                    maxDistance: filter?.maxDistance,
                    userLocation: userLocation
                )
                
                // 重置强制刷新标志
                await MainActor.run {
                    shouldForceRefresh = false
                }
                
                // 确保按照推荐分数排序（从高到低）
                let sortedRecommendations = recommendations.sorted { $0.score > $1.score }
                
                let brewNetProfiles = sortedRecommendations.map { $0.profile }
                
                // 注意：推荐系统在计算时已经过滤了排除用户，这里只做防御性验证
                // 获取需要排除的用户ID集合（在显示前进行最终验证）
                let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
                print("🔍 Final validation: excluding \(excludedUserIds.count) users (recommendation system already filtered)")
                print("📊 Recommendations received: \(brewNetProfiles.count) profiles")
                
                // 诊断：分析为什么用户被排除
                var excludedByReason: [String: Int] = [:]
                var invalidNames: [String] = []
                
                for profile in brewNetProfiles {
                    if excludedUserIds.contains(profile.userId) {
                        excludedByReason["excludedUserIds", default: 0] += 1
                    }
                    if !isValidProfileName(profile.coreIdentity.name) {
                        invalidNames.append(profile.coreIdentity.name)
                        excludedByReason["invalidName", default: 0] += 1
                    }
                }
                
                print("🔍 Exclusion analysis:")
                print("   - Excluded by excludedUserIds: \(excludedByReason["excludedUserIds", default: 0])")
                print("   - Excluded by invalid name: \(excludedByReason["invalidName", default: 0])")
                if !invalidNames.isEmpty {
                    print("   - Invalid names: \(invalidNames.prefix(5).joined(separator: ", "))")
                }
                
                // 最终过滤：确保不包含任何已交互的用户和无效测试用户
                var finalValidProfiles = brewNetProfiles.filter { profile in
                    !excludedUserIds.contains(profile.userId) &&
                    isValidProfileName(profile.coreIdentity.name)
                }
                
                // 应用用户设置的filter（非距离过滤，距离过滤已在推荐系统中处理）
                if let filter = filter {
                    finalValidProfiles = finalValidProfiles.filter { filter.matches($0) }
                    print("📊 Applied filter: \(finalValidProfiles.count) profiles remain (from \(brewNetProfiles.count))")
                }
                
                print("📊 Filtered results: \(finalValidProfiles.count) valid profiles from \(brewNetProfiles.count) recommendations (excluded: \(brewNetProfiles.count - finalValidProfiles.count))")
                
                await MainActor.run {
                    if finalValidProfiles.isEmpty {
                        // 如果过滤后没有有效用户，显示详细诊断信息
                        print("⚠️ No valid profiles after filtering all recommendations")
                        print("   - Total recommendations received: \(brewNetProfiles.count)")
                        print("   - Total excluded users: \(excludedUserIds.count)")
                        print("   - Excluded by excludedUserIds: \(excludedByReason["excludedUserIds", default: 0])")
                        print("   - Excluded by invalid name: \(excludedByReason["invalidName", default: 0])")
                        print("   - This may indicate:")
                        print("     1. All recommended users have been interacted with")
                        print("     2. All recommended users have invalid names")
                        print("     3. Database may need more users")
                        
                        profiles = []
                        cachedProfiles = []
                        isLoading = false
                        hasMoreProfiles = false
                        // 不保存空缓存
                    } else {
                    // 确保按照推荐分数排序显示（只显示最终验证后的结果）
                    profiles = finalValidProfiles
                    cachedProfiles = finalValidProfiles
                    lastLoadTime = Date()
                    isLoading = false
                    saveCachedProfilesToStorage(isFromRecommendation: true) // 标记为来自推荐系统
                    hasMoreProfiles = false // Two-Tower 返回固定数量
                    
                    // 尝试保持当前索引（如果有效），否则使用保存的索引
                    let savedIndex = restoreCurrentIndex()
                    if savedIndex < finalValidProfiles.count {
                        currentIndex = savedIndex
                        print("📌 Restored index from previous session: \(savedIndex)")
                    } else {
                        currentIndex = 0
                    }
                    
                    // 保存当前状态
                    saveCachedProfilesToStorage(isFromRecommendation: true)
                    
                    print("✅ Two-Tower recommendations loaded: \(finalValidProfiles.count) profiles (filtered from \(brewNetProfiles.count))")
                    print("📊 Top 5 Scores: \(sortedRecommendations.prefix(5).map { String(format: "%.3f", $0.score) }.joined(separator: ", "))")
                    if let firstProfile = finalValidProfiles.first {
                        print("📊 First profile: \(firstProfile.coreIdentity.name) (score: \(sortedRecommendations.first?.score ?? 0.0))")
                        }
                    }
                }
                return
            }
            
            // ========== 传统模式（分页加载更多）==========
            // 注意：传统模式不应该被调用，因为我们已经使用推荐系统
            // 如果到达这里，说明有错误，应该清除缓存并重新使用推荐系统
            print("⚠️ Traditional pagination mode should not be called when using recommendation system")
            print("📄 Falling back to traditional pagination mode (this should be rare)")
            
            let (supabaseProfiles, totalInBatch, filteredCount) = try await supabaseService.getRecommendedProfiles(
                userId: currentUser.id,
                limit: limit,
                offset: offset
            )
            
            // Convert SupabaseProfile to BrewNetProfile
            let brewNetProfiles = supabaseProfiles.map { $0.toBrewNetProfile() }
            
            // 获取完整的排除列表（包括所有交互）
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            
            // 过滤掉已pass、已like和已匹配的用户（避免重复显示），同时排除无效测试用户
            var filteredProfiles = brewNetProfiles.filter { profile in
                !excludedUserIds.contains(profile.userId) &&
                !passedUserIds.contains(profile.userId) && 
                !likedUserIds.contains(profile.userId) &&
                !excludedMatchedUserIds.contains(profile.userId) && // 防御性过滤已匹配用户
                isValidProfileName(profile.coreIdentity.name) // 排除无效测试用户
            }
            
            // 应用用户设置的filter
            let filter = await MainActor.run { currentFilter }
            if let filter = filter {
                filteredProfiles = filteredProfiles.filter { filter.matches($0) }
            }
            
            let localFilteredCount = brewNetProfiles.count - filteredProfiles.count
            if localFilteredCount > 0 {
                print("🔍 Filtered out \(localFilteredCount) profiles that were already interacted with")
            }
            
            await MainActor.run {
                if isInitial {
                    profiles = filteredProfiles
                    // 注意：传统模式不更新缓存，只使用推荐系统的缓存
                    // 不清除缓存，但也不保存传统模式的结果
                    isLoading = false
                    print("✅ Initially loaded \(filteredProfiles.count) profiles from Supabase (traditional mode, not cached)")
                } else {
                    // 追加时也要过滤重复的
                    let existingUserIds = Set(profiles.map { $0.userId })
                    let newProfiles = filteredProfiles.filter { profile in
                        !existingUserIds.contains(profile.userId)
                    }
                    profiles.append(contentsOf: newProfiles)
                    // 注意：传统模式追加时不更新缓存
                    isLoadingMore = false
                    print("✅ Loaded \(newProfiles.count) more profiles (traditional mode, not cached)")
                }
                
                totalFetched += totalInBatch
                totalFiltered += filteredCount + localFilteredCount
                
                // 如果返回的数量少于请求的数量，说明没有更多了
                if supabaseProfiles.count < limit {
                    hasMoreProfiles = false
                    print("ℹ️ No more profiles available. Total loaded: \(profiles.count), Filtered: \(totalFiltered)")
                } else {
                    hasMoreProfiles = true
                }
                
                // 如果当前没有卡片显示，确保从第一条开始
                // 只有在非过渡状态下才调整索引，避免在过渡期间重置索引
                if !isTransitioning && currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = profiles.count - 1
                    print("⚠️ Adjusted index to \(currentIndex) after loading profiles")
                }
            }
            
            // Load Pro and verification status from Supabase for all loaded profiles
            await loadProStatusForProfiles()
            await loadVerifiedStatusForProfiles()
            
        } catch {
            print("❌ Failed to load profiles: \(error.localizedDescription)")
            print("🔍 Error type: \(type(of: error))")
            
            // 检查是否是 noCandidates 错误（通过错误描述判断）
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("no candidates") || 
               errorString.contains("没有候选用户") ||
               errorString.contains("no valid profiles") {
                print("⚠️ No candidates available - all users have been interacted with or database is empty")
                await MainActor.run {
                    if isInitial {
                        profiles = []
                        cachedProfiles = []
                        isLoading = false
                        hasMoreProfiles = false
                        errorMessage = nil  // 不显示错误，显示"No More Profiles"
                    } else {
                        isLoadingMore = false
                        hasMoreProfiles = false
                    }
                }
                return
            }
            
            // 检查是否是数据解码错误
            if let decodingError = error as? DecodingError {
                print("🔍 DecodingError detected:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - Missing key: \(key.stringValue)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("   - Missing value of type: \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: expected \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("   - Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
            
            await MainActor.run {
                if isInitial {
                    // 更详细的错误提示，帮助诊断问题
                    if let decodingError = error as? DecodingError {
                        var detailMessage = "Data format issue: "
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            detailMessage += "Missing '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                        case .valueNotFound(let type, let context):
                            detailMessage += "Missing value of type \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                        case .typeMismatch(let type, let context):
                            detailMessage += "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                        case .dataCorrupted(let context):
                            detailMessage += "Corrupted data at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
                        @unknown default:
                            detailMessage += "Unknown decoding error"
                        }
                        print("🔍 详细错误: \(detailMessage)")
                        errorMessage = "Profile data error. Please check console for details."
                    } else if errorString.contains("couldn't be read") || errorString.contains("missing") {
                        errorMessage = "Some profile data is incomplete. Please refresh to try again."
                    } else {
                        errorMessage = "Failed to load profiles: \(error.localizedDescription)"
                    }
                    isLoading = false
                } else {
                    isLoadingMore = false
                }
            }
        }
    }
    
    // MARK: - Preload Profile Images
    private func preloadProfileImages() {
        guard !profiles.isEmpty else { return }
        
        var imageUrls: [String] = []
        
        // 预加载当前卡片和接下来3个卡片的头像（增加预加载数量）
        let startIndex = currentIndex
        let endIndex = min(currentIndex + 4, profiles.count)
        
        for i in startIndex..<endIndex {
            if let imageUrl = profiles[i].coreIdentity.profileImage,
               !imageUrl.isEmpty,
               imageUrl.hasPrefix("http") {
                imageUrls.append(imageUrl)
            }
        }
        
        // 批量预加载
        if !imageUrls.isEmpty {
            ImageCacheManager.shared.preloadImages(from: imageUrls)
        }
    }
    
    // MARK: - Preload Current User Pro Status
    private func preloadCurrentUserProStatus() {
        guard let currentUser = authManager.currentUser else { return }
        guard currentUserIsPro == nil else { return } // 如果已经加载过，不再重复加载
        
        Task {
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                await MainActor.run {
                    currentUserIsPro = canChat
                    print("✅ [临时聊天] 预加载 Pro 状态: \(canChat ? "Pro用户" : "普通用户")")
                }
            } catch {
                print("⚠️ [临时聊天] 预加载 Pro 状态失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load Pro Status from Users Table
    private func loadProStatusForProfiles() async {
        guard !profiles.isEmpty else { return }
        
        let userIds = profiles.map { $0.userId }
        print("🔍 [Pro] Loading Pro status from users table for \(userIds.count) profiles...")
        
        do {
            // Batch fetch Pro status from users table
            let proUserIds = try await supabaseService.getProUserIds(from: userIds)
            
            await MainActor.run {
                self.proUsers = proUserIds
                print("✅ [Pro] Loaded Pro status: \(proUserIds.count) Pro users among \(userIds.count) profiles")
            }
        } catch {
            print("⚠️ [Pro] Failed to load Pro status: \(error.localizedDescription)")
            // Don't fail the whole load if Pro status fails
        }
    }
    
    private func loadVerifiedStatusForProfiles() async {
        guard !profiles.isEmpty else { return }
        
        let userIds = profiles.map { $0.userId }
        print("🔍 [Verify] Loading verification status for \(userIds.count) profiles...")
        
        do {
            let verifiedIds = try await supabaseService.getVerifiedUserIds(from: userIds)
            await MainActor.run {
                self.verifiedUsers = verifiedIds
                print("✅ [Verify] Loaded verification status: \(verifiedIds.count) verified users")
            }
        } catch {
            print("⚠️ [Verify] Failed to load verification status: \(error.localizedDescription)")
        }
    }
    
    private func refreshProfiles() {
        print("🔄 Refreshing profiles - clearing all caches...")
        
        // 清除所有缓存，强制重新生成推荐
        guard let currentUser = authManager.currentUser else { return }
        
        // 1. 清除客户端持久化缓存
        clearInvalidCache()
        
        // 2. 重置状态
        currentIndex = 0
        hasMoreProfiles = true
        likedProfiles.removeAll()
        passedProfiles.removeAll()
        profiles.removeAll()
        proUsers.removeAll()
        verifiedUsers.removeAll()
        cachedProfiles.removeAll()
        isCacheFromRecommendation = false
        lastLoadTime = nil
        isLoading = true
        
        // 3. 设置强制刷新标志并清除服务器端推荐缓存
        shouldForceRefresh = true
        
        Task {
            do {
                // 先清除服务器端缓存
                try await supabaseService.clearRecommendationCache(userId: currentUser.id)
                print("✅ Cleared server-side recommendation cache")
                
                // 清除完成后，重新加载（会使用 forceRefresh）
                await MainActor.run {
        loadProfiles()
                }
            } catch {
                print("⚠️ Failed to clear server-side cache: \(error.localizedDescription)")
                // 即使清除失败，也尝试重新加载（使用 forceRefresh）
                await MainActor.run {
                    loadProfiles()
                }
            }
        }
    }
    
    // MARK: - Sample Data
    private func createSampleBrewNetProfiles() -> [BrewNetProfile] {
        let now = ISO8601DateFormatter().string(from: Date())
        
        // Sample Profile 1 - Full profile
        let profile1 = BrewNetProfile(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: "Sarah Chen",
                email: "sarah@example.com",
                phoneNumber: nil,
                profileImage: nil,
                bio: "Passionate Product Manager bridging design and data",
                pronouns: "She/Her",
                location: "San Francisco, CA",
                personalWebsite: "https://sarahchen.com",
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: "America/Los_Angeles"
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: "Google",
                jobTitle: "Product Designer",
                industry: "Technology (Software, Data, AI, IT)",
                experienceLevel: .senior,
                education: "Stanford University · M.S. in Human-Computer Interaction",
                educations: nil,
                yearsOfExperience: 8.5,
                careerStage: .manager,
                skills: ["Product Strategy", "User Research", "UX Design", "Data Analysis", "Agile"],
                certifications: [],
                languagesSpoken: ["English", "Mandarin"],
                workExperiences: [
                    WorkExperience(
                        companyName: "Google",
                        startYear: 2021,
                        startMonth: nil,
                        endYear: nil,
                        endMonth: nil,
                        position: "Senior Product Designer"
                    ),
                    WorkExperience(
                        companyName: "Adobe",
                        startYear: 2020,
                        startMonth: nil,
                        endYear: 2021,
                        endMonth: nil,
                        position: "Product Designer"
                    ),
                    WorkExperience(
                        companyName: "StartupCo",
                        startYear: 2018,
                        startMonth: nil,
                        endYear: 2020,
                        endMonth: nil,
                        position: "UX Designer"
                    )
                ]
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .learnGrow,
                selectedSubIntentions: [.careerDirection, .skillDevelopment],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .virtual,
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    monday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    tuesday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                ),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: ["Curious", "Empathetic", "Collaborative"],
                hobbies: ["Coffee Culture", "Photography", "Hiking"],
                preferredMeetingVibe: .reflective,
                preferredMeetingVibes: [.reflective],
                selfIntroduction: "I love bridging design and data to solve real-world problems. When I'm not designing products, you'll find me exploring coffee shops or capturing moments with my camera."
            ),
            workPhotos: nil,
            lifestylePhotos: nil,
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .verifiedProfessional,
                dataSharingConsent: true,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
        
        // Sample Profile 2 - Minimal profile
        let profile2 = BrewNetProfile(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: "Mike Rodriguez",
                email: "mike@example.com",
                phoneNumber: nil,
                profileImage: nil,
                bio: "Full-stack developer building the future",
                pronouns: "He/Him",
                location: "New York, NY",
                personalWebsite: nil,
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: "America/New_York"
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: "StartupXYZ",
                jobTitle: "Software Engineer",
                industry: "Technology (Software, Data, AI, IT)",
                experienceLevel: .mid,
                education: "MIT · B.S. in Computer Science",
                educations: nil,
                yearsOfExperience: 5.0,
                careerStage: .midLevel,
                skills: ["iOS Development", "Swift", "React Native", "Backend"],
                certifications: [],
                languagesSpoken: ["English", "Spanish"],
                workExperiences: [
                    WorkExperience(
                        companyName: "StartupXYZ",
                        startYear: 2020,
                        startMonth: nil,
                        endYear: nil,
                        endMonth: nil,
                        position: "Software Engineer"
                    ),
                    WorkExperience(
                        companyName: "TechCorp",
                        startYear: 2019,
                        startMonth: nil,
                        endYear: 2020,
                        endMonth: nil,
                        position: "Junior Developer"
                    )
                ]
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .learnGrow,
                selectedSubIntentions: [.careerDirection, .skillDevelopment],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .either,
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    monday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    tuesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                ),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: ["Innovative", "Passionate"],
                hobbies: ["Guitar", "Coding Side Projects"],
                preferredMeetingVibe: .casual,
                preferredMeetingVibes: [.casual],
                selfIntroduction: "Passionate about mobile apps and building great user experiences."
            ),
            workPhotos: nil,
            lifestylePhotos: nil,
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .verifiedProfessional,
                dataSharingConsent: true,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
        
        return [profile1, profile2]
    }
    
    // MARK: - Filter Methods
    private func loadSavedFilter() {
        guard let userId = authManager.currentUser?.id else { return }
        if let data = UserDefaults.standard.data(forKey: "match_filter_\(userId)"),
           let savedFilter = try? JSONDecoder().decode(MatchFilter.self, from: data) {
            currentFilter = savedFilter
            print("✅ Loaded saved filter")
        }
    }
    
    private func applyFilter(_ filter: MatchFilter) {
        currentFilter = filter
        print("🔍 Applying filter: \(filter.hasActiveFilters() ? "Active" : "None")")
        
        // 重新过滤当前profiles（包括距离过滤）
        if let filter = currentFilter {
            // 保存当前profiles的副本，避免在异步操作中访问可变状态
            let currentProfiles = profiles
            
            Task {
                // 如果有距离限制，需要异步计算距离
                var filteredProfiles: [BrewNetProfile]
                
                do {
                    if let maxDistance = filter.maxDistance {
                        // 需要计算距离，异步处理
                        filteredProfiles = await filterProfilesWithDistance(
                            profiles: currentProfiles,
                            filter: filter,
                            maxDistance: maxDistance
                        )
                    } else {
                        // 不需要距离计算，直接过滤
                        filteredProfiles = currentProfiles.filter { filter.matches($0) }
                    }
                    
                    let filteredCount = currentProfiles.count - filteredProfiles.count
                    
                    await MainActor.run {
                        profiles = filteredProfiles
                        cachedProfiles = cachedProfiles.filter { filter.matches($0) }
                        
                        // 调整索引
                        if currentIndex >= profiles.count && !profiles.isEmpty {
                            currentIndex = 0
                        } else if profiles.isEmpty {
                            currentIndex = 0
                            // 如果没有匹配的profiles，尝试加载更多
                            if hasMoreProfiles {
                                loadMoreProfiles()
                            }
                        }
                        
                        print("✅ Applied filter: \(filteredCount) profiles filtered out, \(profiles.count) remain")
                        saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
                    }
                } catch {
                    print("❌ Error applying filter: \(error.localizedDescription)")
                    // 出错时至少应用基本过滤
                    await MainActor.run {
                        let basicFiltered = currentProfiles.filter { filter.matches($0) }
                        profiles = basicFiltered
                        print("⚠️ Applied basic filter only due to error")
                    }
                }
            }
        }
    }
    
    // 异步过滤profiles，包括距离计算
    private func filterProfilesWithDistance(
        profiles: [BrewNetProfile],
        filter: MatchFilter,
        maxDistance: Double
    ) async -> [BrewNetProfile] {
        guard let currentUser = authManager.currentUser else {
            return profiles.filter { filter.matches($0) }
        }
        
        // 先进行基本过滤
        let basicFilteredProfiles = profiles.filter { filter.matches($0) }
        
        // 如果没有设置距离限制或没有profiles，直接返回
        guard !basicFilteredProfiles.isEmpty else {
            return []
        }
        
        // 获取当前用户的位置
        var currentUserLocation: CLLocation? = nil
        do {
            if let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = currentUserProfile.toBrewNetProfile()
                if let userLocationString = brewNetProfile.coreIdentity.location, !userLocationString.isEmpty {
                    // 使用LocationService获取当前用户位置的坐标
                    let locationService = LocationService.shared
                    currentUserLocation = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
                        let queue = DispatchQueue(label: "com.brewnet.geocode.queue")
                        var hasResumed = false
                        
                        let timeoutTask = Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                            queue.sync {
                                if !hasResumed {
                                    hasResumed = true
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                        
                        locationService.geocodeAddress(userLocationString) { location in
                            queue.sync {
                                if !hasResumed {
                                    hasResumed = true
                                    timeoutTask.cancel()
                                    continuation.resume(returning: location)
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            print("⚠️ Failed to get current user profile: \(error.localizedDescription)")
        }
        
        // 如果无法获取当前用户位置，无法进行距离过滤，返回基本过滤结果
        guard let userLocation = currentUserLocation else {
            print("⚠️ Cannot get current user location, skipping distance filter")
            return basicFilteredProfiles
        }
        
        var filteredProfiles: [BrewNetProfile] = []
        let locationService = LocationService.shared
        
        // 并行处理所有profiles的距离计算（限制并发数量避免过多请求）
        await withTaskGroup(of: (BrewNetProfile, Double?).self) { group in
            for profile in basicFilteredProfiles {
                group.addTask {
                    // 计算距离
                    guard let profileLocationString = profile.coreIdentity.location,
                          !profileLocationString.isEmpty else {
                        // 如果没有位置信息，保留（或者可以根据需求过滤掉）
                        return (profile, nil)
                    }
                    
                    let profileLocation = await withCheckedContinuation { (continuation: CheckedContinuation<CLLocation?, Never>) in
                        let queue = DispatchQueue(label: "com.brewnet.geocode.queue.\(UUID().uuidString)")
                        var hasResumed = false
                        
                        let timeoutTask = Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                            queue.sync {
                                if !hasResumed {
                                    hasResumed = true
                                    continuation.resume(returning: nil)
                                }
                            }
                        }
                        
                        locationService.geocodeAddress(profileLocationString) { location in
                            queue.sync {
                                if !hasResumed {
                                    hasResumed = true
                                    timeoutTask.cancel()
                                    continuation.resume(returning: location)
                                }
                            }
                        }
                    }
                    
                    guard let location = profileLocation else {
                        return (profile, nil)
                    }
                    
                    let distance = locationService.calculateDistance(from: userLocation, to: location)
                    return (profile, distance)
                }
            }
            
            // 收集结果并过滤
            for await (profile, distance) in group {
                if let distance = distance {
                    // 有距离信息，检查是否在范围内
                    if distance <= maxDistance {
                        filteredProfiles.append(profile)
                    }
                } else {
                    // 没有距离信息，保留（或者可以根据需求过滤掉）
                    filteredProfiles.append(profile)
                }
            }
        }
        
        return filteredProfiles
    }
    
    // MARK: - Helper Methods
    /// 验证 profile 名称是否有效（排除测试用户）
    private func isValidProfileName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 排除无效或测试用户名
        let invalidNames: Set<String> = ["123", "test", "Test", "TEST", "测试", "demo", "Demo", "DEMO"]
        
        // 排除空字符串或过短的名字
        if trimmedName.isEmpty || trimmedName.count < 2 {
            return false
        }
        
        // 排除已知的测试用户名
        if invalidNames.contains(trimmedName) {
            print("⚠️ Filtered out invalid test user: \(trimmedName)")
            return false
        }
        
        // 排除只包含数字的名字（如 "123", "456" 等）
        if trimmedName.allSatisfy({ $0.isNumber }) {
            print("⚠️ Filtered out numeric-only username: \(trimmedName)")
            return false
        }
        
        return true
    }
    
    // MARK: - Add Message Prompt View
    private var addMessagePromptView: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss when tapping outside
                }
            
            // Alert dialog
            VStack(spacing: 20) {
                // Title
                Text("Add a message?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                
                // Message
                Text("Personalize your request by adding a message. People are more likely to accept requests that include a message.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                // Buttons
                VStack(spacing: 12) {
                    // Add a Message button
                    Button(action: {
                        showAddMessagePrompt = false
                        if let profile = profilePendingInvitation {
                            checkProStatusAndOpenChat(profile: profile)
                        }
                    }) {
                        Text("Add a Message")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .cornerRadius(25)
                    }
                    
                    // Send Anyway button
                    Button(action: {
                        showAddMessagePrompt = false
                        if let profile = profilePendingInvitation {
                            Task {
                                await sendInvitationWithoutMessage(profile: profile)
                            }
                        }
                    }) {
                        Text("Send Anyway")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.1), lineWidth: 1.5)
                            )
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Group Meet View
struct GroupMeetView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    .padding(.top, 40)
                
                Text("Group Meet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("Join or create group networking events")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
        }
    }
}

// MARK: - Match Filter Model
struct MatchFilter: Codable, Equatable {
    // 单选字段（唯一选项）
    var experienceLevel: ExperienceLevel?
    var careerStage: CareerStage?
    var preferredChatFormat: ChatFormat?
    var verifiedStatus: VerifiedStatus?
    
    // 多选字段
    var selectedSkills: Set<String> = []
    var selectedHobbies: Set<String> = []
    var selectedValues: Set<String> = []
    var selectedIndustries: Set<String> = []
    var preferredMeetingVibes: Set<MeetingVibe> = []
    
    // 范围字段
    var minYearsOfExperience: Double?
    var maxDistance: Double? // 最大距离（公里），nil表示不限
    
    // 是否启用filter
    var isActive: Bool = false
    
    static let `default` = MatchFilter()
    
    enum CodingKeys: String, CodingKey {
        case experienceLevel
        case careerStage
        case preferredChatFormat
        case preferredMeetingVibes
        case legacyPreferredMeetingVibe
        case verifiedStatus
        case selectedSkills
        case selectedHobbies
        case selectedValues
        case selectedIndustries
        case minYearsOfExperience
        case maxDistance
        case isActive
    }
    
    init() {}
    
    init(
        experienceLevel: ExperienceLevel? = nil,
        careerStage: CareerStage? = nil,
        preferredChatFormat: ChatFormat? = nil,
        preferredMeetingVibes: Set<MeetingVibe> = [],
        verifiedStatus: VerifiedStatus? = nil,
        selectedSkills: Set<String> = [],
        selectedHobbies: Set<String> = [],
        selectedValues: Set<String> = [],
        selectedIndustries: Set<String> = [],
        minYearsOfExperience: Double? = nil,
        maxDistance: Double? = nil,
        isActive: Bool = false
    ) {
        self.experienceLevel = experienceLevel
        self.careerStage = careerStage
        self.preferredChatFormat = preferredChatFormat
        self.preferredMeetingVibes = preferredMeetingVibes
        self.verifiedStatus = verifiedStatus
        self.selectedSkills = selectedSkills
        self.selectedHobbies = selectedHobbies
        self.selectedValues = selectedValues
        self.selectedIndustries = selectedIndustries
        self.minYearsOfExperience = minYearsOfExperience
        self.maxDistance = maxDistance
        self.isActive = isActive
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        experienceLevel = try container.decodeIfPresent(ExperienceLevel.self, forKey: .experienceLevel)
        careerStage = try container.decodeIfPresent(CareerStage.self, forKey: .careerStage)
        preferredChatFormat = try container.decodeIfPresent(ChatFormat.self, forKey: .preferredChatFormat)
        let decodedVibes = try container.decodeIfPresent([MeetingVibe].self, forKey: .preferredMeetingVibes) ?? []
        preferredMeetingVibes = Set(decodedVibes)
        if preferredMeetingVibes.isEmpty, let legacy = try container.decodeIfPresent(MeetingVibe.self, forKey: .legacyPreferredMeetingVibe) {
            preferredMeetingVibes = [legacy]
        }
        verifiedStatus = try container.decodeIfPresent(VerifiedStatus.self, forKey: .verifiedStatus)
        selectedSkills = try container.decodeIfPresent(Set<String>.self, forKey: .selectedSkills) ?? []
        selectedHobbies = try container.decodeIfPresent(Set<String>.self, forKey: .selectedHobbies) ?? []
        selectedValues = try container.decodeIfPresent(Set<String>.self, forKey: .selectedValues) ?? []
        selectedIndustries = try container.decodeIfPresent(Set<String>.self, forKey: .selectedIndustries) ?? []
        minYearsOfExperience = try container.decodeIfPresent(Double.self, forKey: .minYearsOfExperience)
        maxDistance = try container.decodeIfPresent(Double.self, forKey: .maxDistance)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(experienceLevel, forKey: .experienceLevel)
        try container.encodeIfPresent(careerStage, forKey: .careerStage)
        try container.encodeIfPresent(preferredChatFormat, forKey: .preferredChatFormat)
        let vibesArray = Array(preferredMeetingVibes)
        if !vibesArray.isEmpty {
            try container.encode(vibesArray, forKey: .preferredMeetingVibes)
            try container.encode(vibesArray.first, forKey: .legacyPreferredMeetingVibe)
        }
        try container.encodeIfPresent(verifiedStatus, forKey: .verifiedStatus)
        try container.encode(selectedSkills, forKey: .selectedSkills)
        try container.encode(selectedHobbies, forKey: .selectedHobbies)
        try container.encode(selectedValues, forKey: .selectedValues)
        try container.encode(selectedIndustries, forKey: .selectedIndustries)
        try container.encodeIfPresent(minYearsOfExperience, forKey: .minYearsOfExperience)
        try container.encodeIfPresent(maxDistance, forKey: .maxDistance)
        try container.encode(isActive, forKey: .isActive)
    }
    
    func hasActiveFilters() -> Bool {
        return experienceLevel != nil ||
               careerStage != nil ||
               preferredChatFormat != nil ||
               verifiedStatus != nil ||
               !selectedSkills.isEmpty ||
               !selectedHobbies.isEmpty ||
               !selectedValues.isEmpty ||
               !selectedIndustries.isEmpty ||
               minYearsOfExperience != nil ||
               maxDistance != nil
    }
    
    func matches(_ profile: BrewNetProfile) -> Bool {
        // 如果没有任何filter，返回true
        guard hasActiveFilters() else { return true }
        
        if let level = experienceLevel,
           profile.professionalBackground.experienceLevel != level {
            return false
        }
        
        if let stage = careerStage,
           profile.professionalBackground.careerStage != stage {
            return false
        }
        
        if let format = preferredChatFormat,
           profile.networkingPreferences.preferredChatFormat != format {
            return false
        }
        
        if let verified = verifiedStatus,
           profile.privacyTrust.verifiedStatus != verified {
            return false
        }
        
        if !selectedSkills.isEmpty {
            let profileSkills = Set(profile.professionalBackground.skills)
            if profileSkills.isDisjoint(with: selectedSkills) {
                return false
            }
        }
        
        if !selectedHobbies.isEmpty {
            let profileHobbies = Set(profile.personalitySocial.hobbies)
            if profileHobbies.isDisjoint(with: selectedHobbies) {
                return false
            }
        }
        
        if !selectedValues.isEmpty {
            let profileValues = Set(profile.personalitySocial.valuesTags)
            if profileValues.isDisjoint(with: selectedValues) {
                return false
            }
        }
        
        if !selectedIndustries.isEmpty {
            if let industry = profile.professionalBackground.industry,
               !selectedIndustries.contains(industry) {
                return false
            } else if profile.professionalBackground.industry == nil {
                return false
            }
        }
        
        if let minYears = minYearsOfExperience,
           let profileYears = profile.professionalBackground.yearsOfExperience,
           profileYears < minYears {
            return false
        }
        
        // 距离过滤在外部单独处理
        return true
    }
}

// MARK: - Match Filter View
struct MatchFilterView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var filter: MatchFilter = .default
    @State private var showingResetConfirmation = false
    @State private var showSubscriptionPayment = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Icon
                        VStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 48, weight: .light))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Text("Match Filter")
                                .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("Filter your matches by preferences")
                                .font(.system(size: 15))
                    .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Filter Sections
                        // 重新组织：优先级高的和关联性大的放在一起
                        VStack(spacing: 20) {
                            // ========== Professional Background Section (高优先级) ==========
                            // 1. Experience Level (单选)
                            FilterSection(title: "Experience Level") {
                                SingleSelectFilter(
                                    options: ExperienceLevel.allCases,
                                    selected: $filter.experienceLevel,
                                    displayName: { $0.displayName }
                                )
                            }
                            
                            // 2. Years of Experience Range - 关联Experience Level [PRO ONLY]
                            FilterSection(title: "Years of Experience", isProOnly: !(authManager.currentUser?.isProActive ?? false)) {
                                ExperienceRangeFilter(
                                    minYears: $filter.minYearsOfExperience
                                )
                                .disabled(!(authManager.currentUser?.isProActive ?? false))
                                .opacity((authManager.currentUser?.isProActive ?? false) ? 1.0 : 0.5)
                                .overlay(
                                    Group {
                                        if !(authManager.currentUser?.isProActive ?? false) {
                                            Color.clear
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    showSubscriptionPayment = true
                                                }
                                        }
                                    }
                                )
                            }
                            
                            // 4. Industry (多选) - Professional相关，使用IndustryOption与Profile对齐
                            FilterSection(title: "Industry") {
                                MultiSelectFilter(
                                    options: IndustryOption.allCases.map { $0.rawValue },
                                    selected: $filter.selectedIndustries,
                                    maxSelections: 10
                                )
                            }
                            
                            // 5. Skills (多选) - 高优先级，Professional相关 [PRO ONLY]
                            // 使用FeatureVocabularies，与推荐系统对齐
                            FilterSection(title: "Skills", isProOnly: !(authManager.currentUser?.isProActive ?? false)) {
                                MultiSelectFilter(
                                    options: FeatureVocabularies.allSkills,
                                    selected: $filter.selectedSkills,
                                    maxSelections: 10
                                )
                                .disabled(!(authManager.currentUser?.isProActive ?? false))
                                .opacity((authManager.currentUser?.isProActive ?? false) ? 1.0 : 0.5)
                                .overlay(
                                    Group {
                                        if !(authManager.currentUser?.isProActive ?? false) {
                                            Color.clear
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    showSubscriptionPayment = true
                                                }
                                        }
                                    }
                                )
                            }
                            
                            // ========== Networking Preferences Section (中优先级) ==========
                            // 6. Preferred Chat Format (单选) - Networking相关
                            FilterSection(title: "Chat Format") {
                                SingleSelectFilter(
                                    options: ChatFormat.allCases,
                                    selected: $filter.preferredChatFormat,
                                    displayName: { $0.displayName }
                                )
                            }
                            
                            // ========== Personal Preferences Section (低优先级) ==========
                            // 7. Hobbies (多选) - 使用ProfileOptions，与profile设置对齐
                            FilterSection(title: "Hobbies") {
                                MultiSelectFilter(
                                    options: HobbiesOptions.allHobbies,
                                    selected: $filter.selectedHobbies,
                                    maxSelections: 10
                                )
                            }
                            
                            // 8. Values (多选) - 使用ProfileOptions，与profile设置对齐
                            FilterSection(title: "Values") {
                                MultiSelectFilter(
                                    options: ValuesOptions.allValues,
                                    selected: $filter.selectedValues,
                                    maxSelections: 10
                                )
                            }
                            
                            // ========== Location Section (中优先级) ==========
                            // 9. Maximum Distance (范围)
                            FilterSection(title: "Maximum Distance") {
                                DistanceFilter(maxDistance: $filter.maxDistance)
                            }
                            
                            // ========== Verification Section (低优先级) ==========
                            // 10. Verified Status (单选) [PRO ONLY]
                            FilterSection(title: "Verified Status", isProOnly: !(authManager.currentUser?.isProActive ?? false)) {
                                SingleSelectFilter(
                                    options: VerifiedStatus.allCases,
                                    selected: $filter.verifiedStatus,
                                    displayName: { $0.displayName }
                                )
                                .disabled(!(authManager.currentUser?.isProActive ?? false))
                                .opacity((authManager.currentUser?.isProActive ?? false) ? 1.0 : 0.5)
                                .overlay(
                                    Group {
                                        if !(authManager.currentUser?.isProActive ?? false) {
                                            Color.clear
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    showSubscriptionPayment = true
                                                }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // Bottom Action Bar
                VStack {
                Spacer()
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Reset Button
                            Button(action: {
                                showingResetConfirmation = true
                            }) {
                                Text("Reset")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 1.5)
                                    )
                            }
                            
                            // Apply Button
                            Button(action: {
                                applyFilter()
                            }) {
                                Text("Apply")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        filter.hasActiveFilters() ?
                                        Color(red: 0.4, green: 0.2, blue: 0.1) :
                                        Color.gray
                                    )
                                    .cornerRadius(12)
                            }
                            .disabled(!filter.hasActiveFilters())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(
                        Color(red: 0.98, green: 0.97, blue: 0.95)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
        }
        .alert("Reset Filters", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetFilter()
            }
        } message: {
            Text("Are you sure you want to reset all filters?")
        }
        .onAppear {
            loadSavedFilter()
        }
        .sheet(isPresented: $showSubscriptionPayment) {
            if let userId = authManager.currentUser?.id {
                SubscriptionPaymentView(currentUserId: userId) {
                    // Reload user data after subscription
                    Task {
                        await authManager.refreshUser()
                    }
                }
            }
        }
    }
    
    private func applyFilter() {
        // Save filter to UserDefaults
        if let data = try? JSONEncoder().encode(filter) {
            UserDefaults.standard.set(data, forKey: "match_filter_\(authManager.currentUser?.id ?? "default")")
        }
        
        // Post notification to apply filter
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyMatchFilter"),
            object: nil,
            userInfo: ["filter": filter]
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func resetFilter() {
        filter = .default
        UserDefaults.standard.removeObject(forKey: "match_filter_\(authManager.currentUser?.id ?? "default")")
    }
    
    private func loadSavedFilter() {
        guard let userId = authManager.currentUser?.id else { return }
        if let data = UserDefaults.standard.data(forKey: "match_filter_\(userId)"),
           let savedFilter = try? JSONDecoder().decode(MatchFilter.self, from: data) {
            filter = savedFilter
        }
    }
}

// MARK: - Filter Section
struct FilterSection<Content: View>: View {
    let title: String
    let content: Content
    let isProOnly: Bool
    
    init(title: String, isProOnly: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isProOnly = isProOnly
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                if isProOnly {
                    ProBadge(size: .small)
                }
            }
            
            if isProOnly {
                Text("Become Pro to unlock this filter")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.0))
            }
            
            content
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Single Select Filter
struct SingleSelectFilter<T: Hashable & RawRepresentable>: View where T.RawValue: StringProtocol {
    let options: [T]
    @Binding var selected: T?
    let displayName: (T) -> String
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    if selected == option {
                        selected = nil
                    } else {
                        selected = option
                    }
                }) {
                    HStack {
                        Text(displayName(option))
                            .font(.system(size: 15))
                            .foregroundColor(selected == option ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Spacer()
                        
                        if selected == option {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        selected == option ?
                        Color(red: 0.4, green: 0.2, blue: 0.1) :
                        Color(red: 0.98, green: 0.97, blue: 0.95)
                    )
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Multi Select Filter
struct MultiSelectFilter: View {
    let options: [String]
    @Binding var selected: Set<String>
    let maxSelections: Int
    
    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        if selected.contains(option) {
                            selected.remove(option)
                        } else if selected.count < maxSelections {
                            selected.insert(option)
                        }
                    }) {
                        HStack {
                            Text(option)
                                .font(.system(size: 14))
                                .foregroundColor(selected.contains(option) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                            
                            if selected.contains(option) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            selected.contains(option) ?
                            Color(red: 0.4, green: 0.2, blue: 0.1) :
                            Color(red: 0.98, green: 0.97, blue: 0.95)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!selected.contains(option) && selected.count >= maxSelections)
                    .opacity((!selected.contains(option) && selected.count >= maxSelections) ? 0.5 : 1.0)
                }
            }
            
            if selected.count >= maxSelections {
                Text("Maximum \(maxSelections) selections")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Distance Filter
struct DistanceFilter: View {
    @Binding var maxDistance: Double?
    @State private var sliderValue: Double = 50
    @State private var allowUnlimited: Bool = false
    
    private let distanceRange: ClosedRange<Double> = 5...200
    private let step: Double = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Maximum Distance")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Spacer()
                Text(allowUnlimited ? "Unlimited" : "\(Int(sliderValue)) km")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        if !allowUnlimited {
                            maxDistance = newValue
                        }
                    }
                ),
                in: distanceRange,
                step: step
            )
            .disabled(allowUnlimited)
            .accentColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            .opacity(allowUnlimited ? 0.4 : 1.0)
            
            HStack {
                Text("\(Int(distanceRange.lowerBound)) km")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(distanceRange.upperBound)) km")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Toggle(isOn: $allowUnlimited) {
                Text("Show beyond this range if needed")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
            .onChange(of: allowUnlimited) { isOn in
                if isOn {
                    maxDistance = nil
                } else {
                    maxDistance = sliderValue
                }
            }
        }
        .onAppear {
            if let maxDistance = maxDistance {
                sliderValue = max(distanceRange.lowerBound, min(maxDistance, distanceRange.upperBound))
                allowUnlimited = false
            } else {
                sliderValue = 50
                allowUnlimited = true
            }
        }
        .onChange(of: maxDistance) { newValue in
            if let newValue = newValue {
                sliderValue = max(distanceRange.lowerBound, min(newValue, distanceRange.upperBound))
                if allowUnlimited {
                    allowUnlimited = false
                }
            } else {
                allowUnlimited = true
            }
        }
    }
}

// MARK: - Experience Range Filter
struct ExperienceRangeFilter: View {
    @Binding var minYears: Double?
    
    @State private var sliderValue: Double = 0
    
    private let range: ClosedRange<Double> = 0...30
    private let step: Double = 1
    
    private var displayLabel: String {
        if sliderValue <= range.lowerBound { return "Any" }
        if sliderValue >= 20 { return "20+ yrs" }
        return "\(Int(sliderValue)) yrs"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Minimum Experience")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Spacer()
                Text(displayLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            Slider(
                value: Binding(
                    get: { sliderValue },
                    set: { newValue in
                        sliderValue = newValue
                        if newValue <= range.lowerBound {
                            minYears = nil
                        } else {
                            minYears = newValue
                        }
                    }
                ),
                in: range,
                step: step
            )
            .accentColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            HStack {
                Text("Any")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text("20+ yrs")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            let initialValue = minYears ?? range.lowerBound
            sliderValue = max(range.lowerBound, min(initialValue, range.upperBound))
        }
        .onChange(of: minYears) { newValue in
            let updated = newValue ?? range.lowerBound
            sliderValue = max(range.lowerBound, min(updated, range.upperBound))
        }
    }
}

// MARK: - Increase Exposure View
struct IncreaseExposureView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var boostCount: Int = 0
    @State private var superboostCount: Int = 0
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Increase Exposure")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                Text("Boost your profile visibility")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Superboost Card
                    ExposureBoostCard(
                        title: "Superboost",
                        icon: "star.fill",
                        iconColor: Color(red: 1.0, green: 0.84, blue: 0.0),
                        duration: "24 hours",
                        multiplier: "100x",
                        description: "Be the top profile in your area for 24 hours",
                        availableCount: superboostCount,
                        isLoading: isLoading,
                        action: {
                            useSuperboost()
                        }
                    )
                    
                    // Regular Boost Card
                    ExposureBoostCard(
                        title: "Boost",
                        icon: "bolt.fill",
                        iconColor: Color(red: 0.4, green: 0.5, blue: 0.5),
                        duration: "1 hour",
                        multiplier: "11x",
                        description: "Show your profile to 11x more people",
                        availableCount: boostCount,
                        isLoading: isLoading,
                        action: {
                            useBoost()
                        }
                    )
                    
                    // Info text
                    Text("Use your boosts anytime to increase visibility")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .onAppear {
            loadBoostCounts()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadBoostCounts() {
        guard let userId = authManager.currentUser?.id else { return }
        
        Task {
            do {
                struct BoostData: Codable {
                    let boost_count: Int?
                    let superboost_count: Int?
                }
                
                let response: BoostData = try await SupabaseConfig.shared.client
                    .from("users")
                    .select("boost_count, superboost_count")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run {
                    boostCount = response.boost_count ?? 0
                    superboostCount = response.superboost_count ?? 0
                }
            } catch {
                print("Error loading boost counts: \(error)")
            }
        }
    }
    
    private func useBoost() {
        guard let userId = authManager.currentUser?.id else { return }
        guard boostCount > 0 else {
            errorMessage = "You don't have any boosts available. Purchase more from your profile."
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Calculate expiry time (1 hour from now)
                let expiryTime = Date().addingTimeInterval(3600) // 1 hour
                
                // Create update struct
                struct BoostUpdate: Encodable {
                    let boost_count: Int
                    let active_boost_expiry: String
                    let boost_last_used: String
                }
                
                let updateData = BoostUpdate(
                    boost_count: boostCount - 1,
                    active_boost_expiry: expiryTime.ISO8601Format(),
                    boost_last_used: Date().ISO8601Format()
                )
                
                // Update database
                try await SupabaseConfig.shared.client
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()
                
                await MainActor.run {
                    isLoading = false
                    boostCount -= 1
                    
                    // Show success message
                    errorMessage = "Boost activated! Your profile will be shown to 11x more people for 1 hour."
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to activate boost: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func useSuperboost() {
        guard let userId = authManager.currentUser?.id else { return }
        guard superboostCount > 0 else {
            errorMessage = "You don't have any superboosts available. Purchase more from your profile."
            showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // Calculate expiry time (24 hours from now)
                let expiryTime = Date().addingTimeInterval(86400) // 24 hours
                
                // Create update struct
                struct SuperboostUpdate: Encodable {
                    let superboost_count: Int
                    let active_superboost_expiry: String
                    let superboost_last_used: String
                }
                
                let updateData = SuperboostUpdate(
                    superboost_count: superboostCount - 1,
                    active_superboost_expiry: expiryTime.ISO8601Format(),
                    superboost_last_used: Date().ISO8601Format()
                )
                
                // Update database
                try await SupabaseConfig.shared.client
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()
                
                await MainActor.run {
                    isLoading = false
                    superboostCount -= 1
                    
                    // Show success message
                    errorMessage = "Superboost activated! You'll be the top profile in your area for 24 hours."
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to activate superboost: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Exposure Boost Card
struct ExposureBoostCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let duration: String
    let multiplier: String
    let description: String
    let availableCount: Int
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Count badge
                        Text("\(availableCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 32, minHeight: 32)
                            .background(iconColor)
                            .clipShape(Circle())
                    }
                    
                    Text("\(multiplier) visibility for \(duration)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Use button
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(availableCount > 0 ? "Use \(title)" : "No \(title)s Available")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(availableCount > 0 ? iconColor : Color.gray)
                .cornerRadius(25)
            }
            .disabled(isLoading || availableCount == 0)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview
struct BrewNetMatchesView_Previews: PreviewProvider {
    static var previews: some View {
        BrewNetMatchesView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

