import Foundation
import SwiftUI

// MARK: - User Model
struct User: Codable, Identifiable {
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
    case authenticated(User)
    case unauthenticated
}

// MARK: - Authentication Manager
class AuthManager: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "current_user"
    
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
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            print("✅ Found saved user: \(user.name)")
            self.currentUser = user
            self.authState = .authenticated(user)
        } else {
            print("❌ No saved user found, showing login screen")
            self.authState = .unauthenticated
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async -> Result<User, AuthError> {
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Simple mock validation
        if email == "test@brewnet.com" && password == "123456" {
            let user = User(email: email, name: "Test User")
            await MainActor.run {
                saveUser(user)
            }
            return .success(user)
        } else if email == "admin@brewnet.com" && password == "admin123" {
            let user = User(email: email, name: "Administrator")
            await MainActor.run {
                saveUser(user)
            }
            return .success(user)
        } else {
            return .failure(.invalidCredentials)
        }
    }
    
    // MARK: - Guest Login
    func guestLogin() async -> Result<User, AuthError> {
        print("🚀 Starting guest login process...")
        
        // Generate random guest name
        let guestNames = ["Coffee Lover", "BrewNet User", "Guest", "New Friend", "Coffee Enthusiast"]
        let randomName = guestNames.randomElement() ?? "Guest User"
        let guestId = "guest_\(UUID().uuidString.prefix(8))"
        
        let user = User(
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
    func quickLogin() async -> Result<User, AuthError> {
        return await guestLogin()
    }
    
    // MARK: - Register
    func register(email: String, password: String, name: String) async -> Result<User, AuthError> {
        // Simulate network request delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simple email format validation
        guard isValidEmail(email) else {
            return .failure(.invalidEmail)
        }
        
        // Simulate successful registration
        let user = User(email: email, name: name)
        await MainActor.run {
            saveUser(user)
        }
        return .success(user)
    }
    
    // MARK: - Logout
    func logout() {
        print("🚪 Starting logout...")
        
        // Immediately clear all data
        userDefaults.removeObject(forKey: userKey)
        currentUser = nil
        authState = .unauthenticated
        
        print("✅ Authentication state updated to: unauthenticated")
        print("👤 Current user cleared")
        
        // Clear other related data
        clearUserData()
        
        print("🧹 User data cleared")
        print("🔄 Should navigate to login screen")
    }
    
    // MARK: - Clear User Data
    private func clearUserData() {
        // Clear user preferences
        userDefaults.removeObject(forKey: "user_preferences")
        userDefaults.removeObject(forKey: "last_login_time")
        userDefaults.removeObject(forKey: "app_launch_count")
        
        // Clear all related data
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.contains("user") || key.contains("auth") || key.contains("login") {
                userDefaults.removeObject(forKey: key)
                print("🗑️ Cleared data: \(key)")
            }
        }
        
        print("🧹 All user data cleared")
    }
    
    // MARK: - Debug Method: Force Clear All Data
    func forceLogout() {
        print("🔄 Force clearing all data...")
        userDefaults.removeObject(forKey: userKey)
        currentUser = nil
        authState = .unauthenticated
        clearUserData()
        print("✅ Force clear completed")
    }
    
    // MARK: - Check if Current User is Guest
    func isCurrentUserGuest() -> Bool {
        return currentUser?.isGuest ?? false
    }
    
    // MARK: - Upgrade Guest Account
    func upgradeGuestToRegular(email: String, password: String, name: String) async -> Result<User, AuthError> {
        guard let currentUser = currentUser, currentUser.isGuest else {
            return .failure(.unknownError)
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            return .failure(.invalidEmail)
        }
        
        // Simulate network request
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Create regular user
        let regularUser = User(
            id: currentUser.id, // Keep the same ID
            email: email,
            name: name,
            isGuest: false
        )
        
        await MainActor.run {
            saveUser(regularUser)
        }
        return .success(regularUser)
    }
    
    // MARK: - Save User Information
    private func saveUser(_ user: User) {
        print("🔄 Saving user information: \(user.name) (guest: \(user.isGuest))")
        
        // Ensure UI state updates on main thread
        DispatchQueue.main.async {
            self.currentUser = user
            self.authState = .authenticated(user)
            
            print("✅ Authentication state updated to: authenticated")
            print("👤 Current user: \(user.name)")
            
            // Save to local storage
            if let userData = try? JSONEncoder().encode(user) {
                self.userDefaults.set(userData, forKey: self.userKey)
                print("💾 User data saved to local storage")
            } else {
                print("❌ User data save failed")
            }
        }
    }
    
    // MARK: - Email Validation
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidEmail
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .networkError:
            return "Network connection failed, please check your network settings"
        case .unknownError:
            return "Login failed, please try again later"
        }
    }
}
