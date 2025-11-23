import SwiftUI

// MARK: - Talent Scout Main View
struct ExploreMainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    private let recommendationService = RecommendationService.shared
    private let queryParser = QueryParser.shared
    private let fieldAwareScoring = FieldAwareScoring()
    private let placeholderText = "alumni, works at a top tech company, three years of experience, open to mentoring"
    
    @State private var descriptionText: String = ""
    @State private var recommendedProfiles: [BrewNetProfile] = []
    @State private var selectedProfile: BrewNetProfile?
    @State private var engagedProfileIds: Set<String> = []
    @State private var proUserIds: Set<String> = []
    @State private var verifiedUserIds: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var showingTemporaryChat = false
    @State private var selectedProfileForChat: BrewNetProfile?
    @State private var showSubscriptionPayment = false
    @State private var showingInviteLimitAlert = false
    @State private var currentUserProfile: BrewNetProfile? = nil
    @FocusState private var textEditorFocused: Bool
    @State private var showHeaderAnimation = false
    @State private var showResults = false
    
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        descriptionSection
                        inputSection
                        actionButton
                        statusSection
                        resultsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedProfile) { profile in
            TalentScoutProfileCardSheet(
                profile: profile,
                isPro: proUserIds.contains(profile.userId),
                isVerifiedOverride: verifiedUserIds.contains(profile.userId) ? true : nil,
                onDismiss: {
                    selectedProfile = nil
                },
                onTemporaryChat: { profile in
                    Task {
                        await handleTemporaryChatAction(profile: profile)
                    }
                },
                onRequestConnect: { profile in
                    Task {
                        await handleCoffeeChatConnect(profile: profile)
                    }
                },
                shouldShowActions: !engagedProfileIds.contains(profile.userId),
                hasEngaged: engagedProfileIds.contains(profile.userId)
            )
            .environmentObject(authManager)
            .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showingTemporaryChat) {
            if let profile = selectedProfileForChat {
                TemporaryChatFromProfileView(
                    profile: profile,
                    onDismiss: {
                        showingTemporaryChat = false
                        selectedProfileForChat = nil
                    },
                    onSend: { message in
                        handleTemporaryChatSend(message: message, profile: profile)
                    }
                )
                .environmentObject(authManager)
                .environmentObject(supabaseService)
            }
        }
        .sheet(isPresented: $showSubscriptionPayment) {
            if let userId = authManager.currentUser?.id {
                SubscriptionPaymentView(currentUserId: userId) {
                    Task {
                        await authManager.refreshUser()
                    }
                }
            }
        }
        .alert("No Connects Left", isPresented: $showingInviteLimitAlert) {
            Button("Subscribe to Pro") {
                showingInviteLimitAlert = false
                showSubscriptionPayment = true
            }
            Button("Cancel", role: .cancel) {
                showingInviteLimitAlert = false
            }
        } message: {
            Text("You've used all 10 connects for today. Upgrade to BrewNet Pro for unlimited connections and more exclusive features.")
        }
    }
    
    // MARK: - Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(themeColor)
                    .modifier(PulseAnimationModifier())
                
                Text("Talent Scout")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(themeColor)
            }
        }
        .opacity(showHeaderAnimation ? 1 : 0)
        .scaleEffect(showHeaderAnimation ? 1 : 0.8)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showHeaderAnimation)
        .onAppear {
            withAnimation {
                showHeaderAnimation = true
            }
        }
    }
    
    private var descriptionSection: some View {
        Text("Describe who you want to connect with, and we'll scout the perfect talent for you!")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(themeColor)
            .opacity(showHeaderAnimation ? 1 : 0)
            .offset(y: showHeaderAnimation ? 0 : 10)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showHeaderAnimation)
    }
    
    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(textEditorFocused ? themeColor.opacity(0.7) : Color.gray.opacity(0.2), lineWidth: textEditorFocused ? 2 : 1.5)
                )
                .shadow(color: textEditorFocused ? themeColor.opacity(0.2) : Color.black.opacity(0.05), radius: textEditorFocused ? 12 : 8, x: 0, y: 4)
                .scaleEffect(textEditorFocused ? 1.01 : 1.0)
            
            TextEditor(text: $descriptionText)
                .focused($textEditorFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .font(.system(size: 16))
            
            if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholderText)
                    .font(.system(size: 15))
                    .foregroundColor(Color.gray.opacity(0.6))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: textEditorFocused)
        .opacity(showHeaderAnimation ? 1 : 0)
        .offset(y: showHeaderAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: showHeaderAnimation)
    }
    
    private var actionButton: some View {
        Button(action: {
            // 添加触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            runTalentScoutSearch()
        }) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                        .modifier(PulseAnimationModifier())
                }
                Text(isLoading ? "Scouting..." : "Start Scouting")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(
                Group {
                    if isLoading {
                        LinearGradient(
                            gradient: Gradient(colors: [themeColor, themeColor.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        isSearchDisabled ? Color.gray : themeColor
                    }
                }
            )
            .cornerRadius(16)
            .shadow(color: isSearchDisabled ? Color.clear : themeColor.opacity(0.3), radius: isLoading ? 8 : 4, x: 0, y: 4)
            .scaleEffect(isLoading ? 0.98 : 1.0)
        }
        .disabled(isSearchDisabled)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLoading)
        .opacity(showHeaderAnimation ? 1 : 0)
        .offset(y: showHeaderAnimation ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showHeaderAnimation)
    }
    
    private var statusSection: some View {
        Group {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                        .scaleEffect(1.1)
                    Text("Scanning BrewNet profiles for the best matches...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let errorMessage = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .modifier(ShakeAnimationModifier())
                    Text(errorMessage)
                        .font(.system(size: 15))
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale))
            } else if hasSearched && recommendedProfiles.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(themeColor)
                        .modifier(PulseAnimationModifier())
                    Text("No perfect fits yet. Try tweaking the description or include more details like company, industry, or seniority.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasSearched)
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !recommendedProfiles.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeColor)
                        .modifier(PulseAnimationModifier())
                    
                    Text("Top 5 matches")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeColor)
                }
                .opacity(showResults ? 1 : 0)
                .offset(x: showResults ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: showResults)
                
                ForEach(Array(recommendedProfiles.enumerated()), id: \.element.id) { entry in
                    let profile = entry.element
                    TalentScoutResultCard(
                        profile: profile,
                        rank: entry.offset + 1,
                        isEngaged: engagedProfileIds.contains(profile.userId),
                        onTap: {
                            selectedProfile = profile
                        }
                    )
                    .opacity(showResults ? 1 : 0)
                    .offset(y: showResults ? 0 : 30)
                    .scaleEffect(showResults ? 1 : 0.9)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.75)
                        .delay(Double(entry.offset) * 0.1 + 0.2),
                        value: showResults
                    )
                }
            }
        }
        .padding(.top, recommendedProfiles.isEmpty ? 0 : 8)
        .onChange(of: recommendedProfiles.isEmpty) { isEmpty in
            if !isEmpty {
                withAnimation {
                    showResults = true
                }
            } else {
                showResults = false
            }
        }
    }
    
    private var isSearchDisabled: Bool {
        descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
    }
    
    // MARK: - Actions
    private func runTalentScoutSearch() {
        let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            errorMessage = "Please describe the person you're hoping to meet."
            return
        }
        
        guard let currentUser = authManager.currentUser else {
            errorMessage = "Please sign in again to run a search."
            return
        }
        
        isLoading = true
        errorMessage = nil
        hasSearched = true
        textEditorFocused = false
        
        Task {
            let searchStart = Date()
            
            do {
                // 获取当前用户的 profile（用于校友匹配）
                if currentUserProfile == nil {
                    if let supabaseProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                        await MainActor.run {
                            currentUserProfile = supabaseProfile.toBrewNetProfile()
                        }
                    }
                }
                
                // ===== V2.0: NLP 增强 =====
                // 1. 解析查询
                let parsedQuery = queryParser.parse(trimmed)
                print("\n📊 Query Analysis:")
                print("  - Difficulty: \(parsedQuery.difficulty)")
                print("  - Summary: \(parsedQuery.summary)")
                
                // 2. 获取推荐候选池（扩大到100人）
                let step1 = Date()
                let recommendations = try await recommendationService.getRecommendations(
                    for: currentUser.id,
                    limit: 100,  // V2.0: 从60扩大到100
                    forceRefresh: true
                )
                print("  ⏱️  Recall: \(Date().timeIntervalSince(step1) * 1000)ms")
                
                // 3. V2.0 升级的排序逻辑
                let step2 = Date()
                let ranked = rankRecommendationsV2(
                    recommendations, 
                    parsedQuery: parsedQuery,
                    currentUserProfile: currentUserProfile
                )
                print("  ⏱️  Ranking: \(Date().timeIntervalSince(step2) * 1000)ms")
                
                let topProfiles = Array(ranked.prefix(5))
                let topIds = topProfiles.map { $0.userId }
                
                var fetchedProIds = Set<String>()
                var fetchedVerifiedIds = Set<String>()
                
                do {
                    fetchedProIds = try await supabaseService.getProUserIds(from: topIds)
                } catch {
                    print("⚠️ Talent Scout: failed to fetch Pro statuses: \(error.localizedDescription)")
                }
                
                do {
                    fetchedVerifiedIds = try await supabaseService.getVerifiedUserIds(from: topIds)
                } catch {
                    print("⚠️ Talent Scout: failed to fetch verification statuses: \(error.localizedDescription)")
                }
                
                print("  ⏱️  Total time: \(Date().timeIntervalSince(searchStart) * 1000)ms")
                print("  ✅ Top 5 selected from \(recommendations.count) candidates\n")
                
                await MainActor.run {
                    self.recommendedProfiles = topProfiles
                    // 触发结果动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            self.showResults = true
                        }
                    }
                    self.proUserIds = fetchedProIds
                    self.verifiedUserIds = fetchedVerifiedIds
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.recommendedProfiles = []
                    self.showResults = false
                    self.errorMessage = "Unable to complete the talent scout request. Please try again shortly."
                    print("❌ Talent Scout search failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Ranking Logic V2.0
    
    /// V2.0 升级版排序逻辑（使用NLP增强）
    private func rankRecommendationsV2(
        _ recommendations: [(userId: String, score: Double, profile: BrewNetProfile)],
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?
    ) -> [BrewNetProfile] {
        
        guard !parsedQuery.tokens.isEmpty else {
            return recommendations.map { $0.profile }
        }
        
        // 动态权重调整
        let weights = DynamicWeighting.adjustWeights(
            for: parsedQuery.rawText,
            parsedQuery: parsedQuery
        )
        
        // 查询的概念标签
        let queryConceptTags = ConceptTagger.mapQueryToConcepts(query: parsedQuery.rawText)
        
        let ranked = recommendations.map { item -> (profile: BrewNetProfile, score: Double) in
            print("\n👤 Scoring: \(item.profile.coreIdentity.name)")
            
            // V2.0 升级的匹配分数
            let matchScore = computeMatchScoreV2(
                for: item.profile,
                parsedQuery: parsedQuery,
                currentUserProfile: currentUserProfile,
                queryConceptTags: queryConceptTags
            )
            
            // 动态权重混合
            let blendedScore = (item.score * weights.recommendation) + (matchScore * weights.textMatch)
            
            print("  📊 Final: Rec(\(String(format: "%.2f", item.score))×\(String(format: "%.1f", weights.recommendation))) + Match(\(String(format: "%.2f", matchScore))×\(String(format: "%.1f", weights.textMatch))) = \(String(format: "%.2f", blendedScore))")
            
            return (profile: item.profile, score: blendedScore)
        }
        
        return ranked
            .sorted { $0.score > $1.score }
            .map { $0.profile }
    }
    
    /// V1.0 原始排序逻辑（保留作为备用）
    private func rankRecommendations(
        _ recommendations: [(userId: String, score: Double, profile: BrewNetProfile)],
        query: String,
        currentUserProfile: BrewNetProfile?
    ) -> [BrewNetProfile] {
        let tokens = tokenize(query)
        let numbers = extractNumbers(from: query)
        
        guard !tokens.isEmpty else {
            return recommendations.map { $0.profile }
        }
        
        let ranked = recommendations.map { item -> (profile: BrewNetProfile, score: Double) in
            let matchScore = computeMatchScore(for: item.profile, tokens: tokens, numbers: numbers, currentUserProfile: currentUserProfile)
            let blendedScore = (item.score * 0.3) + matchScore
            return (profile: item.profile, score: blendedScore)
        }
        
        return ranked
            .sorted { $0.score > $1.score }
            .map { $0.profile }
    }
    
    // MARK: - Match Scoring V2.0
    
    /// V2.0 升级版匹配分数计算
    private func computeMatchScoreV2(
        for profile: BrewNetProfile,
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?,
        queryConceptTags: Set<ConceptTag>
    ) -> Double {
        var score: Double = 0.0
        
        // 1. 字段感知评分（替代简单的关键词匹配）
        let fieldScore = fieldAwareScoring.computeScore(
            profile: profile,
            tokens: parsedQuery.tokens
        )
        score += fieldScore
        
        // 2. 实体匹配评分（精确匹配公司、职位、学校等）
        let entityScore = fieldAwareScoring.computeEntityScore(
            profile: profile,
            entities: parsedQuery.entities
        )
        score += entityScore
        
        // 3. 概念标签匹配
        let profileConceptTags = profile.conceptTags
        let conceptScore = ConceptTagger.scoreConceptMatch(
            profileTags: profileConceptTags,
            queryTags: queryConceptTags
        )
        score += conceptScore
        
        // 4. 软年限匹配（使用高斯衰减）
        if !parsedQuery.entities.numbers.isEmpty {
            let expScore = SoftMatching.softExperienceMatch(
                profile: profile,
                targetYears: parsedQuery.entities.numbers
            )
            score += expScore
        }
        
        // 5. Mentor/Mentoring 意图匹配
        if parsedQuery.tokens.contains(where: { $0.contains("mentor") || $0.contains("mentoring") }) {
            if profile.networkingIntention.selectedIntention == .learnGrow ||
                profile.networkingIntention.selectedSubIntentions.contains(.skillDevelopment) ||
                profile.networkingIntention.selectedSubIntentions.contains(.careerDirection) {
                score += 1.5
                print("  ✓ Mentor intention match (+1.5)")
            }
        }
        
        // 6. 校友匹配（增强版）
        if parsedQuery.tokens.contains(where: { $0.contains("alum") }) {
            let alumniScore = computeAlumniScore(
                profile: profile,
                parsedQuery: parsedQuery,
                currentUserProfile: currentUserProfile
            )
            score += alumniScore
        }
        
        // 7. Founder/Startup 匹配
        if parsedQuery.tokens.contains(where: { $0.contains("founder") || $0.contains("startup") || $0.contains("entrepreneur") }) {
            if profile.professionalBackground.careerStage == .founder ||
                profile.networkingIntention.selectedIntention == .buildCollaborate {
                score += 1.0
                print("  ✓ Founder/Startup match (+1.0)")
            }
        }
        
        // 8. 否定词处理（降权）
        for negation in parsedQuery.modifiers.negations {
            let zonedText = ZonedSearchableText.from(profile: profile)
            let allText = [zonedText.zoneA, zonedText.zoneB, zonedText.zoneC].joined(separator: " ")
            if allText.contains(negation) {
                score -= 2.0
                print("  ⚠️ Negation match: '\(negation)' (-2.0)")
            }
        }
        
        return max(0.0, score)  // 确保分数不为负
    }
    
    /// V1.0 原始匹配分数计算（保留作为备用）
    private func computeMatchScore(
        for profile: BrewNetProfile,
        tokens: [String],
        numbers: [Double],
        currentUserProfile: BrewNetProfile?
    ) -> Double {
        var score: Double = 0.0
        let searchableText = aggregatedSearchableText(for: profile)
        let tokenSet = Set(tokens)
        
        for token in tokenSet {
            if token.count < 2 { continue }
            if searchableText.contains(token) {
                score += 1.0
            }
        }
        
        if let years = profile.professionalBackground.yearsOfExperience {
            for target in numbers {
                if abs(years - target) <= 1.0 {
                    score += 2.0
                }
            }
        }
        
        if tokenSet.contains(where: { $0.contains("mentor") || $0.contains("mentoring") }) {
            if profile.networkingIntention.selectedIntention == .learnGrow ||
                profile.networkingIntention.selectedSubIntentions.contains(.skillDevelopment) ||
                profile.networkingIntention.selectedSubIntentions.contains(.careerDirection) {
                score += 1.5
            }
        }
        
        // 校友匹配逻辑：如果查询包含 alumni/alum 相关词汇
        if tokenSet.contains(where: { $0.contains("alum") }) {
            // 基础分：有教育经历的用户
            if let educations = profile.professionalBackground.educations, !educations.isEmpty {
                score += 1.0
            } else if profile.professionalBackground.education != nil {
                score += 0.5
            }
            
            // 校友加分：如果与当前用户来自同一所学校
            if let currentUserProfile = currentUserProfile,
               let currentUserEducations = currentUserProfile.professionalBackground.educations,
               !currentUserEducations.isEmpty,
               let targetEducations = profile.professionalBackground.educations,
               !targetEducations.isEmpty {
                
                // 提取当前用户的学校名称集合（转为小写便于比较）
                let currentUserSchools = Set(currentUserEducations.map { $0.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
                
                // 检查目标用户是否有匹配的学校
                for targetEducation in targetEducations {
                    let targetSchool = targetEducation.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if currentUserSchools.contains(targetSchool) {
                        // 校友匹配！给予高额加分
                        score += 5.0
                        print("🎓 Alumni match found! School: \(targetEducation.schoolName)")
                        break // 只要找到一个匹配的学校即可
                    }
                }
            }
        }
        
        if tokenSet.contains("founder") || tokenSet.contains("startup") {
            if profile.professionalBackground.careerStage == .founder ||
                profile.networkingIntention.selectedIntention == .buildCollaborate {
                score += 1.0
            }
        }
        
        return score
    }
    
    private func aggregatedSearchableText(for profile: BrewNetProfile) -> String {
        var parts: [String] = [
            profile.coreIdentity.name,
            profile.coreIdentity.bio ?? "",
            profile.coreIdentity.location ?? "",
            profile.professionalBackground.currentCompany ?? "",
            profile.professionalBackground.jobTitle ?? "",
            profile.professionalBackground.industry ?? "",
            profile.professionalBackground.education ?? "",
            profile.personalitySocial.selfIntroduction ?? ""
        ]
        
        parts.append(contentsOf: profile.professionalBackground.skills)
        parts.append(contentsOf: profile.professionalBackground.certifications)
        parts.append(contentsOf: profile.professionalBackground.languagesSpoken)
        parts.append(contentsOf: profile.personalitySocial.valuesTags)
        parts.append(contentsOf: profile.personalitySocial.hobbies)
        
        if let educations = profile.professionalBackground.educations {
            for education in educations {
                parts.append(education.schoolName)
                if let field = education.fieldOfStudy {
                    parts.append(field)
                }
                parts.append(education.degree.displayName)
            }
        }
        
        for experience in profile.professionalBackground.workExperiences {
            parts.append(experience.companyName)
            if let role = experience.position {
                parts.append(role)
            }
            parts.append(contentsOf: experience.highlightedSkills)
            if let responsibilities = experience.responsibilities {
                parts.append(responsibilities)
            }
        }
        
        return parts
            .joined(separator: " ")
            .lowercased()
    }
    
    // MARK: - 校友匹配增强
    
    /// 增强版校友匹配（支持精确和模糊匹配）
    private func computeAlumniScore(
        profile: BrewNetProfile,
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?
    ) -> Double {
        var score: Double = 0.0
        
        // 基础分：有教育经历的用户
        if let educations = profile.professionalBackground.educations, !educations.isEmpty {
            score += 1.0
        } else if profile.professionalBackground.education != nil {
            score += 0.5
        }
        
        // 校友加分：与当前用户同校
        if let currentUserProfile = currentUserProfile,
           let currentUserEducations = currentUserProfile.professionalBackground.educations,
           !currentUserEducations.isEmpty,
           let targetEducations = profile.professionalBackground.educations,
           !targetEducations.isEmpty {
            
            // 提取当前用户的学校名称集合
            let currentUserSchools = Set(currentUserEducations.map { 
                $0.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) 
            })
            
            // 检查是否同校（精确匹配）
            for targetEducation in targetEducations {
                let targetSchool = targetEducation.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                if currentUserSchools.contains(targetSchool) {
                    // 精确同校匹配
                    score += 5.0
                    print("  🎓 Alumni match (exact): \(targetEducation.schoolName) (+5.0)")
                    break
                } else {
                    // 模糊匹配（处理 "Stanford" vs "Stanford University"）
                    for currentSchool in currentUserSchools {
                        let similarity = SoftMatching.fuzzySimilarity(
                            string1: currentSchool,
                            string2: targetSchool
                        )
                        if similarity > 0.8 {
                            score += 4.0
                            print("  🎓 Alumni match (fuzzy): \(targetEducation.schoolName) ≈ \(currentSchool) (+4.0)")
                            break
                        }
                    }
                }
            }
        }
        
        // 查询中指定学校（无需当前用户也是校友）
        if !parsedQuery.entities.schools.isEmpty {
            if let targetEducations = profile.professionalBackground.educations {
                for targetEducation in targetEducations {
                    let targetSchool = targetEducation.schoolName.lowercased()
                    for querySchool in parsedQuery.entities.schools {
                        if targetSchool.contains(querySchool) || querySchool.contains(targetSchool) {
                            score += 2.0
                            print("  🎓 School match: \(querySchool) (+2.0)")
                            break
                        }
                    }
                }
            }
        }
        
        return score
    }
    
    // MARK: - Legacy Functions (V1.0)
    
    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
    
    private func extractNumbers(from text: String) -> [Double] {
        let components = text.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted)
        return components.compactMap { Double($0) }
    }
    
    private func handleTemporaryChatSend(message: String, profile: BrewNetProfile) {
        guard let currentUser = authManager.currentUser else { return }
        
        showingTemporaryChat = false
        selectedProfileForChat = nil
        
        Task {
            do {
                let canInvite = try await supabaseService.decrementUserLikes(userId: currentUser.id)
                if !canInvite {
                    await MainActor.run {
                        showingInviteLimitAlert = true
                    }
                    return
                }
                
                _ = try await supabaseService.sendMessage(
                    senderId: currentUser.id,
                    receiverId: profile.userId,
                    content: message,
                    messageType: "temporary"
                )
                
                var senderProfile: InvitationProfile? = nil
                if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let brewNetProfile = supabaseProfile.toBrewNetProfile()
                    senderProfile = brewNetProfile.toInvitationProfile()
                }
                
                _ = try await supabaseService.sendInvitation(
                    senderId: currentUser.id,
                    receiverId: profile.userId,
                    reasonForInterest: nil,
                    senderProfile: senderProfile
                )
                
                await recommendationService.recordLike(
                    userId: currentUser.id,
                    targetUserId: profile.userId
                )
                
                await MainActor.run {
                    engagedProfileIds.insert(profile.userId)
                }
            } catch {
                print("❌ Talent Scout: failed to send temporary message: \(error.localizedDescription)")
            }
        }
    }
    
    private func openTemporaryChat(profile: BrewNetProfile) {
        guard let currentUser = authManager.currentUser else { return }
        
        Task {
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                await MainActor.run {
                    if canChat {
                        selectedProfileForChat = profile
                        showingTemporaryChat = true
                    } else {
                        showSubscriptionPayment = true
                    }
                }
            } catch {
                print("❌ Talent Scout: failed to check temporary chat eligibility: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleCoffeeChatConnect(profile: BrewNetProfile) async {
        guard let currentUser = authManager.currentUser else { return }
        do {
            let canInvite = try await supabaseService.decrementUserLikes(userId: currentUser.id)
            if !canInvite {
                await MainActor.run {
                    showingInviteLimitAlert = true
                }
                return
            }
            
            var senderProfile: InvitationProfile? = nil
            if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                let brewNetProfile = supabaseProfile.toBrewNetProfile()
                senderProfile = brewNetProfile.toInvitationProfile()
            }
            
            _ = try await supabaseService.sendInvitation(
                senderId: currentUser.id,
                receiverId: profile.userId,
                reasonForInterest: "Talent Scout coffee chat",
                senderProfile: senderProfile
            )
            
            await MainActor.run {
                engagedProfileIds.insert(profile.userId)
            }
        } catch {
            print("❌ Talent Scout: failed to send coffee chat connect request: \(error.localizedDescription)")
        }
    }
    
    private func handleTemporaryChatAction(profile: BrewNetProfile) async {
        await MainActor.run {
            engagedProfileIds.insert(profile.userId)
        }
        openTemporaryChat(profile: profile)
    }
}

