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
    case coffeeChatInvitation = "coffee_chat_invitation"
}

// MARK: - Chat User Model
struct ChatUser: Identifiable, Codable {
    let id: UUID
    let name: String
    let avatar: String
    let interests: [String]
    let bio: String
    let isMatched: Bool
    let matchDate: Date?
    let matchType: MatchType
    let userId: String? // Optional userId for fetching profile from database
    
    init(name: String, avatar: String, interests: [String] = [], bio: String = "", isMatched: Bool = false, matchDate: Date? = nil, matchType: MatchType = .none, userId: String? = nil) {
        self.id = UUID()
        self.name = name
        self.avatar = avatar
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
    let style: SuggestionStyle? // 回复风格
    
    init(content: String, category: SuggestionCategory, isUsed: Bool = false, style: SuggestionStyle? = nil) {
        self.id = UUID()
        self.content = content
        self.category = category
        self.timestamp = Date()
        self.isUsed = isUsed
        self.style = style
    }
}

// MARK: - Suggestion Style
enum SuggestionStyle: String, Codable, CaseIterable {
    case humorous = "humorous"      // 幽默
    case serious = "serious"        // 严肃
    case caring = "caring"           // 体贴
    case professional = "professional" // 专业
    case friendly = "friendly"       // 友好
    case curious = "curious"         // 好奇
    case supportive = "supportive"   // 支持
    case playful = "playful"         // 轻松
    case thoughtful = "thoughtful"   // 深思
    case warm = "warm"               // 温暖
    
    var displayName: String {
        switch self {
        case .humorous: return "Humorous"
        case .serious: return "Serious"
        case .caring: return "Caring"
        case .professional: return "Professional"
        case .friendly: return "Friendly"
        case .curious: return "Curious"
        case .supportive: return "Supportive"
        case .playful: return "Playful"
        case .thoughtful: return "Thoughtful"
        case .warm: return "Warm"
        }
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
    
    /// 默认建议内容（用于 API 调用失败时的回退）
    var defaultSuggestions: [AISuggestion] {
        switch self {
        case .iceBreaker:
            return [
                AISuggestion(content: "Hi! I'd love to learn more about your professional journey.", category: .iceBreaker),
                AISuggestion(content: "What exciting projects have you been working on lately?", category: .iceBreaker),
                AISuggestion(content: "If you could master any new skill, what would it be?", category: .iceBreaker),
                AISuggestion(content: "How do you usually spend your weekends to recharge?", category: .iceBreaker),
                AISuggestion(content: "What's the best professional advice you've ever received?", category: .iceBreaker)
            ]
        case .followUp:
            return [
                AISuggestion(content: "That sounds interesting! Could you tell me more about that?", category: .followUp, style: .curious),
                AISuggestion(content: "How did you get interested in this field?", category: .followUp, style: .friendly),
                AISuggestion(content: "What challenges have you faced along the way?", category: .followUp, style: .serious),
                AISuggestion(content: "That's really impressive! I'd love to learn more about your experience.", category: .followUp, style: .warm),
                AISuggestion(content: "Based on what you've shared, I think this is a great opportunity to explore further.", category: .followUp, style: .professional),
                AISuggestion(content: "I can relate to that! How did you handle it?", category: .followUp, style: .caring),
                AISuggestion(content: "That's fascinating! What made you choose that path?", category: .followUp, style: .thoughtful),
                AISuggestion(content: "Haha, that's a great point! I never thought about it that way.", category: .followUp, style: .humorous),
                AISuggestion(content: "That's really inspiring! Keep up the great work.", category: .followUp, style: .supportive),
                AISuggestion(content: "Sounds like you've had quite the journey! What's next for you?", category: .followUp, style: .playful)
            ]
        case .compliment:
            return [
                AISuggestion(content: "I really appreciate your professional insights!", category: .compliment),
                AISuggestion(content: "Your experience and perspectives are inspiring!", category: .compliment),
                AISuggestion(content: "I admire your dedication to continuous learning!", category: .compliment)
            ]
        case .sharedInterest:
            return [
                AISuggestion(content: "We seem to share similar interests! Would love to chat more about this.", category: .sharedInterest),
                AISuggestion(content: "I'm also passionate about this topic! What drew you to it?", category: .sharedInterest),
                AISuggestion(content: "It's great to find someone with common interests!", category: .sharedInterest),
                AISuggestion(content: "We have a lot in common! Let's explore these topics together.", category: .sharedInterest)
            ]
        case .question:
            return [
                AISuggestion(content: "How do you maintain work-life balance?", category: .question),
                AISuggestion(content: "In your field, what skills do you think are most valuable?", category: .question),
                AISuggestion(content: "Any books or resources you'd recommend?", category: .question),
                AISuggestion(content: "What's the most challenging project you've worked on?", category: .question),
                AISuggestion(content: "Any advice for someone starting in your industry?", category: .question)
            ]
        }
    }
}

// MARK: - Coffee Chat Invitation Model
struct CoffeeChatInvitation: Identifiable, Codable {
    let id: UUID
    let senderId: String
    let receiverId: String
    let senderName: String
    let receiverName: String
    let status: InvitationStatus // pending, accepted, rejected
    let createdAt: Date
    let respondedAt: Date?
    let scheduledDate: Date? // 确认后的日程日期
    let location: String? // 确认后的地点
    let notes: String? // 备注
    
    enum InvitationStatus: String, Codable {
        case pending = "pending"
        case accepted = "accepted"
        case rejected = "rejected"
    }
    
