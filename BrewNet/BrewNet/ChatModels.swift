import Foundation
import SwiftUI

// MARK: - Message Model
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFromUser: Bool
    let messageType: MessageType
    let senderName: String?
    let senderAvatar: String?
    let isRead: Bool // 添加是否已读属性
    
    init(content: String, isFromUser: Bool, messageType: MessageType = .text, senderName: String? = nil, senderAvatar: String? = nil, isRead: Bool = true) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromUser = isFromUser
        self.messageType = messageType
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.isRead = isRead
    }
}

// MARK: - Message Type
enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case aiSuggestion = "ai_suggestion"
    case iceBreaker = "ice_breaker"
    case system = "system"
}

// MARK: - Chat User Model
struct ChatUser: Identifiable, Codable {
    let id: UUID
    let name: String
    let avatar: String
    let isOnline: Bool
    let lastSeen: Date
    let interests: [String]
    let bio: String
    let isMatched: Bool
    let matchDate: Date?
    let matchType: MatchType
    let userId: String? // Optional userId for fetching profile from database
    
    init(name: String, avatar: String, isOnline: Bool = false, lastSeen: Date = Date(), interests: [String] = [], bio: String = "", isMatched: Bool = false, matchDate: Date? = nil, matchType: MatchType = .none, userId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.avatar = avatar
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.interests = interests
        self.bio = bio
        self.isMatched = isMatched
        self.matchDate = matchDate
        self.matchType = matchType
        self.userId = userId
    }
}

// MARK: - Match Type
enum MatchType: String, Codable, CaseIterable {
    case none = "none"
    case mutual = "mutual"
    case superLike = "super_like"
    case instant = "instant"
    