// MARK: - Result Card
struct TalentScoutResultCard: View {
    let profile: BrewNetProfile
    let rank: Int
    var isEngaged: Bool
    var onTap: (() -> Void)? = nil
    
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text("#\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(themeColor.opacity(0.1))
                        .cornerRadius(12)
                    
                    if isEngaged {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.green)
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                
                Spacer()
                
                Text(profile.professionalBackground.experienceLevel.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            HStack(alignment: .top, spacing: 16) {
                profileImage
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text(primaryHeadline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeColor)
                        .lineLimit(2)
                    
                    if let location = profile.coreIdentity.location, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text(location)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(3)
                    }
                }
            }
            
            if !skillsPreview.isEmpty {
                HStack {
                    ForEach(skillsPreview, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(themeColor.opacity(0.08))
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            onTap?()
        }
    }
    
    private var profileImage: some View {
        Group {
            if let urlString = profile.coreIdentity.profileImage,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 3)
    }
    
    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColor.opacity(0.15))
            Image(systemName: "person.crop.square")
                .font(.system(size: 24))
                .foregroundColor(themeColor)
        }
    }
    
    private var primaryHeadline: String {
        let job = profile.professionalBackground.jobTitle ?? ""
        let company = profile.professionalBackground.currentCompany ?? ""
        
        if !job.isEmpty && !company.isEmpty {
            return "\(job) · \(company)"
        } else if !job.isEmpty {
            return job
        } else if !company.isEmpty {
            return company
        } else {
            return profile.professionalBackground.industry ?? "Professional"
        }
    }
    
    private var skillsPreview: [String] {
        Array(profile.professionalBackground.skills.prefix(3))
    }
}

