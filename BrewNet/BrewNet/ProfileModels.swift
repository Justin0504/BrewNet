import Foundation
import SwiftUI

// MARK: - Complete Profile Model
struct BrewNetProfile: Codable, Identifiable {
    let id: String
    let userId: String
    let createdAt: String
    let updatedAt: String
    
    // MARK: - 1. Core Identity (必填基础信息)
    let coreIdentity: CoreIdentity
    
    // MARK: - 2. Professional Background
    let professionalBackground: ProfessionalBackground
    
    // MARK: - 3. Networking & Intent
    let networkingIntent: NetworkingIntent
    
    // MARK: - 4. Personality & Social Layer
    let personalitySocial: PersonalitySocial
    
    // MARK: - 5. Privacy & Trust Controls
    let privacyTrust: PrivacyTrust
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case coreIdentity = "core_identity"
        case professionalBackground = "professional_background"
        case networkingIntent = "networking_intent"
        case personalitySocial = "personality_social"
        case privacyTrust = "privacy_trust"
    }
}

// MARK: - 1. Core Identity
struct CoreIdentity: Codable {
    let name: String
    let email: String
    let phoneNumber: String?
    let profileImage: String?
    let bio: String?
    let pronouns: String?
    let location: String?
    let personalWebsite: String?
    let githubUrl: String?
    let linkedinUrl: String?
    let timeZone: String
    let availableTimeslot: AvailableTimeslot
    
    enum CodingKeys: String, CodingKey {
        case name
        case email
        case phoneNumber = "phone_number"
        case profileImage = "profile_image"
        case bio
        case pronouns
        case location
        case personalWebsite = "personal_website"
        case githubUrl = "github_url"
        case linkedinUrl = "linkedin_url"
        case timeZone = "time_zone"
        case availableTimeslot = "available_timeslot"
    }
    
    init(name: String, email: String, phoneNumber: String?, profileImage: String?, bio: String?, pronouns: String?, location: String?, personalWebsite: String?, githubUrl: String?, linkedinUrl: String?, timeZone: String, availableTimeslot: AvailableTimeslot) {
        self.name = name
        self.email = email
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
        self.bio = bio
        self.pronouns = pronouns
        self.location = location
        self.personalWebsite = personalWebsite
        self.githubUrl = githubUrl
        self.linkedinUrl = linkedinUrl
        self.timeZone = timeZone
        self.availableTimeslot = availableTimeslot
    }
}

// MARK: - 2. Professional Background
struct ProfessionalBackground: Codable {
    let currentCompany: String?
    let jobTitle: String?
    let industry: String?
    let experienceLevel: ExperienceLevel
    let education: String?
    let yearsOfExperience: Double?
    let careerStage: CareerStage
    let skills: [String]
    let certifications: [String]
    let languagesSpoken: [String]
    let workExperiences: [WorkExperience]
    
    enum CodingKeys: String, CodingKey {
        case currentCompany = "current_company"
        case jobTitle = "job_title"
        case industry
        case experienceLevel = "experience_level"
        case education
        case yearsOfExperience = "years_of_experience"
        case careerStage = "career_stage"
        case skills
        case certifications
        case languagesSpoken = "languages_spoken"
        case workExperiences = "work_experiences"
    }
}

// MARK: - 3. Networking & Intent
struct NetworkingIntent: Codable {
    let networkingIntent: [NetworkingIntentType]
    let conversationTopics: [String]
    let collaborationInterest: [CollaborationInterest]
    let coffeeChatGoal: String?
    let preferredChatFormat: ChatFormat
    let availableTimeslot: AvailableTimeslot
    let preferredChatDuration: String?
    let introPromptAnswers: [IntroPromptAnswer]
    
    enum CodingKeys: String, CodingKey {
        case networkingIntent = "networking_intent"
        case conversationTopics = "conversation_topics"
        case collaborationInterest = "collaboration_interest"
        case coffeeChatGoal = "coffee_chat_goal"
        case preferredChatFormat = "preferred_chat_format"
        case availableTimeslot = "available_timeslot"
        case preferredChatDuration = "preferred_chat_duration"
        case introPromptAnswers = "intro_prompt_answers"
    }
}

// MARK: - 4. Personality & Social Layer
struct PersonalitySocial: Codable {
    let icebreakerPrompts: [IcebreakerPrompt]
    let valuesTags: [String]
    let hobbies: [String]
    let preferredMeetingVibe: MeetingVibe
    let communicationStyle: CommunicationStyle
    
