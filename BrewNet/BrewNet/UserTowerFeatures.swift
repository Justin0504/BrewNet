import Foundation

// MARK: - User Tower Features Model

/// 用户塔特征模型 - 用于 Two-Tower 推荐系统
struct UserTowerFeatures: Codable {
    // ========== 稀疏特征 ==========
    let location: String?
    let timeZone: String?
    let industry: String?
    let experienceLevel: String?
    let careerStage: String?
    let mainIntention: String?
    
    // ========== 多值特征 ==========
    let skills: [String]
    let hobbies: [String]
    let values: [String]
    let languages: [String]
    let subIntentions: [String]
    
    // ========== 学习/教授配对 ==========
    let skillsToLearn: [String]
    let skillsToTeach: [String]
    let functionsToLearn: [String]
    let functionsToTeach: [String]
    
    // ========== 数值特征 ==========
    let yearsOfExperience: Double
    let profileCompletion: Double
    let isVerified: Int
    
    enum CodingKeys: String, CodingKey {
        case location
        case timeZone = "time_zone"
        case industry
        case experienceLevel = "experience_level"
        case careerStage = "career_stage"
        case mainIntention = "main_intention"
        case skills
        case hobbies
        case values
        case languages
        case subIntentions = "sub_intentions"
        case skillsToLearn = "skills_to_learn"
        case skillsToTeach = "skills_to_teach"
        case functionsToLearn = "functions_to_learn"
        case functionsToTeach = "functions_to_teach"
        case yearsOfExperience = "years_of_experience"
        case profileCompletion = "profile_completion"
        case isVerified = "is_verified"
    }
    
    /// 从 BrewNetProfile 转换为 UserTowerFeatures
    static func from(_ profile: BrewNetProfile) -> UserTowerFeatures {
        UserTowerFeatures(
            location: profile.coreIdentity.location,
            timeZone: profile.coreIdentity.timeZone,
            industry: profile.professionalBackground.industry,
            experienceLevel: profile.professionalBackground.experienceLevel.rawValue,
            careerStage: profile.professionalBackground.careerStage.rawValue,
            mainIntention: profile.networkingIntention.selectedIntention.rawValue,
            skills: profile.professionalBackground.skills,
            hobbies: profile.personalitySocial.hobbies,
            values: profile.personalitySocial.valuesTags,
            languages: profile.professionalBackground.languagesSpoken,
            subIntentions: profile.networkingIntention.selectedSubIntentions.map { $0.rawValue },
            skillsToLearn: extractSkills(profile, mode: .learn),
            skillsToTeach: extractSkills(profile, mode: .teach),
            functionsToLearn: extractFunctions(profile, mode: .learn),
            functionsToTeach: extractFunctions(profile, mode: .teach),
            yearsOfExperience: profile.professionalBackground.yearsOfExperience ?? 0,
            profileCompletion: profile.completionPercentage,
            isVerified: profile.privacyTrust.verifiedStatus == .verifiedProfessional ? 1 : 0
        )
    }
    
    private static func extractSkills(_ profile: BrewNetProfile, mode: ExtractMode) -> [String] {
        guard let skills = profile.networkingIntention.skillDevelopment?.skills else {
            return []
        }
        return skills.compactMap { skill in
            switch mode {
            case .learn where skill.learnIn:
                return skill.skillName
            case .teach where skill.guideIn:
                return skill.skillName
            default:
                return nil
            }
        }
    }
    
    private static func extractFunctions(_ profile: BrewNetProfile, mode: ExtractMode) -> [String] {
        guard let functions = profile.networkingIntention.careerDirection?.functions else {
            return []
        }
        return functions.compactMap { funcItem in
            switch mode {
            case .learn:
                return funcItem.learnIn.first
            case .teach:
                return funcItem.guideIn.first
            }
        }
    }
}

enum ExtractMode {
    case learn
    case teach
}

// MARK: - Feature Vocabularies

/// 特征词汇表 - 用于编码
struct FeatureVocabularies {
    /// 所有技能
    static let allSkills = [
        "Swift", "Python", "JavaScript", "TypeScript", "React", "Vue", "Angular",
        "iOS Development", "Android Development", "Web Development",
        "AI", "Machine Learning", "Deep Learning", "Data Science", "NLP",
        "Product Management", "Project Management", "Scrum", "Agile",
        "UX Design", "UI Design", "Interaction Design", "Visual Design",
        "DevOps", "Cloud Computing", "AWS", "Azure", "GCP",
        "Backend Development", "Frontend Development", "Full Stack",
        "Database Design", "SQL", "NoSQL",
        "Cybersecurity", "Blockchain", "Web3",
        "Marketing", "Growth Hacking", "SEO", "SEM",
        "Business Strategy", "Consulting", "Finance"
    ]
    
    /// 所有爱好
    static let allHobbies = [
        "Coffee Culture", "Photography", "Hiking", "Traveling", "Backpacking",
        "Reading", "Writing", "Blogging", "Podcasting",
        "Gaming", "Board Games", "Video Games",
        "Music", "Playing Instruments", "Concerts",
        "Cooking", "Baking", "Craft Beer", "Wine Tasting",
        "Fitness", "Yoga", "Meditation", "Running", "Cycling",
        "Art", "Painting", "Drawing", "Design",
        "Volunteering", "Social Impact", "Sustainability"
    ]
    
    /// 所有价值观
    static let allValues = [
        "Innovation", "Collaboration", "Curiosity", "Passion", "Growth",
        "Integrity", "Diversity", "Inclusion", "Equality",
        "Sustainability", "Environmental Impact", "Social Responsibility",
        "Excellence", "Quality", "Attention to Detail",
        "Work-Life Balance", "Wellbeing", "Mental Health",
        "Transparency", "Open Communication", "Trust"
    ]
    
    /// 所有行业
    static let allIndustries = [
        "Technology", "Software", "SaaS",
        "Finance", "FinTech", "Banking", "Investments",
        "Healthcare", "Medical Devices", "Biotech", "Pharma",
        "Education", "EdTech", "Training",
        "E-commerce", "Retail", "Consumer Goods",
        "Gaming", "Entertainment", "Media", "Content Creation",
        "Consulting", "Management Consulting", "Strategy Consulting",
        "Startup", "Entrepreneurship", "Venture Capital",
        "Enterprise", "B2B", "B2C",
        "Government", "Non-profit", "Social Impact",
        "Manufacturing", "Logistics", "Supply Chain"
    ]
    
    /// 所有意图
    static let allIntentions = [
        "learnGrow", "connectShare", "buildCollaborate", "unwindChat"
    ]
    
    /// 所有经验水平
    static let allExperienceLevels = [
        "Intern", "Entry", "Mid", "Senior", "Executive"
    ]
    
    /// 所有职业阶段
    static let allCareerStages = [
        "earlyCareer", "midLevel", "manager", "director", "executive"
    ]
}

// MARK: - Verification

extension UserTowerFeatures {
    /// 验证特征是否有效
    var isValid: Bool {
        // 至少需要有基本的特征信息
        return !(skills.isEmpty && hobbies.isEmpty && location == nil)
    }
    
    /// 获取特征摘要（用于调试）
    var summary: String {
        return """
        Location: \(location ?? "N/A")
        Industry: \(industry ?? "N/A")
        Skills: \(skills.prefix(3).joined(separator: ", "))
        Hobbies: \(hobbies.prefix(3).joined(separator: ", "))
        Intention: \(mainIntention ?? "N/A")
        """
    }
}

