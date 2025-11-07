import Foundation
import SwiftUI
import AuthenticationServices
import Supabase

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let createdAt: Date
    let lastLoginAt: Date
    let isGuest: Bool // Whether it's a guest user
    let profileSetupCompleted: Bool // Whether profile setup is completed
    
    init(id: String = UUID().uuidString, email: String, name: String, isGuest: Bool = false, profileSetupCompleted: Bool = false) {
        self.id = id
        self.email = email
        self.name = name
        self.createdAt = Date()
        self.lastLoginAt = Date()
        self.isGuest = isGuest
        self.profileSetupCompleted = profileSetupCompleted
    }
}

// MARK: - Authentication State
enum AuthState {
    case loading
    case authenticated(AppUser)
    case unauthenticated
}

// MARK: - Authentication Manager
class AuthManager: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: AppUser?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "current_user"
    private weak var databaseManager: DatabaseManager?
    private weak var supabaseService: SupabaseService?
    private var hasCheckedAuth = false // 标记是否已经检查过认证状态
    
    init() {
        print("🚀 =========================================")
        print("🚀 AuthManager initialized")
        print("🚀 =========================================")
        print("TEST - AuthManager 初始化")
        print("🔍 [AuthManager] init() - supabaseService 初始值: \(supabaseService == nil ? "nil" : "已设置")")
        // 不在 init 中检查，等待依赖注入完成后再检查
        print("⚠️ [AuthManager] 注意：checkAuthStatus 将在依赖注入后调用")
    }
    
    // MARK: - Dependency Injection
    func setDependencies(databaseManager: DatabaseManager, supabaseService: SupabaseService) {
        print("🔧 [AuthManager] setDependencies 被调用")
        print("   - databaseManager: \(databaseManager)")
        print("   - supabaseService: \(supabaseService)")
        self.databaseManager = databaseManager
        self.supabaseService = supabaseService
        print("✅ [AuthManager] 依赖注入完成，supabaseService 已设置: \(self.supabaseService != nil)")
        
        // 依赖注入完成后，检查认证状态
        if !hasCheckedAuth {
            print("🔄 [AuthManager] 依赖注入完成，现在检查认证状态")
            hasCheckedAuth = true
            checkAuthStatus()
        }
    }
    
    // MARK: - Check Authentication Status
    private func checkAuthStatus() {
        print("🔍 [AuthManager] checkAuthStatus() 被调用")
        print("⚠️ [AuthManager] 自动登录功能已禁用，需要用户手动登录")
        // 不再检查 session 并自动登录，直接设置为未认证状态
        Task {
            await MainActor.run {
                self.authState = .unauthenticated
                print("✅ [AuthManager] 认证状态已设置为 unauthenticated（需要手动登录）")
            }
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async -> Result<AppUser, AuthError> {
        // Check if input is email or phone number
        let isEmail = isValidEmail(email)
        let _ = isValidPhoneNumber(email)
        
        guard isEmail else {
            return .failure(.invalidEmail)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return .failure(.invalidCredentials)
        }
        
        // 使用 Supabase 登录
        return await supabaseLogin(email: email, password: password)
    }
    
    /// 本地登录（测试模式）
    private func localLogin(email: String, password: String) async -> Result<AppUser, AuthError> {
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Check if input is email or phone number
        let isEmail = isValidEmail(email)
        let _ = isValidPhoneNumber(email)
        
        // Check if user exists in database
        let userEntity: UserEntity?
        if isEmail {
            userEntity = databaseManager?.getUserByEmail(email)
        } else {
            // For phone number, we store it as email in database
            let phoneEmail = "\(email)@brewnet.local"
            userEntity = databaseManager?.getUserByEmail(phoneEmail)
        }
        
        // 如果用户不存在，自动注册
        guard let existingUser = userEntity else {
            print("👤 用户不存在，自动注册新用户: \(email)")
            return await autoRegisterUser(email: email, password: password)
        }
        
        // Update last login time
        databaseManager?.updateUserLastLogin(existingUser.id ?? "")
        
        // Convert to User model
        let user = AppUser(
            id: existingUser.id ?? UUID().uuidString,
            email: existingUser.email ?? "",
            name: existingUser.name ?? "",
            isGuest: existingUser.isGuest,
            profileSetupCompleted: existingUser.profileSetupCompleted
        )
        
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    /// 自动注册用户（当用户不存在时）
    private func autoRegisterUser(email: String, password: String) async -> Result<AppUser, AuthError> {
        print("🔄 自动注册新用户: \(email)")
        
        // 从邮箱中提取用户名（@ 符号前的部分）
        let name = String(email.split(separator: "@").first ?? "User")
        
        // 调用本地注册方法
        return await localRegister(email: email, password: password, name: name)
    }
    
    /// 自动注册 Supabase 用户（当用户认证成功但缺少详细信息时）
    private func autoRegisterSupabaseUser(email: String, userId: String) async -> Result<AppUser, AuthError> {
        print("🔄 自动注册 Supabase 用户: \(email)")
        
        // 从邮箱中提取用户名
        let name = String(email.split(separator: "@").first ?? "User")
        
        // 创建 Supabase 用户详细信息
        let supabaseUser = SupabaseUser(
            id: userId,
            email: email,
            name: name,
            phoneNumber: nil,
            isGuest: false,
            profileImage: nil,
            bio: nil,
            company: nil,
            jobTitle: nil,
            location: nil,
            skills: nil,
            interests: nil,
            profileSetupCompleted: false,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            lastLoginAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        do {
            // 保存到 Supabase
            if let createdUser = try await supabaseService?.createUser(user: supabaseUser) {
                print("✅ Supabase 用户详细信息创建成功")
                
                let appUser = createdUser.toAppUser()
                
                await MainActor.run {
                    saveUser(appUser)
                }
                
                // 在线状态功能已移除
                
                return .success(appUser)
            } else {
                print("❌ 无法创建 Supabase 用户详细信息")
                return .failure(.unknownError)
            }
        } catch {
            print("❌ 创建 Supabase 用户详细信息失败: \(error)")
            return .failure(.unknownError)
        }
    }
    
    /// Supabase 登录
    private func supabaseLogin(email: String, password: String) async -> Result<AppUser, AuthError> {
        print("🚀 开始 Supabase 登录: \(email)")
        do {
            // 使用 Supabase 认证
            print("📡 正在连接 Supabase Auth...")
            let response = try await SupabaseConfig.shared.client.auth.signIn(
                email: email,
                password: password
            )
            
            print("✅ Supabase Auth 认证成功")
            let user = response.user
            print("👤 用户 ID: \(user.id.uuidString)")
            
            // 从 Supabase 获取用户详细信息
            print("📥 正在获取用户详细信息...")
            let supabaseUser = try await supabaseService?.getUser(id: user.id.uuidString)
            
            if let supabaseUser = supabaseUser {
                print("✅ 找到用户详细信息: \(supabaseUser.name)")
                let appUser = supabaseUser.toAppUser()
                
                // 额外检查：如果用户有 profile 数据，确保 profileSetupCompleted 为 true
                // 使用 try? 而不是 try 因为 profile 可能不存在（这是正常的）
                let hasProfile = (try? await supabaseService?.getProfile(userId: supabaseUser.id)) != nil
                let finalAppUser = AppUser(
                    id: appUser.id,
                    email: appUser.email,
                    name: appUser.name,
                    isGuest: appUser.isGuest,
                    profileSetupCompleted: appUser.profileSetupCompleted || hasProfile
                )
                
                await MainActor.run {
                    saveUser(finalAppUser)
                    print("✅ 用户登录成功: \(finalAppUser.name), profile completed: \(finalAppUser.profileSetupCompleted)")
                }
                
                // 在线状态功能已移除
                
                return .success(finalAppUser)
            } else {
                // 如果 Supabase 中没有用户详细信息，自动创建
                print("⚠️ Supabase 用户不存在详细信息，自动创建: \(email)")
                return await autoRegisterSupabaseUser(email: email, userId: user.id.uuidString)
            }
            
        } catch {
            print("❌ Supabase 登录失败:")
            print("🔍 错误类型: \(type(of: error))")
            print("📝 错误详情: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("🔢 错误代码: \(nsError.code)")
                print("📄 错误域: \(nsError.domain)")
                print("👤 错误信息: \(nsError.userInfo)")
            }
            
            // 根据错误类型返回更具体的错误信息
            if error.localizedDescription.contains("Invalid login credentials") ||
               error.localizedDescription.contains("Invalid password") ||
               error.localizedDescription.contains("invalid email") {
                return .failure(.invalidCredentials)
            } else if error.localizedDescription.contains("Email not confirmed") {
                return .failure(.invalidEmail)
            } else {
                return .failure(.networkError)
            }
        }
    }
    
    // MARK: - Guest Login
    func guestLogin() async -> Result<AppUser, AuthError> {
        print("🚀 Starting guest login process...")
        
        // Generate random guest name
        let guestNames = ["Coffee Lover", "BrewNet User", "Guest", "New Friend", "Coffee Enthusiast"]
        let randomName = guestNames.randomElement() ?? "Guest User"
        let guestId = "guest_\(UUID().uuidString.prefix(8))"
        
        // Create guest user in database
        let _ = databaseManager?.createUser(
            id: guestId,
            email: "guest@brewnet.com",
            name: randomName,
            isGuest: true,
            profileSetupCompleted: false
        )
        
        let user = AppUser(
            id: guestId,
            email: "guest@brewnet.com",
            name: randomName,
            isGuest: true,
            profileSetupCompleted: false
        )
        
        print("👤 Created guest user: \(user.name)")
        
        // Immediately update state, ensuring execution on main thread
        await MainActor.run {
            print("🔄 Preparing to update authentication state...")
            print("🔄 Current state: \(self.authState)")
            self.currentUser = user
            self.authState = .authenticated(user)
            print("✅ Authentication state updated to: authenticated")
            print("👤 Current user: \(user.name)")
            print("🔄 State update completed, should trigger UI refresh")
            print("🔄 Updated state: \(self.authState)")
        }
        
        print("✅ Guest login completed")
        return .success(user)
    }
    
    // MARK: - Quick Login (maintain backward compatibility)
    func quickLogin() async -> Result<AppUser, AuthError> {
        return await guestLogin()
    }
    
    // MARK: - Apple Sign In
    func signInWithApple(authorization: ASAuthorization) async -> Result<AppUser, AuthError> {
        print("🍎 Starting Apple Sign In...")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Failed to get Apple ID credential")
            return .failure(.unknownError)
        }
        
        // Get user ID (always available)
        let userID = appleIDCredential.user
        print("👤 Apple User ID: \(userID)")
        
        // Check if we have existing user data
        if let userData = userDefaults.data(forKey: "apple_user_\(userID)"),
           let savedUser = try? JSONDecoder().decode(AppUser.self, from: userData) {
            print("✅ Found existing Apple Sign In user: \(savedUser.name)")
            await MainActor.run {
                saveUser(savedUser)
            }
            return .success(savedUser)
        }
        
        // First time login - get user information from Apple
        let email = appleIDCredential.email ?? "\(userID)@privaterelay.appleid.com"
        
        // Construct full name
        var fullName = ""
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            fullName = "\(givenName) \(familyName)"
        } else if let givenName = appleIDCredential.fullName?.givenName {
            fullName = givenName
        } else {
            // If no name provided, use email prefix
            fullName = email.components(separatedBy: "@").first?.capitalized ?? "Apple User"
        }
        
        print("👤 Apple Sign In user info (first time):")
        print("   - User ID: \(userID)")
        print("   - Email: \(email)")
        print("   - Name: \(fullName)")
        
        // Create user object
        let user = AppUser(
            id: userID,
            email: email,
            name: fullName,
            isGuest: false,
            profileSetupCompleted: false
        )
        
        // Save user information (both to current user and Apple-specific storage)
        await MainActor.run {
            saveUser(user)
            // Also save to Apple-specific key for future logins
            if let userData = try? JSONEncoder().encode(user) {
                userDefaults.set(userData, forKey: "apple_user_\(userID)")
            }
        }
        
        print("✅ Apple Sign In completed successfully")
        return .success(user)
    }
    
    // MARK: - Register
    func register(email: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        print("🔐 开始注册流程")
        print("📧 邮箱: \(email)")
        print("👤 姓名: \(name)")
        
        // Simple email format validation
        guard isValidEmail(email) else {
            print("❌ 邮箱格式无效")
            return .failure(.invalidEmail)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            print("❌ 密码长度不足")
            return .failure(.invalidCredentials)
        }
        
        print("✅ 验证通过")
        print("🔧 使用 Supabase 注册")
        
        // 使用 Supabase 注册
        return await supabaseRegister(email: email, password: password, name: name)
    }
    
    /// 本地注册（测试模式）
    private func localRegister(email: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        print("📱 开始本地注册: \(email)")
        
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // 检查 databaseManager 是否可用
        guard let dbManager = databaseManager else {
            print("❌ DatabaseManager 不可用")
            return .failure(.unknownError)
        }
        
        print("✅ DatabaseManager 可用")
        
        // Check if email already exists in database
        if dbManager.getUserByEmail(email) != nil {
            print("⚠️ 邮箱已存在: \(email)")
            return .failure(.emailAlreadyExists)
        }
        
        print("✅ 邮箱可用，创建新用户")
        
        // Create new user in database
        let userId = UUID().uuidString
        guard let userEntity = dbManager.createUser(
            id: userId,
            email: email,
            name: name,
            isGuest: false,
            profileSetupCompleted: false
        ) else {
            print("❌ 创建用户实体失败")
            return .failure(.unknownError)
        }
        
        print("✅ 用户实体创建成功")
        
        // Convert to User model
        let user = AppUser(
            id: userEntity.id ?? userId,
            email: userEntity.email ?? email,
            name: userEntity.name ?? name,
            isGuest: false,
            profileSetupCompleted: false
        )
        
        print("✅ 本地注册成功: \(user.name)")
        
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    /// Supabase 注册
    private func supabaseRegister(email: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        do {
            print("🚀 开始 Supabase 注册: \(email)")
            print("🔗 使用 URL: https://jcxvdolcdifdghaibspy.supabase.co")
            
            // 使用 Supabase 注册
            let response = try await SupabaseConfig.shared.client.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            
            print("✅ Supabase 注册响应成功")
            print("👤 用户 ID: \(response.user.id.uuidString)")
            
            let user = response.user
            
            // 创建用户详细信息
            let supabaseUser = SupabaseUser(
                id: user.id.uuidString,
                email: email,
                name: name,
                phoneNumber: nil,
                isGuest: false,
                profileImage: nil,
                bio: nil,
                company: nil,
                jobTitle: nil,
                location: nil,
                skills: nil,
                interests: nil,
                profileSetupCompleted: false,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                lastLoginAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // 尝试保存到 Supabase
            do {
                if let createdUser = try await supabaseService?.createUser(user: supabaseUser) {
                    print("✅ 用户数据已保存到 Supabase")
                    
                    let appUser = createdUser.toAppUser()
                    
                    await MainActor.run {
                        saveUser(appUser)
                    }
                    
                    return .success(appUser)
                } else {
                    // supabaseService 为 nil
                    print("⚠️ Supabase 服务不可用")
                    return .failure(.unknownError)
                }
            } catch {
                // Supabase 数据库操作失败
                print("⚠️ Supabase 数据保存失败: \(error.localizedDescription)")
                throw error
            }
            
        } catch {
            print("❌ Supabase 注册失败:")
            print("🔍 错误类型: \(type(of: error))")
            print("📝 错误信息: \(error.localizedDescription)")
            
            // 根据错误类型返回更具体的错误信息
            if error.localizedDescription.contains("already registered") ||
               error.localizedDescription.contains("already exists") ||
               error.localizedDescription.contains("duplicate key") {
                return .failure(.emailAlreadyExists)
            } else if error.localizedDescription.contains("password") {
                return .failure(.invalidCredentials)
            } else if let httpError = error as? URLError {
                print("🌐 网络错误代码: \(httpError.code.rawValue)")
                return .failure(.networkError)
            } else {
                return .failure(.unknownError)
            }
        }
    }
    
    // MARK: - Register with Phone
    func registerWithPhone(phoneNumber: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        print("🔐 开始手机号注册流程")
        print("📱 手机号: \(phoneNumber)")
        print("👤 姓名: \(name)")
        
        // Validate phone number format
        guard isValidPhoneNumber(phoneNumber) else {
            print("❌ 手机号格式无效")
            return .failure(.invalidPhoneNumber)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            print("❌ 密码长度不足")
            return .failure(.invalidCredentials)
        }
        
        print("✅ 验证通过")
        print("🔧 使用 Supabase 手机号注册")
        
        // 使用 Supabase 手机号注册
        return await supabaseRegisterWithPhone(phoneNumber: phoneNumber, password: password, name: name)
    }
    
    /// Supabase 手机号注册
    private func supabaseRegisterWithPhone(phoneNumber: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        do {
            print("🚀 开始 Supabase 手机号注册: \(phoneNumber)")
            
            // 使用 Supabase 手机号注册
            let response = try await SupabaseConfig.shared.client.auth.signUp(
                phone: phoneNumber,
                password: password,
                data: ["name": .string(name)]
            )
            
            print("✅ Supabase 手机号注册响应成功")
            print("👤 用户 ID: \(response.user.id.uuidString)")
            
            let user = response.user
            
            // 创建用户详细信息（使用手机号作为标识）
            // 为手机号用户生成一个虚拟邮箱，因为 Supabase users 表的 email 是 NOT NULL
            let phoneEmail = "\(phoneNumber.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: ""))@phone.brewnet.local"
            
            let supabaseUser = SupabaseUser(
                id: user.id.uuidString,
                email: phoneEmail,
                name: name,
                phoneNumber: phoneNumber,
                isGuest: false,
                profileImage: nil,
                bio: nil,
                company: nil,
                jobTitle: nil,
                location: nil,
                skills: nil,
                interests: nil,
                profileSetupCompleted: false,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                lastLoginAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            // 保存到 Supabase
            do {
                if let createdUser = try await supabaseService?.createUser(user: supabaseUser) {
                    print("✅ 用户数据已保存到 Supabase")
                    
                    let appUser = createdUser.toAppUser()
                    
                    await MainActor.run {
                        saveUser(appUser)
                    }
                    
                    return .success(appUser)
                } else {
                    print("⚠️ Supabase 服务不可用")
                    return .failure(.unknownError)
                }
            } catch {
                print("⚠️ Supabase 数据保存失败: \(error.localizedDescription)")
                throw error
            }
            
        } catch {
            print("❌ Supabase 手机号注册失败:")
            print("🔍 错误类型: \(type(of: error))")
            print("📝 错误信息: \(error.localizedDescription)")
            
            // 根据错误类型返回更具体的错误信息
            if error.localizedDescription.contains("already registered") ||
               error.localizedDescription.contains("already exists") ||
               error.localizedDescription.contains("duplicate key") {
                return .failure(.phoneAlreadyExists)
            } else if error.localizedDescription.contains("password") {
                return .failure(.invalidCredentials)
            } else if let httpError = error as? URLError {
                print("🌐 网络错误代码: \(httpError.code.rawValue)")
                return .failure(.networkError)
            } else {
                return .failure(.unknownError)
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        print("🚪 Starting logout...")
        
        // 在线状态功能已移除，直接登出
        Task {
            // 从 Supabase 登出
            do {
                try await SupabaseConfig.shared.client.auth.signOut()
                print("✅ Supabase 登出成功")
            } catch {
                print("⚠️ Supabase 登出失败: \(error.localizedDescription)")
            }
            
            // 在主线程上清除用户数据和状态
            await MainActor.run {
                // Clear current user
                currentUser = nil
                
                // Update authentication state
                authState = .unauthenticated
                
                // Clear saved user data
                clearUserData()
                
                print("✅ Logout completed")
            }
        }
    }
    
    // MARK: - Clear User Data
    private func clearUserData() {
        userDefaults.removeObject(forKey: userKey)
        
        // Clear Apple Sign In data
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("apple_user_") {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        print("🗑️ User data cleared from UserDefaults")
    }
    
    // MARK: - Force Logout (for debugging)
    func forceLogout() {
        print("🔄 Force logout initiated...")
        logout()
    }
    
    // MARK: - Check if Current User is Guest
    func isCurrentUserGuest() -> Bool {
        return currentUser?.isGuest ?? false
    }
    
    // MARK: - Upgrade Guest to Regular User
    func upgradeGuestToRegular(email: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        guard let currentUser = currentUser, currentUser.isGuest else {
            return .failure(.unknownError)
        }
        
        // Register as regular user
        let result = await register(email: email, password: password, name: name)
        
        switch result {
        case .success(let newUser):
            print("✅ Guest upgraded to regular user: \(newUser.name)")
            return .success(newUser)
        case .failure(let error):
            print("❌ Failed to upgrade guest: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Save User
    private func saveUser(_ user: AppUser) {
        print("💾 Saving user: \(user.name)")
        
        // Update current user
        currentUser = user
        
        // 只有当 authState 不是 authenticated 状态时才更新
        // 避免在编辑 profile 时触发 ContentView 重新渲染
        if case .authenticated = authState {
            // 已经认证，只更新 currentUser，不改变 authState
            print("✅ User updated (already authenticated)")
        } else {
            // 更新认证状态
            authState = .authenticated(user)
            print("✅ Authentication state updated to: authenticated")
        }
        
        print("👤 Current user: \(user.name)")
        
        // Save to local storage
        if let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: userKey)
            print("💾 User data saved to local storage")
        } else {
            print("❌ User data save failed")
        }
    }
    
    /// Update profile setup completion status
    func updateProfileSetupCompleted(_ completed: Bool) {
        guard let user = currentUser else { return }
        
        let updatedUser = AppUser(
            id: user.id,
            email: user.email,
            name: user.name,
            isGuest: user.isGuest,
            profileSetupCompleted: completed
        )
        
        saveUser(updatedUser)
    }
    
    // MARK: - Validation Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Remove all non-digit characters
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        // Check if it's a valid length (7-15 digits)
        return digitsOnly.count >= 7 && digitsOnly.count <= 15
    }
    
    // Note: emailExists and phoneExists functions removed as they're now handled by database queries
}

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidEmail
    case invalidPhoneNumber
    case emailAlreadyExists
    case phoneAlreadyExists
    case networkError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email/phone or password"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .phoneAlreadyExists:
            return "An account with this phone number already exists"
        case .networkError:
            return "Network connection failed, please check your network settings"
        case .unknownError:
            return "Registration failed, please try again later"
        }
    }
}
