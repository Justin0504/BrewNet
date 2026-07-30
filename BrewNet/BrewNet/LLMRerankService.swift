import Foundation

// MARK: - LLM Rerank Service
//
// Talent Scout 排序管线的 LLM 精排层(研究驱动的架构,2026-07):
//   双塔召回 + 规则打分(现有,保留) → top-N 作为先验顺序
//   → 单次 Gemini Flash listwise 调用,每候选输出显式双向分数:
//       fit    = 候选人符合查询要求的程度 (0-100)
//       accept = 候选人接受本次 coffee chat 邀请的可能性 (0-100, 基于其 networking 意向)
//   → 最终分 = fit × accept(互惠推荐:match 概率 = 双方意愿乘积)
//   → evidence 必须引用传入档案字段(grounded, 抑制幻觉)
//   任何失败/超时 → 调用方无缝退回现有规则排序(本服务只增强,不接管)

// MARK: - Result Types

struct LLMRerankResult {
    let userId: String
    let fitScore: Int        // 0-100 符合查询程度
    let acceptScore: Int     // 0-100 接受邀请可能性
    let evidence: [String]   // 引用档案字段的理由
    var reciprocalScore: Double { Double(fitScore) * Double(acceptScore) / 100.0 }
}

final class LLMRerankService {

    static let shared = LLMRerankService()
    private init() {}

    /// 单次调用超时(秒)。超时即放弃,调用方退回规则排序
    /// (15 候选大 prompt 经多 provider 链,实测 8s 偶发不够)
    private let timeoutSeconds: TimeInterval = 12.0
    /// 传给 LLM 的最大候选数(研究结论:≤20-30 可单窗 listwise;12 平衡质量与生成延迟)
    static let maxCandidates = 12

    /// 熔断器:连续失败(配额爆/网络断)达到阈值后,本次 app 会话内跳过 LLM,
    /// 避免每次搜索都白等超时(Gemini 429 时 edge function 重试可达 10s+)
    private var consecutiveFailures = 0
    private let circuitBreakerThreshold = 2

    private var edgeFunctionURL: String {
        "\(SupabaseConfig.shared.url)/functions/v1/gemini-ai"
    }

    // MARK: - Public API

    /// 对候选列表做 LLM 互惠重排。
    /// - Parameters:
    ///   - query: 用户的自然语言查询
    ///   - candidates: 按现有规则分数排好序的候选(作为 LLM 先验)
    ///   - requesterProfile: 发起查询的用户档案(用于评估对方接受度),可为 nil
    /// - Returns: 重排结果;nil 表示失败/超时,调用方应退回规则排序
    func rerank(
        query: String,
        candidates: [BrewNetProfile],
        requesterProfile: BrewNetProfile?
    ) async -> [LLMRerankResult]? {
        guard !candidates.isEmpty else { return nil }

        // 熔断:连续失败后本会话不再尝试(下次冷启动自动恢复)
        guard consecutiveFailures < circuitBreakerThreshold else {
            print("⛔️ [LLMRerank] 熔断已开(连续失败 \(consecutiveFailures) 次),跳过 LLM 直接规则排序")
            return nil
        }

        let pool = Array(candidates.prefix(Self.maxCandidates))

        let prompt = buildPrompt(query: query, candidates: pool, requester: requesterProfile)

        let start = Date()
        guard let raw = await callEdgeFunctionWithTimeout(prompt: prompt) else {
            consecutiveFailures += 1
            print("⚠️ [LLMRerank] 调用失败/超时(\(String(format: "%.1f", Date().timeIntervalSince(start)))s),退回规则排序(连续失败 \(consecutiveFailures))")
            return nil
        }
        consecutiveFailures = 0
        print("⏱️ [LLMRerank] LLM 调用耗时 \(String(format: "%.1f", Date().timeIntervalSince(start)))s")

        guard let results = parseAndValidate(raw, allowedIds: Set(pool.map { $0.userId })), results.count >= 3 else {
            print("⚠️ [LLMRerank] 输出解析/校验失败,退回规则排序")
            return nil
        }

        // 互惠乘积降序
        let sorted = results.sorted { $0.reciprocalScore > $1.reciprocalScore }
        print("✅ [LLMRerank] 重排成功: \(sorted.prefix(3).map { "\($0.userId.prefix(8))(fit:\($0.fitScore)×acc:\($0.acceptScore))" }.joined(separator: ", "))")
        return sorted
    }

    // MARK: - Prompt

    private func buildPrompt(query: String, candidates: [BrewNetProfile], requester: BrewNetProfile?) -> String {
        let candidateJSON = candidates.map { compactProfileJSON($0) }.joined(separator: ",\n")

        var requesterLine = "A BrewNet user"
        if let r = requester {
            var parts: [String] = []
            if let title = r.professionalBackground.jobTitle, !title.isEmpty { parts.append(title) }
            if let company = r.professionalBackground.currentCompany, !company.isEmpty { parts.append("at \(company)") }
            parts.append("looking to: \(r.networkingIntention.selectedIntention.rawValue)")
            requesterLine = "\(r.coreIdentity.name) (\(parts.joined(separator: ", ")))"
        }

        return """
        You are the matching engine of BrewNet, a professional coffee-chat networking app. \
        Score each candidate for this request. The candidate data below is the ONLY ground truth — never invent facts.

        REQUESTER: \(requesterLine)
        REQUEST: "\(query)"

        CANDIDATES:
        [
        \(candidateJSON)
        ]

        Score EVERY candidate (be terse — numbers only):
        - "fit": 0-100, how well the candidate matches the REQUEST (semantic match, not just keywords: role, seniority, domain, topics they can speak to).
        - "accept": 0-100, how likely this candidate would welcome a coffee chat from the REQUESTER, judged from the candidate's "looking_for" intention and profile.

        Then for ONLY your top 3 candidates (highest fit×accept), give "evidence": 1-2 short strings, each grounded in a specific field of that candidate's data (quote or close paraphrase). No generic praise, no invented facts.

        Return ONLY valid JSON, no markdown fences, exactly this shape:
        {"scores":[{"id":"...","fit":85,"accept":70}],"top":[{"id":"...","evidence":["...","..."]}]}
        Include every candidate exactly once in "scores".
        """
    }

