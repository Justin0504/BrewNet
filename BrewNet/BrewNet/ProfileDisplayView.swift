import SwiftUI
import PhotosUI
import UIKit
import Supabase

// MARK: - Local Cache Manager
class LocalCacheManager {
    static let shared = LocalCacheManager()
    private let userDefaults = UserDefaults.standard
    static let redeemCacheVersion = 3
    
    private init() {}
    
    // MARK: - Credit View Cache
    func saveCreditData(userId: String, credits: Int, history: [CoffeeChatRecord]) {
        let key = "credit_cache_\(userId)"
        let data = CreditCacheData(credits: credits, history: history, timestamp: Date())
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: key)
            print("💾 [Cache] 已保存 Credit 数据到本地缓存")
        }
    }
    
    func loadCreditData(userId: String) -> CreditCacheData? {
        let key = "credit_cache_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CreditCacheData.self, from: data) else {
            return nil
        }
        
        // 检查缓存是否过期（24小时）
        if let timestamp = decoded.timestamp,
           Date().timeIntervalSince(timestamp) > 86400 {
            print("⏰ [Cache] Credit 缓存已过期")
            return nil
        }
        
        print("📦 [Cache] 从本地缓存加载 Credit 数据")
        return decoded
    }
    
    // MARK: - Redeem View Cache (Optimized)
    func saveRedeemData(userId: String, credits: Int, rewards: [Reward], redemptions: [RedemptionRecord], coffeeRewards: [Reward]? = nil, membershipRewards: [Reward]? = nil) {
        let key = "redeem_cache_\(userId)"
        let data = RedeemCacheData(
            credits: credits,
            rewards: rewards,
            redemptions: redemptions,
            coffeeRewards: coffeeRewards,
            membershipRewards: membershipRewards,
            timestamp: Date(),
            version: LocalCacheManager.redeemCacheVersion // 缓存版本号
        )
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults.set(encoded, forKey: key)
            print("💾 [Cache] 已保存 Redeem 数据到本地缓存 (版本 3)")
        }
    }
    
    func loadRedeemData(userId: String) -> RedeemCacheData? {
        let key = "redeem_cache_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RedeemCacheData.self, from: data) else {
            return nil
        }
        
        // 检查缓存版本，旧版本需要重新加载
        if decoded.version < 2 {
            print("⚠️ [Cache] Redeem 缓存版本过旧，需要更新")
            return nil
        }
        if decoded.version < LocalCacheManager.redeemCacheVersion {
            print("⚠️ [Cache] Redeem 缓存版本 \(decoded.version) 已过期，最新版本为 \(LocalCacheManager.redeemCacheVersion)")
            return nil
        }
        
        // 检查缓存是否过期（奖励数据 12 小时，兑换记录 1 小时）
        if let timestamp = decoded.timestamp {
            let timeSinceCache = Date().timeIntervalSince(timestamp)
            // 如果超过 12 小时，认为缓存过期
            if timeSinceCache > 43200 {
                print("⏰ [Cache] Redeem 缓存已过期 (\(Int(timeSinceCache/3600)) 小时前)")
                return nil
            }
            print("📦 [Cache] 从本地缓存加载 Redeem 数据 (\(Int(timeSinceCache/60)) 分钟前)")
        }
        
        return decoded
    }
    
    // 快速更新积分（不更新其他数据）
    func updateRedeemCredits(userId: String, credits: Int) {
        let key = "redeem_cache_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              var decoded = try? JSONDecoder().decode(RedeemCacheData.self, from: data) else {
            return
        }
        
        // 只更新积分，保持其他数据不变
        let updatedData = RedeemCacheData(
            credits: credits,
            rewards: decoded.rewards,
            redemptions: decoded.redemptions,
            coffeeRewards: decoded.coffeeRewards,
            membershipRewards: decoded.membershipRewards,
            timestamp: decoded.timestamp, // 保持原时间戳
            version: LocalCacheManager.redeemCacheVersion
        )
        
        if let encoded = try? JSONEncoder().encode(updatedData) {
            userDefaults.set(encoded, forKey: key)
            print("💾 [Cache] 已快速更新积分缓存: \(credits)")
        }
    }
    
    // MARK: - Chats View Cache
    func saveChatsData(userId: String, schedules: [CoffeeChatSchedule]) {
        let key = "chats_cache_\(userId)"
        let cacheData = ChatsCacheData(schedules: schedules, timestamp: Date())
        if let encoded = try? JSONEncoder().encode(cacheData) {
            userDefaults.set(encoded, forKey: key)
            print("💾 [Cache] 已保存 Chats 数据到本地缓存")
        }
    }
    
    func loadChatsData(userId: String) -> ChatsCacheData? {
        let key = "chats_cache_\(userId)"
        guard let data = userDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ChatsCacheData.self, from: data) else {
            return nil
        }
        
        // 检查缓存是否过期（24小时）
        if let timestamp = decoded.timestamp,
           Date().timeIntervalSince(timestamp) > 86400 {
            print("⏰ [Cache] Chats 缓存已过期")
            return nil
        }
        
        print("📦 [Cache] 从本地缓存加载 Chats 数据")
        return decoded
    }
    
    // MARK: - Clear Cache
    func clearCache(userId: String) {
        userDefaults.removeObject(forKey: "credit_cache_\(userId)")
        userDefaults.removeObject(forKey: "redeem_cache_\(userId)")
        userDefaults.removeObject(forKey: "chats_cache_\(userId)")
        print("🗑️ [Cache] 已清除用户缓存")
    }
}

// MARK: - Chats Cache Data Model
struct ChatsCacheData: Codable {
    let schedules: [CoffeeChatSchedule]
    let timestamp: Date?
}

// MARK: - Cache Data Models
struct CreditCacheData: Codable {
    let credits: Int
    let history: [CoffeeChatRecord]
    let timestamp: Date?
}

struct RedeemCacheData: Codable {
    let credits: Int
    let rewards: [Reward]
    let redemptions: [RedemptionRecord]
    let coffeeRewards: [Reward]? // 预过滤的咖啡奖励
    let membershipRewards: [Reward]? // 预过滤的会员奖励
    let timestamp: Date?
    let version: Int // 缓存版本号
    
    // 为了兼容旧版本缓存
    init(credits: Int, rewards: [Reward], redemptions: [RedemptionRecord], coffeeRewards: [Reward]? = nil, membershipRewards: [Reward]? = nil, timestamp: Date?, version: Int = LocalCacheManager.redeemCacheVersion) {
        self.credits = credits
        self.rewards = rewards
        self.redemptions = redemptions
        self.coffeeRewards = coffeeRewards
        self.membershipRewards = membershipRewards
        self.timestamp = timestamp
        self.version = version
    }
}

struct ProfileDisplayView: View {
    @State var profile: BrewNetProfile
    @Binding var showSubscriptionPayment: Bool
    var onEditProfile: (() -> Void)?
    var onProfileUpdated: ((BrewNetProfile) -> Void)?
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    // State variables for matches and invitations
    @State private var showingMatches = false
    @State private var matches: [SupabaseMatch] = []
    @State private var isLoadingMatches = false
    
    @State private var showingSentInvitations = false
    @State private var sentInvitations: [SupabaseInvitation] = []
    @State private var isLoadingInvitations = false
    
    // State variable for showing profile card
    @State private var showingProfileCard = false
    @State private var showingPointsSystem = false
    @State private var showingRedemptionSystem = false
    @State private var showingCoffeeChatSchedule = false
    @State private var showingBoostPurchase = false
    
