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
    
    private init() {}
    
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
    func createUser(id: String, email: String, name: String, phoneNumber: String? = nil, isGuest: Bool = false) -> UserEntity? {
        let user = UserEntity(context: context)
        user.id = id
        user.email = email
        user.name = name
        user.phoneNumber = phoneNumber
        user.isGuest = isGuest
        user.createdAt = Date()
        user.lastLoginAt = Date()
        
        saveContext()
        return user
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
        
        saveContext()
        return post
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
            createPost(
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
}
