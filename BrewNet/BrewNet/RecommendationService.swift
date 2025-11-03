import Foundation

// MARK: - Two-Tower Recommendation Service

/// Two-Tower 推荐服务
/// 负责生成智能推荐列表
class RecommendationService: ObservableObject {
    static let shared = RecommendationService()
    
    private let encoder = SimpleTwoTowerEncoder.self
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    /// 获取推荐用户（完整的 Two-Tower 流程）
    /// - Parameters:
    ///   - userId: 当前用户ID
    ///   - limit: 返回的推荐数量
    /// - Returns: 推荐结果列表（包含 userId, score 和用户资料）
    func getRecommendations(
        for userId: String,
        limit: Int = 20
    ) async throws -> [(userId: String, score: Double, profile: BrewNetProfile)] {
        
        print("🔍 Getting recommendations for user: \(userId), limit: \(limit)")
        
        // 1. 检查缓存
        if let cached = try await supabaseService.getCachedRecommendations(userId: userId) {
            print("✅ Using cached recommendations")
            return try await loadProfilesWithCache(cached)
        }
        
        // 2. 获取用户特征
        guard let userFeatures = try await supabaseService.getUserFeatures(userId: userId) else {
            throw RecommendationError.userNotFound
        }
        
        print("📊 User features loaded: \(userFeatures.summary)")
        
        // 3. 编码用户
        let userVector = encoder.computeEmbedding(encoder.encodeUser(userFeatures))
        print("✅ User encoded to embedding vector (64 dimensions)")
        
        // 4. 获取候选用户特征
        let candidates = try await supabaseService.getAllCandidateFeatures(
            excluding: userId,
            limit: 1000
        )
        
        print("📊 Processing \(candidates.count) candidates")
        
        guard !candidates.isEmpty else {
            throw RecommendationError.noCandidates
        }
        
        // 5. 批量计算相似度
        var scoredCandidates: [(userId: String, features: UserTowerFeatures, score: Double)] = []
        
        for (candidateUserId, candidateFeatures) in candidates {
            let candidateVector = encoder.computeEmbedding(encoder.encodeUser(candidateFeatures))
            let score = encoder.cosineSimilarity(userVector, candidateVector)
            scoredCandidates.append((candidateUserId, candidateFeatures, score))
        }
        
        // 6. 排序
        scoredCandidates.sort { $0.score > $1.score }
        
        print("📊 Top 5 scores: \(scoredCandidates.prefix(5).map { String(format: "%.3f", $0.score) }.joined(separator: ", "))")
        
        // 7. 获取 Top-K
        let topK = Array(scoredCandidates.prefix(limit))
        
        // 8. 转换为 BrewNetProfile
        var results: [(userId: String, score: Double, profile: BrewNetProfile)] = []
        for item in topK {
            // 获取完整 profile
            if let supabaseProfile = try? await supabaseService.getProfile(userId: item.userId) {
                let brewNetProfile = supabaseProfile.toBrewNetProfile()
                results.append((item.userId, item.score, brewNetProfile))
            } else {
                print("⚠️ Failed to load profile for user: \(item.userId)")
            }
        }
        
        // 9. 缓存结果
        let userIds = results.map { $0.userId }
        let scores = results.map { $0.score }
        
        try await supabaseService.cacheRecommendations(
            userId: userId,
            recommendations: userIds,
            scores: scores,
            modelVersion: "two_tower_simple_v1"
        )
        
        print("✅ Recommendations generated: \(results.count) profiles")
        return results
    }
    
    /// 从缓存加载推荐结果
    private func loadProfilesWithCache(
        _ cached: ([String], [Double])
    ) async throws -> [(userId: String, score: Double, profile: BrewNetProfile)] {
        let (userIds, scores) = cached
        var results: [(userId: String, score: Double, profile: BrewNetProfile)] = []
        
        for (index, userId) in userIds.enumerated() {
            if index < scores.count,
               let supabaseProfile = try? await supabaseService.getProfile(userId: userId) {
                let brewNetProfile = supabaseProfile.toBrewNetProfile()
                results.append((userId, scores[index], brewNetProfile))
            }
        }
        
        return results
    }
    
    /// 记录用户交互（Pass）
    func recordPass(userId: String, targetUserId: String) async {
        do {
            try await supabaseService.recordInteraction(
                userId: userId,
                targetUserId: targetUserId,
                type: .pass
            )
        } catch {
            print("❌ Failed to record pass: \(error)")
        }
    }
    
    /// 记录用户交互（Like）
    func recordLike(userId: String, targetUserId: String) async {
        do {
            try await supabaseService.recordInteraction(
                userId: userId,
                targetUserId: targetUserId,
                type: .like
            )
        } catch {
            print("❌ Failed to record like: \(error)")
        }
    }
    
    /// 记录用户交互（Match）
    func recordMatch(userId: String, targetUserId: String) async {
        do {
            try await supabaseService.recordInteraction(
                userId: userId,
                targetUserId: targetUserId,
                type: .match
            )
        } catch {
            print("❌ Failed to record match: \(error)")
        }
    }
}

// MARK: - Recommendation Errors

enum RecommendationError: LocalizedError {
    case userNotFound
    case noCandidates
    case encodingFailed
    case profileLoadFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "用户特征未找到"
        case .noCandidates:
            return "没有候选用户可用"
        case .encodingFailed:
            return "特征编码失败"
        case .profileLoadFailed:
            return "加载用户资料失败"
        }
    }
}

