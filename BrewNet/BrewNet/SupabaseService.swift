import Foundation
import Supabase
import CoreData

// MARK: - Supabase Service
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    private weak var databaseManager: DatabaseManager?
    
    private init() {
        self.client = SupabaseConfig.shared.client
    }
    
    // MARK: - Dependency Injection
    func setDependencies(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }
    
    // MARK: - Database Setup
    func createProfilesTable() async throws {
        print("🔧 正在创建 profiles 表...")
        
        // 由于 Supabase 客户端可能不支持直接执行 DDL，我们使用一个变通方法
        // 尝试插入一个测试记录来检查表是否存在，如果不存在则提示用户手动创建
        do {
            // 先尝试查询表是否存在
            let response = try await client
                .from("profiles")
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ profiles 表已存在！")
            print("📊 响应状态: \(response.response.statusCode)")
            
        } catch {
            print("❌ profiles 表不存在，需要手动创建")
            print("🔍 错误信息: \(error.localizedDescription)")
            
            // 提供创建表的 SQL 语句
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS profiles (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                core_identity JSONB NOT NULL,
                professional_background JSONB NOT NULL,
                networking_intent JSONB NOT NULL,
                personality_social JSONB NOT NULL,
                privacy_trust JSONB NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                UNIQUE(user_id)
            );
            """
            
            print("📋 请在 Supabase Dashboard 的 SQL Editor 中执行以下 SQL 语句:")
            print(String(repeating: "=", count: 60))
            print(createTableSQL)
            print(String(repeating: "=", count: 60))
            
            throw error
        }
    }
    
    func ensureTablesExist() async {
        print("🔧 开始检查 Supabase 连接...")
        print("🔗 Supabase URL: https://jcxvdolcdifdghaibspy.supabase.co")
        
        // 首先检查网络连接
        guard isNetworkAvailable() else {
            print("⚠️ 网络不可用，使用离线模式")
            await MainActor.run {
                isOnline = false
            }
            return
        }
        
        // 详细检查 Supabase 连接
        do {
            print("📡 正在测试 Supabase 连接...")
            
            // 测试基本连接
            let response = try await client
                .from("users")
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ Supabase 连接成功！")
            print("📊 响应状态: \(response.response.statusCode)")
            print("📋 响应数据: \(String(data: response.data, encoding: .utf8) ?? "无数据")")
            
            await MainActor.run {
                isOnline = true
            }
            
        } catch {
            print("⚠️ Supabase 连接失败，将使用离线模式:")
            print("🔍 错误类型: \(type(of: error))")
            print("📝 错误信息: \(error.localizedDescription)")
            
            if let httpError = error as? URLError {
                print("🌐 URL 错误代码: \(httpError.code.rawValue)")
                print("🌐 URL 错误描述: \(httpError.localizedDescription)")
            }
            
            // 静默处理错误，不要弹出警告
            await MainActor.run {
                isOnline = false
            }
            
            print("📱 应用将继续使用本地存储模式")
        }
    }
    
    private func isNetworkAvailable() -> Bool {
        // 简单的网络检查
        return true // 暂时总是返回 true，让系统处理网络错误
    }
    
    // MARK: - Test Connection
    func testSupabaseConnection() async -> Bool {
        print("🧪 开始测试 Supabase 连接...")
        
        do {
            // 测试基本连接
            let response = try await client
                .from("users")
                .select("count")
                .execute()
            
            print("✅ Supabase 连接测试成功！")
            print("📊 HTTP 状态码: \(response.response.statusCode)")
            
            if let responseString = String(data: response.data, encoding: .utf8) {
                print("📋 响应内容: \(responseString)")
            }
            
            return true
            
        } catch {
            print("❌ Supabase 连接测试失败:")
            print("🔍 错误详情: \(error)")
            
            if let httpError = error as? URLError {
                print("🌐 URL 错误: \(httpError.code.rawValue) - \(httpError.localizedDescription)")
            }
            
            return false
        }
    }
    
    // MARK: - Network Status
    @Published var isOnline = true
    @Published var lastSyncTime: Date?
    
    // MARK: - User Operations
    
    /// 创建用户到 Supabase
    func createUser(user: SupabaseUser) async throws -> SupabaseUser {
        let response = try await client
            .from(SupabaseTable.users.rawValue)
            .insert(user)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let createdUser = try JSONDecoder().decode(SupabaseUser.self, from: data)
        
        // 同时保存到本地数据库
        await MainActor.run {
            let _ = databaseManager?.createUser(
                id: createdUser.id,
                email: createdUser.email,
                name: createdUser.name,
                phoneNumber: createdUser.phoneNumber,
                isGuest: createdUser.isGuest,
                profileSetupCompleted: createdUser.profileSetupCompleted
            )
        }
        
        return createdUser
    }
    
    /// 更新用户资料设置完成状态
    func updateUserProfileSetupCompleted(userId: String, completed: Bool) async throws {
        print("🔄 Updating profile setup status for user: \(userId) to \(completed)")
        
        do {
            try await client
                .from(SupabaseTable.users.rawValue)
                .update(["profile_setup_completed": completed])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Profile setup status updated successfully")
        } catch {
            print("❌ Failed to update profile setup status: \(error.localizedDescription)")
            
            // If column doesn't exist, try alternative approach
            if error.localizedDescription.contains("profile_setup_completed") {
                print("⚠️ profile_setup_completed column not found, skipping update")
                // Don't throw error, just log and continue
                return
            }
            
            throw error
        }
    }
    
    /// 从 Supabase 获取用户
    func getUser(id: String) async throws -> SupabaseUser? {
        let response = try await client
            .from(SupabaseTable.users.rawValue)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }
    
    /// 从 Supabase 通过邮箱获取用户
    func getUserByEmail(email: String) async throws -> SupabaseUser? {
        let response = try await client
            .from(SupabaseTable.users.rawValue)
            .select()
            .eq("email", value: email)
            .single()
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode(SupabaseUser.self, from: data)
    }
    
    /// 更新用户最后登录时间
    func updateUserLastLogin(userId: String) async throws {
        try await client
            .from(SupabaseTable.users.rawValue)
            .update(["last_login_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Post Operations
    
    /// 创建帖子到 Supabase
    func createPost(post: SupabasePost) async throws -> SupabasePost {
        let response = try await client
            .from(SupabaseTable.posts.rawValue)
            .insert(post)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let createdPost = try JSONDecoder().decode(SupabasePost.self, from: data)
        
        // 同时保存到本地数据库
        await MainActor.run {
            let _ = databaseManager?.createPost(
                id: createdPost.id,
                title: createdPost.title,
                content: createdPost.content ?? "",
                question: createdPost.question ?? "",
                tag: createdPost.tag,
                tagColor: createdPost.tagColor,
                backgroundColor: createdPost.backgroundColor,
                authorId: createdPost.authorId,
                authorName: createdPost.authorName
            )
        }
        
        return createdPost
    }
    
    /// 从 Supabase 获取所有帖子
    func getAllPosts() async throws -> [SupabasePost] {
        let response = try await client
            .from(SupabaseTable.posts.rawValue)
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabasePost].self, from: data)
    }
    
    /// 从 Supabase 获取用户的帖子
    func getPostsByAuthor(authorId: String) async throws -> [SupabasePost] {
        let response = try await client
            .from(SupabaseTable.posts.rawValue)
            .select()
            .eq("author_id", value: authorId)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabasePost].self, from: data)
    }
    
    // MARK: - Like Operations
    
    /// 点赞帖子
    func likePost(userId: String, postId: String) async throws -> Bool {
        // 检查是否已经点赞
        let existingLikes = try await client
            .from(SupabaseTable.likes.rawValue)
            .select()
            .eq("user_id", value: userId)
            .eq("post_id", value: postId)
            .execute()
        
        let data = existingLikes.data
        let likes = try JSONDecoder().decode([SupabaseLike].self, from: data)
        
        if !likes.isEmpty {
            return false // 已经点赞过了
        }
        
        // 创建点赞记录
        let like = SupabaseLike(
            id: UUID().uuidString,
            userId: userId,
            postId: postId,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from(SupabaseTable.likes.rawValue)
            .insert(like)
            .execute()
        
        // 更新帖子点赞数
        try await updatePostLikeCount(postId: postId, increment: 1)
        
        // 同时保存到本地数据库
        await MainActor.run {
            _ = databaseManager?.likePost(userId: userId, postId: postId)
        }
        
        return true
    }
    
    /// 取消点赞
    func unlikePost(userId: String, postId: String) async throws -> Bool {
        // 删除点赞记录
        try await client
            .from(SupabaseTable.likes.rawValue)
            .delete()
            .eq("user_id", value: userId)
            .eq("post_id", value: postId)
            .execute()
        
        // 更新帖子点赞数
        try await updatePostLikeCount(postId: postId, increment: -1)
        
        // 同时从本地数据库删除
        await MainActor.run {
            _ = databaseManager?.unlikePost(userId: userId, postId: postId)
        }
        
        return true
    }
    
    /// 更新帖子点赞数
    private func updatePostLikeCount(postId: String, increment: Int) async throws {
        // 先获取当前点赞数
        let response = try await client
            .from(SupabaseTable.posts.rawValue)
            .select("like_count")
            .eq("id", value: postId)
            .single()
            .execute()
        
        let data = response.data
        let postData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let currentCount = postData["like_count"] as? Int ?? 0
        let newCount = max(0, currentCount + increment)
        
        // 更新点赞数
        try await client
            .from(SupabaseTable.posts.rawValue)
            .update(["like_count": newCount])
            .eq("id", value: postId)
            .execute()
    }
    
    // MARK: - Save Operations
    
    /// 保存帖子
    func savePost(userId: String, postId: String) async throws -> Bool {
        // 检查是否已经保存
        let existingSaves = try await client
            .from(SupabaseTable.saves.rawValue)
            .select()
            .eq("user_id", value: userId)
            .eq("post_id", value: postId)
            .execute()
        
        let data = existingSaves.data
        let saves = try JSONDecoder().decode([SupabaseSave].self, from: data)
        
        if !saves.isEmpty {
            return false // 已经保存过了
        }
        
        // 创建保存记录
        let save = SupabaseSave(
            id: UUID().uuidString,
            userId: userId,
            postId: postId,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from(SupabaseTable.saves.rawValue)
            .insert(save)
            .execute()
        
        // 同时保存到本地数据库
        await MainActor.run {
            _ = databaseManager?.savePost(userId: userId, postId: postId)
        }
        
        return true
    }
    
    /// 取消保存
    func unsavePost(userId: String, postId: String) async throws -> Bool {
        try await client
            .from(SupabaseTable.saves.rawValue)
            .delete()
            .eq("user_id", value: userId)
            .eq("post_id", value: postId)
            .execute()
        
        // 同时从本地数据库删除
        await MainActor.run {
            _ = databaseManager?.unsavePost(userId: userId, postId: postId)
        }
        
        return true
    }
    
    // MARK: - Profile Operations
    
    /// 创建用户资料
    func createProfile(profile: SupabaseProfile) async throws -> SupabaseProfile {
        print("🔧 Creating profile for user: \(profile.userId)")
        
        // Validate profile data
        guard !profile.coreIdentity.name.isEmpty else {
            throw ProfileError.invalidData("Name is required")
        }
        
        guard !profile.coreIdentity.email.isEmpty else {
            throw ProfileError.invalidData("Email is required")
        }
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .insert(profile)
                .select()
                .single()
                .execute()
            
            let data = response.data
            let createdProfile = try JSONDecoder().decode(SupabaseProfile.self, from: data)
            print("✅ Profile created successfully: \(createdProfile.id)")
            return createdProfile
            
        } catch {
            print("❌ Failed to create profile: \(error.localizedDescription)")
            
            // If it's a duplicate key error, try to update existing profile
            if error.localizedDescription.contains("duplicate key value violates unique constraint") {
                print("🔄 Profile already exists, updating instead...")
                do {
                    let existingProfile = try await getProfile(userId: profile.userId)
                    if let existing = existingProfile {
                        return try await updateProfile(profileId: existing.id, profile: profile)
                    }
                } catch {
                    print("❌ Failed to update existing profile: \(error.localizedDescription)")
                }
            }
            
            throw ProfileError.creationFailed(error.localizedDescription)
        }
    }
    
    /// 获取用户资料
    func getProfile(userId: String) async throws -> SupabaseProfile? {
        print("🔍 Fetching profile for user: \(userId)")
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            let data = response.data
            let profile = try JSONDecoder().decode(SupabaseProfile.self, from: data)
            print("✅ Profile fetched successfully: \(profile.id)")
            return profile
            
        } catch {
            if error.localizedDescription.contains("No rows found") {
                print("ℹ️ No profile found for user: \(userId)")
                return nil
            } else {
                print("❌ Failed to fetch profile: \(error.localizedDescription)")
                throw ProfileError.fetchFailed(error.localizedDescription)
            }
        }
    }
    
    /// 更新用户资料
    func updateProfile(profileId: String, profile: SupabaseProfile) async throws -> SupabaseProfile {
        print("🔄 Updating profile: \(profileId)")
        
        // Validate profile data
        guard !profile.coreIdentity.name.isEmpty else {
            throw ProfileError.invalidData("Name is required")
        }
        
        guard !profile.coreIdentity.email.isEmpty else {
            throw ProfileError.invalidData("Email is required")
        }
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .update(profile)
                .eq("id", value: profileId)
                .select()
                .single()
                .execute()
            
            let data = response.data
            let updatedProfile = try JSONDecoder().decode(SupabaseProfile.self, from: data)
            print("✅ Profile updated successfully: \(updatedProfile.id)")
            return updatedProfile
            
        } catch {
            print("❌ Failed to update profile: \(error.localizedDescription)")
            throw ProfileError.updateFailed(error.localizedDescription)
        }
    }
    
    /// 删除用户资料
    func deleteProfile(profileId: String) async throws {
        print("🗑️ Deleting profile: \(profileId)")
        
        do {
            try await client
                .from(SupabaseTable.profiles.rawValue)
                .delete()
                .eq("id", value: profileId)
                .execute()
            
            print("✅ Profile deleted successfully: \(profileId)")
            
        } catch {
            print("❌ Failed to delete profile: \(error.localizedDescription)")
            throw ProfileError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// 获取推荐用户列表
    func getRecommendedProfiles(userId: String, limit: Int = 20) async throws -> [SupabaseProfile] {
        print("🔍 Fetching recommended profiles for user: \(userId)")
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .neq("user_id", value: userId)
                .limit(limit)
                .execute()
            
            let data = response.data
            let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
            print("✅ Fetched \(profiles.count) recommended profiles")
            return profiles
            
        } catch {
            print("❌ Failed to fetch recommended profiles: \(error.localizedDescription)")
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// 搜索用户资料
    func searchProfiles(query: String, limit: Int = 20) async throws -> [SupabaseProfile] {
        print("🔍 Searching profiles with query: \(query)")
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .or("core_identity->name.ilike.%\(query)%,core_identity->bio.ilike.%\(query)%,professional_background->skills.cs.{\(query)}")
                .limit(limit)
                .execute()
            
            let data = response.data
            let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
            print("✅ Found \(profiles.count) profiles matching query")
            return profiles
            
        } catch {
            print("❌ Failed to search profiles: \(error.localizedDescription)")
            throw ProfileError.searchFailed(error.localizedDescription)
        }
    }
    
    /// 检查用户是否有资料
    func hasProfile(userId: String) async throws -> Bool {
        do {
            let _ = try await getProfile(userId: userId)
            return true
        } catch {
            return false
        }
    }
    
    /// 获取用户资料完成度
    func getProfileCompletion(userId: String) async throws -> Double {
        guard let profile = try await getProfile(userId: userId) else {
            return 0.0
        }
        
        let brewNetProfile = profile.toBrewNetProfile()
        return brewNetProfile.completionPercentage
    }
    
    // MARK: - Anonymous Post Operations
    
    /// 创建匿名帖子
    func createAnonymousPost(post: SupabaseAnonymousPost) async throws -> SupabaseAnonymousPost {
        let response = try await client
            .from(SupabaseTable.anonymousPosts.rawValue)
            .insert(post)
            .select()
            .single()
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode(SupabaseAnonymousPost.self, from: data)
    }
    
    /// 获取所有匿名帖子
    func getAllAnonymousPosts() async throws -> [SupabaseAnonymousPost] {
        let response = try await client
            .from(SupabaseTable.anonymousPosts.rawValue)
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabaseAnonymousPost].self, from: data)
    }
    
    // MARK: - Sync Operations
    
    /// 同步本地数据到云端
    func syncToCloud() async {
        guard isOnline else { return }
        
        do {
            // 同步用户数据
            guard let localUsers = databaseManager?.getAllUsers() else { return }
            for user in localUsers {
                let supabaseUser = SupabaseUser(
                    id: user.id ?? UUID().uuidString,
                    email: user.email ?? "",
                    name: user.name ?? "",
                    phoneNumber: user.phoneNumber,
                    isGuest: user.isGuest,
                    profileImage: user.profileImage,
                    bio: user.bio,
                    company: user.company,
                    jobTitle: user.jobTitle,
                    location: user.location,
                    skills: user.skills,
                    interests: user.interests,
                    profileSetupCompleted: user.profileSetupCompleted,
                    createdAt: ISO8601DateFormatter().string(from: user.createdAt ?? Date()),
                    lastLoginAt: ISO8601DateFormatter().string(from: user.lastLoginAt ?? Date()),
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                // 检查云端是否已存在
                if let _ = try? await getUser(id: supabaseUser.id) {
                    // 用户已存在，跳过
                    continue
                } else {
                    // 创建新用户
                    let _ = try await createUser(user: supabaseUser)
                }
            }
            
            // 同步帖子数据
            guard let localPosts = databaseManager?.getAllPosts() else { return }
            for post in localPosts {
                let supabasePost = SupabasePost(
                    id: post.id ?? UUID().uuidString,
                    title: post.title ?? "",
                    content: post.content,
                    question: post.question,
                    tag: post.tag ?? "",
                    tagColor: post.tagColor ?? "",
                    backgroundColor: post.backgroundColor ?? "",
                    authorId: post.authorId ?? "",
                    authorName: post.authorName ?? "",
                    likeCount: Int(post.likeCount),
                    viewCount: Int(post.viewCount),
                    createdAt: ISO8601DateFormatter().string(from: post.createdAt ?? Date()),
                    updatedAt: ISO8601DateFormatter().string(from: post.updatedAt ?? Date())
                )
                
                // 检查云端是否已存在
                if let _ = try? await client
                    .from(SupabaseTable.posts.rawValue)
                    .select("id")
                    .eq("id", value: supabasePost.id)
                    .single()
                    .execute() {
                    // 帖子已存在，跳过
                    continue
                } else {
                    // 创建新帖子
                    let _ = try await createPost(post: supabasePost)
                }
            }
            
            await MainActor.run {
                self.lastSyncTime = Date()
            }
            
            print("✅ 数据同步到云端完成")
            
        } catch {
            print("❌ 数据同步到云端失败: \(error)")
        }
    }
    
    /// 从云端同步数据到本地
    func syncFromCloud() async {
        guard isOnline else { return }
        
        do {
            // 同步帖子数据
            let cloudPosts = try await getAllPosts()
            await MainActor.run {
                // 清空本地帖子数据
                databaseManager?.clearAllPosts()
                
                // 重新创建帖子数据
                for cloudPost in cloudPosts {
                    let _ = databaseManager?.createPost(
                        id: cloudPost.id,
                        title: cloudPost.title,
                        content: cloudPost.content ?? "",
                        question: cloudPost.question ?? "",
                        tag: cloudPost.tag,
                        tagColor: cloudPost.tagColor,
                        backgroundColor: cloudPost.backgroundColor,
                        authorId: cloudPost.authorId,
                        authorName: cloudPost.authorName
                    )
                }
            }
            
            await MainActor.run {
                self.lastSyncTime = Date()
            }
            
            print("✅ 从云端同步数据完成")
            
        } catch {
            print("❌ 从云端同步数据失败: \(error)")
        }
    }
    
    // MARK: - Network Status Monitoring
    
    func startNetworkMonitoring() {
        // 简单的网络状态检查
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.checkNetworkStatus()
            }
        }
    }
    
    private func checkNetworkStatus() async {
        do {
            // 尝试连接 Supabase
            _ = try await client
                .from(SupabaseTable.users.rawValue)
                .select("id")
                .limit(1)
                .execute()
            
            await MainActor.run {
                self.isOnline = true
            }
        } catch {
            await MainActor.run {
                self.isOnline = false
            }
        }
    }
}

// MARK: - Profile Error Types
enum ProfileError: LocalizedError {
    case invalidData(String)
    case creationFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case searchFailed(String)
    case networkError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid profile data: \(message)"
        case .creationFailed(let message):
            return "Failed to create profile: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch profile: \(message)"
        case .updateFailed(let message):
            return "Failed to update profile: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete profile: \(message)"
        case .searchFailed(let message):
            return "Failed to search profiles: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - DatabaseManager Extensions
// 这些方法已移动到 DatabaseManager.swift 中
