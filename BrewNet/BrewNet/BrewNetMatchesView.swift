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
    @State private var isConnection: Bool = false // Whether the viewer is connected to profiles
    @State private var errorMessage: String?
    @State private var totalFetched = 0
    @State private var totalFiltered = 0
    @State private var lastLoadTime: Date? = nil // 记录上次加载时间
    
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
            // 先尝试从持久化缓存加载
            loadCachedProfilesFromStorage()
            
            // 如果有缓存数据且距离上次加载不到5分钟，先显示缓存，然后后台刷新
            if !cachedProfiles.isEmpty, let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < 300 {
                // 显示缓存数据（立即显示，无延迟）
                profiles = cachedProfiles
                isLoading = false
                currentIndex = 0 // 重置到第一张卡片
                print("✅ Using cached profiles: \(cachedProfiles.count) profiles")
                // 后台静默刷新
                Task {
                    await refreshProfilesSilently()
                }
            } else {
                // 首次加载或缓存过期，正常加载
                loadProfiles()
            }
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
                Text("You've seen all available profiles!\n\(profiles.count) profiles loaded.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
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
        if currentIndex < profiles.count {
            let profile = profiles[currentIndex]
            passedProfiles.append(profile)
            
            // 记录 Pass 交互
            if let currentUser = authManager.currentUser {
                Task {
                    await recommendationService.recordPass(
                        userId: currentUser.id,
                        targetUserId: profile.userId
                    )
                }
            }
            
            print("❌ Passed profile: \(profile.coreIdentity.name)")
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
                    errorMessage = "Failed to send invitation. Please try again."
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
    
    private func loadProfiles() {
        errorMessage = nil
        currentIndex = 0
        // 如果有缓存，先显示缓存（提供即时反馈）
        if !cachedProfiles.isEmpty {
            profiles = cachedProfiles
            isLoading = false // 允许用户立即看到数据
            print("✅ Displaying cached profiles immediately: \(cachedProfiles.count) profiles")
        } else {
            // 没有缓存时才显示加载状态
            isLoading = true
            profiles.removeAll()
        }
        totalFetched = 0
        totalFiltered = 0
        
        Task {
            await loadProfilesBatch(offset: 0, limit: 20, isInitial: true) // 先加载少量数据（20个）快速显示
        }
    }
    
    // 后台静默刷新，不显示加载状态
    private func refreshProfilesSilently() async {
        isRefreshing = true
        await loadProfilesBatch(offset: 0, limit: 20, isInitial: true)
        isRefreshing = false
    }
    
    // 从持久化存储加载缓存
    private func loadCachedProfilesFromStorage() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "matches_cache_\(currentUser.id)"
        let timeKey = "matches_cache_time_\(currentUser.id)"
        
        // 从 UserDefaults 加载缓存
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let timestamp = UserDefaults.standard.object(forKey: timeKey) as? Date,
           Date().timeIntervalSince(timestamp) < 300 { // 5分钟内有效
            
            do {
                let decoder = JSONDecoder()
                let cachedProfilesData = try decoder.decode([BrewNetProfile].self, from: data)
                cachedProfiles = cachedProfilesData
                lastLoadTime = timestamp
                print("✅ Loaded \(cachedProfiles.count) profiles from persistent cache")
            } catch {
                print("⚠️ Failed to decode cached profiles: \(error)")
            }
        }
    }
    
    // 保存缓存到持久化存储
    private func saveCachedProfilesToStorage() {
        guard let currentUser = authManager.currentUser else { return }
        
        let cacheKey = "matches_cache_\(currentUser.id)"
        let timeKey = "matches_cache_time_\(currentUser.id)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cachedProfiles)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            print("✅ Saved \(cachedProfiles.count) profiles to persistent cache")
        } catch {
            print("⚠️ Failed to save cached profiles: \(error)")
        }
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
            
            // ========== Two-Tower 推荐模式 ==========
            if offset == 0 && isInitial {
                // 使用 Two-Tower 推荐引擎
                print("🚀 Using Two-Tower recommendation engine")
                let recommendations = try await recommendationService.getRecommendations(
                    for: currentUser.id,
                    limit: 20
                )
                
                let brewNetProfiles = recommendations.map { $0.profile }
                
                await MainActor.run {
                    profiles = brewNetProfiles
                    cachedProfiles = brewNetProfiles
                    lastLoadTime = Date()
                    isLoading = false
                    saveCachedProfilesToStorage()
                    hasMoreProfiles = false // Two-Tower 返回固定数量
                    
                    print("✅ Two-Tower recommendations loaded: \(brewNetProfiles.count) profiles")
                    print("📊 Scores: \(recommendations.map { String(format: "%.3f", $0.score) }.joined(separator: ", "))")
                }
                return
            }
            
            // ========== 传统模式（分页加载更多）==========
            print("📄 Using traditional pagination mode")
            let (supabaseProfiles, totalInBatch, filteredCount) = try await supabaseService.getRecommendedProfiles(
                userId: currentUser.id,
                limit: limit,
                offset: offset
            )
            
            // Convert SupabaseProfile to BrewNetProfile
            let brewNetProfiles = supabaseProfiles.map { $0.toBrewNetProfile() }
            
            await MainActor.run {
                if isInitial {
                    profiles = brewNetProfiles
                    // 更新缓存
                    cachedProfiles = brewNetProfiles
                    lastLoadTime = Date()
                    isLoading = false
                    // 保存到持久化存储
                    saveCachedProfilesToStorage()
                    print("✅ Initially loaded \(brewNetProfiles.count) profiles from Supabase")
                } else {
                    profiles.append(contentsOf: brewNetProfiles)
                    // 更新缓存
                    cachedProfiles.append(contentsOf: brewNetProfiles)
                    isLoadingMore = false
                    // 保存到持久化存储
                    saveCachedProfilesToStorage()
                    print("✅ Loaded \(brewNetProfiles.count) more profiles (total: \(profiles.count))")
                }
                
                totalFetched += totalInBatch
                totalFiltered += filteredCount
                
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
        currentIndex = 0
        hasMoreProfiles = true
        likedProfiles.removeAll()
        passedProfiles.removeAll()
        loadProfiles()
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
                timeZone: "America/Los_Angeles",
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    monday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    tuesday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                )
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
                timeZone: "America/New_York",
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    monday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    tuesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                )
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
}

// MARK: - Preview
struct BrewNetMatchesView_Previews: PreviewProvider {
    static var previews: some View {
        BrewNetMatchesView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

