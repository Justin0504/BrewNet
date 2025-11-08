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
    
    // MARK: - 3. Networking Intention
    let networkingIntention: NetworkingIntention
    
    // MARK: - 4. Networking Preferences
    let networkingPreferences: NetworkingPreferences
    
    // MARK: - 5. Personality & Social Layer
    let personalitySocial: PersonalitySocial
    
    // MARK: - 6. Moments
    let moments: Moments?
    
    // MARK: - 7. Privacy & Trust Controls
    let privacyTrust: PrivacyTrust
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case coreIdentity = "core_identity"
        case professionalBackground = "professional_background"
        case networkingIntention = "networking_intention"
        case networkingPreferences = "networking_preferences"
        case personalitySocial = "personality_social"
        case moments
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
    // 注意：available_timeslot 已移动到 NetworkingPreferences 中
    
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
        // available_timeslot 已移除，现在在 networking_preferences 中
    }
    
    init(name: String, email: String, phoneNumber: String?, profileImage: String?, bio: String?, pronouns: String?, location: String?, personalWebsite: String?, githubUrl: String?, linkedinUrl: String?, timeZone: String) {
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
    }
    
    // 自定义解码器：忽略 core_identity 中的 available_timeslot（如果存在）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.email = try container.decode(String.self, forKey: .email)
        self.phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.pronouns = try container.decodeIfPresent(String.self, forKey: .pronouns)
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.personalWebsite = try container.decodeIfPresent(String.self, forKey: .personalWebsite)
        self.githubUrl = try container.decodeIfPresent(String.self, forKey: .githubUrl)
        self.linkedinUrl = try container.decodeIfPresent(String.self, forKey: .linkedinUrl)
        self.timeZone = try container.decode(String.self, forKey: .timeZone)
        
        // 忽略 available_timeslot（如果存在），因为现在它应该在 networking_preferences 中
        // 这样即使数据库中的 core_identity 包含 available_timeslot，也不会解码错误
    }
}

// MARK: - 2. Professional Background
struct ProfessionalBackground: Codable {
    let currentCompany: String?
    let jobTitle: String?
    let industry: String?
    let experienceLevel: ExperienceLevel
    let education: String? // 旧字段，保留以向后兼容
    let educations: [Education]? // 新字段，存储详细的教育信息
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
        case educations
        case yearsOfExperience = "years_of_experience"
        case careerStage = "career_stage"
        case skills
        case certifications
        case languagesSpoken = "languages_spoken"
        case workExperiences = "work_experiences"
    }
}

// MARK: - 3. Networking Intention
struct NetworkingIntention: Codable, Equatable {
    var selectedIntention: NetworkingIntentionType
    var additionalIntentions: [NetworkingIntentionType]
    var selectedSubIntentions: [SubIntentionType]
    var careerDirection: CareerDirectionData?
    var skillDevelopment: SkillDevelopmentData?
    var industryTransition: IndustryTransitionData?
    
    enum CodingKeys: String, CodingKey {
        case selectedIntention = "selected_intention"
        case additionalIntentions = "additional_intentions"
        case selectedSubIntentions = "selected_sub_intentions"
        case careerDirection = "career_direction"
        case skillDevelopment = "skill_development"
        case industryTransition = "industry_transition"
    }
    
    init(
        selectedIntention: NetworkingIntentionType,
        additionalIntentions: [NetworkingIntentionType] = [],
        selectedSubIntentions: [SubIntentionType],
        careerDirection: CareerDirectionData?,
        skillDevelopment: SkillDevelopmentData?,
        industryTransition: IndustryTransitionData?
    ) {
        self.selectedIntention = selectedIntention
        self.additionalIntentions = additionalIntentions
        self.selectedSubIntentions = selectedSubIntentions
        self.careerDirection = careerDirection
        self.skillDevelopment = skillDevelopment
        self.industryTransition = industryTransition
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedIntention = try container.decode(NetworkingIntentionType.self, forKey: .selectedIntention)
        self.additionalIntentions = try container.decodeIfPresent([NetworkingIntentionType].self, forKey: .additionalIntentions) ?? []
        self.selectedSubIntentions = try container.decode([SubIntentionType].self, forKey: .selectedSubIntentions)
        self.careerDirection = try container.decodeIfPresent(CareerDirectionData.self, forKey: .careerDirection)
        self.skillDevelopment = try container.decodeIfPresent(SkillDevelopmentData.self, forKey: .skillDevelopment)
        self.industryTransition = try container.decodeIfPresent(IndustryTransitionData.self, forKey: .industryTransition)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selectedIntention, forKey: .selectedIntention)
        if !additionalIntentions.isEmpty {
            try container.encode(additionalIntentions, forKey: .additionalIntentions)
        }
        try container.encode(selectedSubIntentions, forKey: .selectedSubIntentions)
        try container.encodeIfPresent(careerDirection, forKey: .careerDirection)
        try container.encodeIfPresent(skillDevelopment, forKey: .skillDevelopment)
        try container.encodeIfPresent(industryTransition, forKey: .industryTransition)
    }
}

