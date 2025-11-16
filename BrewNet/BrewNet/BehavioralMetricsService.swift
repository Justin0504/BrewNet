import Foundation
import Supabase

// MARK: - Behavioral Metrics Service

/// 行为量化指标服务 - 负责收集、计算和更新用户行为数据
class BehavioralMetricsService {
    static let shared = BehavioralMetricsService()

    private let client: SupabaseClient
    private weak var supabaseService: SupabaseService?

    private init() {
        self.client = SupabaseConfig.shared.client
    }

    /// 依赖注入
    func setDependencies(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
    }

    // MARK: - 行为数据收集

    /// 收集用户的7天行为数据
    /// - Parameter userId: 用户ID
    /// - Returns: 用户7天内的行为数据
    func collectUserBehaviorData(userId: String) async throws -> UserBehaviorData {
        print("📊 Collecting behavioral data for user: \(userId)")

        // 并行收集各项行为数据
        async let sessionsResult = getSessionsCount7d(userId: userId)
        async let messagesResult = getMessagesSentCount7d(userId: userId)
        async let matchesResult = getMatchesCount7d(userId: userId)
        async let lastActiveResult = getLastActiveDays(userId: userId)
        async let responseRateResult = getResponseRate30d(userId: userId)
        async let passRateResult = getPassRate(userId: userId)
        async let responseTimeResult = getAvgResponseTimeHours(userId: userId)
        async let mentorshipResult = getPastMentorshipCount(userId: userId)

        // 等待所有数据收集完成
        let behaviorData = try await UserBehaviorData(
            sessions7d: sessionsResult,
            messagesSent7d: messagesResult,
            matches7d: matchesResult,
            lastActiveDays: lastActiveResult,
            responseRate30d: responseTimeResult,
            passRate: passRateResult,
            avgResponseTimeHours: responseTimeResult,
            pastMentorshipCount: mentorshipResult
        )

        print("✅ Collected behavioral data: sessions=\(behaviorData.sessions7d), messages=\(behaviorData.messagesSent7d), matches=\(behaviorData.matches7d)")

        return behaviorData
    }

