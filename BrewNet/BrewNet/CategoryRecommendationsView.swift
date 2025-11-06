import SwiftUI

// MARK: - Category Recommendations View
struct CategoryRecommendationsView: View {
    let category: NetworkingIntentionType?
    let categoryName: String?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var profiles: [BrewNetProfile] = []
    private let recommendationService = RecommendationService.shared
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle = 0.0
    @State private var showingMatchAlert = false
    @State private var matchedProfile: BrewNetProfile?
    @State private var likedProfiles: [BrewNetProfile] = []
    @State private var passedProfiles: [BrewNetProfile] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMoreProfiles = true
    @State private var isConnection: Bool = false
    @State private var showingTemporaryChat = false
    @State private var selectedProfileForChat: BrewNetProfile?
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    init(category: NetworkingIntentionType) {
        self.category = category
        self.categoryName = nil
    }
    
    init(categoryName: String) {
        self.category = nil
        self.categoryName = categoryName
    }
    
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
                // Cards Stack
                else if currentIndex < profiles.count {
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
                    .padding(.top, 50) // Add top padding to avoid status bar overlap
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
            
            // Header - positioned at the top over content
            VStack {
                headerView
                    .background(.ultraThinMaterial)
                Spacer()
            }
            
            // Action Buttons - positioned at the bottom over content (only when showing cards)
            if !isLoading && currentIndex < profiles.count {
                VStack {
                    Spacer()
                    actionButtonsView
                        .padding(.bottom, 40) // Distance from bottom
                        .zIndex(100) // 确保按钮在最上层
                }
            }
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
            Button("Keep Swiping") {
                showingMatchAlert = false
            }
            Button("View Match") {
                showingMatchAlert = false
            }
        } message: {
            if let profile = matchedProfile {
                Text("You and \(profile.coreIdentity.name) liked each other!")
            }
        }
        .onAppear {
            loadRecommendations()
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
    }
    
    private var headerView: some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            Spacer()
            