// MARK: - 4. Networking Preferences
struct NetworkingPreferences: Codable, Equatable {
    let preferredChatFormat: ChatFormat
    let availableTimeslot: AvailableTimeslot
    let preferredChatDuration: String?
    
    enum CodingKeys: String, CodingKey {
        case preferredChatFormat = "preferred_chat_format"
        case availableTimeslot = "available_timeslot"
        case preferredChatDuration = "preferred_chat_duration"
    }
}

// MARK: - 5. Networking & Intent (Legacy - keeping for backward compatibility)
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
    var icebreakerPrompts: [IcebreakerPrompt]
    var valuesTags: [String]
    var hobbies: [String]
    var preferredMeetingVibe: MeetingVibe
    var preferredMeetingVibes: [MeetingVibe]
    var selfIntroduction: String?
    
    enum CodingKeys: String, CodingKey {
        case icebreakerPrompts = "icebreaker_prompts"
        case valuesTags = "values_tags"
        case hobbies
        case preferredMeetingVibe = "preferred_meeting_vibe"
        case preferredMeetingVibes = "preferred_meeting_vibes"
        case selfIntroduction = "self_introduction"
    }
    
    init(
        icebreakerPrompts: [IcebreakerPrompt],
        valuesTags: [String],
        hobbies: [String],
        preferredMeetingVibe: MeetingVibe,
        preferredMeetingVibes: [MeetingVibe] = [],
        selfIntroduction: String?
    ) {
        self.icebreakerPrompts = icebreakerPrompts
        self.valuesTags = valuesTags
        self.hobbies = hobbies
        self.preferredMeetingVibe = preferredMeetingVibe
        if preferredMeetingVibes.isEmpty {
            self.preferredMeetingVibes = [preferredMeetingVibe]
        } else {
            self.preferredMeetingVibes = preferredMeetingVibes
        }
        self.selfIntroduction = selfIntroduction
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.icebreakerPrompts = try container.decode([IcebreakerPrompt].self, forKey: .icebreakerPrompts)
        self.valuesTags = try container.decode([String].self, forKey: .valuesTags)
        self.hobbies = try container.decode([String].self, forKey: .hobbies)
        let primaryVibe = try container.decodeIfPresent(MeetingVibe.self, forKey: .preferredMeetingVibe)
        let vibes = try container.decodeIfPresent([MeetingVibe].self, forKey: .preferredMeetingVibes) ?? []
        if let primaryVibe = primaryVibe {
            self.preferredMeetingVibe = primaryVibe
            self.preferredMeetingVibes = vibes.isEmpty ? [primaryVibe] : vibes
        } else if let firstVibe = vibes.first {
            self.preferredMeetingVibe = firstVibe
            self.preferredMeetingVibes = vibes
        } else {
            self.preferredMeetingVibe = .casual
            self.preferredMeetingVibes = [.casual]
        }
        self.selfIntroduction = try container.decodeIfPresent(String.self, forKey: .selfIntroduction)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(icebreakerPrompts, forKey: .icebreakerPrompts)
        try container.encode(valuesTags, forKey: .valuesTags)
        try container.encode(hobbies, forKey: .hobbies)
        try container.encode(preferredMeetingVibe, forKey: .preferredMeetingVibe)
        if !preferredMeetingVibes.isEmpty {
            try container.encode(preferredMeetingVibes, forKey: .preferredMeetingVibes)
        }
        try container.encodeIfPresent(selfIntroduction, forKey: .selfIntroduction)
    }
}

