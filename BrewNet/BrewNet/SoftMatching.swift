import Foundation

// MARK: - Soft Matching Utilities

class SoftMatching {
    
    // MARK: - 高斯衰减函数
    
    /// 高斯衰减函数（用于年限匹配）
    /// - Parameters:
    ///   - actual: 实际值
    ///   - target: 目标值
    ///   - sigma: 标准差（控制衰减速度）
    /// - Returns: 匹配分数 [0, 1]
    static func gaussianDecay(
        actual: Double,
        target: Double,
        sigma: Double = 1.5
    ) -> Double {
        let exponent = -pow(actual - target, 2) / (2 * pow(sigma, 2))
        return exp(exponent)
    }
    
    /// 软年限匹配（替代硬截断）
    /// - Parameters:
    ///   - profile: 用户资料
    ///   - targetYears: 目标年限列表
    /// - Returns: 匹配分数 [0, 2.0]
    static func softExperienceMatch(
        profile: BrewNetProfile,
        targetYears: [Double]
    ) -> Double {
        guard let actual = profile.professionalBackground.yearsOfExperience else {
            return 0.0
        }
        
        guard !targetYears.isEmpty else {
            return 0.0
        }
        
        var maxScore: Double = 0.0
        
        for target in targetYears {
            let score = gaussianDecay(actual: actual, target: target, sigma: 1.5)
            maxScore = max(maxScore, score)
            
            if score > 0.8 {  // 高匹配度
                print("  ✓ Experience match: \(actual) years ≈ \(target) years (score: \(String(format: "%.2f", score)))")
            }
        }
        
        // 归一化到 [0, 2.0] 区间（匹配原有 +2.0 的逻辑）
        let finalScore = maxScore * 2.0
        
        return finalScore
    }
    
    // MARK: - 模糊字符串匹配
    
    /// 模糊字符串匹配（Levenshtein 距离）
    /// - Parameters:
    ///   - string1: 字符串1
    ///   - string2: 字符串2
    ///   - threshold: 距离阈值
    /// - Returns: 是否匹配
    static func fuzzyStringMatch(
        string1: String,
        string2: String,
        threshold: Int = 2
    ) -> Bool {
        let distance = levenshteinDistance(string1.lowercased(), string2.lowercased())
        return distance <= threshold
    }
    
    /// 模糊字符串匹配（返回相似度分数）
    /// - Parameters:
    ///   - string1: 字符串1
    ///   - string2: 字符串2
    /// - Returns: 相似度 [0, 1]
    static func fuzzySimilarity(
        string1: String,
        string2: String
    ) -> Double {
        let distance = levenshteinDistance(string1.lowercased(), string2.lowercased())
        let maxLength = Double(max(string1.count, string2.count))
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Double(distance) / maxLength)
    }
    
    /// Levenshtein 距离计算（编辑距离）
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        // 空字符串处理
        if m == 0 { return n }
        if n == 0 { return m }
        
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
    
    // MARK: - 时间衰减
    
    /// 时间衰减函数（用于工作经历）
    /// - Parameters:
    ///   - yearsAgo: 多少年前
    ///   - halfLife: 半衰期（年）
    /// - Returns: 权重 [0, 1]
    static func timeDecay(
        yearsAgo: Double,
        halfLife: Double = 3.0
    ) -> Double {
        // 指数衰减: weight = 0.5^(yearsAgo / halfLife)
        return pow(0.5, yearsAgo / halfLife)
    }
    
    /// 计算工作经历的时间加权分数
    /// - Parameters:
    ///   - experiences: 工作经历列表
    ///   - keyword: 关键词
    /// - Returns: 加权分数
    static func timeWeightedExperienceMatch(
        experiences: [WorkExperience],
        keyword: String
    ) -> Double {
        var totalScore: Double = 0.0
        let currentYear = Double(Calendar.current.component(.year, from: Date()))
        
        for experience in experiences {
            // 检查是否包含关键词
            let companyLower = experience.companyName.lowercased()
            let positionLower = (experience.position ?? "").lowercased()
            
            if companyLower.contains(keyword) || positionLower.contains(keyword) {
                // 计算结束时间（如果是当前工作，使用当前年份）
                let endYear = experience.endYear.map { Double($0) } ?? currentYear
                let yearsAgo = currentYear - endYear
                
                // 应用时间衰减
                let weight = timeDecay(yearsAgo: yearsAgo)
                totalScore += weight
                
                print("  ✓ '\(keyword)' in \(experience.companyName) (\(Int(yearsAgo)) years ago, weight: \(String(format: "%.2f", weight)))")
            }
        }
        
        return totalScore
    }
}