    /// 压缩档案(每候选约 100-200 token,控制单次调用成本与延迟)
    private func compactProfileJSON(_ p: BrewNetProfile) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: " ")
        }
        var fields: [String] = ["\"id\": \"\(esc(p.userId))\"", "\"name\": \"\(esc(p.coreIdentity.name))\""]

        let pb = p.professionalBackground
        if let t = pb.jobTitle, !t.isEmpty { fields.append("\"role\": \"\(esc(t))\"") }
        if let c = pb.currentCompany, !c.isEmpty { fields.append("\"company\": \"\(esc(c))\"") }
        if let i = pb.industry, !i.isEmpty { fields.append("\"industry\": \"\(esc(i))\"") }
        if let y = pb.yearsOfExperience { fields.append("\"years_experience\": \(String(format: "%.0f", y))") }
        fields.append("\"career_stage\": \"\(esc(pb.careerStage.rawValue))\"")
        if !pb.skills.isEmpty {
            fields.append("\"skills\": [\(pb.skills.prefix(6).map { "\"\(esc($0))\"" }.joined(separator: ", "))]")
        }
        if let edus = pb.educations, let first = edus.first {
            fields.append("\"education\": \"\(esc(first.schoolName))\"")
        } else if let edu = pb.education, !edu.isEmpty {
            fields.append("\"education\": \"\(esc(edu))\"")
        }

        // 互惠关键:候选人自己的社交意向(决定 accept 分)
        fields.append("\"looking_for\": \"\(esc(p.networkingIntention.selectedIntention.rawValue))\"")
        let subs = p.networkingIntention.selectedSubIntentions
        if !subs.isEmpty {
            fields.append("\"open_to\": [\(subs.prefix(4).map { "\"\(esc($0.rawValue))\"" }.joined(separator: ", "))]")
        }

        if let bio = p.coreIdentity.bio, !bio.isEmpty {
            fields.append("\"bio\": \"\(esc(String(bio.prefix(140))))\"")
        }
        return "  {\(fields.joined(separator: ", "))}"
    }

    // MARK: - Edge Function Call

    private func callEdgeFunctionWithTimeout(prompt: String) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { [timeoutSeconds] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil  // 超时哨兵
            }
            group.addTask {
                await self.callEdgeFunction(prompt: prompt)
            }
            // 取第一个完成的:要么结果、要么超时 nil
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func callEdgeFunction(prompt: String) async -> String? {
        guard let url = URL(string: edgeFunctionURL) else { return nil }

        // 优先用户会话 token;无会话(自定义登录路径)退回 anon key(网关同样放行)
        let accessToken: String
        if let token = try? await SupabaseConfig.shared.client.auth.session.accessToken {
            accessToken = token
        } else {
            accessToken = SupabaseConfig.shared.key
        }

        let body: [String: Any] = [
            "prompt": prompt,
            "category": "rerank",
            "generationConfig": [
                "temperature": 0.2,       // 低温:排序稳定性
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 1024   // 全员分数 + 仅 top3 证据 ≈ 400 token
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.shared.key, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            return nil
        }
        return text
    }

    // MARK: - Parse & Validate

    private func parseAndValidate(_ raw: String, allowedIds: Set<String>) -> [LLMRerankResult]? {
        // 容错:剥掉可能的 markdown 围栏
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 容错:截取第一个 { 到最后一个 }
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scores = json["scores"] as? [[String: Any]] else {
            return nil
        }

        // top-3 的 grounded 证据(输出瘦身:只为最终展示的候选生成理由)
        var evidenceById: [String: [String]] = [:]
        for item in (json["top"] as? [[String: Any]] ?? []) {
            guard let id = item["id"] as? String else { continue }
            let evidence = (item["evidence"] as? [String] ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { String($0.prefix(120)) }
            if !evidence.isEmpty { evidenceById[id] = Array(evidence.prefix(2)) }
        }

        var seen = Set<String>()
        var results: [LLMRerankResult] = []
        for item in scores {
            guard let id = item["id"] as? String,
                  allowedIds.contains(id),        // 只接受传入过的候选(防幻觉 id)
                  !seen.contains(id) else { continue }
            seen.insert(id)
            results.append(LLMRerankResult(
                userId: id,
                fitScore: clamp(item["fit"]),
                acceptScore: clamp(item["accept"]),
                evidence: evidenceById[id] ?? []
            ))
        }
        return results.isEmpty ? nil : results
    }

    private func clamp(_ value: Any?) -> Int {
        let n: Int
        if let i = value as? Int { n = i }
        else if let d = value as? Double { n = Int(d) }
        else if let s = value as? String, let i = Int(s) { n = i }
        else { n = 0 }
        return min(100, max(0, n))
    }
}
