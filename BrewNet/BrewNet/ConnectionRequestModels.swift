import Foundation
import SwiftUI

// MARK: - Connection Request Model
struct ConnectionRequest: Identifiable, Codable {
    let id: String
    let requesterId: String
    let requesterName: String
    let requesterProfile: ConnectionRequestProfile
    let reasonForInterest: String? // e.g., "Interested in your article on design thinking"
    let createdAt: Date
    let isFeatured: Bool // "Featured Professional" tag
    var temporaryMessages: [TemporaryMessage] = [] // 临时消息列表
    var isOnline: Bool = false // 用户在线状态
    var lastSeen: Date? // 最后活跃时间
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case requesterName = "requester_name"
        case requesterProfile = "requester_profile"
        case reasonForInterest = "reason_for_interest"
        case createdAt = "created_at"
        case isFeatured = "is_featured"
        case temporaryMessages = "temporary_messages"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// 最近的一条临时消息
    var latestTemporaryMessage: TemporaryMessage? {
        return temporaryMessages.sorted(by: { $0.timestamp > $1.timestamp }).first
    }
    
    /// 未读临时消息数量（只统计对方发送给我的未读消息）
    var unreadTemporaryMessageCount: Int {
        // 注意：这个方法需要知道当前用户ID才能正确计算
        // 暂时返回所有未读消息，实际使用时会在调用处传入当前用户ID
        return temporaryMessages.filter { !$0.isRead }.count
    }
    
    /// 计算未读消息数量（需要传入当前用户ID）
    func unreadTemporaryMessageCount(currentUserId: String) -> Int {
        return temporaryMessages.filter { message in
            !message.isRead && message.senderId != currentUserId
        }.count
    }
}

// MARK: - Connection Request Profile
struct ConnectionRequestProfile: Codable {
    let profilePhoto: String?
    let name: String
    let jobTitle: String
    let company: String
    let location: String
    let bio: String
    let expertise: [String] // Skills/tags
    let backgroundImage: String? // Optional background image for card
    
    enum CodingKeys: String, CodingKey {
        case profilePhoto = "profile_photo"
        case name
        case jobTitle = "job_title"
        case company
        case location
        case bio
        case expertise
        case backgroundImage = "background_image"
    }
}

// MARK: - Temporary Message Model
struct TemporaryMessage: Identifiable, Codable {
    let id: String
    let content: String
    let senderId: String
    let receiverId: String
    let timestamp: Date
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case timestamp
        case isRead = "is_read"
    }
    
    /// 从 SupabaseMessage 创建 TemporaryMessage
    init(from supabaseMessage: SupabaseMessage) {
        self.id = supabaseMessage.id
        self.content = supabaseMessage.content
        self.senderId = supabaseMessage.senderId
        self.receiverId = supabaseMessage.receiverId
        self.isRead = supabaseMessage.isRead
        
        // 解析时间戳
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: supabaseMessage.timestamp) {
            self.timestamp = date
        } else {
            dateFormatter.formatOptions = [.withInternetDateTime]
            self.timestamp = dateFormatter.date(from: supabaseMessage.timestamp) ?? Date()
        }
    }
}

// MARK: - Connection Request Status
enum ConnectionRequestStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

// MARK: - Sample Data
extension ConnectionRequest {
    static var sampleRequests: [ConnectionRequest] {
        return [
            ConnectionRequest(
                id: UUID().uuidString,
                requesterId: UUID().uuidString,
                requesterName: "Sarah Chen",
                requesterProfile: ConnectionRequestProfile(
                    profilePhoto: nil,
                    name: "Sarah Chen",
                    jobTitle: "Senior Product Designer",
                    company: "Meta",
                    location: "San Francisco, CA",
                    bio: "Design systems advocate. Building products that millions use daily. Previously at Airbnb and Dropbox 🎨",
                    expertise: ["UX Design", "Design Systems", "Product Strategy", "Mentorship"],
                    backgroundImage: nil
                ),
                reasonForInterest: "Interested in your article on design thinking",
                createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
                isFeatured: true
            ),
            ConnectionRequest(
                id: UUID().uuidString,
                requesterId: UUID().uuidString,
                requesterName: "Mike Rodriguez",
                requesterProfile: ConnectionRequestProfile(
                    profilePhoto: nil,
                    name: "Mike Rodriguez",
                    jobTitle: "Software Engineer",
                    company: "StartupXYZ",
                    location: "New York, NY",
                    bio: "Full-stack developer with a passion for mobile apps. When I'm not coding, you'll find me playing guitar or exploring the city.",
                    expertise: ["iOS Development", "Swift", "React Native", "Backend"],
                    backgroundImage: nil
                ),
                reasonForInterest: "We have similar interests in Swift development",
                createdAt: Date().addingTimeInterval(-14400), // 4 hours ago
                isFeatured: false
            ),
            ConnectionRequest(
                id: UUID().uuidString,
                requesterId: UUID().uuidString,
                requesterName: "Emma Wilson",
                requesterProfile: ConnectionRequestProfile(
                    profilePhoto: nil,
                    name: "Emma Wilson",
                    jobTitle: "UX Designer",
                    company: "DesignStudio",
                    location: "Los Angeles, CA",
                    bio: "Creative designer who believes good design can change the world. Love art galleries and weekend brunches.",
                    expertise: ["UI/UX Design", "Figma", "User Testing", "Prototyping"],
                    backgroundImage: nil
                ),
                reasonForInterest: nil,
                createdAt: Date().addingTimeInterval(-28800), // 8 hours ago
                isFeatured: false
            )
        ]
    }
}

