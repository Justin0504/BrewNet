import Foundation

// MARK: - User Behavioral Metrics

/// 用户行为量化指标 - 基于近期活动和互动模式计算
struct UserBehavioralMetrics: Codable {
    // ========== 行为指标 ==========
    let activityScore: Int // 活跃度分数 (0-10)
    let connectScore: Int // 连接意愿分数 (0-10)
    let mentorScore: Int // 导师潜力分数 (0-10)

    // ========== 原始行为数据 ==========
    let sessions7d: Int // 7天内会话数
    let messagesSent7d: Int // 7天内发送消息数
    let matches7d: Int // 7天内匹配数
    let lastActiveDays: Int // 最后活跃距今天数
    let responseRate30d: Double // 30天回复率
    let passRate: Double // 通过推荐比率
    let avgResponseTimeHours: Double // 平均回复时间(小时)
    let profilePublicnessScore: Double // 资料公开度分数
    let pastMentorshipCount: Int // 历史导师次数
    let isVerified: Bool // 是否已验证
    let isProUser: Bool // 是否为Pro用户
    let seniorityLevel: Double // 资历水平(0-1标准化)

    // ========== 计算时间戳 ==========
    let calculatedAt: Date

    enum CodingKeys: String, CodingKey {
        case activityScore = "activity_score"
        case connectScore = "connect_score"
        case mentorScore = "mentor_score"
        case sessions7d = "sessions_7d"
        case messagesSent7d = "messages_sent_7d"
        case matches7d = "matches_7d"
        case lastActiveDays = "last_active_days"
        case responseRate30d = "response_rate_30d"
        case passRate = "pass_rate"
        case avgResponseTimeHours = "avg_response_time_hours"
        case profilePublicnessScore = "profile_publicness_score"
        case pastMentorshipCount = "past_mentorship_count"
        case isVerified = "is_verified"
        case isProUser = "is_pro_user"
        case seniorityLevel = "seniority_level"
        case calculatedAt = "calculated_at"
    }

    /// 标准化函数：将值映射到[0,1]区间
    private static func normalize(_ value: Double, minValue: Double = 0.0, maxValue: Double = 1.0) -> Double {
        guard maxValue > minValue else { return 0.5 }
        return max(0.0, min(1.0, (value - minValue) / (maxValue - minValue)))
    }

    /// 计算活跃度分数 (0-10)
    /// 衡量用户在平台上的参与强度
    private static func calculateActivityScore(
        sessions7d: Int,
        messagesSent7d: Int,
        matches7d: Int,
        lastActiveDays: Int
    ) -> Int {
        // 归一化各项指标
        let sessionsNorm = Self.normalize(Double(sessions7d), minValue: 0, maxValue: 20.0)
        let messagesNorm = Self.normalize(Double(messagesSent7d), minValue: 0, maxValue: 50.0)
        let matchesNorm = Self.normalize(Double(matches7d), minValue: 0, maxValue: 10.0)
        let recencyNorm = Self.normalize(1.0 / (1.0 + Double(lastActiveDays)), minValue: 0, maxValue: 1.0)

        // 加权合成 (权重: 0.3, 0.3, 0.2, 0.2)
        let activityRaw = 0.3 * sessionsNorm +
                         0.3 * messagesNorm +
                         0.2 * matchesNorm +
                         0.2 * recencyNorm

        return Int(round(activityRaw * 10.0))
    }

    /// 计算连接意愿分数 (0-10)
    /// 表示用户愿意被他人接触的主观倾向
    private static func calculateConnectScore(
        responseRate30d: Double,
        passRate: Double,
        avgResponseTimeHours: Double,
        profilePublicnessScore: Double,
        isProUser: Bool
    ) -> Int {
        // 归一化各项指标
        let responseRateNorm = Self.normalize(responseRate30d, minValue: 0, maxValue: 1.0)
        let passRateNorm = Self.normalize(passRate, minValue: 0, maxValue: 1.0)
        let responseTimeNorm = Self.normalize(1.0 / (1.0 + avgResponseTimeHours), minValue: 0, maxValue: 1.0)
        let proBonus = isProUser ? 1.0 : 0.0

        // 加权合成 (权重: 0.35, 0.15, 0.15, 0.25, 0.10)
        let connectRaw = 0.25 * profilePublicnessScore +
                        0.35 * responseRateNorm +
                        0.15 * responseTimeNorm +
                        0.15 * passRateNorm +
                        0.10 * proBonus

        return Int(round(connectRaw * 10.0))
    }

