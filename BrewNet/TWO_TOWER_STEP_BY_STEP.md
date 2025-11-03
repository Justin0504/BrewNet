# Two-Tower 推荐系统实施计划（Step-by-Step）

## 📅 总体时间规划

- **总时长**: 6-8 周
- **Phase 1**: Week 1-2 (基础设施)
- **Phase 2**: Week 3-4 (简单 Two-Tower)
- **Phase 3**: Week 5-6 (深度学习升级)
- **Phase 4**: Week 7-8 (优化和部署)

---

## 🎯 Phase 1: 数据基础设施（Week 1-2）

### Day 1-2: 数据库 Schema 设置

#### Step 1.1: 创建 SQL 文件

**文件**: `BrewNet/BrewNet/create_two_tower_tables.sql`

```sql
-- 1. 用户特征表
CREATE TABLE IF NOT EXISTS user_features (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- 稀疏特征
    location VARCHAR(100),
    time_zone VARCHAR(50),
    industry VARCHAR(100),
    experience_level VARCHAR(50),
    career_stage VARCHAR(50),
    main_intention VARCHAR(50),
    
    -- 多值特征
    skills JSONB DEFAULT '[]'::jsonb,
    hobbies JSONB DEFAULT '[]'::jsonb,
    values JSONB DEFAULT '[]'::jsonb,
    languages JSONB DEFAULT '[]'::jsonb,
    sub_intentions JSONB DEFAULT '[]'::jsonb,
    
    -- 学习/教授配对
    skills_to_learn JSONB DEFAULT '[]'::jsonb,
    skills_to_teach JSONB DEFAULT '[]'::jsonb,
    functions_to_learn JSONB DEFAULT '[]'::jsonb,
    functions_to_teach JSONB DEFAULT '[]'::jsonb,
    
    -- 数值特征
    years_of_experience FLOAT DEFAULT 0,
    profile_completion FLOAT DEFAULT 0,
    is_verified INT DEFAULT 0,
    
    -- Embedding 向量
    user_embedding FLOAT[],
    
    -- 元数据
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_user_features_industry ON user_features(industry);
CREATE INDEX idx_user_features_intention ON user_features(main_intention);
CREATE INDEX idx_user_features_embedding ON user_features USING ivfflat (user_embedding vector_cosine_ops);

-- 2. 用户交互表
CREATE TABLE IF NOT EXISTS user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('like', 'pass', 'match')),
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, target_user_id, interaction_type)
);

CREATE INDEX idx_interactions_user_type ON user_interactions(user_id, interaction_type);
CREATE INDEX idx_interactions_target ON user_interactions(target_user_id);

-- 3. 推荐缓存表
CREATE TABLE IF NOT EXISTS recommendation_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    recommended_user_ids JSONB,
    scores JSONB,
    model_version VARCHAR(50) DEFAULT 'baseline',
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP
);

CREATE INDEX idx_cache_expires ON recommendation_cache(expires_at);
CREATE INDEX idx_cache_model ON recommendation_cache(model_version);

COMMENT ON TABLE user_features IS '用户特征表，用于 Two-Tower 推荐模型';
COMMENT ON TABLE user_interactions IS '用户交互日志表，记录 like/pass/match 行为';
COMMENT ON TABLE recommendation_cache IS '推荐结果缓存表，提高响应速度';
```

**执行命令**:
```bash
cd /Users/justin/BrewNet-Fresh
psql -h <your-supabase-host> -U postgres -d postgres -f BrewNet/BrewNet/create_two_tower_tables.sql
```

#### Step 1.2: 创建数据同步函数

**文件**: `BrewNet/BrewNet/sync_user_features_function.sql`

