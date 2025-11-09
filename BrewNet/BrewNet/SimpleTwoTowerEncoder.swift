import Foundation

// MARK: - Recommendation Weights Configuration

/// 推荐系统权重配置 - 针对职场社交场景优化
struct RecommendationWeights {
    // ========== 互补匹配权重（高优先级） ==========
    /// 技能互补匹配权重：用户想学的技能 vs 对方会教的技能
    static let skillComplementWeight: Double = 0.12
    
    // ========== 相似匹配权重（中等优先级） ==========
    /// 意图匹配权重：相同的 networking intention
    static let intentionWeight: Double = 0.24
    
    /// 子意图匹配权重：更细粒度的意图标签
    static let subIntentionWeight: Double = 0.18
    
    /// 行业匹配权重：相同或相关行业
    static let industryWeight: Double = 0.20
    
    /// 技能相似度权重：共同技能
    static let skillSimilarityWeight: Double = 0.035
    
    /// 价值观匹配权重：共同价值观
    static let valuesWeight: Double = 0.028
    
    /// 兴趣匹配权重：共同爱好
    static let hobbiesWeight: Double = 0.02
    
    // ========== 辅助权重（低优先级） ==========
    /// 经验水平匹配权重：相似的经验水平
    static let experienceLevelWeight: Double = 0.12
    
    /// 职业阶段匹配权重：相似的职业阶段
    static let careerStageWeight: Double = 0.02
    
    /// 资料完整度权重：鼓励完整资料
    static let profileCompletionWeight: Double = 0.015
    
    /// 认证状态权重：优先推荐认证用户
    static let verifiedWeight: Double = 0.015
    
    // ========== 多样性权重 ==========
    /// 多样性惩罚：避免过度推荐同一类型用户
    static let diversityPenalty: Double = 0.1
}

// MARK: - Simple Two-Tower Encoder

/// 简单 Two-Tower 编码器
/// 针对职场社交场景优化，支持互补匹配和相似匹配
class SimpleTwoTowerEncoder {
    
    // MARK: - User Encoding
    
    /// 编码用户特征为特征向量
    /// - Parameter features: 用户特征
    /// - Returns: 特征向量
    static func encodeUser(_ features: UserTowerFeatures) -> [Double] {
        var vector: [Double] = []
        
        // 1. One-hot 编码稀疏特征
        vector += oneHotEncode(
            features.mainIntention,
            allCategories: FeatureVocabularies.allIntentions
        )
        
        vector += oneHotEncode(
            features.experienceLevel,
            allCategories: FeatureVocabularies.allExperienceLevels
        )
        
        vector += oneHotEncode(
            features.careerStage,
            allCategories: FeatureVocabularies.allCareerStages
        )
        
        vector += oneHotEncode(
            features.industry ?? "",
            allCategories: FeatureVocabularies.allIndustries
        )
        
        // 2. Multi-hot 编码多值特征
        vector += multiHotEncode(
            features.skills,
            allCategories: FeatureVocabularies.allSkills
        )
        
        vector += multiHotEncode(
            features.hobbies,
            allCategories: FeatureVocabularies.allHobbies
        )
        
        vector += multiHotEncode(
            features.subIntentions,
            allCategories: FeatureVocabularies.allSubIntentions
        )
        
        vector += multiHotEncode(
            features.values,
            allCategories: FeatureVocabularies.allValues
        )
        
        // 3. 学习/教授配对（Multi-hot）
        vector += multiHotEncode(
            features.skillsToLearn,
            allCategories: FeatureVocabularies.allSkills
        )
        
        vector += multiHotEncode(
            features.skillsToTeach,
            allCategories: FeatureVocabularies.allSkills
        )
        
        // 4. 数值特征（归一化）
        vector.append(features.yearsOfExperience / 50.0)  // 归一化到 [0, 1]，假设最多50年经验
        vector.append(min(features.profileCompletion, 1.0))  // 已经是 [0, 1]
        vector.append(Double(features.isVerified))  // 0 or 1
        
        print("📊 Encoded feature vector with \(vector.count) dimensions")
        return vector
    }
    
    // MARK: - Embedding Computation
    