    enum CodingKeys: String, CodingKey {
        case icebreakerPrompts = "icebreaker_prompts"
        case valuesTags = "values_tags"
        case hobbies
        case preferredMeetingVibe = "preferred_meeting_vibe"
        case communicationStyle = "communication_style"
    }
}

// MARK: - 5. Privacy & Trust Controls
struct PrivacyTrust: Codable {
    let visibilitySettings: VisibilitySettings
    let verifiedStatus: VerifiedStatus
    let dataSharingConsent: Bool
    let reportPreferences: ReportPreferences
    
    enum CodingKeys: String, CodingKey {
        case visibilitySettings = "visibility_settings"
        case verifiedStatus = "verified_status"
        case dataSharingConsent = "data_sharing_consent"
        case reportPreferences = "report_preferences"
    }
}

// MARK: - Supporting Models

// Available Timeslot Matrix (Sunday-Saturday × Morning/Noon/Afternoon/Evening/Night)
struct AvailableTimeslot: Codable {
    let sunday: DayTimeslots
    let monday: DayTimeslots
    let tuesday: DayTimeslots
    let wednesday: DayTimeslots
    let thursday: DayTimeslots
    let friday: DayTimeslots
    let saturday: DayTimeslots
    
    enum CodingKeys: String, CodingKey {
        case sunday, monday, tuesday, wednesday, thursday, friday, saturday
    }
}

struct DayTimeslots: Codable {
    let morning: Bool
    let noon: Bool
    let afternoon: Bool
    let evening: Bool
    let night: Bool
    
    enum CodingKeys: String, CodingKey {
        case morning, noon, afternoon, evening, night
    }
}

// Enums
enum ExperienceLevel: String, CaseIterable, Codable {
    case intern = "Intern"
    case entry = "Entry"
    case mid = "Mid"
    case senior = "Senior"
    case exec = "Exec"
    
    var displayName: String {
        return self.rawValue
    }
}

enum CareerStage: String, CaseIterable, Codable {
    case earlyCareer = "Early-career"
    case midLevel = "Mid-level"
    case manager = "Manager"
    case executive = "Executive"
    case founder = "Founder"
    
    var displayName: String {
        return self.rawValue
    }
}

enum NetworkingIntentType: String, CaseIterable, Codable {
    case findMentor = "Find a mentor"
    case exploreIndustries = "Explore new industries"
    case makeFriends = "Make friends"
    case findCollaborators = "Find collaborators"
    case recruitTalent = "Recruit talent"
    case findJob = "Find job opportunities"
    case shareKnowledge = "Share knowledge"
    case buildNetwork = "Build professional network"
    
    var displayName: String {
        return self.rawValue
    }
}

enum CollaborationInterest: String, CaseIterable, Codable {
    case startupIdeas = "Startup ideas"
    case sideProjects = "Side projects"
    case mentoring = "Mentoring"
    case research = "Research collaboration"
    case speaking = "Speaking opportunities"
    case writing = "Writing collaboration"
    case consulting = "Consulting"
    
    var displayName: String {
        return self.rawValue
    }
}

enum ChatFormat: String, CaseIterable, Codable {
    case virtual = "Virtual"
    case inPerson = "In-person"
    case either = "Either"
    
    var displayName: String {
        return self.rawValue
    }
}

enum MeetingVibe: String, CaseIterable, Codable {
    case casual = "Casual"
    case deep = "Deep"
    case goalDriven = "Goal-driven"
    case mentorMentee = "Mentor-mentee"
    
    var displayName: String {
        return self.rawValue
    }
}

enum CommunicationStyle: String, CaseIterable, Codable {
    case direct = "Direct"
    case reflective = "Reflective"
    case exploratory = "Exploratory"
    case collaborative = "Collaborative"
    
    var displayName: String {
        return self.rawValue
    }
}

enum VerifiedStatus: String, CaseIterable, Codable {
    case unverified = "unverified"
    case verifiedStudent = "verified_student"
    case verifiedProfessional = "verified_professional"
    case verifiedCompany = "verified_company"
    
    var displayName: String {
        switch self {
        case .unverified: return "Unverified"
        case .verifiedStudent: return "Verified Student"
        case .verifiedProfessional: return "Verified Professional"
        case .verifiedCompany: return "Verified Company"
        }
    }
}

// Complex Models
struct IntroPromptAnswer: Codable {
    let prompt: String
    let answer: String
    
    enum CodingKeys: String, CodingKey {
        case prompt, answer
    }
}

struct IcebreakerPrompt: Codable {
    let prompt: String
    let answer: String
    
    enum CodingKeys: String, CodingKey {
        case prompt, answer
    }
}

