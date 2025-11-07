import Foundation
import SwiftUI

// MARK: - Supabase User Model
struct SupabaseUser: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let phoneNumber: String?
    let isGuest: Bool
    let profileImage: String?
    let bio: String?
    let company: String?
    let jobTitle: String?
    let location: String?
    let skills: String?
    let interests: String?
    let profileSetupCompleted: Bool
    let createdAt: String
    let lastLoginAt: String
    let updatedAt: String
    
    // BrewNet Pro subscription fields
    let isPro: Bool
    let proStart: String?
    let proEnd: String?
    let likesRemaining: Int
    let likesDepletedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case phoneNumber = "phone_number"
        case isGuest = "is_guest"
        case profileImage = "profile_image"
        case bio
        case company
        case jobTitle = "job_title"
        case location
        case skills
        case interests
        case profileSetupCompleted = "profile_setup_completed"
        case createdAt = "created_at"
        case lastLoginAt = "last_login_at"
        case updatedAt = "updated_at"
        case isPro = "is_pro"
        case proStart = "pro_start"
        case proEnd = "pro_end"
        case likesRemaining = "likes_remaining"
        case likesDepletedAt = "likes_depleted_at"
    }
    
    // Standard initializer for creating new users
    init(
        id: String,
        email: String,
        name: String,
        phoneNumber: String? = nil,
        isGuest: Bool,
        profileImage: String? = nil,
        bio: String? = nil,
        company: String? = nil,
        jobTitle: String? = nil,
        location: String? = nil,
        skills: String? = nil,
        interests: String? = nil,
        profileSetupCompleted: Bool,
        createdAt: String,
        lastLoginAt: String,
        updatedAt: String,
        isPro: Bool = false,
        proStart: String? = nil,
        proEnd: String? = nil,
        likesRemaining: Int = 10,
        likesDepletedAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.phoneNumber = phoneNumber
        self.isGuest = isGuest
        self.profileImage = profileImage
        self.bio = bio
        self.company = company
        self.jobTitle = jobTitle
        self.location = location
        self.skills = skills
        self.interests = interests
        self.profileSetupCompleted = profileSetupCompleted
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.updatedAt = updatedAt
        self.isPro = isPro
        self.proStart = proStart
        self.proEnd = proEnd
        self.likesRemaining = likesRemaining
        self.likesDepletedAt = likesDepletedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        isGuest = try container.decode(Bool.self, forKey: .isGuest)
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        company = try container.decodeIfPresent(String.self, forKey: .company)
        jobTitle = try container.decodeIfPresent(String.self, forKey: .jobTitle)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        skills = try container.decodeIfPresent(String.self, forKey: .skills)
        interests = try container.decodeIfPresent(String.self, forKey: .interests)
        profileSetupCompleted = try container.decode(Bool.self, forKey: .profileSetupCompleted)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        lastLoginAt = try container.decode(String.self, forKey: .lastLoginAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        // Pro subscription fields with defaults for backward compatibility
        isPro = try container.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        proStart = try container.decodeIfPresent(String.self, forKey: .proStart)
        proEnd = try container.decodeIfPresent(String.self, forKey: .proEnd)
        likesRemaining = try container.decodeIfPresent(Int.self, forKey: .likesRemaining) ?? 10
        likesDepletedAt = try container.decodeIfPresent(String.self, forKey: .likesDepletedAt)
    }
    
    // Convert to AppUser
    func toAppUser() -> AppUser {
        return AppUser(
            id: id,
            email: email,
            name: name,
            isGuest: isGuest,
            profileSetupCompleted: profileSetupCompleted,
            isPro: isPro,
            proEnd: proEnd,
            likesRemaining: likesRemaining
        )
    }
    
    // Helper computed properties
    var isProActive: Bool {
        guard isPro, let proEndStr = proEnd else { return false }
        let formatter = ISO8601DateFormatter()
        guard let proEndDate = formatter.date(from: proEndStr) else { return false }
        return proEndDate > Date()
    }
    
    var canLike: Bool {
        return isProActive || likesRemaining > 0
    }
}

// MARK: - Supabase Profile Model
struct SupabaseProfile: Codable, Identifiable {
    let id: String
    let userId: String
    let coreIdentity: CoreIdentity
    let professionalBackground: ProfessionalBackground
    let networkingIntention: NetworkingIntention
    let networkingPreferences: NetworkingPreferences
    let personalitySocial: PersonalitySocial
    let privacyTrust: PrivacyTrust
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case coreIdentity = "core_identity"
        case professionalBackground = "professional_background"
        case networkingIntention = "networking_intention"
        case networkingPreferences = "networking_preferences"
        case personalitySocial = "personality_social"
        case privacyTrust = "privacy_trust"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Convert to BrewNetProfile
    func toBrewNetProfile() -> BrewNetProfile {
        return BrewNetProfile(
            id: id,
            userId: userId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            coreIdentity: coreIdentity,
            professionalBackground: professionalBackground,
            networkingIntention: networkingIntention,
            networkingPreferences: networkingPreferences,
            personalitySocial: personalitySocial,
            privacyTrust: privacyTrust
        )
    }
}

// MARK: - Supabase Invitation Model
struct SupabaseInvitation: Codable, Identifiable {
    let id: String
    let senderId: String
    let receiverId: String
    let status: InvitationStatus
    let reasonForInterest: String?
    let senderProfile: InvitationProfile?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case status
        case reasonForInterest = "reason_for_interest"
        case senderProfile = "sender_profile"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Invitation Status
enum InvitationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case cancelled = "cancelled"
}

// MARK: - Invitation Profile
struct InvitationProfile: Codable {
    let name: String
    let jobTitle: String?
    let company: String?
    let location: String?
    let bio: String?
    let profileImage: String?
    let expertise: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case jobTitle = "job_title"
        case company
        case location
        case bio
        case profileImage = "profile_image"
        case expertise
    }
}

// MARK: - Supabase Match Model
struct SupabaseMatch: Codable, Identifiable {
    let id: String
    let userId: String
    let matchedUserId: String
    let matchedUserName: String
    let matchType: SupabaseMatchType
    let isActive: Bool
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case matchedUserId = "matched_user_id"
        case matchedUserName = "matched_user_name"
        case matchType = "match_type"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase Match Type
enum SupabaseMatchType: String, Codable, CaseIterable {
    case mutual = "mutual"
    case invitationBased = "invitation_based"
    case recommended = "recommended"
}

// MARK: - Supabase Coffee Chat Model
struct SupabaseCoffeeChat: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let participantId: String
    let participantName: String
    let scheduledDate: String
    let location: String
    let status: String
    let notes: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case participantId = "participant_id"
        case participantName = "participant_name"
        case scheduledDate = "scheduled_date"
        case location
        case status
        case notes
        case createdAt = "created_at"
    }
}

// MARK: - Supabase Message Model
struct SupabaseMessage: Codable, Identifiable {
    let id: String
    let senderId: String
    let receiverId: String
    let content: String
    let messageType: String
    let isRead: Bool
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case messageType = "message_type"
        case isRead = "is_read"
        case timestamp
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timeAgoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
