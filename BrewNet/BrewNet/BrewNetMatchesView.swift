import SwiftUI

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
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    private let recommendationService = RecommendationService.shared
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .frame(height: screenHeight * 0.6)
                }
                // Cards Stack（确保 profiles 不为空且当前索引有效）
                else if !profiles.isEmpty && currentIndex < profiles.count {
                    ZStack {
                        // Next card (background)
                        if currentIndex + 1 < profiles.count {
                            UserProfileCardView(
                                profile: profiles[currentIndex + 1],
                                dragOffset: .constant(.zero),
                                rotationAngle: .constant(0),
                                onSwipe: { _ in },
                                isConnection: isConnection
                            )
                            .scaleEffect(0.95)
                            .offset(y: 10)
                        }
                        
                        // Current card (foreground)
                        UserProfileCardView(
                            profile: profiles[currentIndex],
                            dragOffset: $dragOffset,
                            rotationAngle: $rotationAngle,
                            onSwipe: handleSwipe,
                            isConnection: isConnection
                        )
                    }
                    .frame(height: screenHeight * 0.8)
                    .padding(.top, 50) // 添加顶部padding避免和状态栏重叠
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
                        .padding(.bottom, 40) // 放在底部，距离底部一点距离
                }
            }
        }
        .onAppear {
            // 先尝试从持久化缓存加载（包括索引）
            loadCachedProfilesFromStorage()
            
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
        .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
            Button("Keep Swiping") {
                showingMatchAlert = false
            }
            Button("View Match") {
                // Navigate to match details
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
        HStack(spacing: 40) {
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
            
            // Like button
            Button(action: {
                swipeRight()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .disabled(currentIndex >= profiles.count)
        }
    }
    
    private func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            passProfile()
        case .right:
            likeProfile()
        case .none:
            break
        }
    }
    
    private func swipeLeft() {
        withAnimation(.spring()) {
            dragOffset = CGSize(width: -screenWidth, height: 0)
            rotationAngle = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            passProfile()
        }
    }
    
    private func swipeRight() {
        withAnimation(.spring()) {
            dragOffset = CGSize(width: screenWidth, height: 0)
            rotationAngle = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            likeProfile()
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
        
        // 立即从列表中移除已拒绝的 profile，避免连续闪过
        profiles.remove(at: currentIndex)
        
        // 同时从缓存中移除，确保切换 tab 后不会再次显示
        cachedProfiles.removeAll { $0.userId == profile.userId }
        
        // 如果移除后当前索引超出范围，调整索引
        if currentIndex >= profiles.count && !profiles.isEmpty {
            currentIndex = 0
        } else if profiles.isEmpty {
            // 如果列表为空，尝试加载更多
            if hasMoreProfiles {
                loadMoreProfiles()
            }
        }
        
        // 重置动画状态
        dragOffset = .zero
        rotationAngle = 0
        
        // 立即更新持久化缓存，确保切换 tab 后不会显示已拒绝的用户
        saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
        
        // 记录 Pass 交互（异步，不阻塞UI）
        Task {
            await recommendationService.recordPass(
                userId: currentUser.id,
                targetUserId: profile.userId
            )
        }
        
        print("❌ Passed profile: \(profile.coreIdentity.name)")
    }
    
    private func likeProfile() {
        guard currentIndex < profiles.count else { return }
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        let profile = profiles[currentIndex]
        likedProfiles.append(profile)
        
        // 记录 Like 交互
        Task {
            await recommendationService.recordLike(
                userId: currentUser.id,
                targetUserId: profile.userId
            )
        }
        
        // 发送邀请到 Supabase
        Task {
            do {
                // 获取当前用户的 profile 信息用于 senderProfile
                var senderProfile: InvitationProfile? = nil
                if let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let brewNetProfile = currentUserProfile.toBrewNetProfile()
                    senderProfile = brewNetProfile.toInvitationProfile()
                }
                
                // 发送邀请
                let invitation = try await supabaseService.sendInvitation(
                    senderId: currentUser.id,
                    receiverId: profile.userId,
                    reasonForInterest: nil, // 可以后续添加理由
                    senderProfile: senderProfile
                )
                
                print("✅ Invitation sent successfully: \(invitation.id)")
                
                // 清除推荐缓存，确保已发送邀请的用户不再出现在推荐列表中
                await MainActor.run {
                    // 1. 立即从当前显示列表中移除（如果还在显示）
                    profiles.removeAll { $0.userId == profile.userId }
                    
                    // 2. 从缓存中移除（如果还在缓存中）
                    cachedProfiles.removeAll { $0.userId == profile.userId }
                    
                    // 3. 更新持久化缓存（保存移除后的缓存）
                    if !cachedProfiles.isEmpty {
                        saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
                        print("✅ Updated cache after sending invitation (removed \(profile.coreIdentity.name))")
                    } else {
                        // 如果缓存为空，清除持久化缓存
                        if let currentUser = authManager.currentUser {
                            let cacheKey = "matches_cache_\(currentUser.id)"
                            let timeKey = "matches_cache_time_\(currentUser.id)"
                            let sourceKey = "matches_cache_source_\(currentUser.id)"
                            UserDefaults.standard.removeObject(forKey: cacheKey)
                            UserDefaults.standard.removeObject(forKey: timeKey)
                            UserDefaults.standard.removeObject(forKey: sourceKey)
                            isCacheFromRecommendation = false
                            print("🗑️ Cleared local cache (empty after removing invited user)")
                        }
                    }
                    
                    // 4. 调整索引（如果当前索引超出范围）
                    if currentIndex >= profiles.count && !profiles.isEmpty {
                        currentIndex = 0
                    } else if profiles.isEmpty {
                        currentIndex = 0
                    }
                    
                    // 5. 清除服务器端的推荐缓存（异步）
                    Task {
                        do {
                            try await supabaseService.clearRecommendationCache(userId: currentUser.id)
                            print("🗑️ Cleared server-side recommendation cache")
                        } catch {
                            print("⚠️ Failed to clear server-side cache: \(error.localizedDescription)")
                        }
                    }
                }
                
                // 检查对方是否也给我发了邀请（双向邀请）
                let receivedInvitations = try? await supabaseService.getPendingInvitations(userId: currentUser.id)
                let existingInvitationFromThem = receivedInvitations?.first { $0.senderId == profile.userId }
                
                if let theirInvitation = existingInvitationFromThem {
                    // 双方互相发送了邀请，自动创建匹配
                    print("💚 Mutual invitation detected! Auto-creating match...")
                    
                    // 先接受对方发给我的邀请（这会触发数据库触发器创建匹配）
                    do {
                        _ = try await supabaseService.acceptInvitation(
                            invitationId: theirInvitation.id,
                            userId: currentUser.id
                        )
                        print("✅ Accepted their invitation - match created via trigger")
                    } catch {
                        print("⚠️ Failed to accept their invitation: \(error.localizedDescription)")
                    }
                    
                    // 然后接受我刚发送的邀请（确保数据库记录一致）
                    do {
                        _ = try await supabaseService.acceptInvitation(
                            invitationId: invitation.id,
                            userId: currentUser.id
                        )
                        print("✅ Accepted my invitation")
                    } catch {
                        // 如果失败，可能匹配已经通过触发器创建了，不影响
                        print("⚠️ Failed to accept my invitation (match may already exist): \(error.localizedDescription)")
                    }
                    
                    // 记录 Match 交互
                    await recommendationService.recordMatch(
                        userId: currentUser.id,
                        targetUserId: profile.userId
                    )
                    
                    // 显示匹配成功提示
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
                
                await MainActor.run {
                    moveToNextProfile()
                }
                
            } catch {
                print("❌ Failed to send invitation: \(error.localizedDescription)")
                await MainActor.run {
                    // 检查是否是已存在的邀请错误
                    if let invitationError = error as? InvitationError,
                       case .alreadyExists = invitationError {
                        // 如果是重复邀请，静默处理，不显示错误
                        print("ℹ️ Invitation already exists, continuing...")
                        moveToNextProfile()
                    } else if error.localizedDescription.contains("already exists") ||
                              error.localizedDescription.contains("duplicate") {
                        // 捕获其他形式的重复错误
                        print("ℹ️ Invitation already exists, continuing...")
                        moveToNextProfile()
                    } else {
                        // 其他错误才显示错误信息
                        errorMessage = "Failed to send invitation: \(error.localizedDescription)"
                        // 延迟清除错误信息
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            errorMessage = nil
                        }
                    }
                    // 即使出错也继续下一个profile
                    moveToNextProfile()
                }
            }
        }
    }
    
    private func moveToNextProfile() {
        currentIndex += 1
        dragOffset = .zero
        rotationAngle = 0
        
        // 每次移动到下一个时保存索引
        saveCurrentIndex()
        
        // 如果已经到达最后一个，检查是否需要加载更多
        if currentIndex >= profiles.count {
            print("📄 Reached end of profiles, may need to load more")
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
            let recommendations = try await recommendationService.getRecommendations(
                for: currentUser.id,
                limit: 50,  // 从 20 增加到 50，增加成功率
                forceRefresh: true  // 静默刷新时也强制刷新
            )
            
            // 获取需要排除的用户ID集合
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            
            // 确保按照推荐分数排序（从高到低）
            let sortedRecommendations = recommendations.sorted { $0.score > $1.score }
            
            // 过滤掉已交互的用户和无效测试用户
            let validRecommendations = sortedRecommendations.filter { rec in
                !excludedUserIds.contains(rec.userId) &&
                !passedProfiles.contains(where: { $0.userId == rec.userId }) &&
                !likedProfiles.contains(where: { $0.userId == rec.userId }) &&
                isValidProfileName(rec.profile.coreIdentity.name) // 排除无效测试用户
            }
            
            let brewNetProfiles = validRecommendations.map { $0.profile }
            
            await MainActor.run {
                // 更新 profiles 和缓存（只保留推荐系统的结果）
                profiles = brewNetProfiles
                cachedProfiles = brewNetProfiles
                lastLoadTime = Date()
                saveCachedProfilesToStorage(isFromRecommendation: true) // 标记为来自推荐系统
                
                // 如果当前索引超出范围，重置
                if currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = 0
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
                let recommendations = try await recommendationService.getRecommendations(
                    for: currentUser.id,
                    limit: 50,  // 从 20 增加到 50，增加成功率
                    forceRefresh: forceRefresh
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
                let finalValidProfiles = brewNetProfiles.filter { profile in
                    !excludedUserIds.contains(profile.userId) &&
                    isValidProfileName(profile.coreIdentity.name)
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
            let filteredProfiles = brewNetProfiles.filter { profile in
                !excludedUserIds.contains(profile.userId) &&
                !passedUserIds.contains(profile.userId) && 
                !likedUserIds.contains(profile.userId) &&
                !excludedMatchedUserIds.contains(profile.userId) && // 防御性过滤已匹配用户
                isValidProfileName(profile.coreIdentity.name) // 排除无效测试用户
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
                if currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = 0
                }
            }
            
        } catch {
            print("❌ Failed to load profiles: \(error.localizedDescription)")
            
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
            
            await MainActor.run {
                if isInitial {
                    errorMessage = "Failed to load profiles: \(error.localizedDescription)"
                    isLoading = false
                } else {
                    isLoadingMore = false
                }
            }
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
                yearsOfExperience: 8.5,
                careerStage: .manager,
                skills: ["Product Strategy", "User Research", "UX Design", "Data Analysis", "Agile"],
                certifications: [],
                languagesSpoken: ["English", "Mandarin"],
                workExperiences: [
                    WorkExperience(
                        companyName: "Google",
                        startYear: 2021,
                        endYear: nil,
                        position: "Senior Product Designer"
                    ),
                    WorkExperience(
                        companyName: "Adobe",
                        startYear: 2020,
                        endYear: 2021,
                        position: "Product Designer"
                    ),
                    WorkExperience(
                        companyName: "StartupCo",
                        startYear: 2018,
                        endYear: 2020,
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
                selfIntroduction: "I love bridging design and data to solve real-world problems. When I'm not designing products, you'll find me exploring coffee shops or capturing moments with my camera."
            ),
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
                yearsOfExperience: 5.0,
                careerStage: .midLevel,
                skills: ["iOS Development", "Swift", "React Native", "Backend"],
                certifications: [],
                languagesSpoken: ["English", "Spanish"],
                workExperiences: [
                    WorkExperience(
                        companyName: "StartupXYZ",
                        startYear: 2020,
                        endYear: nil,
                        position: "Software Engineer"
                    ),
                    WorkExperience(
                        companyName: "TechCorp",
                        startYear: 2019,
                        endYear: 2020,
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
                selfIntroduction: "Passionate about mobile apps and building great user experiences."
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .verifiedProfessional,
                dataSharingConsent: true,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
        
        return [profile1, profile2]
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
}

// MARK: - Preview
struct BrewNetMatchesView_Previews: PreviewProvider {
    static var previews: some View {
        BrewNetMatchesView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

