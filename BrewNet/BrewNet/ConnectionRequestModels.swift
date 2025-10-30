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
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case requesterName = "requester_name"
        case requesterProfile = "requester_profile"
        case reasonForInterest = "reason_for_interest"
        case createdAt = "created_at"
        case isFeatured = "is_featured"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
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

