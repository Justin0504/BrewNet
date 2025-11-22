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
        // Zone A: 当前职位、公司、核心技能、About Me、工作技能和职责（最重要）⭐
        var zoneA = [
            profile.professionalBackground.jobTitle ?? "",
            profile.professionalBackground.currentCompany ?? "",
            profile.professionalBackground.industry ?? ""
        ]
        
        // ⭐ 提升 About Me (bio) 到 Zone A - 包含关键职业信息
        if let bio = profile.coreIdentity.bio {
            zoneA.append(bio)
        }
        
        // 核心技能（前5个）
        zoneA.append(contentsOf: Array(profile.professionalBackground.skills.prefix(5)))
        
        // ⭐ 提升最近工作经历的 Role Highlights 和 Skills 到 Zone A（最近1个）
        if let recentExp = profile.professionalBackground.workExperiences.first {
            // 最近工作的职责/角色亮点 - 最重要的信息
            if let responsibilities = recentExp.responsibilities {
                zoneA.append(responsibilities)
            }
            // 最近工作的所有关键技能
            zoneA.append(contentsOf: recentExp.highlightedSkills)
        }
        
        // Zone B: 职业介绍、过往经历、教育（中等重要）
        var zoneB = [
            profile.coreIdentity.location ?? "",
            profile.professionalBackground.education ?? ""
        ]
        
        // 添加职业自我介绍（Self Introduction）
        if let selfIntro = profile.personalitySocial.selfIntroduction {
            zoneB.append(selfIntro)
        }
        
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
        
        // 过往工作经历（第2-3个）- 公司和职位
        for exp in profile.professionalBackground.workExperiences.dropFirst().prefix(2) {
            zoneB.append(exp.companyName)
            if let position = exp.position {
                zoneB.append(position)
            }
            // 过往工作的职责和技能权重稍低
            if let responsibilities = exp.responsibilities {
                zoneB.append(responsibilities)
            }
            zoneB.append(contentsOf: exp.highlightedSkills)
        }
        
        // Zone C: 爱好、兴趣、价值观（较低权重）
        var zoneC = profile.personalitySocial.hobbies
        zoneC.append(contentsOf: profile.personalitySocial.valuesTags)
        
        return ZonedSearchableText(
            zoneA: zoneA.joined(separator: " ").lowercased(),
            zoneB: zoneB.joined(separator: " ").lowercased(),
            zoneC: zoneC.joined(separator: " ").lowercased()
        )
    }
}

/// 字段感知评分
class FieldAwareScoring {
    
    // MARK: - 同义词映射（简化版，与 QueryParser 保持一致）
    
    /// 常见同义词映射表（用于评分时的软匹配）⭐ 扩展版
    private let commonSynonyms: [String: Set<String>] = [
        // 职位同义词
        "engineer": ["developer", "programmer", "swe", "sde"],
        "developer": ["engineer", "programmer", "swe", "sde"],
        "pm": ["product manager", "program manager"],
        "swe": ["software engineer", "engineer", "developer"],
        
        // 技术栈同义词
        "frontend": ["front-end", "fe", "client side"],
        "backend": ["back-end", "be", "server side"],
        "fullstack": ["full-stack", "fs", "full stack"],
        
        // ⭐ ML/AI 同义词组（完整映射）
        "ml": ["machine learning", "ai", "artificial intelligence", "deep learning"],
        "ai": ["artificial intelligence", "machine learning", "ml", "deep learning"],
        "machine learning": ["ml", "ai", "artificial intelligence", "deep learning"],
        "deep learning": ["ml", "ai", "machine learning", "artificial intelligence"],
        "artificial intelligence": ["ai", "ml", "machine learning", "deep learning"],
        
        // 编程语言
        "js": ["javascript"],
        "javascript": ["js"],
        "ts": ["typescript"],
        "typescript": ["ts"],
        "py": ["python"],
        "python": ["py"],
        
        // 框架和工具
        "react": ["reactjs"],
        "reactjs": ["react"],
        "vue": ["vuejs"],
        "vuejs": ["vue"],
        "k8s": ["kubernetes"],
        "kubernetes": ["k8s"],
        
        // 云平台
        "aws": ["amazon web services"],
        "amazon web services": ["aws"],
        
        // 公司
        "google": ["alphabet"],
        "alphabet": ["google"],
        "facebook": ["meta"],
        "meta": ["facebook"]
    ]
    
