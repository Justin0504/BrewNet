import Foundation

// MARK: - 信誉评分系统

/// 信誉等级
enum CredibilityTier: String, Codable {
    case highlyTrusted = "Highly Trusted"     // 4.6-5.0
    case wellTrusted = "Well Trusted"         // 4.1-4.5
    case trusted = "Trusted"                  // 3.6-4.0
    case normal = "Normal"                    // 2.6-3.5
    case needsImprovement = "Needs Improvement" // 2.1-2.5
    case alert = "Alert"                      // 1.6-2.0
    case lowTrust = "Low Trust"               // 1.1-1.5
    case critical = "Critical"                // 0.6-1.0
    case banned = "Banned"                    // 0-0.5
    
    var color: String {
        switch self {
        case .highlyTrusted, .wellTrusted: return "green"
        case .trusted, .normal: return "blue"
        case .needsImprovement: return "yellow"
        case .alert: return "orange"
        case .lowTrust, .critical, .banned: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .highlyTrusted: return "star.fill"
        case .wellTrusted: return "checkmark.seal.fill"
        case .trusted: return "checkmark.circle.fill"
        case .normal: return "circle.fill"
        case .needsImprovement: return "exclamationmark.circle"
        case .alert: return "exclamationmark.triangle.fill"
        case .lowTrust: return "xmark.circle.fill"
        case .critical: return "xmark.octagon.fill"
        case .banned: return "hand.raised.fill"
        }
    }
    
    /// 匹配权重加成/惩罚
    var matchingWeightMultiplier: Double {
        switch self {
        case .highlyTrusted: return 1.6      // +60%
        case .wellTrusted: return 1.3        // +30%
        case .trusted: return 1.1            // +10%
        case .normal: return 1.0             // 0%
        case .needsImprovement: return 0.9   // -10%
        case .alert: return 0.7              // -30%
        case .lowTrust, .critical: return 0.4 // -60%
        case .banned: return 0.0             // 封禁
        }
    }
    
    /// 每日右划名额
    var dailySwipeLimit: Int? {
        switch self {
        case .alert: return 3
        case .lowTrust, .critical: return 1
        case .banned: return 0
        default: return nil // 无限制
        }
    }
    
    /// PRO会员折扣
    var proDiscount: Double {
        switch self {
        case .highlyTrusted: return 0.7      // 七折
        case .wellTrusted: return 0.8        // 八折
        case .trusted: return 0.9            // 九折
        default: return 1.0                  // 无折扣
        }
    }
    
    static func fromScore(_ score: Double) -> CredibilityTier {
        switch score {
        case 4.6...5.0: return .highlyTrusted
        case 4.1..<4.6: return .wellTrusted
        case 3.6..<4.1: return .trusted
        case 2.6..<3.6: return .normal
        case 2.1..<2.6: return .needsImprovement
        case 1.6..<2.1: return .alert
        case 1.1..<1.6: return .lowTrust
        case 0.6..<1.1: return .critical
        case 0.0..<0.6: return .banned
        default: return .normal
        }
    }
}

// MARK: - 信誉评分数据

struct CredibilityScore: Codable, Equatable {
    let userId: String
    var overallScore: Double          // 最终评分 (0-5)
    var averageRating: Double         // 平均星级评分 (0-5)
    var fulfillmentRate: Double       // 履约率 (0-100)
    var totalMeetings: Int            // 总见面次数
    var totalNoShows: Int             // 放鸽子次数
    var lastMeetingDate: Date?        // 最后一次见面日期
    var tier: CredibilityTier         // 信誉等级
    var isFrozen: Bool                // 是否冻结
    var freezeEndDate: Date?          // 冻结结束日期
    var isBanned: Bool                // 是否封禁
    var banReason: String?            // 封禁原因
    var gpsAnomalyCount: Int          // GPS异常次数
    var mutualHighRatingCount: Int    // 互相刷分次数
    var lastDecayDate: Date?          // 最后衰减日期
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case overallScore = "overall_score"
        case averageRating = "average_rating"
        case fulfillmentRate = "fulfillment_rate"
        case totalMeetings = "total_meetings"
        case totalNoShows = "total_no_shows"
        case lastMeetingDate = "last_meeting_date"
        case tier
        case isFrozen = "is_frozen"
        case freezeEndDate = "freeze_end_date"
        case isBanned = "is_banned"
        case banReason = "ban_reason"
        case gpsAnomalyCount = "gps_anomaly_count"
        case mutualHighRatingCount = "mutual_high_rating_count"
        case lastDecayDate = "last_decay_date"
    }
    
    init(userId: String) {
        self.userId = userId
        self.overallScore = 3.0          // 默认起点
        self.averageRating = 3.0
        self.fulfillmentRate = 100.0
        self.totalMeetings = 0
        self.totalNoShows = 0
        self.lastMeetingDate = nil
        self.tier = .normal
        self.isFrozen = false
        self.freezeEndDate = nil
        self.isBanned = false
        self.banReason = nil
        self.gpsAnomalyCount = 0
        self.mutualHighRatingCount = 0
        self.lastDecayDate = Date()
    }
}

