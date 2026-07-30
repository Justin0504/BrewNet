import SwiftUI

// MARK: - Brew Agent View(Stage 1:对话式 Talent Scout)
//
// Scout Tab 的新形态:与「Brew」的对话线程。
// 用户说目标 → Brew 澄清/搜索(ScoutSearchEngine)→ 对话内出精选卡
// → 用户选人 → Brew 起草邀请 → 确认卡(发送走现有邀请流程,含限额检查)。
// LLM 熔断 → 自动降级到经典搜索表单(ExploreMainView 原样保留)。

// MARK: - Message Model

struct BrewMessage: Identifiable {
    enum Kind {
        case agentText(String)
        case userText(String)
        case picks([(profile: BrewNetProfile, reasons: [String], matchPercent: Int?)])
        case inviteDraft(profile: BrewNetProfile, initialText: String)
        case survey(profile: BrewNetProfile)   // worth-it 一键问卷(北极星指标)
        case note(String)
    }
    let id = UUID()
    let kind: Kind
}

// MARK: - Main View

struct BrewAgentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService

    @State private var messages: [BrewMessage] = []
    @State private var history: [BrewChatEntry] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var lastPicks: [(profile: BrewNetProfile, reasons: [String], matchPercent: Int?)] = []
    @State private var lastGoal = ""
    @State private var currentUserProfile: BrewNetProfile?
    @State private var useClassicSearch = false
    @State private var engagedProfileIds: Set<String> = []
    @State private var showingInviteLimitAlert = false
    @State private var selectedProfile: BrewNetProfile?
    @State private var didGreet = false
    @State private var animatedMessageIds: Set<UUID> = []  // 打字机动画只放一次
    @FocusState private var composerFocused: Bool

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }

    var body: some View {
        Group {
            if useClassicSearch {
                // 降级/手动切换:经典搜索表单(原功能完整保留)+ 返回 Brew 浮钮
                ZStack(alignment: .bottomTrailing) {
                    ExploreMainView()
                    Button {
                        useClassicSearch = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Brew")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(themeColor))
                        .shadow(color: themeColor.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 24)
                }
            } else {
                conversationBody
            }
        }
    }

    private var conversationBody: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    messageList
                    composer
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadRequesterProfile()
            let proactiveRunStarted = greetIfNeeded()
            if !proactiveRunStarted {
                maybeAskWorthIt()   // 📊 北极星:见面后的 worth-it 回访
            }
            autoChatIfNeeded()
        }
        .alert("No Connects Left", isPresented: $showingInviteLimitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've used all connects for today. Upgrade to BrewNet Pro for unlimited connections.")
        }
        .sheet(item: $selectedProfile) { profile in
            TalentScoutProfileCardSheet(
                profile: profile,
                isPro: false,
                isVerifiedOverride: nil,
                onDismiss: { selectedProfile = nil },
                onTemporaryChat: { _ in },
                onRequestConnect: { _ in },
                shouldShowActions: false,
                hasEngaged: engagedProfileIds.contains(profile.userId)
            )
            .environmentObject(authManager)
            .environmentObject(supabaseService)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(themeColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Brew")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(themeColor)
                Text("Your networking agent")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            // 切换到经典搜索
            Button {
                useClassicSearch = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeColor.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(Color.white))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    // 快速起步建议:用户还没说过话时显示(降低第一句输入门槛)
                    if !hasUserSpoken && !isThinking {
                        suggestionChips
                    }
                    if isThinking {
                        thinkingBubble.id("thinking")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: isThinking) { thinking in
                if thinking {
                    withAnimation { proxy.scrollTo("thinking", anchor: .bottom) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: BrewMessage) -> some View {
        switch message.kind {
        case .agentText(let text):
            HStack(alignment: .bottom, spacing: 8) {
                agentAvatar(size: 24)
                BrewTypewriterText(
                    text: text,
                    animate: !animatedMessageIds.contains(message.id),
                    onDone: { animatedMessageIds.insert(message.id) }
                )
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16)
                            .fill(Color.white)
                    )
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16)
                            .stroke(themeColor.opacity(0.08), lineWidth: 1)
                    )
                Spacer(minLength: 32)
            }
        case .userText(let text):
            HStack {
                Spacer(minLength: 40)
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(themeColor))
            }
        case .picks(let entries):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.profile.id) { index, entry in
                    BrewPickCard(
                        profile: entry.profile,
                        reasons: entry.reasons,
                        rank: index + 1,
                        matchPercent: entry.matchPercent,
                        isEngaged: engagedProfileIds.contains(entry.profile.userId),
                        onTap: { selectedProfile = entry.profile },
                        onConnect: {
                            Task { await draftInviteFor(profile: entry.profile) }
                        }
                    )
                }
            }
        case .survey(let profile):
            BrewWorthItCard(
                profile: profile,
                onAnswer: { worthIt in
                    guard let uid = authManager.currentUser?.id else { return }
                    let name = profile.coreIdentity.name
                    BrewMemoryStore.shared.recordWorthIt(name: name, worthIt: worthIt, userId: uid)
                    // ☁️ 北极星指标落云(表未建则静默跳过,见 create_brew_worthit_votes.sql)
                    Task {
                        struct WorthItInsert: Encodable {
                            let user_id: String
                            let subject_user_id: String?
                            let subject_name: String
                            let worth_it: Bool
                        }
                        do {
                            _ = try await SupabaseConfig.shared.client
                                .from("brew_worthit_votes")
                                .insert(WorthItInsert(user_id: uid, subject_user_id: profile.userId, subject_name: name, worth_it: worthIt))
                                .execute()
                            print("☁️ [WorthIt] synced to cloud")
                        } catch {
                            print("⚠️ [WorthIt] cloud sync skipped: \(error.localizedDescription)")
                        }
                    }
                    appendAgent(worthIt
                        ? "Love to hear it! I'll look for more people like \(name)."
                        : "Got it — I'll adjust what I look for. Thanks for telling me.")
                },
                onNotMetYet: {
                    appendAgent("No rush — I'll check back later.")
                }
            )
        case .inviteDraft(let profile, let initialText):
            BrewInviteDraftCard(
                profile: profile,
                initialText: initialText,
                alreadySent: engagedProfileIds.contains(profile.userId),
                onSend: { finalText in
                    Task { await sendInvite(to: profile, message: finalText) }
                },
                onCancel: {
                    // 🧠 Stage 2:记录拒绝,供后续排序/对话参考
                    if let uid = authManager.currentUser?.id {
                        BrewMemoryStore.shared.recordDeclined(name: profile.coreIdentity.name, userId: uid)
                    }
                    appendAgent("No problem — tell me if you'd like a different match or a new search.")
                }
            )
        case .note(let text):
            HStack {
                Spacer()
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
    }

    private var hasUserSpoken: Bool {
        messages.contains { if case .userText = $0.kind { return true } else { return false } }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach([
                "🎯 Find me a mentor in my field",
                "🚀 Meet startup founders near me",
                "🎓 Alumni I could grab coffee with"
            ], id: \.self) { chip in
                Button {
                    let text = String(chip.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    Task { await send(userText: text) }
                } label: {
                    Text(chip)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(themeColor.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(.top, 2)
        .transition(.opacity)
    }

    private var thinkingBubble: some View {
        HStack(spacing: 8) {
            agentAvatar(size: 24)
            BrewTypingDots()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func agentAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeColor.opacity(0.18),
                            Color(red: 0.85, green: 0.65, blue: 0.4).opacity(0.25)
                        ]),
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(themeColor)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Tell Brew who you need…", text: $inputText, axis: .vertical)
                .focused($composerFocused)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeColor.opacity(composerFocused ? 0.4 : 0.12), lineWidth: 1.2))

            Button {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, !isThinking else { return }
                inputText = ""
                Task { await send(userText: text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : themeColor)
            }
            .disabled(isThinking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(backgroundColor)
    }

    // MARK: - Orchestration(ReAct 执行器)

    private func send(userText: String) async {
        await MainActor.run {
            messages.append(BrewMessage(kind: .userText(userText)))
            history.append(BrewChatEntry(role: .user, text: userText))
            lastGoal = userText
            isThinking = true
        }

        let memoryContext = authManager.currentUser.flatMap {
            BrewMemoryStore.shared.contextSummary(userId: $0.id)
        }
        guard let turn = await BrewAgentService.shared.nextTurn(
            history: history,
            requesterProfile: currentUserProfile,
            memoryContext: memoryContext
        ) else {
            await MainActor.run {
                isThinking = false
                if BrewAgentService.shared.isCircuitOpen {
                    messages.append(BrewMessage(kind: .note("Brew is temporarily unavailable — switching to classic search.")))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        useClassicSearch = true
                    }
                } else {
                    messages.append(BrewMessage(kind: .note("Hmm, that didn't go through. Try again?")))
                }
            }
            return
        }

        await MainActor.run {
            messages.append(BrewMessage(kind: .agentText(turn.say)))
            history.append(BrewChatEntry(role: .agent, text: turn.say))
        }

        switch turn.action {
        case .none:
            await MainActor.run { isThinking = false }

        case .search(let query):
            await runSearch(query: query)

        case .draftInvite(let targetUserId):
            if let entry = lastPicks.first(where: { $0.profile.userId == targetUserId }) {
                await draftInviteFor(profile: entry.profile)
            } else {
                await MainActor.run {
                    isThinking = false
                    messages.append(BrewMessage(kind: .note("I lost track of that candidate — run a new search and pick again.")))
                }
            }
        }
    }

    private func runSearch(query: String) async {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run { isThinking = false }
            return
        }
        do {
            // 🧠 记忆排除:已邀请/已拒绝的人不再出现在推荐里
            let memory = BrewMemoryStore.shared.load(userId: currentUser.id)
            let excludeNames = Set(memory.sentInviteNames + memory.declinedNames)
            let outcome = try await ScoutSearchEngine.shared.search(
                query: query,
                currentUserId: currentUser.id,
                currentUserProfile: currentUserProfile,
                topCount: 3,
                excludeNames: excludeNames
            )
            await MainActor.run {
                isThinking = false
                // 🧠 目标一律持久化为常驻 mission(空结果时它是"我持续帮你盯着"的承诺)
                if let uid = authManager.currentUser?.id {
                    BrewMemoryStore.shared.recordSearch(goal: query, userId: uid)
                }
                if outcome.top.isEmpty {
                    // 冷启动缓冲:把"现在没人"转化为 agent 的主动性承诺
                    messages.append(BrewMessage(kind: .agentText("No strong fits in the pool right now — but I've saved this as your mission. I'll keep scouting and report back as soon as someone good joins. Add more detail anytime to widen the net.")))
                } else {
                    messages.append(BrewMessage(kind: .picks(outcome.top)))
                    lastPicks = outcome.top
                    history.append(BrewChatEntry(role: .tool, text: BrewAgentService.toolResultSummary(for: outcome.top.map { ($0.profile, $0.reasons) })))
                    messages.append(BrewMessage(kind: .agentText("Tap a card to see more, or tell me which one you'd like to meet — I'll draft the invite.")))
                }
            }
        } catch {
            await MainActor.run {
                isThinking = false
                messages.append(BrewMessage(kind: .note("Search failed — please try again.")))
            }
            print("❌ [BrewAgent] search failed: \(error.localizedDescription)")
        }
    }

    private func draftInviteFor(profile: BrewNetProfile) async {
        await MainActor.run { isThinking = true }
        let draft = await BrewAgentService.shared.draftInvite(
            requester: currentUserProfile,
            target: profile,
            conversationGoal: lastGoal.isEmpty ? "meet interesting professionals" : lastGoal
        )
        let fallbackDraft = "Hi \(profile.coreIdentity.name.components(separatedBy: " ").first ?? profile.coreIdentity.name), I'd love to grab a coffee chat and hear about your experience. Would you be open to connecting?"
        await MainActor.run {
            isThinking = false
            messages.append(BrewMessage(kind: .inviteDraft(profile: profile, initialText: draft ?? fallbackDraft)))
            history.append(BrewChatEntry(role: .agent, text: "Drafted an invitation to \(profile.coreIdentity.name), awaiting user confirmation."))
        }
    }

    /// 发送邀请:与手动流程完全一致(限额检查 + sendInvitation)
    private func sendInvite(to profile: BrewNetProfile, message: String) async {
        guard let currentUser = authManager.currentUser else { return }
        do {
            let canInvite = try await supabaseService.decrementUserLikes(userId: currentUser.id)
            if !canInvite {
                await MainActor.run { showingInviteLimitAlert = true }
                return
            }
            var senderProfile: InvitationProfile? = nil
            if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                senderProfile = supabaseProfile.toBrewNetProfile().toInvitationProfile()
            }
            _ = try await supabaseService.sendInvitation(
                senderId: currentUser.id,
                receiverId: profile.userId,
                reasonForInterest: message,
                senderProfile: senderProfile
            )
            await MainActor.run {
                engagedProfileIds.insert(profile.userId)
                // 🧠 Stage 2:记录已邀请,避免重复推荐
                BrewMemoryStore.shared.recordInviteSent(to: profile.coreIdentity.name, userId: currentUser.id)
                messages.append(BrewMessage(kind: .note("☕️ Invitation sent to \(profile.coreIdentity.name)")))
                messages.append(BrewMessage(kind: .agentText("Done! I'll let you know when \(profile.coreIdentity.name.components(separatedBy: " ").first ?? "they") responds. Anything else you're looking for?")))
                history.append(BrewChatEntry(role: .tool, text: "Invitation sent to \(profile.coreIdentity.name)."))
            }
        } catch {
            await MainActor.run {
                messages.append(BrewMessage(kind: .note("Failed to send — please try again.")))
            }
            print("❌ [BrewAgent] send invite failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Setup

    private func loadRequesterProfile() {
        guard currentUserProfile == nil, let currentUser = authManager.currentUser else { return }
        Task {
            if let supabaseProfile = try? await supabaseService.getProfile(userId: currentUser.id) {
                await MainActor.run {
                    currentUserProfile = supabaseProfile.toBrewNetProfile()
                }
            }
        }
    }

    @discardableResult
    private func greetIfNeeded() -> Bool {
        guard !didGreet else { return false }
        didGreet = true
        let firstName = authManager.currentUser?.name.components(separatedBy: " ").first
        let userId = authManager.currentUser?.id

        // 🧠 Stage 2:有常驻 mission 且距上次 >20h → 主动替用户再跑一轮并汇报
        if let uid = userId, let dueMission = BrewMemoryStore.shared.missionDueForProactiveRun(userId: uid) {
            let greeting = "Welcome back\(firstName.map { ", \($0)" } ?? "")! I kept your mission in mind — \"\(dueMission.goal)\". Let me check who's a good fit today…"
            messages.append(BrewMessage(kind: .agentText(greeting)))
            history.append(BrewChatEntry(role: .agent, text: greeting))
            lastGoal = dueMission.goal
            Task {
                await MainActor.run { isThinking = true }
                await runSearch(query: dueMission.goal)
            }
            return true
        }

        // 有 mission 但最近跑过 → 提及即可;无 mission → 标准开场
        var greeting: String
        if let uid = userId, let mission = BrewMemoryStore.shared.load(userId: uid).activeMission {
            greeting = "Hi\(firstName.map { " \($0)" } ?? "")! Your standing mission is \"\(mission.goal)\" — say \"run it again\" anytime, or tell me about someone new you'd like to meet."
        } else {
            greeting = "Hi\(firstName.map { " \($0)" } ?? "")! Who would you like to meet? Describe them in your own words — role, industry, vibe, anything."
        }
        messages.append(BrewMessage(kind: .agentText(greeting)))
        history.append(BrewChatEntry(role: .agent, text: greeting))
        return false
    }

    /// 📊 worth-it 回访:对已匹配但未回访过的对象,让 Brew 顺口问一句(一次一个)
    private func maybeAskWorthIt() {
        guard let currentUser = authManager.currentUser else { return }
        Task {
            guard let matches = try? await supabaseService.getActiveMatches(userId: currentUser.id),
                  !matches.isEmpty else { return }
            let surveyed = Set(BrewMemoryStore.shared.load(userId: currentUser.id).surveyedNames ?? [])
            for match in matches {
                let otherId = match.userId == currentUser.id ? match.matchedUserId : match.userId
                guard let supabaseProfile = try? await supabaseService.getProfile(userId: otherId) else { continue }
                let profile = supabaseProfile.toBrewNetProfile()
                guard !surveyed.contains(profile.coreIdentity.name) else { continue }
                await MainActor.run {
                    messages.append(BrewMessage(kind: .agentText("By the way — you matched with \(profile.coreIdentity.name) a while back. Did you two end up meeting?")))
                    messages.append(BrewMessage(kind: .survey(profile: profile)))
                }
                break   // 一次会话只问一个,不轰炸
            }
        }
    }

    private func autoChatIfNeeded() {
        #if DEBUG
        // 仅 Debug:环境变量自动发消息(模拟器/UI 测试);MESSAGE2 在第一轮完成后追发
        let env = ProcessInfo.processInfo.environment
        if let autoMessage = env["BREWNET_AUTOCHAT_MESSAGE"],
           !autoMessage.isEmpty, messages.count <= 1 {
            print("🧪 [DEBUG] Auto-chat via env var: \(autoMessage)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                Task {
                    await send(userText: autoMessage)
                    if let second = env["BREWNET_AUTOCHAT_MESSAGE2"], !second.isEmpty {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        print("🧪 [DEBUG] Auto-chat message 2: \(second)")
                        await send(userText: second)
                    }
                }
            }
        }
        #endif
    }

    private func appendAgent(_ text: String) {
        messages.append(BrewMessage(kind: .agentText(text)))
        history.append(BrewChatEntry(role: .agent, text: text))
    }
}

// MARK: - Pick Card(精选卡气泡,瘦身版结果卡)

struct BrewPickCard: View {
    let profile: BrewNetProfile
    let reasons: [String]
    let rank: Int
    var matchPercent: Int? = nil
    let isEngaged: Bool
    var onTap: () -> Void
    var onConnect: () -> Void

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                avatar
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("#\(rank)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(themeColor))
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Text(headline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeColor)
                        .lineLimit(2)
                }
                Spacer()
                // ⭐ 互惠匹配度徽章(fit×accept,LLM 路径才有)
                if let percent = matchPercent, percent > 0 {
                    VStack(spacing: 0) {
                        Text("\(percent)%")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.85, green: 0.6, blue: 0.1),
                                        Color(red: 0.65, green: 0.42, blue: 0.12)
                                    ]),
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Text("match")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 1.0, green: 0.95, blue: 0.85))
                    )
                }
            }

            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(reasons.prefix(2), id: \.self) { reason in
                        HStack(alignment: .top, spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                                .foregroundColor(themeColor.opacity(0.8))
                                .padding(.top, 2)
                            Text(reason)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(themeColor.opacity(0.06)))
            }

            Button(action: onConnect) {
                Text(isEngaged ? "Invited ✓" : "Connect")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isEngaged ? .gray : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isEngaged ? Color.gray.opacity(0.15) : themeColor))
            }
            .disabled(isEngaged)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeColor.opacity(0.1), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var headline: String {
        var parts: [String] = []
        if let t = profile.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
        if let c = profile.professionalBackground.currentCompany, !c.isEmpty { parts.append(c) }
        return parts.isEmpty ? (profile.coreIdentity.bio ?? "") : parts.joined(separator: " · ")
    }

    private var avatar: some View {
        Group {
            if let urlString = profile.coreIdentity.profileImage, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(themeColor.opacity(0.1))
            Image(systemName: "person.fill")
                .foregroundColor(themeColor.opacity(0.4))
        }
    }
}

