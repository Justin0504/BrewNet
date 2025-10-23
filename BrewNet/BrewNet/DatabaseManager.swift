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
    
    // MARK: - PostEntity Operations
    func createPost(id: String, title: String, content: String, question: String, tag: String, tagColor: String, backgroundColor: String, authorId: String, authorName: String) -> PostEntity? {
        print("🔧 DatabaseManager.createPost called")
        print("  - ID: \(id)")
        print("  - Title: \(title)")
        print("  - Author: \(authorName)")
        
        // Check if post with same ID already exists (prevent duplicates)
        if let existingPost = getPost(by: id) {
            print("⚠️ Post already exists, returning existing post")
            return existingPost
        }
        
        let post = PostEntity(context: context)
        post.id = id
        post.title = title
        post.content = content
        post.question = question
        post.tag = tag
        post.tagColor = tagColor
        post.backgroundColor = backgroundColor
        post.authorId = authorId
        post.authorName = authorName
        post.createdAt = Date()
        post.updatedAt = Date()
        post.likeCount = 0
        post.viewCount = 0
        
        print("📦 PostEntity object created")
        
        saveContext()
        
        print("💾 saveContext called")
        
        // Verify save
        let allPosts = getAllPosts()
        print("📊 Total posts in database: \(allPosts.count)")
        
        // Send notification that post was created
        NotificationCenter.default.post(
            name: NSNotification.Name("PostCreated"),
            object: nil,
            userInfo: ["postId": id]
        )
        print("📨 PostCreated notification sent")
        
        // Sync to cloud based on sync mode
        if syncMode != .localOnly && isOnline {
            Task {
                await syncPostToCloud(post: post)
            }
        }
        
        print("✅ createPost completed")
        return post
    }
    
    /// Sync post data to cloud
    private func syncPostToCloud(post: PostEntity) async {
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
        
        do {
            let _ = try await supabaseService.createPost(post: supabasePost)
            print("✅ Post data synced to cloud: \(post.title ?? "")")
        } catch {
            print("❌ Failed to sync post data to cloud: \(error)")
        }
    }
    
    func getAllPosts() -> [PostEntity] {
        let request: NSFetchRequest<PostEntity> = PostEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PostEntity.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching posts: \(error)")
            return []
        }
    }
    
    func getPosts(by authorId: String) -> [PostEntity] {
        let request: NSFetchRequest<PostEntity> = PostEntity.fetchRequest()
        request.predicate = NSPredicate(format: "authorId == %@", authorId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PostEntity.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("❌ Error fetching user posts: \(error)")
            return []
        }
    }
    
    // MARK: - LikeEntity Operations
    func likePost(userId: String, postId: String) -> Bool {
        // Check if already liked
        if isPostLiked(userId: userId, postId: postId) {
            return false
        }
        
        guard let user = getUser(by: userId),
              let post = getPost(by: postId) else {
            return false
        }
        
        let like = LikeEntity(context: context)
        like.id = UUID().uuidString
        like.createdAt = Date()
        like.user = user
        like.post = post
        
        // Update post like count
        post.likeCount += 1
        
        saveContext()
        return true
    }
    
    func unlikePost(userId: String, postId: String) -> Bool {
        let request: NSFetchRequest<LikeEntity> = LikeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@ AND post.id == %@", userId, postId)
        
        do {
            let likes = try context.fetch(request)
            for like in likes {
                // Update post like count
                if let post = like.post {
                    post.likeCount = max(0, post.likeCount - 1)
                }
                context.delete(like)
            }
            saveContext()
            return true
        } catch {
            print("❌ Error unliking post: \(error)")
            return false
        }
    }
    
    func isPostLiked(userId: String, postId: String) -> Bool {
        let request: NSFetchRequest<LikeEntity> = LikeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@ AND post.id == %@", userId, postId)
        
        do {
            let likes = try context.fetch(request)
            return !likes.isEmpty
        } catch {
            print("❌ Error checking like status: \(error)")
            return false
        }
    }
    
    func getLikedPosts(userId: String) -> [PostEntity] {
        let request: NSFetchRequest<LikeEntity> = LikeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LikeEntity.createdAt, ascending: false)]
        
        do {
            let likes = try context.fetch(request)
            return likes.compactMap { $0.post }
        } catch {
            print("❌ Error fetching liked posts: \(error)")
            return []
        }
    }
    
    // MARK: - SaveEntity Operations
    func savePost(userId: String, postId: String) -> Bool {
        // Check if already saved
        if isPostSaved(userId: userId, postId: postId) {
            return false
        }
        
        guard let user = getUser(by: userId),
              let post = getPost(by: postId) else {
            return false
        }
        
        let save = SaveEntity(context: context)
        save.id = UUID().uuidString
        save.createdAt = Date()
        save.user = user
        save.post = post
        
        saveContext()
        return true
    }
    
    func unsavePost(userId: String, postId: String) -> Bool {
        let request: NSFetchRequest<SaveEntity> = SaveEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@ AND post.id == %@", userId, postId)
        
        do {
            let saves = try context.fetch(request)
            for save in saves {
                context.delete(save)
            }
            saveContext()
            return true
        } catch {
            print("❌ Error unsaving post: \(error)")
            return false
        }
    }
    
    func isPostSaved(userId: String, postId: String) -> Bool {
        let request: NSFetchRequest<SaveEntity> = SaveEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@ AND post.id == %@", userId, postId)
        
        do {
            let saves = try context.fetch(request)
            return !saves.isEmpty
        } catch {
            print("❌ Error checking save status: \(error)")
            return false
        }
    }
    
    func getSavedPosts(userId: String) -> [PostEntity] {
        let request: NSFetchRequest<SaveEntity> = SaveEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user.id == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SaveEntity.createdAt, ascending: false)]
        
        do {
            let saves = try context.fetch(request)
            return saves.compactMap { $0.post }
        } catch {
            print("❌ Error fetching saved posts: \(error)")
            return []
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
    
    // MARK: - Helper Methods
    private func getPost(by id: String) -> PostEntity? {
        let request: NSFetchRequest<PostEntity> = PostEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let posts = try context.fetch(request)
            return posts.first
        } catch {
            print("❌ Error fetching post: \(error)")
            return nil
        }
    }
    
    // MARK: - Sample Data
    func createSampleData() {
        // Create sample posts
        let samplePosts = [
            ("1", "After leading people in big companies, I found that this kind of 'junior' is destined not to be promoted", "", "What kind of talent can be promoted in big companies?", "Experience Sharing", "green", "white", "system", "BrewNet Team"),
            ("2", "◆◆ Standard Process ◆◆", "1. Thank him for his time\n2. Introduce yourself\n3. Then the other party will usually take the lead to introduce their experience\n4. Thank him for his introduction", "How to do a coffee chat?", "Experience Sharing", "green", "white", "system", "BrewNet Team"),
            ("3", "First wave of employees replaced by AI recount personal experience of mass layoffs", "\"Always be prepared to leave your employer, because they are prepared to leave you.\" Brothers, this is it. I was just informed by my boss and HR that my entire career has been replaced by AI.", "AIGC layoff wave?", "Trend Direction", "blue", "white", "system", "BrewNet Team"),
            ("4", "5 Workplace efficiency improvement small tools", "", "What tools can improve workplace efficiency?!", "Resource Library", "purple", "white", "system", "BrewNet Team"),
            ("5", "Many advertising companies facing layoffs", "", "", "Industry News", "orange", "white", "system", "BrewNet Team"),
            ("6", "Coffee Chat Tips", "Learn how to network effectively through coffee meetings and build meaningful professional relationships.", "How to make the most of coffee chats?", "Networking", "brown", "white", "system", "BrewNet Team")
        ]
        
        for postData in samplePosts {
            let _ = createPost(
                id: postData.0,
                title: postData.1,
                content: postData.2,
                question: postData.3,
                tag: postData.4,
                tagColor: postData.5,
                backgroundColor: postData.6,
                authorId: postData.7,
                authorName: postData.8
            )
        }
        
        print("✅ Sample data created successfully")
    }
    
    // MARK: - Clear All Data
    func clearAllData() {
        let entities = ["UserEntity", "PostEntity", "LikeEntity", "SaveEntity", "MatchEntity", "CoffeeChatEntity", "MessageEntity"]
        
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
    
    // getAllPosts() 方法已在上面定义，此处删除重复定义
    
    func clearAllPosts() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Post")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            saveContext()
            print("🗑️ All posts cleared")
        } catch {
            print("❌ Error clearing posts: \(error)")
        }
    }
    
    /// Remove duplicate posts (based on ID or content)
    func removeDuplicatePosts() {
        let allPosts = getAllPosts()
        print("🔍 Checking \(allPosts.count) posts for duplicates")
        
        var seenIds = Set<String>()
        var duplicates: [PostEntity] = []
        
        // Step 1: Remove ID duplicates (case-insensitive)
        for post in allPosts {
            if let id = post.id {
                let normalizedId = id.lowercased() // Normalize to lowercase for comparison
                
                if seenIds.contains(normalizedId) {
                    duplicates.append(post)
                    print("🔍 Found duplicate ID: \(id) (normalized: \(normalizedId))")
                } else {
                    seenIds.insert(normalizedId)
                }
            }
        }
        
        // Step 2: Remove content duplicates
        let remainingPosts = allPosts.filter { !duplicates.contains($0) }
        var contentGroups: [String: [PostEntity]] = [:]
        
        for post in remainingPosts {
            let contentSignature = "\(post.title ?? "")_\(post.authorName ?? "")_\(post.tag ?? "")"
            if contentGroups[contentSignature] == nil {
                contentGroups[contentSignature] = []
            }
            contentGroups[contentSignature]?.append(post)
        }
        
        // For each group with same content, keep only the newest one
        for (signature, posts) in contentGroups {
            if posts.count > 1 {
                print("🔍 Found \(posts.count) posts with same content: \(signature)")
                
                // Sort by creation time, keep newest
                let sortedPosts = posts.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                
                // Delete all except the first (newest) one
                for i in 1..<sortedPosts.count {
                    duplicates.append(sortedPosts[i])
                    print("  Marked for deletion: \(sortedPosts[i].title ?? "Untitled") (ID: \(sortedPosts[i].id ?? "No ID"))")
                }
            }
        }
        
        if !duplicates.isEmpty {
            print("🗑️ Deleting \(duplicates.count) duplicate posts")
            for duplicate in duplicates {
                print("  Deleting: \(duplicate.title ?? "Untitled") (ID: \(duplicate.id ?? "No ID"))")
                context.delete(duplicate)
            }
            saveContext()
            
            // Verify deletion result
            let remaining = getAllPosts()
            print("✅ Cleanup complete, \(remaining.count) unique posts remaining")
        } else {
            print("✅ No duplicate posts found")
        }
    }
}