    /// 获取用户7天内的会话数
    private func getSessionsCount7d(userId: String) async throws -> Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        do {
            // 查询用户在过去7天内的活跃匹配（有消息往来的匹配）
            let response = try await client
                .from("matches")
                .select("id, user_id, matched_user_id")
                .or("user_id.eq.\(userId),matched_user_id.eq.\(userId)")
                .eq("status", "active")
                .execute()

            let matches = try JSONDecoder().decode([SupabaseMatch].self, from: response.data)

            var sessionCount = 0

            for match in matches {
                let otherUserId = match.userId == userId ? match.matchedUserId : match.userId

                // 检查这个匹配在过去7天内是否有消息往来
                let messageResponse = try await client
                    .from("messages")
                    .select("id", count: .exact)
                    .or("and(sender_id.eq.\(userId),receiver_id.eq.\(otherUserId)),and(sender_id.eq.\(otherUserId),receiver_id.eq.\(userId))")
                    .gte("created_at", sevenDaysAgo.ISO8601Format())
                    .execute()

                if (messageResponse.count ?? 0) > 0 {
                    sessionCount += 1
                }
            }

            return sessionCount

        } catch {
            print("⚠️ Failed to get sessions count: \(error.localizedDescription)")
            return 0
        }
    }

    /// 获取用户7天内发送的消息数
    private func getMessagesSentCount7d(userId: String) async throws -> Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        do {
            let response = try await client
                .from("messages")
                .select("id", count: .exact)
                .eq("sender_id", userId)
                .gte("created_at", sevenDaysAgo.ISO8601Format())
                .execute()

            return response.count ?? 0

        } catch {
            print("⚠️ Failed to get messages sent count: \(error.localizedDescription)")
            return 0
        }
    }

    /// 获取用户7天内的匹配数
    private func getMatchesCount7d(userId: String) async throws -> Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        do {
            let response = try await client
                .from("matches")
                .select("id", count: .exact)
                .or("user_id.eq.\(userId),matched_user_id.eq.\(userId)")
                .gte("created_at", sevenDaysAgo.ISO8601Format())
                .execute()

            return response.count ?? 0

        } catch {
            print("⚠️ Failed to get matches count: \(error.localizedDescription)")
            return 0
        }
    }

    /// 获取用户最后活跃距今天数
    private func getLastActiveDays(userId: String) async throws -> Int {
        do {
            // 首先检查用户最后的消息发送时间
            let messageResponse = try await client
                .from("messages")
                .select("created_at")
                .eq("sender_id", userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()

            if let messages = try? JSONDecoder().decode([SupabaseMessage].self, from: messageResponse.data),
               let lastMessage = messages.first,
               let lastMessageDate = ISO8601DateFormatter().date(from: lastMessage.createdAt) {

                let days = Calendar.current.dateComponents([.day], from: lastMessageDate, to: Date()).day ?? 0
                return min(days, 365) // 最多365天，避免异常值
            }

            // 如果没有消息记录，检查最后登录时间
            let userResponse = try await client
                .from("users")
                .select("last_login_at")
                .eq("id", userId)
                .single()
                .execute()

            if let userData = try? JSONDecoder().decode(SupabaseUser.self, from: userResponse.data),
               let lastLoginString = userData.lastLoginAt,
               let lastLoginDate = ISO8601DateFormatter().date(from: lastLoginString) {

                let days = Calendar.current.dateComponents([.day], from: lastLoginDate, to: Date()).day ?? 0
                return min(days, 365)
            }

            // 默认30天
            return 30

        } catch {
            print("⚠️ Failed to get last active days: \(error.localizedDescription)")
            return 30
        }
    }

    /// 获取用户30天的回复率
    private func getResponseRate30d(userId: String) async throws -> Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        do {
            // 获取收到的消息数
            let receivedResponse = try await client
                .from("messages")
                .select("id", count: .exact)
                .eq("receiver_id", userId)
                .gte("created_at", thirtyDaysAgo.ISO8601Format())
                .execute()

            let receivedCount = receivedResponse.count ?? 0

            if receivedCount == 0 {
                return 0.5 // 默认回复率
            }

            // 获取回复的消息数（发送给同一用户的消息）
            let sentResponse = try await client
                .from("messages")
                .select("id", count: .exact)
                .eq("sender_id", userId)
                .gte("created_at", thirtyDaysAgo.ISO8601Format())
                .execute()

            let sentCount = sentResponse.count ?? 0

            return min(1.0, Double(sentCount) / Double(receivedCount))

        } catch {
            print("⚠️ Failed to get response rate: \(error.localizedDescription)")
            return 0.5
        }
    }

    /// 获取用户通过推荐的比率
    private func getPassRate(userId: String) async throws -> Double {
        do {
            // 获取用户的所有匹配邀请
            let invitationsResponse = try await client
                .from("coffee_chat_invitations")
                .select("id, status")
                .eq("receiver_id", userId)
                .execute()

            let invitations = try JSONDecoder().decode([CoffeeChatInvitation].self, from: invitationsResponse.data)

            if invitations.isEmpty {
                return 0.5 // 默认通过率
            }

            let acceptedCount = invitations.filter { $0.status == .accepted }.count
            return Double(acceptedCount) / Double(invitations.count)

        } catch {
            print("⚠️ Failed to get pass rate: \(error.localizedDescription)")
            return 0.5
        }
    }

    /// 获取用户的平均回复时间（小时）
    private func getAvgResponseTimeHours(userId: String) async throws -> Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        do {
            // 获取用户收到的消息
            let receivedResponse = try await client
                .from("messages")
                .select("id, sender_id, created_at")
                .eq("receiver_id", userId)
                .gte("created_at", thirtyDaysAgo.ISO8601Format())
                .order("created_at", ascending: true)
                .execute()

            let receivedMessages = try JSONDecoder().decode([SupabaseMessage].self, from: receivedResponse.data)

            if receivedMessages.isEmpty {
                return 24.0 // 默认24小时
            }

            var totalResponseTime: TimeInterval = 0
            var responseCount = 0

            for receivedMessage in receivedMessages {
                guard let receivedDate = ISO8601DateFormatter().date(from: receivedMessage.createdAt) else {
                    continue
                }

                // 查找用户对这条消息的回复
                let replyResponse = try await client
                    .from("messages")
                    .select("created_at")
                    .eq("sender_id", userId)
                    .eq("receiver_id", receivedMessage.senderId)
                    .gte("created_at", receivedDate.ISO8601Format())
                    .order("created_at", ascending: true)
                    .limit(1)
                    .execute()

                if let replies = try? JSONDecoder().decode([SupabaseMessage].self, from: replyResponse.data),
                   let reply = replies.first,
                   let replyDate = ISO8601DateFormatter().date(from: reply.createdAt) {

                    let responseTime = replyDate.timeIntervalSince(receivedDate)
                    if responseTime > 0 && responseTime < 7 * 24 * 3600 { // 最多7天
                        totalResponseTime += responseTime
                        responseCount += 1
                    }
                }
            }

            if responseCount == 0 {
                return 24.0
            }

            let avgResponseTimeHours = (totalResponseTime / Double(responseCount)) / 3600.0
            return min(avgResponseTimeHours, 168.0) // 最多7天

        } catch {
            print("⚠️ Failed to get average response time: \(error.localizedDescription)")
            return 24.0
        }
    }

    /// 获取用户历史导师次数
    private func getPastMentorshipCount(userId: String) async throws -> Int {
        do {
            // 查询用户作为导师的完成会话数
            let response = try await client
                .from("coffee_chat_schedules")
                .select("id", count: .exact)
                .eq("mentor_id", userId)
                .eq("status", "completed")
                .execute()

            return response.count ?? 0

        } catch {
            print("⚠️ Failed to get past mentorship count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - 行为指标计算和更新

    /// 计算并更新用户的行为指标
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - profile: 用户资料（可选，用于Pro状态检查）
    /// - Returns: 计算出的行为指标
    func calculateAndUpdateBehavioralMetrics(
        userId: String,
        profile: BrewNetProfile? = nil
    ) async throws -> UserBehavioralMetrics {

        print("🔄 Calculating behavioral metrics for user: \(userId)")

        // 收集行为数据
        let behaviorData = try await collectUserBehaviorData(userId: userId)

        // 检查Pro用户状态
        let isProUser = profile?.subscription?.isActive ?? false

        // 计算行为指标
        let metrics = UserBehavioralMetrics.from(
            profile: profile ?? BrewNetProfile.createDefault(userId: userId),
            behaviorData: behaviorData,
            isProUser: isProUser
        )

        // 更新数据库
        try await updateUserBehavioralMetrics(userId: userId, metrics: metrics, behaviorData: behaviorData)

        print("✅ Updated behavioral metrics: activity=\(metrics.activityScore), connect=\(metrics.connectScore), mentor=\(metrics.mentorScore)")

        return metrics
    }

    /// 更新用户的行为指标到数据库
    private func updateUserBehavioralMetrics(
        userId: String,
        metrics: UserBehavioralMetrics,
        behaviorData: UserBehaviorData
    ) async throws {

        // 更新user_features表
        let updateData: [String: AnyEncodableValue] = [
            "activity_score": .int(metrics.activityScore),
            "connect_score": .int(metrics.connectScore),
            "mentor_score": .int(metrics.mentorScore),
            "sessions_7d": .int(behaviorData.sessions7d),
            "messages_sent_7d": .int(behaviorData.messagesSent7d),
            "matches_7d": .int(behaviorData.matches7d),
            "last_active_at": .string(Date().ISO8601Format()),
            "behavioral_metrics": .dict([
                "activity_score": .int(metrics.activityScore),
                "connect_score": .int(metrics.connectScore),
                "mentor_score": .int(metrics.mentorScore),
                "sessions_7d": .int(behaviorData.sessions7d),
                "messages_sent_7d": .int(behaviorData.messagesSent7d),
                "matches_7d": .int(behaviorData.matches7d),
                "last_active_days": .int(behaviorData.lastActiveDays),
                "response_rate_30d": .double(behaviorData.responseRate30d),
                "pass_rate": .double(behaviorData.passRate),
                "avg_response_time_hours": .double(behaviorData.avgResponseTimeHours),
                "profile_publicness_score": .double(metrics.profilePublicnessScore),
                "past_mentorship_count": .int(behaviorData.pastMentorshipCount),
                "is_verified": .bool(metrics.isVerified),
                "is_pro_user": .bool(metrics.isProUser),
                "seniority_level": .double(metrics.seniorityLevel),
                "calculated_at": .string(metrics.calculatedAt.ISO8601Format())
            ]),
            "updated_at": .string(Date().ISO8601Format())
        ]

        try await client
            .from("user_features")
            .update(updateData)
            .eq("user_id", userId)
            .execute()
    }

    // MARK: - 批量处理

    /// 批量计算和更新多个用户的行为指标
    /// - Parameter userIds: 用户ID列表
    func batchCalculateBehavioralMetrics(userIds: [String]) async throws {
        print("🔄 Batch calculating behavioral metrics for \(userIds.count) users")

        for userId in userIds {
            do {
                // 尝试获取用户资料
                let profile = try await supabaseService?.getProfile(userId: userId)
                _ = try await calculateAndUpdateBehavioralMetrics(userId: userId, profile: profile?.toBrewNetProfile())
            } catch {
                print("⚠️ Failed to calculate metrics for user \(userId): \(error.localizedDescription)")
            }

            // 添加小延迟避免过载
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        }

        print("✅ Batch calculation completed")
    }

    /// 计算所有活跃用户的行为指标（后台任务）
    func calculateAllActiveUsersBehavioralMetrics() async throws {
        print("🔄 Calculating behavioral metrics for all active users")

        // 获取最近30天活跃的用户
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        let response = try await client
            .from("messages")
            .select("sender_id")
            .gte("created_at", thirtyDaysAgo.ISO8601Format())
            .execute()

        // 提取唯一用户ID
        let messages = try JSONDecoder().decode([SupabaseMessage].self, from: response.data)
        let activeUserIds = Array(Set(messages.map { $0.senderId }))

        try await batchCalculateBehavioralMetrics(userIds: activeUserIds)
    }

    // MARK: - 查询方法

    /// 获取用户的行为指标
    func getUserBehavioralMetrics(userId: String) async throws -> UserBehavioralMetrics? {
        let response = try await client
            .from("user_features")
            .select("behavioral_metrics")
            .eq("user_id", userId)
            .single()
            .execute()

        if let jsonString = String(data: response.data, encoding: .utf8),
           let jsonData = jsonString.data(using: .utf8),
           let behavioralData = try? JSONDecoder().decode([String: Any].self, from: jsonData),
           let metricsData = behavioralData["behavioral_metrics"] as? [String: Any] {

            let jsonMetricsData = try JSONSerialization.data(withJSONObject: metricsData)
            return try JSONDecoder().decode(UserBehavioralMetrics.self, from: jsonMetricsData)
        }

        return nil
    }

    /// 获取用户的基础行为分数字段
    func getUserBehavioralScores(userId: String) async throws -> (activity: Int, connect: Int, mentor: Int)? {
        let response = try await client
            .from("user_features")
            .select("activity_score, connect_score, mentor_score")
            .eq("user_id", userId)
            .single()
            .execute()

        struct ScoreData: Codable {
            let activity_score: Int
            let connect_score: Int
            let mentor_score: Int
        }

        let scores = try JSONDecoder().decode(ScoreData.self, from: response.data)
        return (scores.activity_score, scores.connect_score, scores.mentor_score)
    }

    // MARK: - 辅助方法

    /// 记录用户活动（用于实时更新行为指标）
    func recordUserActivity(userId: String, activityType: UserActivityType) async throws {
        // 这里可以实现实时活动记录逻辑
        // 例如：更新last_active_at，增加相应的计数器等
        print("📝 Recording user activity: \(activityType.rawValue) for user \(userId)")

        let updateData: [String: AnyEncodableValue] = [
            "last_active_at": .string(Date().ISO8601Format()),
            "updated_at": .string(Date().ISO8601Format())
        ]

        try await client
            .from("user_features")
            .update(updateData)
            .eq("user_id", userId)
            .execute()
    }
}

/// 用户活动类型枚举
enum UserActivityType: String {
    case login
    case sendMessage = "send_message"
    case receiveMessage = "receive_message"
    case createMatch = "create_match"
    case acceptInvitation = "accept_invitation"
    case completeSession = "complete_session"
    case updateProfile = "update_profile"
}

// MARK: - 扩展方法

extension Date {
    func ISO8601Format() -> String {
        return ISO8601DateFormatter().string(from: self)
    }
}

extension BrewNetProfile {
    static func createDefault(userId: String) -> BrewNetProfile {
        // 创建一个默认的BrewNetProfile用于行为指标计算
        return BrewNetProfile(
            userId: userId,
            coreIdentity: CoreIdentity(
                userId: userId,
                name: "",
                location: nil,
                timeZone: nil,
                profileImageUrl: nil,
                headline: nil
            ),
            professionalBackground: ProfessionalBackground(
                industry: nil,
                experienceLevel: .entry,
                careerStage: .earlyCareer,
                skills: [],
                languagesSpoken: [],
                yearsOfExperience: nil
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .connectShare,
                selectedSubIntentions: [],
                skillDevelopment: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredIndustries: [],
                preferredExperienceLevels: [],
                preferredCareerStages: [],
                preferredLocations: [],
                preferredTimeZones: []
            ),
            personalitySocial: PersonalitySocial(
                hobbies: [],
                valuesTags: []
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: .private,
                verifiedStatus: .notVerified
            ),
            subscription: nil,
            workPhotos: nil,
            lifestylePhotos: nil,
            completionPercentage: 0.0
        )
    }
}
