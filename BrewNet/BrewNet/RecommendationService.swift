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
    ///   - forceRefresh: 是否强制刷新，忽略缓存
    ///   - maxDistance: 最大距离限制（公里），nil表示不限制
    ///   - userLocation: 当前用户的位置字符串
    /// - Returns: 推荐结果列表（包含 userId, score 和用户资料）
    func getRecommendations(
        for userId: String,
        limit: Int = 20,
        forceRefresh: Bool = false,
        maxDistance: Double? = nil,
        userLocation: String? = nil
    ) async throws -> [(userId: String, score: Double, profile: BrewNetProfile)] {
        
        print("🔍 Getting recommendations for user: \(userId), limit: \(limit), forceRefresh: \(forceRefresh)")
        
        // 1. 检查缓存（如果 forceRefresh 为 true，跳过缓存）
        if !forceRefresh {
        if let cached = try await supabaseService.getCachedRecommendations(userId: userId) {
            let (cachedUserIds, cachedScores) = cached
            
            // 验证缓存数据的有效性：确保有 userIds 和 scores，且数量匹配
            if !cachedUserIds.isEmpty && cachedUserIds.count == cachedScores.count && cachedScores.count > 0 {
                // 缓存有效，使用缓存
                print("✅ Using cached recommendations (validated: \(cachedUserIds.count) users)")
                return try await loadProfilesWithCache(cached, userId: userId)
            } else {
                // 缓存无效，清除并继续生成新的推荐
                print("⚠️ Invalid cache data, regenerating recommendations...")
                try? await supabaseService.clearRecommendationCache(userId: userId)
                // 继续执行下面的代码生成新的推荐
            }
            }
        } else {
            print("🔄 Force refresh: skipping cache check")
        }
        
        // 2. 获取用户特征
        guard let userFeatures = try await supabaseService.getUserFeatures(userId: userId) else {
            throw RecommendationError.userNotFound
        }
        
        print("📊 User features loaded: \(userFeatures.summary)")
        
        // 3. 获取需要排除的用户ID集合（包括 Invitations、Matches、Interactions）
        let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: userId)
        print("🚫 Will exclude \(excludedUserIds.count) users from recommendations")
        
        // 4. 获取候选用户特征
        // 增加 limit 以覆盖更多用户（数据库有1000个用户）
        let allCandidates = try await supabaseService.getAllCandidateFeatures(
            excluding: userId,
            limit: 2000  // 从 1000 增加到 2000，确保覆盖所有用户
        )
        
        print("📊 Candidate analysis:")
        print("   - Total candidates from user_features table: \(allCandidates.count)")
        print("   - Total excluded users: \(excludedUserIds.count)")
        
        // 4.5. 过滤掉需要排除的用户
        let candidates = allCandidates.filter { candidate in
            !excludedUserIds.contains(candidate.userId)
        }
        
        print("📊 Processing \(candidates.count) candidates (filtered from \(allCandidates.count), excluded \(allCandidates.count - candidates.count))")
        
        // 详细分析：为什么没有候选用户
        if candidates.isEmpty {
            print("⚠️ No candidates available after filtering")
            print("   - All candidates in excluded list: \(allCandidates.count > 0 ? "Yes" : "No")")
            
            // 检查有多少候选用户被排除
            let excludedCandidates = allCandidates.filter { excludedUserIds.contains($0.userId) }
            print("   - Excluded candidates: \(excludedCandidates.count)/\(allCandidates.count)")
            
            // 如果 user_features 表中有很多用户但都被排除了，说明排除列表可能有问题
            if allCandidates.count > 0 && excludedCandidates.count == allCandidates.count {
                print("   ⚠️ CRITICAL: All \(allCandidates.count) candidates are in the excluded list!")
                print("   - This suggests:")
                print("     1. The exclusion list (192 users) may be too large")
                print("     2. All users in user_features have been interacted with")
                print("     3. Possible duplicate entries in exclusion list")
                print("   - Recommendation: Check if exclusion logic is too strict")
            }
            
            // 如果 user_features 表中用户很少，说明数据同步问题
            if allCandidates.count == 0 {
                print("   ⚠️ CRITICAL: No users in user_features table!")
                print("   - Database has 1000 users, but user_features table is empty or not synced")
                print("   - Recommendation: Sync user_features table with users table")
            }
            
            print("   - Possible reasons:")
            print("     1. All users in user_features table have been interacted with")
            print("     2. user_features table has too few users (not synced with users table)")
            print("     3. All users are in excluded list (invitations/matches/interactions)")
            print("     4. Exclusion list (192 users) may contain duplicates or be too large")
            
            throw RecommendationError.noCandidates
        }
        
        // 5. 批量计算相似度（使用新的综合匹配算法）
        var scoredCandidates: [(userId: String, features: UserTowerFeatures, score: Double)] = []
        
        // Fetch Pro status for all candidates in batch for efficiency
        let candidateUserIds = candidates.map { $0.userId }
        let proUserIds = try await supabaseService.getProUserIds(from: candidateUserIds)
        print("✨ [Pro Boost] Found \(proUserIds.count) Pro users among \(candidateUserIds.count) candidates")
        
        for (candidateUserId, candidateFeatures) in candidates {
            // 使用新的综合匹配算法（包含互补匹配和相似匹配）
            var score = encoder.calculateSimilarity(
                userFeatures: userFeatures,
                candidateFeatures: candidateFeatures
            )
            
            // BrewNet Pro boost: Pro users get 1.5x score boost to appear higher in recommendations
            if proUserIds.contains(candidateUserId) {
                score *= 1.5
                print("✨ [Pro Boost] User \(candidateUserId) boosted: \(String(format: "%.3f", score / 1.5)) -> \(String(format: "%.3f", score))")
            }
            
            scoredCandidates.append((candidateUserId, candidateFeatures, score))
        }
        
        // 6. 排序
        scoredCandidates.sort { $0.score > $1.score }
        
        print("📊 Top 5 scores: \(scoredCandidates.prefix(5).map { String(format: "%.3f", $0.score) }.joined(separator: ", "))")
        
        // 7. 获取 Top-K
        let topK = Array(scoredCandidates.prefix(limit))
        print("📊 Selected top \(topK.count) candidates (requested: \(limit))")
        
        // 8. 批量获取所有 Top-K 用户的 profiles（优化性能）
        let topKUserIds = topK.map { $0.userId }
        print("🔍 Fetching profiles for \(topKUserIds.count) recommended users...")
        let profilesDict = try await supabaseService.getProfilesBatch(userIds: topKUserIds)
        print("✅ Fetched \(profilesDict.count) profiles from database (requested: \(topKUserIds.count))")
        
        // 9. 构建结果，保持推荐分数顺序
        var results: [(userId: String, score: Double, profile: BrewNetProfile)] = []
        var missingProfiles: [String] = []
        var decodingErrors: [String] = []
        
        for item in topK {
            if let supabaseProfile = profilesDict[item.userId] {
                do {
                    let brewNetProfile = supabaseProfile.toBrewNetProfile()
                    results.append((item.userId, item.score, brewNetProfile))
                } catch let error as DecodingError {
                    print("⚠️ Decoding error for user \(item.userId):")
                    switch error {
                    case .keyNotFound(let key, let context):
                        print("   - Missing key: \(key.stringValue)")
                        print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("   - Missing value of type: \(type)")
                        print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("   - Type mismatch: expected \(type)")
                        print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("   - Data corrupted: \(context.debugDescription)")
                    @unknown default:
                        print("   - Unknown decoding error")
                    }
                    decodingErrors.append(item.userId)
                } catch {
                    print("⚠️ Failed to convert profile for user \(item.userId): \(error.localizedDescription)")
                    missingProfiles.append(item.userId)
                }
            } else {
                print("⚠️ Profile not found for recommended user: \(item.userId)")
                missingProfiles.append(item.userId)
            }
        }
        
        if !missingProfiles.isEmpty {
            print("⚠️ \(missingProfiles.count) profiles not found: \(missingProfiles.prefix(5).joined(separator: ", "))")
        }
        
        if !decodingErrors.isEmpty {
            print("⚠️ \(decodingErrors.count) profiles failed to decode: \(decodingErrors.prefix(5).joined(separator: ", "))")
            print("   These profiles may have incomplete or corrupted data in the database")
        }
        
        // 9.5. 应用距离过滤（如果设置了 maxDistance）
        if let maxDistance = maxDistance, let userLocation = userLocation, !userLocation.isEmpty {
            print("📍 Applying distance filter: max \(maxDistance) km from '\(userLocation)'")
            let locationService = LocationService.shared
            var filteredResults: [(userId: String, score: Double, profile: BrewNetProfile)] = []
            
            for result in results {
                let candidateLocation = result.profile.coreIdentity.location
                
                // 如果候选人没有位置信息（nil或空字符串），则过滤掉
                guard let candidateLocation = candidateLocation, !candidateLocation.isEmpty else {
                    print("   ❌ Filtered out \(result.profile.coreIdentity.name): no location")
                    continue
                }
                
                // 使用信号量等待距离计算完成
                let semaphore = DispatchSemaphore(value: 0)
                var calculatedDistance: Double? = nil
                
                locationService.calculateDistanceBetweenAddresses(
                    address1: userLocation,
                    address2: candidateLocation
                ) { distance in
                    calculatedDistance = distance
                    semaphore.signal()
                }
                
                // 等待计算完成（最多5秒）
                _ = semaphore.wait(timeout: .now() + 5.0)
                
                if let distance = calculatedDistance {
                    if distance <= maxDistance {
                        print("   ✅ \(result.profile.coreIdentity.name): \(String(format: "%.1f", distance)) km (within \(maxDistance) km)")
                        filteredResults.append(result)
                    } else {
                        print("   ❌ Filtered out \(result.profile.coreIdentity.name): \(String(format: "%.1f", distance)) km (exceeds \(maxDistance) km)")
                    }
                } else {
                    // 无法计算距离的用户也过滤掉
                    print("   ❌ Filtered out \(result.profile.coreIdentity.name): unable to calculate distance")
                }
            }
            
            print("📍 Distance filter result: \(filteredResults.count)/\(results.count) profiles within \(maxDistance) km")
            results = filteredResults
        }
        
        // 10. 缓存结果（确保只缓存推荐系统的结果）
        let userIds = results.map { $0.userId }
        let scores = results.map { $0.score }
        
        // 验证结果：确保每个结果都有有效的分数和用户ID
        guard userIds.count == scores.count, !userIds.isEmpty else {
            print("⚠️ Invalid results for caching, skipping cache")
            return results
        }
        
        try await supabaseService.cacheRecommendations(
            userId: userId,
            recommendations: userIds,
            scores: scores,
            modelVersion: "two_tower_enhanced_v1" // 更新版本号以标识新算法
        )
        
        print("💾 Cached \(userIds.count) recommendations from Two-Tower system")
        
        print("✅ Recommendations generated: \(results.count) profiles (requested: \(limit))")
        
        // 如果成功获取的profiles数量太少，给出警告
        if results.count < limit / 2 && results.count > 0 {
            print("⚠️ WARNING: Only \(results.count)/\(limit) profiles successfully loaded")
            print("   - Missing profiles: \(missingProfiles.count)")
            print("   - Decoding errors: \(decodingErrors.count)")
        }
        
        if results.isEmpty {
            print("⚠️ WARNING: Recommendation system returned 0 profiles!")
            print("   - Requested: \(limit) profiles")
            print("   - Candidates available: \(candidates.count)")
            print("   - Profiles fetched from DB: \(profilesDict.count)")
            print("   - Missing profiles: \(missingProfiles.count)")
            print("   - Decoding errors: \(decodingErrors.count)")
            print("   - Possible causes:")
            print("     1. All top-K profiles failed to load from database")
            print("     2. Profile decoding failed for all recommended users")
            print("     3. All profiles have incomplete/corrupted data in database")
        }
        
        return results
    }
    
    /// 从缓存加载推荐结果（优化版：批量获取，确保只使用推荐系统中的用户）
    private func loadProfilesWithCache(
        _ cached: ([String], [Double]),
        userId: String
    ) async throws -> [(userId: String, score: Double, profile: BrewNetProfile)] {
        let (userIds, scores) = cached
        
        print("📦 Loading \(userIds.count) profiles from cache...")
        
        // 获取需要排除的用户ID集合（包括 Invitations、Matches、Interactions）
        let excludedUserIds = try await supabaseService.getExcludedUserIds(userId: userId)
        print("🚫 Filtering cache: excluding \(excludedUserIds.count) users")
        
        // 过滤掉需要排除的用户，同时保留分数索引
        var validUserIds: [(userId: String, scoreIndex: Int)] = []
        for (index, cachedUserId) in userIds.enumerated() {
            if !excludedUserIds.contains(cachedUserId) && index < scores.count {
                validUserIds.append((cachedUserId, index))
            }
        }
        
        print("✅ \(validUserIds.count) valid users after filtering (from \(userIds.count) cached)")
        
        // 批量获取所有有效的 profiles（大幅提升速度）
        let userIdsToFetch = validUserIds.map { $0.userId }
        let profilesDict = try await supabaseService.getProfilesBatch(userIds: userIdsToFetch)
        
        // 构建结果，保持推荐分数顺序
        var results: [(userId: String, score: Double, profile: BrewNetProfile)] = []
        for (cachedUserId, scoreIndex) in validUserIds {
            if let supabaseProfile = profilesDict[cachedUserId] {
                let brewNetProfile = supabaseProfile.toBrewNetProfile()
                let score = scores[scoreIndex]
                results.append((cachedUserId, score, brewNetProfile))
            } else {
                print("⚠️ Profile not found for cached user: \(cachedUserId)")
            }
        }
        
        // 按推荐分数排序（确保顺序正确）
        results.sort { $0.score > $1.score }
        
        print("✅ Loaded \(results.count) profiles from cache (batch fetched, filtered from \(userIds.count))")
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