```sql
-- 提取技能学习/教授列表的函数
CREATE OR REPLACE FUNCTION extract_skills_from_development(dev_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    skill_record JSONB;
BEGIN
    IF dev_data IS NULL OR dev_data->'skills' IS NULL THEN
        RETURN result;
    END IF;
    
    FOR skill_record IN SELECT * FROM jsonb_array_elements(dev_data->'skills')
    LOOP
        IF (skill_record->>mode)::boolean = true THEN
            result := result || jsonb_build_array(skill_record->>'skill_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 提取职能学习/教授列表的函数
CREATE OR REPLACE FUNCTION extract_functions_from_direction(direction_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    func_record JSONB;
BEGIN
    IF direction_data IS NULL OR direction_data->'functions' IS NULL THEN
        RETURN result;
    END IF;
    
    FOR func_record IN SELECT * FROM jsonb_array_elements(direction_data->'functions')
    LOOP
        IF (func_record->>mode)::boolean = true THEN
            result := result || jsonb_build_array(func_record->>'function_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 计算资料完整度的函数
CREATE OR REPLACE FUNCTION calculate_profile_completion(profile_data JSONB)
RETURNS FLOAT AS $$
DECLARE
    completed_fields INT := 0;
    total_fields INT := 0;
BEGIN
    -- 检查每个关键字段
    total_fields := 20;  -- 假设总共 20 个重要字段
    
    -- Core Identity
    IF (profile_data->'core_identity'->>'name') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'bio') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'location') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    
    -- Professional Background
    IF (profile_data->'professional_background'->>'job_title') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'industry') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'skills', '[]'::jsonb)) > 0 
        THEN completed_fields := completed_fields + 1; 
    END IF;
    
    -- Personality & Social
    IF (profile_data->'personality_social'->>'self_introduction') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'personality_social'->'hobbies', '[]'::jsonb)) > 0 
        THEN completed_fields := completed_fields + 1; 
    END IF;
    
    -- ... 检查更多字段
    
    RETURN completed_fields::FLOAT / total_fields::FLOAT;
END;
$$ LANGUAGE plpgsql;

-- 同步用户特征的触发器函数
CREATE OR REPLACE FUNCTION sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_features (
        user_id,
        location,
        time_zone,
        industry,
        experience_level,
        career_stage,
        main_intention,
        skills,
        hobbies,
        values,
        languages,
        sub_intentions,
        skills_to_learn,
        skills_to_teach,
        functions_to_learn,
        functions_to_teach,
        years_of_experience,
        profile_completion,
        is_verified
    ) VALUES (
        NEW.id,
        NEW.core_identity->>'location',
        NEW.core_identity->>'time_zone',
        NEW.professional_background->>'industry',
        NEW.professional_background->>'experience_level',
        NEW.professional_background->>'career_stage',
        NEW.networking_intention->>'selected_intention',
        NEW.professional_background->'skills',
        NEW.personality_social->'hobbies',
        NEW.personality_social->'values_tags',
        NEW.professional_background->'languages_spoken',
        NEW.networking_intention->'selected_sub_intentions',
        extract_skills_from_development(NEW.networking_intention->'skill_development', 'learn_in'),
        extract_skills_from_development(NEW.networking_intention->'skill_development', 'guide_in'),
        extract_functions_from_direction(NEW.networking_intention->'career_direction', 'learn_in'),
        extract_functions_from_direction(NEW.networking_intention->'career_direction', 'guide_in'),
        COALESCE((NEW.professional_background->>'years_of_experience')::FLOAT, 0),
        calculate_profile_completion(NEW::jsonb),
        CASE 
            WHEN NEW.privacy_trust->'verified_status' = '"verified_professional"' THEN 1 
            WHEN NEW.privacy_trust->'verified_status' = '"verified"' THEN 1 
            ELSE 0 
        END
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        location = EXCLUDED.location,
        time_zone = EXCLUDED.time_zone,
        industry = EXCLUDED.industry,
        experience_level = EXCLUDED.experience_level,
        career_stage = EXCLUDED.career_stage,
        main_intention = EXCLUDED.main_intention,
        skills = EXCLUDED.skills,
        hobbies = EXCLUDED.hobbies,
        values = EXCLUDED.values,
        languages = EXCLUDED.languages,
        sub_intentions = EXCLUDED.sub_intentions,
        skills_to_learn = EXCLUDED.skills_to_learn,
        skills_to_teach = EXCLUDED.skills_to_teach,
        functions_to_learn = EXCLUDED.functions_to_learn,
        functions_to_teach = EXCLUDED.functions_to_teach,
        years_of_experience = EXCLUDED.years_of_experience,
        profile_completion = EXCLUDED.profile_completion,
        is_verified = EXCLUDED.is_verified,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
DROP TRIGGER IF EXISTS trigger_sync_user_features ON profiles;
CREATE TRIGGER trigger_sync_user_features
    AFTER INSERT OR UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_features();
```

