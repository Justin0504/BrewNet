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
                networking_intention JSONB NOT NULL,
                networking_preferences JSONB NOT NULL,
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
    
    /// 修复 profiles 表架构
    func fixProfilesTableSchema() async throws {
        print("🔧 正在修复 profiles 表架构...")
        
        // 由于 Supabase 客户端不支持直接执行 DDL，我们提供一个修复脚本
        let fixSQL = """
        -- 快速修复 profiles 表问题
        -- 请在 Supabase Dashboard 的 SQL Editor 中执行此脚本
        
        -- 1. 如果 profiles 表不存在，创建完整的表
        CREATE TABLE IF NOT EXISTS profiles (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            core_identity JSONB NOT NULL,
            professional_background JSONB NOT NULL,
            networking_intention JSONB NOT NULL,
            networking_preferences JSONB NOT NULL,
            personality_social JSONB NOT NULL,
            privacy_trust JSONB NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(user_id)
        );
        
        -- 2. 如果表存在但缺少列，添加缺少的列
        ALTER TABLE profiles 
        ADD COLUMN IF NOT EXISTS core_identity JSONB,
        ADD COLUMN IF NOT EXISTS professional_background JSONB,
        ADD COLUMN IF NOT EXISTS networking_intention JSONB,
        ADD COLUMN IF NOT EXISTS networking_preferences JSONB,
        ADD COLUMN IF NOT EXISTS personality_social JSONB,
        ADD COLUMN IF NOT EXISTS privacy_trust JSONB;
        
        -- 3. 为现有记录设置默认值
        UPDATE profiles 
        SET 
            core_identity = COALESCE(core_identity, '{}'::jsonb),
            professional_background = COALESCE(professional_background, '{}'::jsonb),
            networking_intention = COALESCE(networking_intention, '{}'::jsonb),
            networking_preferences = COALESCE(networking_preferences, '{}'::jsonb),
            personality_social = COALESCE(personality_social, '{}'::jsonb),
            privacy_trust = COALESCE(privacy_trust, '{}'::jsonb);
        
        -- 4. 设置 NOT NULL 约束
        ALTER TABLE profiles 
        ALTER COLUMN core_identity SET NOT NULL,
        ALTER COLUMN professional_background SET NOT NULL,
        ALTER COLUMN networking_intention SET NOT NULL,
        ALTER COLUMN networking_preferences SET NOT NULL,
        ALTER COLUMN personality_social SET NOT NULL,
        ALTER COLUMN privacy_trust SET NOT NULL;
        
        -- 5. 启用行级安全
        ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
        
        -- 6. 创建策略
        DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
        DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
        DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
        DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;
        
        CREATE POLICY "Users can view their own profile" ON profiles 
            FOR SELECT USING (auth.uid()::text = user_id::text);
        
        CREATE POLICY "Users can insert their own profile" ON profiles 
            FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);
        
        CREATE POLICY "Users can update their own profile" ON profiles 
            FOR UPDATE USING (auth.uid()::text = user_id::text);
        
        CREATE POLICY "Users can delete their own profile" ON profiles 
            FOR DELETE USING (auth.uid()::text = user_id::text);
        
        -- 7. 创建索引
        CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
        CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);
        
        SELECT '✅ 修复完成！现在可以正常保存用户资料了。' as result;
        """
        
        print("📋 请在 Supabase Dashboard 的 SQL Editor 中执行以下修复脚本:")
        print(String(repeating: "=", count: 80))
        print(fixSQL)
        print(String(repeating: "=", count: 80))
        
        // 由于无法直接执行 DDL，我们抛出错误提示用户手动执行
        throw ProfileError.creationFailed("请手动执行上述 SQL 脚本来修复数据库架构问题。")
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
    
    /// 获取所有用户
    func getAllUsers() async throws -> [SupabaseUser] {
        let response = try await client
            .from(SupabaseTable.users.rawValue)
            .select()
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        return try JSONDecoder().decode([SupabaseUser].self, from: data)
    }
    
    
    // MARK: - Storage Operations
    
    /// 上传用户头像到 Supabase Storage
    func uploadProfileImage(userId: String, imageData: Data, fileExtension: String = "jpg") async throws -> String {
        print("📤 Uploading profile image for user: \(userId)")
        
        let fileName = "avatar.\(fileExtension)"
        let filePath = "\(userId)/\(fileName)"
        
        do {
            // 上传图片到 storage bucket
            try await client.storage
                .from("avatars")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/\(fileExtension == "jpg" ? "jpeg" : fileExtension)"
                    )
                )
            
            print("✅ Profile image uploaded successfully")
            
            // 获取公共 URL
            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: filePath)
            
            print("🔗 Public URL: \(publicURL)")
            return publicURL.absoluteString
            
        } catch {
            print("❌ Failed to upload profile image: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 删除用户头像
    func deleteProfileImage(userId: String) async throws {
        print("🗑️ Deleting profile image for user: \(userId)")
        
        let fileName = "avatar.jpg" // 需要匹配实际文件名
        let filePath = "\(userId)/\(fileName)"
        
        do {
            try await client.storage
                .from("avatars")
                .remove(paths: [filePath])
            
            print("✅ Profile image deleted successfully")
        } catch {
            print("❌ Failed to delete profile image: \(error.localizedDescription)")
            throw error
        }
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
        
        // 尝试多次创建，处理各种错误
        for attempt in 1...3 {
            do {
                print("🔄 Attempt \(attempt) to create profile...")
                
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
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                
                // 检查是否是架构问题
                if error.localizedDescription.contains("core_identity") || 
                   error.localizedDescription.contains("Could not find") ||
                   error.localizedDescription.contains("schema cache") ||
                   error.localizedDescription.contains("does not exist") ||
                   error.localizedDescription.contains("profile_image") ||
                   error.localizedDescription.contains("column") {
                    
                    if attempt == 1 {
                        print("🔧 Database schema issue detected. Please execute force_fix.sql script.")
                        throw ProfileError.creationFailed("数据库架构问题：请执行 force_fix.sql 脚本修复数据库。")
                    }
                }
                
                // 如果是重复键错误，尝试更新
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
                
                // 如果是最后一次尝试，抛出错误
                if attempt == 3 {
                    throw ProfileError.creationFailed("Failed to create profile after 3 attempts: \(error.localizedDescription)")
                }
                
                // 等待一秒后重试
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        throw ProfileError.creationFailed("Unexpected error in profile creation")
    }
    
    /// 获取用户资料
    func getProfile(userId: String) async throws -> SupabaseProfile? {
        print("🔍 Fetching profile for user: \(userId)")
        
        do {
            // 首先尝试获取所有匹配的记录
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .eq("user_id", value: userId)
                .execute()
            
            print("📊 Response status: \(response.response.statusCode)")
            let data = response.data
            print("📦 Response data size: \(data.count) bytes")
            
            // 打印原始数据以便调试
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Response JSON: \(jsonString)")
            }
            
            let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
            
            if profiles.isEmpty {
                print("ℹ️ No profile found for user: \(userId)")
                return nil
            } else if profiles.count == 1 {
                let profile = profiles.first!
                print("✅ Profile fetched successfully: \(profile.id)")
                return profile
            } else {
                print("⚠️ Multiple profiles found for user: \(userId), returning the first one")
                let profile = profiles.first!
                print("✅ Profile fetched successfully: \(profile.id)")
                return profile
            }
            
        } catch {
            print("❌ Failed to fetch profile: \(error.localizedDescription)")
            print("🔍 错误类型: \(type(of: error))")
            
            if let decodingError = error as? DecodingError {
                print("🔍 DecodingError 详情:")
                switch decodingError {
                case .dataCorrupted(let context):
                    print("   - 数据损坏: \(context.debugDescription)")
                    print("   - 原因: \(context.underlyingError?.localizedDescription ?? "unknown")")
                case .keyNotFound(let key, let context):
                    print("   - 缺少键: \(key.stringValue)")
                    print("   - 上下文: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   - 类型不匹配: \(type)")
                    print("   - 上下文: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   - 值不存在: \(type)")
                    print("   - 上下文: \(context.debugDescription)")
                @unknown default:
                    print("   - 未知错误")
                }
            }
            
            throw ProfileError.fetchFailed(error.localizedDescription)
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
                .execute()
            
            let data = response.data
            let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
            
            if profiles.isEmpty {
                throw ProfileError.updateFailed("No profile found with ID: \(profileId)")
            } else if profiles.count == 1 {
                let updatedProfile = profiles.first!
                print("✅ Profile updated successfully: \(updatedProfile.id)")
                return updatedProfile
            } else {
                print("⚠️ Multiple profiles updated, returning the first one")
                let updatedProfile = profiles.first!
                print("✅ Profile updated successfully: \(updatedProfile.id)")
                return updatedProfile
            }
            
        } catch {
            print("❌ Failed to update profile: \(error.localizedDescription)")
            
            // 如果是 JSON 解析错误，尝试使用 maybeSingle
            if error.localizedDescription.contains("Cannot coerce") || 
               error.localizedDescription.contains("single JSON object") {
                print("🔧 JSON coercion error in update, trying alternative approach...")
                
                do {
                    let response = try await client
                        .from(SupabaseTable.profiles.rawValue)
                        .update(profile)
                        .eq("id", value: profileId)
                        .select()
                        .limit(1)
                        .execute()
                    
                    let data = response.data
                    let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
                    
                    if profiles.isEmpty {
                        throw ProfileError.updateFailed("No profile found with ID: \(profileId)")
                    } else {
                        let updatedProfile = profiles.first!
                        print("✅ Profile updated successfully with limit(1): \(updatedProfile.id)")
                        return updatedProfile
                    }
                    
                } catch {
                    print("❌ Alternative update approach also failed: \(error.localizedDescription)")
                    throw ProfileError.updateFailed(error.localizedDescription)
                }
            }
            
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
    
    /// 获取推荐用户列表（带分页和统计信息）
    func getRecommendedProfiles(userId: String, limit: Int = 20, offset: Int = 0) async throws -> ([SupabaseProfile], totalInBatch: Int, filteredCount: Int) {
        print("🔍 Fetching recommended profiles for user: \(userId), limit: \(limit), offset: \(offset)")
        
        do {
            // 获取需要排除的用户ID集合（所有在 Sent 和 Matches 中出现过的用户）
            var excludedUserIds: Set<String> = []
            
            // 1. 排除所有已发送邀请的用户（所有状态）
            do {
                let sentInvitations = try await getSentInvitations(userId: userId)
                for invitation in sentInvitations {
                    excludedUserIds.insert(invitation.receiverId)
                }
                print("🔍 Excluding \(sentInvitations.count) users with sent invitations (all statuses: pending, accepted, rejected, cancelled)")
            } catch {
                print("⚠️ Failed to fetch sent invitations for filtering: \(error.localizedDescription)")
                // 如果获取失败，不应该继续，因为这可能导致重复推荐
                throw error
            }
            
            // 2. 排除所有已匹配的用户（包括活跃和非活跃的匹配）
            do {
                // 获取所有匹配（包括非活跃的），因为即使匹配被取消，也不应该再推荐
                let allMatches = try await getMatches(userId: userId, activeOnly: false)
                for match in allMatches {
                    if match.userId == userId {
                        excludedUserIds.insert(match.matchedUserId)
                    } else if match.matchedUserId == userId {
                        excludedUserIds.insert(match.userId)
                    }
                }
                print("🔍 Excluding \(allMatches.count) matched users (all matches, including inactive)")
            } catch {
                print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
                // 如果获取失败，不应该继续，因为这可能导致重复推荐
                throw error
            }
            
            // 构建查询（Supabase PostgREST 使用 range header 进行分页）
            // 注意：由于 Supabase Swift 客户端限制，无法在查询中直接排除多个用户ID
            // 我们只在查询时排除当前用户，然后在客户端过滤其他需要排除的用户
            let query = client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .neq("user_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit * 3 - 1) // 多获取一些，以便过滤后仍有足够的结果
            
            if !excludedUserIds.isEmpty {
                print("🔍 Will exclude \(excludedUserIds.count) users from recommendations (client-side filtering)")
                print("   - Users in Sent list: \(excludedUserIds.count)")
                print("   - These users will NOT appear in recommendations")
            }
            
            let response = try await query.execute()
            
            let data = response.data
            
            // 打印原始响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📋 Raw response data (first 500 chars): \(String(responseString.prefix(500)))")
            }
            
            // 尝试解码
            do {
                let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
                
                // 客户端过滤：严格排除所有在 Sent 和 Matches 中出现过的用户
                let filteredProfiles = profiles.filter { profile in
                    let shouldExclude = excludedUserIds.contains(profile.userId)
                    if shouldExclude {
                        print("⚠️ Filtering out user \(profile.userId) - appears in Sent or Matches")
                    }
                    return !shouldExclude
                }
                
                // 只返回请求的数量（如果过滤后还有足够的结果）
                let finalProfiles = Array(filteredProfiles.prefix(limit))
                let totalFiltered = profiles.count - filteredProfiles.count
                
                if totalFiltered > 0 {
                    print("🔍 Filtered out \(totalFiltered) profiles (users in Sent/Matches lists)")
                }
                
                print("✅ Fetched \(finalProfiles.count) recommended profiles (offset: \(offset), excluded: \(excludedUserIds.count) users from Sent/Matches)")
                return (finalProfiles, profiles.count, totalFiltered)
            } catch let decodingError as DecodingError {
                // 详细解析解码错误
                print("❌ Decoding error details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  - Missing key: \(key.stringValue)")
                    print("  - Context: \(context.debugDescription)")
                    print("  - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .valueNotFound(let type, let context):
                    print("  - Missing value for type: \(type)")
                    print("  - Context: \(context.debugDescription)")
                    print("  - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .typeMismatch(let type, let context):
                    print("  - Type mismatch for type: \(type)")
                    print("  - Context: \(context.debugDescription)")
                    print("  - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                case .dataCorrupted(let context):
                    print("  - Data corrupted")
                    print("  - Context: \(context.debugDescription)")
                @unknown default:
                    print("  - Unknown decoding error: \(decodingError)")
                }
                
                // 尝试解析为 JSON 数组，检查每条记录
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("📊 Found \(jsonArray.count) records in response")
                    var validProfiles: [SupabaseProfile] = []
                    
                    for (index, record) in jsonArray.enumerated() {
                        print("  Record \(index + 1):")
                        print("    - Has core_identity: \(record["core_identity"] != nil)")
                        print("    - Has professional_background: \(record["professional_background"] != nil)")
                        print("    - Has networking_intention: \(record["networking_intention"] != nil)")
                        print("    - Has networking_preferences: \(record["networking_preferences"] != nil)")
                        print("    - Has personality_social: \(record["personality_social"] != nil)")
                        print("    - Has privacy_trust: \(record["privacy_trust"] != nil)")
                        
                        // 检查是否为 null
                        var hasNullFields = false
                        if record["core_identity"] == nil || record["core_identity"] as? NSNull != nil {
                            print("    ⚠️ core_identity is null or missing!")
                            hasNullFields = true
                        }
                        if record["professional_background"] == nil || record["professional_background"] as? NSNull != nil {
                            print("    ⚠️ professional_background is null or missing!")
                            hasNullFields = true
                        }
                        if record["networking_intention"] == nil || record["networking_intention"] as? NSNull != nil {
                            print("    ⚠️ networking_intention is null or missing!")
                            hasNullFields = true
                        }
                        if record["networking_preferences"] == nil || record["networking_preferences"] as? NSNull != nil {
                            print("    ⚠️ networking_preferences is null or missing!")
                            hasNullFields = true
                        }
                        if record["personality_social"] == nil || record["personality_social"] as? NSNull != nil {
                            print("    ⚠️ personality_social is null or missing!")
                            hasNullFields = true
                        }
                        if record["privacy_trust"] == nil || record["privacy_trust"] as? NSNull != nil {
                            print("    ⚠️ privacy_trust is null or missing!")
                            hasNullFields = true
                        }
                        
                        // 尝试解码单个记录
                        if !hasNullFields {
                            do {
                                let recordData = try JSONSerialization.data(withJSONObject: record)
                                let profile = try JSONDecoder().decode(SupabaseProfile.self, from: recordData)
                                validProfiles.append(profile)
                                print("    ✅ Record \(index + 1) decoded successfully")
                            } catch {
                                print("    ❌ Record \(index + 1) failed to decode: \(error.localizedDescription)")
                            }
                        } else {
                            print("    ❌ Record \(index + 1) skipped due to null fields")
                        }
                    }
                    
                    let filteredCount = jsonArray.count - validProfiles.count
                    if !validProfiles.isEmpty {
                        print("✅ Successfully decoded \(validProfiles.count) out of \(jsonArray.count) profiles (filtered: \(filteredCount))")
                        return (validProfiles, jsonArray.count, filteredCount)
                    } else {
                        throw ProfileError.fetchFailed("All profiles failed to decode. Check database records for missing or null JSONB fields. Error: \(decodingError.localizedDescription)")
                    }
                }
                
                throw ProfileError.fetchFailed("Decoding failed: \(decodingError.localizedDescription). Check database records for missing or null JSONB fields.")
            }
            
        } catch {
            print("❌ Failed to fetch recommended profiles: \(error.localizedDescription)")
            throw ProfileError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// 获取推荐用户列表（向后兼容的旧方法）
    func getRecommendedProfiles(userId: String, limit: Int = 20) async throws -> [SupabaseProfile] {
        let (profiles, _, _) = try await getRecommendedProfiles(userId: userId, limit: limit, offset: 0)
        return profiles
    }
    
    /// 获取指定 Networking Intention 的推荐用户列表（带分页和统计信息）
    func getProfilesByNetworkingIntention(userId: String, intention: NetworkingIntentionType, limit: Int = 20, offset: Int = 0) async throws -> ([SupabaseProfile], totalInBatch: Int, filteredCount: Int) {
        print("🔍 Fetching profiles for intention: \(intention.rawValue), limit: \(limit), offset: \(offset)")
        
        do {
            // 获取需要排除的用户ID集合（所有在 Sent 和 Matches 中出现过的用户）
            var excludedUserIds: Set<String> = []
            
            // 1. 排除所有已发送邀请的用户（所有状态）
            do {
                let sentInvitations = try await getSentInvitations(userId: userId)
                for invitation in sentInvitations {
                    excludedUserIds.insert(invitation.receiverId)
                }
                print("🔍 Excluding \(sentInvitations.count) users with sent invitations")
            } catch {
                print("⚠️ Failed to fetch sent invitations for filtering: \(error.localizedDescription)")
                throw error
            }
            
            // 2. 排除所有已匹配的用户（包括非活跃的）
            do {
                let allMatches = try await getMatches(userId: userId, activeOnly: false)
                for match in allMatches {
                    if match.userId == userId {
                        excludedUserIds.insert(match.matchedUserId)
                    } else if match.matchedUserId == userId {
                        excludedUserIds.insert(match.userId)
                    }
                }
                print("🔍 Excluding \(allMatches.count) matched users from intention-based recommendations")
            } catch {
                print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
                throw error
            }
            
            // 构建查询（使用 JSONB 过滤）
            let query = client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .neq("user_id", value: userId)
                .eq("networking_intention->selected_intention", value: intention.rawValue)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit * 3 - 1) // 多获取一些，以便过滤后仍有足够的结果
            
            if !excludedUserIds.isEmpty {
                print("🔍 Will exclude \(excludedUserIds.count) users from intention recommendations (client-side filtering)")
            }
            
            let response = try await query.execute()
            
            let data = response.data
            
            // 尝试解码
            do {
                let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
                
                // 客户端过滤：严格排除所有在 Sent 和 Matches 中出现过的用户
                let filteredProfiles = profiles.filter { profile in
                    !excludedUserIds.contains(profile.userId)
                }
                
                // 只返回请求的数量（如果过滤后还有足够的结果）
                let finalProfiles = Array(filteredProfiles.prefix(limit))
                let totalFiltered = profiles.count - filteredProfiles.count
                
                if totalFiltered > 0 {
                    print("🔍 Filtered out \(totalFiltered) profiles (sent invitations/matches) from intention recommendations")
                }
                
                print("✅ Fetched \(finalProfiles.count) profiles for intention \(intention.rawValue) (offset: \(offset), excluded: \(excludedUserIds.count) users from Sent/Matches)")
                return (finalProfiles, profiles.count, totalFiltered)
            } catch let decodingError as DecodingError {
                // 详细解析解码错误
                print("❌ Decoding error details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  - Missing key: \(key.stringValue)")
                    print("  - Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("  - Missing value for type: \(type)")
                    print("  - Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("  - Type mismatch for type: \(type)")
                    print("  - Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("  - Data corrupted")
                    print("  - Context: \(context.debugDescription)")
                @unknown default:
                    print("  - Unknown decoding error: \(decodingError)")
                }
                
                // 尝试解析为 JSON 数组，检查每条记录
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("📊 Found \(jsonArray.count) records in response")
                    var validProfiles: [SupabaseProfile] = []
                    
                    for (index, record) in jsonArray.enumerated() {
                        // 尝试解码单个记录
                        do {
                            let recordData = try JSONSerialization.data(withJSONObject: record)
                            let profile = try JSONDecoder().decode(SupabaseProfile.self, from: recordData)
                            validProfiles.append(profile)
                            print("    ✅ Record \(index + 1) decoded successfully")
                        } catch {
                            print("    ❌ Record \(index + 1) failed to decode: \(error.localizedDescription)")
                        }
                    }
                    
                    let filteredCount = jsonArray.count - validProfiles.count
                    if !validProfiles.isEmpty {
                        print("✅ Successfully decoded \(validProfiles.count) out of \(jsonArray.count) profiles (filtered: \(filteredCount))")
                        return (validProfiles, jsonArray.count, filteredCount)
                    } else {
                        throw ProfileError.fetchFailed("All profiles failed to decode. Error: \(decodingError.localizedDescription)")
                    }
                }
                
                throw ProfileError.fetchFailed("Decoding failed: \(decodingError.localizedDescription)")
            }
            
        } catch {
            print("❌ Failed to fetch profiles by intention: \(error.localizedDescription)")
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
    
    /// 获取所有 Networking Intention 的用户数量映射
    /// 由于 JSONB 过滤可能不支持 .eq() 操作符，采用获取所有profiles后过滤的方式
    func getUserCountsByAllIntentions() async throws -> [String: Int] {
        print("🔍 Fetching user counts for all intentions")
        
        var counts: [String: Int] = [:]
        
        // Initialize counts to 0
        for intention in NetworkingIntentionType.allCases {
            counts[intention.rawValue] = 0
        }
        
        do {
            // Fetch a reasonable sample of profiles to count (or all if fewer than 10000)
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select("networking_intention")
                .limit(10000)
                .execute()
            
            let data = response.data
            
            // Parse JSON to extract networking_intention
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for record in jsonArray {
                    if let networkingIntentionJson = record["networking_intention"] as? [String: Any],
                       let selectedIntention = networkingIntentionJson["selected_intention"] as? String {
                        counts[selectedIntention, default: 0] += 1
                    }
                }
                
                print("✅ User counts from sample: \(counts)")
                return counts
            }
            
            print("⚠️ Could not parse profiles, returning 0 counts")
            return counts
            
        } catch {
            print("❌ Failed to fetch user counts: \(error.localizedDescription)")
            // Return 0 counts on error instead of throwing
            return counts
        }
    }
    
    /// 获取数据库中的总用户数量
    func getTotalUserCount() async throws -> Int {
        print("🔍 Fetching total user count")
        
        do {
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .select("id", head: false, count: .exact)
                .limit(1)
                .execute()
            
            // Get count from response headers
            if let countHeader = response.response.value(forHTTPHeaderField: "content-range") {
                // Parse count from header like "0-0/150" or "*/150"
                if let rangeEnd = countHeader.split(separator: "/").last, let count = Int(rangeEnd) {
                    print("✅ Total user count: \(count)")
                    return count
                }
            }
            
            // Fallback: decode and count
            let data = response.data
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("✅ Total user count from data: \(jsonArray.count)")
                return jsonArray.count
            }
            
            print("⚠️ Could not parse total count, returning 0")
            return 0
            
        } catch {
            print("❌ Failed to fetch total user count: \(error.localizedDescription)")
            // Return 0 on error instead of throwing
            return 0
        }
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
            // 同步用户数据
            let cloudUsers = try await getAllUsers()
            await MainActor.run {
                // 清空本地用户数据
                databaseManager?.clearAllUsers()
                
                // 重新创建用户数据
                for cloudUser in cloudUsers {
                    let _ = databaseManager?.createUser(
                        id: cloudUser.id,
                        email: cloudUser.email,
                        name: cloudUser.name,
                        phoneNumber: cloudUser.phoneNumber,
                        isGuest: cloudUser.isGuest,
                        profileSetupCompleted: cloudUser.profileSetupCompleted
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
    
    // MARK: - Invitation Operations
    
    /// 发送邀请
    func sendInvitation(senderId: String, receiverId: String, reasonForInterest: String?, senderProfile: InvitationProfile?) async throws -> SupabaseInvitation {
        print("📨 Sending invitation from \(senderId) to \(receiverId)")
        
        // 先检查是否已经存在pending的邀请
        do {
            let existingInvitations = try await getSentInvitations(userId: senderId)
            if let existingInvitation = existingInvitations.first(where: { 
                $0.receiverId == receiverId && $0.status == .pending 
            }) {
                print("ℹ️ Invitation already exists (pending), returning existing: \(existingInvitation.id)")
                return existingInvitation
            }
        } catch {
            print("⚠️ Error checking existing invitations: \(error.localizedDescription)")
            // 继续尝试发送，如果确实存在，会在插入时被捕获
        }
        
        // 创建可编码的邀请结构体
        struct InvitationInsert: Codable {
            let senderId: String
            let receiverId: String
            let status: String
            let reasonForInterest: String?
            let senderProfile: InvitationProfile?
            
            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case status
                case reasonForInterest = "reason_for_interest"
                case senderProfile = "sender_profile"
            }
        }
        
        let invitationInsert = InvitationInsert(
            senderId: senderId,
            receiverId: receiverId,
            status: InvitationStatus.pending.rawValue,
            reasonForInterest: reasonForInterest,
            senderProfile: senderProfile
        )
        
        do {
            let response = try await client
                .from(SupabaseTable.invitations.rawValue)
                .insert(invitationInsert)
                .select()
                .single()
                .execute()
            
            let data = response.data
            let createdInvitation = try JSONDecoder().decode(SupabaseInvitation.self, from: data)
            print("✅ Invitation sent successfully: \(createdInvitation.id)")
            return createdInvitation
        } catch {
            // 处理唯一约束冲突错误
            let errorMessage = error.localizedDescription
            if errorMessage.contains("duplicate key") || 
               errorMessage.contains("unique constraint") ||
               errorMessage.contains("already exists") {
                // 如果因为唯一约束失败，尝试获取已存在的邀请
                print("ℹ️ Duplicate invitation detected, fetching existing invitation...")
                do {
                    let existingInvitations = try await getSentInvitations(userId: senderId)
                    if let existingInvitation = existingInvitations.first(where: { 
                        $0.receiverId == receiverId && $0.status == .pending 
                    }) {
                        print("✅ Found existing invitation: \(existingInvitation.id)")
                        return existingInvitation
                    }
                } catch {
                    print("⚠️ Failed to fetch existing invitation: \(error.localizedDescription)")
                }
                throw InvitationError.alreadyExists("An invitation to this user already exists")
            }
            throw error
        }
    }
    
    /// 获取用户发送的所有邀请
    func getSentInvitations(userId: String) async throws -> [SupabaseInvitation] {
        print("🔍 Fetching sent invitations for user: \(userId)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select()
            .eq("sender_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        let invitations = try JSONDecoder().decode([SupabaseInvitation].self, from: data)
        print("✅ Found \(invitations.count) sent invitations")
        return invitations
    }
    
    /// 获取用户收到的所有邀请
    func getReceivedInvitations(userId: String) async throws -> [SupabaseInvitation] {
        print("🔍 Fetching received invitations for user: \(userId)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select()
            .eq("receiver_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        let invitations = try JSONDecoder().decode([SupabaseInvitation].self, from: data)
        print("✅ Found \(invitations.count) received invitations")
        return invitations
    }
    
    /// 获取待处理的邀请（收到的待处理邀请）
    func getPendingInvitations(userId: String) async throws -> [SupabaseInvitation] {
        print("🔍 Fetching pending invitations for user: \(userId)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select()
            .eq("receiver_id", value: userId)
            .eq("status", value: InvitationStatus.pending.rawValue)
            .order("created_at", ascending: false)
            .execute()
        
        let data = response.data
        let invitations = try JSONDecoder().decode([SupabaseInvitation].self, from: data)
        print("✅ Found \(invitations.count) pending invitations")
        return invitations
    }
    
    /// 接受邀请
    func acceptInvitation(invitationId: String, userId: String) async throws -> SupabaseInvitation {
        print("✅ Accepting invitation: \(invitationId)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .update(["status": InvitationStatus.accepted.rawValue])
            .eq("id", value: invitationId)
            .eq("receiver_id", value: userId)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let updatedInvitation = try JSONDecoder().decode(SupabaseInvitation.self, from: data)
        print("✅ Invitation accepted successfully")
        
        // 触发器会自动创建匹配记录，这里不需要手动创建
        return updatedInvitation
    }
    
    /// 拒绝邀请
    func rejectInvitation(invitationId: String, userId: String) async throws -> SupabaseInvitation {
        print("❌ Rejecting invitation: \(invitationId)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .update(["status": InvitationStatus.rejected.rawValue])
            .eq("id", value: invitationId)
            .eq("receiver_id", value: userId)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let updatedInvitation = try JSONDecoder().decode(SupabaseInvitation.self, from: data)
        print("✅ Invitation rejected successfully")
        return updatedInvitation
    }
    
    /// 取消邀请（发送者取消）
    func cancelInvitation(invitationId: String, userId: String) async throws {
        print("🚫 Cancelling invitation: \(invitationId)")
        
        try await client
            .from(SupabaseTable.invitations.rawValue)
            .update(["status": InvitationStatus.cancelled.rawValue])
            .eq("id", value: invitationId)
            .eq("sender_id", value: userId)
            .execute()
        
        print("✅ Invitation cancelled successfully")
    }
    
    /// 获取单个邀请
    func getInvitation(id: String) async throws -> SupabaseInvitation? {
        print("🔍 Fetching invitation: \(id)")
        
        let response = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        
        let data = response.data
        let invitation = try JSONDecoder().decode(SupabaseInvitation.self, from: data)
        print("✅ Invitation fetched successfully")
        return invitation
    }
    
    /// 检查是否是双向邀请（两个用户互相发送了邀请）
    func checkMutualInvitation(userId1: String, userId2: String) async throws -> Bool {
        print("🔍 Checking mutual invitation between \(userId1) and \(userId2)")
        
        // 检查 userId1 -> userId2 的邀请
        let response1 = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select("id")
            .eq("sender_id", value: userId1)
            .eq("receiver_id", value: userId2)
            .eq("status", value: InvitationStatus.pending.rawValue)
            .limit(1)
            .execute()
        
        let data1 = response1.data
        guard let jsonArray1 = try? JSONSerialization.jsonObject(with: data1) as? [[String: Any]],
              !jsonArray1.isEmpty else {
            return false
        }
        
        // 检查 userId2 -> userId1 的邀请
        let response2 = try await client
            .from(SupabaseTable.invitations.rawValue)
            .select("id")
            .eq("sender_id", value: userId2)
            .eq("receiver_id", value: userId1)
            .eq("status", value: InvitationStatus.pending.rawValue)
            .limit(1)
            .execute()
        
        let data2 = response2.data
        guard let jsonArray2 = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]],
              !jsonArray2.isEmpty else {
            return false
        }
        
        print("✅ Mutual invitation found!")
        return true
    }
    
    // MARK: - Match Operations
    
    /// 创建匹配（通常由系统自动创建，当邀请被接受时）
    func createMatch(userId: String, matchedUserId: String, matchedUserName: String, matchType: SupabaseMatchType = .invitationBased) async throws -> SupabaseMatch {
        print("💚 Creating match between \(userId) and \(matchedUserId)")
        
        // 检查是否已存在活跃的匹配
        let existingMatches = try await getMatches(userId: userId)
        if existingMatches.contains(where: { $0.matchedUserId == matchedUserId && $0.isActive }) {
            throw MatchError.alreadyExists("Match already exists between these users")
        }
        
        // 创建可编码的匹配结构体
        struct MatchInsert: Codable {
            let userId: String
            let matchedUserId: String
            let matchedUserName: String
            let matchType: String
            let isActive: Bool
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case matchedUserId = "matched_user_id"
                case matchedUserName = "matched_user_name"
                case matchType = "match_type"
                case isActive = "is_active"
            }
        }
        
        let matchInsert = MatchInsert(
            userId: userId,
            matchedUserId: matchedUserId,
            matchedUserName: matchedUserName,
            matchType: matchType.rawValue,
            isActive: true
        )
        
        let response = try await client
            .from(SupabaseTable.matches.rawValue)
            .insert(matchInsert)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let createdMatch = try JSONDecoder().decode(SupabaseMatch.self, from: data)
        print("✅ Match created successfully: \(createdMatch.id)")
        return createdMatch
    }
    
    /// 获取用户的所有匹配
    func getMatches(userId: String, activeOnly: Bool = true) async throws -> [SupabaseMatch] {
        print("🔍 Fetching matches for user: \(userId), activeOnly: \(activeOnly)")
        
        // 使用两个查询分别获取作为 user_id 和 matched_user_id 的匹配，然后合并
        var matches: [SupabaseMatch] = []
        
        // 获取作为 user_id 的匹配
        // 注意：必须在 order 之前调用所有 eq 过滤
        var query1 = client
            .from(SupabaseTable.matches.rawValue)
            .select()
            .eq("user_id", value: userId)
        
        if activeOnly {
            query1 = query1.eq("is_active", value: true)
        }
        
        let response1 = try await query1.order("created_at", ascending: false).execute()
        let data1 = response1.data
        let matches1 = try JSONDecoder().decode([SupabaseMatch].self, from: data1)
        matches.append(contentsOf: matches1)
        
        // 获取作为 matched_user_id 的匹配
        var query2 = client
            .from(SupabaseTable.matches.rawValue)
            .select()
            .eq("matched_user_id", value: userId)
        
        if activeOnly {
            query2 = query2.eq("is_active", value: true)
        }
        
        let response2 = try await query2.order("created_at", ascending: false).execute()
        let data2 = response2.data
        let matches2 = try JSONDecoder().decode([SupabaseMatch].self, from: data2)
        matches.append(contentsOf: matches2)
        
        // 去重并按创建时间排序
        let uniqueMatches = Array(Set(matches.map { $0.id })).compactMap { matchId in
            matches.first { $0.id == matchId }
        }
        let sortedMatches = uniqueMatches.sorted { match1, match2 in
            match1.createdAt > match2.createdAt
        }
        
        print("✅ Found \(sortedMatches.count) matches")
        return sortedMatches
    }
    
    /// 获取活跃匹配
    func getActiveMatches(userId: String) async throws -> [SupabaseMatch] {
        return try await getMatches(userId: userId, activeOnly: true)
    }
    
    /// 获取匹配统计
    func getMatchStats(userId: String) async throws -> (total: Int, active: Int, thisWeek: Int, thisMonth: Int) {
        print("📊 Fetching match stats for user: \(userId)")
        
        let allMatches = try await getMatches(userId: userId, activeOnly: false)
        let activeMatches = allMatches.filter { $0.isActive }
        
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
        
        let dateFormatter = ISO8601DateFormatter()
        
        let thisWeekMatches = allMatches.filter { match in
            if let createdAt = dateFormatter.date(from: match.createdAt) {
                return createdAt >= weekAgo
            }
            return false
        }
        
        let thisMonthMatches = allMatches.filter { match in
            if let createdAt = dateFormatter.date(from: match.createdAt) {
                return createdAt >= monthAgo
            }
            return false
        }
        
        let stats = (total: allMatches.count, active: activeMatches.count, thisWeek: thisWeekMatches.count, thisMonth: thisMonthMatches.count)
        print("✅ Match stats: total=\(stats.total), active=\(stats.active), thisWeek=\(stats.thisWeek), thisMonth=\(stats.thisMonth)")
        return stats
    }
    
    /// 取消匹配（设置为非活跃状态）
    func deactivateMatch(matchId: String, userId: String) async throws -> SupabaseMatch {
        print("🚫 Deactivating match: \(matchId)")
        
        // 先检查匹配是否存在且属于该用户
        guard let match = try await getMatch(id: matchId) else {
            throw MatchError.notFound("Match not found")
        }
        
        guard match.userId == userId || match.matchedUserId == userId else {
            throw MatchError.updateFailed("User does not have permission to deactivate this match")
        }
        
        let response = try await client
            .from(SupabaseTable.matches.rawValue)
            .update(["is_active": false])
            .eq("id", value: matchId)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let updatedMatch = try JSONDecoder().decode(SupabaseMatch.self, from: data)
        print("✅ Match deactivated successfully")
        return updatedMatch
    }
    
    /// 检查两个用户是否已匹配
    func checkMatchExists(userId1: String, userId2: String) async throws -> Bool {
        print("🔍 Checking if match exists between \(userId1) and \(userId2)")
        
        // 检查两个方向的匹配
        let response1 = try await client
            .from(SupabaseTable.matches.rawValue)
            .select("id")
            .eq("user_id", value: userId1)
            .eq("matched_user_id", value: userId2)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
        
        let data1 = response1.data
        if let jsonArray = try? JSONSerialization.jsonObject(with: data1) as? [[String: Any]], !jsonArray.isEmpty {
            print("✅ Match exists: true")
            return true
        }
        
        // 检查反向匹配
        let response2 = try await client
            .from(SupabaseTable.matches.rawValue)
            .select("id")
            .eq("user_id", value: userId2)
            .eq("matched_user_id", value: userId1)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
        
        let data2 = response2.data
        if let jsonArray = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]], !jsonArray.isEmpty {
            print("✅ Match exists: true")
            return true
        }
        
        print("✅ Match exists: false")
        return false
    }
    
    /// 获取单个匹配
    func getMatch(id: String) async throws -> SupabaseMatch? {
        print("🔍 Fetching match: \(id)")
        
        let response = try await client
            .from(SupabaseTable.matches.rawValue)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        
        let data = response.data
        let match = try JSONDecoder().decode(SupabaseMatch.self, from: data)
        print("✅ Match fetched successfully")
        return match
    }
    
    // MARK: - Message Operations
    
    /// 发送消息
    func sendMessage(senderId: String, receiverId: String, content: String, messageType: String = "text") async throws -> SupabaseMessage {
        print("📨 Sending message from \(senderId) to \(receiverId)")
        
        struct MessageInsert: Codable {
            let senderId: String
            let receiverId: String
            let content: String
            let messageType: String
            let isRead: Bool
            
            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case content
                case messageType = "message_type"
                case isRead = "is_read"
            }
        }
        
        let messageInsert = MessageInsert(
            senderId: senderId,
            receiverId: receiverId,
            content: content,
            messageType: messageType,
            isRead: false
        )
        
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .insert(messageInsert)
            .select()
            .single()
            .execute()
        
        let data = response.data
        let createdMessage = try JSONDecoder().decode(SupabaseMessage.self, from: data)
        print("✅ Message sent successfully: \(createdMessage.id)")
        return createdMessage
    }
    
    /// 获取两个用户之间的所有消息
    func getMessages(userId1: String, userId2: String) async throws -> [SupabaseMessage] {
        print("🔍 Fetching messages between \(userId1) and \(userId2)")
        
        // 获取所有消息：userId1 发送给 userId2 的，或 userId2 发送给 userId1 的
        // 使用 OR 查询
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .select()
            .or("sender_id.eq.\(userId1),receiver_id.eq.\(userId1)")
            .or("sender_id.eq.\(userId2),receiver_id.eq.\(userId2)")
            .order("timestamp", ascending: true)
            .execute()
        
        let data = response.data
        
        // 解析 JSON 数组
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ProfileError.fetchFailed("Failed to parse messages response")
        }
        
        var messages: [SupabaseMessage] = []
        for json in jsonArray {
            // 只包含涉及这两个用户的消息
            let senderId = json["sender_id"] as? String ?? ""
            let receiverId = json["receiver_id"] as? String ?? ""
            
            if (senderId == userId1 && receiverId == userId2) || 
               (senderId == userId2 && receiverId == userId1) {
                if let messageData = try? JSONSerialization.data(withJSONObject: json),
                   let message = try? JSONDecoder().decode(SupabaseMessage.self, from: messageData) {
                    messages.append(message)
                }
            }
        }
        
        print("✅ Found \(messages.count) messages between users")
        return messages
    }
    
    /// 将消息标记为已读
    func markMessageAsRead(messageId: String) async throws {
        print("✅ Marking message \(messageId) as read")
        
        try await client
            .from(SupabaseTable.messages.rawValue)
            .update(["is_read": true])
            .eq("id", value: messageId)
            .execute()
    }
    
    /// 获取未读消息数量
    func getUnreadMessageCount(userId: String) async throws -> Int {
        print("🔍 Getting unread message count for user: \(userId)")
        
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .select("id")
            .eq("receiver_id", value: userId)
            .eq("is_read", value: false)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return 0
        }
        
        return jsonArray.count
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

// MARK: - Match Error Types
enum MatchError: LocalizedError {
    case creationFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case alreadyExists(String)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create match: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch match: \(message)"
        case .updateFailed(let message):
            return "Failed to update match: \(message)"
        case .alreadyExists(let message):
            return "Match already exists: \(message)"
        case .notFound(let message):
            return "Match not found: \(message)"
        }
    }
}

// MARK: - Invitation Error Types
enum InvitationError: LocalizedError {
    case creationFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case alreadyExists(String)
    case notFound(String)
    case invalidStatus(String)
    
    var errorDescription: String? {
        switch self {
        case .creationFailed(let message):
            return "Failed to create invitation: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch invitation: \(message)"
        case .updateFailed(let message):
            return "Failed to update invitation: \(message)"
        case .alreadyExists(let message):
            return "Invitation already exists: \(message)"
        case .notFound(let message):
            return "Invitation not found: \(message)"
        case .invalidStatus(let message):
            return "Invalid invitation status: \(message)"
        }
    }
}

// MARK: - DatabaseManager Extensions
// 这些方法已移动到 DatabaseManager.swift 中
