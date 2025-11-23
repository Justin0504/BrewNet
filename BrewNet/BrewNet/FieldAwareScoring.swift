import Foundation

// MARK: - Field-Aware Scoring

/// 字段权重配置
enum FieldZone {
    case zoneA  // 高权: Current Title, Company, Top Skills
    case zoneB  // 中权: Bio, Past Experience, School
    case zoneC  // 低权: Hobbies, Interests
    
    var weight: Double {
        switch self {
        case .zoneA: return 3.0
        case .zoneB: return 1.5
        case .zoneC: return 0.5
        }
    }
    
    var name: String {
        switch self {
        case .zoneA: return "Current (×3.0)"
        case .zoneB: return "Recent (×1.5)"
        case .zoneC: return "Background (×0.5)"
        }
    }
}

/// 分区索引文本
struct ZonedSearchableText {
    let zoneA: String  // 高权文本
    let zoneB: String  // 中权文本
    let zoneC: String  // 低权文本
    
    /// 构建分区文本
    static func from(profile: BrewNetProfile) -> ZonedSearchableText {
        // Zone A: 当前职位、公司、核心技能（最重要）
        var zoneA = [
            profile.professionalBackground.jobTitle ?? "",
            profile.professionalBackground.currentCompany ?? "",
            profile.professionalBackground.industry ?? ""
        ]
        // 只取前5个技能
        zoneA.append(contentsOf: Array(profile.professionalBackground.skills.prefix(5)))
        
        // Zone B: 简介、过往经历、教育（中等重要）
        var zoneB = [
            profile.coreIdentity.bio ?? "",
            profile.coreIdentity.location ?? "",
            profile.professionalBackground.education ?? ""
        ]
        
        // 教育经历
        if let educations = profile.professionalBackground.educations {
            for education in educations.prefix(3) {
                zoneB.append(education.schoolName)
                zoneB.append(education.degree.displayName)
                if let field = education.fieldOfStudy {
                    zoneB.append(field)
                }
            }
        }
        
        // 工作经历（最近3个）
        for exp in profile.professionalBackground.workExperiences.prefix(3) {
            zoneB.append(exp.companyName)
            if let position = exp.position {
                zoneB.append(position)
            }
            zoneB.append(contentsOf: Array(exp.highlightedSkills.prefix(3)))
        }
        
        // Zone C: 爱好、兴趣、价值观（较低权重）
        var zoneC = profile.personalitySocial.hobbies
        zoneC.append(contentsOf: profile.personalitySocial.valuesTags)
        if let intro = profile.personalitySocial.selfIntroduction {
            zoneC.append(intro)
        }
        
        return ZonedSearchableText(
            zoneA: zoneA.joined(separator: " ").lowercased(),
            zoneB: zoneB.joined(separator: " ").lowercased(),
            zoneC: zoneC.joined(separator: " ").lowercased()
        )
    }
}

/// 字段感知评分
class FieldAwareScoring {
    
    /// 计算字段感知分数
    /// - Parameters:
    ///   - profile: 用户资料
    ///   - tokens: 查询关键词
    /// - Returns: 分区加权分数
    func computeScore(
        profile: BrewNetProfile,
        tokens: [String]
    ) -> Double {
        let zonedText = ZonedSearchableText.from(profile: profile)
        var score: Double = 0.0
        var matchDetails: [(token: String, zone: FieldZone)] = []
        
        // 确保所有 tokens 都转换为小写进行比较
        for token in tokens {
            if token.count < 2 { continue }
            
            // 将 token 转换为小写以确保不区分大小写的匹配
            let lowercasedToken = token.lowercased()
            
            // 在不同区域搜索，应用不同权重
            if zonedText.zoneA.contains(lowercasedToken) {
                score += FieldZone.zoneA.weight
                matchDetails.append((token, .zoneA))
            } else if zonedText.zoneB.contains(lowercasedToken) {
                score += FieldZone.zoneB.weight
                matchDetails.append((token, .zoneB))
            } else if zonedText.zoneC.contains(lowercasedToken) {
                score += FieldZone.zoneC.weight
                matchDetails.append((token, .zoneC))
            }
        }
        
        // 打印匹配详情（只显示前5个）
        if !matchDetails.isEmpty {
            let topMatches = matchDetails.prefix(5)
            for (token, zone) in topMatches {
                print("  ✓ '\(token)' in \(zone.name)")
            }
            if matchDetails.count > 5 {
                print("  ... and \(matchDetails.count - 5) more")
            }
        }
        
        return score
    }
    