**执行命令**:
```bash
psql -h <your-supabase-host> -U postgres -d postgres -f BrewNet/BrewNet/sync_user_features_function.sql
```

**验证**:
```sql
-- 检查触发器是否创建成功
SELECT * FROM pg_trigger WHERE tgname = 'trigger_sync_user_features';

-- 测试触发器：更新一个用户资料
UPDATE profiles SET updated_at = NOW() WHERE id = '<some-user-id>';

-- 检查 user_features 是否同步
SELECT * FROM user_features WHERE user_id = '<some-user-id>';
```

---

### Day 3-5: Swift 数据模型

#### Step 1.3: 创建 UserTowerFeatures 模型

**文件**: `BrewNet/BrewNet/UserTowerFeatures.swift`

```swift
import Foundation

/// 用户塔特征模型
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

// MARK: - 特征词汇表
struct FeatureVocabularies {
    static let allSkills = [
        "Swift", "Python", "JavaScript", "TypeScript", "React",
        "iOS Development", "Android Development", "Web Development",
        "AI", "Machine Learning", "Deep Learning", "Data Science",
        "Product Management", "Project Management", "UX Design", "UI Design",
        "DevOps", "Cloud Computing", "Backend Development", "Frontend Development"
    ]
    
    static let allHobbies = [
        "Coffee Culture", "Photography", "Hiking", "Traveling",
        "Reading", "Gaming", "Music", "Cooking", "Writing",
        "Fitness", "Yoga", "Meditation", "Art"
    ]
    
    static let allValues = [
        "Innovation", "Collaboration", "Curiosity", "Passion",
        "Integrity", "Diversity", "Sustainability", "Growth"
    ]
    
    static let allIndustries = [
        "Technology", "Finance", "Healthcare", "Education",
        "E-commerce", "Gaming", "Media", "Consulting",
        "Startup", "Enterprise", "Government", "Non-profit"
    ]
    
    static let allIntentions = [
        "learnGrow", "connectShare", "buildCollaborate", "unwindChat"
    ]
    
    static let allExperienceLevels = [
        "entry", "mid", "senior", "executive"
    ]
}
```

---

### Day 6-7: SupabaseService 扩展

#### Step 1.4: 添加特征获取方法

**文件**: `BrewNet/BrewNet/SupabaseService.swift` (在文件末尾添加)

