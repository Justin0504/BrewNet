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
    
    // MARK: - Online Status Management (已移除)
    
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
    
    /// 更新用户的实时GPS位置
    func updateUserRealTimeLocation(userId: String, latitude: Double, longitude: Double) async throws {
        print("📍 [实时位置] 更新用户 \(userId) 的位置: (\(latitude), \(longitude))")
        do {
            // 创建一个符合 Encodable 的结构体
            struct LocationUpdate: Encodable {
                let latitude: Double
                let longitude: Double
                let updated_at: String
            }
            
            let update = LocationUpdate(
                latitude: latitude,
                longitude: longitude,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from(SupabaseTable.users.rawValue)
                .update(update)
                .eq("id", value: userId)
                .execute()
            print("✅ [实时位置] 位置更新成功")
        } catch {
            print("❌ [实时位置] 位置更新失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取用户的实时GPS位置
    func getUserRealTimeLocation(userId: String) async throws -> (latitude: Double, longitude: Double)? {
        do {
            let response = try await client
                .from(SupabaseTable.users.rawValue)
                .select("latitude, longitude")
                .eq("id", value: userId)
                .single()
                .execute()
            
            let data = response.data
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lat = json["latitude"] as? Double,
               let lon = json["longitude"] as? Double {
                print("✅ [实时位置] 获取到用户 \(userId) 的位置: (\(lat), \(lon))")
                return (latitude: lat, longitude: lon)
            } else {
                print("⚠️ [实时位置] 用户 \(userId) 没有实时位置信息")
                return nil
            }
        } catch {
            print("❌ [实时位置] 获取位置失败: \(error.localizedDescription)")
            // 如果字段不存在，返回 nil 而不是抛出错误
            if error.localizedDescription.contains("latitude") || error.localizedDescription.contains("longitude") {
                return nil
            }
            throw error
        }
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
            // 先尝试删除旧的头像文件（如果存在），避免 "resource already exists" 错误
            do {
                try await client.storage
                    .from("avatars")
                    .remove(paths: [filePath])
                print("🗑️ Removed existing avatar file")
            } catch {
                // 如果文件不存在，忽略错误（这是正常的）
                print("ℹ️ No existing avatar file to remove (this is OK)")
            }
            
            // 上传图片到 storage bucket
            // 注意：由于我们已经删除了旧文件，这里应该不会出现 "resource already exists" 错误
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
        
        // 使用手动构建字典的方式来避免类型转换错误
        do {
            // 编码各个 JSONB 字段为字典
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            let coreIdentityData = try encoder.encode(profile.coreIdentity)
            let professionalBackgroundData = try encoder.encode(profile.professionalBackground)
            let networkingIntentionData = try encoder.encode(profile.networkingIntention)
            let networkingPreferencesData = try encoder.encode(profile.networkingPreferences)
            let personalitySocialData = try encoder.encode(profile.personalitySocial)
            let privacyTrustData = try encoder.encode(profile.privacyTrust)
            
            // 将 Data 转换为字典（JSON 对象）
            guard let coreIdentity = try JSONSerialization.jsonObject(with: coreIdentityData) as? [String: Any],
                  let professionalBackground = try JSONSerialization.jsonObject(with: professionalBackgroundData) as? [String: Any],
                  let networkingIntention = try JSONSerialization.jsonObject(with: networkingIntentionData) as? [String: Any],
                  let networkingPreferences = try JSONSerialization.jsonObject(with: networkingPreferencesData) as? [String: Any],
                  let personalitySocial = try JSONSerialization.jsonObject(with: personalitySocialData) as? [String: Any],
                  let privacyTrust = try JSONSerialization.jsonObject(with: privacyTrustData) as? [String: Any] else {
                throw ProfileError.creationFailed("Failed to encode profile fields")
            }
            
            // 创建一个符合 Codable 的结构体来包装插入数据
            struct ProfileInsert: Codable {
                let user_id: String
                let core_identity: [String: AnyCodableValue]
                let professional_background: [String: AnyCodableValue]
                let networking_intention: [String: AnyCodableValue]
                let networking_preferences: [String: AnyCodableValue]
                let personality_social: [String: AnyCodableValue]
                let privacy_trust: [String: AnyCodableValue]
            }
            
            // 辅助类型：将 [String: Any] 转换为 [String: AnyCodableValue]
            enum AnyCodableValue: Codable {
                case string(String)
                case int(Int)
                case double(Double)
                case bool(Bool)
                case array([AnyCodableValue])
                case object([String: AnyCodableValue])
                case null
                
                init(_ value: Any) {
                    switch value {
                    case let string as String:
                        self = .string(string)
                    case let int as Int:
                        self = .int(int)
                    case let double as Double:
                        self = .double(double)
                    case let bool as Bool:
                        self = .bool(bool)
                    case let number as NSNumber:
                        // JSONSerialization 可能返回 NSNumber，需要转换为正确的类型
                        if CFGetTypeID(number) == CFBooleanGetTypeID() {
                            self = .bool(number.boolValue)
                        } else {
                            // 检查是否是浮点数：通过比较 doubleValue 和 intValue 是否相等
                            let doubleVal = number.doubleValue
                            let intVal = Double(number.intValue)
                            // 如果 double 值不等于 int 值，或者类型编码显示是浮点数，则使用 double
                            let objCType = String(cString: number.objCType)
                            if objCType.contains("f") || objCType.contains("d") || abs(doubleVal - intVal) > 0.0001 {
                                self = .double(doubleVal)
                            } else {
                                self = .int(number.intValue)
                            }
                        }
                    case let array as [Any]:
                        self = .array(array.map { AnyCodableValue($0) })
                    case let dict as [String: Any]:
                        self = .object(dict.mapValues { AnyCodableValue($0) })
                    default:
                        self = .null
                    }
                }
                
                func encode(to encoder: Encoder) throws {
                    var container = encoder.singleValueContainer()
                    switch self {
                    case .string(let value):
                        try container.encode(value)
                    case .int(let value):
                        try container.encode(value)
                    case .double(let value):
                        try container.encode(value)
                    case .bool(let value):
                        try container.encode(value)
                    case .array(let value):
                        try container.encode(value)
                    case .object(let value):
                        try container.encode(value)
                    case .null:
                        try container.encodeNil()
                    }
                }
            }
            
            // 转换字典值
            func convertDict(_ dict: [String: Any]) -> [String: AnyCodableValue] {
                return dict.mapValues { AnyCodableValue($0) }
            }
            
            let insertData = ProfileInsert(
                user_id: profile.userId,
                core_identity: convertDict(coreIdentity),
                professional_background: convertDict(professionalBackground),
                networking_intention: convertDict(networkingIntention),
                networking_preferences: convertDict(networkingPreferences),
                personality_social: convertDict(personalitySocial),
                privacy_trust: convertDict(privacyTrust)
            )
            
            print("🔄 Inserting profile with manual dictionary...")
            
            // 尝试编码 insertData 以验证格式
            do {
                let testEncoder = JSONEncoder()
                testEncoder.outputFormatting = .prettyPrinted
                let testData = try testEncoder.encode(insertData)
                if let testString = String(data: testData, encoding: .utf8) {
                    print("📤 Insert data preview: \(testString.prefix(500))...")
                }
            } catch {
                print("⚠️ Failed to encode insert data for preview: \(error)")
            }
                
            do {
                let response = try await client
                    .from(SupabaseTable.profiles.rawValue)
                    .insert(insertData)
                    .select()
                    .single()
                    .execute()
                
                print("📊 Response status: \(response.response.statusCode)")
                print("📦 Response data size: \(response.data.count) bytes")
                
                let data = response.data
                
                // 打印原始响应用于调试
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response JSON: \(responseString.prefix(1000))")
                }
                
                let createdProfile = try JSONDecoder().decode(SupabaseProfile.self, from: data)
                print("✅ Profile created successfully: \(createdProfile.id)")
                return createdProfile
            } catch let encodingError {
                print("❌ Failed to create profile: \(encodingError.localizedDescription)")
                
                // 如果是 DecodingError，打印更详细的信息
                if let decodingError = encodingError as? DecodingError {
                    print("🔍 Decoding error details:")
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch: expected \(type), path: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found: \(type), path: \(context.codingPath)")
                    case .keyNotFound(let key, let context):
                        print("   Key not found: \(key.stringValue), path: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   Data corrupted: \(context.debugDescription), path: \(context.codingPath)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                
                // 重新抛出错误以便外层处理
                throw encodingError
            }
            
            } catch {
            print("❌ Failed to create profile (outer catch): \(error.localizedDescription)")
            print("🔍 Error type: \(type(of: error))")
                
                // 如果是重复键错误，尝试更新
                if error.localizedDescription.contains("duplicate key value violates unique constraint") {
                    print("🔄 Profile already exists, updating instead...")
                    do {
                        let existingProfile = try await getProfile(userId: profile.userId)
                        if let existing = existingProfile {
                            return try await updateProfile(profileId: existing.id, profile: profile)
                        } else {
                            print("⚠️ Profile exists but couldn't be fetched, trying to update directly...")
                            // 如果获取失败，尝试直接更新（使用 userId 查询）
                            // 注意：这需要知道 profile ID，如果没有，我们需要先查询
                            throw ProfileError.creationFailed("Profile exists but couldn't be fetched for update")
                        }
                    } catch let fetchError {
                        print("❌ Failed to fetch existing profile for update: \(fetchError.localizedDescription)")
                        // 不要在这里重新抛出，让外层处理
                        throw ProfileError.creationFailed("Profile creation failed: \(error.localizedDescription). Also failed to fetch existing profile: \(fetchError.localizedDescription)")
                    }
                }
                
            // 检查是否是架构问题
            if error.localizedDescription.contains("core_identity") || 
               error.localizedDescription.contains("Could not find") ||
               error.localizedDescription.contains("schema cache") ||
               error.localizedDescription.contains("does not exist") ||
               error.localizedDescription.contains("profile_image") ||
               error.localizedDescription.contains("column") {
                print("🔧 Database schema issue detected. Please execute force_fix.sql script.")
                throw ProfileError.creationFailed("数据库架构问题：请执行 force_fix.sql 脚本修复数据库。")
            }
            
            throw ProfileError.creationFailed(error.localizedDescription)
        }
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
            
            // 尝试解码前，先验证 JSON 结构
            do {
                let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
                
                if profiles.isEmpty {
                    print("ℹ️ No profile found for user: \(userId)")
                    return nil
                } else if profiles.count == 1 {
                    let profile = profiles.first!
                    // Verify privacy_trust is loaded from database
                    print("✅ Profile fetched successfully: \(profile.id)")
                    print("🔒 Privacy Trust loaded - visibility_settings:")
                    print("   - company: \(profile.privacyTrust.visibilitySettings.company.rawValue)")
                    print("   - skills: \(profile.privacyTrust.visibilitySettings.skills.rawValue)")
                    print("   - interests: \(profile.privacyTrust.visibilitySettings.interests.rawValue)")
                    print("   - location: \(profile.privacyTrust.visibilitySettings.location.rawValue)")
                    print("   - timeslot: \(profile.privacyTrust.visibilitySettings.timeslot.rawValue)")
                    print("   - email: \(profile.privacyTrust.visibilitySettings.email.rawValue)")
                    print("   - phone_number: \(profile.privacyTrust.visibilitySettings.phoneNumber.rawValue)")
                    return profile
                } else {
                    print("⚠️ Multiple profiles found for user: \(userId), returning the first one")
                    let profile = profiles.first!
                    print("✅ Profile fetched successfully: \(profile.id)")
                    // Verify privacy_trust is loaded from database
                    print("🔒 Privacy Trust loaded - visibility_settings:")
                    print("   - company: \(profile.privacyTrust.visibilitySettings.company.rawValue)")
                    print("   - skills: \(profile.privacyTrust.visibilitySettings.skills.rawValue)")
                    print("   - interests: \(profile.privacyTrust.visibilitySettings.interests.rawValue)")
                    print("   - location: \(profile.privacyTrust.visibilitySettings.location.rawValue)")
                    print("   - timeslot: \(profile.privacyTrust.visibilitySettings.timeslot.rawValue)")
                    return profile
                }
            } catch let decodeError {
                // 解码失败，尝试打印原始 JSON 以诊断问题
                print("❌ Failed to decode profile data")
                
                // 尝试解析为通用字典，查看实际返回的数据结构
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstProfile = jsonObject.first {
                    print("🔍 原始 JSON 结构分析:")
                    print("   - 包含的键: \(firstProfile.keys.sorted())")
                    
                    // 检查必需字段是否存在
                    let requiredKeys = ["id", "user_id", "core_identity", "professional_background", 
                                       "networking_intention", "networking_preferences", 
                                       "personality_social", "privacy_trust", "created_at", "updated_at"]
                    for key in requiredKeys {
                        if firstProfile[key] == nil {
                            print("   ⚠️ 缺少必需字段: \(key)")
                        }
                    }
                    
                    // 打印缺失字段的详细信息
                    if let decodingError = decodeError as? DecodingError {
                        print("🔍 DecodingError 详情:")
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("   - 数据损坏: \(context.debugDescription)")
                            print("   - 原因: \(context.underlyingError?.localizedDescription ?? "unknown")")
                        case .keyNotFound(let key, let context):
                            print("   - 缺少键: \(key.stringValue)")
                            print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                            print("   - 上下文: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("   - 类型不匹配: 期望 \(type)")
                            print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                            print("   - 上下文: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("   - 值不存在: \(type)")
                            print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                            print("   - 上下文: \(context.debugDescription)")
                            // 检查该路径对应的实际值
                            var currentDict = firstProfile
                            for pathKey in context.codingPath {
                                if let key = pathKey.stringValue as String?,
                                   let nestedDict = currentDict[key] as? [String: Any] {
                                    currentDict = nestedDict
                                }
                            }
                            print("   - 实际值: \(currentDict)")
                        @unknown default:
                            print("   - 未知错误")
                        }
                    }
                }
                
                // 重新抛出解码错误
                throw decodeError
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
                    print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("   - 上下文: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   - 类型不匹配: \(type)")
                    print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("   - 上下文: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   - 值不存在: \(type)")
                    print("   - 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
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
        
        // 使用与 createProfile 相同的方法：Supabase Swift SDK 的 .update() 方法
        // 这样应该能避免 PostgREST 的类型转换问题
        do {
            // 编码各个 JSONB 字段为字典（与 createProfile 完全相同的方法）
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            
            let coreIdentityData = try encoder.encode(profile.coreIdentity)
            let professionalBackgroundData = try encoder.encode(profile.professionalBackground)
            let networkingIntentionData = try encoder.encode(profile.networkingIntention)
            let networkingPreferencesData = try encoder.encode(profile.networkingPreferences)
            let personalitySocialData = try encoder.encode(profile.personalitySocial)
            let privacyTrustData = try encoder.encode(profile.privacyTrust)
            
            // 将 Data 转换为字典（JSON 对象）
            guard let coreIdentity = try JSONSerialization.jsonObject(with: coreIdentityData) as? [String: Any],
                  let professionalBackground = try JSONSerialization.jsonObject(with: professionalBackgroundData) as? [String: Any],
                  let networkingIntention = try JSONSerialization.jsonObject(with: networkingIntentionData) as? [String: Any],
                  let networkingPreferences = try JSONSerialization.jsonObject(with: networkingPreferencesData) as? [String: Any],
                  let personalitySocial = try JSONSerialization.jsonObject(with: personalitySocialData) as? [String: Any],
                  let privacyTrust = try JSONSerialization.jsonObject(with: privacyTrustData) as? [String: Any] else {
                throw ProfileError.updateFailed("Failed to encode profile fields")
            }
            
            // 创建一个符合 Codable 的结构体来包装更新数据（与 createProfile 完全相同的结构）
            struct ProfileUpdate: Codable {
                let user_id: String
                let core_identity: [String: AnyCodableValue]
                let professional_background: [String: AnyCodableValue]
                let networking_intention: [String: AnyCodableValue]
                let networking_preferences: [String: AnyCodableValue]
                let personality_social: [String: AnyCodableValue]
                let privacy_trust: [String: AnyCodableValue]
            }
            
            // 辅助类型：将 [String: Any] 转换为 [String: AnyCodableValue]（与 createProfile 完全相同）
            enum AnyCodableValue: Codable {
                case string(String)
                case int(Int)
                case double(Double)
                case bool(Bool)
                case array([AnyCodableValue])
                case object([String: AnyCodableValue])
                case null
                
                init(_ value: Any) {
                    switch value {
                    case let string as String:
                        self = .string(string)
                    case let int as Int:
                        self = .int(int)
                    case let double as Double:
                        self = .double(double)
                    case let bool as Bool:
                        self = .bool(bool)
                    case let array as [Any]:
                        self = .array(array.map { AnyCodableValue($0) })
                    case let dict as [String: Any]:
                        self = .object(dict.mapValues { AnyCodableValue($0) })
                    default:
                        self = .null
                    }
                }
            }
            
            // 转换字典值
            func convertDict(_ dict: [String: Any]) -> [String: AnyCodableValue] {
                return dict.mapValues { AnyCodableValue($0) }
            }
            
            let updateData = ProfileUpdate(
                user_id: profile.userId,
                core_identity: convertDict(coreIdentity),
                professional_background: convertDict(professionalBackground),
                networking_intention: convertDict(networkingIntention),
                networking_preferences: convertDict(networkingPreferences),
                personality_social: convertDict(personalitySocial),
                privacy_trust: convertDict(privacyTrust)
            )
            
            print("🔄 Updating profile with SDK .update() method (same as createProfile)...")
            
            // 使用 Supabase Swift SDK 的 .update() 方法，与 createProfile 使用 .insert() 的方式一致
            let response = try await client
                .from(SupabaseTable.profiles.rawValue)
                .update(updateData)
                .eq("id", value: profileId)
                .select()
                .execute()
            
            let data = response.data
            let profiles = try JSONDecoder().decode([SupabaseProfile].self, from: data)
            
            if profiles.isEmpty {
                throw ProfileError.updateFailed("No profile found with ID: \(profileId)")
            } else if profiles.count == 1 {
                let updatedProfile = profiles.first!
                print("✅ Profile updated successfully via SDK: \(updatedProfile.id)")
                return updatedProfile
            } else {
                print("⚠️ Multiple profiles updated, returning the first one")
                let updatedProfile = profiles.first!
                print("✅ Profile updated successfully via SDK: \(updatedProfile.id)")
                return updatedProfile
            }
            
        } catch {
            print("❌ Failed to update profile via SDK: \(error.localizedDescription)")
            print("🔍 This is unexpected since createProfile uses the same method and works")
            
            // 如果 SDK 方法失败，尝试使用 RPC 函数作为 fallback
            print("🔧 Trying RPC function approach as fallback...")
            print("⚠️ Note: If this fails, the database may need the simple_update_profile function")
            
            do {
                // 编码各个 JSONB 字段为字典
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    
                    let coreIdentityData = try encoder.encode(profile.coreIdentity)
                    let professionalBackgroundData = try encoder.encode(profile.professionalBackground)
                    let networkingIntentionData = try encoder.encode(profile.networkingIntention)
                    let networkingPreferencesData = try encoder.encode(profile.networkingPreferences)
                    let personalitySocialData = try encoder.encode(profile.personalitySocial)
                    let privacyTrustData = try encoder.encode(profile.privacyTrust)
                    
                // 将 Data 转换为字典（JSON 对象）
                let coreIdentity = try JSONSerialization.jsonObject(with: coreIdentityData) as? [String: Any] ?? [:]
                let professionalBackground = try JSONSerialization.jsonObject(with: professionalBackgroundData) as? [String: Any] ?? [:]
                let networkingIntention = try JSONSerialization.jsonObject(with: networkingIntentionData) as? [String: Any] ?? [:]
                let networkingPreferences = try JSONSerialization.jsonObject(with: networkingPreferencesData) as? [String: Any] ?? [:]
                let personalitySocial = try JSONSerialization.jsonObject(with: personalitySocialData) as? [String: Any] ?? [:]
                let privacyTrust = try JSONSerialization.jsonObject(with: privacyTrustData) as? [String: Any] ?? [:]
                
                // 构建 RPC 参数 - 使用 Encodable 结构体
                // 注意：参数名必须与 SQL 函数中的参数名完全匹配
                struct RPCParams: Codable {
                    let profile_id_param: String
                    let user_id_param: String
                    let core_identity_param: AnyCodableValue
                    let professional_background_param: AnyCodableValue
                    let networking_intention_param: AnyCodableValue
                    let networking_preferences_param: AnyCodableValue
                    let personality_social_param: AnyCodableValue
                    let privacy_trust_param: AnyCodableValue
                }
                
                // 辅助类型：将 [String: Any] 转换为 Codable
                enum AnyCodableValue: Codable {
                    case string(String)
                    case int(Int)
                    case double(Double)
                    case bool(Bool)
                    case array([AnyCodableValue])
                    case object([String: AnyCodableValue])
                    case null
                        
                        init(_ value: Any) {
                            switch value {
                            case let string as String:
                            self = .string(string)
                            case let int as Int:
                            self = .int(int)
                            case let double as Double:
                            self = .double(double)
                            case let bool as Bool:
                            self = .bool(bool)
                            case let array as [Any]:
                            self = .array(array.map { AnyCodableValue($0) })
                        case let dict as [String: Any]:
                            self = .object(dict.mapValues { AnyCodableValue($0) })
                            default:
                            self = .null
                        }
                    }
                        
                        init(from decoder: Decoder) throws {
                            let container = try decoder.singleValueContainer()
                            if container.decodeNil() {
                                self = .null
                            } else if let string = try? container.decode(String.self) {
                                self = .string(string)
                            } else if let int = try? container.decode(Int.self) {
                                self = .int(int)
                            } else if let double = try? container.decode(Double.self) {
                                self = .double(double)
                            } else if let bool = try? container.decode(Bool.self) {
                                self = .bool(bool)
                        } else if let array = try? container.decode([AnyCodableValue].self) {
                                self = .array(array)
                        } else if let object = try? container.decode([String: AnyCodableValue].self) {
                                self = .object(object)
                            } else {
                                throw DecodingError.dataCorrupted(
                                    DecodingError.Context(
                                        codingPath: decoder.codingPath,
                                    debugDescription: "Cannot decode AnyCodableValue"
                                    )
                                )
                            }
                        }
                        
                        func encode(to encoder: Encoder) throws {
                            var container = encoder.singleValueContainer()
                            switch self {
                        case .string(let value):
                            try container.encode(value)
                        case .int(let value):
                            try container.encode(value)
                        case .double(let value):
                            try container.encode(value)
                        case .bool(let value):
                            try container.encode(value)
                        case .array(let value):
                            try container.encode(value)
                        case .object(let value):
                            try container.encode(value)
                        case .null:
                            try container.encodeNil()
                        }
                    }
                }
                
                // 转换字典值
                func convertDict(_ dict: [String: Any]) -> [String: AnyCodableValue] {
                    return dict.mapValues { AnyCodableValue($0) }
                }
                
                let rpcParams = RPCParams(
                    profile_id_param: profileId,
                    user_id_param: profile.userId,
                    core_identity_param: .object(convertDict(coreIdentity)),
                    professional_background_param: .object(convertDict(professionalBackground)),
                    networking_intention_param: .object(convertDict(networkingIntention)),
                    networking_preferences_param: .object(convertDict(networkingPreferences)),
                    personality_social_param: .object(convertDict(personalitySocial)),
                    privacy_trust_param: .object(convertDict(privacyTrust))
                )
                
                // 调试：打印 RPC 参数
                let debugEncoder = JSONEncoder()
                debugEncoder.outputFormatting = JSONEncoder.OutputFormatting.prettyPrinted
                if let paramsData = try? debugEncoder.encode(rpcParams),
                   let paramsString = String(data: paramsData, encoding: .utf8) {
                    print("📤 RPC params: \(paramsString.prefix(500))")
                }
                
                // 使用 HTTP 直接调用 RPC 函数，避免 PostgREST 的类型推断问题
                let config = SupabaseConfig.shared
                let supabaseURL = config.url
                let supabaseKey = config.key
                
                // 尝试使用简化版本的 RPC 函数
                // 如果 update_profile_jsonb 失败，可以尝试 update_profile_simple
                let rpcFunctionName = "update_profile_jsonb"
                
                // 如果原始函数失败，尝试使用简化函数
                // 首先构建完整的 profile JSON 字符串
                let profileDict: [String: Any] = [
                    "user_id": profile.userId,
                    "core_identity": coreIdentity,
                    "professional_background": professionalBackground,
                    "networking_intention": networkingIntention,
                    "networking_preferences": networkingPreferences,
                    "personality_social": personalitySocial,
                    "privacy_trust": privacyTrust
                ]
                
                let profileJsonData = try JSONSerialization.data(withJSONObject: profileDict, options: [])
                let profileJsonString = String(data: profileJsonData, encoding: .utf8) ?? "{}"
                
                // 构建 RPC 请求 URL
                guard let url = URL(string: "\(supabaseURL)/rest/v1/rpc/\(rpcFunctionName)") else {
                    throw ProfileError.updateFailed("Invalid RPC URL")
                }
                
                print("🔗 RPC URL: \(url.absoluteString)")
                
                // 创建请求
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                // 将 RPC 参数编码为 JSON
                // 注意：尝试使用不同的编码方式，避免 PostgREST 的类型推断问题
                // 将 JSONB 字段编码为 JSON 字符串，而不是对象
                // 这可能是 PostgREST 期望的格式
                // 重用已经编码好的 Data（已在上面定义）
                let coreIdentityJsonString = String(data: coreIdentityData, encoding: .utf8) ?? "{}"
                let professionalBackgroundJsonString = String(data: professionalBackgroundData, encoding: .utf8) ?? "{}"
                let networkingIntentionJsonString = String(data: networkingIntentionData, encoding: .utf8) ?? "{}"
                let networkingPreferencesJsonString = String(data: networkingPreferencesData, encoding: .utf8) ?? "{}"
                let personalitySocialJsonString = String(data: personalitySocialData, encoding: .utf8) ?? "{}"
                let privacyTrustJsonString = String(data: privacyTrustData, encoding: .utf8) ?? "{}"
                
                // 构建参数字典，使用 JSON 字符串
                // 注意：参数名使用 p_ 前缀，匹配 SQL 函数参数名
                let rpcParamsDict: [String: Any] = [
                    "p_profile_id": profileId,
                    "p_user_id": profile.userId,
                    "p_core_identity": coreIdentityJsonString,
                    "p_professional_background": professionalBackgroundJsonString,
                    "p_networking_intention": networkingIntentionJsonString,
                    "p_networking_preferences": networkingPreferencesJsonString,
                    "p_personality_social": personalitySocialJsonString,
                    "p_privacy_trust": privacyTrustJsonString
                ]
                
                let paramsData = try JSONSerialization.data(withJSONObject: rpcParamsDict, options: [])
                request.httpBody = paramsData
                
                // 调试：打印请求
                if let paramsString = String(data: paramsData, encoding: .utf8) {
                    print("📤 RPC HTTP request body: \(paramsString.prefix(500))")
                }
                
                // 执行请求
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // 检查响应
                if let httpResponse = response as? HTTPURLResponse {
                    print("📊 RPC HTTP Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("❌ RPC Error response: \(errorString)")
                            
                            // 如果仍然是类型转换错误，尝试使用简化函数
                            if errorString.contains("cannot cast type profiles to jsonb") {
                                print("🔧 Trying simplified RPC function...")
                                
                                // 尝试使用 update_profile_simple 函数
                                let simpleParamsDict: [String: Any] = [
                                    "profile_id_param": profileId,
                                    "profile_json": profileJsonString
                                ]
                                
                                let simpleParamsData = try JSONSerialization.data(withJSONObject: simpleParamsDict, options: [])
                                
                                guard let simpleUrl = URL(string: "\(supabaseURL)/rest/v1/rpc/update_profile_simple") else {
                                    throw ProfileError.updateFailed("Invalid simple RPC URL")
                                }
                                
                                var simpleRequest = URLRequest(url: simpleUrl)
                                simpleRequest.httpMethod = "POST"
                                simpleRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                                simpleRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
                                simpleRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                                simpleRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                                simpleRequest.httpBody = simpleParamsData
                                
                                let (simpleData, simpleResponse) = try await URLSession.shared.data(for: simpleRequest)
                                
                                if let simpleHttpResponse = simpleResponse as? HTTPURLResponse {
                                    if simpleHttpResponse.statusCode == 200 {
                                        let updatedProfile = try JSONDecoder().decode(SupabaseProfile.self, from: simpleData)
                                        print("✅ Profile updated successfully via simplified RPC: \(updatedProfile.id)")
                        return updatedProfile
                    }
                                }
                            }
                        }
                        throw ProfileError.updateFailed("RPC HTTP \(httpResponse.statusCode)")
                    }
                }
                
                // 解析响应 - RPC 函数返回单个 JSONB 对象
                let updatedProfile = try JSONDecoder().decode(SupabaseProfile.self, from: data)
                
                print("✅ Profile updated successfully via RPC HTTP: \(updatedProfile.id)")
                return updatedProfile
                
            } catch {
                print("❌ RPC function also failed: \(error.localizedDescription)")
                print("💡 Note: Make sure you have executed update_profile_rpc.sql in Supabase Dashboard")
                
                // 这是 PostgREST 的已知 bug，无法更新 JSONB 字段
                let errorMessage = """
                ❌ Profile update failed due to PostgREST bug: "cannot cast type profiles to jsonb"
                
                🔍 This is a known PostgREST issue when updating JSONB fields.
                
                💡 Possible solutions:
                1. Check PostgREST version in Supabase Dashboard (Settings → API)
                2. Use Supabase Edge Functions to update profiles (see PROFILE_UPDATE_FIX.md)
                3. Try updating PostgREST configuration
                4. As a temporary workaround, delete and recreate the profile
                
                📝 For now, the profile data has been saved locally but not synced to Supabase.
                """
                print(errorMessage)
                
                throw ProfileError.updateFailed("PostgREST bug: cannot cast type profiles to jsonb. See PROFILE_UPDATE_FIX.md for solutions.")
            }
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
            // 注意：这里不使用 created_at 排序，因为推荐系统会按推荐分数排序
            // 如果推荐系统没有结果，才使用默认排序
            let query = client
                .from(SupabaseTable.profiles.rawValue)
                .select()
                .neq("user_id", value: userId)
                // 移除 created_at 排序，让推荐系统控制排序
                // 如果推荐系统不可用，可以按随机或其他方式排序
                .order("updated_at", ascending: false) // 使用 updated_at 作为备用排序，而不是 created_at
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
    
    /// 获取临时消息（发送给我但还未匹配的消息）
    /// 临时消息是指：1. message_type 为 "temporary"，或 2. 在两个用户之间还没有匹配记录时的消息
    func getTemporaryMessages(receiverId: String) async throws -> [SupabaseMessage] {
        print("🔍 [临时消息] Fetching all temporary messages for receiver: \(receiverId)")
        
        // 获取所有发送给我的消息
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .select()
            .eq("receiver_id", value: receiverId)
            .order("timestamp", ascending: false)
            .execute()
        
        let data = response.data
        
        // 解析 JSON 数组
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ProfileError.fetchFailed("Failed to parse temporary messages response")
        }
        
        print("🔍 [临时消息] 查询到 \(jsonArray.count) 条发送给我的消息")
        
        var messages: [SupabaseMessage] = []
        for json in jsonArray {
            if let messageData = try? JSONSerialization.data(withJSONObject: json),
               let message = try? JSONDecoder().decode(SupabaseMessage.self, from: messageData) {
                messages.append(message)
            }
        }
        
        // 获取所有匹配记录
        var matchedUserIds: Set<String> = []
        do {
            let matches = try await getActiveMatches(userId: receiverId)
            for match in matches {
                if match.userId == receiverId {
                    matchedUserIds.insert(match.matchedUserId)
                } else if match.matchedUserId == receiverId {
                    matchedUserIds.insert(match.userId)
                }
            }
            print("🔍 [临时消息] 已匹配的用户: \(matchedUserIds)")
        } catch {
            print("⚠️ [临时消息] 检查匹配状态失败: \(error.localizedDescription)")
        }
        
        // 过滤临时消息
        var temporaryMessages: [SupabaseMessage] = []
        for message in messages {
            let senderId = message.senderId
            let isMatched = matchedUserIds.contains(senderId)
            
            // 如果消息类型是 "temporary"，或者未匹配时发送的消息，都视为临时消息
            if message.messageType == "temporary" {
                temporaryMessages.append(message)
                print("✅ [临时消息] 添加临时消息 (类型): \(message.content.prefix(30))...")
            } else if !isMatched {
                // 如果还未匹配，所有消息都视为临时消息
                temporaryMessages.append(message)
                print("✅ [临时消息] 添加临时消息 (未匹配): \(message.content.prefix(30))...")
            } else {
                print("ℹ️ [临时消息] 跳过已匹配后的消息: \(message.content.prefix(30))...")
            }
        }
        
        print("✅ [临时消息] 最终找到 \(temporaryMessages.count) 条临时消息")
        return temporaryMessages
    }
    
    /// 获取两个用户之间的所有临时消息（双向查询，类似 getMessages）
    /// 临时消息是指：1. message_type 为 "temporary"，或 2. 在两个用户之间还没有匹配记录时的消息
    /// 参数说明：userId1 和 userId2 是任意顺序的两个用户ID，方法会查询这两个用户之间的所有临时消息
    func getTemporaryMessagesFromSender(receiverId: String, senderId: String) async throws -> [SupabaseMessage] {
        // 使用更通用的参数名，因为这是双向查询
        let userId1 = receiverId
        let userId2 = senderId
        print("🔍 [临时消息] 开始双向查询: userId1=\(userId1), userId2=\(userId2)")
        
        // 检查是否已匹配
        var isMatched = false
        do {
            let matches = try await getActiveMatches(userId: userId1)
            isMatched = matches.contains { match in
                (match.userId == userId1 && match.matchedUserId == userId2) ||
                (match.userId == userId2 && match.matchedUserId == userId1)
            }
            print("🔍 [临时消息] 匹配状态: \(isMatched ? "已匹配" : "未匹配")")
        } catch {
            print("⚠️ [临时消息] 检查匹配状态失败: \(error.localizedDescription)")
        }
        
        // 如果已匹配，则没有临时消息（所有消息都是正常消息）
        if isMatched {
            print("ℹ️ [临时消息] 用户已匹配，返回空列表")
            return []
        }
        
        // 双向查询：获取两个用户之间的所有消息（无论谁发给谁）
        // 使用和 getMessages 完全相同的查询方式
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .select()
            .or("sender_id.eq.\(userId1),receiver_id.eq.\(userId1)")
            .or("sender_id.eq.\(userId2),receiver_id.eq.\(userId2)")
            .order("timestamp", ascending: true)
            .execute()
        
        let data = response.data
        
        // 解析 JSON 数组（使用和 getMessages 相同的解析方式）
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("❌ [临时消息] 解析响应失败")
            throw ProfileError.fetchFailed("Failed to parse temporary messages response")
        }
        
        print("🔍 [临时消息] 查询到 \(jsonArray.count) 条原始消息")
        
        var messages: [SupabaseMessage] = []
        for json in jsonArray {
            // 只包含涉及这两个用户的消息（和 getMessages 相同的过滤逻辑）
            let msgSenderId = json["sender_id"] as? String ?? ""
            let msgReceiverId = json["receiver_id"] as? String ?? ""
            
            // 确保消息只涉及这两个用户
            if (msgSenderId == userId1 && msgReceiverId == userId2) ||
               (msgSenderId == userId2 && msgReceiverId == userId1) {
                
                if let messageData = try? JSONSerialization.data(withJSONObject: json),
                   let message = try? JSONDecoder().decode(SupabaseMessage.self, from: messageData) {
                    
                    let messageType = message.messageType
                    print("🔍 [临时消息] 消息类型: \(messageType), 发送者: \(msgSenderId), 接收者: \(msgReceiverId), 内容: \(message.content.prefix(30))...")
                    
                    // 如果消息类型明确标记为 "temporary"，或者未匹配时发送的所有消息都视为临时消息
                    if messageType == "temporary" {
                        messages.append(message)
                        print("✅ [临时消息] 添加临时消息: \(message.content.prefix(30))...")
                    } else if !isMatched {
                        // 如果还未匹配，所有消息都视为临时消息
                        messages.append(message)
                        print("✅ [临时消息] 添加未匹配时的消息: \(message.content.prefix(30))...")
                    } else {
                        print("ℹ️ [临时消息] 跳过已匹配后的消息: \(message.content.prefix(30))...")
                    }
                }
            }
        }
        
        print("✅ [临时消息] 最终返回 \(messages.count) 条临时消息（双向）")
        return messages
    }
    
    /// 获取我发送的所有临时消息
    func getSentTemporaryMessages(senderId: String) async throws -> [SupabaseMessage] {
        print("🔍 [临时消息] Fetching sent temporary messages from sender: \(senderId)")
        
        let response = try await client
            .from(SupabaseTable.messages.rawValue)
            .select()
            .eq("sender_id", value: senderId)
            .eq("message_type", value: "temporary")
            .order("timestamp", ascending: false)
            .execute()
        
        let data = response.data
        
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ProfileError.fetchFailed("Failed to parse sent temporary messages response")
        }
        
        var messages: [SupabaseMessage] = []
        for json in jsonArray {
            if let messageData = try? JSONSerialization.data(withJSONObject: json),
               let message = try? JSONDecoder().decode(SupabaseMessage.self, from: messageData) {
                messages.append(message)
            }
        }
        
        print("✅ [临时消息] 找到 \(messages.count) 条我发送的临时消息")
        return messages
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

// MARK: - Two-Tower Recommendation Methods

extension SupabaseService {
    
    /// 获取用户特征
    func getUserFeatures(userId: String) async throws -> UserTowerFeatures? {
        print("🔍 Fetching user features for: \(userId)")
        
        let response = try await client
            .from("user_features")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
        
        let data = response.data
        let features = try JSONDecoder().decode(UserTowerFeatures.self, from: data)
        print("✅ Fetched user features successfully")
        return features
    }
    
    /// 获取需要排除的用户ID集合（用于推荐系统）
    /// 包括：已发送的 Invitations（所有状态）、已收到且被拒绝的 Invitations、已交互的用户（like/pass/match）
    func getExcludedUserIds(userId: String) async throws -> Set<String> {
        var excludedUserIds: Set<String> = []
        
        // 1. 排除所有已发送邀请的用户（所有状态：pending, accepted, rejected, cancelled）
        do {
            let sentInvitations = try await getSentInvitations(userId: userId)
            for invitation in sentInvitations {
                excludedUserIds.insert(invitation.receiverId)
            }
            print("🔍 Excluding \(sentInvitations.count) users with sent invitations (all statuses)")
        } catch {
            print("⚠️ Failed to fetch sent invitations for filtering: \(error.localizedDescription)")
        }
        
        // 2. 排除所有已收到且被拒绝的邀请的发送者
        do {
            let receivedInvitations = try await getReceivedInvitations(userId: userId)
            let rejectedInvitations = receivedInvitations.filter { $0.status == .rejected }
            for invitation in rejectedInvitations {
                excludedUserIds.insert(invitation.senderId)
            }
            print("🔍 Excluding \(rejectedInvitations.count) users with rejected invitations")
        } catch {
            print("⚠️ Failed to fetch received invitations for filtering: \(error.localizedDescription)")
        }
        
        // 3. 排除所有已匹配的用户（包括活跃和非活跃的匹配）
        do {
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
        }
        
        // 4. 排除所有已交互过的用户（like/pass/match）
        do {
            let response = try await client
                .from("user_interactions")
                .select("target_user_id,interaction_type")
                .eq("user_id", value: userId)
                .execute()
            
            let data = response.data
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let typeSet = Set(["like", "pass", "match"])
                for record in jsonArray {
                    if let interactionType = record["interaction_type"] as? String,
                       typeSet.contains(interactionType),
                       let targetUserId = record["target_user_id"] as? String {
                        excludedUserIds.insert(targetUserId)
                    }
                }
                print("🔍 Excluding users with interactions (like/pass/match)")
            }
        } catch {
            print("⚠️ Failed to fetch user interactions for filtering: \(error.localizedDescription)")
        }
        
        print("✅ Total excluded users: \(excludedUserIds.count)")
        
        // 详细诊断：显示排除原因统计
        var exclusionBreakdown: [String: Int] = [:]
        do {
            // 统计已发送邀请
            let sentInvitations = try await getSentInvitations(userId: userId)
            exclusionBreakdown["sent_invitations"] = sentInvitations.count
            
            // 统计已收到且被拒绝的邀请
            let receivedInvitations = try await getReceivedInvitations(userId: userId)
            let rejectedInvitations = receivedInvitations.filter { $0.status == .rejected }
            exclusionBreakdown["rejected_invitations"] = rejectedInvitations.count
            
            // 统计已匹配
            let allMatches = try await getMatches(userId: userId, activeOnly: false)
            exclusionBreakdown["matches"] = allMatches.count
            
            // 统计交互记录
            let response = try await client
                .from("user_interactions")
                .select("target_user_id,interaction_type")
                .eq("user_id", value: userId)
                .execute()
            
            if let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] {
                let typeSet = Set(["like", "pass", "match"])
                let interactions = jsonArray.filter { record in
                    if let interactionType = record["interaction_type"] as? String {
                        return typeSet.contains(interactionType)
                    }
                    return false
                }
                exclusionBreakdown["interactions"] = interactions.count
            }
        } catch {
            print("⚠️ Failed to get exclusion breakdown: \(error.localizedDescription)")
        }
        
        print("📊 Exclusion breakdown:")
        print("   - Sent invitations: \(exclusionBreakdown["sent_invitations", default: 0])")
        print("   - Rejected invitations: \(exclusionBreakdown["rejected_invitations", default: 0])")
        print("   - Matches: \(exclusionBreakdown["matches", default: 0])")
        print("   - Interactions: \(exclusionBreakdown["interactions", default: 0])")
        print("   - Total unique excluded: \(excludedUserIds.count)")
        
        return excludedUserIds
    }
    
    /// 获取所有候选用户特征（用于推荐）
    func getAllCandidateFeatures(
        excluding userId: String,
        limit: Int = 1000
    ) async throws -> [(userId: String, features: UserTowerFeatures)] {
        print("🔍 Fetching candidate features, excluding: \(userId), limit: \(limit)")
        
        // 首先检查 user_features 表中的总用户数
        do {
            let countResponse = try await client
                .from("user_features")
                .select("user_id", head: true, count: .exact)
                .neq("user_id", value: userId)
                .execute()
            
            if let count = countResponse.count {
                print("📊 Total users in user_features table (excluding current user): \(count)")
            }
        } catch {
            print("⚠️ Failed to count users in user_features: \(error.localizedDescription)")
        }
        
        let response = try await client
            .from("user_features")
            .select()
            .neq("user_id", value: userId)
            .limit(limit)
            .execute()
        
        let data = response.data
        
        // 解析为字典，包含 user_id 和 features
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var results: [(userId: String, features: UserTowerFeatures)] = []
            var failedDecodes = 0
            
            for record in jsonArray {
                if let userIdStr = record["user_id"] as? String {
                    do {
                        let recordData = try JSONSerialization.data(withJSONObject: record)
                        let features = try JSONDecoder().decode(UserTowerFeatures.self, from: recordData)
                    results.append((userIdStr, features))
                    } catch {
                        failedDecodes += 1
                        print("⚠️ Failed to decode features for user \(userIdStr): \(error.localizedDescription)")
                    }
                }
            }
            
            print("✅ Fetched \(results.count) candidate features (failed to decode: \(failedDecodes), total records: \(jsonArray.count))")
            
            if results.count == 0 && jsonArray.count > 0 {
                print("⚠️ Warning: All candidate features failed to decode!")
                print("   - Total records fetched: \(jsonArray.count)")
                print("   - Successfully decoded: \(results.count)")
                print("   - Failed to decode: \(failedDecodes)")
            }
            
            return results
        }
        
        print("⚠️ Failed to parse candidate features - no valid JSON array")
        return []
    }
    
    /// 记录用户交互
    func recordInteraction(
        userId: String,
        targetUserId: String,
        type: InteractionType
    ) async throws {
        print("📝 Recording interaction: \(userId) -> \(targetUserId), type: \(type)")
        
        struct InteractionInsert: Codable {
            let userId: String
            let targetUserId: String
            let interactionType: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case targetUserId = "target_user_id"
                case interactionType = "interaction_type"
            }
        }
        
        let insert = InteractionInsert(
            userId: userId,
            targetUserId: targetUserId,
            interactionType: type.rawValue
        )
        
        try await client
            .from("user_interactions")
            .insert(insert)
            .execute()
        
        print("✅ Interaction recorded")
    }
    
    /// 缓存推荐结果
    func cacheRecommendations(
        userId: String,
        recommendations: [String],
        scores: [Double],
        modelVersion: String = "baseline",
        expiresIn: TimeInterval = 300
    ) async throws {
        print("💾 Caching recommendations for: \(userId)")
        
        struct CacheInsert: Codable {
            let userId: String
            let recommendedUserIds: [String]
            let scores: [Double]
            let modelVersion: String
            let expiresAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case recommendedUserIds = "recommended_user_ids"
                case scores
                case modelVersion = "model_version"
                case expiresAt = "expires_at"
            }
        }
        
        let expiresDate = Date().addingTimeInterval(expiresIn)
        let formatter = ISO8601DateFormatter()
        
        let insert = CacheInsert(
            userId: userId,
            recommendedUserIds: recommendations,
            scores: scores,
            modelVersion: modelVersion,
            expiresAt: formatter.string(from: expiresDate)
        )
        
        try await client
            .from("recommendation_cache")
            .upsert(insert)
            .execute()
        
        print("✅ Recommendations cached")
    }
    
    /// 清除推荐缓存
    func clearRecommendationCache(userId: String) async throws {
        print("🗑️ Clearing recommendation cache for: \(userId)")
        
        // 删除该用户的所有推荐缓存记录
        try await client
            .from("recommendation_cache")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Recommendation cache cleared")
    }
    
    /// 获取缓存的推荐结果
    func getCachedRecommendations(userId: String) async throws -> ([String], [Double])? {
        print("🔍 Fetching cached recommendations for: \(userId)")
        
        let response = try await client
            .from("recommendation_cache")
            .select()
            .eq("user_id", value: userId)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .limit(1)
            .execute()
        
        let data = response.data
        
        // 尝试解析为数组
        struct CacheResult: Codable {
            let recommendedUserIds: [String]
            let scores: [Double]
            
            enum CodingKeys: String, CodingKey {
                case recommendedUserIds = "recommended_user_ids"
                case scores
            }
        }
        
        if let results = try? JSONDecoder().decode([CacheResult].self, from: data),
           let result = results.first {
            print("✅ Found cached recommendations: \(result.recommendedUserIds.count) users")
            return (result.recommendedUserIds, result.scores)
        }
        
        print("ℹ️ No cached recommendations found")
        return nil
    }
    
    /// 批量获取多个用户的 profiles（优化性能：使用并行请求）
    /// - Parameter userIds: 用户ID列表
    /// - Returns: Profile 字典，key 为 userId
    func getProfilesBatch(userIds: [String]) async throws -> [String: SupabaseProfile] {
        guard !userIds.isEmpty else {
            return [:]
        }
        
        print("📦 Batch fetching \(userIds.count) profiles (parallel requests)...")
        
        // 使用并行任务批量获取（大幅提升速度）
        // 使用 TaskGroup 进行并行请求，最多同时 10 个并发
        return await withTaskGroup(of: [String: SupabaseProfile].self, returning: [String: SupabaseProfile].self) { group in
            var allResults: [String: SupabaseProfile] = [:]
            let concurrencyLimit = 10
            
            // 分批处理，每批最多 10 个并发
            for i in stride(from: 0, to: userIds.count, by: concurrencyLimit) {
                let batch = Array(userIds[i..<min(i + concurrencyLimit, userIds.count)])
                
                group.addTask {
                    await withTaskGroup(of: (String, SupabaseProfile?).self, returning: [String: SupabaseProfile].self) { batchGroup in
                        var batchResults: [String: SupabaseProfile] = [:]
                        
                        for userId in batch {
                            batchGroup.addTask {
                                do {
                                    let profile = try await self.getProfile(userId: userId)
                                    return (userId, profile)
                                } catch {
                                    print("⚠️ Failed to fetch profile for \(userId): \(error.localizedDescription)")
                                    return (userId, nil)
                                }
                            }
                        }
                        
                        for await (id, profile) in batchGroup {
                            if let profile = profile {
                                batchResults[id] = profile
                            }
                        }
                        
                        return batchResults
                    }
                }
            }
            
            // 收集所有批次的结果
            for await batchResults in group {
                allResults.merge(batchResults) { (_, new) in new }
            }
            
            print("✅ Batch fetch complete: \(allResults.count)/\(userIds.count) profiles retrieved")
            return allResults
        }
    }
    
    // MARK: - Online Status Management (已移除)
    // 所有在线状态相关方法已删除
}

enum InteractionType: String, Codable {
    case like = "like"
    case pass = "pass"
    case match = "match"
}

// MARK: - Points System Functions
extension SupabaseService {
    /// 获取用户积分
    func getUserPoints(userId: String) async throws -> Int {
        print("🔍 [积分系统] 获取用户积分: \(userId)")
        
        // 从 coffee_chat_records 表计算总积分
        let response = try await client
            .from("coffee_chat_records")
            .select("points_earned")
            .eq("user_id", value: userId)
            .eq("status", value: "completed")
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return 0
        }
        
        let totalPoints = jsonArray.compactMap { json -> Int? in
            if let points = json["points_earned"] as? Int {
                return points
            } else if let pointsString = json["points_earned"] as? String {
                return Int(pointsString)
            }
            return nil
        }.reduce(0, +)
        
        print("✅ [积分系统] 用户 \(userId) 总积分: \(totalPoints)")
        return totalPoints
    }
    
    /// 获取 Coffee Chat 历史记录
    func getCoffeeChatHistory(userId: String) async throws -> [CoffeeChatRecord] {
        print("🔍 [积分系统] 获取 Coffee Chat 历史: \(userId)")
        
        let response = try await client
            .from("coffee_chat_records")
            .select()
            .eq("user_id", value: userId)
            .order("date", ascending: false)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var records: [CoffeeChatRecord] = []
        for json in jsonArray {
            guard let id = json["id"] as? String,
                  let partnerId = json["partner_id"] as? String,
                  let statusString = json["status"] as? String,
                  let status = CoffeeChatRecord.CoffeeChatStatus(rawValue: statusString) else {
                continue
            }
            
            let pointsEarned: Int
            if let points = json["points_earned"] as? Int {
                pointsEarned = points
            } else if let pointsString = json["points_earned"] as? String, let points = Int(pointsString) {
                pointsEarned = points
            } else {
                pointsEarned = 0
            }
            
            // 获取 partner 名称
            var partnerName = "Unknown"
            if let partnerProfile = try? await getProfile(userId: partnerId) {
                partnerName = partnerProfile.coreIdentity.name
            }
            
            // 解析日期
            var date = Date()
            if let dateString = json["date"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                date = formatter.date(from: dateString) ?? Date()
            }
            
            // 获取参与者头像
            var avatarURL: String? = nil
            if let profile = try? await getProfile(userId: partnerId) {
                avatarURL = profile.coreIdentity.profileImage
            }
            
            let record = CoffeeChatRecord(
                id: id,
                partnerId: partnerId,
                partnerName: partnerName,
                partnerAvatar: avatarURL,
                date: date,
                pointsEarned: pointsEarned,
                status: status
            )
            records.append(record)
        }
        
        print("✅ [积分系统] 找到 \(records.count) 条 Coffee Chat 记录")
        return records
    }
    
    /// 记录完成一次 Coffee Chat（双方确认后调用）
    func recordCoffeeChatCompletion(userId1: String, userId2: String) async throws {
        print("🔍 [积分系统] 记录 Coffee Chat 完成: \(userId1) 和 \(userId2)")
        
        let pointsEarned = 10 // 每次完成获得 10 积分
        let now = ISO8601DateFormatter().string(from: Date())
        
        // 为两个用户分别创建记录
        let record1: [String: String] = [
            "id": UUID().uuidString,
            "user_id": userId1,
            "partner_id": userId2,
            "date": now,
            "points_earned": String(pointsEarned),
            "status": "completed",
            "created_at": now,
            "updated_at": now
        ]
        
        let record2: [String: String] = [
            "id": UUID().uuidString,
            "user_id": userId2,
            "partner_id": userId1,
            "date": now,
            "points_earned": String(pointsEarned),
            "status": "completed",
            "created_at": now,
            "updated_at": now
        ]
        
        // 插入两条记录
        // 分别插入两条记录
        try await client
            .from("coffee_chat_records")
            .insert(record1)
            .execute()
        
        try await client
            .from("coffee_chat_records")
            .insert(record2)
            .execute()
        
        print("✅ [积分系统] Coffee Chat 记录已创建，双方各获得 \(pointsEarned) 积分")
    }
    
    /// 获取可兑换的奖励列表
    func getAvailableRewards() async throws -> [Reward] {
        print("🔍 [兑换系统] 获取可兑换奖励列表")
        
        let response = try await client
            .from("rewards")
            .select()
            .eq("is_active", value: true)
            .order("points_required", ascending: true)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var rewards: [Reward] = []
        for json in jsonArray {
            guard let id = json["id"] as? String,
                  let name = json["name"] as? String,
                  let description = json["description"] as? String,
                  let categoryString = json["category"] as? String,
                  let category = Reward.RewardCategory(rawValue: categoryString) else {
                continue
            }
            
            let pointsRequired: Int
            if let points = json["points_required"] as? Int {
                pointsRequired = points
            } else if let pointsString = json["points_required"] as? String, let points = Int(pointsString) {
                pointsRequired = points
            } else {
                pointsRequired = 0
            }
            
            let imageUrl = json["image_url"] as? String
            
            let reward = Reward(
                id: id,
                name: name,
                description: description,
                pointsRequired: pointsRequired,
                category: category,
                imageUrl: imageUrl
            )
            rewards.append(reward)
        }
        
        print("✅ [兑换系统] 找到 \(rewards.count) 个可用奖励")
        return rewards
    }
    
    /// 获取用户的兑换记录
    func getUserRedemptions(userId: String) async throws -> [RedemptionRecord] {
        print("🔍 [兑换系统] 获取用户兑换记录: \(userId)")
        
        let response = try await client
            .from("redemptions")
            .select()
            .eq("user_id", value: userId)
            .order("redeemed_at", ascending: false)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var records: [RedemptionRecord] = []
        for json in jsonArray {
            guard let id = json["id"] as? String,
                  let rewardId = json["reward_id"] as? String,
                  let statusString = json["status"] as? String,
                  let status = RedemptionRecord.RedemptionStatus(rawValue: statusString) else {
                continue
            }
            
            let pointsUsed: Int
            if let points = json["points_used"] as? Int {
                pointsUsed = points
            } else if let pointsString = json["points_used"] as? String, let points = Int(pointsString) {
                pointsUsed = points
            } else {
                pointsUsed = 0
            }
            
            // 获取奖励名称
            var rewardName = "Unknown Reward"
            if let rewardResponse = try? await client
                .from("rewards")
                .select("name")
                .eq("id", value: rewardId)
                .single()
                .execute() {
                let rewardData = rewardResponse.data
                if let rewardJson = try? JSONSerialization.jsonObject(with: rewardData) as? [String: Any],
                   let name = rewardJson["name"] as? String {
                    rewardName = name
                }
            }
            
            // 解析日期
            var date = Date()
            if let dateString = json["redeemed_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                date = formatter.date(from: dateString) ?? Date()
            }
            
            let record = RedemptionRecord(
                id: id,
                rewardId: rewardId,
                rewardName: rewardName,
                pointsUsed: pointsUsed,
                redeemedAt: date,
                status: status
            )
            records.append(record)
        }
        
        print("✅ [兑换系统] 找到 \(records.count) 条兑换记录")
        return records
    }
    
    /// 兑换奖励
    func redeemReward(userId: String, rewardId: String) async throws {
        print("🔍 [兑换系统] 用户 \(userId) 兑换奖励 \(rewardId)")
        
        // 1. 获取奖励信息
        let rewardResponse = try await client
            .from("rewards")
            .select()
            .eq("id", value: rewardId)
            .single()
            .execute()
        
        let rewardData = rewardResponse.data
        guard let rewardJson = try? JSONSerialization.jsonObject(with: rewardData) as? [String: Any] else {
            throw ProfileError.fetchFailed("Reward not found")
        }
        
        let pointsRequired: Int
        if let points = rewardJson["points_required"] as? Int {
            pointsRequired = points
        } else if let pointsString = rewardJson["points_required"] as? String, let points = Int(pointsString) {
            pointsRequired = points
        } else {
            throw ProfileError.fetchFailed("Reward points_required invalid")
        }
        
        // 2. 检查用户积分是否足够
        let userPoints = try await getUserPoints(userId: userId)
        guard userPoints >= pointsRequired else {
            throw ProfileError.fetchFailed("Insufficient points")
        }
        
        // 3. 创建兑换记录
        let now = ISO8601DateFormatter().string(from: Date())
        let redemption: [String: String] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "reward_id": rewardId,
            "points_used": String(pointsRequired),
            "status": "pending",
            "redeemed_at": now,
            "created_at": now,
            "updated_at": now
        ]
        
        try await client
            .from("redemptions")
            .insert(redemption)
            .execute()
        
        print("✅ [兑换系统] 兑换记录已创建，消耗 \(pointsRequired) 积分")
    }
    
    // MARK: - Coffee Chat Invitations
    
    /// 创建咖啡聊天邀请记录
    func createCoffeeChatInvitation(senderId: String, receiverId: String, senderName: String, receiverName: String) async throws -> String {
        print("📧 [咖啡聊天] 创建邀请: \(senderName) -> \(receiverName)")
        
        let invitationId = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        
        struct InvitationInsert: Codable {
            let id: String
            let senderId: String
            let receiverId: String
            let senderName: String
            let receiverName: String
            let status: String
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case senderName = "sender_name"
                case receiverName = "receiver_name"
                case status
                case createdAt = "created_at"
            }
        }
        
        let invitation = InvitationInsert(
            id: invitationId,
            senderId: senderId,
            receiverId: receiverId,
            senderName: senderName,
            receiverName: receiverName,
            status: "pending",
            createdAt: now
        )
        
        try await client
            .from("coffee_chat_invitations")
            .insert(invitation)
            .execute()
        
        print("✅ [咖啡聊天] 邀请已创建: \(invitationId)")
        return invitationId
    }
    
    /// 接受咖啡聊天邀请并创建日程
    func acceptCoffeeChatInvitation(invitationId: String, scheduledDate: Date, location: String, notes: String? = nil) async throws {
        print("✅ [咖啡聊天] 接受邀请: \(invitationId)")
        
        // 首先获取邀请信息
        let response = try await client
            .from("coffee_chat_invitations")
            .select()
            .eq("id", value: invitationId)
            .single()
            .execute()
        
        let data = response.data
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let senderId = json["sender_id"] as? String,
              let receiverId = json["receiver_id"] as? String else {
            throw ProfileError.fetchFailed("Failed to fetch invitation")
        }
        
        // 从 profile 获取双方的真实名字，确保一致性
        var senderName = json["sender_name"] as? String ?? "Unknown"
        var receiverName = json["receiver_name"] as? String ?? "Unknown"
        
        // 从 profile 获取发送者的名字
        if let senderProfile = try? await getProfile(userId: senderId) {
            senderName = senderProfile.coreIdentity.name
            print("✅ [咖啡聊天] 从 profile 获取发送者名字: \(senderName)")
        } else {
            print("⚠️ [咖啡聊天] 无法获取发送者 profile，使用邀请中的名字: \(senderName)")
        }
        
        // 从 profile 获取接收者的名字
        if let receiverProfile = try? await getProfile(userId: receiverId) {
            receiverName = receiverProfile.coreIdentity.name
            print("✅ [咖啡聊天] 从 profile 获取接收者名字: \(receiverName)")
        } else {
            print("⚠️ [咖啡聊天] 无法获取接收者 profile，使用邀请中的名字: \(receiverName)")
        }
        
        let now = ISO8601DateFormatter().string(from: Date())
        let dateString = ISO8601DateFormatter().string(from: scheduledDate)
        
        // 更新邀请状态
        try await client
            .from("coffee_chat_invitations")
            .update([
                "status": "accepted",
                "responded_at": now,
                "scheduled_date": dateString,
                "location": location,
                "notes": notes ?? ""
            ])
            .eq("id", value: invitationId)
            .execute()
        
        // 为发送者和接收者分别创建日程记录
        let scheduleId1 = UUID().uuidString
        let scheduleId2 = UUID().uuidString
        
        struct ScheduleInsert: Codable {
            let id: String
            let userId: String
            let participantId: String
            let participantName: String
            let scheduledDate: String
            let location: String
            let notes: String
            let createdAt: String
            
            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case participantId = "participant_id"
                case participantName = "participant_name"
                case scheduledDate = "scheduled_date"
                case location
                case notes
                case createdAt = "created_at"
            }
        }
        
        let schedule1 = ScheduleInsert(
            id: scheduleId1,
            userId: senderId,
            participantId: receiverId,
            participantName: receiverName,
            scheduledDate: dateString,
            location: location,
            notes: notes ?? "",
            createdAt: now
        )
        
        let schedule2 = ScheduleInsert(
            id: scheduleId2,
            userId: receiverId,
            participantId: senderId,
            participantName: senderName,
            scheduledDate: dateString,
            location: location,
            notes: notes ?? "",
            createdAt: now
        )
        
        // 插入两条日程记录
        try await client
            .from("coffee_chat_schedules")
            .insert(schedule1)
            .execute()
        
        try await client
            .from("coffee_chat_schedules")
            .insert(schedule2)
            .execute()
        
        print("✅ [咖啡聊天] 邀请已接受，日程已创建")
    }
    
    /// 拒绝咖啡聊天邀请
    func rejectCoffeeChatInvitation(invitationId: String) async throws {
        print("❌ [咖啡聊天] 拒绝邀请: \(invitationId)")
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        try await client
            .from("coffee_chat_invitations")
            .update([
                "status": "rejected",
                "responded_at": now
            ])
            .eq("id", value: invitationId)
            .execute()
        
        print("✅ [咖啡聊天] 邀请已拒绝")
    }
    
    /// 查找待处理的咖啡聊天邀请ID
    func findPendingInvitationId(senderId: String, receiverId: String) async throws -> String? {
        print("🔍 [咖啡聊天] 查找待处理的邀请: senderId=\(senderId), receiverId=\(receiverId)")
        
        let response = try await client
            .from("coffee_chat_invitations")
            .select("id")
            .eq("sender_id", value: senderId)
            .eq("receiver_id", value: receiverId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstInvitation = jsonArray.first,
              let invitationId = firstInvitation["id"] as? String else {
            print("⚠️ [咖啡聊天] 未找到待处理的邀请")
            return nil
        }
        
        print("✅ [咖啡聊天] 找到待处理的邀请ID: \(invitationId)")
        return invitationId
    }
    
    /// 获取用户的咖啡聊天日程列表
    func getCoffeeChatSchedules(userId: String) async throws -> [CoffeeChatSchedule] {
        print("📅 [咖啡聊天] 获取日程列表，用户ID: \(userId)")
        print("📅 [咖啡聊天] 用户ID类型: \(type(of: userId))")
        
        // 只查询 user_id 等于当前用户 ID 的记录
        // 因为每个用户都有自己的日程记录（在 acceptCoffeeChatInvitation 中为双方各创建一条）
        let response = try await client
            .from("coffee_chat_schedules")
            .select()
            .eq("user_id", value: userId)
            .order("scheduled_date", ascending: true)
            .execute()
        
        print("📅 [咖啡聊天] 查询响应状态码: \(response.status)")
        print("📅 [咖啡聊天] 响应数据大小: \(response.data.count) bytes")
        
        let data = response.data
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("❌ [咖啡聊天] JSON解析失败")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [咖啡聊天] 原始响应: \(jsonString)")
            }
            return []
        }
        
        print("📅 [咖啡聊天] 解析到 \(jsonArray.count) 条原始记录")
        
        // 使用 Set 来去重，确保同一个 schedule ID 只处理一次
        var seenScheduleIds = Set<String>()
        var schedules: [CoffeeChatSchedule] = []
        
        for (index, json) in jsonArray.enumerated() {
            print("📅 [咖啡聊天] 处理第 \(index + 1) 条记录")
            print("📅 [咖啡聊天] 记录内容: \(json)")
            
            guard let id = json["id"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 id")
                continue
            }
            
            // 检查是否已经处理过这个 schedule ID
            if seenScheduleIds.contains(id) {
                print("⚠️ [咖啡聊天] 跳过重复的 schedule ID: \(id)")
                continue
            }
            seenScheduleIds.insert(id)
            guard let recordUserId = json["user_id"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 user_id")
                continue
            }
            guard let participantId = json["participant_id"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 participant_id")
                continue
            }
            guard let participantName = json["participant_name"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 participant_name")
                continue
            }
            
            // 确定当前用户在这个 schedule 中的角色
            // 如果当前用户是 user_id，那么 participant 是对方
            // 如果当前用户是 participant_id，那么 participant 是 user_id（需要获取对方的名称）
            let isCurrentUserOwner = recordUserId == userId
            let actualParticipantId: String
            let actualParticipantName: String
            
            if isCurrentUserOwner {
                // 当前用户是 owner，participant 就是对方
                actualParticipantId = participantId
                // 从 profile 获取 participant 的真实名字，确保一致性
                if let participantProfile = try? await getProfile(userId: participantId) {
                    actualParticipantName = participantProfile.coreIdentity.name
                    print("✅ [咖啡聊天] 从 profile 获取 participant 名字: \(actualParticipantName)")
                } else {
                    // 如果无法获取，使用数据库中的名字作为后备
                    actualParticipantName = participantName
                    print("⚠️ [咖啡聊天] 无法获取 participant profile，使用数据库中的名字: \(actualParticipantName)")
                }
            } else {
                // 当前用户是 participant，需要获取 owner 的信息作为 participant
                actualParticipantId = recordUserId
                // 从 profile 获取 owner 的真实名字，确保一致性
                if let ownerProfile = try? await getProfile(userId: recordUserId) {
                    actualParticipantName = ownerProfile.coreIdentity.name
                    print("✅ [咖啡聊天] 从 profile 获取 owner 名字: \(actualParticipantName)")
                } else {
                    // 如果无法获取，使用 "Unknown"
                    actualParticipantName = "Unknown"
                    print("⚠️ [咖啡聊天] 无法获取 user_id \(recordUserId) 的名称，使用 Unknown")
                }
            }
            
            print("📅 [咖啡聊天] 当前用户角色: \(isCurrentUserOwner ? "owner" : "participant")")
            print("📅 [咖啡聊天] actualParticipantId: \(actualParticipantId)")
            print("📅 [咖啡聊天] actualParticipantName: \(actualParticipantName)")
            guard let location = json["location"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 location")
                continue
            }
            guard let dateString = json["scheduled_date"] as? String else {
                print("❌ [咖啡聊天] 第 \(index + 1) 条记录缺少 scheduled_date")
                continue
            }
            
            print("📅 [咖啡聊天] id: \(id)")
            print("📅 [咖啡聊天] participant_id: \(participantId)")
            print("📅 [咖啡聊天] participant_name: \(participantName)")
            print("📅 [咖啡聊天] location: \(location)")
            print("📅 [咖啡聊天] scheduled_date 字符串: \(dateString)")
            
            // 尝试多种日期格式
            var scheduledDate: Date?
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            scheduledDate = formatter.date(from: dateString)
            
            if scheduledDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                scheduledDate = formatter.date(from: dateString)
            }
            
            if scheduledDate == nil {
                let postgresFormatter = DateFormatter()
                postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                postgresFormatter.locale = Locale(identifier: "en_US_POSIX")
                postgresFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                scheduledDate = postgresFormatter.date(from: dateString)
            }
            
            guard let finalScheduledDate = scheduledDate else {
                print("❌ [咖啡聊天] 无法解析日期: \(dateString)")
                continue
            }
            
            print("✅ [咖啡聊天] 使用备用格式解析成功")
            
            let notes = json["notes"] as? String
            
            // 解析 ID
            let scheduleId: UUID
            if let uuid = UUID(uuidString: id) {
                scheduleId = uuid
            } else {
                print("⚠️ [咖啡聊天] ID格式无效，生成新UUID: \(id)")
                scheduleId = UUID()
            }
            
            // 解析创建时间
            var createdAt = Date()
            if let createdAtString = json["created_at"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                createdAt = formatter.date(from: createdAtString) ?? Date()
            }
            
            let hasMet = json["has_met"] as? Bool ?? false
            
            print("📅 [咖啡聊天] user_id: \(recordUserId), participant_id: \(participantId), 当前用户: \(userId)")
            print("📅 [咖啡聊天] isCurrentUserOwner: \(isCurrentUserOwner), hasMet: \(hasMet)")
            
            let schedule = CoffeeChatSchedule(
                id: scheduleId,
                userId: userId, // 当前用户的 ID
                participantId: actualParticipantId,
                participantName: actualParticipantName,
                scheduledDate: finalScheduledDate,
                location: location,
                notes: notes,
                createdAt: createdAt,
                hasMet: hasMet
            )
            schedules.append(schedule)
            print("✅ [咖啡聊天] 成功解析日程: \(actualParticipantName) at \(location) on \(dateString), hasMet: \(hasMet)")
        }
        
        print("✅ [咖啡聊天] 总共找到 \(schedules.count) 个有效日程")
        return schedules
    }
    
    /// 标记咖啡聊天日程为已见面
    func markCoffeeChatAsMet(scheduleId: String, currentUserId: String) async throws {
        print("✅ [咖啡聊天] 标记日程为已见面: \(scheduleId)")
        print("✅ [咖啡聊天] 当前用户ID: \(currentUserId)")
        print("✅ [咖啡聊天] scheduleId 类型: \(type(of: scheduleId))")
        
        do {
            // 创建一个符合 Encodable 的结构体
            struct HasMetUpdate: Encodable {
                let has_met: Bool
            }
            
            let update = HasMetUpdate(has_met: true)
            print("✅ [咖啡聊天] 准备更新，has_met = true")
            
            // 先检查记录是否存在以及当前用户是否有权限
            let checkResponse = try await client
                .from("coffee_chat_schedules")
                .select("id, user_id, participant_id, has_met")
                .eq("id", value: scheduleId)
                .execute()
            
            if let checkData = try? JSONSerialization.jsonObject(with: checkResponse.data) as? [[String: Any]],
               let record = checkData.first {
                let recordUserId = record["user_id"] as? String ?? "nil"
                let recordParticipantId = record["participant_id"] as? String ?? "nil"
                let recordHasMet = record["has_met"] as? Bool ?? false
                
                print("✅ [咖啡聊天] 找到记录:")
                print("   - id: \(record["id"] ?? "nil")")
                print("   - user_id: \(recordUserId)")
                print("   - participant_id: \(recordParticipantId)")
                print("   - 当前 has_met: \(recordHasMet)")
                print("   - 当前用户ID: \(currentUserId)")
                print("   - 用户是否匹配 user_id: \(currentUserId == recordUserId)")
                print("   - 用户是否匹配 participant_id: \(currentUserId == recordParticipantId)")
                
                // 检查权限
                if currentUserId != recordUserId && currentUserId != recordParticipantId {
                    print("❌ [咖啡聊天] 权限错误：当前用户不是 user_id 或 participant_id")
                    print("❌ [咖啡聊天] 这会导致 RLS 策略阻止更新")
                }
            } else {
                print("⚠️ [咖啡聊天] 未找到记录或无法解析，scheduleId: \(scheduleId)")
                if let checkString = String(data: checkResponse.data, encoding: .utf8) {
                    print("⚠️ [咖啡聊天] 检查响应: \(checkString)")
                }
            }
            
            // 执行更新
            print("🔄 [咖啡聊天] 开始执行更新查询...")
            let response = try await client
                .from("coffee_chat_schedules")
                .update(update)
                .eq("id", value: scheduleId)
                .execute()
            
            print("✅ [咖啡聊天] 更新请求已发送，响应状态码: \(response.status)")
            print("✅ [咖啡聊天] 响应数据大小: \(response.data.count) bytes")
            
            // 打印响应内容
            if let responseString = String(data: response.data, encoding: .utf8) {
                print("✅ [咖啡聊天] 响应内容: \(responseString)")
                
                // 检查响应是否为空数组（表示没有行被更新）
                if responseString == "[]" || responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                    print("❌ [咖啡聊天] 错误：更新响应为空数组，表示没有行被更新")
                    print("❌ [咖啡聊天] 这通常意味着：")
                    print("   1. RLS 策略阻止了更新")
                    print("   2. 没有找到匹配的记录")
                    print("   3. 当前用户没有权限更新这条记录")
                    throw NSError(domain: "CoffeeChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "更新失败：没有行被更新，可能是 RLS 策略阻止了更新"])
                }
            }
            
            // 检查状态码
            if response.status < 200 || response.status >= 300 {
                print("❌ [咖啡聊天] 更新失败，HTTP 状态码: \(response.status)")
                throw NSError(domain: "CoffeeChatError", code: 2, userInfo: [NSLocalizedDescriptionKey: "更新失败：HTTP 状态码 \(response.status)"])
            }
            
            // 等待一小段时间确保更新完成
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 验证更新是否成功：查询更新后的记录
            print("🔄 [咖啡聊天] 开始验证更新结果...")
            let verifyResponse = try await client
                .from("coffee_chat_schedules")
                .select("id, has_met")
                .eq("id", value: scheduleId)
                .execute()
            
            print("✅ [咖啡聊天] 验证查询完成，状态码: \(verifyResponse.status)")
            if let verifyString = String(data: verifyResponse.data, encoding: .utf8) {
                print("✅ [咖啡聊天] 验证响应内容: \(verifyString)")
            }
            
            if let verifyData = try? JSONSerialization.jsonObject(with: verifyResponse.data) as? [[String: Any]],
               let record = verifyData.first,
               let hasMet = record["has_met"] as? Bool {
                print("✅ [咖啡聊天] 验证更新结果: has_met = \(hasMet)")
                if !hasMet {
                    print("❌ [咖啡聊天] 错误：数据库中的 has_met 仍然是 false")
                    print("❌ [咖啡聊天] 可能的原因：")
                    print("   1. RLS 策略阻止了更新")
                    print("   2. 当前用户不是 user_id 或 participant_id")
                    print("   3. 数据库字段不存在或名称不匹配")
                    throw NSError(domain: "CoffeeChatError", code: 3, userInfo: [NSLocalizedDescriptionKey: "更新失败：数据库中的 has_met 仍然是 false"])
                } else {
                    print("✅ [咖啡聊天] 更新成功！has_met 已设置为 true")
                }
            } else {
                print("⚠️ [咖啡聊天] 无法验证更新结果")
                if let verifyString = String(data: verifyResponse.data, encoding: .utf8) {
                    print("⚠️ [咖啡聊天] 验证响应: \(verifyString)")
                }
                // 如果无法验证，仍然抛出错误以确保用户知道更新可能失败
                throw NSError(domain: "CoffeeChatError", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法验证更新结果"])
            }
            
            print("✅ [咖啡聊天] 日程已标记为已见面")
            
            // 获取 schedule 信息以确定双方用户和对应的另一条记录
            let scheduleResponse = try await client
                .from("coffee_chat_schedules")
                .select("user_id, participant_id, scheduled_date, location")
                .eq("id", value: scheduleId)
                .single()
                .execute()
            
            if let scheduleData = try? JSONSerialization.jsonObject(with: scheduleResponse.data) as? [String: Any],
               let userId = scheduleData["user_id"] as? String,
               let participantId = scheduleData["participant_id"] as? String,
               let scheduledDate = scheduleData["scheduled_date"] as? String,
               let location = scheduleData["location"] as? String {
                
                // 查找对应的另一条记录（user_id 和 participant_id 互换）
                // 同时匹配 scheduled_date 和 location 以确保是同一场 coffee chat
                print("🔄 [咖啡聊天] 查找对应的另一条记录...")
                print("   - 当前记录: user_id=\(userId), participant_id=\(participantId)")
                print("   - 查找: user_id=\(participantId), participant_id=\(userId)")
                
                let correspondingResponse = try await client
                    .from("coffee_chat_schedules")
                    .select("id, has_met")
                    .eq("user_id", value: participantId)
                    .eq("participant_id", value: userId)
                    .eq("scheduled_date", value: scheduledDate)
                    .eq("location", value: location)
                    .limit(1)
                    .execute()
                
                print("🔄 [咖啡聊天] 查找对应记录的响应状态码: \(correspondingResponse.status)")
                if let responseString = String(data: correspondingResponse.data, encoding: .utf8) {
                    print("🔄 [咖啡聊天] 查找对应记录的响应内容: \(responseString)")
                }
                
                if let correspondingData = try? JSONSerialization.jsonObject(with: correspondingResponse.data) as? [[String: Any]],
                   let correspondingId = correspondingData.first?["id"] as? String,
                   correspondingId != scheduleId {
                    
                    let currentHasMet = correspondingData.first?["has_met"] as? Bool ?? false
                    print("✅ [咖啡聊天] 找到对应的另一条记录: \(correspondingId), 当前 has_met: \(currentHasMet)")
                    
                    // 更新对应的另一条记录
                    // 注意：当前用户是 participant_id，所以可以更新这条记录（RLS 策略允许）
                    print("🔄 [咖啡聊天] 开始更新对应的另一条记录...")
                    print("   - 当前用户ID: \(currentUserId)")
                    print("   - 目标记录的 user_id: \(participantId)")
                    print("   - 目标记录的 participant_id: \(userId)")
                    print("   - 当前用户是 participant_id，应该可以更新")
                    
                    let correspondingUpdateResponse = try await client
                        .from("coffee_chat_schedules")
                        .update(update)
                        .eq("id", value: correspondingId)
                        .execute()
                    
                    print("✅ [咖啡聊天] 对应的另一条记录已更新，状态码: \(correspondingUpdateResponse.status)")
                    
                    // 验证更新是否成功
                    if let updateString = String(data: correspondingUpdateResponse.data, encoding: .utf8) {
                        print("✅ [咖啡聊天] 更新响应内容: \(updateString)")
                        
                        if updateString == "[]" || updateString.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
                            print("❌ [咖啡聊天] 警告：更新对应的另一条记录时响应为空数组")
                            print("❌ [咖啡聊天] 这可能是因为 RLS 策略阻止了更新")
                            print("❌ [咖啡聊天] 当前用户ID: \(currentUserId)")
                            print("❌ [咖啡聊天] 目标记录的 user_id: \(participantId)")
                            print("❌ [咖啡聊天] 如果当前用户不是目标记录的 user_id，RLS 可能会阻止更新")
                        }
                    }
                    
                    // 等待一小段时间后验证
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                    
                    let verifyCorrespondingResponse = try await client
                        .from("coffee_chat_schedules")
                        .select("id, has_met")
                        .eq("id", value: correspondingId)
                        .execute()
                    
                    if let verifyData = try? JSONSerialization.jsonObject(with: verifyCorrespondingResponse.data) as? [[String: Any]],
                       let verifyRecord = verifyData.first,
                       let verifyHasMet = verifyRecord["has_met"] as? Bool {
                        print("✅ [咖啡聊天] 验证对应的另一条记录: has_met = \(verifyHasMet)")
                        if !verifyHasMet {
                            print("❌ [咖啡聊天] 警告：对应的另一条记录的 has_met 仍然是 false")
                            print("❌ [咖啡聊天] 这可能是 RLS 策略问题，需要确保当前用户有权限更新对方的记录")
                        }
                    }
                } else {
                    print("⚠️ [咖啡聊天] 未找到对应的另一条记录")
                    if let correspondingData = try? JSONSerialization.jsonObject(with: correspondingResponse.data) as? [[String: Any]] {
                        print("⚠️ [咖啡聊天] 查询返回了 \(correspondingData.count) 条记录")
                        if let firstRecord = correspondingData.first {
                            print("⚠️ [咖啡聊天] 第一条记录的 id: \(firstRecord["id"] ?? "nil")")
                            print("⚠️ [咖啡聊天] 当前 scheduleId: \(scheduleId)")
                        }
                    }
                }
                
                // 更新双方的 credits（严格根据 hasMet 数量重新计算并同步）
                
                print("🔄 [积分] 开始同步双方 credits（基于 hasMet 数量）: user_id=\(userId), participant_id=\(participantId)")
                
                // 更新 user_id 的 credits（重新计算，不累加）
                do {
                    // 使用 getUserCredits 会自动根据 hasMet 数量同步 credits
                    let updatedCredits = try await getUserCredits(userId: userId)
                    print("✅ [积分] 用户 \(userId) 的 credits 已同步: \(updatedCredits)（基于 hasMet 数量）")
                } catch {
                    print("⚠️ [积分] 同步用户 \(userId) 的 credits 失败: \(error.localizedDescription)")
                }
                
                // 更新 participant_id 的 credits（重新计算，不累加）
                do {
                    // 使用 getUserCredits 会自动根据 hasMet 数量同步 credits
                    let updatedCredits = try await getUserCredits(userId: participantId)
                    print("✅ [积分] 用户 \(participantId) 的 credits 已同步: \(updatedCredits)（基于 hasMet 数量）")
                } catch {
                    print("⚠️ [积分] 同步用户 \(participantId) 的 credits 失败: \(error.localizedDescription)")
                }
                
                // 发送通知，触发 UI 刷新
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("UserCreditsUpdated"), object: nil)
                    print("🔄 [积分] 已发送积分更新通知")
                }
            } else {
                print("⚠️ [积分] 无法获取 schedule 信息，跳过 credits 更新")
            }
        } catch {
            print("❌ [咖啡聊天] 标记失败: \(error.localizedDescription)")
            print("❌ [咖啡聊天] 错误类型: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ [咖啡聊天] 错误域: \(nsError.domain)")
                print("❌ [咖啡聊天] 错误代码: \(nsError.code)")
                print("❌ [咖啡聊天] 错误信息: \(nsError.userInfo)")
            }
            throw error
        }
    }
    
    // MARK: - Credits Management
    
    /// 获取用户的 credits，并自动同步已 met 的 coffee chat 数量
    /// 严格根据 hasMet 的数量来计算和同步 credits
    func getUserCredits(userId: String) async throws -> Int {
        print("🔍 [积分] 获取用户 \(userId) 的 credits")
        
        // 获取已 met 的 coffee chat 数量（这是唯一真实来源）
        let allSchedules = try await getCoffeeChatSchedules(userId: userId)
        let metSchedules = allSchedules.filter { $0.hasMet }
        let expectedCredits = metSchedules.count * 10
        
        print("🔍 [积分] 已 met 的 coffee chat 数量: \(metSchedules.count)")
        print("🔍 [积分] 根据 hasMet 计算的期望 credits: \(expectedCredits)")
        
        // 获取数据库中的当前 credits
        let response = try await client
            .from("users")
            .select("credits")
            .eq("id", value: userId)
            .single()
            .execute()
        
        let data = response.data
        var currentCredits: Int = 0
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            currentCredits = json["credits"] as? Int ?? 0
            print("✅ [积分] 数据库中的当前 credits: \(currentCredits)")
        } else {
            print("⚠️ [积分] 无法解析 credits，使用默认值 0")
        }
        
        // 强制同步：无论 credits 是大于还是小于期望值，都更新到正确值
        if currentCredits != expectedCredits {
            print("🔄 [积分] credits 不匹配，强制同步更新...")
            print("   - 当前 credits: \(currentCredits)")
            print("   - 期望 credits（基于 hasMet）: \(expectedCredits)")
            print("   - 差异: \(currentCredits > expectedCredits ? "多" : "少") \(abs(currentCredits - expectedCredits))")
            
            // 直接设置 credits 为期望值（严格根据 hasMet 数量）
            try await setUserCredits(userId: userId, credits: expectedCredits)
            print("✅ [积分] credits 已强制同步: \(currentCredits) -> \(expectedCredits)")
            return expectedCredits
        } else {
            print("✅ [积分] credits 已同步，无需更新")
            return currentCredits
        }
    }
    
    /// 给用户添加 credits
    func addCreditsToUser(userId: String, amount: Int) async throws {
        print("🔄 [积分] 给用户 \(userId) 添加 \(amount) credits")
        
        // 先获取当前 credits
        let currentCredits = try await getUserCredits(userId: userId)
        let newCredits = currentCredits + amount
        
        // 更新 credits
        struct CreditsUpdate: Encodable {
            let credits: Int
        }
        
        let update = CreditsUpdate(credits: newCredits)
        
        let response = try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()
        
        print("✅ [积分] 用户 \(userId) 的 credits 已更新: \(currentCredits) -> \(newCredits)")
        
        // 验证更新
        if response.status < 200 || response.status >= 300 {
            print("❌ [积分] 更新失败，HTTP 状态码: \(response.status)")
            throw NSError(domain: "CreditsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "更新 credits 失败：HTTP 状态码 \(response.status)"])
        }
    }
    
    /// 设置用户的 credits（直接设置值，不累加）
    func setUserCredits(userId: String, credits: Int) async throws {
        print("🔄 [积分] 设置用户 \(userId) 的 credits 为 \(credits)")
        
        struct CreditsUpdate: Encodable {
            let credits: Int
        }
        
        let update = CreditsUpdate(credits: credits)
        
        let response = try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .execute()
        
        print("✅ [积分] 用户 \(userId) 的 credits 已设置为: \(credits)")
        
        // 验证更新
        if response.status < 200 || response.status >= 300 {
            print("❌ [积分] 更新失败，HTTP 状态码: \(response.status)")
            throw NSError(domain: "CreditsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "设置 credits 失败：HTTP 状态码 \(response.status)"])
        }
    }
    
    /// 同步用户的 credits 到数据库（严格根据 hasMet 数量计算）
    /// 这是 credits 更新的主要方法，确保 credits 始终与 hasMet 数量一致
    func syncUserCredits(userId: String) async throws -> Int {
        print("🔄 [积分] 同步用户 \(userId) 的 credits（基于 hasMet 数量）")
        return try await getUserCredits(userId: userId)
    }
}

// MARK: - DatabaseManager Extensions
// 这些方法已移动到 DatabaseManager.swift 中
