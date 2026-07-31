import Foundation

// MARK: - Brew Agent Service
//
// 「Brew」对话式 agent 的编排层(Stage 1,2026-07):
// 轻量 ReAct 循环 —— 每轮把系统 prompt + 对话历史(+ 工具结果)发给
// gemini-ai edge function,要求结构化输出 {say, action, params}:
//   action = none         → 纯对话(澄清/闲聊/汇报)
//   action = search       → app 执行 ScoutSearchEngine.search(params.query)
//   action = draft_invite → app 调 draftInvite() 生成邀请草稿 → 确认卡
// 权限模型:Brew 只能「说话 / 搜索 / 起草」;一切对外动作(发送邀请)
// 必须经用户在确认卡上点击,代码路径与手动流程完全一致。
// LLM 不可用 → 熔断,BrewAgentView 自动降级到经典搜索表单。

// MARK: - Types

enum BrewAgentAction: Equatable {
    case none
    case search(query: String)
    case draftInvite(targetUserId: String)
}

struct BrewAgentTurn {
    let say: String
    let action: BrewAgentAction
}

struct BrewChatEntry {
    enum Role: String { case user, agent, tool }
    let role: Role
    let text: String
}

final class BrewAgentService {

    static let shared = BrewAgentService()
    private init() {}

    private let timeoutSeconds: TimeInterval = 15.0  // edge 侧多 provider 链最长 ~14s,留足余量
    /// 对话上下文只保留最近 N 条(控制 token)
    private let maxHistoryEntries = 8

    /// 熔断:连续失败后本会话降级(BrewAgentView 据此切换到经典表单)
    private(set) var consecutiveFailures = 0
    private let circuitBreakerThreshold = 2
    var isCircuitOpen: Bool { consecutiveFailures >= circuitBreakerThreshold }

    private var edgeFunctionURL: String {
        "\(SupabaseConfig.shared.url)/functions/v1/gemini-ai"
    }

    // MARK: - 对话轮次

    /// 生成 Brew 的下一轮回应。history 含用户/agent/工具消息(时间序)。
    /// 返回 nil = LLM 不可用,调用方应降级。
    func nextTurn(
        history: [BrewChatEntry],
        requesterProfile: BrewNetProfile?,
        memoryContext: String? = nil
    ) async -> BrewAgentTurn? {
        guard !isCircuitOpen else {
            print("⛔️ [BrewAgent] 熔断已开,跳过 LLM")
            return nil
        }

        let prompt = buildConversationPrompt(history: history, requester: requesterProfile, memoryContext: memoryContext)
        guard let raw = await callEdgeFunction(prompt: prompt, maxTokens: 512) else {
            consecutiveFailures += 1
            print("⚠️ [BrewAgent] 对话调用失败(连续 \(consecutiveFailures))")
            return nil
        }
        consecutiveFailures = 0

        if let turn = parseTurn(raw) {
            print("🗣️ [BrewAgent] say=\"\(turn.say.prefix(80))\" action=\(turn.action)")
            return turn
        }
        // 结构化解析失败:把原文当纯文本回复(降级但不失败)
        let plain = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty ? nil : BrewAgentTurn(say: String(plain.prefix(600)), action: .none)
    }

    // MARK: - 邀请草稿