// MARK: - 评分记录

struct MeetingRating: Codable, Identifiable {
    let id: UUID
    let meetingId: String
    let raterId: String               // 评分者
    let ratedUserId: String           // 被评分者
    let rating: Double                // 评分 (0.5-5.0)
    let tags: [RatingTag]             // 评分标签
    let timestamp: Date
    let gpsVerified: Bool             // GPS验证通过
    let meetingDuration: TimeInterval // 见面时长（秒）
    
    enum CodingKeys: String, CodingKey {
        case id
        case meetingId = "meeting_id"
        case raterId = "rater_id"
        case ratedUserId = "rated_user_id"
        case rating
        case tags
        case timestamp
        case gpsVerified = "gps_verified"
        case meetingDuration = "meeting_duration"
    }
    
    init(meetingId: String, raterId: String, ratedUserId: String, rating: Double, tags: [RatingTag], gpsVerified: Bool, meetingDuration: TimeInterval) {
        self.id = UUID()
        self.meetingId = meetingId
        self.raterId = raterId
        self.ratedUserId = ratedUserId
        self.rating = rating
        self.tags = tags
        self.timestamp = Date()
        self.gpsVerified = gpsVerified
        self.meetingDuration = meetingDuration
    }
}

// MARK: - 评分标签

enum RatingTag: String, Codable, CaseIterable {
    // Positive
    case professionalHelpful = "Professional and helpful"
    case friendlyRespectful = "Friendly and respectful"
    case onTime = "On time"
    case stayInTouch = "Will stay in touch"
    
    // Neutral
    case conversationMismatch = "Conversation didn't fully align"
    case limitedSharing = "Limited information shared"
    case briefMeeting = "Brief meeting"
    
    // Negative (not misconduct)
    case lateRescheduled = "Late or rescheduled last-minute"
    case unfocusedDisengaged = "Unfocused or disengaged"
    case notRespectful = "Not respectful of the conversation flow"
    
    var category: TagCategory {
        switch self {
        case .professionalHelpful, .friendlyRespectful, .onTime, .stayInTouch:
            return .positive
        case .conversationMismatch, .limitedSharing, .briefMeeting:
            return .neutral
        case .lateRescheduled, .unfocusedDisengaged, .notRespectful:
            return .negative
        }
    }
    
    enum TagCategory {
        case positive, neutral, negative
    }
}

// MARK: - 举报类型

enum MisconductType: String, Codable, CaseIterable {
    case violence = "Violence, threats, or intimidation"
    case sexualHarassment = "Sexual harassment or unwanted physical contact"
    case stalking = "Stalking or invasion of privacy"
    case fraud = "Fraud, impersonation, or coercive sales"
    case other = "Other serious misconduct"
    
    var severity: Int {
        switch self {
        case .violence, .sexualHarassment: return 5
        case .stalking: return 4
        case .fraud: return 3
        case .other: return 2
        }
    }
}

// MARK: - 举报记录

struct MisconductReport: Codable, Identifiable {
    let id: UUID
    let reporterId: String
    let reportedUserId: String
    let meetingId: String?
    let misconductType: MisconductType
    let description: String
    let location: String?
    let evidence: [String]?           // 证据文件URL
    let needsFollowUp: Bool
    let timestamp: Date
    var status: ReportStatus
    var reviewNotes: String?
    var reviewedAt: Date?
    var reviewedBy: String?
    
