import Foundation

// MARK: - Simple Two-Tower Encoder

/// 简单 Two-Tower 编码器
/// 不使用深度学习，仅使用特征向量化和降维
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
    
    /// 计算两个用户之间的余弦相似度
    /// - Parameters:
    ///   - userFeatures: 用户 A 的特征
    ///   - candidateFeatures: 用户 B 的特征
    /// - Returns: 相似度分数 [0, 1]
    static func calculateSimilarity(
        userFeatures: UserTowerFeatures,
        candidateFeatures: UserTowerFeatures
    ) -> Double {
        let userEmbedding = computeEmbedding(encodeUser(userFeatures))
        let candidateEmbedding = computeEmbedding(encodeUser(candidateFeatures))
        return cosineSimilarity(userEmbedding, candidateEmbedding)
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
    
    /// 批量计算相似度
    /// - Parameters:
    ///   - userFeatures: 查询用户特征
    ///   - candidateFeaturesList: 候选用户特征列表
    /// - Returns: 相似度分数列表（与候选列表对应）
    static func batchSimilarity(
        userFeatures: UserTowerFeatures,
        candidateFeaturesList: [UserTowerFeatures]
    ) -> [Double] {
        let userEmbedding = computeEmbedding(encodeUser(userFeatures))
        
        return candidateFeaturesList.map { candidate in
            let candidateEmbedding = computeEmbedding(encodeUser(candidate))
            return cosineSimilarity(userEmbedding, candidateEmbedding)
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