    /// 基于双方档案 + 用户目标,生成个性化咖啡邀请语(纯文本)。
    func draftInvite(
        requester: BrewNetProfile?,
        target: BrewNetProfile,
        conversationGoal: String
    ) async -> String? {
        guard !isCircuitOpen else { return nil }

        var requesterDesc = "a BrewNet user"
        if let r = requester {
            var parts = [r.coreIdentity.name]
            if let t = r.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
            if let c = r.professionalBackground.currentCompany, !c.isEmpty { parts.append("at \(c)") }
            requesterDesc = parts.joined(separator: ", ")
        }
        var targetDesc = [target.coreIdentity.name]
        if let t = target.professionalBackground.jobTitle, !t.isEmpty { targetDesc.append(t) }
        if let c = target.professionalBackground.currentCompany, !c.isEmpty { targetDesc.append("at \(c)") }

        let prompt = """
        Write a short, warm, specific coffee-chat invitation message (2-3 sentences, first person, English) \
        from \(requesterDesc) to \(targetDesc.joined(separator: ", ")).
        The sender's goal: "\(conversationGoal)".
        Reference something concrete about the recipient. No emojis, no subject line, no placeholders. \
        Output ONLY the message text.
        """
        guard let raw = await callEdgeFunction(prompt: prompt, maxTokens: 256) else {
            consecutiveFailures += 1
            return nil
        }
        consecutiveFailures = 0
        let text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        return text.isEmpty ? nil : String(text.prefix(500))
    }

    // MARK: - 开场话题(邀请被接受后的下一步)

