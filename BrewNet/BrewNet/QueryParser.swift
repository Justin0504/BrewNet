import Foundation
import NaturalLanguage

// MARK: - Query Parser

/// 结构化查询意图
struct ParsedQuery {
    let rawText: String
    let tokens: [String]
    let entities: QueryEntities
    let modifiers: QueryModifiers
    let conceptTags: [String]
}

/// 实体识别结果
struct QueryEntities {
    var companies: [String] = []
    var roles: [String] = []
    var schools: [String] = []
    var skills: [String] = []
    var industries: [String] = []
    var numbers: [Double] = []
    
    var hasCompany: Bool { !companies.isEmpty }
    var hasRole: Bool { !roles.isEmpty }
    var hasSchool: Bool { !schools.isEmpty }
    var hasSkill: Bool { !skills.isEmpty }
    var hasNumber: Bool { !numbers.isEmpty }
}

/// 查询修饰符
struct QueryModifiers {
    var negations: [String] = []  // "not", "except"
    var emphasis: [String] = []   // "must", "only"
    var fuzzy: [String] = []      // "around", "about"
}

class QueryParser {
    
    static let shared = QueryParser()
    
    // MARK: - 领域词典
    
    private let companyDictionary: Set<String> = [
        // FAANG
        "google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix",
        // Big Tech
        "uber", "airbnb", "stripe", "openai", "tesla", "nvidia", "adobe", "salesforce",
        // Consulting (MBB)
        "mckinsey", "bain", "bcg", "boston consulting",
        // Finance
        "goldman", "goldman sachs", "morgan stanley", "jpmorgan", "jp morgan",
        "blackrock", "citadel",
        // Startups
        "stripe", "databricks", "figma", "notion", "canva"
    ]
    
    private let roleDictionary: Set<String> = [
        // Product
        "product manager", "pm", "program manager", "product owner",
        // Engineering
        "engineer", "software engineer", "swe", "developer", "programmer",
        "frontend engineer", "backend engineer", "fullstack engineer",
        "ml engineer", "data engineer", "devops engineer",
        // Data
        "data scientist", "data analyst", "analyst",
        // Design
        "designer", "product designer", "ux designer", "ui designer",
        // Leadership
        "founder", "ceo", "cto", "vp", "director", "manager", "lead",
        // Other
        "consultant", "researcher", "scientist"
    ]
    
    private let schoolDictionary: Set<String> = [
        // Ivy League (with full names)
        "harvard", "harvard university", "yale", "yale university",
        "princeton", "princeton university", "columbia", "columbia university",
        "penn", "upenn", "university of pennsylvania",
        "brown", "brown university", "dartmouth", "dartmouth college",
        "cornell", "cornell university",
        // Top US (Private)
        "stanford", "stanford university", "mit", "massachusetts institute of technology",
        "caltech", "california institute of technology", "duke", "duke university",
        "johns hopkins", "northwestern", "northwestern university",
        "carnegie mellon", "vanderbilt", "vanderbilt university",
        "rice", "rice university",
        // Top US (Public)
        "berkeley", "uc berkeley", "university of california berkeley",
        "michigan", "umich", "university of michigan",
        "ucla", "university of california los angeles",
        "virginia", "uva", "university of virginia",
        "unc", "north carolina", "university of north carolina",
        "georgia tech", "georgia institute of technology",
        "wisconsin", "university of wisconsin",
        "illinois", "university of illinois",
        "washington", "uw", "university of washington",
        "texas", "ut austin", "university of texas",
        "ucsd", "uc san diego",
        // Top Business Schools
        "wharton", "sloan", "haas", "kellogg", "booth", "uchicago", "university of chicago",
        // Top International
        "oxford", "university of oxford", "cambridge", "university of cambridge",
        "imperial", "imperial college", "eth zurich", "toronto", "university of toronto",
        // Top China
        "tsinghua", "tsinghua university", "peking", "peking university", "pku",
        "fudan", "fudan university", "sjtu", "shanghai jiao tong", "shanghai jiao tong university",
        "zhejiang", "zju", "zhejiang university", "ustc", "nanjing", "nju", "nanjing university"
    ]
    
