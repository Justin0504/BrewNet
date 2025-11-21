import Foundation

// MARK: - Dynamic Weighting System

/// 上下文感知权重调整
class DynamicWeighting {
    
    /// 权重配置
    struct Weights {
        let recommendation: Double  // 推荐系统权重
        let textMatch: Double       // 文本匹配权重
        
        var description: String {
            String(format: "Rec=%.1f%%, Text=%.1f%%", recommendation * 100, textMatch * 100)
        }
    }
    
    /// 根据查询复杂度动态调整权重
    /// - Parameters:
    ///   - query: 查询文本
    ///   - parsedQuery: 解析后的查询
    /// - Returns: 调整后的权重
    static func adjustWeights(
        for query: String,
        parsedQuery: ParsedQuery
    ) -> Weights {
        
        let tokens = parsedQuery.tokens
        let entities = parsedQuery.entities
        
        // 默认权重
        var recWeight: Double = 0.3
        var textWeight: Double = 0.7
        
        // ===== 规则1: 查询长度 =====
        let queryLength = tokens.count
        
        if queryLength <= 2 {
            // 查询很短（如 "Founder"）：更依赖推荐系统
            recWeight = 0.5
            textWeight = 0.5
            print("  📏 Short query → balanced weights")
        } else if queryLength >= 6 {
            // 查询很长且具体：更依赖文本匹配
            recWeight = 0.2
            textWeight = 0.8
            print("  📏 Long query → text-focused weights")
        }
        
        // ===== 规则2: 实体信息 =====
        let entityCount = 
            entities.companies.count + 
            entities.roles.count + 
            entities.schools.count + 
            entities.skills.count
        
        if entityCount >= 3 {
            // 有多个明确实体：提高文本权重
            textWeight += 0.1
            recWeight -= 0.1
            print("  🎯 Multiple entities (\(entityCount)) → text +10%")
        }
        
        // ===== 规则3: 数字信息 =====
        if entities.hasNumber {
            // 有明确数字（年限）：提高文本权重
            textWeight += 0.1
            recWeight -= 0.1
            print("  🔢 Has numbers → text +10%")
        }
        
        // ===== 规则4: 特定术语 =====
        let hasSpecificTerms = tokens.contains(where: { 
            ["alumni", "alum", "founder", "mentor", "mentoring", "startup"].contains($0)
        })
        
        if hasSpecificTerms {
            // 包含特定术语：提高文本权重
            textWeight += 0.05
            recWeight -= 0.05
            print("  ⚡ Specific terms → text +5%")
        }
        
        // ===== 规则5: 概念标签 =====
        if !parsedQuery.conceptTags.isEmpty {
            // 有概念标签（如 "top tech"）：提高文本权重
            textWeight += 0.05
            recWeight -= 0.05
            print("  🏷️  Concept tags → text +5%")
        }
        
        // 归一化到总和为 1.0
        let total = recWeight + textWeight
        recWeight /= total
        textWeight /= total
        
        // 限制范围 [0.1, 0.9]
        recWeight = max(0.1, min(0.9, recWeight))
        textWeight = 1.0 - recWeight
        
        let weights = Weights(recommendation: recWeight, textMatch: textWeight)
        print("  ⚖️  Final weights: \(weights.description)")
        
        return weights
    }
    
    /// 计算查询复杂度
    static func queryComplexity(parsedQuery: ParsedQuery) -> Double {
        var complexity: Double = 0.0
        
        // 长度因素
        complexity += Double(parsedQuery.tokens.count) * 0.1
        
        // 实体因素
        complexity += Double(parsedQuery.entities.companies.count) * 0.3
        complexity += Double(parsedQuery.entities.roles.count) * 0.3
        complexity += Double(parsedQuery.entities.schools.count) * 0.3
        complexity += Double(parsedQuery.entities.skills.count) * 0.2
        
        // 数字因素
        if parsedQuery.entities.hasNumber {
            complexity += 0.5
        }
        
        // 修饰符因素
        complexity += Double(parsedQuery.modifiers.negations.count) * 0.2
        complexity += Double(parsedQuery.modifiers.emphasis.count) * 0.2
        
        return min(complexity, 10.0)  // 限制在 [0, 10]
    }
}

// MARK: - 查询难度分析

/// 查询难度等级
enum QueryDifficulty {
    case simple      // 简单查询 (1-2个词)
    case moderate    // 中等查询 (3-5个词)
    case complex     // 复杂查询 (6+个词，多个实体)
    
    var strategy: String {
        switch self {
        case .simple:
            return "Rely more on recommendation system"
        case .moderate:
            return "Balanced approach"
        case .complex:
            return "Rely more on text matching"
        }
    }
}

extension ParsedQuery {
    /// 查询难度
    var difficulty: QueryDifficulty {
        let tokenCount = tokens.count
        let entityCount = 
            entities.companies.count + 
            entities.roles.count + 
            entities.schools.count
        
        if tokenCount <= 2 || entityCount == 0 {
            return .simple
        } else if tokenCount <= 5 && entityCount <= 2 {
            return .moderate
        } else {
            return .complex
        }
    }
    
    /// 查询特征摘要
    var summary: String {
        var parts: [String] = []
        
        if entities.hasCompany {
            parts.append("Company: \(entities.companies.joined(separator: ", "))")
        }
        if entities.hasRole {
            parts.append("Role: \(entities.roles.joined(separator: ", "))")
        }
        if entities.hasSchool {
            parts.append("School: \(entities.schools.joined(separator: ", "))")
        }
        if entities.hasNumber {
            parts.append("Years: \(entities.numbers.map { String(Int($0)) }.joined(separator: ", "))")
        }
        
        return parts.isEmpty ? "General query" : parts.joined(separator: " | ")
    }
}