    /// 特定实体的精确匹配（用于结构化查询）
    /// - Parameters:
    ///   - profile: 用户资料
    ///   - entities: 解析出的实体
    /// - Returns: 实体匹配分数
    func computeEntityScore(
        profile: BrewNetProfile,
        entities: QueryEntities
    ) -> Double {
        var score: Double = 0.0
        
        // 公司匹配（当前公司 +5分，过往公司 +2分，确保所有文本比较都转换为小写）
        if let currentCompany = profile.professionalBackground.currentCompany?.lowercased() {
            for company in entities.companies {
                // 确保查询中的公司名称也转换为小写进行比较
                let lowercasedCompany = company.lowercased()
                if currentCompany.contains(lowercasedCompany) || lowercasedCompany.contains(currentCompany) {
                    score += 5.0
                    print("  🏢 Current company match: \(company) (+5.0)")
                    break
                }
            }
        }
        
        // 检查过往公司（确保所有文本比较都转换为小写）
        for experience in profile.professionalBackground.workExperiences.prefix(5) {
            let pastCompany = experience.companyName.lowercased()
            for company in entities.companies {
                // 确保查询中的公司名称也转换为小写进行比较
                let lowercasedCompany = company.lowercased()
                if pastCompany.contains(lowercasedCompany) || lowercasedCompany.contains(pastCompany) {
                    // 计算时间衰减
                    let currentYear = Double(Calendar.current.component(.year, from: Date()))
                    let endYear = experience.endYear.map { Double($0) } ?? currentYear
                    let yearsAgo = currentYear - endYear
                    let timeWeight = SoftMatching.timeDecay(yearsAgo: yearsAgo, halfLife: 3.0)
                    let weightedScore = 2.0 * timeWeight
                    
                    score += weightedScore
                    print("  🏢 Past company match: \(company) (+\(String(format: "%.1f", weightedScore)))")
                    break
                }
            }
        }
        
        // 职位匹配（当前职位 +4分，确保所有文本比较都转换为小写）
        if let currentRole = profile.professionalBackground.jobTitle?.lowercased() {
            for role in entities.roles {
                // 确保查询中的职位名称也转换为小写进行比较
                let lowercasedRole = role.lowercased()
                if currentRole.contains(lowercasedRole) || lowercasedRole.contains(currentRole) ||
                   SoftMatching.fuzzySimilarity(string1: currentRole, string2: lowercasedRole) > 0.7 {
                    score += 4.0
                    print("  💼 Current role match: \(role) (+4.0)")
                    break
                }
            }
        }
        
        // 学校匹配（+3分每个，确保所有文本比较都转换为小写）
        if let educations = profile.professionalBackground.educations {
            for education in educations {
                let schoolName = education.schoolName.lowercased()
                for school in entities.schools {
                    // 确保查询中的学校名称也转换为小写进行比较
                    let lowercasedSchool = school.lowercased()
                    if schoolName.contains(lowercasedSchool) || lowercasedSchool.contains(schoolName) {
                        score += 3.0
                        print("  🎓 School match: \(school) (+3.0)")
                        break
                    }
                }
            }
        }
        
        // 技能匹配（+1分每个，最多+5分，确保所有文本比较都转换为小写）
        let matchedSkills = profile.professionalBackground.skills.filter { skill in
            let lowercasedSkill = skill.lowercased()
            return entities.skills.contains(where: { querySkill in
                let lowercasedQuerySkill = querySkill.lowercased()
                return lowercasedSkill.contains(lowercasedQuerySkill) || lowercasedQuerySkill.contains(lowercasedSkill)
            })
        }
        
        if !matchedSkills.isEmpty {
            let skillScore = min(Double(matchedSkills.count), 5.0)
            score += skillScore
            print("  🛠️  Skill matches: \(matchedSkills.prefix(3).joined(separator: ", ")) (+\(String(format: "%.1f", skillScore)))")
        }
        
        return score
    }
}

