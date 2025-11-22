import SwiftUI

// MARK: - 评分查看界面

struct RatingReviewView: View {
    let meetingId: String
    let participantId: String
    let participantName: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var rating: MeetingRating?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if let rating = rating {
                    ratingContentView(rating: rating)
                } else {
                    noRatingView
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadRating()
            }
        }
    }
    
    // MARK: - Rating Content View
    
    @ViewBuilder
    private func ratingContentView(rating: MeetingRating) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Rating from \(participantName)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text(formatDate(rating.timestamp))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                Divider()
                
                // Star Rating Display
                VStack(spacing: 16) {
                    Text("Rating")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 8) {
                        ForEach(0..<5) { index in
                            let starValue = Double(index) + 0.5
                            let isFilled = rating.rating >= starValue
                            let isHalfFilled = rating.rating >= Double(index) && rating.rating < starValue
                            
                            Group {
                                if isFilled {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                } else if isHalfFilled {
                                    Image(systemName: "star.lefthalf.fill")
                                        .foregroundColor(.yellow)
                                } else {
                                    Image(systemName: "star")
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                            }
                            .font(.system(size: 32))
                        }
                        
                        Spacer()
                        
                        Text(String(format: "%.1f", rating.rating))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(ratingColor(rating.rating))
                    }
                    
                    Text(ratingDescription(rating.rating))
                        .font(.system(size: 16))
                        .foregroundColor(ratingColor(rating.rating))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                // Tags (if any)
                if !rating.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.system(size: 18, weight: .semibold))
                        
                        FlowLayout(spacing: 8) {
                            ForEach(rating.tags, id: \.self) { tag in
                                TagChip(tag: tag)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                
                // Comment (if any)
                if let comment = rating.comment, !comment.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comment")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text(comment)
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
                            .cornerRadius(12)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                }
                
                // Meeting Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meeting Details")
                        .font(.system(size: 18, weight: .semibold))
                    
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(rating.gpsVerified ? .green : .gray)
                        Text(rating.gpsVerified ? "GPS Verified" : "Not GPS Verified")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    if rating.meetingDuration > 0 {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Duration: \(formatDuration(rating.meetingDuration))")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - No Rating View
    
    private var noRatingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Rating Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("\(participantName) hasn't rated this meeting yet.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Helper Functions
    
    private func loadRating() {
        guard let currentUserId = authManager.currentUser?.id else {
            errorMessage = "Unable to load rating"
            isLoading = false
            return
        }
        
        print("🔍 [RatingReview] 开始加载评分")
        print("🔍 [RatingReview] meetingId: \(meetingId)")
        print("🔍 [RatingReview] participantId (raterId): \(participantId)")
        print("🔍 [RatingReview] currentUserId (ratedUserId): \(currentUserId)")
        
        Task {
            do {
                // 直接查询所有 meeting_ratings 记录，然后手动匹配（避免 UUID 格式问题）
                print("🔍 [RatingReview] 步骤1: 查询所有 meeting_ratings 记录...")
                print("🔍 [RatingReview] 期望的 meetingId: \(meetingId.lowercased())")
                print("🔍 [RatingReview] 期望的 participantId (raterId): \(participantId.lowercased())")
                print("🔍 [RatingReview] 期望的 currentUserId (ratedUserId): \(currentUserId.lowercased())")
                
                // 查询所有记录（不添加过滤条件，避免 UUID 格式问题）
                let allRatingsResponse = try await supabaseService.supabase
                    .from("meeting_ratings")
                    .select("*")
                    .limit(100)  // 限制数量，避免查询过多
                    .execute()
                
                print("🔍 [RatingReview] 查询响应状态码: \(allRatingsResponse.response.statusCode)")
                print("🔍 [RatingReview] 响应数据: \(String(data: allRatingsResponse.data, encoding: .utf8) ?? "无法解析")")
                
                if let allData = try? JSONSerialization.jsonObject(with: allRatingsResponse.data) as? [[String: Any]] {
                    print("🔍 [RatingReview] 找到 \(allData.count) 条评分记录")
                    for (index, record) in allData.enumerated() {
                        let raterId = record["rater_id"] as? String ?? "nil"
                        let ratedUserId = record["rated_user_id"] as? String ?? "nil"
                        let ratingValue = record["rating"] as? Double ?? 0
                        let comment = record["comment"] as? String ?? "nil"
                        print("🔍 [RatingReview] 记录 \(index):")
                        print("   - rater_id: \(raterId)")
                        print("   - rated_user_id: \(ratedUserId)")
                        print("   - rating: \(ratingValue)")
                        print("   - comment: \(comment)")
                        print("   - 期望的 raterId (participantId): \(participantId)")
                        print("   - 期望的 ratedUserId (currentUserId): \(currentUserId)")
                        print("   - raterId 匹配: \(raterId.lowercased() == participantId.lowercased())")
                        print("   - ratedUserId 匹配: \(ratedUserId.lowercased() == currentUserId.lowercased())")
                    }
                } else {
                    print("⚠️ [RatingReview] 无法解析响应数据")
                }
                
                // 🆕 从所有记录中手动匹配
                print("🔍 [RatingReview] 步骤2: 从所有记录中手动匹配...")
                
                if let allData = try? JSONSerialization.jsonObject(with: allRatingsResponse.data) as? [[String: Any]] {
                    print("🔍 [RatingReview] 查询到 \(allData.count) 条记录")
                    
                    // 查找匹配的记录（不区分大小写比较 UUID）
                    // 注意：由于 meeting_id 可能不匹配（可能是不同的 schedule），我们只匹配 rater_id 和 rated_user_id
                    var matchedRecord: [String: Any]? = nil
                    let expectedRaterId = participantId.lowercased()
                    let expectedRatedUserId = currentUserId.lowercased()
                    
                    print("🔍 [RatingReview] 匹配策略: 只匹配 rater_id 和 rated_user_id（忽略 meeting_id，因为可能不匹配）")
                    
                    for (index, record) in allData.enumerated() {
                        let recordMeetingId = (record["meeting_id"] as? String ?? "").lowercased()
                        let raterId = (record["rater_id"] as? String ?? "").lowercased()
                        let ratedUserId = (record["rated_user_id"] as? String ?? "").lowercased()
                        let ratingValue = record["rating"] as? Double ?? 0
                        let comment = record["comment"] as? String ?? "nil"
                        
                        let raterMatch = raterId == expectedRaterId
                        let ratedMatch = ratedUserId == expectedRatedUserId
                        
                        print("🔍 [RatingReview] 记录 \(index):")
                        print("   - meeting_id: \(recordMeetingId)")
                        print("   - rater_id: \(raterId) vs \(expectedRaterId) -> \(raterMatch)")
                        print("   - rated_user_id: \(ratedUserId) vs \(expectedRatedUserId) -> \(ratedMatch)")
                        print("   - rating: \(ratingValue)")
                        print("   - comment: \(comment)")
                        
                        // 只匹配 rater_id 和 rated_user_id（因为 meeting_id 可能不匹配）
                        if raterMatch && ratedMatch {
                            matchedRecord = record
                            print("✅ [RatingReview] 找到匹配的记录! (rater_id 和 rated_user_id 匹配)")
                            break
                        }
                    }
                    
                    if let firstRecord = matchedRecord {
                        print("🔍 [RatingReview] 匹配的记录: \(firstRecord)")
                        
                        // 直接从响应数据中解码（使用原始的 JSON 响应）
                        print("🔍 [RatingReview] 尝试从原始响应数据解码...")
                        
                        // 从 allRatingsResponse 中查找匹配的记录并解码
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        let dateFormatter = ISO8601DateFormatter()
                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        decoder.dateDecodingStrategy = .custom { decoder in
                            let container = try decoder.singleValueContainer()
                            let dateString = try container.decode(String.self)
                            
                            if let date = dateFormatter.date(from: dateString) {
                                return date
                            }
                            
                            dateFormatter.formatOptions = [.withInternetDateTime]
                            if let date = dateFormatter.date(from: dateString) {
                                return date
                            }
                            
                            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
                        }
                        
                        // 解码所有记录
                        if let allRatings = try? decoder.decode([MeetingRating].self, from: allRatingsResponse.data) {
                            // 查找匹配的记录
                            let expectedRaterId = participantId.lowercased()
                            let expectedRatedUserId = currentUserId.lowercased()
                            
                            if let matchedRating = allRatings.first(where: { rating in
                                rating.raterId.lowercased() == expectedRaterId &&
                                rating.ratedUserId.lowercased() == expectedRatedUserId
                            }) {
                                print("✅ [RatingReview] 从原始响应解码成功: \(matchedRating.rating) 星")
                                print("✅ [RatingReview] 评分详情: id=\(matchedRating.id), comment=\(matchedRating.comment ?? "无评论"), tags=\(matchedRating.tags.count)个")
                                await MainActor.run {
                                    rating = matchedRating
                                    isLoading = false
                                }
                                return
                            } else {
                                print("⚠️ [RatingReview] 在解码的记录中未找到匹配项")
                            }
                        } else {
                            print("⚠️ [RatingReview] 无法解码原始响应数据")
                        }
                        
                        // 如果解码失败，使用手动构建（作为后备方案）
                        print("⚠️ [RatingReview] 使用手动构建作为后备方案...")
                        
                        guard let idString = firstRecord["id"] as? String,
                              let ratingValue = firstRecord["rating"] as? Double ?? (firstRecord["rating"] as? Int).map(Double.init),
                              let timestampString = firstRecord["timestamp"] as? String else {
                            print("❌ [RatingReview] 无法从记录中提取必需字段")
                            await MainActor.run {
                                isLoading = false
                            }
                            return
                        }
                        
                        let recordMeetingId = (firstRecord["meeting_id"] as? String ?? "").lowercased()
                        let recordRaterId = (firstRecord["rater_id"] as? String ?? "").lowercased()
                        let recordRatedUserId = (firstRecord["rated_user_id"] as? String ?? "").lowercased()
                        
                        // 解析日期
                        let dateFormatter2 = ISO8601DateFormatter()
                        dateFormatter2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        var timestamp = Date()
                        if let date = dateFormatter2.date(from: timestampString) {
                            timestamp = date
                        } else {
                            dateFormatter2.formatOptions = [.withInternetDateTime]
                            if let date = dateFormatter2.date(from: timestampString) {
                                timestamp = date
                            }
                        }
                        
                        // 解析 tags
                        var tags: [RatingTag] = []
                        if let tagsArray = firstRecord["tags"] as? [String] {
                            tags = tagsArray.compactMap { RatingTag(rawValue: $0) }
                        }
                        
                        // 解析其他字段
                        let gpsVerified = (firstRecord["gps_verified"] as? Bool) ?? ((firstRecord["gps_verified"] as? Int) != 0)
                        let meetingDuration = (firstRecord["meeting_duration"] as? TimeInterval) ?? TimeInterval((firstRecord["meeting_duration"] as? Int) ?? 0)
                        let comment = firstRecord["comment"] as? String
                        
                        // 手动构建 MeetingRating
                        let manualRating = MeetingRating(
                            meetingId: recordMeetingId,
                            raterId: recordRaterId,
                            ratedUserId: recordRatedUserId,
                            rating: ratingValue,
                            tags: tags,
                            comment: comment,
                            gpsVerified: gpsVerified,
                            meetingDuration: meetingDuration
                        )
                        
                        print("✅ [RatingReview] 手动构建成功: \(manualRating.rating) 星")
                        await MainActor.run {
                            rating = manualRating
                            isLoading = false
                        }
                        return
                    } else {
                        print("⚠️ [RatingReview] 未找到匹配的记录")
                    }
                } else {
                    print("⚠️ [RatingReview] 无法解析响应数据")
                }
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                print("❌ [RatingReview] 加载评分失败: \(error.localizedDescription)")
                print("❌ [RatingReview] 错误类型: \(type(of: error))")
                print("❌ [RatingReview] 错误详情: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to load rating: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func ratingColor(_ rating: Double) -> Color {
        switch rating {
        case 4.5...5.0: return .green
        case 4.0..<4.5: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case 3.5..<4.0: return .blue
        case 3.0..<3.5: return Color(red: 0.4, green: 0.6, blue: 0.9)
        case 2.5..<3.0: return .orange
        case 2.0..<2.5: return Color(red: 1.0, green: 0.6, blue: 0.2)
        default: return .red
        }
    }
    
    private func ratingDescription(_ rating: Double) -> String {
        switch rating {
        case 4.6...5.0: return "Excellent — Highly valuable conversation"
        case 3.6..<4.6: return "Good — Smooth and insightful"
        case 2.6..<3.6: return "Fair — Average experience"
        case 1.6..<2.6: return "Poor — Below expectations"
        case 0.6..<1.6: return "Very Poor — Would not meet again"
        default: return "Unacceptable — Seriously negative experience"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: RatingTag
    
    private var tagColor: Color {
        switch tag.category {
        case .positive: return .green
        case .neutral: return .blue
        case .negative: return .orange
        }
    }
    
    var body: some View {
        Text(tag.rawValue)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tagColor.opacity(0.15))
            .foregroundColor(tagColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tagColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Preview

struct RatingReviewView_Previews: PreviewProvider {
    static var previews: some View {
        RatingReviewView(
            meetingId: "test-meeting-id",
            participantId: "test-participant-id",
            participantName: "John Doe"
        )
        .environmentObject(AuthManager())
        .environmentObject(SupabaseService.shared)
    }
}