// MARK: - 6. Moments
struct Moments: Codable, Equatable {
    var moments: [Moment]
    
    enum CodingKeys: String, CodingKey {
        case moments
    }
    
    init(moments: [Moment] = []) {
        self.moments = moments
    }
}

struct Moment: Codable, Equatable, Identifiable {
    let id: String
    var imageUrl: String?
    var caption: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case caption
    }
    
    init(id: String = UUID().uuidString, imageUrl: String? = nil, caption: String? = nil) {
        self.id = id
        self.imageUrl = imageUrl
        self.caption = caption
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
    
    init(visibilitySettings: VisibilitySettings, verifiedStatus: VerifiedStatus, dataSharingConsent: Bool, reportPreferences: ReportPreferences) {
        self.visibilitySettings = visibilitySettings
        self.verifiedStatus = verifiedStatus
        self.dataSharingConsent = dataSharingConsent
        self.reportPreferences = reportPreferences
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.visibilitySettings = try container.decode(VisibilitySettings.self, forKey: .visibilitySettings)
        self.verifiedStatus = try container.decode(VerifiedStatus.self, forKey: .verifiedStatus)
        
        // 处理 dataSharingConsent：可能是 Bool 或 Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .dataSharingConsent) {
            self.dataSharingConsent = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .dataSharingConsent) {
            self.dataSharingConsent = intValue != 0
        } else {
            // 尝试作为数字字符串
            let stringValue = try container.decode(String.self, forKey: .dataSharingConsent)
            self.dataSharingConsent = stringValue == "1" || stringValue.lowercased() == "true"
        }
        
        self.reportPreferences = try container.decode(ReportPreferences.self, forKey: .reportPreferences)
    }
}

// MARK: - Supporting Models

// Career Direction Data
struct CareerDirectionData: Codable, Equatable {
    let functions: [FunctionSelection]
    
    enum CodingKeys: String, CodingKey {
        case functions
    }
}

struct FunctionSelection: Codable, Equatable {
    let functionName: String
    let learnIn: [String]
    let guideIn: [String]
    
    enum CodingKeys: String, CodingKey {
        case functionName = "function_name"
        case learnIn = "learn_in"
        case guideIn = "guide_in"
    }
}

// Skill Development Data
struct SkillDevelopmentData: Codable, Equatable {
    let skills: [SkillSelection]
    
    enum CodingKeys: String, CodingKey {
        case skills
    }
}

struct SkillSelection: Codable, Equatable {
    let skillName: String
    var learnIn: Bool
    var guideIn: Bool
    
    enum CodingKeys: String, CodingKey {
        case skillName = "skill_name"
        case learnIn = "learn_in"
        case guideIn = "guide_in"
    }
    
    init(skillName: String, learnIn: Bool, guideIn: Bool) {
        self.skillName = skillName
        self.learnIn = learnIn
        self.guideIn = guideIn
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.skillName = try container.decode(String.self, forKey: .skillName)
        
        // 辅助函数：将值转换为 Bool（处理 Bool、Int、String）
        func decodeBool(forKey key: CodingKeys) throws -> Bool {
            if let boolValue = try? container.decode(Bool.self, forKey: key) {
                return boolValue
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                return intValue != 0
            } else {
                // 尝试作为数字字符串
                let stringValue = try container.decode(String.self, forKey: key)
                return stringValue == "1" || stringValue.lowercased() == "true"
            }
        }
        
        self.learnIn = try decodeBool(forKey: .learnIn)
        self.guideIn = try decodeBool(forKey: .guideIn)
    }
}

// Industry Transition Data
struct IndustryTransitionData: Codable, Equatable {
    let industries: [IndustrySelection]
    
    enum CodingKeys: String, CodingKey {
        case industries
    }
}

struct IndustrySelection: Codable, Equatable {
    let industryName: String
    var learnIn: Bool
    var guideIn: Bool
    
    enum CodingKeys: String, CodingKey {
        case industryName = "industry_name"
        case learnIn = "learn_in"
        case guideIn = "guide_in"
    }
}

