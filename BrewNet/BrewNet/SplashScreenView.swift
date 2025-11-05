import SwiftUI
import UIKit

// MARK: - Splash Screen View
struct SplashScreenView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var databaseManager: DatabaseManager
    
    @State private var isLoading = true
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage = "Getting ready..."
    
    var body: some View {
        ZStack {
            // 背景渐变 - 使用应用的棕色主题
            LinearGradient(
                gradient: Gradient(colors: [
                    BrewTheme.primaryBrown.opacity(0.95),
                    BrewTheme.secondaryBrown.opacity(0.9),
                    BrewTheme.accentColor.opacity(0.85)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo 区域
                VStack(spacing: 24) {
                    // Logo 图标
                    ZStack {
                        // 背景圆形
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)
                        
                        // Logo 图片
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                    }
                    
                    // 应用名称
                    VStack(spacing: 8) {
                        Text("BrewNet")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                        
                        Text("Connect. Brew. Network.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            loadInitialData()
        }
    }
    
    // MARK: - Data Loading
    // This animation loads the following data to improve app performance:
    // 1. User Profile - Personal information and settings
    // 2. Recommended Profiles - Potential matches for the Matches tab (cached)
    // 3. Active Matches - Existing matches for the Chat tab (cached)
    // 4. Pending Invitations - Connection requests for the Requests tab (cached)
    // 5. Profile Images - All avatar images for instant display
    private func loadInitialData() {
        guard let currentUser = authManager.currentUser else {
            return
        }
        
        Task {
            await updateProgress(0.1, message: "Connecting now, setting up somehow...")
            
            // 1. Ensure database connection
            await updateProgress(0.2, message: "Database steady, getting ready...")
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // 2. Load user Profile - Personal information and settings
            await updateProgress(0.4, message: "Loading your profile, in a while...")
            var userProfile: SupabaseProfile? = nil
            do {
                userProfile = try? await supabaseService.getProfile(userId: currentUser.id)
            }
            
            // 2.5. 优先预加载当前用户的头像（确保登录后立即显示）
            if let profileImage = userProfile?.coreIdentity.profileImage, !profileImage.isEmpty {
                await preloadImages(urls: [profileImage])
                print("✅ Preloaded current user's profile image: \(profileImage)")
            }
            
            // 3. Preload recommended profiles using Two-Tower recommendation system
            await updateProgress(0.5, message: "Finding great matches, making catches...")
            var recommendedProfiles: [SupabaseProfile] = []
            var brewNetProfiles: [BrewNetProfile] = []
            do {
                // 使用推荐系统（Two-Tower）进行预热，确保使用与推荐页面相同的逻辑
                let recommendationService = RecommendationService.shared
                let recommendations = try await recommendationService.getRecommendations(
                    for: currentUser.id,
                    limit: 50,  // 使用与推荐页面相同的数量
                    forceRefresh: false  // 使用缓存如果可用
                )
                
                // 转换为 BrewNetProfile
                brewNetProfiles = recommendations.map { $0.profile }
                
                // 转换为 SupabaseProfile 用于图片预加载
                // 注意：这里我们需要从 profiles 获取，但推荐系统返回的是 BrewNetProfile
                // 我们需要获取原始 SupabaseProfile 用于图片预加载
                let profileUserIds = brewNetProfiles.map { $0.userId }
                let profilesDict = try await supabaseService.getProfilesBatch(userIds: profileUserIds)
                recommendedProfiles = Array(profilesDict.values)
                
                // 保存到 UserDefaults 缓存，并标记为来自推荐系统
                await saveProfilesToCache(profiles: brewNetProfiles, userId: currentUser.id, isFromRecommendation: true)
                print("✅ Preloaded and saved \(brewNetProfiles.count) profiles from recommendation system to cache")
            } catch {
                print("⚠️ Failed to preload profiles with recommendation system: \(error.localizedDescription)")
                // 如果推荐系统失败，回退到传统方法
            do {
                let (profiles, _, _) = try await supabaseService.getRecommendedProfiles(
                    userId: currentUser.id,
                    limit: 20,
                    offset: 0
                )
                recommendedProfiles = profiles
                    brewNetProfiles = profiles.map { $0.toBrewNetProfile() }
                    await saveProfilesToCache(profiles: brewNetProfiles, userId: currentUser.id, isFromRecommendation: false)
                    print("✅ Fallback: Saved \(brewNetProfiles.count) profiles to cache using traditional method")
            } catch {
                    print("⚠️ Failed to preload profiles with fallback method: \(error.localizedDescription)")
                }
            }
            
            // 4. Preload active matches (for Chat tab cache) - Existing matches
            await updateProgress(0.7, message: "Loading your chats, where it's at...")
            var activeMatches: [SupabaseMatch] = []
            do {
                activeMatches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                
                // 构建 ChatSessions 并保存到缓存，供 ChatInterfaceView 使用
                let chatSessions = await buildChatSessionsFromMatches(
                    matches: activeMatches,
                    currentUserId: currentUser.id
                )
                await saveChatSessionsToCache(sessions: chatSessions, userId: currentUser.id)
                print("✅ Saved \(chatSessions.count) chat sessions to cache for Chat tab")
            } catch {
                print("⚠️ Failed to preload matches: \(error.localizedDescription)")
            }
            
            // 5. Preload pending invitations (for Requests tab cache) - Connection requests
            // Note: ConnectionRequestsView doesn't use cache, but we still preload for faster display
            await updateProgress(0.85, message: "Syncing invitations, creating connections...")
            var pendingInvitations: [SupabaseInvitation] = []
            do {
                pendingInvitations = try await supabaseService.getPendingInvitations(userId: currentUser.id)
                print("✅ Preloaded \(pendingInvitations.count) pending invitations")
            } catch {
                print("⚠️ Failed to preload invitations: \(error.localizedDescription)")
            }
            
            // 6. Preload all profile images - Avatars for instant display
            await updateProgress(0.95, message: "Loading profile images, perfecting the scene...")
            
            // Collect all image URLs (excluding current user's image as it's already loaded)
            var imageURLs: [String] = []
            
            // Add recommended profiles images
            for profile in recommendedProfiles {
                if let profileImage = profile.coreIdentity.profileImage, !profileImage.isEmpty {
                    imageURLs.append(profileImage)
                }
            }
            
            // Add matched users' profile images (need to fetch their profiles concurrently)
            let matchImageTasks = activeMatches.map { match -> Task<String?, Never> in
                Task {
                    let matchedUserId = match.userId == currentUser.id ? match.matchedUserId : match.userId
                    if let matchedProfile = try? await supabaseService.getProfile(userId: matchedUserId),
                       let profileImage = matchedProfile.coreIdentity.profileImage,
                       !profileImage.isEmpty {
                        return profileImage
                    }
                    return nil
                }
            }
            
            // Wait for all match profile fetches
            for task in matchImageTasks {
                if let imageUrl = await task.value {
                    imageURLs.append(imageUrl)
                }
            }
            
            // Add invitation senders' profile images (from senderProfile or fetch concurrently)
            let invitationImageTasks = pendingInvitations.map { invitation -> Task<String?, Never> in
                Task {
                    // First try senderProfile
                    if let senderProfile = invitation.senderProfile,
                       let profileImage = senderProfile.profileImage,
                       !profileImage.isEmpty {
                        return profileImage
                    }
                    
                    // Fetch profile if not in senderProfile
                    if let senderProfile = try? await supabaseService.getProfile(userId: invitation.senderId),
                       let profileImage = senderProfile.coreIdentity.profileImage,
                       !profileImage.isEmpty {
                        return profileImage
                    }
                    
                    return nil
                }
            }
            
            // Wait for all invitation profile fetches
            for task in invitationImageTasks {
                if let imageUrl = await task.value {
                    imageURLs.append(imageUrl)
                }
            }
            
            // Preload all images concurrently
            await preloadImages(urls: imageURLs)
            
            // 7. Complete
            await updateProgress(1.0, message: "Almost there, getting ready to share...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Mark loading as complete, ContentView will automatically switch to main interface
            await MainActor.run {
                isLoading = false
                print("✅ Splash screen loading completed")
            }
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double, message: String) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            loadingProgress = progress
            loadingMessage = message
        }
    }
    
    // MARK: - Image Preloading
    /// Preload images by downloading them and caching them
    /// This ensures images appear instantly when users navigate to profiles
    private func preloadImages(urls: [String]) async {
        guard !urls.isEmpty else {
            print("📷 No images to preload")
            return
        }
        
        print("📷 Preloading \(urls.count) profile images...")
        
        // Remove duplicates
        let uniqueURLs = Array(Set(urls))
        
        // Create tasks for concurrent image loading
        let imageTasks = uniqueURLs.compactMap { urlString -> Task<Void, Never>? in
            guard let url = URL(string: urlString) else { return nil }
            
            return Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    
                    // Cache the image data
                    // SwiftUI's AsyncImage will automatically use URLCache, but we can also
                    // force it into memory cache by accessing it
                    if let image = UIImage(data: data) {
                        // Image is now in memory, AsyncImage cache will handle persistence
                        print("✅ Preloaded image: \(urlString)")
                    }
                } catch {
                    print("⚠️ Failed to preload image \(urlString): \(error.localizedDescription)")
                }
            }
        }
        
        // Wait for all images to load (with timeout)
        await withTaskGroup(of: Void.self) { group in
            for task in imageTasks {
                group.addTask {
                    await task.value
                }
            }
            
            // Add a timeout to prevent indefinite waiting
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
            }
        }
        
        print("✅ Completed preloading \(imageTasks.count) images")
    }
    
    // MARK: - Cache Helpers
    
    /// Save profiles to UserDefaults cache (same format as BrewNetMatchesView)
    private func saveProfilesToCache(profiles: [BrewNetProfile], userId: String, isFromRecommendation: Bool = false) async {
        let cacheKey = "matches_cache_\(userId)"
        let timeKey = "matches_cache_time_\(userId)"
        let sourceKey = "matches_cache_source_\(userId)"  // 标记缓存来源
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            UserDefaults.standard.set(isFromRecommendation, forKey: sourceKey)  // 保存缓存来源标记
            print("✅ Saved \(profiles.count) profiles to cache (from recommendation system: \(isFromRecommendation))")
        } catch {
            print("⚠️ Failed to save profiles to cache: \(error)")
        }
    }
    
    /// Build ChatSessions from matches and save to cache
    private func buildChatSessionsFromMatches(matches: [SupabaseMatch], currentUserId: String) async -> [ChatSession] {
        var sessions: [ChatSession] = []
        var processedUserIds = Set<String>()
        let dateFormatter = ISO8601DateFormatter()
        
        for match in matches {
            let matchedUserId = match.userId == currentUserId ? match.matchedUserId : match.userId
            
            // Skip self and duplicates
            if matchedUserId == currentUserId || processedUserIds.contains(matchedUserId) {
                continue
            }
            processedUserIds.insert(matchedUserId)
            
            // Get matched user's name
            let matchedUserName: String
            if match.userId == currentUserId {
                matchedUserName = match.matchedUserName
            } else {
                // Fetch name if needed
                if let profile = try? await supabaseService.getProfile(userId: matchedUserId) {
                    matchedUserName = profile.coreIdentity.name
                } else {
                    matchedUserName = match.matchedUserName
                }
            }
            
            let matchDate = dateFormatter.date(from: match.createdAt)
            
            let chatUser = ChatUser(
                name: matchedUserName,
                avatar: "person.circle.fill",
                isOnline: false,
                lastSeen: matchDate ?? Date(),
                interests: [],
                bio: "",
                isMatched: true,
                matchDate: matchDate,
                matchType: .mutual,
                userId: matchedUserId
            )
            
            let session = ChatSession(
                user: chatUser,
                messages: [],
                aiSuggestions: [],
                isActive: true
            )
            
            sessions.append(session)
        }
        
        // Sort by match date
        sessions.sort { session1, session2 in
            let date1 = session1.user.matchDate ?? Date.distantPast
            let date2 = session2.user.matchDate ?? Date.distantPast
            return date1 > date2
        }
        
        return sessions
    }
    
    /// Save chat sessions to UserDefaults cache (same format as ChatInterfaceView)
    private func saveChatSessionsToCache(sessions: [ChatSession], userId: String) async {
        let cacheKey = "chat_sessions_cache_\(userId)"
        let timeKey = "chat_sessions_cache_time_\(userId)"
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessions)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: timeKey)
            print("✅ Saved \(sessions.count) chat sessions to cache")
        } catch {
            print("⚠️ Failed to save chat sessions to cache: \(error)")
        }
    }
}

// MARK: - Preview
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
            .environmentObject(DatabaseManager.shared)
    }
}