    /// 检查两个词是否是同义词
    private func areSynonyms(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        
        if w1 == w2 { return true }
        
        // 检查 w1 是否在 w2 的同义词集合中
        if let synonyms = commonSynonyms[w1], synonyms.contains(w2) {
            return true
        }
        
        // 反向检查：w2 是否在 w1 的同义词集合中
        if let synonyms = commonSynonyms[w2], synonyms.contains(w1) {
            return true
        }
        
        return false
    }
    
    /// 检查 token 是否在文本中（支持同义词）
    private func containsWithSynonyms(_ text: String, token: String) -> Bool {
        // 1. 直接包含
        if text.contains(token) {
            return true
        }
        
        // 2. 同义词匹配
        let words = text.split(separator: " ").map { String($0) }
        for word in words {
            if areSynonyms(token, word) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - 相似度计算
    
    /// 计算字符串相似度（用于容错匹配）
    /// - Parameters:
    ///   - s1: 字符串1
    ///   - s2: 字符串2
    /// - Returns: 相似度 [0, 1]，1表示完全相同
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.isEmpty { return 1.0 }
        
        // 计算编辑距离
        let distance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(distance)) / Double(longer.count)
    }
    
    /// 计算编辑距离（Levenshtein Distance）
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                if s1Array[i-1] == s2Array[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,      // deletion
                        matrix[i][j-1] + 1,      // insertion
                        matrix[i-1][j-1] + 1     // substitution
                    )
                }
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    // 停用词列表 - 常见的无意义词汇（扩展版）
    private let stopWords: Set<String> = [
        // 英文介词
        "in", "at", "on", "to", "for", "of", "with", "from", "by", "as",
        "across", "through", "into", "over", "under", "between", "among",
        "within", "without", "during", "before", "after", "above", "below",
        // 英文冠词
        "a", "an", "the",
        // 英文代词
        "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
        "my", "your", "his", "her", "its", "our", "their",
        // 英文连词
        "and", "or", "but", "so", "yet", "nor",
        // 英文动词（常见无意义动词）
        "is", "am", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did",
        "will", "would", "can", "could", "may", "might", "should", "must",
        "get", "got", "getting", "make", "made", "making",
        "work", "works", "worked", "working",  // ⭐ 添加 works
        "go", "goes", "went", "going",
        "come", "comes", "came", "coming",
        "take", "takes", "took", "taking",
        "give", "gives", "gave", "giving",
        "use", "uses", "used", "using",
        "teach", "teaches", "taught", "teaching",  // ⭐ 添加 teach 相关词
        "build", "builds", "built", "building",    // ⭐ 添加 build 相关词
        "create", "creates", "created", "creating", // ⭐ 添加 create 相关词
        "develop", "develops", "developed", "developing", // ⭐ 添加 develop 相关词
        "design", "designs", "designed", "designing",     // ⭐ 添加 design 相关词 (注意: "designer" 是职位)
        "manage", "manages", "managed", "managing",       // ⭐ 添加 manage 相关词 (注意: "manager" 是职位)
        "lead", "leads", "led", "leading",                // ⭐ 添加 lead 相关词 (注意: "leader" 是职位)
        // 其他常见词
        "that", "this", "these", "those", "there", "here",
        "who", "what", "where", "when", "why", "how",
        "want", "wanna", "looking", "find", "person", "someone", "anyone",
        "very", "much", "more", "most", "many", "some", "any", "all",
        // 通用词汇（单独出现无意义）
        "experience", "exp", "experienced", "graduate", "graduated", "graduating",
        "learn", "learning", "learned",  // ⭐ 添加 learn 相关词
        "train", "training", "trained"   // ⭐ 添加 train 相关词
    ]
    
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
        var matchedSynonymGroups: Set<String> = []  // ⭐ 记录已匹配的同义词组
        
        // 1. 找出所有短语（包含空格的token）
        let phrases = tokens.filter { $0.contains(" ") }
        
        // 2. 找出短语中包含的单词
        let phraseWords = Set(phrases.flatMap { $0.split(separator: " ").map { String($0) } })
        
        for token in tokens {
            if token.count < 2 { continue }
            
            // 过滤停用词
            if stopWords.contains(token) { continue }
            
            // 如果这个词是某个短语的一部分，跳过（避免重复计分）
            if phraseWords.contains(token) { continue }
            
            // ⭐ 检查是否已经为同义词组计分
            // 如果这个 token 属于某个同义词组，且该组已经计分，则跳过
            let synonymGroup = getSynonymGroupKey(for: token)
            if matchedSynonymGroups.contains(synonymGroup) {
                continue
            }
            
            // 在不同区域搜索，应用不同权重（支持同义词）
            if containsWithSynonyms(zonedText.zoneA, token: token) {
                score += FieldZone.zoneA.weight
                matchDetails.append((token, .zoneA))
                matchedSynonymGroups.insert(synonymGroup)  // ⭐ 标记该同义词组已计分
            } else if containsWithSynonyms(zonedText.zoneB, token: token) {
                score += FieldZone.zoneB.weight
                matchDetails.append((token, .zoneB))
                matchedSynonymGroups.insert(synonymGroup)  // ⭐ 标记该同义词组已计分
            } else if containsWithSynonyms(zonedText.zoneC, token: token) {
                score += FieldZone.zoneC.weight
                matchDetails.append((token, .zoneC))
                matchedSynonymGroups.insert(synonymGroup)  // ⭐ 标记该同义词组已计分
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
    
    /// 获取同义词组的唯一标识符
    /// 同义词组内的所有词返回相同的key，非同义词返回自身
    private func getSynonymGroupKey(for term: String) -> String {
        let t = term.lowercased()
        
        // 检查是否在 commonSynonyms 中有定义
        if let synonyms = commonSynonyms[t] {
            // 返回该组中字典序最小的词作为 key（保证一致性）
            var allTerms = synonyms
            allTerms.insert(t)
            return allTerms.sorted().first ?? t
        }
        
        // 反向查找：是否作为某个词的同义词出现
        for (key, values) in commonSynonyms {
            if values.contains(t) {
                var allTerms = values
                allTerms.insert(key)
                return allTerms.sorted().first ?? t
            }
        }
        
        // 不是同义词，返回自身
        return t
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
        
        // 公司匹配（当前公司 +5分，过往公司 +2分）
        if let currentCompany = profile.professionalBackground.currentCompany?.lowercased() {
            for company in entities.companies {
                if currentCompany.contains(company) || company.contains(currentCompany) {
                    score += 5.0
                    print("  🏢 Current company match: \(company) (+5.0)")
                    break
                }
            }
        }
        
        // 检查过往公司
        for experience in profile.professionalBackground.workExperiences.prefix(5) {
            let pastCompany = experience.companyName.lowercased()
            for company in entities.companies {
                if pastCompany.contains(company) || company.contains(pastCompany) {
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
        
        // 职位匹配（当前职位 +4分）
        if let currentRole = profile.professionalBackground.jobTitle?.lowercased() {
            for role in entities.roles {
                if currentRole.contains(role) || role.contains(currentRole) ||
                   SoftMatching.fuzzySimilarity(string1: currentRole, string2: role) > 0.7 {
                    score += 4.0
                    print("  💼 Current role match: \(role) (+4.0)")
                    break
                }
            }
        }
        
        // 学校匹配（+3分每个）
        if let educations = profile.professionalBackground.educations {
            for education in educations {
                let schoolName = education.schoolName.lowercased()
                for school in entities.schools {
                    var isMatch = false
                    
                    // 1. 精确包含匹配
                    if schoolName.contains(school) || school.contains(schoolName) {
                        isMatch = true
                    }
                    // 2. 特殊简称处理（使用模糊匹配容错拼写错误）
                    else if school == "umich" {
                        // 检查学校名称中是否包含 "michigan" 或类似词（容错拼写）
                        let schoolWords = schoolName.split(separator: " ").map { String($0) }
                        for word in schoolWords {
                            if word == "michigan" || similarity(word, "michigan") > 0.85 {
                                isMatch = true
                                if word != "michigan" {
                                    print("  🔍 Fuzzy word match: '\(word)' ≈ 'michigan' (similarity: \(String(format: "%.1f%%", similarity(word, "michigan") * 100)))")
                                }
                                break
                            }
                        }
                    }
                    else if school == "stanford" && (schoolName.contains("stanford") || similarity(schoolName, "stanford university") > 0.85) {
                        isMatch = true
                    }
                    else if school == "mit" && (schoolName.contains("massachusetts institute") || schoolName.contains("mit")) {
                        isMatch = true
                    }
                    else if school == "berkeley" && (schoolName.contains("berkeley") || similarity(schoolName, "uc berkeley") > 0.85) {
                        isMatch = true
                    }
                    else if school == "fudan" {
                        let schoolWords = schoolName.split(separator: " ").map { String($0) }
                        for word in schoolWords {
                            if word == "fudan" || similarity(word, "fudan") > 0.85 {
                                isMatch = true
                                break
                            }
                        }
                    }
                    // 3. 完整短语的模糊匹配（容错拼写错误，相似度 > 85%）
                    if !isMatch {
                        let sim = similarity(school, schoolName)
                        if sim > 0.85 {
                            isMatch = true
                            print("  🔍 Fuzzy school match: '\(school)' ≈ '\(education.schoolName)' (similarity: \(String(format: "%.1f%%", sim * 100)))")
                        }
                    }
                    
                    if isMatch {
                        score += 3.0
                        print("  🎓 School match: \(school) → \(education.schoolName) (+3.0)")
                        break
                    }
                }
            }
        }
        
        // 技能匹配（+1分每个，最多+5分）
        let matchedSkills = profile.professionalBackground.skills.filter { skill in
            entities.skills.contains(where: { querySkill in
                skill.lowercased().contains(querySkill) || querySkill.contains(skill.lowercased())
            })
        }
        
        if !matchedSkills.isEmpty {
            let skillScore = min(Double(matchedSkills.count), 5.0)
            score += skillScore
            print("  🛠️  Skill matches: \(matchedSkills.prefix(3).joined(separator: ", ")) (+\(String(format: "%.1f", skillScore)))")
        }
        
        // ⭐ 行业匹配（当前行业 +6分，过往行业经验 +3分）
        if !entities.industries.isEmpty {
            // 检查当前行业
            if let currentIndustry = profile.professionalBackground.industry?.lowercased() {
                for industry in entities.industries {
                    if currentIndustry.contains(industry) || industry.contains(currentIndustry) {
                        score += 6.0
                        print("  🏭 Current industry match: \(industry) (+6.0)")
                        break
                    }
                }
            }
            
            // 检查工作经历中的行业关键词（从公司名、职位、职责中推断）
            for experience in profile.professionalBackground.workExperiences.prefix(5) {
                let expText = [
                    experience.companyName,
                    experience.position ?? "",
                    experience.responsibilities ?? ""
                ].joined(separator: " ").lowercased()
                
                for industry in entities.industries {
                    if expText.contains(industry) {
                        // 计算时间衰减
                        let currentYear = Double(Calendar.current.component(.year, from: Date()))
                        let endYear = experience.endYear.map { Double($0) } ?? currentYear
                        let yearsAgo = currentYear - endYear
                        let timeWeight = SoftMatching.timeDecay(yearsAgo: yearsAgo, halfLife: 3.0)
                        let weightedScore = 3.0 * timeWeight
                        
                        score += weightedScore
                        print("  🏭 Past industry experience: \(industry) (+\(String(format: "%.1f", weightedScore)))")
                        break
                    }
                }
            }
        }
        
        return score
    }
}