    /// 计算用户 Embedding（降维到 64 维）
    /// - Parameter features: 高维特征向量
    /// - Returns: 64 维归一化的 Embedding
    static func computeEmbedding(_ features: [Double]) -> [Double] {
        let embeddingDim = 64
        var embedding = [Double](repeating: 0.0, count: embeddingDim)
        
        // 简单的线性投影（未来可以用学习到的权重替换）
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
    
    // MARK: - Similarity Computation
    
    /// 计算两个用户之间的综合匹配分数（职场社交优化版）
    /// - Parameters:
    ///   - userFeatures: 用户 A 的特征
    ///   - candidateFeatures: 用户 B 的特征
    /// - Returns: 综合匹配分数 [0, 1]
    static func calculateSimilarity(
        userFeatures: UserTowerFeatures,
        candidateFeatures: UserTowerFeatures
    ) -> Double {
        // 1. 互补匹配分数（高优先级）
        let skillComplementScore = calculateSkillComplement(
            userWantToLearn: userFeatures.skillsToLearn,
            candidateCanTeach: candidateFeatures.skillsToTeach
        )
        
        // 2. 反向互补匹配（候选用户想学 vs 用户会教）
        let reverseSkillComplement = calculateSkillComplement(
            userWantToLearn: candidateFeatures.skillsToLearn,
            candidateCanTeach: userFeatures.skillsToTeach
        )
        
        // 双向互补取平均值
        let avgSkillComplement = (skillComplementScore + reverseSkillComplement) / 2.0
        
        // 3. 相似匹配分数
        let intentionScore = userFeatures.mainIntention == candidateFeatures.mainIntention ? 1.0 : 0.0
        let subIntentionScore = calculateSubIntentionSimilarity(
            userSubIntentions: userFeatures.subIntentions,
            candidateSubIntentions: candidateFeatures.subIntentions
        )
        let industryScore = calculateIndustrySimilarity(
            userIndustry: userFeatures.industry,
            candidateIndustry: candidateFeatures.industry
        )
        let skillSimilarityScore = calculateSkillSimilarity(
            userSkills: userFeatures.skills,
            candidateSkills: candidateFeatures.skills
        )
        let valuesScore = calculateValuesSimilarity(
            userValues: userFeatures.values,
            candidateValues: candidateFeatures.values
        )
        let hobbiesScore = calculateHobbiesSimilarity(
            userHobbies: userFeatures.hobbies,
            candidateHobbies: candidateFeatures.hobbies
        )
        
        // 4. 经验水平匹配
        let experienceScore = calculateExperienceSimilarity(
            userLevel: userFeatures.experienceLevel,
            candidateLevel: candidateFeatures.experienceLevel
        )
        
        // 5. 职业阶段匹配
        let careerStageScore = userFeatures.careerStage == candidateFeatures.careerStage ? 1.0 : 0.0
        
        // 6. 辅助分数
        let profileCompletionScore = (userFeatures.profileCompletion + candidateFeatures.profileCompletion) / 2.0
        let verifiedScore = (Double(userFeatures.isVerified) + Double(candidateFeatures.isVerified)) / 2.0
        
        // 7. 加权综合分数
        var finalScore = 0.0
        finalScore += avgSkillComplement * RecommendationWeights.skillComplementWeight
        finalScore += intentionScore * RecommendationWeights.intentionWeight
        finalScore += subIntentionScore * RecommendationWeights.subIntentionWeight
        finalScore += industryScore * RecommendationWeights.industryWeight
        finalScore += skillSimilarityScore * RecommendationWeights.skillSimilarityWeight
        finalScore += valuesScore * RecommendationWeights.valuesWeight
        finalScore += hobbiesScore * RecommendationWeights.hobbiesWeight
        finalScore += experienceScore * RecommendationWeights.experienceLevelWeight
        finalScore += careerStageScore * RecommendationWeights.careerStageWeight
        finalScore += profileCompletionScore * RecommendationWeights.profileCompletionWeight
        finalScore += verifiedScore * RecommendationWeights.verifiedWeight
        
        // 确保分数在 [0, 1] 范围内
        return min(max(finalScore, 0.0), 1.0)
    }
    
    /// 计算子意图相似度（Jaccard）
    private static func calculateSubIntentionSimilarity(
        userSubIntentions: [String],
        candidateSubIntentions: [String]
    ) -> Double {
        guard !userSubIntentions.isEmpty && !candidateSubIntentions.isEmpty else {
            return 0.0
        }
        
        let intersection = Set(userSubIntentions).intersection(Set(candidateSubIntentions))
        let union = Set(userSubIntentions).union(Set(candidateSubIntentions))
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    // MARK: - Complementary Matching Functions
    
    /// 计算技能互补分数：用户想学的技能 vs 对方会教的技能
    private static func calculateSkillComplement(
        userWantToLearn: [String],
        candidateCanTeach: [String]
    ) -> Double {
        guard !userWantToLearn.isEmpty && !candidateCanTeach.isEmpty else {
            return 0.0
        }
        
        let intersection = Set(userWantToLearn).intersection(Set(candidateCanTeach))
        let union = Set(userWantToLearn).union(Set(candidateCanTeach))
        
        // 使用 Jaccard 相似度
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    // MARK: - Similarity Matching Functions
    
    /// 计算行业相似度
    private static func calculateIndustrySimilarity(
        userIndustry: String?,
        candidateIndustry: String?
    ) -> Double {
        guard let user = userIndustry, let candidate = candidateIndustry,
              !user.isEmpty, !candidate.isEmpty else {
            return 0.0
        }
        
        if user == candidate {
            return 1.0
        }
        
        // 相关行业（简单判断，可以扩展）
        let relatedIndustries: [String: [String]] = [
            "Technology": ["Software", "SaaS"],
            "Finance": ["FinTech", "Banking", "Investments"],
            "Healthcare": ["Medical Devices", "Biotech", "Pharma"],
            "Education": ["EdTech", "Training"]
        ]
        
        for (key, related) in relatedIndustries {
            if (user == key && related.contains(candidate)) ||
               (candidate == key && related.contains(user)) {
                return 0.7
            }
        }
        
        return 0.0
    }
    
    /// 计算技能相似度（Jaccard）
    private static func calculateSkillSimilarity(
        userSkills: [String],
        candidateSkills: [String]
    ) -> Double {
        guard !userSkills.isEmpty && !candidateSkills.isEmpty else {
            return 0.0
        }
        
        let intersection = Set(userSkills).intersection(Set(candidateSkills))
        let union = Set(userSkills).union(Set(candidateSkills))
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    /// 计算价值观相似度
    private static func calculateValuesSimilarity(
        userValues: [String],
        candidateValues: [String]
    ) -> Double {
        guard !userValues.isEmpty && !candidateValues.isEmpty else {
            return 0.0
        }
        
        let intersection = Set(userValues).intersection(Set(candidateValues))
        let union = Set(userValues).union(Set(candidateValues))
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    /// 计算兴趣爱好相似度
    private static func calculateHobbiesSimilarity(
        userHobbies: [String],
        candidateHobbies: [String]
    ) -> Double {
        guard !userHobbies.isEmpty && !candidateHobbies.isEmpty else {
            return 0.0
        }
        
        let intersection = Set(userHobbies).intersection(Set(candidateHobbies))
        let union = Set(userHobbies).union(Set(candidateHobbies))
        
        guard !union.isEmpty else { return 0.0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    /// 计算经验水平相似度
    private static func calculateExperienceSimilarity(
        userLevel: String?,
        candidateLevel: String?
    ) -> Double {
        guard let user = userLevel, let candidate = candidateLevel else {
            return 0.0
        }
        
        if user == candidate {
            return 1.0
        }
        
        // 定义经验水平层次
        let levels = ["Intern", "Entry", "Mid", "Senior", "Executive"]
        guard let userIndex = levels.firstIndex(of: user),
              let candidateIndex = levels.firstIndex(of: candidate) else {
            return 0.0
        }
        
        let distance = abs(userIndex - candidateIndex)
        // 距离越近，相似度越高
        return 1.0 - (Double(distance) / Double(levels.count - 1))
    }
    
    /// 余弦相似度计算
    /// - Parameters:
    ///   - a: 向量 A
    ///   - b: 向量 B
    /// - Returns: 相似度 [0, 1]
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else {
            print("⚠️ Vector dimensions mismatch: \(a.count) vs \(b.count)")
            return 0.0
        }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        let result = dotProduct / max(magnitudeA * magnitudeB, 1e-10)
        
        print("📊 Cosine similarity: \(String(format: "%.4f", result))")
        return result
    }
    
    // MARK: - Helper Functions
    
    /// One-hot 编码
    /// - Parameters:
    ///   - value: 待编码的值
    ///   - allCategories: 所有可能的值
    /// - Returns: One-hot 向量
    private static func oneHotEncode(_ value: String?, allCategories: [String]) -> [Double] {
        guard let value = value, !value.isEmpty else {
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        
        guard let index = allCategories.firstIndex(of: value) else {
            // 值不在词汇表中，返回全零向量
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        
        var oneHot = [Double](repeating: 0.0, count: allCategories.count)
        oneHot[index] = 1.0
        return oneHot
    }
    
    /// Multi-hot 编码
    /// - Parameters:
    ///   - values: 待编码的值列表
    ///   - allCategories: 所有可能的值
    /// - Returns: Multi-hot 向量
    private static func multiHotEncode(_ values: [String], allCategories: [String]) -> [Double] {
        guard !values.isEmpty else {
            return [Double](repeating: 0.0, count: allCategories.count)
        }
        
        var multiHot = [Double](repeating: 0.0, count: allCategories.count)
        
        for value in values {
            if let index = allCategories.firstIndex(of: value) {
                multiHot[index] = 1.0
            } else {
                // 值不在词汇表中，可以记录但不编码
                print("⚠️ Unknown category: \(value) (skipping)")
            }
        }
        
        // 可选：归一化 Multi-hot 向量（使总和为 1）
        let sum = multiHot.reduce(0, +)
        if sum > 0 {
            return multiHot.map { $0 / sum }
        }
        
        return multiHot
    }
    
    // MARK: - Batch Processing
    
    /// 批量编码用户特征
    /// - Parameter features: 用户特征列表
    /// - Returns: Embedding 列表
    static func batchEncode(_ features: [UserTowerFeatures]) -> [[Double]] {
        return features.map { computeEmbedding(encodeUser($0)) }
    }
    
    /// 批量计算相似度（使用新的综合匹配算法）
    /// - Parameters:
    ///   - userFeatures: 查询用户特征
    ///   - candidateFeaturesList: 候选用户特征列表
    /// - Returns: 相似度分数列表（与候选列表对应）
    static func batchSimilarity(
        userFeatures: UserTowerFeatures,
        candidateFeaturesList: [UserTowerFeatures]
    ) -> [Double] {
        return candidateFeaturesList.map { candidate in
            calculateSimilarity(userFeatures: userFeatures, candidateFeatures: candidate)
        }
    }
}

// MARK: - Top-K Retrieval

extension SimpleTwoTowerEncoder {
    /// 获取 Top-K 最相似的用户
    /// - Parameters:
    ///   - userFeatures: 查询用户特征
    ///   - candidateFeaturesList: 候选用户特征列表
    ///   - k: 返回 Top-K 个结果
    /// - Returns: (特征, 分数) 的列表，按分数降序排列
    static func getTopKSimilar(
        userFeatures: UserTowerFeatures,
        candidateFeaturesList: [UserTowerFeatures],
        k: Int
    ) -> [(features: UserTowerFeatures, score: Double)] {
        print("🔍 Finding top \(k) similar users from \(candidateFeaturesList.count) candidates")
        
        // 批量计算相似度
        let scores = batchSimilarity(
            userFeatures: userFeatures,
            candidateFeaturesList: candidateFeaturesList
        )
        
        // 排序并取 Top-K
        let indexedScores = candidateFeaturesList.enumerated().map { (index, features) in
            (features, scores[index])
        }
        
        let sorted = indexedScores.sorted { $0.1 > $1.1 }
        let topK = Array(sorted.prefix(k))
        
        print("✅ Top \(topK.count) recommendations found")
        for (index, item) in topK.enumerated() {
            print("   \(index + 1). Score: \(String(format: "%.4f", item.1))")
        }
        
        return topK
    }
}

// MARK: - Testing Helpers

#if DEBUG
extension SimpleTwoTowerEncoder {
    /// 打印编码统计信息（用于调试）
    static func printEncodingStats() {
        print("📊 Two-Tower Encoding Statistics:")
        print("   Skills vocabulary size: \(FeatureVocabularies.allSkills.count)")
        print("   Hobbies vocabulary size: \(FeatureVocabularies.allHobbies.count)")
        print("   Values vocabulary size: \(FeatureVocabularies.allValues.count)")
        print("   Industries vocabulary size: \(FeatureVocabularies.allIndustries.count)")
        print("   Intentions vocabulary size: \(FeatureVocabularies.allIntentions.count)")
        print("   Experience levels: \(FeatureVocabularies.allExperienceLevels.count)")
        
        // 计算理论特征维度
        let featureDim = FeatureVocabularies.allIntentions.count +
                        FeatureVocabularies.allExperienceLevels.count +
                        FeatureVocabularies.allCareerStages.count +
                        FeatureVocabularies.allIndustries.count +
                        FeatureVocabularies.allSkills.count * 3 + // skills, skillsToLearn, skillsToTeach
                        FeatureVocabularies.allHobbies.count +
                        FeatureVocabularies.allValues.count +
                        3 // yearsOfExperience, profileCompletion, isVerified
        
        print("   Theoretical feature dimension: \(featureDim)")
        print("   Embedding dimension: 64")
    }
}
#endif