    /// 计算导师潜力分数 (0-10)
    /// 衡量用户作为导师的可能性
    private static func calculateMentorScore(
        activityScore: Int,
        pastMentorshipCount: Int,
        isVerified: Bool,
        seniorityLevel: Double
    ) -> Int {
        let verifiedBonus = isVerified ? 1.0 : 0.0
        let mentorshipNorm = Self.normalize(Double(pastMentorshipCount), minValue: 0, maxValue: 20.0)
        let activityScoreNorm = Double(activityScore) / 10.0

        // 加权合成 (权重: 0.3, 0.25, 0.2, 0.15, 0.1)
        let mentorRaw = 0.3 * mentorshipNorm +
                       0.25 * verifiedBonus +
                       0.2 * seniorityLevel +
                       0.15 * activityScoreNorm +
                       0.1 * 0.5 // 假设平均会话评分为0.5，可后续扩展

        return Int(round(mentorRaw * 10.0))
    }

    /// 自定义解码器 - 支持缺失字段使用默认值
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解码行为指标分数（可能缺失，使用默认值5）
        self.activityScore = try container.decodeIfPresent(Int.self, forKey: .activityScore) ?? 5
        self.connectScore = try container.decodeIfPresent(Int.self, forKey: .connectScore) ?? 5
        self.mentorScore = try container.decodeIfPresent(Int.self, forKey: .mentorScore) ?? 5
        
        // 解码原始行为数据（可能缺失，使用默认值）
        self.sessions7d = try container.decodeIfPresent(Int.self, forKey: .sessions7d) ?? 0
        self.messagesSent7d = try container.decodeIfPresent(Int.self, forKey: .messagesSent7d) ?? 0
        self.matches7d = try container.decodeIfPresent(Int.self, forKey: .matches7d) ?? 0
        self.lastActiveDays = try container.decodeIfPresent(Int.self, forKey: .lastActiveDays) ?? 30
        self.responseRate30d = try container.decodeIfPresent(Double.self, forKey: .responseRate30d) ?? 0.5
        self.passRate = try container.decodeIfPresent(Double.self, forKey: .passRate) ?? 0.5
        self.avgResponseTimeHours = try container.decodeIfPresent(Double.self, forKey: .avgResponseTimeHours) ?? 24.0
        self.profilePublicnessScore = try container.decodeIfPresent(Double.self, forKey: .profilePublicnessScore) ?? 0.5
        self.pastMentorshipCount = try container.decodeIfPresent(Int.self, forKey: .pastMentorshipCount) ?? 0
        self.isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        self.isProUser = try container.decodeIfPresent(Bool.self, forKey: .isProUser) ?? false
        self.seniorityLevel = try container.decodeIfPresent(Double.self, forKey: .seniorityLevel) ?? 0.0
        
        // 解码计算时间戳
        if let dateString = try? container.decode(String.self, forKey: .calculatedAt) {
            self.calculatedAt = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else {
            self.calculatedAt = Date()
        }
    }

    /// 从原始数据创建行为指标
    init(
        sessions7d: Int = 0,
        messagesSent7d: Int = 0,
        matches7d: Int = 0,
        lastActiveDays: Int = 30,
        responseRate30d: Double = 0.5,
        passRate: Double = 0.5,
        avgResponseTimeHours: Double = 24.0,
        profilePublicnessScore: Double = 0.5,
        pastMentorshipCount: Int = 0,
        isVerified: Bool = false,
        isProUser: Bool = false,
        seniorityLevel: Double = 0.0,
        calculatedAt: Date = Date()
    ) {
        self.sessions7d = sessions7d
        self.messagesSent7d = messagesSent7d
        self.matches7d = matches7d
        self.lastActiveDays = lastActiveDays
        self.responseRate30d = responseRate30d
        self.passRate = passRate
        self.avgResponseTimeHours = avgResponseTimeHours
        self.profilePublicnessScore = profilePublicnessScore
        self.pastMentorshipCount = pastMentorshipCount
        self.isVerified = isVerified
        self.isProUser = isProUser
        self.seniorityLevel = seniorityLevel
        self.calculatedAt = calculatedAt

        // 计算各项分数（注意：mentorScore 依赖 activityScore，需先计算）
        let computedActivityScore = Self.calculateActivityScore(
            sessions7d: sessions7d,
            messagesSent7d: messagesSent7d,
            matches7d: matches7d,
            lastActiveDays: lastActiveDays
        )
        
        let computedConnectScore = Self.calculateConnectScore(
            responseRate30d: responseRate30d,
            passRate: passRate,
            avgResponseTimeHours: avgResponseTimeHours,
            profilePublicnessScore: profilePublicnessScore,
            isProUser: isProUser
        )
        
        self.activityScore = computedActivityScore
        self.connectScore = computedConnectScore
        self.mentorScore = Self.calculateMentorScore(
            activityScore: computedActivityScore,
            pastMentorshipCount: pastMentorshipCount,
            isVerified: isVerified,
            seniorityLevel: seniorityLevel
        )
    }

