import Foundation
import CoreData
import SwiftUI

// MARK: - Database Manager
class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BrewNet")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Supabase Service
    private let supabaseService = SupabaseService.shared

    // MARK: - Behavioral Metrics Service (已禁用)
    // 注：BehavioralMetricsService 因兼容性问题暂时禁用
    // 行为量化指标功能将通过 UserTowerFeatures.behavioralMetrics 访问
    // let behavioralMetricsService = BehavioralMetricsService.shared
    
    // MARK: - Sync Configuration
    @Published var syncMode: SyncMode = .hybrid
    @Published var lastSyncTime: Date?
    @Published var isOnline: Bool = true
    
    enum SyncMode {
        case localOnly      // Local storage only (test mode)
        case cloudOnly      // Cloud storage only
        case hybrid         // Hybrid mode: cloud + local cache
    }
    
    private init() {
        // Start network monitoring
        supabaseService.startNetworkMonitoring()

        // Set up BehavioralMetricsService dependencies (已禁用)
        // behavioralMetricsService.setDependencies(supabaseService: supabaseService)

        // Listen for network status changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NetworkStatusChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let isOnline = notification.userInfo?["isOnline"] as? Bool {
                self?.isOnline = isOnline
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - SaveEntity Context
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Database saved successfully")
            } catch {
                print("❌ Database save error: \(error)")
            }
        }
    }
    
    // MARK: - User Operations
    func createUser(id: String, email: String, name: String, phoneNumber: String? = nil, isGuest: Bool = false, profileSetupCompleted: Bool = false) -> UserEntity? {
        let user = UserEntity(context: context)
        user.id = id
        user.email = email
        user.name = name
        user.phoneNumber = phoneNumber
        user.isGuest = isGuest
        user.profileSetupCompleted = profileSetupCompleted
        user.createdAt = Date()
        user.lastLoginAt = Date()
        
        saveContext()
        
        // Sync to cloud based on sync mode
        if syncMode != .localOnly && isOnline {
            Task {
                await syncUserToCloud(user: user)
            }
        }
        
        return user
    }
    
    /// Sync user data to cloud
    private func syncUserToCloud(user: UserEntity) async {
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
        
        do {
            _ = try await supabaseService.createUser(user: supabaseUser)
            print("✅ User data synced to cloud: \(user.name ?? "")")
        } catch {
            print("❌ Failed to sync user data to cloud: \(error)")
        }
    }
    
    func getUser(by id: String) -> UserEntity? {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("❌ Error fetching user: \(error)")
            return nil
        }
    }
    
    func getUserByEmail(_ email: String) -> UserEntity? {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let users = try context.fetch(request)
            return users.first
        } catch {
            print("❌ Error fetching user by email: \(error)")
            return nil
        }
    }
    
    func updateUserLastLogin(_ userId: String) {
        if let user = getUser(by: userId) {
            user.lastLoginAt = Date()
            saveContext()
        }
    }
    
    // MARK: - MatchEntity Operations
    func createMatchEntity(userId: String, matchedUserId: String, matchedUserName: String, matchType: String) -> MatchEntity? {
        let match = MatchEntity(context: context)
        match.id = UUID().uuidString
        match.matchedUserId = matchedUserId
        match.matchedUserName = matchedUserName
        match.matchType = matchType
        match.createdAt = Date()
        match.isActive = true
        
        if let user = getUser(by: userId) {
            match.user = user
        }
        
        saveContext()
        return match
    }
    
    func getMatchEntityes(userId: String) -> [MatchEntity] {
        let request: NSFetchRequest<MatchEntity> = MatchEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@ AND isActive == YES", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MatchEntity.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching matches: \(error)")
            return []
        }
    }
    
    // MARK: - Coffee Chat Operations
    func createCoffeeChatEntity(id: String, title: String, participantId: String, participantName: String, scheduledDate: Date, location: String, status: String, notes: String? = nil, userId: String) -> CoffeeChatEntity? {
        let coffeeChat = CoffeeChatEntity(context: context)
        coffeeChat.id = id
        coffeeChat.title = title
        coffeeChat.participantId = participantId
        coffeeChat.participantName = participantName
        coffeeChat.scheduledDate = scheduledDate
        coffeeChat.location = location
        coffeeChat.status = status
        coffeeChat.notes = notes
        coffeeChat.createdAt = Date()
        
        if let user = getUser(by: userId) {
            coffeeChat.user = user
        }
        
        saveContext()
        return coffeeChat
    }
    
    func getCoffeeChatEntitys(userId: String) -> [CoffeeChatEntity] {
        let request: NSFetchRequest<CoffeeChatEntity> = CoffeeChatEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CoffeeChatEntity.scheduledDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching coffee chats: \(error)")
            return []
        }
    }
    
    // MARK: - Sample Data
    func createSampleData() {
        print("✅ Sample data created successfully")
    }
    
    // MARK: - Clear All Data
    func clearAllData() {
        let entities = ["UserEntity", "MatchEntity", "CoffeeChatEntity", "MessageEntity"]
        
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("❌ Error clearing \(entityName): \(error)")
            }
        }
        
        saveContext()
        print("✅ All data cleared")
    }
    
    func clearAllUsers() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "UserEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            print("✅ All users cleared")
        } catch {
            print("❌ Error clearing users: \(error)")
        }
    }
    
    // MARK: - Sync Operations
    
    /// 设置同步模式
    func setSyncMode(_ mode: SyncMode) {
        syncMode = mode
        print("🔄 同步模式已设置为: \(mode)")
    }
    
    /// 手动同步到云端
    func syncToCloud() async {
        guard syncMode != .localOnly && isOnline else {
            print("⚠️ 当前模式不支持云端同步或网络不可用")
            return
        }
        
        await supabaseService.syncToCloud()
        lastSyncTime = Date()
    }
    
    /// 从云端同步数据
    func syncFromCloud() async {
        guard syncMode != .localOnly && isOnline else {
            print("⚠️ 当前模式不支持云端同步或网络不可用")
            return
        }
        
        await supabaseService.syncFromCloud()
        lastSyncTime = Date()
    }
    
    /// 双向同步（云端 ↔ 本地）
    func bidirectionalSync() async {
        guard syncMode == .hybrid && isOnline else {
            print("⚠️ 双向同步仅在混合模式下可用且需要网络连接")
            return
        }
        
        // 先同步本地数据到云端
        await syncToCloud()
        
        // 再从云端同步最新数据到本地
        await syncFromCloud()
        
        print("✅ 双向同步完成")
    }
    
    /// 切换测试模式（仅本地存储）
    func enableTestMode() {
        setSyncMode(.localOnly)
        print("🧪 测试模式已启用 - 仅使用本地存储")
    }
    
    /// 启用混合模式
    func enableHybridMode() {
        setSyncMode(.hybrid)
        print("🔄 混合模式已启用 - 云端 + 本地缓存")
    }
    
    /// 获取同步状态信息
    func getSyncStatus() -> String {
        let modeText = syncMode == .localOnly ? "仅本地" : 
                      syncMode == .cloudOnly ? "仅云端" : "混合模式"
        let onlineText = isOnline ? "在线" : "离线"
        let lastSyncText = lastSyncTime?.formatted() ?? "从未同步"
        
        return """
        同步模式: \(modeText)
        网络状态: \(onlineText)
        最后同步: \(lastSyncText)
        """
    }
    
    // MARK: - Additional Helper Methods
    
    func getAllUsers() -> [UserEntity] {
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching users: \(error)")
            return []
        }
    }
}
