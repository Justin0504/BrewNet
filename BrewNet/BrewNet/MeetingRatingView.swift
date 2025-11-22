import SwiftUI

// MARK: - 见面后评分界面

struct MeetingRatingView: View {
    let meetingId: String
    let otherUserId: String
    let otherUserName: String
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var rating: Double = 3.0
    @State private var selectedTags: Set<RatingTag> = []
    @State private var comment: String = ""  // 🆕 评论内容
    @State private var showReportSheet = false
    @State private var isSubmitting = false
    
    var body: some View {
        // 🆕 使用 NavigationView 来提供导航栏和 dismiss 环境
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Header - 简化版本
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How was your Coffee Chat?")
                            .font(.system(size: 22, weight: .bold))
                        
                        Text("Please rate your in-person meeting.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                    
                    // Star Rating
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Rating")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Drag to set your overall experience rating.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        // Star Display - 优化版本，不使用 GeometryReader
                        HStack(spacing: 8) {
                            ForEach(0..<5) { index in
                                let starValue = Double(index) + 0.5
                                let isFilled = rating >= starValue
                                let isHalfFilled = rating >= Double(index) && rating < starValue
                                
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
                                .font(.system(size: 40))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Slider
                        VStack(spacing: 8) {
                            Slider(value: $rating, in: 0.5...5.0, step: 0.5)
                                .accentColor(.yellow)
                            
                            Text(ratingDescription)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ratingColor)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Rating Scale Reference - 简化版本，只显示当前评分对应的描述
                        if rating >= 4.5 {
                            Text("5.0 ★ Excellent — Highly valuable conversation")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        } else if rating >= 3.5 {
                            Text("4.0 ★ Good — Smooth and insightful")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        } else if rating >= 2.5 {
                            Text("3.0 ★ Fair — Average experience")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        } else if rating >= 1.5 {
                            Text("2.0 ★ Poor — Below expectations")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        } else if rating >= 0.5 {
                            Text("1.0 ★ Very Poor — Would not meet again")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // 🆕 评论框（替代标签）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why this rating? (Optional)")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Share your thoughts about this coffee chat experience.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $comment)
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: comment) { newValue in
                                // 限制评论长度（可选）
                                if newValue.count > 500 {
                                    comment = String(newValue.prefix(500))
                                }
                            }
                        
                        HStack {
                            Spacer()
                            Text("\(comment.count)/500")
                                .font(.system(size: 12))
                                .foregroundColor(comment.count > 500 ? .red : .gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Misconduct Report Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Serious Misconduct Report Section")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("If you experienced any of the following during your Coffee Chat, please report it immediately:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            misconductBullet("Violence, threats, or intimidation")
                            misconductBullet("Sexual harassment, inappropriate comments, or unwanted physical contact")
                            misconductBullet("Stalking or invasion of privacy")
                            misconductBullet("Fraud, impersonation, or coercive sales")
                            misconductBullet("Any other behavior that clearly violates professional conduct")
                        }
                        .font(.system(size: 13))
                        
                        Text("If verified by our Safety Team:")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• The user's score will be reset to 0.0")
                            Text("• Their account will be permanently banned")
                            Text("• Their profile will be removed from all matching pools")
                            Text("• You will not be matched or contacted by this user again")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        
                        Button(action: {
                            showReportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Report Serious Misconduct")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Submit Button
                    Button(action: submitRating) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Submit Rating")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.brown)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .disabled(isSubmitting)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showReportSheet) {
                MisconductReportView(
                    reportedUserId: otherUserId,
                    reportedUserName: otherUserName,
                    meetingId: meetingId
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func ratingReferenceRow(stars: String, description: String) -> some View {
        HStack(spacing: 8) {
            Text(stars)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            Text(description)
        }
    }
    
    private func tagSection(title: String, tags: [RatingTag], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        color: color,
                        action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func misconductBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
    
    // MARK: - Computed Properties
    
    private var ratingDescription: String {
        switch rating {
        case 4.6...5.0: return "Excellent — \(String(format: "%.1f", rating)) ★"
        case 3.6..<4.6: return "Good — \(String(format: "%.1f", rating)) ★"
        case 2.6..<3.6: return "Fair — \(String(format: "%.1f", rating)) ★"
        case 1.6..<2.6: return "Poor — \(String(format: "%.1f", rating)) ★"
        case 0.6..<1.6: return "Very Poor — \(String(format: "%.1f", rating)) ★"
        default: return "Unacceptable — \(String(format: "%.1f", rating)) ★"
        }
    }
    
    private var ratingColor: Color {
        switch rating {
        case 4.0...5.0: return .green
        case 3.0..<4.0: return .blue
        case 2.0..<3.0: return .orange
        default: return .red
        }
    }
    
    private var positiveTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .positive }
    }
    
    private var neutralTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .neutral }
    }
    
    private var negativeTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .negative }
    }
    
    // MARK: - Actions
    
    private func submitRating() {
        guard let currentUserId = authManager.currentUser?.id else {
            print("❌ [评分] 当前用户为空，无法提交评分")
            return
        }
        
        isSubmitting = true
        
        print("📝 [评分] ========== 开始提交评分 ==========")
        print("📝 [评分] meetingId: \(meetingId)")
        print("📝 [评分] raterId: \(currentUserId)")
        print("📝 [评分] ratedUserId: \(otherUserId)")
        print("📝 [评分] rating: \(rating)")
        print("📝 [评分] comment: \(comment.isEmpty ? "(无评论)" : comment)")
        print("📝 [评分] tags: \(selectedTags.map { $0.rawValue })")
        
        Task {
            do {
                // 1. 先查询 meeting 信息，确定当前用户是 user_id 还是 participant_id
                print("🔍 [评分] 步骤1: 查询 meeting 信息...")
                let meetingResponse = try await supabaseService.supabase
                    .from("coffee_chat_schedules")
                    .select("user_id, participant_id")
                    .eq("id", value: meetingId)
                    .single()
                    .execute()
                
                print("✅ [评分] meeting 查询成功，状态码: \(meetingResponse.response.statusCode)")
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                struct MeetingInfo: Codable {
                    let userId: String
                    let participantId: String
                }
                let meetingInfo = try decoder.decode(MeetingInfo.self, from: meetingResponse.data)
                
                let isCurrentUserOwner = meetingInfo.userId == currentUserId
                let ratingIdField = isCurrentUserOwner ? "user_rating_id" : "participant_rating_id"
                let ratedField = isCurrentUserOwner ? "user_rated" : "participant_rated"
                
                print("📝 [评分] 当前用户是 \(isCurrentUserOwner ? "user_id" : "participant_id")")
                
                // 2. 准备评分数据
                print("🔍 [评分] 步骤2: 准备评分数据...")
                let tagsArray = Array(selectedTags)
                
                // 创建符合 Encodable 的结构体
                struct MeetingRatingInsert: Encodable {
                    let meetingId: String
                    let raterId: String
                    let ratedUserId: String
                    let rating: Double
                    let tags: [RatingTag]
                    let comment: String?
                    let gpsVerified: Bool
                    let meetingDuration: Int
                    
                    enum CodingKeys: String, CodingKey {
                        case meetingId = "meeting_id"
                        case raterId = "rater_id"
                        case ratedUserId = "rated_user_id"
                        case rating
                        case tags
                        case comment
                        case gpsVerified = "gps_verified"
                        case meetingDuration = "meeting_duration"
                    }
                }
                
                // 确保 UUID 格式为小写（数据库通常存储为小写）
                let ratingInsert = MeetingRatingInsert(
                    meetingId: meetingId.lowercased(),
                    raterId: currentUserId.lowercased(),
                    ratedUserId: otherUserId.lowercased(),
                    rating: rating,
                    tags: tagsArray,
                    comment: comment.isEmpty ? nil : comment,
                    gpsVerified: true,
                    meetingDuration: 0
                )
                
                print("📝 [评分] 准备插入的数据: meetingId=\(meetingId), rating=\(rating), tags=\(tagsArray.count)个")
                
                // 3. 插入评分记录
                print("🔍 [评分] 步骤3: 插入评分记录到 meeting_ratings 表...")
                let ratingResponse = try await supabaseService.supabase
                    .from("meeting_ratings")
                    .insert(ratingInsert)
                    .select("id")
                    .single()
                    .execute()
                
                print("✅ [评分] 插入成功，状态码: \(ratingResponse.response.statusCode)")
                print("📊 [评分] 响应数据: \(String(data: ratingResponse.data, encoding: .utf8) ?? "无法解析")")
                
                let ratingIdData = try decoder.decode([String: String].self, from: ratingResponse.data)
                let ratingId = ratingIdData["id"] ?? ""
                
                print("✅ [评分] 评分记录已保存到数据库，rating_id: \(ratingId)")
                
                // 4. 更新 coffee_chat_schedules 表的评分状态
                print("🔍 [评分] 步骤4: 更新 coffee_chat_schedules 表...")
                
                // 创建符合 Encodable 的更新结构体
                struct ScheduleUpdate: Encodable {
                    let userRated: Bool?
                    let participantRated: Bool?
                    let userRatingId: String?
                    let participantRatingId: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case userRated = "user_rated"
                        case participantRated = "participant_rated"
                        case userRatingId = "user_rating_id"
                        case participantRatingId = "participant_rating_id"
                    }
                }
                
                // 根据当前用户角色构建更新数据
                let scheduleUpdate: ScheduleUpdate
                if isCurrentUserOwner {
                    scheduleUpdate = ScheduleUpdate(
                        userRated: true,
                        participantRated: nil,
                        userRatingId: ratingId.isEmpty ? nil : ratingId,
                        participantRatingId: nil
                    )
                } else {
                    scheduleUpdate = ScheduleUpdate(
                        userRated: nil,
                        participantRated: true,
                        userRatingId: nil,
                        participantRatingId: ratingId.isEmpty ? nil : ratingId
                    )
                }
                
                print("📝 [评分] 更新数据: \(isCurrentUserOwner ? "user_rated" : "participant_rated") = true, rating_id = \(ratingId)")
                
                let updateResponse = try await supabaseService.supabase
                    .from("coffee_chat_schedules")
                    .update(scheduleUpdate)
                    .eq("id", value: meetingId)
                    .execute()
                
                print("✅ [评分] coffee_chat_schedules 更新成功，状态码: \(updateResponse.response.statusCode)")
                
                // 5. 更新被评分用户的信誉评分
                print("🔍 [评分] 步骤5: 触发信誉评分重新计算...")
                do {
                    let rpcResponse = try await supabaseService.supabase
                        .rpc("calculate_credibility_score", params: ["p_user_id": otherUserId.lowercased()])
                        .execute()
                    print("✅ [评分] 已触发信誉评分重新计算，状态码: \(rpcResponse.response.statusCode)")
                    
                    // 验证评分是否更新
                    if let updatedScore = try? await supabaseService.getCredibilityScore(userId: otherUserId) {
                        print("✅ [评分] 验证更新后的评分:")
                        print("   - average_rating: \(updatedScore.averageRating)")
                        print("   - overall_score: \(updatedScore.overallScore)")
                    } else {
                        print("⚠️ [评分] 无法验证更新后的评分")
                    }
                } catch {
                    print("❌ [评分] 触发信誉评分重新计算失败: \(error.localizedDescription)")
                    print("❌ [评分] 错误详情: \(error)")
                }
                
                // 6. 清除缓存并发送通知，让其他界面刷新评分
                print("🔍 [评分] 步骤6: 清除缓存并发送刷新评分通知...")
                CredibilityScoreCache.shared.invalidateScore(for: otherUserId)
                NotificationCenter.default.post(
                    name: NSNotification.Name("CredibilityScoreUpdated"),
                    object: nil,
                    userInfo: ["userId": otherUserId]
                )
                print("✅ [评分] 已清除缓存并发送刷新评分通知")
                
                print("✅ [评分] ========== 评分提交完成 ==========")
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                print("❌ [评分] ========== 提交失败 ==========")
                print("❌ [评分] 错误类型: \(type(of: error))")
                print("❌ [评分] 错误描述: \(error.localizedDescription)")
                
                // 尝试获取更详细的错误信息
                if let nsError = error as NSError? {
                    print("❌ [评分] 错误代码: \(nsError.code)")
                    print("❌ [评分] 错误域: \(nsError.domain)")
                    print("❌ [评分] 用户信息: \(nsError.userInfo)")
                }
                
                // 打印完整的错误信息
                print("❌ [评分] 完整错误: \(error)")
                
                // 如果是 URL 错误，尝试获取更多信息
                if let urlError = error as? URLError {
                    print("❌ [评分] URL 错误代码: \(urlError.code.rawValue)")
                    print("❌ [评分] URL 错误描述: \(urlError.localizedDescription)")
                }
                
                await MainActor.run {
                    isSubmitting = false
                    // 即使失败也关闭界面，避免用户卡住
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: RatingTag
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.rawValue)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? color : .gray)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Preview

struct MeetingRatingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingRatingView(
            meetingId: "meeting123",
            otherUserId: "user456",
            otherUserName: "John Doe"
        )
    }
}

