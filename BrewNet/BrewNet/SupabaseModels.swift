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
    }
    
    // Convert to AppUser
    func toAppUser() -> AppUser {
        return AppUser(
            id: id,
            email: email,
            name: name,
            isGuest: isGuest,
            profileSetupCompleted: profileSetupCompleted
        )
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

// MARK: - Supabase Match Model
struct SupabaseMatch: Codable, Identifiable {
    let id: String
    let userId: String
    let matchedUserId: String
    let matchedUserName: String
    let matchType: String
    let isActive: Bool
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case matchedUserId = "matched_user_id"
        case matchedUserName = "matched_user_name"
        case matchType = "match_type"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
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