// MARK: - Invite Draft Card(确认卡:发送前人工确认,可直接编辑)

struct BrewInviteDraftCard: View {
    let profile: BrewNetProfile
    let initialText: String
    let alreadySent: Bool
    var onSend: (String) -> Void
    var onCancel: () -> Void

    @State private var text: String
    @State private var didAct = false

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    init(profile: BrewNetProfile, initialText: String, alreadySent: Bool,
         onSend: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.initialText = initialText
        self.alreadySent = alreadySent
        self.onSend = onSend
        self.onCancel = onCancel
        _text = State(initialValue: initialText)
        _didAct = State(initialValue: alreadySent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "envelope.badge.person.crop")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeColor.opacity(0.7))
                Text("Invitation to \(profile.coreIdentity.name)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeColor.opacity(0.8))
                Spacer()
                Text("Edit freely")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(minHeight: 70, maxHeight: 130)
                .padding(6)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.99, green: 0.985, blue: 0.975)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.12), lineWidth: 1))
                .disabled(didAct)

            HStack(spacing: 10) {
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onSend(text.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Text(didAct ? "Sent ✓" : "Send")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : themeColor))
                }
                .disabled(didAct || text.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    guard !didAct else { return }
                    didAct = true
                    onCancel()
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(themeColor.opacity(0.08)))
                }
                .disabled(didAct)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeColor.opacity(0.25), lineWidth: 1.5)
        )
    }
}