```swift
// MARK: - Two-Tower Recommendation Methods

extension SupabaseService {
    
    /// 获取用户特征
    func getUserFeatures(userId: String) async throws -> UserTowerFeatures? {
        print("🔍 Fetching user features for: \(userId)")
        
        let response = try await client
            .from("user_features")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
        
        let data = response.data
        let features = try JSONDecoder().decode(UserTowerFeatures.self, from: data)
        print("✅ Fetched user features successfully")
        return features
    }
    
    /// 获取所有候选用户特征（用于推荐）
    func getAllCandidateFeatures(
        excluding userId: String,
        limit: Int = 1000
    ) async throws -> [UserTowerFeatures] {
        print("🔍 Fetching candidate features, excluding: \(userId)")
        
        let response = try await client
            .from("user_features")
            .select()
            .neq("user_id", value: userId)
            .limit(limit)
            .execute()
        
        let data = response.data
        let features = try JSONDecoder().decode([UserTowerFeatures].self, from: data)
        print("✅ Fetched \(features.count) candidate features")
        return features
    }
    
    /// 记录用户交互
    func recordInteraction(
        userId: String,
        targetUserId: String,
        type: InteractionType
    ) async throws {
        print("📝 Recording interaction: \(userId) -> \(targetUserId), type: \(type)")
        
        struct InteractionInsert: Codable {
            let userId: String
            let targetUserId: String
            let interactionType: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case targetUserId = "target_user_id"
                case interactionType = "interaction_type"
            }
        }
        
        let insert = InteractionInsert(
            userId: userId,
            targetUserId: targetUserId,
            interactionType: type.rawValue
        )
        
        try await client
            .from("user_interactions")
            .insert(insert)
            .execute()
        
        print("✅ Interaction recorded")
    }
    
    /// 缓存推荐结果
    func cacheRecommendations(
        userId: String,
        recommendations: [String],
        scores: [Double],
        modelVersion: String = "baseline",
        expiresIn: TimeInterval = 300 // 5 分钟
    ) async throws {
        print("💾 Caching recommendations for: \(userId)")
        
        struct CacheInsert: Codable {
            let userId: String
            let recommendedUserIds: [String]
            let scores: [Double]
            let modelVersion: String
            let expiresAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case recommendedUserIds = "recommended_user_ids"
                case scores
                case modelVersion = "model_version"
                case expiresAt = "expires_at"
            }
        }
        
        let expiresDate = Date().addingTimeInterval(expiresIn)
        let formatter = ISO8601DateFormatter()
        
        let insert = CacheInsert(
            userId: userId,
            recommendedUserIds: recommendations,
            scores: scores,
            modelVersion: modelVersion,
            expiresAt: formatter.string(from: expiresDate)
        )
        
        try await client
            .from("recommendation_cache")
            .upsert(insert)
            .execute()
        
        print("✅ Recommendations cached")
    }
    
    /// 获取缓存的推荐结果
    func getCachedRecommendations(userId: String) async throws -> ([String], [Double])? {
        print("🔍 Fetching cached recommendations for: \(userId)")
        
        let response = try await client
            .from("recommendation_cache")
            .select()
            .eq("user_id", value: userId)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .maybeSingle()
            .execute()
        
        if let data = response.data {
            struct CacheResult: Codable {
                let recommendedUserIds: [String]
                let scores: [Double]
                
                enum CodingKeys: String, CodingKey {
                    case recommendedUserIds = "recommended_user_ids"
                    case scores
                }
            }
            
            let result = try JSONDecoder().decode(CacheResult.self, from: data)
            print("✅ Found cached recommendations")
            return (result.recommendedUserIds, result.scores)
        }
        
        print("ℹ️ No cached recommendations found")
        return nil
    }
}

enum InteractionType: String, Codable {
    case like = "like"
    case pass = "pass"
    case match = "match"
}
```

---

### Day 8-10: 简单 Two-Tower 编码器

#### Step 1.5: 创建编码器

**文件**: `BrewNet/BrewNet/SimpleTwoTowerEncoder.swift`