// MARK: - Preview
struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreMainView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

// MARK: - Profile Card Sheet
struct TalentScoutProfileCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let profile: BrewNetProfile
    let isPro: Bool
    let isVerifiedOverride: Bool?
    var onDismiss: () -> Void
    var onTemporaryChat: (BrewNetProfile) -> Void
    var onRequestConnect: (BrewNetProfile) -> Void
    var shouldShowActions: Bool
    var hasEngaged: Bool
    
    @State private var selectedWorkExperience: WorkExperience?
    
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                backgroundColor
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        UserProfileCardPreview(
                            profile: profile,
                            isPro: isPro,
                            isVerifiedOverride: isVerifiedOverride,
                            onWorkExperienceTap: { workExp in
                                selectedWorkExperience = workExp
                            }
                        )
                    }
                    .padding(.top, 24)
                    .padding(.bottom, shouldShowActions ? 120 : 40)
                }
                
                if shouldShowActions {
                    VStack {
                        Spacer()
                        actionButtons
                            .padding(.bottom, 24)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                }
            }
        }
        .sheet(item: $selectedWorkExperience) { workExp in
            WorkExperienceDetailSheet(
                workExperience: workExp,
                allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                industry: profile.professionalBackground.industry
            )
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: handleTemporaryChatTap) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .overlay(
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    )
            }
            
            Button(action: handleConnectTap) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .overlay(
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    )
            }
        }
        .padding(.horizontal, 32)
    }
    
    private func handleTemporaryChatTap() {
        onTemporaryChat(profile)
        dismiss()
        onDismiss()
    }
    
    private func handleConnectTap() {
        onRequestConnect(profile)
        dismiss()
        onDismiss()
    }
}