    var displayName: String {
        switch self {
        case .none:
            return "Not Matched"
        case .mutual:
            return "Mutual Like"
        case .superLike:
            return "Super Like"
        case .instant:
            return "Instant Match"
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return "circle"
        case .mutual:
            return "heart.fill"
        case .superLike:
            return "star.fill"
        case .instant:
            return "bolt.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none:
            return .gray
        case .mutual:
            return .red
        case .superLike:
            return .blue
        case .instant:
            return .yellow
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .none:
            return LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
        case .mutual:
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        case .superLike:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .instant:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - AI Suggestion Model
struct AISuggestion: Identifiable, Codable {
    let id: UUID
    let content: String
    let category: SuggestionCategory
    let timestamp: Date
    let isUsed: Bool
    
    init(content: String, category: SuggestionCategory, isUsed: Bool = false) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.timestamp = Date()
        self.isUsed = isUsed
    }
}

// MARK: - Suggestion Category
enum SuggestionCategory: String, Codable, CaseIterable {
    case iceBreaker = "ice_breaker"
    case followUp = "follow_up"
    case question = "question"
    case compliment = "compliment"
    case sharedInterest = "shared_interest"
    
    var displayName: String {
        switch self {
        case .iceBreaker:
            return "Ice Breaker"
        case .followUp:
            return "Follow Up"
        case .question:
            return "Interesting Question"
        case .compliment:
            return "Compliment"
        case .sharedInterest:
            return "Shared Interest"
        }
    }
    
    var icon: String {
        switch self {
        case .iceBreaker:
            return "sparkles"
        case .followUp:
            return "arrow.right.circle"
        case .question:
            return "questionmark.circle"
        case .compliment:
            return "heart.fill"
        case .sharedInterest:
            return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .iceBreaker:
            return .blue
        case .followUp:
            return .green
        case .question:
            return .orange
        case .compliment:
            return .pink
        case .sharedInterest:
            return .purple
        }
    }
}

// MARK: - Chat Session Model
struct ChatSession: Identifiable, Codable {
    let id: UUID
    let user: ChatUser
    var messages: [ChatMessage]
    var aiSuggestions: [AISuggestion]
    let createdAt: Date
    var lastMessageAt: Date
    var isActive: Bool
    
    init(user: ChatUser, messages: [ChatMessage] = [], aiSuggestions: [AISuggestion] = [], isActive: Bool = true) {
        self.id = UUID()
        self.user = user
        self.messages = messages
        self.aiSuggestions = aiSuggestions
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.isActive = isActive
    }
    
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        lastMessageAt = message.timestamp
    }
    
    mutating func addAISuggestion(_ suggestion: AISuggestion) {
        aiSuggestions.append(suggestion)
    }
    
    mutating func markSuggestionAsUsed(_ suggestionId: UUID) {
        if let index = aiSuggestions.firstIndex(where: { $0.id == suggestionId }) {
            aiSuggestions[index] = AISuggestion(
                content: aiSuggestions[index].content,
                category: aiSuggestions[index].category,
                isUsed: true
            )
        }
    }
    
    // 计算未读消息数（来自对方且未读的消息）
    var unreadCount: Int {
        return messages.filter { !$0.isFromUser && !$0.isRead }.count
    }
}

// MARK: - Sample Data
let sampleChatUsers = [
    ChatUser(
        name: "Sarah Chen",
        avatar: "person.circle.fill",
        isOnline: true,
        interests: ["Technology", "Coffee", "Travel"],
        bio: "Product Manager who loves creating amazing user experiences",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-3600), // 1 hour ago
        matchType: .mutual
    ),
    ChatUser(
        name: "Mike Rodriguez",
        avatar: "person.circle.fill",
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-300),
        interests: ["Music", "Coding", "Photography"],
        bio: "Software Engineer with a passion for mobile development",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-7200), // 2 hours ago
        matchType: .superLike
    ),
    ChatUser(
        name: "Emma Wilson",
        avatar: "person.circle.fill",
        isOnline: true,
        interests: ["Design", "Art", "Yoga"],
        bio: "UX Designer who believes good design can change the world",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-1800), // 30 minutes ago
        matchType: .instant
    ),
    ChatUser(
        name: "Alex Kim",
        avatar: "person.circle.fill",
        isOnline: true,
        interests: ["Data Science", "Board Games", "Food"],
        bio: "Data Scientist who loves finding patterns in numbers",
        isMatched: false,
        matchType: .none
    ),
    ChatUser(
        name: "Lisa Zhang",
        avatar: "person.circle.fill",
        isOnline: false,
        lastSeen: Date().addingTimeInterval(-1800),
        interests: ["Marketing", "Books", "Coffee"],
        bio: "Marketing strategist who loves storytelling",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-14400), // 4 hours ago
        matchType: .mutual
    )
]

let sampleAISuggestions = [
    AISuggestion(
        content: "I noticed you also like coffee! What's your favorite type of coffee?",
        category: .sharedInterest
    ),
    AISuggestion(
        content: "As a product manager, what's the most interesting project you've worked on?",
        category: .question
    ),
    AISuggestion(
        content: "Your design work is really amazing! Could you share your creative inspiration?",
        category: .compliment
    ),
    AISuggestion(
        content: "Are there any new tech trends that excite you recently?",
        category: .followUp
    ),
    AISuggestion(
        content: "If you could learn any new skill, what would you choose?",
        category: .iceBreaker
    )
]

// MARK: - Message Conversion Extensions
extension ChatMessage {
    /// 从 SupabaseMessage 创建 ChatMessage
    init(from supabaseMessage: SupabaseMessage, currentUserId: String) {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: supabaseMessage.timestamp) ?? Date()
        
        self.id = UUID(uuidString: supabaseMessage.id) ?? UUID()
        self.content = supabaseMessage.content
        self.timestamp = date
        self.isFromUser = supabaseMessage.senderId == currentUserId
        self.messageType = MessageType(rawValue: supabaseMessage.messageType) ?? .text
        self.senderName = nil // 可以从数据库获取
        self.senderAvatar = nil
        self.isRead = supabaseMessage.isRead // 添加 isRead 信息
    }
}

extension SupabaseMessage {
    /// 转换为 ChatMessage（需要 currentUserId 来确定 isFromUser）
    func toChatMessage(currentUserId: String) -> ChatMessage {
        return ChatMessage(from: self, currentUserId: currentUserId)
    }
}
