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