private struct UserProfileCardPreview: View {
    let profile: BrewNetProfile
    let isPro: Bool
    let isVerifiedOverride: Bool?
    var onWorkExperienceTap: ((WorkExperience) -> Void)?
    
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var credibilityScore: CredibilityScore?
    
    var body: some View {
        ProfileCardContentView(
            profile: profile,
            isConnection: false,
            isProUser: isPro,
            isVerified: isVerifiedOverride,
            currentUserLocation: nil,
            showDistance: false,
            credibilityScore: credibilityScore,
            onWorkExperienceTap: onWorkExperienceTap
        )
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 16)
        .onAppear {
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CredibilityScoreUpdated"))) { _ in
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadCredibilityScore()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedIn"))) { _ in
            loadCredibilityScore()
        }
    }
    
    private func loadCredibilityScore() {
        print("🔄 [TalentScoutProfileCard] 开始加载信誉评分，userId: \(profile.userId)")
        Task {
            do {
                // 尝试从缓存加载
                if let cachedScore = CredibilityScoreCache.shared.getScore(for: profile.userId) {
                    print("✅ [TalentScoutProfileCard] 从缓存加载信誉评分: \(cachedScore.averageRating)")
                    await MainActor.run {
                        credibilityScore = cachedScore
                    }
                    // 并在后台刷新缓存
                    Task { await refreshCredibilityScore(for: profile.userId) }
                    return
                }

                // 强制使用小写格式查询，确保与数据库一致
                if let score = try await supabaseService.getCredibilityScore(userId: profile.userId.lowercased()) {
                    print("✅ [TalentScoutProfileCard] 成功加载信誉评分: \(score.averageRating)")
                    await MainActor.run {
                        credibilityScore = score
                        CredibilityScoreCache.shared.setScore(score, for: profile.userId)
                    }
                } else {
                        print("⚠️ [TalentScoutProfileCard] 未找到评分记录，尝试使用原始 userId 查询...")
                    if let score = try? await supabaseService.getCredibilityScore(userId: profile.userId) {
                        print("✅ [TalentScoutProfileCard] 使用原始格式查询成功: \(score.averageRating)")
                        await MainActor.run {
                            credibilityScore = score
                            CredibilityScoreCache.shared.setScore(score, for: profile.userId)
                        }
                    } else {
                        print("⚠️ [TalentScoutProfileCard] 未找到评分记录，使用默认值")
                        await MainActor.run {
                            let defaultScore = CredibilityScore(userId: profile.userId)
                            credibilityScore = defaultScore
                            CredibilityScoreCache.shared.setScore(defaultScore, for: profile.userId)
                        }
                    }
                }
            } catch {
                print("❌ [TalentScoutProfileCard] 无法加载信誉评分: \(error.localizedDescription)")
                await MainActor.run {
                    let defaultScore = CredibilityScore(userId: profile.userId)
                    credibilityScore = defaultScore
                    CredibilityScoreCache.shared.setScore(defaultScore, for: profile.userId)
                }
            }
        }
    }
    
    private func refreshCredibilityScore(for userId: String) async {
        do {
            if let score = try await supabaseService.getCredibilityScore(userId: userId.lowercased()) {
                await MainActor.run {
                    credibilityScore = score
                    CredibilityScoreCache.shared.setScore(score, for: userId)
                }
            }
        } catch {
            print("⚠️ [TalentScoutProfileCard] 刷新信誉评分失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Animation Modifiers for iOS Compatibility
struct PulseAnimationModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .opacity(isAnimating ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

struct ShakeAnimationModifier: ViewModifier {
    @State private var isShaking = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: isShaking ? -5 : 5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
                    isShaking = true
                }
            }
    }
}