    // 头像同步定时器
    @State private var avatarSyncTimer: Timer?
    @State private var lastProfileImageURL: String? = nil // 跟踪上次的头像URL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header with new layout
                ProfileHeaderView(
                    profile: profile,
                    onEditProfile: onEditProfile,
                    onProfileUpdated: { updatedProfile in
                        profile = updatedProfile
                        // 同时调用父视图的回调，确保更新同步
                        onProfileUpdated?(updatedProfile)
                    },
                    onShowProfileCard: {
                        showingProfileCard = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Coffee Chat Schedule, Points System and Redemption System Buttons
                HStack(spacing: 12) {
                    // Coffee Chat Schedule Button
                    Button(action: {
                        showingCoffeeChatSchedule = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text("Chats")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.clear)
                        .cornerRadius(12)
                    }
                    
                    // Points System Button
                    Button(action: {
                        showingPointsSystem = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text("Credit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.clear)
                        .cornerRadius(12)
                    }
                    
                    // Redemption System Button
                    Button(action: {
                        showingRedemptionSystem = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text("Redeem")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.clear)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                if let currentUser = authManager.currentUser {
                    ProUpgradeCard(isProActive: currentUser.isProActive) {
                        showSubscriptionPayment = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Boost Card
                    BoostCard {
                        showingBoostPurchase = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMatches()
            loadSentInvitations()
            startAvatarSyncTimer()
            lastProfileImageURL = profile.coreIdentity.profileImage
        }
        .onDisappear {
            stopAvatarSyncTimer()
        }
        .onChange(of: profile.coreIdentity.profileImage) { newImageURL in
            // 当头像URL变化时，清除缓存
            if let oldURL = lastProfileImageURL, oldURL != newImageURL,
               oldURL.hasPrefix("http://") || oldURL.hasPrefix("https://") {
                ImageCacheManager.shared.removeImage(for: oldURL)
                print("🔄 [Profile] 头像URL变化，已清除旧缓存: \(oldURL)")
            }
            lastProfileImageURL = newImageURL
        }
        .sheet(isPresented: $showingMatches) {
            NavigationStack {
                MatchesListView(matches: matches, isLoading: isLoadingMatches)
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            }
        }
        .sheet(isPresented: $showingSentInvitations) {
            NavigationStack {
                SentInvitationsListView(invitations: sentInvitations, isLoading: isLoadingInvitations)
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            }
        }
        .sheet(isPresented: $showingProfileCard) {
            // 显示用户自己的 profile 卡片
            // 使用 isConnection: true 来显示 connections_only 的内容（因为是自己查看自己）
            // 但 private 的内容仍然不会显示（符合隐私设置）
            UserProfileCardSheetView(
                profile: profile,
                isConnection: true // 自己查看自己，所以 connections_only 的内容也应该显示
            )
        }
        .sheet(isPresented: $showingPointsSystem) {
            PointsSystemView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showingCoffeeChatSchedule) {
            CoffeeChatScheduleView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showingBoostPurchase) {
            BoostPurchaseView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
                .presentationDetents([.height(600)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingRedemptionSystem) {
            RedemptionSystemView()
                .environmentObject(authManager)
                .environmentObject(supabaseService)
        }
    }
    
    private func loadMatches() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingMatches = true
        Task {
            do {
                let fetchedMatches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                
                // 过滤掉自己（不应该出现在匹配列表中）
                let filteredMatches = fetchedMatches.filter { match in
                    // 确定对方用户ID
                    let otherUserId: String
                    if match.userId == currentUser.id {
                        otherUserId = match.matchedUserId
                    } else {
                        otherUserId = match.userId
                    }
                    
                    // 确保对方用户不是当前用户（防御性检查）
                    let isValid = otherUserId != currentUser.id && !otherUserId.isEmpty
                    
                    if !isValid {
                        print("⚠️ Filtering out invalid match: user_id=\(match.userId), matched_user_id=\(match.matchedUserId), currentUser=\(currentUser.id)")
                    }
                    
                    return isValid
                }
                
                // 去重：确保每个匹配用户只显示一次
                // 因为数据库中可能有两条记录（user_id=A,matched_user_id=B 和 user_id=B,matched_user_id=A）
                var seenUserIds = Set<String>()
                let uniqueMatches = filteredMatches.filter { match in
                    // 确定对方用户ID
                    let otherUserId: String
                    if match.userId == currentUser.id {
                        otherUserId = match.matchedUserId
                    } else {
                        otherUserId = match.userId
                    }
                    
                    // 如果这个用户已经处理过，跳过
                    if seenUserIds.contains(otherUserId) {
                        print("⚠️ Skipping duplicate match for user: \(otherUserId)")
                        return false
                    }
                    
                    seenUserIds.insert(otherUserId)
                    return true
                }
                
                await MainActor.run {
                    matches = uniqueMatches
                    isLoadingMatches = false
                    print("✅ Loaded \(uniqueMatches.count) unique matches (from \(fetchedMatches.count) total, after filtering \(filteredMatches.count))")
                }
            } catch {
                print("❌ Failed to load matches: \(error.localizedDescription)")
                await MainActor.run {
                    matches = []
                    isLoadingMatches = false
                }
            }
        }
    }
    
    // MARK: - Avatar Sync Timer
    /// 启动头像同步定时器（每5秒检查一次）
    private func startAvatarSyncTimer() {
        stopAvatarSyncTimer() // 先停止现有的定时器
        
        print("🔄 [Profile] 启动头像同步定时器（每5秒）")
        
        avatarSyncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                await syncProfileAvatar()
            }
        }
    }
    
    /// 停止头像同步定时器
    private func stopAvatarSyncTimer() {
        avatarSyncTimer?.invalidate()
        avatarSyncTimer = nil
    }
    
    /// 同步当前用户的头像（从数据库获取最新头像）
    @MainActor
    private func syncProfileAvatar() async {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [Profile同步] 没有当前用户，跳过同步")
            return
        }
        
        print("🔄 [Profile同步] 开始同步头像...")
        
        do {
            // 从数据库获取最新的 profile
            if let latestProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = latestProfile.toBrewNetProfile()
                let newImageURL = brewNetProfile.coreIdentity.profileImage
                let currentImageURL = profile.coreIdentity.profileImage
                
                // 检查头像是否有变化
                if newImageURL != currentImageURL {
                    print("🔄 [Profile同步] 检测到头像变化:")
                    print("   - 当前头像: \(currentImageURL ?? "nil")")
                    print("   - 新头像: \(newImageURL ?? "nil")")
                    
                    // 如果头像URL变化了，清除旧缓存
                    if let oldURL = currentImageURL, oldURL != newImageURL,
                       oldURL.hasPrefix("http://") || oldURL.hasPrefix("https://") {
                        ImageCacheManager.shared.removeImage(for: oldURL)
                        print("   🗑️ [Profile同步] 已清除旧头像缓存: \(oldURL)")
                    }
                    
                    // 即使URL相同，也清除缓存以确保显示最新图片
                    if newImageURL == currentImageURL && newImageURL != nil,
                       (newImageURL?.hasPrefix("http://") == true || newImageURL?.hasPrefix("https://") == true) {
                        ImageCacheManager.shared.removeImage(for: newImageURL!)
                        print("   🔄 [Profile同步] 头像URL相同但强制刷新缓存: \(newImageURL!)")
                    }
                    
                    // 更新 profile（创建新的实例，因为所有属性都是 let）
                    let updatedProfile = BrewNetProfile(
                        id: profile.id,
                        userId: profile.userId,
                        createdAt: profile.createdAt,
                        updatedAt: brewNetProfile.updatedAt, // 使用最新的更新时间
                        coreIdentity: brewNetProfile.coreIdentity, // 使用最新的 coreIdentity（包含新头像）
                        professionalBackground: profile.professionalBackground,
                        networkingIntention: profile.networkingIntention,
                        networkingPreferences: profile.networkingPreferences,
                        personalitySocial: profile.personalitySocial,
                        workPhotos: profile.workPhotos,
                        lifestylePhotos: profile.lifestylePhotos,
                        privacyTrust: profile.privacyTrust
                    )
                    profile = updatedProfile
                    lastProfileImageURL = newImageURL
                    
                    // 调用回调通知父视图
                    onProfileUpdated?(updatedProfile)
                    
                    print("✅ [Profile同步] 头像已更新")
                } else {
                    // 即使URL相同，也清除缓存以确保显示最新图片（可能图片内容已更新）
                    if let imageURL = newImageURL, imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://") {
                        ImageCacheManager.shared.removeImage(for: imageURL)
                        print("🔄 [Profile同步] 强制刷新头像缓存: \(imageURL)")
                    }
                }
            } else {
                print("⚠️ [Profile同步] 无法获取最新 profile")
            }
        } catch {
            print("⚠️ [Profile同步] 同步失败: \(error.localizedDescription)")
        }
    }
    
    private func loadSentInvitations() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingInvitations = true
        Task {
            do {
                let fetchedInvitations = try await supabaseService.getSentInvitations(userId: currentUser.id)
                
                // 去重：对于同一个 receiver_id，只保留最新的邀请
                var uniqueInvitations: [SupabaseInvitation] = []
                var seenReceiverIds: Set<String> = []
                
                // 按创建时间排序，最新的在前
                let sortedInvitations = fetchedInvitations.sorted { inv1, inv2 in
                    let date1 = ISO8601DateFormatter().date(from: inv1.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: inv2.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
                
                // 只保留每个 receiver_id 的第一个（最新的）
                for invitation in sortedInvitations {
                    if !seenReceiverIds.contains(invitation.receiverId) {
                        uniqueInvitations.append(invitation)
                        seenReceiverIds.insert(invitation.receiverId)
                    }
                }
                
                await MainActor.run {
                    sentInvitations = uniqueInvitations
                    isLoadingInvitations = false
                    print("✅ Loaded \(uniqueInvitations.count) unique sent invitations (removed \(fetchedInvitations.count - uniqueInvitations.count) duplicates)")
                }
            } catch {
                print("❌ Failed to load sent invitations: \(error.localizedDescription)")
                await MainActor.run {
                    sentInvitations = []
                    isLoadingInvitations = false
                }
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let profile: BrewNetProfile
    var onEditProfile: (() -> Void)?
    var onProfileUpdated: ((BrewNetProfile) -> Void)?
    var onShowProfileCard: (() -> Void)?
    
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingImage = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    
    // 计算资料完成度百分比
    private var profileCompletionPercentage: Int {
        var completedFields = 0
        var totalFields = 0
        
        // Core Identity
        totalFields += 4
        if !profile.coreIdentity.name.isEmpty { completedFields += 1 }
        if !profile.coreIdentity.email.isEmpty { completedFields += 1 }
        if profile.coreIdentity.profileImage != nil { completedFields += 1 }
        if profile.coreIdentity.bio != nil && !profile.coreIdentity.bio!.isEmpty { completedFields += 1 }
        
        // Professional Background
        totalFields += 2
        if profile.professionalBackground.currentCompany != nil { completedFields += 1 }
        if profile.professionalBackground.jobTitle != nil { completedFields += 1 }
        
        // Education
        totalFields += 1
        if profile.professionalBackground.education != nil && !profile.professionalBackground.education!.isEmpty { completedFields += 1 }
        
        guard totalFields > 0 else { return 0 }
        return Int((Double(completedFields) / Double(totalFields)) * 100)
    }
    
    // MARK: - View Components
    @ViewBuilder
    private var avatarWithProgressView: some View {
        ZStack {
            // Progress Circle (outer, red)
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                .frame(width: 100, height: 100)
            
            // Progress Circle (filled portion, red)
            Circle()
                .trim(from: 0, to: CGFloat(profileCompletionPercentage) / 100)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
            
            // Profile Image (inner) - 使用 AvatarView 以便更好地控制缓存
            Group {
                if let imageURL = profile.coreIdentity.profileImage, !imageURL.isEmpty {
                    AvatarView(avatarString: imageURL, size: 84)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .id("profile-avatar-\(profile.coreIdentity.profileImage ?? "nil")")
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            
            // Percentage badge at bottom
            VStack {
                Spacer()
                Text("\(profileCompletionPercentage)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white)
                    .cornerRadius(8)
                    .offset(y: 5)
            }
            .frame(width: 100, height: 100)
        }
    }
    
    @ViewBuilder
    private var nameAndIconsView: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Name
            HStack(spacing: 4) {
                Text(profile.coreIdentity.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.black)
                
                if authManager.currentUser?.isPro == true {
                    ProBadge(size: .medium)
                }
            }
            
            // Icons row
            HStack(spacing: 12) {
                // Camera icon (blue) - 可点击更换头像
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        if isUploadingImage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                }
                
                // Verification icon (grey)
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    @ViewBuilder
    private var companyTitleView: some View {
        HStack {
            // 优先显示公司，如果没有则显示学校
            if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                    Text("\(company) · \(jobTitle)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(company)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else if let education = profile.professionalBackground.education, !education.isEmpty {
                // 如果没有公司，显示学校
                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                    Text("\(education) · \(jobTitle)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(education)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } else {
                // 如果都没有，显示占位符
                Text("Complete Your Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .cornerRadius(12)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                onShowProfileCard?()
            }) {
                HStack(alignment: .top, spacing: 16) {
                    avatarWithProgressView
                    
                    VStack(alignment: .leading, spacing: 8) {
                        nameAndIconsView
                        //companyTitleView
                    }
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(Color.white)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                guard let newItem = newItem else { return }
                
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        isUploadingImage = true
                    }
                    
                    // Upload image to Supabase Storage
                    if let userId = authManager.currentUser?.id {
                        do {
                            print("📤 Uploading profile image...")
                            
                            // Detect file extension from data or use jpg as default
                            let fileExtension = detectImageFormat(from: data) ?? "jpg"
                            
                            // Upload to Supabase Storage
                            let publicURL = try await supabaseService.uploadProfileImage(
                                userId: userId,
                                imageData: data,
                                fileExtension: fileExtension
                            )
                            
                            // Update profile with new image URL
                            let updatedCoreIdentity = CoreIdentity(
                                name: profile.coreIdentity.name,
                                email: profile.coreIdentity.email,
                                phoneNumber: profile.coreIdentity.phoneNumber,
                                profileImage: publicURL,
                                bio: profile.coreIdentity.bio,
                                pronouns: profile.coreIdentity.pronouns,
                                location: profile.coreIdentity.location,
                                personalWebsite: profile.coreIdentity.personalWebsite,
                                githubUrl: profile.coreIdentity.githubUrl,
                                linkedinUrl: profile.coreIdentity.linkedinUrl,
                                timeZone: profile.coreIdentity.timeZone
                            )
                            
                            // Create updated profile
                            let updatedProfile = BrewNetProfile(
                                id: profile.id,
                                userId: profile.userId,
                                createdAt: profile.createdAt,
                                updatedAt: ISO8601DateFormatter().string(from: Date()),
                                coreIdentity: updatedCoreIdentity,
                                professionalBackground: profile.professionalBackground,
                                networkingIntention: profile.networkingIntention,
                                networkingPreferences: profile.networkingPreferences,
                                personalitySocial: profile.personalitySocial,
                                workPhotos: profile.workPhotos,
                                lifestylePhotos: profile.lifestylePhotos,
                                privacyTrust: profile.privacyTrust
                            )
                            
                            // Update in Supabase
                            let supabaseProfile = SupabaseProfile(
                                id: profile.id,
                                userId: profile.userId,
                                coreIdentity: updatedCoreIdentity,
                                professionalBackground: profile.professionalBackground,
                                networkingIntention: profile.networkingIntention,
                                networkingPreferences: profile.networkingPreferences,
                                personalitySocial: profile.personalitySocial,
                                workPhotos: profile.workPhotos,
                                lifestylePhotos: profile.lifestylePhotos,
                                privacyTrust: profile.privacyTrust,
                                createdAt: profile.createdAt,
                                updatedAt: ISO8601DateFormatter().string(from: Date())
                            )
                            
                            // Update in Supabase database
                            let updatedSupabaseProfile = try await supabaseService.updateProfile(profileId: profile.id, profile: supabaseProfile)
                            print("✅ Profile updated in database successfully")
                            
                            // Verify the update by reloading from database
                            if let verifiedProfile = try? await supabaseService.getProfile(userId: profile.userId) {
                                let verifiedBrewNetProfile = verifiedProfile.toBrewNetProfile()
                                print("✅ Verified profile update from database, new image URL: \(verifiedBrewNetProfile.coreIdentity.profileImage ?? "nil")")
                            
                            await MainActor.run {
                                isUploadingImage = false
                                    // Update with verified profile from database
                                    onProfileUpdated?(verifiedBrewNetProfile)
                                    showSuccessAlert = true
                                print("✅ Profile image uploaded and updated successfully: \(publicURL)")
                                // Post notification to refresh profile
                                NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                                }
                            } else {
                                // If verification fails, still update with what we have
                                await MainActor.run {
                                    isUploadingImage = false
                                    onProfileUpdated?(updatedProfile)
                                    showSuccessAlert = true
                                    print("✅ Profile image uploaded and updated (verification skipped): \(publicURL)")
                                    NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                isUploadingImage = false
                                errorMessage = "Failed to update profile image: \(error.localizedDescription)"
                                showErrorAlert = true
                                print("❌ Failed to upload profile image: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Profile image updated successfully!")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // Helper function to detect image format from data
    private func detectImageFormat(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        // Check for JPEG
        if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
            return "jpg"
        }
        
        // Check for PNG
        if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return "png"
        }
        
        // Check for GIF
        if String(data: data.prefix(6), encoding: .ascii) == "GIF89a" || String(data: data.prefix(6), encoding: .ascii) == "GIF87a" {
            return "gif"
        }
        
        return nil
    }
}

// MARK: - Profile Section Container
struct ProfileSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Pro Upgrade Card
struct ProUpgradeCard: View {
    let isProActive: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ProBadge(size: .medium)
                        Text(isProActive ? "Thank you for being Pro" : "Upgrade")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    
                    Text("Match faster\nConnect smarter\nGrow further")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                }
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
            }
            
            Button(action: action) {
                Text(isProActive ? "Manage BrewNet Pro" : "Get BrewNet Pro")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.0),
                                Color(red: 1.0, green: 0.65, blue: 0.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.85, blue: 0.7).opacity(0.35),
                    Color(red: 0.85, green: 0.75, blue: 0.6).opacity(0.35)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.5),
                            Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Boost Card (条状设计)
struct BoostCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 左侧圆形图标
                ZStack {
                    Circle()
                        .fill(Color(red: 0.4, green: 0.5, blue: 0.5))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // 小圆圈显示数量（可选）
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("0")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.5))
                        )
                        .offset(x: 18, y: -18)
                }
                
                // 中间文本
                VStack(alignment: .leading, spacing: 2) {
                    Text("Boost")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Get seen by 11X more people")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Boost Purchase View
struct BoostPurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var selectedBoostIndex: Int = 0
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let boostOptions = [
        BoostOption(
            title: "Superboost",
            duration: "24 hours",
            price: "$29.99",
            multiplier: "33x",
            description: "Get noticed by 33x more people. Maximize your profile's visibility around the clock.",
            isSuperboost: true
        ),
        BoostOption(
            title: "5 Boosts",
            duration: "each",
            price: "$7.99",
            totalPrice: "$39.99",
            multiplier: "11x",
            description: "Elevate your profile 11x more with one-hour boosts. Use each one at any time.",
            savePercentage: "20%"
        ),
        BoostOption(
            title: "3 Boosts",
            duration: "each",
            price: "$8.99",
            totalPrice: "$26.99",
            multiplier: "11x",
            description: "Stand out 11x more with one-hour boosts. Use each one at any time.",
            savePercentage: "10%"
        ),
        BoostOption(
            title: "1 Boost",
            duration: nil,
            price: "$9.99",
            multiplier: "11x",
            description: "Show your profile to 11x more people for one hour.",
            savePercentage: nil
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Boost your profile for\nmore views")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            // Boost Options Carousel
            TabView(selection: $selectedBoostIndex) {
                ForEach(0..<boostOptions.count, id: \.self) { index in
                    BoostOptionCard(option: boostOptions[index])
                        .tag(index)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 320)
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            
            Spacer()
                .frame(height: 8)
            
            // Purchase Buttons
            VStack(spacing: 12) {
                Button(action: {
                    handlePurchase(option: boostOptions[selectedBoostIndex])
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            if let totalPrice = boostOptions[selectedBoostIndex].totalPrice {
                                Text("Get \(boostOptions[selectedBoostIndex].title.lowercased()) for \(totalPrice)")
                            } else if boostOptions[selectedBoostIndex].isSuperboost {
                                Text("Superboost for \(boostOptions[selectedBoostIndex].price)")
                            } else {
                                Text("Get \(boostOptions[selectedBoostIndex].title.lowercased()) for \(boostOptions[selectedBoostIndex].price)")
                            }
                        }
                    }
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Color(red: 0.4, green: 0.5, blue: 0.5)
                )
                .cornerRadius(28)
                .disabled(isProcessing)
                
                Button(action: {
                    // Handle App Store purchase
                }) {
                    Text("Purchase with App Store")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .ignoresSafeArea(edges: .bottom)
        .alert("Purchase Status", isPresented: $showError) {
            Button("OK", role: .cancel) {
                if !errorMessage.contains("Failed") {
                    dismiss()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handlePurchase(option: BoostOption) {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                // Determine how many boosts to add
                var boostCount = 0
                var superboostCount = 0
                
                if option.isSuperboost {
                    superboostCount = 1
                } else if option.title.contains("5") {
                    boostCount = 5
                } else if option.title.contains("3") {
                    boostCount = 3
                } else if option.title.contains("1") {
                    boostCount = 1
                }
                
                // Fetch current counts
                struct BoostData: Codable {
                    let boost_count: Int?
                    let superboost_count: Int?
                }
                
                let currentData: BoostData = try await SupabaseConfig.shared.client
                    .from("users")
                    .select("boost_count, superboost_count")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                let currentBoostCount = currentData.boost_count ?? 0
                let currentSuperboostCount = currentData.superboost_count ?? 0
                
                // Create update struct
                struct BoostCountUpdate: Encodable {
                    let boost_count: Int
                    let superboost_count: Int
                }
                
                let updateData = BoostCountUpdate(
                    boost_count: currentBoostCount + boostCount,
                    superboost_count: currentSuperboostCount + superboostCount
                )
                
                // Update counts
                try await SupabaseConfig.shared.client
                    .from("users")
                    .update(updateData)
                    .eq("id", value: userId)
                    .execute()
                
                await MainActor.run {
                    isProcessing = false
                    if option.isSuperboost {
                        errorMessage = "Successfully purchased 1 Superboost!"
                    } else {
                        errorMessage = "Successfully purchased \(option.title)!"
                    }
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to complete purchase: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Boost Option Model
struct BoostOption {
    let title: String
    let duration: String?
    let price: String
    var totalPrice: String? = nil
    let multiplier: String
    let description: String
    var savePercentage: String? = nil
    var isSuperboost: Bool = false
}

// MARK: - Boost Option Card
struct BoostOptionCard: View {
    let option: BoostOption
    
    var body: some View {
        VStack(spacing: 0) {
            // Save Badge (if applicable)
            if let savePercentage = option.savePercentage {
                Text("Save \(savePercentage)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.4, green: 0.5, blue: 0.5))
                    .cornerRadius(12)
                    .padding(.top, 2)
                    .zIndex(1)
            }
            
            VStack(spacing: 8) {
                // Icon
                Image(systemName: "bolt.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.5))
                    .padding(.top, option.savePercentage != nil ? 2 : 8)
                
                // Title
                Text(option.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                // Price
                if let duration = option.duration {
                    if option.isSuperboost {
                        Text("\(option.price) for \(duration)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(option.price) \(duration)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(option.price)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // Description
                Text(option.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 12)
        }
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 0.4, green: 0.5, blue: 0.5), lineWidth: 2)
        )
    }
}

// MARK: - Core Identity Display
struct CoreIdentityDisplayView: View {
    let identity: CoreIdentity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let pronouns = identity.pronouns {
                InfoRow(label: "Pronouns", value: pronouns)
            }
            
            InfoRow(label: "Email", value: identity.email)
            
            if let phoneNumber = identity.phoneNumber {
                InfoRow(label: "Phone", value: phoneNumber)
            }
            
            InfoRow(label: "Time Zone", value: identity.timeZone)
        }
    }
}

// MARK: - Professional Background Display
struct ProfessionalBackgroundDisplayView: View {
    let background: ProfessionalBackground
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let industry = background.industry {
                InfoRow(label: "Industry", value: industry)
            }
            
            InfoRow(label: "Experience Level", value: background.experienceLevel.displayName)
            
            if let years = background.yearsOfExperience {
                InfoRow(label: "Years of Experience", value: "\(years) years")
            }
            
            InfoRow(label: "Career Stage", value: background.careerStage.displayName)
            
            if let education = background.education {
                InfoRow(label: "Education", value: education)
            }
            
            if !background.skills.isEmpty {
                SkillsDisplayView(skills: background.skills)
            }
            
            if !background.certifications.isEmpty {
                CertificationsDisplayView(certifications: background.certifications)
            }
            
            if !background.languagesSpoken.isEmpty {
                LanguagesDisplayView(languages: background.languagesSpoken)
            }
        }
    }
}

// MARK: - Networking Intention Display
struct NetworkingIntentionDisplayView: View {
    let intention: NetworkingIntention
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Main Intention", value: intention.selectedIntention.displayName)
            
            if let careerDirection = intention.careerDirection {
                CareerDirectionDisplayView(data: careerDirection)
            }
            
            if let skillDevelopment = intention.skillDevelopment {
                SkillDevelopmentDisplayView(data: skillDevelopment)
            }
            
            if let industryTransition = intention.industryTransition {
                IndustryTransitionDisplayView(data: industryTransition)
            }
        }
    }
}

// MARK: - Career Direction Display
struct CareerDirectionDisplayView: View {
    let data: CareerDirectionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Career Direction")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.functions, id: \.functionName) { function in
                VStack(alignment: .leading, spacing: 4) {
                    Text(function.functionName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if !function.learnIn.isEmpty {
                        Text("Learn in: \(function.learnIn.joined(separator: ", "))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if !function.guideIn.isEmpty {
                        Text("Guide in: \(function.guideIn.joined(separator: ", "))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Skill Development Display
struct SkillDevelopmentDisplayView: View {
    let data: SkillDevelopmentData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.skills, id: \.skillName) { skill in
                HStack {
                    Text(skill.skillName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if skill.learnIn {
                        Text("Learn")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if skill.guideIn {
                        Text("Guide")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

// MARK: - Industry Transition Display
struct IndustryTransitionDisplayView: View {
    let data: IndustryTransitionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Industries")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.industries, id: \.industryName) { industry in
                HStack {
                    Text(industry.industryName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if industry.learnIn {
                        Text("Learn")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if industry.guideIn {
                        Text("Guide")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

// MARK: - Personality & Social Display
struct PersonalitySocialDisplayView: View {
    let personality: PersonalitySocial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !personality.valuesTags.isEmpty {
                TagsDisplayView(
                    title: "Values",
                    tags: personality.valuesTags
                )
            }
            
            if !personality.hobbies.isEmpty {
                TagsDisplayView(
                    title: "Hobbies & Interests",
                    tags: personality.hobbies
                )
            }
            
        }
    }
}

// MARK: - Privacy & Trust Display
struct PrivacyTrustDisplayView: View {
    let privacy: PrivacyTrust
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Data Sharing", value: privacy.dataSharingConsent ? "Enabled" : "Disabled")
            InfoRow(label: "Verification Status", value: privacy.verifiedStatus.displayName)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Visibility Settings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                VStack(alignment: .leading, spacing: 4) {
                    VisibilityRow(label: "Company", level: privacy.visibilitySettings.company)
                    VisibilityRow(label: "Email", level: privacy.visibilitySettings.email)
                    VisibilityRow(label: "Phone", level: privacy.visibilitySettings.phoneNumber)
                    VisibilityRow(label: "Location", level: privacy.visibilitySettings.location)
                    VisibilityRow(label: "Skills", level: privacy.visibilitySettings.skills)
                    VisibilityRow(label: "Interests", level: privacy.visibilitySettings.interests)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Spacer()
        }
    }
}

struct TagsDisplayView: View {
    let title: String
    let tags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct SkillsDisplayView: View {
    let skills: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.2, green: 0.6, blue: 0.8))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct CertificationsDisplayView: View {
    let certifications: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certifications")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(certifications, id: \.self) { cert in
                    Text(cert)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.8, green: 0.4, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct LanguagesDisplayView: View {
    let languages: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Languages")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(languages, id: \.self) { language in
                    Text(language)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.4, green: 0.6, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct VisibilityRow: View {
    let label: String
    let level: VisibilityLevel
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(level.displayName)
                .font(.system(size: 12))
                .foregroundColor(level == .public_ ? .green : level == .connectionsOnly ? .orange : .red)
            
            Spacer()
        }
    }
}

// MARK: - Matches List View
struct MatchesListView: View {
    let matches: [SupabaseMatch]
    let isLoading: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if matches.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text("No Matches Yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("Start sending invitations to find your matches!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                List {
                    ForEach(matches) { match in
                        MatchRowView(match: match)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("My Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
    }
}

// MARK: - Match Row View
struct MatchRowView: View {
    let match: SupabaseMatch
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @State private var matchedUserProfile: BrewNetProfile?
    
    // 确定应该显示的用户ID和名称
    private var displayUserId: String {
        guard let currentUser = authManager.currentUser else {
            return match.matchedUserId
        }
        // 如果当前用户是 user_id，则显示 matched_user_id
        // 如果当前用户是 matched_user_id，则显示 user_id
        if match.userId == currentUser.id {
            return match.matchedUserId
        } else {
            return match.userId
        }
    }
    
    private var displayUserName: String {
        if let profile = matchedUserProfile {
            return profile.coreIdentity.name
        }
        // 如果还没加载到 profile，使用匹配记录中的名称
        guard let currentUser = authManager.currentUser else {
            return match.matchedUserName
        }
        // 如果当前用户是 user_id，matched_user_name 就是对方的名字
        if match.userId == currentUser.id {
            return match.matchedUserName
        } else {
            // 如果当前用户是 matched_user_id，matched_user_name 是当前用户的名字
            // 需要返回 user_id 对应的用户名，但我们暂时返回一个占位符
            return "Loading..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayUserName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(match.matchType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                if let createdAt = parseDate(match.createdAt) {
                    Text("Matched \(formatDate(createdAt))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Match indicator
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
        }
        .padding(.vertical, 8)
        .onAppear {
            loadMatchedUserProfile()
        }
    }
    
    private func loadMatchedUserProfile() {
        Task {
            // 加载应该显示的用户信息
            if let profile = try? await supabaseService.getProfile(userId: displayUserId) {
                await MainActor.run {
                    matchedUserProfile = profile.toBrewNetProfile()
                }
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sent Invitations List View
struct SentInvitationsListView: View {
    let invitations: [SupabaseInvitation]
    let isLoading: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if invitations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text("No Sent Invitations")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("Start exploring and send invitations to connect!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                List {
                    ForEach(invitations) { invitation in
                        SentInvitationRowView(invitation: invitation)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Sent Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
    }
}

// MARK: - Sent Invitation Row View
struct SentInvitationRowView: View {
    let invitation: SupabaseInvitation
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var receiverProfile: BrewNetProfile?
    @State private var showingProfileCard = false
    
    var body: some View {
        Button(action: {
            if receiverProfile != nil {
                showingProfileCard = true
            }
        }) {
            HStack(spacing: 12) {
                // Avatar - 加载真实的用户头像
                Group {
                    if let profileImageURL = receiverProfile?.coreIdentity.profileImage, !profileImageURL.isEmpty {
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
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            @unknown default:
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(receiverProfile?.coreIdentity.name ?? "Loading...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(invitation.status.rawValue.capitalized)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    if let createdAt = parseDate(invitation.createdAt) {
                        Text("Sent \(formatDate(createdAt))")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadReceiverProfile()
        }
        .sheet(isPresented: $showingProfileCard) {
            if let profile = receiverProfile {
                PublicProfileView(profile: profile)
                    .environmentObject(supabaseService)
            }
        }
    }
    
    private var statusColor: Color {
        switch invitation.status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch invitation.status {
        case .pending:
            return "clock.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    private func loadReceiverProfile() {
        Task {
            if let profile = try? await supabaseService.getProfile(userId: invitation.receiverId) {
                await MainActor.run {
                    receiverProfile = profile.toBrewNetProfile()
                }
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Public Profile View (Read-only view for viewing other users' profiles)
struct PublicProfileView: View {
    let profile: BrewNetProfile
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            // Use unified PublicProfileCardView
            PublicProfileCardView(profile: profile)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
        }
    }
}

// MARK: - Public Professional Background Display View
struct PublicProfessionalBackgroundDisplayView: View {
    let background: ProfessionalBackground
    let visibilitySettings: VisibilitySettings
    
    // Helper to check if a field should be visible based on privacy settings
    private func isVisible(_ visibilityLevel: VisibilityLevel) -> Bool {
        return visibilityLevel == .public_
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only show skills if public
            if isVisible(visibilitySettings.skills) && !background.skills.isEmpty {
                SkillsDisplayView(skills: background.skills)
            }
            
            // Note: Other fields like industry, experience level, career stage, etc.
            // don't have individual privacy controls, so we can show them
            if let industry = background.industry {
                InfoRow(label: "Industry", value: industry)
            }
            
            InfoRow(label: "Experience Level", value: background.experienceLevel.displayName)
            
            if let years = background.yearsOfExperience {
                InfoRow(label: "Years of Experience", value: "\(years) years")
            }
            
            InfoRow(label: "Career Stage", value: background.careerStage.displayName)
            
            if let education = background.education {
                InfoRow(label: "Education", value: education)
            }
            
            if !background.certifications.isEmpty {
                CertificationsDisplayView(certifications: background.certifications)
            }
            
            if !background.languagesSpoken.isEmpty {
                LanguagesDisplayView(languages: background.languagesSpoken)
            }
        }
    }
}

// MARK: - Public Profile Header View
struct PublicProfileHeaderView: View {
    let profile: BrewNetProfile
    
    // Helper to check if a field should be visible based on privacy settings
    private func isVisible(_ visibilityLevel: VisibilityLevel) -> Bool {
        return visibilityLevel == .public_
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Avatar on left, Name on right
            HStack(alignment: .top, spacing: 16) {
                // Left: Profile Image
                ZStack {
                    AsyncImage(url: URL(string: profile.coreIdentity.profileImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                }
                
                // Right: Name and basic info
                VStack(alignment: .leading, spacing: 8) {
                    // Name (always visible)
                    HStack(spacing: 4) {
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    // Pronouns (always visible)
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Location (only if public)
                    if isVisible(profile.privacyTrust.visibilitySettings.location),
                       let location = profile.coreIdentity.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Company/School and Title button (only if company is public)
                    if isVisible(profile.privacyTrust.visibilitySettings.company) {
                        HStack {
                            // 优先显示公司，如果没有则显示学校
                            if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                                Text(company)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            } else if let education = profile.professionalBackground.education, !education.isEmpty {
                                // 如果没有公司，显示学校
                                Text(education)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.white)
        .onAppear {
            print("🌍 显示公开 Profile: \(profile.coreIdentity.name)")
        }
    }
}

// MARK: - User Profile Card Sheet View
struct UserProfileCardSheetView: View {
    let profile: BrewNetProfile
    let isConnection: Bool // Whether the current user is connected to this profile
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedWorkExperience: WorkExperience?
    
    // Verify privacy settings are loaded from database
    private var privacySettings: VisibilitySettings {
        let settings = profile.privacyTrust.visibilitySettings
        // Log privacy settings for debugging
        print("🔒 Profile Page Privacy Settings for \(profile.coreIdentity.name):")
        print("   - company: \(settings.company.rawValue) -> visible: \(settings.company.isVisible(isConnection: isConnection))")
        print("   - skills: \(settings.skills.rawValue) -> visible: \(settings.skills.isVisible(isConnection: isConnection))")
        print("   - interests: \(settings.interests.rawValue) -> visible: \(settings.interests.isVisible(isConnection: isConnection))")
        print("   - location: \(settings.location.rawValue) -> visible: \(settings.location.isVisible(isConnection: isConnection))")
        print("   - timeslot: \(settings.timeslot.rawValue) -> visible: \(settings.timeslot.isVisible(isConnection: isConnection))")
        print("   - isConnection: \(isConnection)")
        return settings
    }
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .frame(width: screenWidth - 40, height: screenHeight * 0.85)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Level 1: Core Information Area
                        level1CoreInfoView
                        
                        // Level 2: Matching Clues
                        level2MatchingCluesView
                        
                        // Level 3: Deep Understanding
                        level3DeepUnderstandingView
                    }
                    .frame(maxWidth: screenWidth - 40)
                }
                .frame(height: screenHeight * 0.85)
                .cornerRadius(20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedWorkExperience) { workExp in
            WorkExperienceDetailSheet(
                workExperience: workExp,
                allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                industry: profile.professionalBackground.industry
            )
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
                    // Name - 独立换行
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .lineLimit(nil)
                    
                    // Pronouns - 独立一行
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Headline / Bio
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                    }
                }
                
                Spacer()
            }
            
            // Professional Info (only if company visibility is public or connections_only)
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
        .background(Color.clear)
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
            
            // Skills (only if public or connections_only)
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
            
            // Hobbies & Interests (only if public or connections_only)
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
        .background(Color.clear)
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
                        Button {
                            selectedWorkExperience = workExp
                        } label: {
                            WorkExperienceRowView(workExp: workExp)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
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
            
            // Location (only if public or connections_only)
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
        .background(Color.clear)
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
}

// Note: NetworkingIntentionBadgeView, WorkExperienceRowView, and FlowLayout are defined in UserProfileCardView.swift
// They are reused here to avoid code duplication

// MARK: - Points System View
struct PointsSystemView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var totalCredits: Int = 0
    @State private var coffeeChatHistory: [CoffeeChatRecord] = []
    @State private var isLoading = true
    
    // Cached data to improve performance
    @State private var cachedHistory: [CoffeeChatRecord] = []
    @State private var lastHistoryHash: Int = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Credits Display Card
                            VStack(spacing: 16) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                
                                Text("Total Credits")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("\(totalCredits)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            
                            // Coffee Chat History
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Coffee Chat History")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                if cachedHistory.isEmpty {
                                    VStack(spacing: 12) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray.opacity(0.5))
                                        Text("No Coffee Chats completed yet")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    LazyVStack(spacing: 12) {
                                        ForEach(cachedHistory) { record in
                                            CoffeeChatRecordRow(record: record)
                                                .environmentObject(supabaseService)
                                                .id("credit-record-\(record.id)")
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            
                            // Credit Rules
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Credit Rules")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    PointsRuleRow(icon: "checkmark.circle.fill", text: "Complete an in-person Coffee Chat to earn 10 credits")
                                    PointsRuleRow(icon: "checkmark.circle.fill", text: "Both parties need to confirm the meeting completion")
                                    PointsRuleRow(icon: "checkmark.circle.fill", text: "Credits can be used to redeem coffee coupons or other gifts")
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Credit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            .onAppear {
                // 先加载本地缓存，立即显示
                loadCachedData()
                // 然后在后台加载最新数据
                loadPointsData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CoffeeChatScheduleUpdated"))) { _ in
                print("🔄 [Credit] 收到日程更新通知，重新加载")
                loadPointsData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserCreditsUpdated"))) { _ in
                print("🔄 [Credit] 收到积分更新通知，重新加载")
                loadPointsData()
            }
            .onChange(of: coffeeChatHistory) { newHistory in
                // Update cache when history changes
                let newHash = newHistory.map { $0.id }.joined().hashValue
                if newHash != lastHistoryHash {
                    cachedHistory = newHistory
                    lastHistoryHash = newHash
                }
            }
        }
    }
    
    private func loadCachedData() {
        guard let currentUser = authManager.currentUser else { return }
        
        // 从本地缓存加载数据
        if let cached = LocalCacheManager.shared.loadCreditData(userId: currentUser.id) {
            totalCredits = cached.credits
            coffeeChatHistory = cached.history
            cachedHistory = cached.history
            isLoading = false
            print("✅ [Credit] 已从缓存加载数据：积分 = \(cached.credits), 记录数 = \(cached.history.count)")
        }
    }
    
    private func loadPointsData() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        // 如果没有缓存，显示 loading
        if cachedHistory.isEmpty {
            isLoading = true
        }
        
        Task {
            do {
                // 从数据库获取 credits
                let credits = try await supabaseService.getUserCredits(userId: currentUser.id)
                print("✅ [Credit] 从数据库获取 credits: \(credits)")
                
                // 获取所有已 met 的 coffee chat schedules（用于显示历史记录）
                let allSchedules = try await supabaseService.getCoffeeChatSchedules(userId: currentUser.id)
                let metSchedules = allSchedules.filter { $0.hasMet }
                
                print("✅ [Credit] 找到 \(metSchedules.count) 个已 met 的 coffee chat")
                
                // 转换为 CoffeeChatRecord 并获取头像
                // 使用 Set 来去重，确保同一个 schedule 只显示一次
                var seenScheduleIds = Set<String>()
                var records: [CoffeeChatRecord] = []
                
                for schedule in metSchedules {
                    // 使用 schedule.id 作为唯一标识符去重
                    let scheduleIdString = schedule.id.uuidString
                    if seenScheduleIds.contains(scheduleIdString) {
                        print("⚠️ [Credit] 跳过重复的 schedule: \(scheduleIdString)")
                        continue
                    }
                    seenScheduleIds.insert(scheduleIdString)
                    
                    // 获取参与者头像
                    var avatarURL: String? = nil
                    if let profile = try? await supabaseService.getProfile(userId: schedule.participantId) {
                        avatarURL = profile.coreIdentity.profileImage
                    }
                    
                    let record = CoffeeChatRecord(
                        id: scheduleIdString,
                        partnerId: schedule.participantId,
                        partnerName: schedule.participantName,
                        partnerAvatar: avatarURL,
                        date: schedule.scheduledDate,
                        pointsEarned: 10, // 每个已 met 的 coffee chat = 10 积分
                        status: .completed
                    )
                    records.append(record)
                    print("✅ [Credit] 添加记录: \(schedule.participantName), scheduleId: \(scheduleIdString)")
                }
                
                // 按日期排序（最新的在前）
                records.sort { $0.date > $1.date }
                
                await MainActor.run {
                    totalCredits = credits // 使用数据库中的 credits
                    coffeeChatHistory = records
                    
                    // Update cache only if data changed
                    let newHash = records.map { $0.id }.joined().hashValue
                    if newHash != lastHistoryHash {
                        cachedHistory = records
                        lastHistoryHash = newHash
                    }
                    
                    // 保存到本地缓存
                    LocalCacheManager.shared.saveCreditData(
                        userId: currentUser.id,
                        credits: credits,
                        history: records
                    )
                    
                    isLoading = false
                    print("✅ [Credit] 加载完成：总积分 = \(credits), 记录数 = \(records.count)")
                }
            } catch {
                print("❌ Failed to load points data: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Coffee Chat Record
struct CoffeeChatRecord: Identifiable, Codable, Equatable {
    let id: String
    let partnerId: String
    let partnerName: String
    let partnerAvatar: String?
    let date: Date
    let pointsEarned: Int
    let status: CoffeeChatStatus
    
    enum CoffeeChatStatus: String, Codable, Equatable {
        case completed = "completed"
        case pending = "pending"
    }
}

// MARK: - Coffee Chat Record Row
struct CoffeeChatRecordRow: View {
    let record: CoffeeChatRecord
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var avatarURL: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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
                    .frame(width: 50, height: 50)
                
                if let avatar = avatarURL ?? record.partnerAvatar, !avatar.isEmpty {
                    AvatarView(avatarString: avatar, size: 46)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 46))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Coffee Chat with \(record.partnerName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                HStack(spacing: 6) {
                    Text(formatDate(record.date))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if record.status == .completed {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.3))
                            Text("Met")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.3))
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    Text("+\(record.pointsEarned)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
                
                if record.status == .pending {
                    Text("Pending")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .cornerRadius(12)
        .onAppear {
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        if avatarURL == nil && record.partnerAvatar == nil {
            Task {
                if let profile = try? await supabaseService.getProfile(userId: record.partnerId) {
                    await MainActor.run {
                        avatarURL = profile.coreIdentity.profileImage
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// MARK: - Points Rule Row
struct PointsRuleRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

// MARK: - Redemption System View
struct RedemptionSystemView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var totalCredits: Int = 0
    @State private var availableRewards: [Reward] = []
    @State private var myRedemptions: [RedemptionRecord] = []
    @State private var isLoading = true
    @State private var refreshID = UUID() // 用于强制刷新 toolbar
    @State private var showRedeemAlert = false
    @State private var redeemAlertMessage = ""
    @State private var cashOutAmount: String = "" // 提现积分输入
    
    // Cached filtered rewards to improve performance
    @State private var cachedCoffeeRewards: [Reward] = []
    @State private var cachedMembershipRewards: [Reward] = []
    @State private var lastRewardsHash: Int = 0 // 用于检测奖励是否变化
    
    // Cached rewards for better performance
    private var coffeeRewards: [Reward] {
        cachedCoffeeRewards
    }
    
    private var membershipRewards: [Reward] {
        cachedMembershipRewards
    }
    
    private func updateCachedRewards() {
        // 使用哈希值快速检测变化，避免不必要的过滤操作
        let currentHash = availableRewards.map { $0.id }.joined().hashValue
        
        // 如果奖励数组没变化，跳过更新
        if currentHash == lastRewardsHash && !cachedCoffeeRewards.isEmpty && !cachedMembershipRewards.isEmpty {
            return
        }
        
        lastRewardsHash = currentHash
        
        print("🔍 [Redeem] 开始过滤奖励，总数: \(availableRewards.count)")
        for reward in availableRewards {
            print("   - \(reward.name) (category: \(reward.category.rawValue), id: \(reward.id))")
        }
        
        // 使用并行过滤提高性能
        let coffeeFilter: (Reward) -> Bool = { reward in
            // 排除会员奖励，避免名称包含 brew 等关键词时被识别为咖啡券
            if reward.category == .membership {
                return false
            }
            // 匹配 category 为 coffee 的奖励
            // 或者名称中包含 coffee、starbucks、dunkin、tim hortons、frappuccino、latte、brew 等关键词
            let nameLower = reward.name.lowercased()
            return reward.category == .coffee || 
                   nameLower.contains("coffee") ||
                   nameLower.contains("starbucks") ||
                   nameLower.contains("dunkin") ||
                   nameLower.contains("tim hortons") ||
                   nameLower.contains("frappuccino") ||
                   nameLower.contains("latte") ||
                   nameLower.contains("brew") ||
                   nameLower.contains("voucher")
        }
        
        let membershipFilter: (Reward) -> Bool = { reward in
            let nameLower = reward.name.lowercased()
            return reward.category == .membership || 
                   nameLower.contains("premium") || 
                   nameLower.contains("ultimate") ||
                   nameLower.contains("membership") ||
                   nameLower.contains("brewnet")
        }
        
        // 只过滤一次，然后分别提取
        let newCoffeeRewards = availableRewards.filter(coffeeFilter)
        let newMembershipRewards = availableRewards.filter(membershipFilter)
        
        print("✅ [Redeem] 过滤结果 - 咖啡代金券: \(newCoffeeRewards.count), 会员奖励: \(newMembershipRewards.count)")
        
        // 使用 Set 进行快速比较
        let coffeeIds = Set(newCoffeeRewards.map { $0.id })
        let cachedCoffeeIds = Set(cachedCoffeeRewards.map { $0.id })
        
        let membershipIds = Set(newMembershipRewards.map { $0.id })
        let cachedMembershipIds = Set(cachedMembershipRewards.map { $0.id })
        
        // 只在真正变化时更新
        if coffeeIds != cachedCoffeeIds {
            cachedCoffeeRewards = newCoffeeRewards
        }
        
        if membershipIds != cachedMembershipIds {
            cachedMembershipRewards = newMembershipRewards
        }
    }
    
    // 使用 @ViewBuilder 和缓存优化
    @ViewBuilder
    private var availableGiftSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Gift")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            coffeeVouchersSection
            
            Divider()
                .padding(.vertical, 8)
            
            membershipSection
            
            Divider()
                .padding(.vertical, 8)
            
            cashOutSection
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var coffeeVouchersSection: some View {
        DisclosureGroup {
            if coffeeRewards.isEmpty {
                emptyStateView(
                    icon: "cup.and.saucer.fill",
                    message: "No coffee vouchers available"
                )
                .frame(height: 200)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coffeeRewards, id: \.id) { reward in
                            RewardCard(reward: reward, userPoints: totalCredits) {
                                redeemReward(reward)
                            }
                            .equatable() // 使用 Equatable 优化，避免不必要的重绘
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 400) // 固定高度，可以滚动
            }
        } label: {
            sectionLabel(icon: "cup.and.saucer.fill", title: "Coffee Vouchers")
        }
        .id("coffee-section-\(cachedCoffeeRewards.count)")
    }
    
    @ViewBuilder
    private var membershipSection: some View {
        DisclosureGroup {
            if membershipRewards.isEmpty {
                emptyStateView(
                    icon: "crown.fill",
                    message: "No membership options available"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(membershipRewards, id: \.id) { reward in
                        RewardCard(reward: reward, userPoints: totalCredits) {
                            redeemReward(reward)
                        }
                        .equatable() // 使用 Equatable 优化，避免不必要的重绘
                    }
                }
            }
        } label: {
            sectionLabel(icon: "crown.fill", title: "BrewNet membership")
        }
        .id("membership-section-\(cachedMembershipRewards.count)")
    }
    
    @ViewBuilder
    private var membershipSectionLabel: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.9, blue: 0.5),
                                Color(red: 1.0, green: 0.75, blue: 0.25)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.25).opacity(0.35), radius: 6, x: 0, y: 3)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 20, height: 20)
                            .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .overlay(
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                            )
                            .offset(x: -6, y: -6)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("BrewNet Pro")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                Text("Redeem premium perks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
    
    private var cashOutSection: some View {
        DisclosureGroup {
            VStack(spacing: 20) {
                // 输入和显示区域
                HStack(spacing: 16) {
                    // 左边：输入积分
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits to Cash Out")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField("Enter credits", text: $cashOutAmount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(12)
                            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: cashOutAmount) { newValue in
                                // 限制输入不超过用户的 credits 数量
                                if let enteredValue = Int(newValue), enteredValue > totalCredits {
                                    cashOutAmount = String(totalCredits)
                                }
                            }
                    }
                    
                    // 右边：显示现金
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cash Amount")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text(String(format: "%.2f", cashOutValue))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 兑换比例提示
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("100 credits = $10.00")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // 提现按钮
                Button(action: {
                    processCashOut()
                }) {
                    Text("Cash Out")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(canCashOut ? 1.0 : 0.5))
                        .cornerRadius(8)
                }
                .disabled(!canCashOut)
            }
            .padding(.vertical, 8)
        } label: {
            sectionLabel(icon: "dollarsign.circle.fill", title: "Cash Out")
        }
        .id("cashout-section")
    }
    
    // 计算现金金额（100 积分 = 10 美元）
    private var cashOutValue: Double {
        guard let points = Int(cashOutAmount), points > 0 else {
            return 0.0
        }
        return Double(points) / 10.0
    }
    
    // 检查是否可以提现
    private var canCashOut: Bool {
        guard let points = Int(cashOutAmount),
              points > 0,
              points <= totalCredits,
              points >= 100 else { // 最少提现 100 积分
            return false
        }
        return true
    }
    
    // 处理提现
    private func processCashOut() {
        guard let points = Int(cashOutAmount),
              points > 0,
              points <= totalCredits else {
            showRedeemAlert(message: "Invalid amount or insufficient points")
            return
        }
        
        guard points >= 100 else {
            showRedeemAlert(message: "Minimum cash out is 100 points ($10.00)")
            return
        }
        
        guard let currentUser = authManager.currentUser else { return }
        
        Task {
            do {
                // 先保存现金金额（在清空输入前）
                let cashAmount = cashOutValue
                
                // 先立即更新 UI 中的积分（乐观更新）
                let newCredits = totalCredits - points
                await MainActor.run {
                    totalCredits = newCredits
                    refreshID = UUID()
                    LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: newCredits)
                }
                
                // 执行提现：扣除积分并创建提现记录
                try await supabaseService.cashOut(userId: currentUser.id, points: points, cashAmount: cashAmount)
                
                // 清空输入
                await MainActor.run {
                    cashOutAmount = ""
                }
                
                // 等待一小段时间确保数据库更新完成
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                
                // 重新加载数据以确保同步
                await loadRedemptionData()
                
                // 显示成功提示
                await MainActor.run {
                    showRedeemAlert(message: "Successfully cashed out $\(String(format: "%.2f", cashAmount))! Your payment will be processed.")
                }
            } catch {
                print("❌ Failed to cash out: \(error.localizedDescription)")
                
                // 如果失败，恢复积分
                await MainActor.run {
                    Task {
                        do {
                            let actualCredits = try await supabaseService.getUserCredits(userId: currentUser.id)
                            await MainActor.run {
                                totalCredits = actualCredits
                                refreshID = UUID()
                                LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: actualCredits)
                            }
                        } catch {
                            print("⚠️ Failed to restore credits: \(error.localizedDescription)")
                        }
                    }
                }
                
                let errorMessage = error.localizedDescription.contains("Insufficient") 
                    ? error.localizedDescription 
                    : "Failed to cash out. Please try again."
                await MainActor.run {
                    showRedeemAlert(message: errorMessage)
                }
            }
        }
    }
    
    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    private func sectionLabel(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            Spacer()
        }
    }
    
    @ViewBuilder
    private var redemptionHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Redemption History")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            if myRedemptions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No redemption history")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(myRedemptions, id: \.id) { redemption in
                        RedemptionRecordRow(record: redemption)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        availableGiftSection
                        redemptionHistorySection
                    }
                    .padding(16)
                }
                .overlay {
                    // 只在真正需要时显示 loading（没有缓存且正在加载）
                    if isLoading && cachedCoffeeRewards.isEmpty && cachedMembershipRewards.isEmpty && myRedemptions.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.98, green: 0.97, blue: 0.95).opacity(0.9))
                    }
                }
            }
            .navigationTitle("Redeem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 6) {
                        // Total Credits Display (右上角)
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            Text("\(totalCredits)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(8)
                        .id("creditsBadge-\(totalCredits)-\(refreshID)") // 强制刷新整个 badge
                        
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    .id("toolbar-\(refreshID)") // 强制刷新整个 toolbar
                }
            }
            .onAppear {
                // 立即在主线程加载缓存，确保 UI 快速响应
                Task { @MainActor in
                    loadCachedRedeemData()
                    // 延迟一点再加载最新数据，让 UI 先渲染
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                    loadRedemptionData()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CoffeeChatScheduleUpdated"))) { _ in
                print("🔄 [Redeem] 收到日程更新通知，重新加载积分")
                loadRedemptionData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserCreditsUpdated"))) { _ in
                print("🔄 [Redeem] 收到积分更新通知，快速更新积分")
                // 只更新积分，不重新加载所有数据
                Task {
                    guard let currentUser = authManager.currentUser else { return }
                    do {
                        let credits = try await supabaseService.getUserCredits(userId: currentUser.id)
                        await MainActor.run {
                            totalCredits = credits
                            refreshID = UUID()
                            // 快速更新缓存中的积分
                            LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: credits)
                            print("✅ [Redeem] 积分已快速更新: \(credits)")
                        }
                    } catch {
                        print("⚠️ [Redeem] 快速更新积分失败: \(error.localizedDescription)")
                    }
                }
            }
            .onChange(of: availableRewards) { newRewards in
                // 使用哈希值快速检测是否真的需要更新
                let newHash = newRewards.map { $0.id }.joined().hashValue
                if newHash != lastRewardsHash {
                    // 只在真正变化时更新
                    updateCachedRewards()
                }
            }
            .alert("Redemption", isPresented: $showRedeemAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(redeemAlertMessage)
            }
        }
    }
    
    private func loadCachedRedeemData() {
        guard let currentUser = authManager.currentUser else { return }
        
        // 从本地缓存加载数据（同步操作，立即执行）
        if let cached = LocalCacheManager.shared.loadRedeemData(userId: currentUser.id) {
            // 批量更新状态，减少视图重建次数
            totalCredits = cached.credits
            availableRewards = cached.rewards
            myRedemptions = cached.redemptions
            
            // 如果缓存中有预过滤的奖励，直接使用，避免重新过滤
            if let cachedCoffee = cached.coffeeRewards, let cachedMembership = cached.membershipRewards {
                cachedCoffeeRewards = cachedCoffee
                cachedMembershipRewards = cachedMembership
                print("✅ [Redeem] 从缓存加载预过滤奖励 - 咖啡: \(cachedCoffee.count), 会员: \(cachedMembership.count)")
            } else {
                // 如果没有预过滤数据，执行过滤
                print("⚠️ [Redeem] 缓存中没有预过滤数据，执行过滤...")
                updateCachedRewards()
            }
            
            // 立即设置加载完成，让 UI 显示内容
            isLoading = false
        } else {
            // 没有缓存时，保持 loading 状态
            isLoading = true
        }
    }
    
    private func loadRedemptionData() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        // 如果没有缓存，显示 loading
        if availableRewards.isEmpty && myRedemptions.isEmpty {
            isLoading = true
        }
        
        Task {
            do {
                // 并行加载数据以提高性能（移除不必要的 schedule 获取）
                async let creditsTask = supabaseService.getUserCredits(userId: currentUser.id)
                async let rewardsTask: [Reward] = {
                    do {
                        return try await supabaseService.getAvailableRewards()
                    } catch {
                        print("⚠️ [Redeem] 获取奖励失败: \(error.localizedDescription)")
                        return []
                    }
                }()
                async let redemptionsTask: [RedemptionRecord] = {
                    do {
                        return try await supabaseService.getUserRedemptions(userId: currentUser.id)
                    } catch {
                        print("⚠️ [Redeem] 获取兑换记录失败: \(error.localizedDescription)")
                        return []
                    }
                }()
                
                // 等待所有任务完成
                let credits = try await creditsTask
                let rewards = await rewardsTask
                let redemptions = await redemptionsTask
                
                // 批量更新所有状态，减少视图重建
                await MainActor.run {
                    // 只在数据真正变化时更新，避免不必要的重绘
                    var needsUpdate = false
                    
                    if totalCredits != credits {
                        totalCredits = credits
                        refreshID = UUID()
                        needsUpdate = true
                        // 快速更新缓存中的积分
                        LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: credits)
                    }
                    
                    // 使用 Set 比较，只在真正变化时更新
                    let newRewardIds = Set(rewards.map { $0.id })
                    let currentRewardIds = Set(availableRewards.map { $0.id })
                    
                    if newRewardIds != currentRewardIds {
                        print("🔄 [Redeem] 奖励列表已更新，从 \(availableRewards.count) 个变为 \(rewards.count) 个")
                        availableRewards = rewards
                        // 立即更新缓存奖励
                        updateCachedRewards()
                        needsUpdate = true
                    } else if availableRewards.isEmpty && !rewards.isEmpty {
                        // 如果当前为空但新数据不为空，也要更新
                        print("🔄 [Redeem] 首次加载奖励数据: \(rewards.count) 个")
                        availableRewards = rewards
                        updateCachedRewards()
                        needsUpdate = true
                    }
                    
                    let newRedemptionIds = Set(redemptions.map { $0.id })
                    let currentRedemptionIds = Set(myRedemptions.map { $0.id })
                    
                    if newRedemptionIds != currentRedemptionIds {
                        myRedemptions = redemptions
                        needsUpdate = true
                    }
                    
                    // 只在有变化时保存缓存
                    if needsUpdate {
                        LocalCacheManager.shared.saveRedeemData(
                            userId: currentUser.id,
                            credits: totalCredits,
                            rewards: rewards,
                            redemptions: redemptions,
                            coffeeRewards: cachedCoffeeRewards,
                            membershipRewards: cachedMembershipRewards
                        )
                    }
                    
                    isLoading = false
                }
            } catch {
                print("❌ Failed to load redemption data: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func redeemReward(_ reward: Reward) {
        guard let currentUser = authManager.currentUser else { return }
        
        // 先检查积分是否足够
        if totalCredits < reward.pointsRequired {
            showRedeemAlert(message: "Insufficient points. You need \(reward.pointsRequired) points but only have \(totalCredits) points.")
            return
        }
        
        Task {
            do {
                // 先立即更新 UI 中的积分（乐观更新）
                let newCredits = totalCredits - reward.pointsRequired
                await MainActor.run {
                    totalCredits = newCredits
                    refreshID = UUID()
                    // 更新缓存
                    LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: newCredits)
                }
                
                // 执行兑换
                try await supabaseService.redeemReward(userId: currentUser.id, rewardId: reward.id)
                
                // 等待一小段时间确保数据库更新完成
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                
                // 重新加载数据以确保同步
                await loadRedemptionData()
                
                // 再次确认积分已更新
                do {
                    let finalCredits = try await supabaseService.getUserCredits(userId: currentUser.id)
                    await MainActor.run {
                        if totalCredits != finalCredits {
                            print("🔄 [Redeem] 同步最终积分: \(totalCredits) -> \(finalCredits)")
                            totalCredits = finalCredits
                            refreshID = UUID()
                            LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: finalCredits)
                        }
                    }
                } catch {
                    print("⚠️ [Redeem] 无法获取最终积分: \(error.localizedDescription)")
                }
                
                // 显示成功提示
                await MainActor.run {
                    showRedeemAlert(message: "Successfully redeemed \(reward.name)! Your voucher has been saved.")
                }
            } catch {
                print("❌ Failed to redeem reward: \(error.localizedDescription)")
                
                // 如果失败，恢复积分
                await MainActor.run {
                    // 重新获取实际积分
                    Task {
                        do {
                            let actualCredits = try await supabaseService.getUserCredits(userId: currentUser.id)
                            await MainActor.run {
                                totalCredits = actualCredits
                                refreshID = UUID()
                                LocalCacheManager.shared.updateRedeemCredits(userId: currentUser.id, credits: actualCredits)
                            }
                        } catch {
                            print("⚠️ Failed to restore credits: \(error.localizedDescription)")
                        }
                    }
                }
                
                let errorMessage = error.localizedDescription.contains("Insufficient points") 
                    ? error.localizedDescription 
                    : "Failed to redeem reward. Please try again."
                await MainActor.run {
                    showRedeemAlert(message: errorMessage)
                }
            }
        }
    }
    
    private func showRedeemAlert(message: String) {
        redeemAlertMessage = message
        showRedeemAlert = true
    }
}

// MARK: - Reward Model
struct Reward: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let pointsRequired: Int
    let category: RewardCategory
    let imageUrl: String?
    
    enum RewardCategory: String, Codable, Equatable {
        case coffee = "coffee"
        case gift = "gift"
        case membership = "membership"
        case other = "other"
    }
}

// MARK: - Reward Card
struct RewardCard: View, Equatable {
    let reward: Reward
    let userPoints: Int
    let onRedeem: () -> Void
    
    private var canRedeem: Bool {
        userPoints >= reward.pointsRequired
    }
    
    // Equatable 实现，用于优化重绘
    static func == (lhs: RewardCard, rhs: RewardCard) -> Bool {
        lhs.reward.id == rhs.reward.id && 
        lhs.userPoints == rhs.userPoints &&
        lhs.reward == rhs.reward
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 第一行：图片和信息
            HStack(spacing: 16) {
                // Reward Icon/Image
                ZStack {
                    if reward.category == .membership {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.9, blue: 0.5),
                                        Color(red: 1.0, green: 0.75, blue: 0.25)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.25).opacity(0.3), radius: 8, x: 0, y: 4)
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                            .overlay(alignment: .topLeading) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 26, height: 26)
                                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    .overlay(
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                                    )
                                    .offset(x: -10, y: -10)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Group {
                                    if let imageName = reward.imageUrl, !imageName.isEmpty, UIImage(named: imageName) != nil {
                                        Image(imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        Image(systemName: rewardIcon)
                                            .font(.system(size: 40))
                                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    }
                                }
                            )
                    }
                }
                
                // Reward Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(reward.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(reward.description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("\(reward.pointsRequired) points")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                }
                
                Spacer()
            }
            
            // 第二行：按钮
            HStack {
                Spacer()
                
                // Redeem Button
                Button(action: {
                    if canRedeem {
                        onRedeem()
                    }
                }) {
                    Text(canRedeem ? "Redeem" : "Insufficient Points")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canRedeem ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(!canRedeem)
            }
        }
        .padding(16)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .cornerRadius(12)
    }
    
    private var rewardIcon: String {
        switch reward.category {
        case .coffee:
            return "cup.and.saucer.fill"
        case .gift:
            return "gift.fill"
        case .membership:
            return "crown.fill"
        case .other:
            return "star.fill"
        }
    }
}

// MARK: - Redemption Record
struct RedemptionRecord: Identifiable, Codable {
    let id: String
    let rewardId: String
    let rewardName: String
    let pointsUsed: Int
    let redeemedAt: Date
    let status: RedemptionStatus
    
    enum RedemptionStatus: String, Codable {
        case pending = "pending"
        case completed = "completed"
        case cancelled = "cancelled"
    }
}

// MARK: - Redemption Record Row
struct RedemptionRecordRow: View {
    let record: RedemptionRecord
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                .frame(width: 40, height: 40)
                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.rewardName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("\(record.pointsUsed) points")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(formatDate(record.redeemedAt))
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.7))
            }
            
            Spacer()
            
            StatusBadge(status: record.status)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .cornerRadius(12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: RedemptionRecord.RedemptionStatus
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        switch status {
        case .pending:
            return "Pending"
        case .completed:
            return "Use"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending:
            return .orange
        case .completed:
            return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .cancelled:
            return .gray
        }
    }
}

// MARK: - Preview
struct ProfileDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileDisplayView(profile: BrewNetProfile.createDefault(userId: "preview"), showSubscriptionPayment: .constant(false)) {
                // Preview doesn't need action
            }
        }
    }
}