```swift
import Foundation

/// 简单 Two-Tower 编码器（不依赖深度学习）
class SimpleTwoTowerEncoder {
    
    /// 编码用户特征为向量
    static func encodeUser(_ features: UserTowerFeatures) -> [Double] {
        var vector: [Double] = []
        
        // 1. One-hot 编码
        vector += oneHotEncode(
            features.mainIntention,
            allCategories: FeatureVocabularies.allIntentions
        )
        
        vector += oneHotEncode(
            features.experienceLevel,
            allCategories: FeatureVocabularies.allExperienceLevels
        )
        
        vector += oneHotEncode(
            features.industry ?? "",
            allCategories: FeatureVocabularies.allIndustries
        )
        
        // 2. Multi-hot 编码
        vector += multiHotEncode(
            features.skills,
            allCategories: FeatureVocabularies.allSkills
        )
        
        vector += multiHotEncode(
            features.hobbies,
            allCategories: FeatureVocabularies.allHobbies
        )
        
        vector += multiHotEncode(
            features.values,
            allCategories: FeatureVocabularies.allValues
        )
        
        // 3. 数值特征
        vector.append(features.yearsOfExperience / 50.0)
        vector.append(features.profileCompletion)
        vector.append(Double(features.isVerified))
        
        return vector
    }
    
    /// 计算 Embedding（简单的降维 + 归一化）
    static func computeEmbedding(_ features: [Double]) -> [Double] {
        let embeddingDim = 64
        var embedding = [Double](repeating: 0.0, count: embeddingDim)
        
        // 简单的线性投影
        for i in 0..<features.count {
            let hash = i % embeddingDim
            embedding[hash] += features[i]
        }
        
        // L2 归一化
        let norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        if norm > 1e-10 {
            return embedding.map { $0 / norm }
        }
        return embedding
    }
    
    /// 计算余弦相似度
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else {
            print("⚠️ Vector dimensions mismatch: \(a.count) vs \(b.count)")
            return 0.0
        }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        return dotProduct / max(magnitudeA * magnitudeB, 1e-10)
    }
    
    // MARK: - Helper Functions
    
    private static func oneHotEncode(_ value: String?, allCategories: [String]) -> [Double] {
        guard let value = value, !value.isEmpty else {
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        
        guard let index = allCategories.firstIndex(of: value) else {
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        
        var oneHot = [Double](repeating: 0.0, count: allCategories.count)
        oneHot[index] = 1.0
        return oneHot
    }
    
    private static func multiHotEncode(_ values: [String], allCategories: [String]) -> [Double] {
        var multiHot = [Double](repeating: 0.0, count: allCategories.count)
        
        for value in values {
            if let index = allCategories.firstIndex(of: value) {
                multiHot[index] = 1.0
            }
        }
        
        return multiHot
    }
}
```

---

### Day 11-14: 测试和验证

#### Step 1.6: 单元测试

**文件**: `BrewNetTests/SimpleTwoTowerEncoderTests.swift`

```swift
import XCTest
@testable import BrewNet

final class SimpleTwoTowerEncoderTests: XCTestCase {
    
    func testEncodeUser() {
        let features = UserTowerFeatures(
            location: "San Francisco",
            timeZone: "America/Los_Angeles",
            industry: "Technology",
            experienceLevel: "senior",
            careerStage: "manager",
            mainIntention: "learnGrow",
            skills: ["Swift", "AI"],
            hobbies: ["Coffee Culture", "Photography"],
            values: ["Innovative"],
            languages: ["English"],
            subIntentions: ["careerDirection"],
            skillsToLearn: ["Machine Learning"],
            skillsToTeach: ["iOS Development"],
            functionsToLearn: ["Product Management"],
            functionsToTeach: ["Software Engineering"],
            yearsOfExperience: 8.5,
            profileCompletion: 0.85,
            isVerified: 1
        )
        
        let vector = SimpleTwoTowerEncoder.encodeUser(features)
        XCTAssertGreaterThan(vector.count, 0)
    }
    
    func testComputeEmbedding() {
        let features = [1.0, 2.0, 3.0, 4.0, 5.0]
        let embedding = SimpleTwoTowerEncoder.computeEmbedding(features)
        
        XCTAssertEqual(embedding.count, 64)
        
        // 检查 L2 归一化
        let norm = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        XCTAssertEqual(norm, 1.0, accuracy: 0.01)
    }
    
    func testCosineSimilarity() {
        let a = [1.0, 2.0, 3.0]
        let b = [4.0, 5.0, 6.0]
        
        let similarity = SimpleTwoTowerEncoder.cosineSimilarity(a, b)
        XCTAssertGreaterThan(similarity, 0.0)
        XCTAssertLessThanOrEqual(similarity, 1.0)
    }
}
```

#### Step 1.7: 集成测试

**文件**: `BrewNet/Tools/TestTwoTowerIntegration.swift`

