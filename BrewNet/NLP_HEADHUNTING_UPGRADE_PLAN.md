# NLP Headhunting 系统升级方案

> **版本**: 2.0  
> **创建日期**: 2024-11-21  
> **负责人**: BrewNet Team Heady  
> **状态**: 🚧 实施中

---

## 升级背景

### 当前问题

#### 1. 召回池（Recall）严重受限
- 仅在推荐系统给出的 **60个候选人** 中筛选
- 如果这60人里没有"Stanford Alumni"，NLP算法再强也搜不到
- **准确率上限被锁死**

#### 2. 语义鸿沟（Semantic Gap）
- 完全依赖关键词硬匹配（Exact Match）
- 无法理解语义概念（如 "Top Tech Firm"）
- 无法识别缩写（如 "PM" = "Product Manager"）
- 无法处理同义词（"Mentor" vs "Coach"）

### 升级目标

| 指标 | 当前值 | 目标值 | 提升 |
|-----|--------|--------|------|
| 召回池大小 | 60人 | 200-500人 | 3-8倍 |
| 召回准确率 | ~60% | >85% | +25% |
| 语义理解 | 0% | >70% | 质的飞跃 |
| 响应时间 | 1000ms | <800ms | -20% |

---

## 升级方案概览

### 四大维度

```
┌─────────────────────────────────────────────────────────────┐
│                    NLP Headhunting 2.0                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1️⃣ 架构层：两阶段检索                                        │
│     召回池: 60人 → 200-500人                                 │
│     方法: 倒排索引 + 向量检索                                  │
│                                                              │
│  2️⃣ NLP层：意图理解                                           │
│     关键词匹配 → 结构化解析                                    │
│     方法: NER + 同义词 + Query Expansion                      │
│                                                              │
│  3️⃣ 特征工程：细粒度特征                                       │
│     一锅乱炖 → 分区加权                                        │
│     方法: Field-Aware + Concept Tagging                      │
│                                                              │
│  4️⃣ 评分算法：动态加权                                         │
│     线性加分 → BM25 + 软匹配                                  │
│     方法: TF-IDF + Gaussian Decay                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: 架构层升级

### 1.1 两阶段检索架构

#### 当前架构
```
User Query
    ↓
RecommendationService (60人)
    ↓
本地NLP过滤
    ↓
Top 5
```

#### 新架构
```
User Query
    ↓
[粗排] 数据库召回 (200-500人)
    ├─ 全文索引 (PostgreSQL tsvector)
    ├─ 倒排索引 (Trigram)
    └─ 向量检索 (pgvector) [可选]
    ↓
[精排] 本地NLP打分
    ├─ 结构化解析
    ├─ 语义匹配
    └─ 动态加权
    ↓
Top 5
```

### 1.2 数据库层改造

#### SQL Schema 扩展

```sql
-- 1. 添加全文搜索字段
ALTER TABLE user_features 
ADD COLUMN searchable_text_tsv tsvector;

-- 2. 创建全文索引
CREATE INDEX idx_searchable_text_gin 
ON user_features 
USING gin(searchable_text_tsv);

-- 3. 创建 Trigram 索引（模糊搜索）
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_searchable_text_trgm 
ON user_features 
USING gin(searchable_text gin_trgm_ops);

