import Foundation

// MARK: - Scout Search Engine
//
// Talent Scout 搜索管线的单一事实源(从 ExploreView 提取,2026-07):
//   召回(双塔) → 存在性校验 → V2 规则排序(NLP 字段/实体/概念/校友/意图)
//   → V3 LLM 互惠精排(失败退回规则序) → top-3 + 证据式理由
// 供 ExploreMainView(表单搜索)与 BrewAgent(对话式 agent)共用。
// ⚠️ 排序逻辑从 ExploreView 原样移入,调优行为保持不变。

final class ScoutSearchEngine {

    static let shared = ScoutSearchEngine()
    private init() {}

    private let recommendationService = RecommendationService.shared
    private let queryParser = QueryParser.shared
    private let fieldAwareScoring = FieldAwareScoring()
    private let supabaseService = SupabaseService.shared

    // MARK: - Public API

    struct SearchOutcome {
        // matchPercent: LLM 互惠分(fit×accept, 0-100);规则排序路径为 nil
        let top: [(profile: BrewNetProfile, reasons: [String], matchPercent: Int?)]
        let llmRerankApplied: Bool
    }

    /// 完整搜索流程。progress 回调:(进度 0-1, 加载消息索引)
    func search(
        query: String,
        currentUserId: String,
        currentUserProfile: BrewNetProfile?,
        topCount: Int = 3,
        excludeNames: Set<String> = [],   // 🧠 agent 记忆:已邀请/已拒绝的人不再推荐
        progress: (@MainActor (Double, Int) -> Void)? = nil
    ) async throws -> SearchOutcome {
        let searchStart = Date()

        // 1. 解析查询
        await progress?(0.2, 1)
        let parsedQuery = queryParser.parse(query)
        print("\n📊 Query Analysis:")
        print("  - Difficulty: \(parsedQuery.difficulty)")
        print("  - Summary: \(parsedQuery.summary)")

        // 2. 召回候选池
        await progress?(0.4, 2)
        let step1 = Date()
        let recommendations = try await recommendationService.getRecommendations(
            for: currentUserId,
            limit: 100,
            forceRefresh: true
        )
        print("  ⏱️  Recall: \(Date().timeIntervalSince(step1) * 1000)ms")

        // 3. 校验用户存在性
        await progress?(0.6, 3)
        let step1_5 = Date()
        let validRecommendations = await validateRecommendations(recommendations)
        print("  ⏱️  Validation: \(Date().timeIntervalSince(step1_5) * 1000)ms (filtered \(recommendations.count - validRecommendations.count) deleted users)")

        // 3.5 🎰 曝光感知(Match v4):查近 14 天各候选被推次数
        // 依据:探索给欠曝光者机会同时提升整体质量(Meta epinet, WebConf'25);
        // 曝光集中会伤害双边留存(MRet, ICLR 2026)
        let exposureCounts = await fetchExposureCounts(
            candidateIds: validRecommendations.map { $0.userId }
        )

        // 4. V2 规则排序(含曝光调整)
        await progress?(0.8, 4)
        let step2 = Date()
        var ranked = rankRecommendationsV2(
            validRecommendations,
            parsedQuery: parsedQuery,
            currentUserProfile: currentUserProfile,
            exposureCounts: exposureCounts
        )
        if !excludeNames.isEmpty {
            let before = ranked.count
            ranked = ranked.filter { !excludeNames.contains($0.profile.coreIdentity.name) }
            print("  🧠 Memory exclude: filtered \(before - ranked.count) already-engaged people")
        }
        print("  ⏱️  Ranking: \(Date().timeIntervalSince(step2) * 1000)ms")

        // 5. V3 LLM 互惠精排(失败无缝退回规则序)
        await progress?(0.85, 4)
        let llmPool = Array(ranked.prefix(LLMRerankService.maxCandidates))
        var topEntries: [(profile: BrewNetProfile, reasons: [String], matchPercent: Int?)]
        var llmApplied = false

        if let llmResults = await LLMRerankService.shared.rerank(
            query: query,
            candidates: llmPool.map { $0.profile },
            requesterProfile: currentUserProfile
        ) {
            let entryById = Dictionary(
                llmPool.map { ($0.profile.userId, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            topEntries = llmResults.prefix(topCount).compactMap { result in
                guard let entry = entryById[result.userId] else { return nil }
                let reasons = result.evidence.isEmpty ? entry.reasons : result.evidence
                return (profile: entry.profile, reasons: reasons, matchPercent: Int(result.reciprocalScore.rounded()))
            }
            if topEntries.count < topCount {
                let existingIds = Set(topEntries.map { $0.profile.userId })
                for entry in ranked where !existingIds.contains(entry.profile.userId) {
                    topEntries.append((entry.profile, entry.reasons, nil))
                    if topEntries.count >= topCount { break }
                }
            }
            llmApplied = true
            print("  🤖 V3.0: LLM reciprocal rerank applied")
        } else {
            topEntries = ranked.prefix(topCount).map { ($0.profile, $0.reasons, nil) }
            print("  🛟 V3.0: LLM unavailable, fell back to rule-based ranking")
        }

        // ⚡️ 性能修复(2026-08):去掉重复的最终存在性校验——
        // top 候选全部来自步骤 3 刚验证过的池子,再查一遍纯属浪费一个网络往返
        print("  ⏱️  Total time: \(Date().timeIntervalSince(searchStart) * 1000)ms")
        print("  ✅ Top \(topEntries.count) selected from \(recommendations.count) candidates\n")

        // 📓 决策日志(Match v4 反馈闭环的地基:后续 GEPA prompt 自优化的训练素材)
        logDecisions(searcherId: currentUserId, query: query, entries: topEntries, llmApplied: llmApplied)

        await progress?(1.0, 4)
        return SearchOutcome(top: topEntries, llmRerankApplied: llmApplied)
    }

    // MARK: - Match v4:曝光统计 & 决策日志

    /// 近 14 天各候选出现在别人 top 结果里的次数(单查询,失败返回空 = 不调整)
    private func fetchExposureCounts(candidateIds: [String]) async -> [String: Int] {
        guard !candidateIds.isEmpty else { return [:] }
        struct Row: Decodable {
            let candidateId: String
            enum CodingKeys: String, CodingKey { case candidateId = "candidate_id" }
        }
        let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14 * 24 * 3600))
        guard let response = try? await supabaseService.supabase
            .from("match_decisions")
            .select("candidate_id")
            .in("candidate_id", values: candidateIds)
            .gte("created_at", value: cutoff)
            .execute(),
            let rows = try? JSONDecoder().decode([Row].self, from: response.data) else { return [:] }
        var counts: [String: Int] = [:]
        for row in rows { counts[row.candidateId, default: 0] += 1 }
        return counts
    }

    /// 记录本次精选(fire-and-forget;后续与 invitations/worthit 结果 join 形成学习信号)
    private func logDecisions(
        searcherId: String,
        query: String,
        entries: [(profile: BrewNetProfile, reasons: [String], matchPercent: Int?)],
        llmApplied: Bool
    ) {
        guard !entries.isEmpty else { return }
        struct DecisionInsert: Encodable {
            let searcher_id: String, candidate_id: String, query: String
            let rank: Int, fit_score: Int?, accept_score: Int?, llm_applied: Bool, source: String
        }
        let rows = entries.enumerated().map { index, entry in
            DecisionInsert(
                searcher_id: searcherId.lowercased(),
                candidate_id: entry.profile.userId.lowercased(),
                query: String(query.prefix(300)),
                rank: index + 1,
                fit_score: entry.matchPercent,
                accept_score: nil,
                llm_applied: llmApplied,
                source: "scout"
            )
        }
        Task {
            do {
                _ = try await supabaseService.supabase.from("match_decisions").insert(rows).execute()
                print("📓 [v4] logged \(rows.count) decisions")
            } catch {
                print("⚠️ [v4] decision log failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Validation(自 ExploreView 移入)

    func validateRecommendations(
        _ recommendations: [(userId: String, score: Double, profile: BrewNetProfile)]
    ) async -> [(userId: String, score: Double, profile: BrewNetProfile)] {
        var validRecommendations: [(userId: String, score: Double, profile: BrewNetProfile)] = []
        let userIds = recommendations.map { $0.userId }
        let profilesDict = try? await supabaseService.getProfilesBatch(userIds: userIds)
        for item in recommendations {
            if profilesDict?[item.userId] != nil {
                validRecommendations.append(item)
            } else {
                print("⚠️ [验证] 用户 \(item.userId) (\(item.profile.coreIdentity.name)) 已被删除，已过滤")
            }
        }
        return validRecommendations
    }

    func validateProfilesExist(
        _ profiles: [BrewNetProfile]
    ) async -> [BrewNetProfile] {
        var validProfiles: [BrewNetProfile] = []
        let userIds = profiles.map { $0.userId }
        let profilesDict = try? await supabaseService.getProfilesBatch(userIds: userIds)
        for profile in profiles {
            if profilesDict?[profile.userId] != nil {
                validProfiles.append(profile)
            } else {
                print("⚠️ [最终验证] 用户 \(profile.userId) (\(profile.coreIdentity.name)) 已被删除，已从结果中移除")
            }
        }
        return validProfiles
    }

    // MARK: - Ranking V2(自 ExploreView 移入,逻辑不变)

    func rankRecommendationsV2(
        _ recommendations: [(userId: String, score: Double, profile: BrewNetProfile)],
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?,
        exposureCounts: [String: Int] = [:]
    ) -> [(profile: BrewNetProfile, reasons: [String])] {

        guard !parsedQuery.tokens.isEmpty else {
            return recommendations.map { ($0.profile, []) }
        }

        let weights = DynamicWeighting.adjustWeights(
            for: parsedQuery.rawText,
            parsedQuery: parsedQuery
        )
        let queryConceptTags = ConceptTagger.mapQueryToConcepts(query: parsedQuery.rawText)

        let ranked = recommendations.map { item -> (profile: BrewNetProfile, score: Double, reasons: [String]) in
            print("\n👤 Scoring: \(item.profile.coreIdentity.name)")
            let match = computeMatchScoreV2(
                for: item.profile,
                parsedQuery: parsedQuery,
                currentUserProfile: currentUserProfile,
                queryConceptTags: queryConceptTags
            )
            var blendedScore = (item.score * weights.recommendation) + (match.score * weights.textMatch)

            // 🎰 曝光调整(温和,不盖过相关性):
            //   14 天内从未被推 → +0.6 探索加成;被推 ≥3 次 → -0.8 防垄断
            let exposure = exposureCounts[item.userId] ?? 0
            if exposure == 0 {
                blendedScore += 0.6
            } else if exposure >= 3 {
                blendedScore -= 0.8
                print("  🎰 Over-exposed (\(exposure)x in 14d): -0.8")
            }

            print("  📊 Final: Rec(\(String(format: "%.2f", item.score))×\(String(format: "%.1f", weights.recommendation))) + Match(\(String(format: "%.2f", match.score))×\(String(format: "%.1f", weights.textMatch))) + Exp = \(String(format: "%.2f", blendedScore))")
            return (profile: item.profile, score: blendedScore, reasons: match.reasons)
        }

        return ranked
            .sorted { $0.score > $1.score }
            .map { ($0.profile, $0.reasons) }
    }

    func computeMatchScoreV2(
        for profile: BrewNetProfile,
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?,
        queryConceptTags: Set<ConceptTag>
    ) -> (score: Double, reasons: [String]) {
        var score: Double = 0.0
        var weightedReasons: [(weight: Double, text: String)] = []

        // 1. 字段感知评分
        let fieldScore = fieldAwareScoring.computeScore(
            profile: profile,
            tokens: parsedQuery.tokens
        )
        score += fieldScore

        // 2. 实体匹配评分
        let entityScore = fieldAwareScoring.computeEntityScore(
            profile: profile,
            entities: parsedQuery.entities
        )
        score += entityScore

        if entityScore > 0 {
            let profileText = aggregatedSearchableText(for: profile).lowercased()
            let allEntities = parsedQuery.entities.companies
                + parsedQuery.entities.schools
                + parsedQuery.entities.roles
                + parsedQuery.entities.skills
                + parsedQuery.entities.industries
            let matched = allEntities.filter { profileText.contains($0.lowercased()) }
            if !matched.isEmpty {
                let display = matched.prefix(2).map { $0.capitalized }.joined(separator: ", ")
                weightedReasons.append((entityScore + 10, "Direct match: \(display)"))
            }
        }

        // 3. 概念标签匹配
        let profileConceptTags = profile.conceptTags
        let conceptScore = ConceptTagger.scoreConceptMatch(
            profileTags: profileConceptTags,
            queryTags: queryConceptTags
        )
        score += conceptScore

        if conceptScore > 0 {
            let shared = profileConceptTags.intersection(queryConceptTags)
            if !shared.isEmpty {
                let display = shared.prefix(2).map { $0.displayName }.joined(separator: " · ")
                weightedReasons.append((conceptScore + 5, "\(display) background — what you asked for"))
            }
        }

        // 4. 软年限匹配
        if !parsedQuery.entities.numbers.isEmpty {
            let expScore = SoftMatching.softExperienceMatch(
                profile: profile,
                targetYears: parsedQuery.entities.numbers
            )
            score += expScore
            if expScore > 0.5 {
                weightedReasons.append((expScore, "Seniority fits the experience you asked for"))
            }
        }

        // 5. Mentor 意图匹配
        if parsedQuery.tokens.contains(where: { $0.contains("mentor") || $0.contains("mentoring") }) {
            if profile.networkingIntention.selectedIntention == .learnGrow ||
                profile.networkingIntention.selectedSubIntentions.contains(.skillDevelopment) ||
                profile.networkingIntention.selectedSubIntentions.contains(.careerDirection) {
                score += 1.5
                weightedReasons.append((1.5, "Open to mentoring"))
                print("  ✓ Mentor intention match (+1.5)")
            }
        }

        // 6. 校友匹配
        if parsedQuery.tokens.contains(where: { $0.contains("alum") }) {
            let alumniScore = computeAlumniScore(
                profile: profile,
                parsedQuery: parsedQuery,
                currentUserProfile: currentUserProfile
            )
            score += alumniScore
            if alumniScore > 0 {
                weightedReasons.append((alumniScore + 3, "Alumni connection"))
            }
        }

        // 7. Founder/Startup 匹配
        if parsedQuery.tokens.contains(where: { $0.contains("founder") || $0.contains("startup") || $0.contains("entrepreneur") }) {
            if profile.professionalBackground.careerStage == .founder ||
                profile.networkingIntention.selectedIntention == .buildCollaborate {
                score += 1.0
                weightedReasons.append((1.0, "Founder / startup experience"))
                print("  ✓ Founder/Startup match (+1.0)")
            }
        }

        // 7.5 密度加权:同校/同城温和加分(general 发布下优先把用户局部池子的人排上来)
        if let requester = currentUserProfile {
            if let myLoc = requester.coreIdentity.location?.lowercased().trimmingCharacters(in: .whitespaces), !myLoc.isEmpty,
               let theirLoc = profile.coreIdentity.location?.lowercased().trimmingCharacters(in: .whitespaces), !theirLoc.isEmpty,
               myLoc.contains(theirLoc) || theirLoc.contains(myLoc) {
                score += 0.8
                weightedReasons.append((0.8, "Nearby — same city as you"))
            }
            if let mySchools = requester.professionalBackground.educations?.map({ $0.schoolName.lowercased() }), !mySchools.isEmpty,
               let theirSchools = profile.professionalBackground.educations?.map({ $0.schoolName.lowercased() }), !theirSchools.isEmpty,
               !Set(mySchools).isDisjoint(with: Set(theirSchools)) {
                score += 1.2
                weightedReasons.append((1.2, "Fellow alum — same school as you"))
            }
        }

        // 8. 否定词降权
        for negation in parsedQuery.modifiers.negations {
            let zonedText = ZonedSearchableText.from(profile: profile)
            let allText = [zonedText.zoneA, zonedText.zoneB, zonedText.zoneC].joined(separator: " ")
            if allText.contains(negation) {
                score -= 2.0
                print("  ⚠️ Negation match: '\(negation)' (-2.0)")
            }
        }

        if weightedReasons.isEmpty && fieldScore > 0 {
            weightedReasons.append((fieldScore, "Strong overall match for your description"))
        }

        let topReasons = weightedReasons
            .sorted { $0.weight > $1.weight }
            .prefix(3)
            .map { $0.text }

        return (max(0.0, score), Array(topReasons))
    }

    // MARK: - 校友匹配(自 ExploreView 移入)

    func computeAlumniScore(
        profile: BrewNetProfile,
        parsedQuery: ParsedQuery,
        currentUserProfile: BrewNetProfile?
    ) -> Double {
        var score: Double = 0.0

        if let educations = profile.professionalBackground.educations, !educations.isEmpty {
            score += 1.0
        } else if profile.professionalBackground.education != nil {
            score += 0.5
        }

        if let currentUserProfile = currentUserProfile,
           let currentUserEducations = currentUserProfile.professionalBackground.educations,
           !currentUserEducations.isEmpty,
           let targetEducations = profile.professionalBackground.educations,
           !targetEducations.isEmpty {

            let currentUserSchools = Set(currentUserEducations.map {
                $0.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            })

            for targetEducation in targetEducations {
                let targetSchool = targetEducation.schoolName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

                if currentUserSchools.contains(targetSchool) {
                    score += 5.0
                    print("  🎓 Alumni match (exact): \(targetEducation.schoolName) (+5.0)")
                    break
                } else {
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

    // MARK: - 档案文本聚合(自 ExploreView 移入)

    func aggregatedSearchableText(for profile: BrewNetProfile) -> String {
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
}