    private let skillDictionary: Set<String> = [
        // Programming Languages
        "python", "java", "javascript", "typescript", "c++", "go", "rust", "swift",
        "kotlin", "scala", "ruby", "php",
        // Web Development
        "react", "vue", "angular", "node", "django", "flask",
        "frontend", "backend", "fullstack", "full stack",
        "frontend development", "backend development", "full stack development",
        // System & Architecture
        "system design", "distributed systems", "distributed system",
        "microservices", "cloud architecture", "scalability",
        "devops", "kubernetes", "docker", "aws", "gcp", "azure",
        // Data/ML
        "machine learning", "ml", "ai", "artificial intelligence",
        "deep learning", "nlp", "natural language processing",
        "computer vision", "data science", "data engineering",
        "tensorflow", "pytorch", "sql", "nosql", "big data",
        // Product & Design
        "product management", "product design", "ux design", "ui design",
        "user experience", "user interface", "design thinking",
        // Business
        "leadership", "marketing", "sales", "strategy", "consulting",
        "project management", "agile", "scrum"
    ]
    
    // MARK: - 同义词映射（扩展版）
    
    private let synonymMap: [String: [String]] = [
        // ===== 职位缩写 & 同义词 =====
        // Product
        "pm": ["product manager", "program manager", "project manager"],
        "apm": ["associate product manager"],
        "spm": ["senior product manager", "staff product manager"],
        "gpm": ["group product manager"],
        "tpm": ["technical program manager", "technical project manager"],
        "product": ["product manager", "product owner"],
        
        // Engineering - General
        "swe": ["software engineer", "software developer", "engineer"],
        "sde": ["software development engineer", "software engineer"],
        "engineer": ["software engineer", "developer", "programmer", "coder"],
        "developer": ["engineer", "software engineer", "programmer"],
        "dev": ["developer", "engineer"],
        
        // Engineering - Frontend
        "frontend": ["front-end", "front end", "client side", "ui engineer"],
        "fe": ["frontend", "frontend engineer", "frontend developer"],
        
        // Engineering - Backend
        "backend": ["back-end", "back end", "server side", "api engineer"],
        "be": ["backend", "backend engineer", "backend developer"],
        
        // Engineering - Fullstack
        "fullstack": ["full-stack", "full stack", "fullstack engineer"],
        "fs": ["fullstack", "fullstack engineer"],
        
        // Engineering - Mobile
        "mobile": ["mobile engineer", "mobile developer", "ios", "android"],
        "ios": ["mobile", "iphone", "swift developer"],
        "android": ["mobile", "kotlin developer"],
        
        // Engineering - ML/AI
        "mle": ["ml engineer", "machine learning engineer"],
        "ai engineer": ["ml engineer", "machine learning engineer", "ai specialist"],
        
        // Data Roles
        "ds": ["data scientist", "data science"],
        "da": ["data analyst", "analyst"],
        "de": ["data engineer", "data engineering"],
        "bi": ["business intelligence", "business analyst"],
        
        // Design
        "designer": ["product designer", "ux designer", "ui designer"],
        "ux": ["user experience", "product design"],
        "ui": ["user interface", "visual design"],
        "uxd": ["ux designer"],
        "uid": ["ui designer"],
        
        // Leadership
        "ceo": ["chief executive officer", "founder", "co-founder"],
        "cto": ["chief technology officer", "vp engineering"],
        "cpo": ["chief product officer", "vp product"],
        "vp": ["vice president", "director", "head"],
        "director": ["lead", "manager", "head"],
        "lead": ["tech lead", "team lead", "engineering lead"],
        
        // Other Roles
        "consultant": ["advisor", "strategist", "analyst"],
        "researcher": ["research scientist", "scientist"],
        "founder": ["entrepreneur", "startup founder", "cofounder", "co-founder"],
        
        // ===== 技术栈缩写 & 同义词 =====
        // Languages
        "js": ["javascript"],
        "ts": ["typescript"],
        "py": ["python"],
        "golang": ["go"],
        "c++": ["cpp", "cplusplus"],
        "c#": ["csharp"],
        
        // Frontend Frameworks
        "react": ["reactjs", "react.js"],
        "vue": ["vuejs", "vue.js"],
        "angular": ["angularjs"],
        "nextjs": ["next", "next.js"],
        
        // Backend Frameworks
        "nodejs": ["node", "node.js"],
        "django": ["python web"],
        "flask": ["python api"],
        "spring": ["spring boot", "java framework"],
        "express": ["expressjs", "express.js"],
        
        // DevOps & Cloud
        "k8s": ["kubernetes"],
        "aws": ["amazon web services", "cloud"],
        "gcp": ["google cloud", "google cloud platform"],
        "azure": ["microsoft cloud"],
        "docker": ["containerization", "containers"],
        "ci/cd": ["cicd", "continuous integration", "continuous deployment"],
        
        // Databases
        "sql": ["mysql", "postgresql", "relational database"],
        "nosql": ["mongodb", "dynamodb", "document database"],
        "postgres": ["postgresql"],
        "mongo": ["mongodb"],
        
        // ML/AI Frameworks
        "ml": ["machine learning", "ai"],
        "ai": ["artificial intelligence", "machine learning"],
        "dl": ["deep learning"],
        "nlp": ["natural language processing", "language model"],
        "cv": ["computer vision", "image recognition"],
        "tensorflow": ["tf"],
        "pytorch": ["torch"],
        
        // System Design
        "distributed": ["distributed systems", "distributed system", "scalability"],
        "microservices": ["microservice architecture", "service oriented"],
        "system design": ["architecture", "system architecture"],
        
        // ===== 公司缩写 & 别名 =====
        // FAANG
        "fb": ["facebook", "meta"],
        "meta": ["facebook"],
        "msft": ["microsoft"],
        "amzn": ["amazon"],
        "googl": ["google", "alphabet"],
        "goog": ["google", "alphabet"],
        "nflx": ["netflix"],
        
        // Big Tech
        "apple": ["aapl"],
        "tesla": ["tsla"],
        "nvidia": ["nvda"],
        
        // Consulting
        "mckinsey": ["mckinsey & company"],
        "bain": ["bain & company"],
        "bcg": ["boston consulting", "boston consulting group"],
        "mbb": ["mckinsey", "bain", "bcg"],
        
        // Finance
        "gs": ["goldman", "goldman sachs"],
        "ms": ["morgan stanley"],
        "jpm": ["jpmorgan", "jp morgan"],
        
        // ===== 学位 & 教育 =====
        "bs": ["bachelor", "bachelor's", "undergraduate", "undergrad"],
        "ba": ["bachelor", "bachelor's", "undergraduate"],
        "ms": ["master", "master's", "grad", "graduate"],
        "ma": ["master", "master's", "graduate"],
        "mba": ["master of business administration", "business school"],
        "phd": ["doctor", "doctorate", "doctoral"],
        "undergrad": ["undergraduate", "bachelor"],
        "grad": ["graduate", "master", "phd"],
        
        // ===== 经验水平 =====
        "junior": ["entry level", "new grad", "fresh grad", "jr"],
        "mid": ["mid-level", "intermediate"],
        "senior": ["sr", "experienced", "lead"],
        "staff": ["principal", "architect", "expert"],
        "principal": ["staff", "senior staff", "distinguished"],
        
        // ===== 其他常用同义词 =====
        "mentor": ["coach", "advisor", "guide", "tutor"],
        "alumni": ["alum", "graduate", "graduated"],
        "cofounder": ["co-founder", "founder"],
        "startup": ["early stage", "seed", "series a"],
        "intern": ["internship", "summer intern"],
        "remote": ["work from home", "wfh", "distributed"],
        "onsite": ["in-person", "office"],
        "hybrid": ["flexible", "remote + office"],
        
        // ===== 时间单位 =====
        "years": ["year", "yrs", "yr", "y"],
        "months": ["month", "mo", "mos"],
        
        // ===== 中文映射（可选）=====
        "后端": ["backend"],
        "前端": ["frontend"],
        "全栈": ["fullstack"],
        "工程师": ["engineer"],
        "产品经理": ["product manager", "pm"],
        "数据科学家": ["data scientist"],
        "设计师": ["designer"]
    ]
    
