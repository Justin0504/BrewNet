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
    
    init(content: String, isFromUser: Bool, messageType: MessageType = .text, senderName: String? = nil, senderAvatar: String? = nil) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromUser = isFromUser
        self.messageType = messageType
        self.senderName = senderName
        self.senderAvatar = senderAvatar
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
                AISuggestion(content: "That sounds interesting! Could you tell me more about that?", category: .followUp),
                AISuggestion(content: "How did you get interested in this field?", category: .followUp),
                AISuggestion(content: "What challenges have you faced along the way?", category: .followUp)
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