    init(senderId: String, receiverId: String, senderName: String, receiverName: String, status: InvitationStatus = .pending, scheduledDate: Date? = nil, location: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.senderId = senderId
        self.receiverId = receiverId
        self.senderName = senderName
        self.receiverName = receiverName
        self.status = status
        self.createdAt = Date()
        self.respondedAt = status != .pending ? Date() : nil
        self.scheduledDate = scheduledDate
        self.location = location
        self.notes = notes
    }
}

// MARK: - Coffee Chat Schedule Model
struct CoffeeChatSchedule: Identifiable, Codable {
    let id: UUID
    let userId: String
    let participantId: String
    let participantName: String
    let scheduledDate: Date
    let location: String
    let notes: String?
    let createdAt: Date
    var hasMet: Bool
    
    init(userId: String, participantId: String, participantName: String, scheduledDate: Date, location: String, notes: String? = nil, hasMet: Bool = false) {
        self.id = UUID()
        self.userId = userId
        self.participantId = participantId
        self.participantName = participantName
        self.scheduledDate = scheduledDate
        self.location = location
        self.notes = notes
        self.createdAt = Date()
        self.hasMet = hasMet
    }
    
    // 从数据库解码的初始化方法
    init(id: UUID, userId: String, participantId: String, participantName: String, scheduledDate: Date, location: String, notes: String?, createdAt: Date, hasMet: Bool = false) {
        self.id = id
        self.userId = userId
        self.participantId = participantId
        self.participantName = participantName
        self.scheduledDate = scheduledDate
        self.location = location
        self.notes = notes
        self.createdAt = createdAt
        self.hasMet = hasMet
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case participantId = "participant_id"
        case participantName = "participant_name"
        case scheduledDate = "scheduled_date"
        case location
        case notes
        case createdAt = "created_at"
        case hasMet = "has_met"
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
    var isHidden: Bool // 是否被归档到 Hidden
    
    init(user: ChatUser, messages: [ChatMessage] = [], aiSuggestions: [AISuggestion] = [], isActive: Bool = true, isHidden: Bool = false) {
        self.id = UUID()
        self.user = user
        self.messages = messages
        self.aiSuggestions = aiSuggestions
        self.createdAt = Date()
        // 使用最后一条消息的时间，如果没有消息则使用当前时间
        self.lastMessageAt = messages.last?.timestamp ?? Date()
        self.isActive = isActive
        self.isHidden = isHidden
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
    // 注意：Hidden 的聊天不计算未读消息数，由调用方控制
    var unreadCount: Int {
        return messages.filter { !$0.isFromUser && !$0.isRead }.count
    }
    
    // 判断最后一条消息是否来自用户
    var lastMessageIsFromUser: Bool {
        return messages.last?.isFromUser ?? false
    }
}

// MARK: - Sample Data
let sampleChatUsers = [
    ChatUser(
        name: "Sarah Chen",
        avatar: "person.circle.fill",
        interests: ["Technology", "Coffee", "Travel"],
        bio: "Product Manager who loves creating amazing user experiences",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-3600), // 1 hour ago
        matchType: .mutual
    ),
    ChatUser(
        name: "Mike Rodriguez",
        avatar: "person.circle.fill",
        interests: ["Music", "Coding", "Photography"],
        bio: "Software Engineer with a passion for mobile development",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-7200), // 2 hours ago
        matchType: .superLike
    ),
    ChatUser(
        name: "Emma Wilson",
        avatar: "person.circle.fill",
        interests: ["Design", "Art", "Yoga"],
        bio: "UX Designer who believes good design can change the world",
        isMatched: true,
        matchDate: Date().addingTimeInterval(-1800), // 30 minutes ago
        matchType: .instant
    ),
    ChatUser(
        name: "Alex Kim",
        avatar: "person.circle.fill",
        interests: ["Data Science", "Board Games", "Food"],
        bio: "Data Scientist who loves finding patterns in numbers",
        isMatched: false,
        matchType: .none
    ),
    ChatUser(
        name: "Lisa Zhang",
        avatar: "person.circle.fill",
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
        // 使用 ISO8601DateFormatter 解析数据库时间戳
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = dateFormatter.date(from: supabaseMessage.timestamp)
        
        // 如果解析失败，尝试不带小数秒的格式
        if date == nil {
            dateFormatter.formatOptions = [.withInternetDateTime]
            date = dateFormatter.date(from: supabaseMessage.timestamp)
        }
        
        // 如果还是失败，尝试 PostgreSQL timestamp 格式
        if date == nil {
            let postgresFormatter = DateFormatter()
            postgresFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
            postgresFormatter.locale = Locale(identifier: "en_US_POSIX")
            postgresFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            date = postgresFormatter.date(from: supabaseMessage.timestamp)
        }
        
        // 最后兜底：使用当前时间（但应该尽量避免）
        self.id = UUID(uuidString: supabaseMessage.id) ?? UUID()
        self.content = supabaseMessage.content
        self.timestamp = date ?? Date()
        self.isFromUser = supabaseMessage.senderId == currentUserId
        self.messageType = MessageType(rawValue: supabaseMessage.messageType) ?? .text
        self.senderName = nil // 可以从数据库获取
        self.senderAvatar = nil
        self.isRead = supabaseMessage.isRead // 添加 isRead 信息
        
        // 打印调试信息
        if date == nil {
            print("⚠️ Failed to parse timestamp: \(supabaseMessage.timestamp), using current time")
        } else {
            print("✅ Parsed timestamp: \(supabaseMessage.timestamp) -> \(self.timestamp)")
        }
    }
}

extension SupabaseMessage {
    /// 转换为 ChatMessage（需要 currentUserId 来确定 isFromUser）
    func toChatMessage(currentUserId: String) -> ChatMessage {
        return ChatMessage(from: self, currentUserId: currentUserId)
    }
}