```swift
import Foundation
import SwiftUI

struct TwoTowerIntegrationTest: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var testResults: [String] = []
    
    var body: some View {
        List {
            ForEach(testResults, id: \.self) { result in
                Text(result)
            }
        }
        .onAppear {
            runTests()
        }
    }
    
    private func runTests() {
        Task {
            // 测试 1: 同步用户特征
            await testSyncUserFeatures()
            
            // 测试 2: 获取用户特征
            await testGetUserFeatures()
            
            // 测试 3: 编码和解码
            await testEncoding()
            
            // 测试 4: 相似度计算
            await testSimilarity()
        }
    }
    
    private func testSyncUserFeatures() async {
        print("🧪 Test 1: Sync User Features")
        // 触发一次资料更新，检查 user_features 是否同步
    }
    
    private func testGetUserFeatures() async {
        print("🧪 Test 2: Get User Features")
        guard let userId = authManager.currentUser?.id else { return }
        
        do {
            let features = try await supabaseService.getUserFeatures(userId: userId)
            testResults.append("✅ Got user features: \(features?.skills.count ?? 0) skills")
        } catch {
            testResults.append("❌ Failed to get features: \(error)")
        }
    }
    
    private func testEncoding() async {
        print("🧪 Test 3: Encoding")
        // 创建测试特征并编码
    }
    
    private func testSimilarity() async {
        print("🧪 Test 4: Similarity")
        // 测试相似度计算
    }
}
```

---

## 🎯 Phase 2: 推荐逻辑集成（Week 3-4）

### Day 15-17: 推荐服务实现

#### Step 2.1: 创建推荐服务

**文件**: `BrewNet/BrewNet/RecommendationService.swift`

```swift
import Foundation

/// Two-Tower 推荐服务
class RecommendationService {
    static let shared = RecommendationService()
    
    private let encoder = SimpleTwoTowerEncoder.self
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    /// 获取推荐用户（完整的 Two-Tower 流程）
    func getRecommendations(
        for userId: String,
        limit: Int = 20
    ) async throws -> [(profile: UserTowerFeatures, score: Double, userId: String)] {
        
        print("🔍 Getting recommendations for user: \(userId)")
        
        // 1. 检查缓存
        if let cached = try await supabaseService.getCachedRecommendations(userId: userId) {
            print("✅ Using cached recommendations")
            return await loadProfilesWithCache(cached)
        }
        
        // 2. 获取用户特征
        guard let userFeatures = try await supabaseService.getUserFeatures(userId: userId) else {
            throw RecommendationError.userNotFound
        }
        
        // 3. 编码用户
        let userVector = encoder.computeEmbedding(encoder.encodeUser(userFeatures))
        
        // 4. 获取候选用户
        let candidates = try await supabaseService.getAllCandidateFeatures(
            excluding: userId,
            limit: 1000
        )
        
        print("📊 Processing \(candidates.count) candidates")
        
        // 5. 计算相似度
        var scoredCandidates: [(profile: UserTowerFeatures, score: Double, userId: String)] = []
        
        for candidate in candidates {
            // 这里应该从 candidate 获取 userId，需要扩展 UserTowerFeatures
            let candidateVector = encoder.computeEmbedding(encoder.encodeUser(candidate))
            let score = encoder.cosineSimilarity(userVector, candidateVector)
            
            // TODO: 获取 candidate 的 userId
            scoredCandidates.append((candidate, score, ""))
        }
        
        // 6. 排序
        scoredCandidates.sort { $0.score > $1.score }
        
        // 7. 获取 Top-K
        let topK = Array(scoredCandidates.prefix(limit))
        
        // 8. 缓存结果
        let userIds = topK.map { $0.userId }
        let scores = topK.map { $0.score }
        
        try await supabaseService.cacheRecommendations(
            userId: userId,
            recommendations: userIds,
            scores: scores,
            modelVersion: "two_tower_simple_v1"
        )
        
        print("✅ Recommendations generated: \(topK.count) profiles")
        return topK
    }
    
    private func loadProfilesWithCache(
        _ cached: ([String], [Double])
    ) async -> [(profile: UserTowerFeatures, score: Double, userId: String)] {
        // 从缓存加载推荐结果
        return []
    }
}

enum RecommendationError: LocalizedError {
    case userNotFound
    case noCandidates
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User features not found"
        case .noCandidates:
            return "No candidate profiles available"
        }
    }
}
```

