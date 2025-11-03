import SwiftUI

// MARK: - Category Recommendations View
struct CategoryRecommendationsView: View {
    let category: NetworkingIntentionType?
    let categoryName: String?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var profiles: [BrewNetProfile] = []
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
    @State private var databaseOffset: Int = 0 // Track offset for database queries
    
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
        if currentIndex < profiles.count {
            let profile = profiles[currentIndex]
            passedProfiles.append(profile)
            moveToNextProfile()
        }
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
        currentIndex += 1
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
        databaseOffset = 0
        
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
            
            // 获取需要排除的用户ID集合（已匹配 + 已发送邀请）
            var excludedUserIds: Set<String> = []
            
            // 1. 排除已匹配的用户
            do {
                let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                for match in matches {
                    if match.userId == currentUser.id {
                        excludedUserIds.insert(match.matchedUserId)
                    } else if match.matchedUserId == currentUser.id {
                        excludedUserIds.insert(match.userId)
                    }
                }
                if !matches.isEmpty {
                    print("🔍 CategoryRecommendationsView: Excluding \(matches.count) matched users")
                }
            } catch {
                print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
            }
            
            // 2. 排除所有已发送邀请的用户（包括 pending, accepted, rejected, cancelled）
            // 这样可以确保在匹配板块中已发送喜欢/拒绝的人不会出现在 explore
            do {
                let sentInvitations = try await supabaseService.getSentInvitations(userId: currentUser.id)
                for invitation in sentInvitations {
                    excludedUserIds.insert(invitation.receiverId)
                }
                if !sentInvitations.isEmpty {
                    print("🔍 CategoryRecommendationsView: Excluding \(sentInvitations.count) users with sent invitations (all statuses)")
                }
            } catch {
                print("⚠️ Failed to fetch sent invitations for filtering: \(error.localizedDescription)")
            }
            
            // Load profiles from Supabase with pagination using database offset
            let (supabaseProfiles, totalInBatch, filteredCount) = try await supabaseService.getRecommendedProfiles(
                userId: currentUser.id,
                limit: 200,
                offset: databaseOffset
            )
            
            // Convert SupabaseProfile to BrewNetProfile
            let brewNetProfiles = supabaseProfiles.map { $0.toBrewNetProfile() }
            
            // 防御性过滤：再次确保已匹配和已发送邀请的用户被排除
            // 即使 getRecommendedProfiles 已经过滤了，这里再过滤一次确保万无一失
            let profilesWithoutExcluded = brewNetProfiles.filter { profile in
                !excludedUserIds.contains(profile.userId)
            }
            
            if excludedUserIds.count > 0 && brewNetProfiles.count > profilesWithoutExcluded.count {
                let additionalFiltered = brewNetProfiles.count - profilesWithoutExcluded.count
                print("🔍 CategoryRecommendationsView: Additional filtering excluded \(additionalFiltered) users")
            }
            
            // Filter profiles by the selected category (intention) if applicable
            let filteredProfiles: [BrewNetProfile]
            if let category = category {
                // Filter by networking intention
                filteredProfiles = profilesWithoutExcluded.filter { profile in
                    profile.networkingIntention.selectedIntention == category
                }
                print("📊 Filtered \(filteredProfiles.count) profiles from \(profilesWithoutExcluded.count) for category \(category.rawValue)")
            } else {
                // For "Out of Orbit" or other special categories, show all profiles
                filteredProfiles = profilesWithoutExcluded
            }
            
            await MainActor.run {
                if isInitial {
                    profiles = filteredProfiles
                    isLoading = false
                    print("✅ Initially loaded \(filteredProfiles.count) profiles for category (excluded \(excludedUserIds.count) users)")
                } else {
                    // 追加时也要排除重复的
                    let existingUserIds = Set(profiles.map { $0.userId })
                    let newProfiles = filteredProfiles.filter { profile in
                        !existingUserIds.contains(profile.userId)
                    }
                    profiles.append(contentsOf: newProfiles)
                    isLoadingMore = false
                    print("✅ Loaded \(newProfiles.count) more profiles (total: \(profiles.count), filtered duplicates: \(filteredProfiles.count - newProfiles.count))")
                }
                
                // Update database offset for next query
                databaseOffset += supabaseProfiles.count
                
                // If returned count is less than requested, no more profiles from database
                if supabaseProfiles.count < 200 {
                    hasMoreProfiles = false
                    print("ℹ️ No more profiles available. Total loaded: \(profiles.count)")
                } else {
                    hasMoreProfiles = true
                }
                
                // If current index is beyond profiles count, reset to 0
                if currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = 0
                }
            }
            
        } catch {
            print("❌ Failed to load recommendations: \(error.localizedDescription)")
            await MainActor.run {
                if isInitial {
                    isLoading = false
                } else {
                    isLoadingMore = false
                }
            }
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