-- 4. 更新触发器（自动维护搜索文本）
CREATE OR REPLACE FUNCTION update_searchable_text()
RETURNS TRIGGER AS $$
BEGIN
    NEW.searchable_text_tsv := 
        setweight(to_tsvector('english', COALESCE(NEW.location, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.industry, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.career_stage, '')), 'B') ||
        setweight(to_tsvector('english', 
            COALESCE(array_to_string(NEW.skills, ' '), '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_searchable_text
BEFORE INSERT OR UPDATE ON user_features
FOR EACH ROW EXECUTE FUNCTION update_searchable_text();
```

#### 向量检索扩展（进阶）

```sql
-- 1. 安装 pgvector 扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. 添加向量列
ALTER TABLE user_features 
ADD COLUMN profile_embedding vector(768);  -- 768维向量

-- 3. 创建向量索引
CREATE INDEX idx_profile_embedding_ivfflat 
ON user_features 
USING ivfflat (profile_embedding vector_cosine_ops)
WITH (lists = 100);
```

### 1.3 Swift 召回层实现

**新文件**: `BrewNet/HeadhuntingRecallService.swift`

```swift
import Foundation

class HeadhuntingRecallService {
    private let supabaseService = SupabaseService.shared
    
    /// 两阶段召回
    func recall(
        query: String,
        currentUserId: String,
        limit: Int = 200
    ) async throws -> [BrewNetProfile] {
        // 1. 解析查询意图
        let parsedQuery = parseQuery(query)
        
        // 2. 构建数据库查询
        var candidates: [BrewNetProfile] = []
        
        // 策略A: 全文搜索召回
        let textRecall = try await fullTextSearch(
            query: parsedQuery.rawText,
            limit: limit
        )
        candidates.append(contentsOf: textRecall)
        
        // 策略B: 结构化召回（如果有明确字段）
        if let school = parsedQuery.school {
            let schoolRecall = try await searchBySchool(
                school: school,
                limit: 100
            )
            candidates.append(contentsOf: schoolRecall)
        }
        
        if let company = parsedQuery.company {
            let companyRecall = try await searchByCompany(
                company: company,
                limit: 100
            )
            candidates.append(contentsOf: companyRecall)
        }
        
        // 3. 去重（同一用户可能通过多个策略召回）
        let uniqueCandidates = Array(Set(candidates.map { $0.userId }))
            .compactMap { userId in
                candidates.first { $0.userId == userId }
            }
        
        // 4. 排除已连接/已拒绝的用户
        let filtered = try await filterExcluded(
            candidates: uniqueCandidates,
            currentUserId: currentUserId
        )
        
        print("📊 Recall stats:")
        print("  - Text search: \(textRecall.count)")
        print("  - School filter: \(parsedQuery.school != nil ? "Yes" : "No")")
        print("  - Company filter: \(parsedQuery.company != nil ? "Yes" : "No")")
        print("  - Total unique: \(uniqueCandidates.count)")
        print("  - After filtering: \(filtered.count)")
        
        return Array(filtered.prefix(limit))
    }
    
    /// 全文搜索
    private func fullTextSearch(
        query: String,
        limit: Int
    ) async throws -> [BrewNetProfile] {
        // 使用 PostgreSQL 全文搜索
        let response = try await supabaseService.client
            .from("user_features")
            .select("""
                user_id,
                location,
                industry,
                skills,
                career_stage
            """)
            .textSearch("searchable_text_tsv", query: query, config: "english")
            .limit(limit)
            .execute()
        
        // 解析并获取完整 profile
        // ... 实现细节
        return []
    }
    
    /// 按学校搜索
    private func searchBySchool(
        school: String,
        limit: Int
    ) async throws -> [BrewNetProfile] {
        // SQL: WHERE professional_background->'educations' @> '[{"school_name": "Stanford"}]'
        return []
    }
    
    /// 按公司搜索
    private func searchByCompany(
        company: String,
        limit: Int
    ) async throws -> [BrewNetProfile] {
        // SQL: WHERE professional_background->>'current_company' ILIKE '%Google%'
        return []
    }
}
```

---

## Phase 2: NLP 层升级

### 2.1 查询解析器

**新文件**: `BrewNet/QueryParser.swift`

```swift
import Foundation
import NaturalLanguage

/// 结构化查询意图
struct ParsedQuery {
    let rawText: String
    let tokens: [String]
    let entities: QueryEntities
    let modifiers: QueryModifiers
}

/// 实体识别结果
struct QueryEntities {
    var companies: [String] = []
    var roles: [String] = []
    var schools: [String] = []
    var skills: [String] = []
    var industries: [String] = []
    var numbers: [Double] = []
}

/// 查询修饰符
struct QueryModifiers {
    var negations: [String] = []  // "not", "except"
    var emphasis: [String] = []   // "must", "only"
    var fuzzy: [String] = []      // "around", "about"
}

class QueryParser {
    
    // MARK: - 领域词典
    
    private let companyDictionary: Set<String> = [
        "google", "facebook", "meta", "amazon", "apple", "microsoft",
        "netflix", "uber", "airbnb", "stripe", "openai",
        "mckinsey", "bain", "bcg",  // MBB
        "goldman", "morgan stanley", "jpmorgan"  // Finance
    ]
    
    private let roleDictionary: Set<String> = [
        "product manager", "pm", "engineer", "swe", "software engineer",
        "designer", "data scientist", "ml engineer", "founder", "ceo"
    ]
    
    private let schoolDictionary: Set<String> = [
        "stanford", "harvard", "mit", "yale", "princeton",
        "berkeley", "caltech", "cornell", "columbia", "penn"
    ]
    
    private let skillDictionary: Set<String> = [
        "python", "java", "javascript", "react", "ml", "ai",
        "leadership", "marketing", "sales", "design"
    ]
    
    // MARK: - 同义词映射
    
    private let synonymMap: [String: [String]] = [
        "pm": ["product manager", "program manager"],
        "swe": ["software engineer", "developer", "engineer"],
        "ml": ["machine learning", "ai", "artificial intelligence"],
        "fb": ["facebook", "meta"],
        "linkedin": ["linkedin", "in"],
        "founder": ["entrepreneur", "startup owner", "ceo"],
        "mentor": ["coach", "advisor", "guide"],
        "alumni": ["alum", "graduate"]
    ]
    
    // MARK: - 概念标签映射
    
    private let conceptTagMap: [String: [String]] = [
        "top tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft"],
        "faang": ["facebook", "meta", "amazon", "apple", "netflix", "google"],
        "mbb": ["mckinsey", "bain", "bcg"],
        "ivy league": ["harvard", "yale", "princeton", "columbia", "penn", "brown", "dartmouth", "cornell"],
        "big tech": ["google", "facebook", "meta", "amazon", "apple", "microsoft", "netflix", "uber"]
    ]
    
    // MARK: - 解析主函数
    
    func parse(_ query: String) -> ParsedQuery {
        let normalized = query.lowercased()
        
        // 1. 基础分词
        let tokens = tokenize(normalized)
        
        // 2. 实体识别
        let entities = extractEntities(from: normalized, tokens: tokens)
        
        // 3. 识别修饰符
        let modifiers = extractModifiers(from: tokens)
        
        // 4. 同义词扩展
        let expandedTokens = expandSynonyms(tokens: tokens)
        
        // 5. 概念标签扩展
        let conceptExpanded = expandConcepts(tokens: expandedTokens)
        
        return ParsedQuery(
            rawText: normalized,
            tokens: conceptExpanded,
            entities: entities,
            modifiers: modifiers
        )
    }
    
    // MARK: - 实体识别
    
    private func extractEntities(
        from text: String,
        tokens: [String]
    ) -> QueryEntities {
        var entities = QueryEntities()
        
        // 使用 NLTagger 进行命名实体识别
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag {
                let entity = String(text[tokenRange])
                
                switch tag {
                case .organizationName:
                    entities.companies.append(entity)
                default:
                    break
                }
            }
            return true
        }
        
        // 使用词典匹配（更准确）
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
        
        // 提取数字
        entities.numbers = extractNumbers(from: text)
        
        return entities
    }
    
    private func matchPhrases(in text: String, dictionary: Set<String>) -> [String] {
        var matches: [String] = []
        for phrase in dictionary {
            if phrase.contains(" ") && text.contains(phrase) {
                matches.append(phrase)
            }
        }
        return matches
    }
    
    // MARK: - 修饰符识别
    
    private func extractModifiers(from tokens: [String]) -> QueryModifiers {
        var modifiers = QueryModifiers()
        
        for (index, token) in tokens.enumerated() {
            if ["not", "no", "except", "without"].contains(token) {
                // 获取否定词后面的词
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
        
        for token in tokens {
            if let synonyms = synonymMap[token] {
                expanded.append(contentsOf: synonyms)
            }
        }
        
        return expanded
    }
    
    // MARK: - 概念标签扩展
    
    private func expandConcepts(tokens: [String]) -> [String] {
        var expanded = tokens
        
        // 检测概念短语
        let joinedText = tokens.joined(separator: " ")
        
        for (concept, expansions) in conceptTagMap {
            if joinedText.contains(concept) {
                expanded.append(contentsOf: expansions)
                print("🏷️ Expanded concept: \(concept) → \(expansions.joined(separator: ", "))")
            }
        }
        
        return expanded
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
```

### 2.2 缩写处理增强

```swift
extension QueryParser {
    /// 扩展的缩写映射
    private static let abbreviationMap: [String: [String]] = [
        // 职位缩写
        "pm": ["product manager", "program manager", "project manager"],
        "swe": ["software engineer", "software developer"],
        "ds": ["data scientist", "data science"],
        "ml": ["machine learning", "ml engineer"],
        "ui": ["user interface"],
        "ux": ["user experience"],
        "qa": ["quality assurance"],
        "hr": ["human resources"],
        "ceo": ["chief executive officer", "founder"],
        "cto": ["chief technology officer"],
        "cfo": ["chief financial officer"],
        
        // 公司缩写
        "fb": ["facebook", "meta"],
        "msft": ["microsoft"],
        "amzn": ["amazon"],
        "googl": ["google", "alphabet"],
        
        // 学位缩写
        "bs": ["bachelor", "bachelor's"],
        "ms": ["master", "master's"],
        "mba": ["master of business administration"],
        "phd": ["doctor of philosophy", "doctorate"],
        
        // 技能缩写
        "ai": ["artificial intelligence"],
        "nlp": ["natural language processing"],
        "cv": ["computer vision"],
        "ml": ["machine learning"],
        "dl": ["deep learning"]
    ]
}
```

---

## Phase 3: 特征工程升级

### 3.1 分区加权搜索

**新文件**: `BrewNet/FieldAwareScoring.swift`

```swift
import Foundation

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
}

/// 分区索引文本
struct ZonedSearchableText {
    let zoneA: String  // 高权文本
    let zoneB: String  // 中权文本
    let zoneC: String  // 低权文本
    
    /// 构建分区文本
    static func from(profile: BrewNetProfile) -> ZonedSearchableText {
        // Zone A: 当前职位、公司、核心技能
        var zoneA = [
            profile.professionalBackground.jobTitle ?? "",
            profile.professionalBackground.currentCompany ?? "",
            profile.professionalBackground.industry ?? ""
        ]
        zoneA.append(contentsOf: Array(profile.professionalBackground.skills.prefix(3)))
        
        // Zone B: 简介、过往经历、教育
        var zoneB = [
            profile.coreIdentity.bio ?? "",
            profile.coreIdentity.location ?? ""
        ]
        if let educations = profile.professionalBackground.educations {
            zoneB.append(contentsOf: educations.map { $0.schoolName })
        }
        for exp in profile.professionalBackground.workExperiences.prefix(3) {
            zoneB.append(exp.companyName)
            zoneB.append(exp.position ?? "")
        }
        
        // Zone C: 爱好、兴趣
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
    
    /// 计算字段感知分数
    func computeScore(
        profile: BrewNetProfile,
        tokens: [String],
        zonedText: ZonedSearchableText
    ) -> Double {
        var score: Double = 0.0
        
        for token in tokens {
            if token.count < 2 { continue }
            
            // 在不同区域搜索，应用不同权重
            if zonedText.zoneA.contains(token) {
                score += FieldZone.zoneA.weight
                print("  ✓ '\(token)' in Zone A (×3.0)")
            } else if zonedText.zoneB.contains(token) {
                score += FieldZone.zoneB.weight
                print("  ✓ '\(token)' in Zone B (×1.5)")
            } else if zonedText.zoneC.contains(token) {
                score += FieldZone.zoneC.weight
                print("  ✓ '\(token)' in Zone C (×0.5)")
            }
        }
        
        return score
    }
}
```

### 3.2 概念标签系统

**新文件**: `BrewNet/ConceptTagger.swift`

```swift
import Foundation

/// 概念标签
enum ConceptTag: String, CaseIterable {
    case bigTech = "tag_big_tech"
    case startup = "tag_startup"
    case ivyLeague = "tag_ivy_league"
    case topMBA = "tag_top_mba"
    case faang = "tag_faang"
    case mbb = "tag_mbb"
    case finance = "tag_finance"
    case unicorn = "tag_unicorn"
}

class ConceptTagger {
    
    // MARK: - 公司分类
    
    private static let bigTechCompanies: Set<String> = [
        "google", "alphabet", "facebook", "meta", "amazon", "apple",
        "microsoft", "netflix", "tesla", "nvidia"
    ]
    
    private static let faangCompanies: Set<String> = [
        "facebook", "meta", "apple", "amazon", "netflix", "google", "alphabet"
    ]
    
    private static let mbbCompanies: Set<String> = [
        "mckinsey", "bain", "bcg", "boston consulting"
    ]
    
    private static let unicornCompanies: Set<String> = [
        "stripe", "spacex", "databricks", "canva", "figma", "notion"
    ]
    
    // MARK: - 学校分类
    
    private static let ivyLeagueSchools: Set<String> = [
        "harvard", "yale", "princeton", "columbia", "penn",
        "brown", "dartmouth", "cornell"
    ]
    
    private static let topMBASchools: Set<String> = [
        "harvard", "stanford", "wharton", "penn", "mit", "kellogg",
        "booth", "chicago", "columbia", "berkeley", "haas"
    ]
    
    // MARK: - 标签生成
    
    /// 为用户 Profile 生成概念标签
    static func generateTags(for profile: BrewNetProfile) -> Set<ConceptTag> {
        var tags: Set<ConceptTag> = []
        
        // 公司标签
        if let company = profile.professionalBackground.currentCompany?.lowercased() {
            if bigTechCompanies.contains(where: { company.contains($0) }) {
                tags.insert(.bigTech)
            }
            if faangCompanies.contains(where: { company.contains($0) }) {
                tags.insert(.faang)
            }
            if mbbCompanies.contains(where: { company.contains($0) }) {
                tags.insert(.mbb)
                tags.insert(.finance)
            }
            if unicornCompanies.contains(where: { company.contains($0) }) {
                tags.insert(.unicorn)
            }
            if company.contains("startup") || profile.professionalBackground.careerStage == .founder {
                tags.insert(.startup)
            }
        }
        
        // 学校标签
        if let educations = profile.professionalBackground.educations {
            for education in educations {
                let school = education.schoolName.lowercased()
                if ivyLeagueSchools.contains(where: { school.contains($0) }) {
                    tags.insert(.ivyLeague)
                }
                if topMBASchools.contains(where: { school.contains($0) }) && 
                   education.degree == .mba {
                    tags.insert(.topMBA)
                }
            }
        }
        
        return tags
    }
    
    /// 查询中的概念标签映射
    static func mapQueryToConcepts(query: String) -> [ConceptTag] {
        var concepts: [ConceptTag] = []
        let lowercased = query.lowercased()
        
        if lowercased.contains("top tech") || lowercased.contains("big tech") {
            concepts.append(.bigTech)
        }
        if lowercased.contains("faang") {
            concepts.append(.faang)
        }
        if lowercased.contains("mbb") {
            concepts.append(.mbb)
        }
        if lowercased.contains("ivy league") || lowercased.contains("ivy") {
            concepts.append(.ivyLeague)
        }
        if lowercased.contains("top mba") || lowercased.contains("m7") {
            concepts.append(.topMBA)
        }
        if lowercased.contains("startup") || lowercased.contains("founder") {
            concepts.append(.startup)
        }
        if lowercased.contains("unicorn") {
            concepts.append(.unicorn)
        }
        
        return concepts
    }
}

// MARK: - Profile 扩展

extension BrewNetProfile {
    /// 获取概念标签
    var conceptTags: Set<ConceptTag> {
        ConceptTagger.generateTags(for: self)
    }
}
```

---

## Phase 4: 评分算法升级

### 4.1 BM25 算法

**新文件**: `BrewNet/BM25Scorer.swift`

```swift
import Foundation

/// BM25 算法实现
class BM25Scorer {
    
    // BM25 参数
    private let k1: Double = 1.5  // 词频饱和参数
    private let b: Double = 0.75   // 长度归一化参数
    
    /// 文档集合的词频统计
    private var documentFrequency: [String: Int] = [:]
    private var totalDocuments: Int = 0
    private var averageDocumentLength: Double = 0.0
    
    /// 初始化（需要遍历所有文档统计）
    func initialize(profiles: [BrewNetProfile]) {
        totalDocuments = profiles.count
        var totalLength: Double = 0.0
        var df: [String: Set<String>] = [:]  // term -> set of doc ids
        
        for profile in profiles {
            let text = aggregatedSearchableText(for: profile)
            let tokens = tokenize(text)
            totalLength += Double(tokens.count)
            
            // 统计文档频率
            let uniqueTokens = Set(tokens)
            for token in uniqueTokens {
                if df[token] == nil {
                    df[token] = Set()
                }
                df[token]?.insert(profile.userId)
            }
        }
        
        averageDocumentLength = totalLength / Double(totalDocuments)
        documentFrequency = df.mapValues { $0.count }
        
        print("📊 BM25 initialized:")
        print("  - Total documents: \(totalDocuments)")
        print("  - Avg doc length: \(averageDocumentLength)")
        print("  - Vocabulary size: \(documentFrequency.count)")
    }
    
    /// 计算 BM25 分数
    func score(
        profile: BrewNetProfile,
        queryTokens: [String]
    ) -> Double {
        let docText = aggregatedSearchableText(for: profile)
        let docTokens = tokenize(docText)
        let docLength = Double(docTokens.count)
        
        // 计算词频 TF
        var termFrequency: [String: Int] = [:]
        for token in docTokens {
            termFrequency[token, default: 0] += 1
        }
        
        var score: Double = 0.0
        
        for queryToken in Set(queryTokens) {
            let tf = Double(termFrequency[queryToken] ?? 0)
            let df = Double(documentFrequency[queryToken] ?? 1)
            
            // IDF 计算
            let idf = log((Double(totalDocuments) - df + 0.5) / (df + 0.5) + 1.0)
            
            // BM25 公式
            let numerator = tf * (k1 + 1.0)
            let denominator = tf + k1 * (1.0 - b + b * (docLength / averageDocumentLength))
            
            score += idf * (numerator / denominator)
        }
        
        return score
    }
    
    private func aggregatedSearchableText(for profile: BrewNetProfile) -> String {
        // 复用原有逻辑
        var parts: [String] = []
        parts.append(profile.coreIdentity.name)
        parts.append(profile.coreIdentity.bio ?? "")
        parts.append(profile.professionalBackground.currentCompany ?? "")
        parts.append(profile.professionalBackground.jobTitle ?? "")
        parts.append(contentsOf: profile.professionalBackground.skills)
        return parts.joined(separator: " ").lowercased()
    }
    
    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 }
    }
}
```

### 4.2 软匹配逻辑

**新文件**: `BrewNet/SoftMatching.swift`

```swift
import Foundation

class SoftMatching {
    
    /// 高斯衰减函数（用于年限匹配）
    static func gaussianDecay(
        actual: Double,
        target: Double,
        sigma: Double = 1.0
    ) -> Double {
        let exponent = -pow(actual - target, 2) / (2 * pow(sigma, 2))
        return exp(exponent)
    }
    
    /// 软年限匹配
    static func softExperienceMatch(
        profile: BrewNetProfile,
        targetYears: [Double]
    ) -> Double {
        guard let actual = profile.professionalBackground.yearsOfExperience else {
            return 0.0
        }
        
        var maxScore: Double = 0.0
        
        for target in targetYears {
            let score = gaussianDecay(actual: actual, target: target, sigma: 1.5)
            maxScore = max(maxScore, score)
        }
        
        // 归一化到 [0, 2.0] 区间（匹配原有 +2.0 的逻辑）
        return maxScore * 2.0
    }
    
    /// 模糊字符串匹配（Levenshtein 距离）
    static func fuzzyStringMatch(
        string1: String,
        string2: String,
        threshold: Int = 2
    ) -> Bool {
        let distance = levenshteinDistance(string1, string2)
        return distance <= threshold
    }
    
    /// Levenshtein 距离计算
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        for j in 0...n {
            dp[0][j] = j
        }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i-1] == s2Array[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[m][n]
    }
}
```

### 4.3 动态权重调整

```swift
/// 上下文感知权重
class ContextAwareWeighting {
    
    /// 根据查询复杂度动态调整权重
    static func adjustWeights(
        for query: String,
        baseRecommendationWeight: Double = 0.3,
        baseTextWeight: Double = 0.7
    ) -> (recommendation: Double, text: Double) {
        
        let tokens = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        
        let queryLength = tokens.count
        let hasNumbers = tokens.contains(where: { Double($0) != nil })
        let hasSpecificTerms = tokens.contains(where: { 
            ["alumni", "founder", "mentor", "years"].contains($0) 
        })
        
        var recWeight = baseRecommendationWeight
        var textWeight = baseTextWeight
        
        // 查询很短（≤2词）：更依赖推荐系统
        if queryLength <= 2 {
            recWeight = 0.5
            textWeight = 0.5
        }
        
        // 查询很长且具体（≥6词 + 数字）：更依赖文本匹配
        if queryLength >= 6 && hasNumbers {
            recWeight = 0.2
            textWeight = 0.8
        }
        
        // 包含特定术语：提高文本权重
        if hasSpecificTerms {
            textWeight += 0.1
            recWeight -= 0.1
        }
        
        // 归一化
        let total = recWeight + textWeight
        recWeight /= total
        textWeight /= total
        
        print("⚖️ Dynamic weights: Rec=\(String(format: "%.1f%%", recWeight*100)), Text=\(String(format: "%.1f%%", textWeight*100))")
        
        return (recWeight, textWeight)
    }
}
```

---

## 实施计划

### 时间线

| 阶段 | 任务 | 预计时间 | 优先级 |
|-----|------|---------|--------|
| **Phase 1** | 数据库索引升级 | 1周 | 🔴 Critical |
| **Phase 1** | 召回服务实现 | 1周 | 🔴 Critical |
| **Phase 2** | 查询解析器 | 1周 | 🔴 Critical |
| **Phase 2** | 同义词/缩写 | 3天 | 🟡 High |
| **Phase 3** | 分区加权 | 3天 | 🟡 High |
| **Phase 3** | 概念标签 | 1周 | 🟡 High |
| **Phase 4** | BM25实现 | 1周 | 🟢 Medium |
| **Phase 4** | 软匹配 | 3天 | 🟢 Medium |
| **Phase 4** | 动态权重 | 2天 | 🟢 Medium |
| **Testing** | 集成测试 | 1周 | 🔴 Critical |
| **Optimization** | 性能优化 | 1周 | 🟡 High |

**总计**: 约 8-10 周

### 里程碑

- ✅ **Week 2**: 数据库召回能力提升到 200+ 人
- ✅ **Week 4**: 基础 NLP 解析上线（同义词、缩写）
- ✅ **Week 6**: 概念标签系统上线（"Top Tech", "Ivy League"）
- ✅ **Week 8**: BM25 + 软匹配上线
- ✅ **Week 10**: 全面测试 + 性能调优

---

## 预期收益

### 召回率提升

```
场景: "Stanford alumni, PM at Google"

V1.0 (当前):
  候选池: 60人
  召回: 2人（如果推荐系统恰好包含）
  准确率: ~40%

V2.0 (升级后):
  候选池: 500人
  召回: 15人（全库搜索）
  准确率: ~85%

提升: 7.5倍召回 + 45% 准确率
```

### 语义理解提升

```
查询: "Top tech PM with 5 years"

V1.0:
  理解: ["top", "tech", "pm", "5", "years"]
  匹配: 只匹配到 "PM" 字样的人

V2.0:
  理解: {
    concept: "top tech" → [Google, Meta, Amazon, ...]
    role: "PM" → "Product Manager"
    experience: 5 ± 1.5 years (高斯衰减)
  }
  匹配: 所有 FAANG PM，4-6.5年经验
```

### 响应时间优化

```
V1.0:
  推荐系统: 500ms
  本地匹配: 300ms
  总计: 800ms

V2.0:
  数据库召回: 300ms (索引加速)
  NLP解析: 50ms
  精排: 200ms
  总计: 550ms

提升: -31% 响应时间
```

---

## 风险与对策

### 风险 1: 数据库性能

**风险**: 全库搜索可能导致性能下降  
**对策**:
- 使用 PostgreSQL 全文索引（GIN）
- 添加查询缓存
- 限制召回上限（500人）

### 风险 2: 复杂度提升

**风险**: 代码复杂度大幅提升  
**对策**:
- 模块化设计（独立文件）
- 充分的单元测试
- 详细的文档

### 风险 3: 准确率波动

**风险**: 新算法可能在某些场景表现不如预期  
**对策**:
- A/B 测试
- 逐步灰度发布
- 收集用户反馈

---

## 监控指标

### 关键指标

| 指标 | 当前 | 目标 | 监控方式 |
|-----|------|------|---------|
| 召回池大小 | 60 | 200-500 | 日志 |
| Top 5 点击率 | ? | >60% | Analytics |
| 邀请转化率 | ? | >20% | Database |
| 响应时间 P50 | 800ms | <600ms | APM |
| 响应时间 P95 | 1500ms | <1000ms | APM |
| 查询失败率 | <1% | <0.5% | Error Log |

---

## 后续优化方向

### V3.0 展望

1. **深度学习模型**
   - BERT-based 语义匹配
   - 端到端学习排序

2. **个性化**
   - 用户历史行为建模
   - 协同过滤

3. **多模态**
   - 图片理解（工作照、生活照）
   - 视频简介分析

4. **实时更新**
   - 用户上线立即可搜
   - 增量索引更新

---

## 总结

这次升级将从根本上解决 Headhunting 的两大瓶颈：

1. **召回池扩大 8倍**：从 60人 → 500人
2. **语义理解质的飞跃**：从关键词 → 意图理解

预计整体准确率提升 **45%**，响应时间降低 **31%**。

---

**文档版本**: 2.0 Plan  
**创建日期**: 2024-11-21  
**状态**: 🚧 待实施  
**负责人**: BrewNet Team Heady