---

### Day 18-21: 集成到 BrewNetMatchesView

#### Step 2.2: 更新 BrewNetMatchesView

**文件**: `BrewNet/BrewNet/BrewNetMatchesView.swift` (修改 loadProfiles 方法)

```swift
// 在 BrewNetMatchesView 中添加
private let recommendationService = RecommendationService.shared

private func loadProfilesBatch(offset: Int, limit: Int, isInitial: Bool) async {
    do {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run {
                errorMessage = "Please log in to view profiles"
                isLoading = false
                isLoadingMore = false
            }
            return
        }
        
        // 使用 Two-Tower 推荐
        let recommendations = try await recommendationService.getRecommendations(
            for: currentUser.id,
            limit: limit
        )
        
        // 转换为 BrewNetProfile 并显示
        var brewNetProfiles: [BrewNetProfile] = []
        for rec in recommendations {
            // TODO: 从 user_features 加载完整 profile
            // 暂时跳过，需要实现 profile loader
        }
        
        await MainActor.run {
            if isInitial {
                profiles = brewNetProfiles
                isLoading = false
            } else {
                profiles.append(contentsOf: brewNetProfiles)
                isLoadingMore = false
            }
        }
        
    } catch {
        print("❌ Failed to get recommendations: \(error)")
    }
}
```

---

## 🎯 Phase 3: 深度学习升级（Week 5-6）

### Day 22-28: Python 训练环境

#### Step 3.1: 数据导出

**文件**: `scripts/export_interaction_data.py`

```python
import psycopg2
import json
from datetime import datetime

def export_interactions():
    # 连接数据库
    conn = psycopg2.connect(
        host="your-supabase-host",
        database="postgres",
        user="postgres",
        password="your-password"
    )
    
    cur = conn.cursor()
    
    # 导出交互数据
    cur.execute("""
        SELECT 
            user_id,
            target_user_id,
            interaction_type
        FROM user_interactions
        ORDER BY created_at DESC
        LIMIT 10000
    """)
    
    interactions = []
    for row in cur.fetchall():
        interactions.append({
            'user_id': row[0],
            'target_user_id': row[1],
            'label': 1 if row[2] == 'like' else 0
        })
    
    with open('interactions.json', 'w') as f:
        json.dump(interactions, f)
    
    print(f"Exported {len(interactions)} interactions")
    
    # 导出用户特征
    cur.execute("SELECT * FROM user_features")
    # ... 导出逻辑
    
    cur.close()
    conn.close()

if __name__ == '__main__':
    export_interactions()
```

---

## 📝 验收清单

### Phase 1 完成标准 ✅

- [ ] 数据库表创建成功
- [ ] 触发器正常工作
- [ ] 用户特征数据同步
- [ ] Swift 模型编译通过
- [ ] 单元测试全部通过
- [ ] 集成测试验证通过

### Phase 2 完成标准 ✅

- [ ] 推荐服务正常运行
- [ ] 缓存机制工作正常
- [ ] UI 集成成功
- [ ] 性能满足要求（< 1秒）
- [ ] 错误处理完善

### Phase 3 完成标准 ✅

- [ ] Python 环境搭建
- [ ] 数据导出成功
- [ ] 模型训练收敛
- [ ] Core ML 转换成功
- [ ] iOS 端集成成功
- [ ] A/B 测试开始

---

## 🎓 学习资源

**Swift**:
- SwiftUI 异步编程
- Codable 协议
- Supabase Swift SDK

**PostgreSQL**:
- JSONB 操作
- 触发器编写
- 函数编程

**推荐系统**:
- Two-Tower 论文阅读
- 向量检索
- A/B 测试

---

**准备好开始了吗？从 Phase 1 的第一天开始执行！🚀**