    enum ReportStatus: String, Codable {
        case pending = "Pending Review"
        case underInvestigation = "Under Investigation"
        case verified = "Verified - Action Taken"
        case rejected = "Not Verified"
        case dismissed = "Dismissed"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case reportedUserId = "reported_user_id"
        case meetingId = "meeting_id"
        case misconductType = "misconduct_type"
        case description
        case location
        case evidence
        case needsFollowUp = "needs_follow_up"
        case timestamp
        case status
        case reviewNotes = "review_notes"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
    }
    
    init(reporterId: String, reportedUserId: String, meetingId: String?, misconductType: MisconductType, description: String, location: String?, evidence: [String]?, needsFollowUp: Bool) {
        self.id = UUID()
        self.reporterId = reporterId
        self.reportedUserId = reportedUserId
        self.meetingId = meetingId
        self.misconductType = misconductType
        self.description = description
        self.location = location
        self.evidence = evidence
        self.needsFollowUp = needsFollowUp
        self.timestamp = Date()
        self.status = .pending
        self.reviewNotes = nil
        self.reviewedAt = nil
        self.reviewedBy = nil
    }
}

// MARK: - 评分计算服务

class CredibilityCalculator {
    
    /// 计算最终评分
    /// S = 0.7 × 对方评分 + 0.3 × 履约率得分
    static func calculateOverallScore(averageRating: Double, fulfillmentRate: Double) -> Double {
        let ratingScore = averageRating // 0-5
        let fulfillmentScore = convertFulfillmentRateToScore(fulfillmentRate) // 0-5
        
        let overall = 0.7 * ratingScore + 0.3 * fulfillmentScore
        
        // 四舍五入到0.5
        return round(overall * 2) / 2
    }
    
    /// 履约率转换为评分 (0-5)
    static func convertFulfillmentRateToScore(_ rate: Double) -> Double {
        switch rate {
        case 95...100: return 5.0
        case 90..<95: return 4.5
        case 85..<90: return 4.0
        case 80..<85: return 3.5
        case 70..<80: return 3.0
        case 60..<70: return 2.5
        case 50..<60: return 2.0
        case 40..<50: return 1.5
        case 30..<40: return 1.0
        default: return 0.5
        }
    }
    
    /// 计算履约率
    static func calculateFulfillmentRate(totalMeetings: Int, noShows: Int) -> Double {
        guard totalMeetings > 0 else { return 100.0 }
        let rate = Double(totalMeetings - noShows) / Double(totalMeetings) * 100.0
        return max(0, min(100, rate))
    }
    
    /// 评分衰减
    /// 15天未见面开始衰减，越高分衰减越快
    static func applyDecay(currentScore: Double, daysSinceLastMeeting: Int) -> Double {
        guard daysSinceLastMeeting >= 15 else { return currentScore }
        
        let daysOverLimit = Double(daysSinceLastMeeting - 14)
        var decayPerDay: Double
        
        // 越高分，衰减越快
        switch currentScore {
        case 4.5...5.0: decayPerDay = 0.08  // 高分衰减最快
        case 4.0..<4.5: decayPerDay = 0.06
        case 3.5..<4.0: decayPerDay = 0.04
        case 3.0..<3.5: decayPerDay = 0.03
        case 2.5..<3.0: decayPerDay = 0.02
        default: decayPerDay = 0.01         // 低分衰减最慢
        }
        
        let totalDecay = decayPerDay * daysOverLimit
        let newScore = currentScore - totalDecay
        
        // 四舍五入到0.5
        let rounded = round(max(0.5, newScore) * 2) / 2
        return rounded
    }
    
    /// 检查是否需要衰减
    static func shouldApplyDecay(lastMeetingDate: Date?) -> Bool {
        guard let lastDate = lastMeetingDate else { return false }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return days >= 15
    }
    
    /// 获取距离上次见面的天数
    static func daysSinceLastMeeting(lastMeetingDate: Date?) -> Int {
        guard let lastDate = lastMeetingDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }
}