    // MARK: - 概念标签映射（扩展版）
    
    private let conceptTagMap: [String: [String]] = [
        // ===== 公司类别 =====
        "faang": ["facebook", "meta", "apple", "amazon", "netflix", "google"],
        "fang": ["facebook", "meta", "apple", "netflix", "google"],
        "manga": ["microsoft", "apple", "nvidia", "google", "amazon"],
        "big tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix", "uber", "airbnb", "tesla", "nvidia"],
        "top tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix", "uber", "stripe", "openai"],
        "unicorn": ["stripe", "databricks", "figma", "notion", "canva", "databricks"],
        "startup": ["stripe", "figma", "notion", "canva", "openai"],
        
        // ===== 咨询 =====
        "mbb": ["mckinsey", "bain", "bcg"],
        "consulting": ["mckinsey", "bain", "bcg", "deloitte", "accenture", "oliver wyman"],
        "strategy": ["mckinsey", "bain", "bcg"],
        
        // ===== 金融 =====
        "investment banking": ["goldman sachs", "morgan stanley", "jpmorgan", "citi"],
        "wall street": ["goldman sachs", "morgan stanley", "jpmorgan", "blackrock", "citadel"],
        "hedge fund": ["citadel", "bridgewater", "renaissance", "two sigma"],
        "private equity": ["blackstone", "kkr", "carlyle", "apollo"],
        
        // ===== 学校类别 =====
        "ivy league": ["harvard", "yale", "princeton", "columbia", "penn", "upenn", "brown", "dartmouth", "cornell"],
        "ivy": ["harvard", "yale", "princeton", "columbia", "penn", "upenn", "brown", "dartmouth", "cornell"],
        "ivy plus": ["harvard", "yale", "princeton", "stanford", "mit", "columbia", "penn", "brown", "dartmouth", "cornell"],
        "top us": ["stanford", "mit", "harvard", "princeton", "yale", "berkeley", "columbia", "caltech"],
        "top engineering": ["mit", "stanford", "berkeley", "carnegie mellon", "georgia tech", "caltech", "illinois"],
        "top cs": ["stanford", "mit", "berkeley", "carnegie mellon", "illinois", "washington", "cornell"],
        "top business": ["wharton", "harvard", "stanford", "kellogg", "booth", "sloan", "haas"],
        "top china": ["tsinghua", "peking", "fudan", "sjtu", "zhejiang", "ustc"],
        
        // ===== 技能类别 =====
        "web development": ["react", "vue", "angular", "node", "javascript", "typescript", "html", "css"],
        "frontend stack": ["react", "vue", "angular", "javascript", "typescript", "html", "css"],
        "backend stack": ["node", "python", "java", "go", "django", "flask", "spring"],
        "fullstack": ["react", "node", "javascript", "typescript", "python"],
        "data science": ["python", "sql", "machine learning", "statistics", "pandas", "numpy"],
        "machine learning": ["python", "tensorflow", "pytorch", "scikit-learn", "deep learning"],
        "ai": ["machine learning", "deep learning", "nlp", "computer vision", "tensorflow", "pytorch"],
        "cloud": ["aws", "gcp", "azure", "kubernetes", "docker"],
        "devops": ["kubernetes", "docker", "ci/cd", "jenkins", "terraform"],
        
        // ===== 职位级别 =====
        "entry level": ["junior", "new grad", "associate"],
        "experienced": ["senior", "staff", "principal", "lead"],
        "leadership": ["director", "vp", "cto", "ceo", "head"],
        
        // ===== 意图类别 =====
        "mentorship": ["mentor", "coach", "advisor", "guide"],
        "networking": ["connect", "meet", "network", "coffee chat"],
        "hiring": ["recruiting", "job", "opportunity", "opening"],
        "learning": ["learn", "teach", "training", "education"]
    ]
    
    // MARK: - 主解析函数
    
    func parse(_ query: String) -> ParsedQuery {
        print("\n🔍 Parsing query: \"\(query)\"")
        
        let normalized = query.lowercased()
        
        // 1. 基础分词
        let basicTokens = tokenize(normalized)
        
        // 2. 识别实体（包括短语和单词）
        let entities = extractEntities(from: normalized, tokens: basicTokens)
        printEntities(entities)
        
        // 3. 合并分词结果（基础词 + 实体短语）
        var tokens = basicTokens
        tokens.append(contentsOf: entities.companies)
        tokens.append(contentsOf: entities.roles)
        tokens.append(contentsOf: entities.schools)
        tokens.append(contentsOf: entities.skills)
        
        // 去重
        tokens = Array(Set(tokens))
        
        print("  📝 Tokens (with phrases): \(tokens.prefix(10).joined(separator: ", "))")
        
        // 4. 识别修饰符
        let modifiers = extractModifiers(from: tokens)
        
        // 5. 同义词扩展
        var expandedTokens = expandSynonyms(tokens: tokens)
        
        // 6. 概念标签扩展
        let (conceptExpanded, conceptTags) = expandConcepts(tokens: expandedTokens, query: normalized)
        expandedTokens = conceptExpanded
        
        if !conceptTags.isEmpty {
            print("  🏷️  Concept tags: \(conceptTags.joined(separator: ", "))")
        }
        
        return ParsedQuery(
            rawText: normalized,
            tokens: expandedTokens,
            entities: entities,
            modifiers: modifiers,
            conceptTags: conceptTags
        )
    }
    
    // MARK: - 实体识别
    
    private func extractEntities(
        from text: String,
        tokens: [String]
    ) -> QueryEntities {
        var entities = QueryEntities()
        
        // 优先匹配多词短语（长度从大到小）
        let companyPhrases = matchPhrases(in: text, dictionary: companyDictionary)
        let rolePhrases = matchPhrases(in: text, dictionary: roleDictionary)
        let schoolPhrases = matchPhrases(in: text, dictionary: schoolDictionary)
        let skillPhrases = matchPhrases(in: text, dictionary: skillDictionary)
        
        entities.companies.append(contentsOf: companyPhrases)
        entities.roles.append(contentsOf: rolePhrases)
        entities.schools.append(contentsOf: schoolPhrases)
        entities.skills.append(contentsOf: skillPhrases)
        
        // 单词匹配（只在没有匹配到短语时）
        let matchedPhraseWords = Set(
            (companyPhrases + rolePhrases + schoolPhrases + skillPhrases)
                .flatMap { $0.split(separator: " ").map { String($0) } }
        )
        
        for token in tokens {
            // 如果这个词已经是某个短语的一部分，跳过
            if matchedPhraseWords.contains(token) { continue }
            
            if companyDictionary.contains(token) {
                entities.companies.append(token)
            }
            if roleDictionary.contains(token) {
                entities.roles.append(token)
            }
            if schoolDictionary.contains(token) {
                entities.schools.append(token)
            }
            if skillDictionary.contains(token) {
                entities.skills.append(token)
            }
        }
        
        // 去重
        entities.companies = Array(Set(entities.companies))
        entities.roles = Array(Set(entities.roles))
        entities.schools = Array(Set(entities.schools))
        entities.skills = Array(Set(entities.skills))
        
        // 提取数字
        entities.numbers = extractNumbers(from: text)
        
        return entities
    }
    
    private func matchPhrases(in text: String, dictionary: Set<String>) -> [String] {
        var matches: [String] = []
        for phrase in dictionary where phrase.contains(" ") {
            // 精确匹配
            if text.contains(phrase) {
                matches.append(phrase)
            }
            // 模糊匹配（容错拼写错误）
            else {
                // 检查查询文本中是否有与短语相似的部分
                let words = text.split(separator: " ").map { String($0) }
                let phraseWords = phrase.split(separator: " ").map { String($0) }
                
                // 如果短语的每个词都能在查询中找到相似匹配，则认为匹配成功
                var allWordsMatch = true
                for phraseWord in phraseWords {
                    let hasMatch = words.contains { queryWord in
                        // 完全匹配或高相似度匹配（> 85%）
                        queryWord == phraseWord || similarity(queryWord, phraseWord) > 0.85
                    }
                    if !hasMatch {
                        allWordsMatch = false
                        break
                    }
                }
                
                if allWordsMatch {
                    matches.append(phrase)
                    print("  🔍 Fuzzy phrase match: '\(text)' ≈ '\(phrase)'")
                }
            }
        }
        return matches
    }
    
    /// 计算字符串相似度（用于容错匹配）
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.isEmpty { return 1.0 }
        
        let distance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(distance)) / Double(longer.count)
    }
    
    /// 计算编辑距离
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
                        matrix[i-1][j] + 1,
                        matrix[i][j-1] + 1,
                        matrix[i-1][j-1] + 1
                    )
                }
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    private func printEntities(_ entities: QueryEntities) {
        if entities.hasCompany {
            print("  🏢 Companies: \(entities.companies.joined(separator: ", "))")
        }
        if entities.hasRole {
            print("  💼 Roles: \(entities.roles.joined(separator: ", "))")
        }
        if entities.hasSchool {
            print("  🎓 Schools: \(entities.schools.joined(separator: ", "))")
        }
        if entities.hasSkill {
            print("  🛠️  Skills: \(entities.skills.joined(separator: ", "))")
        }
        if entities.hasNumber {
            print("  🔢 Numbers: \(entities.numbers.map { String($0) }.joined(separator: ", "))")
        }
    }
    
    // MARK: - 修饰符识别
    
    private func extractModifiers(from tokens: [String]) -> QueryModifiers {
        var modifiers = QueryModifiers()
        
        for (index, token) in tokens.enumerated() {
            if ["not", "no", "except", "without"].contains(token) {
                if index + 1 < tokens.count {
                    modifiers.negations.append(tokens[index + 1])
                }
            }
            
            if ["must", "only", "require", "need"].contains(token) {
                if index + 1 < tokens.count {
                    modifiers.emphasis.append(tokens[index + 1])
                }
            }
            
            if ["around", "about", "approximately", "~"].contains(token) {
                if index + 1 < tokens.count {
                    modifiers.fuzzy.append(tokens[index + 1])
                }
            }
        }
        
        return modifiers
    }
    
    // MARK: - 同义词扩展（优化版）
    
    /// 扩展同义词，支持双向映射和智能过滤
    private func expandSynonyms(tokens: [String]) -> [String] {
        var expanded = Set(tokens)  // 使用 Set 自动去重
        var addedSynonyms: [String] = []
        
        for token in tokens {
            // 1. 正向映射：token -> synonyms (缩写 -> 全称)
            if let synonyms = synonymMap[token] {
                let newSynonyms = synonyms.filter { !expanded.contains($0) }
                addedSynonyms.append(contentsOf: newSynonyms)
                expanded.formUnion(newSynonyms)
            }
            
            // 2. 反向映射：在 synonymMap 的值中查找 token (全称 -> 缩写)
            for (key, values) in synonymMap {
                if values.contains(token) && !expanded.contains(key) {
                    // 找到了，说明 token 是某个缩写的同义词
                    // 添加该缩写和其他同义词
                    if !addedSynonyms.contains(key) {
                        addedSynonyms.append(key)
                    }
                    expanded.insert(key)
                    
                    // 也添加同组的其他同义词（限制数量避免过度扩展）
                    let otherSynonyms = values.filter { $0 != token && !expanded.contains($0) }
                    if otherSynonyms.count <= 3 {  // 最多添加3个额外同义词
                        addedSynonyms.append(contentsOf: otherSynonyms)
                        expanded.formUnion(otherSynonyms)
                    }
                }
            }
        }
        
        if !addedSynonyms.isEmpty {
            print("  🔄 Synonyms expanded: \(addedSynonyms.prefix(8).joined(separator: ", "))\(addedSynonyms.count > 8 ? " +\(addedSynonyms.count - 8) more" : "")")
        }
        
        return Array(expanded)
    }
    
    /// 获取语义组（用于软匹配）
    private func getSemanticGroup(for term: String) -> Set<String> {
        var group = Set<String>([term])
        
        // 从 synonymMap 中查找所有相关词
        if let synonyms = synonymMap[term] {
            group.formUnion(synonyms)
        }
        
        for (key, values) in synonymMap {
            if values.contains(term) {
                group.insert(key)
                group.formUnion(values)
            }
        }
        
        return group
    }
    
    // MARK: - 概念标签扩展
    
    private func expandConcepts(tokens: [String], query: String) -> ([String], [String]) {
        var expanded = tokens
        var conceptTags: [String] = []
        
        for (concept, expansions) in conceptTagMap {
            if query.contains(concept) {
                expanded.append(contentsOf: expansions)
                conceptTags.append(concept)
            }
        }
        
        return (expanded, conceptTags)
    }
    
    // MARK: - 辅助函数
    
    // 停用词列表 - 常见的无意义词汇
    private let stopWords: Set<String> = [
        // 英文介词
        "in", "at", "on", "to", "for", "of", "with", "from", "by", "as",
        // 英文冠词
        "a", "an", "the",
        // 英文代词
        "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
        "my", "your", "his", "her", "its", "our", "their",
        // 英文连词
        "and", "or", "but", "so", "yet",
        // 英文动词
        "is", "am", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did",
        "will", "would", "can", "could", "may", "might", "should",
        // 其他常见词
        "that", "this", "these", "those", "there", "here",
        "who", "what", "where", "when", "why", "how",
        "want", "wanna", "looking", "find", "person", "someone",
        // 通用词汇（单独出现无意义）
        "experience", "exp", "graduated", "graduate", "work", "working"
    ]
    
    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 && !stopWords.contains($0) }
    }
    
    private func extractNumbers(from text: String) -> [Double] {
        let components = text.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
        return components.compactMap { Double($0) }
    }
}