    /// 为已约成的 coffee chat 生成 3 个 grounded 开场话题
    func conversationStarters(
        requester: BrewNetProfile?,
        target: BrewNetProfile
    ) async -> String? {
        guard !isCircuitOpen else { return nil }

        var targetDesc = [target.coreIdentity.name]
        if let t = target.professionalBackground.jobTitle, !t.isEmpty { targetDesc.append(t) }
        if let c = target.professionalBackground.currentCompany, !c.isEmpty { targetDesc.append("at \(c)") }
        if !target.professionalBackground.skills.isEmpty {
            targetDesc.append("skills: \(target.professionalBackground.skills.prefix(5).joined(separator: ", "))")
        }
        if let bio = target.coreIdentity.bio, !bio.isEmpty { targetDesc.append("bio: \(String(bio.prefix(120)))") }

        var requesterDesc = "a BrewNet user"
        if let r = requester {
            var parts = [r.coreIdentity.name]
            if let t = r.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
            requesterDesc = parts.joined(separator: ", ")
        }

        let prompt = """
        \(requesterDesc) has an upcoming coffee chat with \(targetDesc.joined(separator: ", ")).
        Write exactly 3 short, specific conversation starters grounded in the recipient's actual background above. \
        No generic questions ("tell me about yourself"). Each under 20 words. \
        Output as a numbered list, nothing else.
        """
        guard let raw = await callEdgeFunction(prompt: prompt, maxTokens: 300) else {
            consecutiveFailures += 1
            return nil
        }
        consecutiveFailures = 0
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(700))
    }

    // MARK: - Prompt

    private func buildConversationPrompt(history: [BrewChatEntry], requester: BrewNetProfile?, memoryContext: String? = nil) -> String {
        var userLine = "the user"
        if let r = requester {
            var parts = [r.coreIdentity.name]
            if let t = r.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
            if let c = r.professionalBackground.currentCompany, !c.isEmpty { parts.append("at \(c)") }
            userLine = parts.joined(separator: ", ")
        }

        let historyText = history.suffix(maxHistoryEntries).map { entry -> String in
            switch entry.role {
            case .user: return "USER: \(entry.text)"
            case .agent: return "BREW: \(entry.text)"
            case .tool: return "TOOL_RESULT: \(entry.text)"
            }
        }.joined(separator: "\n")

        return """
        You are Brew, the personal networking agent inside BrewNet (a professional coffee-chat app). \
        You help \(userLine) meet the right professionals. You are concise, warm, and action-oriented.

        YOUR TOOLS (via "action"):
        - "search": run a talent search. Set params.query to a self-contained English description of who to find \
        (merge everything learned in the conversation).
        - "draft_invite": draft a coffee-chat invitation. Set params.target_user_id to the chosen candidate's id \
        (must be an id that appeared in a TOOL_RESULT).
        - "none": just talk (clarify, summarize, answer).

        HARD RULES:
        1. If the user's goal is clear enough to search, ACT — do not over-ask. At most ONE clarifying question, then search.
        2. After TOOL_RESULT with candidates, briefly point out which one stands out and why (grounded in the data). Never invent facts.
        3. When the user picks a candidate (by name, number, or "the first one"), use draft_invite with that candidate's id.
        4. Keep "say" under 60 words.
        5. Reply with ONLY valid JSON, no markdown fences:
        {"say":"...","action":"none|search|draft_invite","params":{"query":"...","target_user_id":"..."}}

        \(memoryContext.map { "WHAT YOU REMEMBER ABOUT THIS USER (use it — reference their mission, respect their preferences, never re-suggest people already invited):\n\($0)\n" } ?? "")
        CONVERSATION:
        \(historyText)

        BREW's next turn (JSON only):
        """
    }

    // MARK: - Parse

    private func parseTurn(_ raw: String) -> BrewAgentTurn? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let say = json["say"] as? String, !say.isEmpty else {
            return nil
        }

        let params = json["params"] as? [String: Any]
        let action: BrewAgentAction
        switch (json["action"] as? String ?? "none").lowercased() {
        case "search":
            if let q = params?["query"] as? String, !q.trimmingCharacters(in: .whitespaces).isEmpty {
                action = .search(query: q)
            } else {
                action = .none
            }
        case "draft_invite":
            if let id = params?["target_user_id"] as? String, !id.isEmpty {
                action = .draftInvite(targetUserId: id)
            } else {
                action = .none
            }
        default:
            action = .none
        }
        return BrewAgentTurn(say: String(say.prefix(600)), action: action)
    }

    // MARK: - Edge Function Call(与 LLMRerankService 同构)

    private func callEdgeFunction(prompt: String, maxTokens: Int) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { [timeoutSeconds] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return nil
            }
            group.addTask {
                await self.performCall(prompt: prompt, maxTokens: maxTokens)
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func performCall(prompt: String, maxTokens: Int) async -> String? {
        guard let url = URL(string: edgeFunctionURL) else {
            print("❌ [BrewAgent] 无效 URL")
            return nil
        }
        // 优先用户会话 token;无会话(自定义登录路径)退回 anon key(网关同样放行)
        let accessToken: String
        if let token = try? await SupabaseConfig.shared.client.auth.session.accessToken {
            accessToken = token
        } else {
            accessToken = SupabaseConfig.shared.key
        }
        let body: [String: Any] = [
            "prompt": prompt,
            "category": "brew_agent",
            "generationConfig": [
                "temperature": 0.4,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": maxTokens
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.shared.key, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard http.statusCode == 200 else {
                print("❌ [BrewAgent] Edge HTTP \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String else {
                print("❌ [BrewAgent] 响应解析失败: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
                return nil
            }
            if let provider = json["provider"] as? String {
                print("✅ [BrewAgent] provider=\(provider)")
            }
            return text
        } catch {
            print("❌ [BrewAgent] 网络错误: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 工具结果序列化(供 BrewAgentView 把搜索结果喂回对话)

    static func toolResultSummary(for entries: [(profile: BrewNetProfile, reasons: [String])]) -> String {
        let items = entries.map { entry -> String in
            let p = entry.profile
            var parts = ["id=\(p.userId)", "name=\(p.coreIdentity.name)"]
            if let t = p.professionalBackground.jobTitle, !t.isEmpty { parts.append("role=\(t)") }
            if let c = p.professionalBackground.currentCompany, !c.isEmpty { parts.append("company=\(c)") }
            parts.append("looking_for=\(p.networkingIntention.selectedIntention.rawValue)")
            if !entry.reasons.isEmpty { parts.append("why=\(entry.reasons.joined(separator: "; "))") }
            return "{\(parts.joined(separator: ", "))}"
        }
        return "SEARCH returned \(entries.count) candidates: [\(items.joined(separator: ", "))]"
    }
}