            // Title only
            Text(displayTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 15) // Top padding adjusted to 15
        .padding(.bottom, 16)
    }
    
    private var noMoreProfilesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
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
                Text("You've seen all available profiles in this category!\nCheck back later for new recommendations.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
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
                Button("Back to Explore") {
                    dismiss()
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
            // Auto load more if there is data
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
                    
                    Image(systemName: "message.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
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
    
    private func openTemporaryChat() {
        guard currentIndex < profiles.count else { return }
        let profile = profiles[currentIndex]
        selectedProfileForChat = profile
        showingTemporaryChat = true
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
        
        // 如果移除后当前索引超出范围，调整索引
        if currentIndex >= profiles.count && !profiles.isEmpty {
            currentIndex = 0
        } else if profiles.isEmpty {
            // 如果列表为空，加载更多
            loadMoreProfiles()
        }
        
        // 重置动画状态
        dragOffset = .zero
        rotationAngle = 0
        
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
                    reasonForInterest: nil,
                    senderProfile: senderProfile
                )
                
                print("✅ Invitation sent successfully: \(invitation.id)")
                
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
                    moveToNextProfile()
                }
            }
        }
    }
    
    private func moveToNextProfile() {
        // 确保索引有效
        guard !profiles.isEmpty else {
            loadMoreProfiles()
            return
        }
        
        currentIndex += 1
        
        // 如果超出范围，尝试加载更多或重置
        if currentIndex >= profiles.count {
            if hasMoreProfiles {
                loadMoreProfiles()
            } else {
                currentIndex = profiles.count - 1 // 保持在最后一个
            }
        }
        
        dragOffset = .zero
        rotationAngle = 0
    }
    
    // MARK: - Computed Properties
    private var displayTitle: String {
        if let category = category {
            return category.displayName
        } else if let categoryName = categoryName {
            return categoryName
        }
        return "Recommendations"
    }
    
    // MARK: - Load Recommendations
    private func loadRecommendations() {
        isLoading = true
        currentIndex = 0
        profiles.removeAll()
        
        Task {
            await loadProfilesBatch(isInitial: true)
        }
    }
    
    private func loadMoreProfiles() {
        guard !isLoadingMore && hasMoreProfiles else { return }
        
        isLoadingMore = true
        
        Task {
            await loadProfilesBatch(isInitial: false)
        }
    }
    
    private func loadProfilesBatch(isInitial: Bool) async {
        do {
            // Get current user ID
            guard let currentUser = authManager.currentUser else {
                await MainActor.run {
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }
            
            // 使用 Two-Tower 推荐系统（与主页面相同）
            print("🚀 CategoryRecommendationsView: Using Two-Tower recommendation engine")
            
            // 获取推荐（使用推荐系统，与主页面一致）
            let recommendations = try await recommendationService.getRecommendations(
                for: currentUser.id,
                limit: 50,  // 与主页面相同
                forceRefresh: false  // 使用缓存
            )
            
            // 确保按照推荐分数排序（从高到低）
            let sortedRecommendations = recommendations.sorted { $0.score > $1.score }
            
            // 获取需要排除的用户ID集合（推荐系统已经过滤了大部分，这里做最终验证）
            let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: currentUser.id)
            
            // 过滤掉已交互的用户和无效测试用户
            var profilesWithoutExcluded = sortedRecommendations.filter { rec in
                !excludedUserIds.contains(rec.userId) &&
                !passedProfiles.contains(where: { $0.userId == rec.userId }) &&
                !likedProfiles.contains(where: { $0.userId == rec.userId }) &&
                isValidProfileName(rec.profile.coreIdentity.name)
            }
            
            // Filter profiles by the selected category (intention) if applicable
            // 同时过滤掉无效或测试用户（如名为 "123" 的用户）
            let filteredProfiles: [BrewNetProfile]
            if let category = category {
                // Filter by networking intention
                filteredProfiles = profilesWithoutExcluded
                    .filter { $0.profile.networkingIntention.selectedIntention == category }
                    .map { $0.profile }
                print("📊 CategoryRecommendationsView: Filtered \(filteredProfiles.count) profiles from \(profilesWithoutExcluded.count) for category \(category.rawValue)")
            } else {
                // For "Out of Orbit" or other special categories, show all profiles (excluding test users)
                filteredProfiles = profilesWithoutExcluded.map { $0.profile }
                print("📊 CategoryRecommendationsView: Showing all \(filteredProfiles.count) profiles for \(categoryName ?? "Out of Orbit")")
            }
            
            await MainActor.run {
                if isInitial {
                    profiles = filteredProfiles
                    isLoading = false
                    print("✅ CategoryRecommendationsView: Initially loaded \(filteredProfiles.count) profiles for category (excluded \(excludedUserIds.count) users)")
                } else {
                    // 追加时也要排除重复的
                    let existingUserIds = Set(profiles.map { $0.userId })
                    let newProfiles = filteredProfiles.filter { profile in
                        !existingUserIds.contains(profile.userId)
                    }
                    profiles.append(contentsOf: newProfiles)
                    isLoadingMore = false
                    print("✅ CategoryRecommendationsView: Loaded \(newProfiles.count) more profiles (total: \(profiles.count), filtered duplicates: \(filteredProfiles.count - newProfiles.count))")
                }
                
                // 如果返回的推荐数量少于请求的，可能没有更多了
                if recommendations.count < 50 {
                    hasMoreProfiles = false
                    print("ℹ️ CategoryRecommendationsView: No more profiles available. Total loaded: \(profiles.count)")
                } else {
                    // 如果过滤后还有数据，可能还有更多
                    hasMoreProfiles = !filteredProfiles.isEmpty
                }
                
                // If current index is beyond profiles count, reset to 0
                if currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = 0
                }
            }
            
        } catch {
            print("❌ CategoryRecommendationsView: Failed to load recommendations: \(error.localizedDescription)")
            await MainActor.run {
                if isInitial {
                    isLoading = false
                } else {
                    isLoadingMore = false
                }
            }
        }
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

// MARK: - Temporary Chat From Profile View
struct TemporaryChatFromProfileView: View {
    let profile: BrewNetProfile
    let onDismiss: () -> Void
    let onSend: (String) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isSending = false
    
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
                            if let profileImageURL = profile.coreIdentity.profileImage, !profileImageURL.isEmpty {
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
                        
                        Text("Send a message to \(profile.coreIdentity.name)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeBrown)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Text("This will send a connection request and start a temporary chat")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
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
                        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedMessage.isEmpty && !isSending {
                            isSending = true
                            Task {
                                // 发送消息和连接请求（onSend 回调会处理）
                                onSend(trimmedMessage)
                                // 等待一小段时间确保操作开始
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                await MainActor.run {
                                    isSending = false
                                    onDismiss()
                                }
                            }
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Sending...")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.leading, 8)
                            } else {
                                Text("Send Message and Connection Request")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(
                            Group {
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending {
                                    Color.gray.opacity(0.5)
                                } else {
                                    BrewTheme.gradientPrimary()
                                }
                            }
                        )
                        .cornerRadius(12)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
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

// MARK: - Preview
struct CategoryRecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CategoryRecommendationsView(category: .learnGrow)
                .environmentObject(AuthManager())
                .environmentObject(SupabaseService.shared)
            
            CategoryRecommendationsView(categoryName: "Out of Orbit")
                .environmentObject(AuthManager())
                .environmentObject(SupabaseService.shared)
        }
    }
}

