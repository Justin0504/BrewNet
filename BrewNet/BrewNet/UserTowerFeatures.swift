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
        case yearsOfExperience = "years_of_experience"
        case profileCompletion = "profile_completion"
        case isVerified = "is_verified"
    }
    
    // 标准初始化器（用于从BrewNetProfile创建）
    init(
        location: String?,
        timeZone: String?,
        industry: String?,
        experienceLevel: String?,
        careerStage: String?,
        mainIntention: String?,
        skills: [String],
        hobbies: [String],
        values: [String],
        languages: [String],
        subIntentions: [String],
        skillsToLearn: [String],
        skillsToTeach: [String],
        yearsOfExperience: Double,
        profileCompletion: Double,
        isVerified: Int
    ) {
        self.location = location
        self.timeZone = timeZone
        self.industry = industry
        self.experienceLevel = experienceLevel
        self.careerStage = careerStage
        self.mainIntention = mainIntention
        self.skills = skills
        self.hobbies = hobbies
        self.values = values
        self.languages = languages
        self.subIntentions = subIntentions
        self.skillsToLearn = skillsToLearn
        self.skillsToTeach = skillsToTeach
        self.yearsOfExperience = yearsOfExperience
        self.profileCompletion = profileCompletion
        self.isVerified = isVerified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.location = try container.decodeIfPresent(String.self, forKey: .location)
        self.timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
        self.industry = try container.decodeIfPresent(String.self, forKey: .industry)
        self.experienceLevel = try container.decodeIfPresent(String.self, forKey: .experienceLevel)
        self.careerStage = try container.decodeIfPresent(String.self, forKey: .careerStage)
        self.mainIntention = try container.decodeIfPresent(String.self, forKey: .mainIntention)

        self.skills = try container.decodeIfPresent([String].self, forKey: .skills) ?? []
        self.hobbies = try container.decodeIfPresent([String].self, forKey: .hobbies) ?? []
        self.values = try container.decodeIfPresent([String].self, forKey: .values) ?? []
        self.languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? []
        self.subIntentions = try container.decodeIfPresent([String].self, forKey: .subIntentions) ?? []
        self.skillsToLearn = try container.decodeIfPresent([String].self, forKey: .skillsToLearn) ?? []
        self.skillsToTeach = try container.decodeIfPresent([String].self, forKey: .skillsToTeach) ?? []

        self.yearsOfExperience = try container.decodeIfPresent(Double.self, forKey: .yearsOfExperience) ?? 0.0
        self.profileCompletion = try container.decodeIfPresent(Double.self, forKey: .profileCompletion) ?? 0.5 // 默认50%

        // 灵活处理 is_verified 字段（支持 Int, Bool, String 类型）
        if let intValue = try? container.decode(Int.self, forKey: .isVerified) {
            self.isVerified = intValue
        } else if let boolValue = try? container.decode(Bool.self, forKey: .isVerified) {
            self.isVerified = boolValue ? 1 : 0
        } else if let stringValue = try? container.decode(String.self, forKey: .isVerified) {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "t", "yes", "y"].contains(normalized) {
                self.isVerified = 1
            } else {
                self.isVerified = 0
            }
        } else {
            self.isVerified = 0
        }
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
            yearsOfExperience: profile.professionalBackground.yearsOfExperience ?? 0,
            profileCompletion: profile.completionPercentage,
            isVerified: profile.privacyTrust.verifiedStatus == .verifiedProfessional ? 1 : 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(timeZone, forKey: .timeZone)
        try container.encodeIfPresent(industry, forKey: .industry)
        try container.encodeIfPresent(experienceLevel, forKey: .experienceLevel)
        try container.encodeIfPresent(careerStage, forKey: .careerStage)
        try container.encodeIfPresent(mainIntention, forKey: .mainIntention)

        try container.encode(skills, forKey: .skills)
        try container.encode(hobbies, forKey: .hobbies)
        try container.encode(values, forKey: .values)
        try container.encode(languages, forKey: .languages)
        try container.encode(subIntentions, forKey: .subIntentions)
        try container.encode(skillsToLearn, forKey: .skillsToLearn)
        try container.encode(skillsToTeach, forKey: .skillsToTeach)

        try container.encode(yearsOfExperience, forKey: .yearsOfExperience)
        try container.encode(profileCompletion, forKey: .profileCompletion)
        try container.encode(isVerified, forKey: .isVerified)
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
    
    /// 所有子意图
    static let allSubIntentions: [String] = SubIntentionType.allCases.map { $0.rawValue }
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

