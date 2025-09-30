import Foundation
import SwiftUI
import AuthenticationServices

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let createdAt: Date
    let lastLoginAt: Date
    let isGuest: Bool // Whether it's a guest user
    
    init(id: String = UUID().uuidString, email: String, name: String, isGuest: Bool = false) {
        self.id = id
        self.email = email
        self.name = name
        self.createdAt = Date()
        self.lastLoginAt = Date()
        self.isGuest = isGuest
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
    private let databaseManager = DatabaseManager.shared
    
    init() {
        print("🚀 AuthManager initialized")
        // Check if there's saved user information
        checkAuthStatus()
    }
    
    // MARK: - Check Authentication Status
    private func checkAuthStatus() {
        print("🔍 Checking authentication status...")
        // Check locally stored user information
        if let userData = userDefaults.data(forKey: userKey),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
            print("✅ Found saved user: \(user.name)")
            self.currentUser = user
            self.authState = .authenticated(user)
        } else {
            print("❌ No saved user found, showing login screen")
            self.authState = .unauthenticated
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async -> Result<AppUser, AuthError> {
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Check if input is email or phone number
        let isEmail = isValidEmail(email)
        let isPhone = isValidPhoneNumber(email)
        
        guard isEmail || isPhone else {
            return .failure(.invalidEmail)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return .failure(.invalidCredentials)
        }
        
        // Check if user exists in database
        let userEntity: UserEntity?
        if isEmail {
            userEntity = databaseManager.getUserByEmail(email)
        } else {
            // For phone number, we store it as email in database
            let phoneEmail = "\(email)@brewnet.local"
            userEntity = databaseManager.getUserByEmail(phoneEmail)
        }
        
        guard let existingUser = userEntity else {
            return .failure(.invalidCredentials)
        }
        
        // Update last login time
        databaseManager.updateUserLastLogin(existingUser.id ?? "")
        
        // Convert to User model
        let user = AppUser(
            id: existingUser.id ?? UUID().uuidString,
            email: existingUser.email ?? "",
            name: existingUser.name ?? "",
            isGuest: existingUser.isGuest
        )
        
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    // MARK: - Guest Login
    func guestLogin() async -> Result<AppUser, AuthError> {
        print("🚀 Starting guest login process...")
        
        // Generate random guest name
        let guestNames = ["Coffee Lover", "BrewNet User", "Guest", "New Friend", "Coffee Enthusiast"]
        let randomName = guestNames.randomElement() ?? "Guest User"
        let guestId = "guest_\(UUID().uuidString.prefix(8))"
        
        // Create guest user in database
        let userEntity = databaseManager.createUser(
            id: guestId,
            email: "guest@brewnet.com",
            name: randomName,
            isGuest: true
        )
        
        let user = AppUser(
            id: guestId,
            email: "guest@brewnet.com",
            name: randomName,
            isGuest: true
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
            isGuest: false
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
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simple email format validation
        guard isValidEmail(email) else {
            return .failure(.invalidEmail)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return .failure(.invalidCredentials)
        }
        
        // Check if email already exists in database
        if let existingUser = databaseManager.getUserByEmail(email) {
            return .failure(.emailAlreadyExists)
        }
        
        // Create new user in database
        let userId = UUID().uuidString
        guard let userEntity = databaseManager.createUser(
            id: userId,
            email: email,
            name: name,
            isGuest: false
        ) else {
            return .failure(.unknownError)
        }
        
        // Convert to User model
        let user = AppUser(
            id: userEntity.id ?? userId,
            email: userEntity.email ?? email,
            name: userEntity.name ?? name,
            isGuest: false
        )
        
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    // MARK: - Register with Phone
    func registerWithPhone(phoneNumber: String, password: String, name: String) async -> Result<AppUser, AuthError> {
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Validate phone number format
        guard isValidPhoneNumber(phoneNumber) else {
            return .failure(.invalidPhoneNumber)
        }
        
        // Validate password length
        guard password.count >= 6 else {
            return .failure(.invalidCredentials)
        }
        
        // Check if phone already exists in database
        let phoneEmail = "\(phoneNumber)@brewnet.local"
        if let existingUser = databaseManager.getUserByEmail(phoneEmail) {
            return .failure(.phoneAlreadyExists)
        }
        
        // Create new user in database
        let userId = UUID().uuidString
        guard let userEntity = databaseManager.createUser(
            id: userId,
            email: phoneEmail,
            name: name,
            phoneNumber: phoneNumber,
            isGuest: false
        ) else {
            return .failure(.unknownError)
        }
        
        // Convert to User model
        let user = AppUser(
            id: userEntity.id ?? userId,
            email: userEntity.email ?? phoneEmail,
            name: userEntity.name ?? name,
            isGuest: false
        )
        
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    // MARK: - Logout
    func logout() {
        print("🚪 Starting logout...")
        
        // Clear current user
        currentUser = nil
        
        // Update authentication state
        authState = .unauthenticated
        
        // Clear saved user data
        clearUserData()
        
        print("✅ Logout completed")
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
        
        // Update authentication state
        authState = .authenticated(user)
        
        print("✅ Authentication state updated to: authenticated")
        print("👤 Current user: \(user.name)")
        
        // Save to local storage
        if let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: userKey)
            print("💾 User data saved to local storage")
        } else {
            print("❌ User data save failed")
        }
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