// Available Timeslot Matrix (Sunday-Saturday × Morning/Noon/Afternoon/Evening/Night)
struct AvailableTimeslot: Codable, Equatable {
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

struct DayTimeslots: Codable, Equatable {
    let morning: Bool
    let noon: Bool
    let afternoon: Bool
    let evening: Bool
    let night: Bool
    
    enum CodingKeys: String, CodingKey {
        case morning, noon, afternoon, evening, night
    }
    
    init(morning: Bool, noon: Bool, afternoon: Bool, evening: Bool, night: Bool) {
        self.morning = morning
        self.noon = noon
        self.afternoon = afternoon
        self.evening = evening
        self.night = night
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 辅助函数：将值转换为 Bool（处理 Bool、Int、String）
        func decodeBool(forKey key: CodingKeys) throws -> Bool {
            if let boolValue = try? container.decode(Bool.self, forKey: key) {
                return boolValue
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                return intValue != 0
            } else {
                // 尝试作为数字字符串
                let stringValue = try container.decode(String.self, forKey: key)
                return stringValue == "1" || stringValue.lowercased() == "true"
            }
        }
        
        self.morning = try decodeBool(forKey: .morning)
        self.noon = try decodeBool(forKey: .noon)
        self.afternoon = try decodeBool(forKey: .afternoon)
        self.evening = try decodeBool(forKey: .evening)
        self.night = try decodeBool(forKey: .night)
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

enum NetworkingIntentionType: String, CaseIterable, Codable {
    case learnGrow = "Learn & Grow"
    case connectShare = "Connect & Share"
    case buildCollaborate = "Build & Collaborate"
    case unwindChat = "Unwind & Chat"
    
    var displayName: String {
        return self.rawValue
    }
    
    var subIntentions: [SubIntentionType] {
        switch self {
        case .learnGrow:
            return [.careerDirection, .skillDevelopment, .industryTransition]
        case .connectShare:
            return [.industryInsight, .roleBasedExperience]
        case .buildCollaborate:
            return [.cofounderMatch, .joinStartup, .ideaValidation]
        case .unwindChat:
            return [.casualCoffee, .workplaceWellbeing, .localMeetup, .interestSideProject]
        }
    }
}

enum SubIntentionType: String, CaseIterable, Codable {
    case careerDirection = "Career Direction & Planning"
    case skillDevelopment = "Skill Development / Learning Exchange"
    case industryTransition = "Industry Transition / Guidance"
    case industryInsight = "Industry Insight Discussion"
    case roleBasedExperience = "Role-Based Experience Swap"
    case cofounderMatch = "Startup Partner / Project Member Match"
    case joinStartup = "Join an Existing Startup / Project"
    case ideaValidation = "Idea Validation & Feedback"
    case casualCoffee = "Casual Coffee Chat / Make Friends"
    case workplaceWellbeing = "Workplace Well-being / Emotional Support"
    case localMeetup = "Local Meet-up / City Exploration"
    case interestSideProject = "Interest & Side Project Talk"
    
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
    case reflective = "Reflective"
    case goalOriented = "GoalOriented"
    case exploratory = "Exploratory"
    case supportive = "Supportive"
    
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
    let timeslot: VisibilityLevel
    
    enum CodingKeys: String, CodingKey {
        case company
        case email
        case phoneNumber = "phone_number"
        case location
        case skills
        case interests
        case timeslot
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
    
    init(allowReports: Bool, reportCategories: [String]) {
        self.allowReports = allowReports
        self.reportCategories = reportCategories
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 处理 allowReports：可能是 Bool 或 Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .allowReports) {
            self.allowReports = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .allowReports) {
            self.allowReports = intValue != 0
        } else {
            // 尝试作为数字字符串
            let stringValue = try container.decode(String.self, forKey: .allowReports)
            self.allowReports = stringValue == "1" || stringValue.lowercased() == "true"
        }
        
        self.reportCategories = try container.decode([String].self, forKey: .reportCategories)
    }
}

// MARK: - Profile Creation Helper
struct ProfileCreationData {
    var coreIdentity: CoreIdentity?
    var professionalBackground: ProfessionalBackground?
    var networkingIntention: NetworkingIntention?
    var networkingPreferences: NetworkingPreferences?
    var personalitySocial: PersonalitySocial?
    var moments: Moments?
    var privacyTrust: PrivacyTrust?
    
    var isComplete: Bool {
        return coreIdentity != nil &&
               professionalBackground != nil &&
               networkingIntention != nil &&
               networkingPreferences != nil &&
               personalitySocial != nil &&
               privacyTrust != nil
    }
    
    var completionPercentage: Double {
        let completedSections = [
            coreIdentity != nil,
            professionalBackground != nil,
            networkingIntention != nil,
            networkingPreferences != nil,
            personalitySocial != nil,
            moments != nil,
            privacyTrust != nil
        ]
        let completedCount = completedSections.filter { $0 }.count
        return Double(completedCount) / Double(completedSections.count) * 100
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
                timeZone: TimeZone.current.identifier
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: nil,
                jobTitle: nil,
                industry: nil,
                experienceLevel: .entry,
                education: nil,
                educations: nil,
                yearsOfExperience: nil,
                careerStage: .earlyCareer,
                skills: [],
                certifications: [],
                languagesSpoken: [],
                workExperiences: []
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .learnGrow,
                additionalIntentions: [],
                selectedSubIntentions: [],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .virtual,
                availableTimeslot: AvailableTimeslot.createDefault(),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: [],
                hobbies: [],
                preferredMeetingVibe: .casual,
                preferredMeetingVibes: [.casual],
                selfIntroduction: nil
            ),
            moments: nil,
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
            interests: .public_,
            timeslot: .private_
        )
    }
}

// MARK: - AvailableTimeslot Formatting
extension AvailableTimeslot {
    func formattedSummary() -> String {
        var availableSlots: [(day: String, periods: [String])] = []
        
        let days = [
            ("Mon", monday),
            ("Tue", tuesday),
            ("Wed", wednesday),
            ("Thu", thursday),
            ("Fri", friday),
            ("Sat", saturday),
            ("Sun", sunday)
        ]
        
        for (dayName, daySlots) in days {
            var periods: [String] = []
            if daySlots.morning { periods.append("AM") }
            if daySlots.noon { periods.append("Noon") }
            if daySlots.afternoon { periods.append("PM") }
            if daySlots.evening { periods.append("Evening") }
            if daySlots.night { periods.append("Night") }
            
            if !periods.isEmpty {
                availableSlots.append((day: dayName, periods: periods))
            }
        }
        
        if availableSlots.isEmpty {
            return "No availability set"
        }
        
        // Limit to first 3 days for summary
        let displaySlots = Array(availableSlots.prefix(3))
        let summary = displaySlots.map { "\($0.day) \($0.periods.joined(separator: ", "))" }.joined(separator: " | ")
        
        if availableSlots.count > 3 {
            return summary + " ..."
        }
        
        return summary
    }
}

// MARK: - Visibility Check Helper
extension VisibilityLevel {
    func isVisible(isConnection: Bool = false) -> Bool {
        switch self {
        case .public_:
            return true
        case .connectionsOnly:
            return isConnection
        case .private_:
            return false
        }
    }
}

// MARK: - Profile Validation
extension BrewNetProfile {
    var isValid: Bool {
        return !coreIdentity.name.isEmpty &&
               !coreIdentity.email.isEmpty &&
               !professionalBackground.skills.isEmpty &&
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
        if personalitySocial.valuesTags.isEmpty {
            errors.append("At least one value tag is required")
        }
        
        return errors
    }
    
    var completionPercentage: Double {
        let completedSections = [
            !coreIdentity.name.isEmpty,
            !coreIdentity.email.isEmpty,
            !professionalBackground.skills.isEmpty,
            !personalitySocial.valuesTags.isEmpty
        ].filter { $0 }.count
        
        return Double(completedSections) / 4.0
    }
    
    /// 转换为 InvitationProfile 用于发送邀请
    func toInvitationProfile() -> InvitationProfile {
        return InvitationProfile(
            name: coreIdentity.name,
            jobTitle: professionalBackground.jobTitle,
            company: professionalBackground.currentCompany,
            location: coreIdentity.location,
            bio: coreIdentity.bio,
            profileImage: coreIdentity.profileImage,
            expertise: professionalBackground.skills
        )
    }
}