struct VisibilitySettings: Codable, Equatable {
    let company: VisibilityLevel
    let email: VisibilityLevel
    let phoneNumber: VisibilityLevel
    let location: VisibilityLevel
    let skills: VisibilityLevel
    let interests: VisibilityLevel
    
    enum CodingKeys: String, CodingKey {
        case company
        case email
        case phoneNumber = "phone_number"
        case location
        case skills
        case interests
    }
}

enum VisibilityLevel: String, CaseIterable, Codable, Equatable {
    case public_ = "public"
    case connectionsOnly = "connections_only"
    case private_ = "private"
    
    var displayName: String {
        switch self {
        case .public_: return "Public"
        case .connectionsOnly: return "Connections Only"
        case .private_: return "Private"
        }
    }
}

struct ReportPreferences: Codable {
    let allowReports: Bool
    let reportCategories: [String]
    
    enum CodingKeys: String, CodingKey {
        case allowReports = "allow_reports"
        case reportCategories = "report_categories"
    }
}

// MARK: - Profile Creation Helper
struct ProfileCreationData {
    var coreIdentity: CoreIdentity?
    var professionalBackground: ProfessionalBackground?
    var networkingIntent: NetworkingIntent?
    var personalitySocial: PersonalitySocial?
    var privacyTrust: PrivacyTrust?
    
    var isComplete: Bool {
        return coreIdentity != nil &&
               professionalBackground != nil &&
               networkingIntent != nil &&
               personalitySocial != nil &&
               privacyTrust != nil
    }
    
    var completionPercentage: Double {
        let completedSections = [
            coreIdentity != nil,
            professionalBackground != nil,
            networkingIntent != nil,
            personalitySocial != nil,
            privacyTrust != nil
        ].filter { $0 }.count
        
        return Double(completedSections) / 5.0
    }
}

// MARK: - Default Values
extension BrewNetProfile {
    static func createDefault(userId: String) -> BrewNetProfile {
        let now = ISO8601DateFormatter().string(from: Date())
        
        return BrewNetProfile(
            id: UUID().uuidString,
            userId: userId,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: "",
                email: "",
                phoneNumber: nil,
                profileImage: nil,
                bio: nil,
                pronouns: nil,
                location: nil,
                personalWebsite: nil,
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: TimeZone.current.identifier,
                availableTimeslot: AvailableTimeslot.createDefault()
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: nil,
                jobTitle: nil,
                industry: nil,
                experienceLevel: .entry,
                education: nil,
                yearsOfExperience: nil,
                careerStage: .earlyCareer,
                skills: [],
                certifications: [],
                languagesSpoken: [],
                workExperiences: []
            ),
            networkingIntent: NetworkingIntent(
                networkingIntent: [],
                conversationTopics: [],
                collaborationInterest: [],
                coffeeChatGoal: nil,
                preferredChatFormat: .virtual,
                availableTimeslot: AvailableTimeslot.createDefault(),
                preferredChatDuration: nil,
                introPromptAnswers: []
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: [],
                hobbies: [],
                preferredMeetingVibe: .casual,
                communicationStyle: .collaborative
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .unverified,
                dataSharingConsent: false,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
    }
}

extension AvailableTimeslot {
    static func createDefault() -> AvailableTimeslot {
        let defaultDay = DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false)
        return AvailableTimeslot(
            sunday: defaultDay,
            monday: defaultDay,
            tuesday: defaultDay,
            wednesday: defaultDay,
            thursday: defaultDay,
            friday: defaultDay,
            saturday: defaultDay
        )
    }
}

extension VisibilitySettings {
    static func createDefault() -> VisibilitySettings {
        return VisibilitySettings(
            company: .public_,
            email: .private_,
            phoneNumber: .private_,
            location: .public_,
            skills: .public_,
            interests: .public_
        )
    }
}

// MARK: - Profile Validation
extension BrewNetProfile {
    var isValid: Bool {
        return !coreIdentity.name.isEmpty &&
               !coreIdentity.email.isEmpty &&
               !professionalBackground.skills.isEmpty &&
               !networkingIntent.networkingIntent.isEmpty &&
               !personalitySocial.valuesTags.isEmpty
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if coreIdentity.name.isEmpty {
            errors.append("Name is required")
        }
        if coreIdentity.email.isEmpty {
            errors.append("Email is required")
        }
        if professionalBackground.skills.isEmpty {
            errors.append("At least one skill is required")
        }
        if networkingIntent.networkingIntent.isEmpty {
            errors.append("At least one networking intent is required")
        }
        if personalitySocial.valuesTags.isEmpty {
            errors.append("At least one value tag is required")
        }
        
        return errors
    }
}
