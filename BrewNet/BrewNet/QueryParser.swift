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
        // Ivy League
        "harvard", "yale", "princeton", "columbia", "penn", "upenn",
        "brown", "dartmouth", "cornell",
        // Top US
        "stanford", "mit", "berkeley", "caltech", "uchicago", "duke",
        "northwestern", "johns hopkins", "carnegie mellon",
        // Top International
        "oxford", "cambridge", "imperial", "eth zurich",
        // Top China
        "tsinghua", "peking", "fudan", "sjtu", "shanghai jiao tong",
        "zhejiang", "zju", "ustc", "nanjing", "nju"
    ]
    
    private let skillDictionary: Set<String> = [
        // Programming
        "python", "java", "javascript", "typescript", "c++", "go", "rust", "swift",
        // Web
        "react", "vue", "angular", "node", "django", "flask",
        // Data/ML
        "machine learning", "ml", "ai", "deep learning", "nlp", "computer vision",
        "tensorflow", "pytorch", "sql",
        // Other
        "leadership", "marketing", "sales", "design", "ux", "ui"
    ]
    
    // MARK: - 同义词映射
    
    private let synonymMap: [String: [String]] = [
        // 职位缩写
        "pm": ["product manager", "program manager", "project manager"],
        "swe": ["software engineer", "software developer", "engineer"],
        "ds": ["data scientist"],
        "ml": ["machine learning"],
        "ai": ["artificial intelligence", "machine learning"],
        "ux": ["user experience"],
        "ui": ["user interface"],
        
        // 公司缩写
        "fb": ["facebook", "meta"],
        "msft": ["microsoft"],
        "amzn": ["amazon"],
        "googl": ["google", "alphabet"],
        
        // 学位
        "bs": ["bachelor", "bachelor's"],
        "ms": ["master", "master's"],
        "mba": ["master of business administration"],
        "phd": ["doctor", "doctorate"],
        
        // 其他
        "mentor": ["coach", "advisor", "guide"],
        "alumni": ["alum", "graduate", "graduated"],
        "founder": ["entrepreneur", "startup owner"],
        "years": ["year", "yrs", "yr"],
        "experience": ["exp", "experienced"]
    ]
    
    // MARK: - 概念标签映射
    
    private let conceptTagMap: [String: [String]] = [
        "top tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix", "uber"],
        "faang": ["facebook", "meta", "apple", "amazon", "netflix", "google"],
        "big tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix", "uber", "airbnb"],
        "mbb": ["mckinsey", "bain", "bcg"],
        "consulting": ["mckinsey", "bain", "bcg", "deloitte", "accenture"],
        "ivy league": ["harvard", "yale", "princeton", "columbia", "penn", "brown", "dartmouth", "cornell"],
        "ivy": ["harvard", "yale", "princeton", "columbia", "penn", "brown", "dartmouth", "cornell"],
        "stanford": ["stanford university"],
        "mit": ["massachusetts institute of technology"],
        "unicorn": ["stripe", "databricks", "figma", "notion", "canva"]
    ]
    
    // MARK: - 主解析函数
    
    func parse(_ query: String) -> ParsedQuery {
        print("\n🔍 Parsing query: \"\(query)\"")
        
        let normalized = query.lowercased()
        
        // 1. 基础分词
        let tokens = tokenize(normalized)
        print("  📝 Tokens: \(tokens.prefix(10).joined(separator: ", "))")
        
        // 2. 实体识别
        let entities = extractEntities(from: normalized, tokens: tokens)
        printEntities(entities)
        
        // 3. 识别修饰符
        let modifiers = extractModifiers(from: tokens)
        
        // 4. 同义词扩展
        var expandedTokens = expandSynonyms(tokens: tokens)
        
        // 5. 概念标签扩展
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
        
        // 使用词典匹配（单词）
        for token in tokens {
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
        
        // 多词短语匹配
        entities.companies.append(contentsOf: matchPhrases(in: text, dictionary: companyDictionary))
        entities.roles.append(contentsOf: matchPhrases(in: text, dictionary: roleDictionary))
        entities.schools.append(contentsOf: matchPhrases(in: text, dictionary: schoolDictionary))
        entities.skills.append(contentsOf: matchPhrases(in: text, dictionary: skillDictionary))
        
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
            if text.contains(phrase) {
                matches.append(phrase)
            }
        }
        return matches
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
    
    // MARK: - 同义词扩展
    
    private func expandSynonyms(tokens: [String]) -> [String] {
        var expanded = tokens
        var addedSynonyms: [String] = []
        
        for token in tokens {
            if let synonyms = synonymMap[token] {
                addedSynonyms.append(contentsOf: synonyms)
                expanded.append(contentsOf: synonyms)
            }
        }
        
        if !addedSynonyms.isEmpty {
            print("  🔄 Synonyms added: \(addedSynonyms.joined(separator: ", "))")
        }
        
        return expanded
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
    
    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 }
    }
    
    private func extractNumbers(from text: String) -> [Double] {
        let components = text.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
        return components.compactMap { Double($0) }
    }
}