    /// 从用户资料和行为数据创建指标
    static func from(
        profile: BrewNetProfile,
        behaviorData: UserBehaviorData,
        isProUser: Bool = false
    ) -> UserBehavioralMetrics {
        // 计算资历水平 (基于经验年限)
        let expYears = min(Double(profile.professionalBackground.yearsOfExperience ?? 0), 20.0)
        let seniorityLevel = Self.normalize(expYears / 20.0)

        // 计算资料公开度 (基于隐私设置)
        let profilePublicnessScore = calculateProfilePublicnessScore(profile: profile)

        return UserBehavioralMetrics(
            sessions7d: behaviorData.sessions7d,
            messagesSent7d: behaviorData.messagesSent7d,
            matches7d: behaviorData.matches7d,
            lastActiveDays: behaviorData.lastActiveDays,
            responseRate30d: behaviorData.responseRate30d,
            passRate: behaviorData.passRate,
            avgResponseTimeHours: behaviorData.avgResponseTimeHours,
            profilePublicnessScore: profilePublicnessScore,
            pastMentorshipCount: behaviorData.pastMentorshipCount,
            isVerified: profile.privacyTrust.verifiedStatus == .verifiedProfessional,
            isProUser: isProUser,
            seniorityLevel: seniorityLevel
        )
    }

    /// 计算资料公开度分数
    private static func calculateProfilePublicnessScore(profile: BrewNetProfile) -> Double {
        // 基于隐私设置编码公开度 - 计算所有字段的平均公开度
        let settings = profile.privacyTrust.visibilitySettings
        let visibilityLevels = [
            settings.company,
            settings.email,
            settings.phoneNumber,
            settings.location,
            settings.skills,
            settings.interests,
            settings.timeslot
        ]
        
        let scores = visibilityLevels.map { level -> Double in
            switch level {
            case .public_:
                return 1.0
            case .connectionsOnly:
                return 0.6
            case .private_:
                return 0.2
            }
        }
        
        return scores.reduce(0.0, +) / Double(scores.count)
    }

    /// 获取综合行为分数 (用于排序)
    func getCombinedBehaviorScore(beta1: Double = 0.4, beta2: Double = 0.4, beta3: Double = 0.2) -> Double {
        return beta1 * Double(activityScore) +
               beta2 * Double(connectScore) +
               beta3 * Double(mentorScore)
    }

    /// 检查分数是否在有效范围内
    var isValid: Bool {
        return (0...10).contains(activityScore) &&
               (0...10).contains(connectScore) &&
               (0...10).contains(mentorScore)
    }
}

/// 用户行为原始数据结构
struct UserBehaviorData {
    let sessions7d: Int
    let messagesSent7d: Int
    let matches7d: Int
    let lastActiveDays: Int
    let responseRate30d: Double
    let passRate: Double
    let avgResponseTimeHours: Double
    let pastMentorshipCount: Int

    static let zero = UserBehaviorData(
        sessions7d: 0,
        messagesSent7d: 0,
        matches7d: 0,
        lastActiveDays: 30,
        responseRate30d: 0.0,
        passRate: 0.0,
        avgResponseTimeHours: 168.0, // 7天
        pastMentorshipCount: 0
    )
}

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

    // ========== 行为量化指标 ==========
    let behavioralMetrics: UserBehavioralMetrics?
    
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
        case behavioralMetrics = "behavioral_metrics"
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
        isVerified: Int,
        behavioralMetrics: UserBehavioralMetrics? = nil
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
        self.behavioralMetrics = behavioralMetrics
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

        self.behavioralMetrics = try container.decodeIfPresent(UserBehavioralMetrics.self, forKey: .behavioralMetrics)
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
            isVerified: profile.privacyTrust.verifiedStatus == .verifiedProfessional ? 1 : 0,
            behavioralMetrics: nil // 行为指标将通过 BehavioralMetricsService 异步加载
        )
    }

    /// 从 BrewNetProfile 和行为数据创建 UserTowerFeatures
    static func from(
        _ profile: BrewNetProfile,
        behaviorData: UserBehaviorData? = nil,
        isProUser: Bool = false
    ) -> UserTowerFeatures {
        let behavioralMetrics: UserBehavioralMetrics?

        if let behaviorData = behaviorData {
            behavioralMetrics = UserBehavioralMetrics.from(
                profile: profile,
                behaviorData: behaviorData,
                isProUser: isProUser
            )
        } else {
            behavioralMetrics = nil
        }

        return UserTowerFeatures(
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
            isVerified: profile.privacyTrust.verifiedStatus == .verifiedProfessional ? 1 : 0,
            behavioralMetrics: behavioralMetrics
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
        try container.encodeIfPresent(behavioralMetrics, forKey: .behavioralMetrics)
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