// MARK: - Worth-It Card(📊 北极星指标:见面后一键回访)

struct BrewWorthItCard: View {
    let profile: BrewNetProfile
    var onAnswer: (Bool) -> Void
    var onNotMetYet: () -> Void

    @State private var didAct = false
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onAnswer(true)
                } label: {
                    Label("Worth it", systemImage: "hand.thumbsup.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : themeColor))
                }
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onAnswer(false)
                } label: {
                    Label("Not really", systemImage: "hand.thumbsdown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(themeColor.opacity(0.08)))
                }
            }
            Button {
                guard !didAct else { return }
                didAct = true
                onNotMetYet()
            } label: {
                Text("We haven't met yet")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeColor.opacity(0.12), lineWidth: 1))
        .opacity(didAct ? 0.55 : 1)
        .disabled(didAct)
    }
}

// MARK: - Typewriter Text(agent 文字逐字浮现,流式感)

struct BrewTypewriterText: View {
    let text: String
    let animate: Bool
    var onDone: (() -> Void)? = nil

    @State private var shown: String = ""

    var body: some View {
        Text(animate ? shown : text)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                guard animate else { return }
                shown = ""
                Task { @MainActor in
                    // 总时长封顶 1.2s,长文本加速
                    let perChar = min(0.022, 1.2 / Double(max(text.count, 1)))
                    for char in text {
                        shown.append(char)
                        try? await Task.sleep(nanoseconds: UInt64(perChar * 1_000_000_000))
                    }
                    onDone?()
                }
            }
    }
}

// MARK: - Typing Dots(打字动画)

struct BrewTypingDots: View {
    @State private var animating = false
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(themeColor.opacity(0.45))
                    .frame(width: 7, height: 7)
                    .offset(y: animating ? -3 : 2)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16)
                .fill(Color.white)
        )
        .onAppear { animating = true }
    }
}
