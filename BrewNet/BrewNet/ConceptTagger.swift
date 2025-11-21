import Foundation

// MARK: - Concept Tagging System

/// 概念标签（用于语义理解）
enum ConceptTag: String, CaseIterable {
    case bigTech = "tag_big_tech"
    case faang = "tag_faang"
    case startup = "tag_startup"
    case unicorn = "tag_unicorn"
    case ivyLeague = "tag_ivy_league"
    case topMBA = "tag_top_mba"
    case mbb = "tag_mbb"
    case finance = "tag_finance"
    case consulting = "tag_consulting"
    
    var displayName: String {
        switch self {
        case .bigTech: return "Big Tech"
        case .faang: return "FAANG"
        case .startup: return "Startup"
        case .unicorn: return "Unicorn"
        case .ivyLeague: return "Ivy League"
        case .topMBA: return "Top MBA"
        case .mbb: return "MBB"
        case .finance: return "Finance"
        case .consulting: return "Consulting"
        }
    }
}

class ConceptTagger {
    
    static let shared = ConceptTagger()
    
    // MARK: - 公司分类
    
    private static let bigTechCompanies: Set<String> = [
        "google", "alphabet", "facebook", "meta", "amazon", "apple",
        "microsoft", "netflix", "tesla", "nvidia", "uber", "airbnb"
    ]
    
    private static let faangCompanies: Set<String> = [
        "facebook", "meta", "apple", "amazon", "netflix", "google", "alphabet"
    ]
    
    private static let mbbCompanies: Set<String> = [
        "mckinsey", "bain", "bcg", "boston consulting"
    ]
    
    private static let consultingCompanies: Set<String> = [
        "mckinsey", "bain", "bcg", "deloitte", "pwc", "ey", "kpmg",
        "accenture", "oliver wyman", "monitor deloitte"
    ]
    
    private static let financeCompanies: Set<String> = [
        "goldman sachs", "goldman", "morgan stanley", "jpmorgan", "jp morgan",
        "citigroup", "bank of america", "blackrock", "citadel", "bridgewater"
    ]
    
    private static let unicornCompanies: Set<String> = [
        "stripe", "spacex", "databricks", "canva", "figma", "notion",
        "plaid", "instacart", "doordash", "coinbase"
    ]
    
    // MARK: - 学校分类
    
    private static let ivyLeagueSchools: Set<String> = [
        "harvard", "yale", "princeton", "columbia", "penn", "upenn",
        "brown", "dartmouth", "cornell"
    ]
    
    private static let topMBASchools: Set<String> = [
        "harvard", "stanford", "wharton", "penn", "mit sloan", "kellogg",
        "booth", "chicago", "columbia", "berkeley haas", "haas"
    ]
    
    // MARK: - 标签生成
    
    /// 为用户 Profile 生成概念标签
    static func generateTags(for profile: BrewNetProfile) -> Set<ConceptTag> {
        var tags: Set<ConceptTag> = []
        
        // === 公司标签 ===
        if let company = profile.professionalBackground.currentCompany?.lowercased() {
            // Big Tech
            if bigTechCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.bigTech)
            }
            
            // FAANG
            if faangCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.faang)
            }
            
            // MBB
            if mbbCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.mbb)
                tags.insert(.consulting)
            }
            
            // Consulting
            if consultingCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.consulting)
            }
            
            // Finance
            if financeCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.finance)
            }
            
            // Unicorn
            if unicornCompanies.contains(where: { company.contains($0) || $0.contains(company) }) {
                tags.insert(.unicorn)
                tags.insert(.startup)
            }
            
            // Startup（通过关键词或职业阶段判断）
            if company.contains("startup") || 
               profile.professionalBackground.careerStage == .founder ||
               profile.professionalBackground.careerStage == .earlyCareer {
                tags.insert(.startup)
            }
        }
        
        // === 学校标签 ===
        if let educations = profile.professionalBackground.educations {
            for education in educations {
                let school = education.schoolName.lowercased()
                
                // Ivy League
                if ivyLeagueSchools.contains(where: { school.contains($0) || $0.contains(school) }) {
                    tags.insert(.ivyLeague)
                }
                
                // Top MBA
                if topMBASchools.contains(where: { school.contains($0) || $0.contains(school) }) &&
                   (education.degree == .mba || education.fieldOfStudy?.lowercased().contains("business") == true) {
                    tags.insert(.topMBA)
                }
            }
        }
        
        return tags
    }
    
    /// 查询中的概念标签映射
    static func mapQueryToConcepts(query: String) -> Set<ConceptTag> {
        var concepts: Set<ConceptTag> = []
        let lowercased = query.lowercased()
        
        // Top Tech / Big Tech
        if lowercased.contains("top tech") || 
           lowercased.contains("big tech") ||
           lowercased.contains("large tech") {
            concepts.insert(.bigTech)
        }
        
        // FAANG
        if lowercased.contains("faang") || lowercased.contains("f.a.a.n.g") {
            concepts.insert(.faang)
        }
        
        // MBB
        if lowercased.contains("mbb") || 
           lowercased.contains("top consulting") ||
           lowercased.contains("management consulting") {
            concepts.insert(.mbb)
        }
        
        // Consulting
        if lowercased.contains("consulting") || lowercased.contains("consultant") {
            concepts.insert(.consulting)
        }
        
        // Finance
        if lowercased.contains("investment bank") || 
           lowercased.contains("finance") ||
           lowercased.contains("wall street") {
            concepts.insert(.finance)
        }
        
        // Ivy League
        if lowercased.contains("ivy league") || 
           lowercased.contains("ivy") ||
           lowercased.contains("elite university") {
            concepts.insert(.ivyLeague)
        }
        
        // Top MBA
        if lowercased.contains("top mba") || 
           lowercased.contains("m7") ||
           lowercased.contains("elite mba") {
            concepts.insert(.topMBA)
        }
        
        // Startup
        if lowercased.contains("startup") || 
           lowercased.contains("founder") ||
           lowercased.contains("entrepreneurial") {
            concepts.insert(.startup)
        }
        
        // Unicorn
        if lowercased.contains("unicorn") {
            concepts.insert(.unicorn)
        }
        
        return concepts
    }
    
    /// 概念标签匹配得分
    /// - Parameters:
    ///   - profileTags: 候选人的标签
    ///   - queryTags: 查询的标签
    /// - Returns: 匹配分数
    static func scoreConceptMatch(
        profileTags: Set<ConceptTag>,
        queryTags: Set<ConceptTag>
    ) -> Double {
        let intersection = profileTags.intersection(queryTags)
        
        if intersection.isEmpty {
            return 0.0
        }
        
        // 每个匹配的概念标签 +3分
        let score = Double(intersection.count) * 3.0
        
        print("  🏷️  Concept match: \(intersection.map { $0.displayName }.joined(separator: ", ")) (+\(String(format: "%.1f", score)))")
        
        return score
    }
}

// MARK: - Profile Extension

extension BrewNetProfile {
    /// 获取概念标签（懒加载）
    var conceptTags: Set<ConceptTag> {
        ConceptTagger.generateTags(for: self)
    }
}

