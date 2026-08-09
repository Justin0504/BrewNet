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
        case startersOffer(profile: BrewNetProfile)  // 报喜后:要开场话题吗
        case prepOffer(profile: BrewNetProfile, when: String, location: String?)  // ☕ 见面前简报入口
        case weeklyBrew(profile: BrewNetProfile, reasons: [String], matchPercent: Int?, windowText: String?, venueText: String?)  // ☕ 每周一杯提案
        case incomingProposal(proposalId: String, profile: BrewNetProfile, windowText: String?, venueText: String?)  // 🤝 双盲提案(对方 Brew 发来)
        case externalIntroSetup   // 🌐 开放图谱:池外没人时,问用户心里有没有具体的人
        case externalIntroDraft(targetName: String, targetContext: String, initialText: String)  // 🌐 站外 intro 草稿(可编辑→生成分享链接)
        case externalIntroAccepted(targetName: String, email: String?)  // 🌐🎉 池外的人接受了 → 回流报喜 + 联系方式
        case followUpOffer(profile: BrewNetProfile, daysSince: Int)  // 🤝 见过的人:要不要发条保持联系
        case followUpDraft(name: String, initialText: String)        // 🤝 跟进话术草稿(可编辑→分享)
        case winCardOffer(profile: BrewNetProfile)                   // 🏆 好咖啡后:晒战绩卡片(社会证明)
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
    @State private var shareIntroURL: URL?          // 🌐 站外 intro 生成的分享链接
    @State private var shareIntroText: String?      // 🤝 跟进话术等纯文本分享
    @State private var shareWinImage: UIImage?      // 🏆 战绩卡片图片分享
    @State private var showingIntroShare = false
    @State private var didGreet = false
    @State private var animatedMessageIds: Set<UUID> = []  // 打字机动画只放一次
    @FocusState private var composerFocused: Bool

    private var themeColor: Color { Brew.brand }
    private var backgroundColor: Color { Brew.bg }

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
                        .background(Capsule().fill(Brew.brandFill))
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
            PushManager.shared.requestIfAppropriate()   // 🔔 权限请求/token 注册(内部去重)
            loadRequesterProfile()
            Task {
                // 🌟 首开:兑换注册时填的邀请码(会话此时已就绪)→ founding 报喜
                await maybeRedeemPendingInvite()
                // 🌐 首开:认领站外 lead(用户接受 intro 时留的网络意图)→ 直接种 mission 并开搜
                if await maybeClaimLead() { return }

                let proactiveRunStarted = await MainActor.run { greetIfNeeded() }
                if proactiveRunStarted { return }
                // 优先级:🌐站外接受 > 🤝双盲提案 > 报喜 > 见面简报 > worth-it;一次会话只推一件事
                let extAccepted = await maybeAnnounceExternalAcceptance()
                if extAccepted { return }
                let proposal = await maybeShowIncomingProposal()
                if !proposal {
                    let announced = await maybeAnnounceAcceptances()
                    if !announced {
                        let prepped = await maybeOfferCoffeePrep()
                        if !prepped {
                            // 🤝 留存钩子:见过的人该保持联系了
                            let followUp = await maybeOfferFollowUp()
                            if !followUp {
                                await MainActor.run { maybeAskWorthIt() }
                            }
                        }
                    }
                }
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
        .sheet(isPresented: $showingIntroShare) {
            if let image = shareWinImage {
                ActivityShareSheet(items: [image, "Networking, handled — by Brew, my AI networking agent. ☕️"])
            } else if let text = shareIntroText {
                ActivityShareSheet(items: [text])
            } else if let url = shareIntroURL {
                ActivityShareSheet(items: [
                    "I'd love to grab a coffee — here's a quick way to say yes:",
                    url
                ])
            }
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
                    .background(Circle().fill(Brew.surface))
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
                            .fill(Brew.surface)
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
                    .background(RoundedRectangle(cornerRadius: 16).fill(Brew.brandFill))
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
                    if worthIt {
                        appendAgent("Love to hear it! I'll look for more people like \(name).")
                        messages.append(BrewMessage(kind: .winCardOffer(profile: profile)))
                    } else {
                        appendAgent("Got it — I'll adjust what I look for. Thanks for telling me.")
                    }
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
        case .startersOffer(let profile):
            Button {
                Task { await fetchStarters(for: profile) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                    Text("Get conversation starters for \(profile.coreIdentity.name.components(separatedBy: " ").first ?? "them")")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Brew.surface))
                .overlay(Capsule().stroke(themeColor.opacity(0.3), lineWidth: 1.2))
            }
        case .weeklyBrew(let profile, let reasons, let matchPercent, let windowText, let venueText):
            WeeklyBrewCard(
                profile: profile,
                reasons: reasons,
                matchPercent: matchPercent,
                windowText: windowText,
                venueText: venueText,
                isEngaged: engagedProfileIds.contains(profile.userId),
                onTap: { selectedProfile = profile },
                onSetup: {
                    Task { await setupWeeklyBrew(profile: profile, windowText: windowText, venueText: venueText) }
                },
                onSkip: {
                    if let uid = authManager.currentUser?.id {
                        BrewMemoryStore.shared.recordDeclined(name: profile.coreIdentity.name, userId: uid)
                    }
                    appendAgent("No worries — I'll bring someone different next week. You can still search anytime.")
                }
            )
        case .incomingProposal(let proposalId, let profile, let windowText, let venueText):
            IncomingProposalCard(
                profile: profile,
                windowText: windowText,
                venueText: venueText,
                onTap: { selectedProfile = profile },
                onAccept: {
                    Task { await acceptProposal(proposalId: proposalId, profile: profile, windowText: windowText, venueText: venueText) }
                },
                onPass: {
                    Task {
                        struct StatusOnly: Encodable { let status: String }
                        _ = try? await supabaseService.supabase.from("brew_proposals")
                            .update(StatusOnly(status: "declined")).eq("id", value: proposalId).execute()
                    }
                    appendAgent("Passed — and they'll never know. I've noted your taste for next time.")
                    if let uid = authManager.currentUser?.id {
                        BrewMemoryStore.shared.recordDeclined(name: profile.coreIdentity.name, userId: uid)
                    }
                }
            )
        case .externalIntroSetup:
            BrewExternalIntroSetupCard(
                onDraft: { name, context in
                    Task { await draftExternalIntro(targetName: name, targetContext: context) }
                }
            )
        case .externalIntroDraft(let targetName, let targetContext, let initialText):
            BrewExternalIntroDraftCard(
                targetName: targetName,
                initialText: initialText,
                onShare: { finalText in
                    Task { await createAndShareIntro(targetName: targetName, targetContext: targetContext, message: finalText) }
                }
            )
        case .externalIntroAccepted(let targetName, let email):
            BrewExternalIntroAcceptedCard(targetName: targetName, email: email)
        case .followUpOffer(let profile, _):
            Button {
                Task { await draftFollowUpFor(profile: profile) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 14))
                    Text("Draft a note to \(profile.coreIdentity.name.components(separatedBy: " ").first ?? "them")")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Brew.surface))
                .overlay(Capsule().stroke(themeColor.opacity(0.2), lineWidth: 1))
            }
        case .followUpDraft(let name, let initialText):
            BrewExternalIntroDraftCard(
                title: "Keep in touch with \(name.components(separatedBy: " ").first ?? name)",
                initialText: initialText,
                helper: "Send it however you like — text, email, LinkedIn. Staying in touch is how coffees turn into a real network.",
                buttonLabel: "Share note",
                doneLabel: "Ready to send",
                onShare: { finalText in
                    shareWinImage = nil
                    shareIntroURL = nil
                    shareIntroText = finalText
                    showingIntroShare = true
                    if let uid = authManager.currentUser?.id {
                        BrewMemoryStore.shared.recordFollowedUp(name: name, userId: uid)
                    }
                }
            )
        case .winCardOffer(let profile):
            Button {
                shareWinCard(for: profile)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                    Text("Share your win")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Brew.goldDeep)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Brew.goldSoftBg))
                .overlay(Capsule().stroke(Brew.goldFill.opacity(0.4), lineWidth: 1))
            }
        case .prepOffer(let profile, let when, let location):
            Button {
                Task { await fetchPrepBrief(for: profile, when: when, location: location) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14))
                    Text("Prep me for coffee with \(profile.coreIdentity.name.components(separatedBy: " ").first ?? "them")")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Brew.surface))
                .overlay(Capsule().stroke(themeColor.opacity(0.3), lineWidth: 1.2))
            }
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
                        .background(Capsule().fill(Brew.surface))
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
                            BrewTheme.accentColor.opacity(0.25)
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
                .background(RoundedRectangle(cornerRadius: 20).fill(Brew.surface))
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
                    messages.append(BrewMessage(kind: .agentText("No strong fits in the pool right now — but I've saved this as your mission and I'll report back the moment someone good joins.")))
                    // 🌐 开放图谱:池外没人 ≠ 无解,agent 可以主动去够到还没加入的人
                    messages.append(BrewMessage(kind: .agentText("Got someone specific in mind? I can reach out on your behalf — even if they're not on BrewNet yet.")))
                    messages.append(BrewMessage(kind: .externalIntroSetup))
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

    // MARK: - 🌐 站外 warm intro(开放图谱)

    /// 用户填了目标名字+背景 → agent 起草站外 intro
    private func draftExternalIntro(targetName: String, targetContext: String) async {
        let name = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        await MainActor.run { isThinking = true }
        let draft = await BrewAgentService.shared.draftExternalIntro(
            requester: currentUserProfile,
            targetName: name,
            targetContext: targetContext,
            goal: lastGoal.isEmpty ? "a coffee chat to learn from them" : lastGoal
        )
        let firstName = name.components(separatedBy: " ").first ?? name
        let fallback = "Hi \(firstName), I came across your work and would genuinely love to learn from your experience over a coffee sometime this week — would you be open to it?"
        await MainActor.run {
            isThinking = false
            messages.append(BrewMessage(kind: .externalIntroDraft(targetName: name, targetContext: targetContext, initialText: draft ?? fallback)))
            history.append(BrewChatEntry(role: .agent, text: "Drafted an external warm intro to \(name)."))
        }
    }

    /// 落库 external_intros → 拿 token → 拼落地页 URL → 弹系统分享面板
    private func createAndShareIntro(targetName: String, targetContext: String, message: String) async {
        guard let currentUser = authManager.currentUser else { return }
        await MainActor.run { isThinking = true }

        let headline: String? = {
            var parts: [String] = []
            if let t = currentUserProfile?.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
            if let c = currentUserProfile?.professionalBackground.currentCompany, !c.isEmpty { parts.append("at \(c)") }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        struct IntroInsert: Encodable {
            let inviter_id: String, inviter_name: String, inviter_headline: String?
            let target_name: String, target_context: String, message: String
        }
        struct IntroRow: Decodable { let token: String }
        do {
            let resp = try await supabaseService.supabase.from("external_intros")
                .insert(IntroInsert(
                    inviter_id: currentUser.id.lowercased(),
                    inviter_name: currentUserProfile?.coreIdentity.name ?? currentUser.name,
                    inviter_headline: headline,
                    target_name: targetName,
                    target_context: targetContext,
                    message: message
                ))
                .select("token").single().execute()
            let token = (try JSONDecoder().decode(IntroRow.self, from: resp.data)).token
            let url = URL(string: "https://jcxvdolcdifdghaibspy.supabase.co/functions/v1/intro?token=\(token)")

            await MainActor.run {
                isThinking = false
                shareWinImage = nil
                shareIntroText = nil
                shareIntroURL = url
                showingIntroShare = true
                let firstName = targetName.components(separatedBy: " ").first ?? targetName
                messages.append(BrewMessage(kind: .agentText("Link's ready — send it to \(firstName) however you like (text, email, LinkedIn). The moment they tap accept, I'll ping you and help you lock in the coffee.")))
                history.append(BrewChatEntry(role: .agent, text: "Created shareable warm-intro link for \(targetName)."))
            }
        } catch {
            await MainActor.run {
                isThinking = false
                messages.append(BrewMessage(kind: .note("Couldn't create the intro link — try again in a moment.")))
            }
            print("❌ [ExternalIntro] create failed: \(error)")
        }
    }

    /// 🏆 渲染战绩卡片为图片并分享(社会证明 → 免费顶部流量)
    private func shareWinCard(for profile: BrewNetProfile) {
        let card = WinShareCard(
            meName: currentUserProfile?.coreIdentity.name.components(separatedBy: " ").first,
            otherFirstName: profile.coreIdentity.name.components(separatedBy: " ").first ?? profile.coreIdentity.name,
            otherRole: winRoleLine(for: profile)
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareIntroURL = nil
            shareIntroText = nil
            shareWinImage = image
            showingIntroShare = true
        }
    }

    /// "Product manager at TikTok" / "at Stripe" / nil
    private func winRoleLine(for profile: BrewNetProfile) -> String? {
        var parts: [String] = []
        if let t = profile.professionalBackground.jobTitle, !t.isEmpty { parts.append(t) }
        if let c = profile.professionalBackground.currentCompany, !c.isEmpty { parts.append("at \(c)") }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
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

        // ☕ Weekly Brew:每周一次,Brew 直接端上"这周就见这个人"的完整提案
        // (mission 刚跑过、且到周了才触发 → 与 mission 自动跑自然错峰)
        if let uid = userId, BrewMemoryStore.shared.weeklyBrewDue(userId: uid) {
            let greeting = "☕️ It's Weekly Brew time\(firstName.map { ", \($0)" } ?? "")! Once a week I pick ONE person actually worth your coffee. Give me a moment…"
            messages.append(BrewMessage(kind: .agentText(greeting)))
            history.append(BrewChatEntry(role: .agent, text: greeting))
            Task {
                await MainActor.run { isThinking = true }
                await runWeeklyBrew()
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

        // 🌱 池子活性播报:本周新加入的人数(查询失败静默跳过)
        Task {
            let weekAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 24 * 3600))
            if let response = try? await SupabaseConfig.shared.client
                .from("profiles")
                .select("user_id", head: true, count: .exact)
                .gte("created_at", value: weekAgo)
                .execute(),
               let count = response.count, count > 0 {
                await MainActor.run {
                    messages.append(BrewMessage(kind: .note("🌱 \(count) new \(count == 1 ? "person" : "people") joined this week")))
                }
            }
        }
        return false
    }

    /// 🎉 结果回报:我发出的邀请被接受了 → Brew 报喜 + 提供开场话题
    private func maybeAnnounceAcceptances() async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        let memory = BrewMemoryStore.shared.load(userId: currentUser.id)
        let sentNames = Set(memory.sentInviteNames)
        guard !sentNames.isEmpty else { return false }
        let alreadyAnnounced = Set(memory.announcedMatchNames ?? [])

        guard let matches = try? await supabaseService.getActiveMatches(userId: currentUser.id),
              !matches.isEmpty else { return false }

        for match in matches {
            let otherId = match.userId == currentUser.id ? match.matchedUserId : match.userId
            guard let supabaseProfile = try? await supabaseService.getProfile(userId: otherId) else { continue }
            let profile = supabaseProfile.toBrewNetProfile()
            let name = profile.coreIdentity.name
            guard sentNames.contains(name), !alreadyAnnounced.contains(name) else { continue }

            // 🗓 预约 AI 化:双方空闲时段交集 → 直接给可行的见面窗口
            let overlapWindows = timeslotOverlap(me: currentUserProfile, them: profile)
            await MainActor.run {
                messages.append(BrewMessage(kind: .agentText("🎉 Great news — \(name) accepted your invitation! Your coffee chat is on.")))
                messages.append(BrewMessage(kind: .startersOffer(profile: profile)))
                if !overlapWindows.isEmpty {
                    let windows = overlapWindows.prefix(2).joined(separator: " or ")
                    messages.append(BrewMessage(kind: .agentText("Timing tip: you're both usually free \(windows) — good windows to propose when you schedule the coffee ☕️")))
                }
                history.append(BrewChatEntry(role: .agent, text: "Announced: \(name) accepted the invitation."))
            }
            BrewMemoryStore.shared.recordAnnouncedMatch(name: name, userId: currentUser.id)
            return true   // 一次会话报一件喜,不刷屏
        }
        return false
    }

    /// ☕ Weekly Brew:搜出本周唯一精选 + 时段窗口,端出完整提案
    private func runWeeklyBrew() async {
        guard let currentUser = authManager.currentUser else {
            await MainActor.run { isThinking = false }
            return
        }
        BrewMemoryStore.shared.recordWeeklyBrewShown(userId: currentUser.id)

        let memory = BrewMemoryStore.shared.load(userId: currentUser.id)
        let excludeNames = Set(memory.sentInviteNames + memory.declinedNames)
        let goal = memory.activeMission?.goal ?? "interesting professionals nearby worth meeting for a coffee"
        lastGoal = goal

        let outcome = try? await ScoutSearchEngine.shared.search(
            query: goal,
            currentUserId: currentUser.id,
            currentUserProfile: currentUserProfile,
            topCount: 3,
            excludeNames: excludeNames
        )
        guard let top = outcome?.top.first else {
            await MainActor.run {
                isThinking = false
                messages.append(BrewMessage(kind: .agentText("The pool's a bit quiet this week — I'll keep scouting and bring you someone great next week.")))
            }
            return
        }

        let windows = timeslotOverlap(me: currentUserProfile, them: top.profile)
        let windowText = windows.first
        // 🏙 场地规划:双方城市匹配的精选咖啡馆
        let venue = await pickVenue(myLocation: currentUserProfile?.coreIdentity.location,
                                    theirLocation: top.profile.coreIdentity.location)

        await MainActor.run {
            isThinking = false
            lastPicks = [top]
            messages.append(BrewMessage(kind: .weeklyBrew(
                profile: top.profile,
                reasons: top.reasons,
                matchPercent: top.matchPercent,
                windowText: windowText,
                venueText: venue
            )))
            let followUp: String
            if let w = windowText {
                followUp = venue != nil
                    ? "One tap and I'll propose \(w) at \(venue!). Fully planned — no back-and-forth."
                    : "One tap and I'll send an invite proposing \(w). No back-and-forth needed."
            } else {
                followUp = "One tap and I'll draft the invite for you."
            }
            messages.append(BrewMessage(kind: .agentText(followUp)))
            history.append(BrewChatEntry(role: .tool, text: BrewAgentService.toolResultSummary(for: [(top.profile, top.reasons)])))
        }
    }

    /// 🏙 从 brew_venues 里挑一个双方城市都命中的场地("Dulce · USC Village")
    private func pickVenue(myLocation: String?, theirLocation: String?) async -> String? {
        struct VenueRow: Decodable {
            let name: String, area: String?, city: String
        }
        guard let response = try? await supabaseService.supabase
            .from("brew_venues")
            .select("name,area,city")
            .eq("active", value: true)
            .execute(),
            let venues = try? JSONDecoder().decode([VenueRow].self, from: response.data),
            !venues.isEmpty else { return nil }

        let locs = [myLocation, theirLocation].compactMap { $0?.lowercased() }
        guard !locs.isEmpty else { return nil }
        // 双方都在场地城市 → 优先;只匹配一方也接受(v1)
        let scored = venues.map { v -> (VenueRow, Int) in
            let hits = locs.filter { $0.contains(v.city.lowercased()) }.count
            return (v, hits)
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        guard let best = scored.first?.0 else { return nil }
        return best.area.map { "\(best.name) · \($0)" } ?? best.name
    }

    /// ☕ Weekly Brew 的"就这么定"
    /// 有共同时段 → 🤝 双盲提案(Ditto 式:对方 Brew 收到,拒绝不回传,只有成了才庆祝)
    /// 无共同时段 → 传统时间锚定草稿(人在环上确认)
    private func setupWeeklyBrew(profile: BrewNetProfile, windowText: String?, venueText: String? = nil) async {
        guard let currentUser = authManager.currentUser else { return }

        if let window = windowText {
            // —— 双盲路径 ——
            struct ProposalInsert: Encodable {
                let proposer_id: String, target_id: String, proposer_name: String
                let window_text: String, proposed_date: String?, venue: String?
            }
            let proposedDate = concreteDate(for: window).map { ISO8601DateFormatter().string(from: $0) }
            let insert = ProposalInsert(
                proposer_id: currentUser.id.lowercased(),
                target_id: profile.userId.lowercased(),
                proposer_name: currentUser.name,
                window_text: window,
                proposed_date: proposedDate,
                venue: venueText
            )
            do {
                _ = try await supabaseService.supabase.from("brew_proposals").insert(insert).execute()
                BrewMemoryStore.shared.recordInviteSent(to: profile.coreIdentity.name, userId: currentUser.id)
                await MainActor.run {
                    let firstName = profile.coreIdentity.name.components(separatedBy: " ").first ?? "them"
                    let plan = venueText.map { "\(window) at \($0)" } ?? window
                    appendAgent("🤝 Done — I've quietly proposed \(plan) to \(firstName)'s Brew. If they're in, it books itself and I'll celebrate with you. If not… you'll simply meet someone else next week. No awkwardness, ever.")
                    history.append(BrewChatEntry(role: .tool, text: "Blind proposal sent to \(profile.coreIdentity.name): \(plan)."))
                }
            } catch {
                print("❌ [Handshake] proposal insert failed: \(error)")
                await MainActor.run { appendAgent("Hmm, couldn't reach their Brew just now — try again in a moment.") }
            }
            return
        }

        // —— 无共同时段:传统草稿路径 ——
        await MainActor.run { isThinking = true }
        let draft = await BrewAgentService.shared.draftInvite(
            requester: currentUserProfile,
            target: profile,
            conversationGoal: lastGoal.isEmpty ? "meet for a coffee chat" : lastGoal,
            timeHint: nil
        )
        let firstName = profile.coreIdentity.name.components(separatedBy: " ").first ?? profile.coreIdentity.name
        let fallbackDraft = "Hi \(firstName), Brew matched us this week and your background looks great — would sometime this week work for a quick coffee chat?"
        await MainActor.run {
            isThinking = false
            messages.append(BrewMessage(kind: .inviteDraft(profile: profile, initialText: draft ?? fallbackDraft)))
            history.append(BrewChatEntry(role: .agent, text: "Weekly Brew: drafted invite to \(profile.coreIdentity.name)."))
        }
    }

    /// 🌟 首次打开:兑换注册时暂存的邀请码(Supabase 会话此时已建立)
    private func maybeRedeemPendingInvite() async {
        guard let uid = authManager.currentUser?.id,
              let code = UserDefaults.standard.string(forKey: "brew_pending_invite"),
              !code.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: "brew_pending_invite")   // 只尝试一次
        let founding = (try? await FoundingService.shared.redeem(code: code, userId: uid)) ?? false
        if founding {
            await MainActor.run {
                appendAgent("🌟 Your founding invite is in — you've got BrewNet Pro free, for good. Welcome to the inner circle.")
            }
        }
    }

    /// 🌐 首次打开:认领用户在接受站外 intro 时留下的网络意图(brew_leads)
    /// 命中 → 直接种成 mission、欢迎、立即开搜。一人一次(UserDefaults 去重)。
    private func maybeClaimLead() async -> Bool {
        guard let uid = authManager.currentUser?.id else { return false }
        let flagKey = "brew_lead_claimed_\(uid)"
        if UserDefaults.standard.bool(forKey: flagKey) { return false }
        UserDefaults.standard.set(true, forKey: flagKey)   // 无论结果,只尝试一次

        struct LeadResult: Decodable { let intent: String?; let name: String? }
        guard let resp = try? await supabaseService.supabase.rpc("claim_brew_lead").execute(),
              let result = try? JSONDecoder().decode(LeadResult?.self, from: resp.data) ?? nil,
              let intent = result.intent, !intent.isEmpty else { return false }

        await MainActor.run {
            didGreet = true   // 抑制常规开场白
            let firstName = authManager.currentUser?.name.components(separatedBy: " ").first
            let greeting = "Welcome to BrewNet\(firstName.map { ", \($0)" } ?? "")! You mentioned you'd like to meet \(intent) — I already started scouting. Here's who fits…"
            messages.append(BrewMessage(kind: .agentText(greeting)))
            history.append(BrewChatEntry(role: .agent, text: greeting))
            lastGoal = intent
            isThinking = true
        }
        await runSearch(query: intent)   // 内部会把 intent 持久化为常驻 mission
        return true
    }

    /// 🌐🎉 池外的人接受了 warm intro → 回流报喜,把联系方式交给用户去敲定咖啡
    private func maybeAnnounceExternalAcceptance() async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        struct AcceptedRow: Decodable {
            let id: String, targetName: String, targetReplyEmail: String?
            enum CodingKeys: String, CodingKey {
                case id, targetName = "target_name", targetReplyEmail = "target_reply_email"
            }
        }
        guard let response = try? await supabaseService.supabase
            .from("external_intros")
            .select("id,target_name,target_reply_email")
            .eq("inviter_id", value: currentUser.id.lowercased())
            .eq("status", value: "accepted")
            .order("responded_at", ascending: false)
            .limit(5)
            .execute(),
            let rows = try? JSONDecoder().decode([AcceptedRow].self, from: response.data) else { return false }

        // 找第一条还没报喜过的
        guard let row = rows.first(where: {
            !BrewMemoryStore.shared.hasAnnouncedExternalIntro(id: $0.id, userId: currentUser.id)
        }) else { return false }

        let firstName = row.targetName.components(separatedBy: " ").first ?? row.targetName
        await MainActor.run {
            messages.append(BrewMessage(kind: .agentText("🎉 Big news — \(firstName) accepted your intro! Your reach just paid off.")))
            messages.append(BrewMessage(kind: .externalIntroAccepted(targetName: row.targetName, email: row.targetReplyEmail)))
            history.append(BrewChatEntry(role: .agent, text: "Announced external intro acceptance from \(row.targetName)."))
            BrewMemoryStore.shared.recordAnnouncedExternalIntro(id: row.id, userId: currentUser.id)
        }
        return true
    }

    /// 🤝 来件双盲提案(最高优先级):对方的 Brew 提议一起喝咖啡
    private func maybeShowIncomingProposal() async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        struct ProposalRow: Decodable {
            let id: String, proposerId: String, windowText: String?, venue: String?
            enum CodingKeys: String, CodingKey {
                case id, proposerId = "proposer_id", windowText = "window_text", venue
            }
        }
        let weekAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7 * 24 * 3600))
        guard let response = try? await supabaseService.supabase
            .from("brew_proposals")
            .select("id,proposer_id,window_text,venue")
            .eq("target_id", value: currentUser.id.lowercased())
            .eq("status", value: "pending")
            .gte("created_at", value: weekAgo)
            .order("created_at", ascending: false)
            .limit(1)
            .execute(),
            let rows = try? JSONDecoder().decode([ProposalRow].self, from: response.data),
            let row = rows.first else { return false }

        // 会话内去重:切 tab 反复触发 onAppear,同一提案卡只贴一次
        let alreadyShown = await MainActor.run {
            messages.contains {
                if case .incomingProposal(let pid, _, _, _) = $0.kind { return pid == row.id }
                return false
            }
        }
        if alreadyShown { return true }

        guard let supabaseProfile = try? await supabaseService.getProfile(userId: row.proposerId) else { return false }
        let profile = supabaseProfile.toBrewNetProfile()
        await MainActor.run {
            var planBits: [String] = []
            if let w = row.windowText { planBits.append("you're both free \(w)") }
            if let v = row.venue { planBits.append("place picked: \(v)") }
            let plan = planBits.isEmpty ? "" : " — \(planBits.joined(separator: ", "))"
            messages.append(BrewMessage(kind: .agentText("🤝 My counterpart on \(profile.coreIdentity.name)'s side thinks you two should grab coffee\(plan). One tap and it's booked. They won't know unless you say yes.")))
            messages.append(BrewMessage(kind: .incomingProposal(proposalId: row.id, profile: profile, windowText: row.windowText, venueText: row.venue)))
            history.append(BrewChatEntry(role: .agent, text: "Showed incoming blind proposal from \(profile.coreIdentity.name)."))
        }
        return true
    }

    /// 🤝 接受提案 = 自动成局:match + 带具体时间的咖啡预约,双边后续流程自动接管
    private func acceptProposal(proposalId: String, profile: BrewNetProfile, windowText: String?, venueText: String? = nil) async {
        guard let currentUser = authManager.currentUser else { return }
        await MainActor.run { isThinking = true }
        do {
            // 原子 RPC:提案→邀请→(触发器建双向 match)→咖啡预约,一步到位
            // 客户端替提案人写记录会被 RLS 拒(auth.uid ≠ sender),故下沉 SECURITY DEFINER
            struct AcceptParams: Encodable { let p_proposal_id: String; let p_scheduled_date: String? }
            let concrete = windowText.flatMap { concreteDate(for: $0) }.map { ISO8601DateFormatter().string(from: $0) }
            _ = try await supabaseService.supabase
                .rpc("accept_brew_proposal", params: AcceptParams(p_proposal_id: proposalId, p_scheduled_date: concrete))
                .execute()

            await MainActor.run {
                isThinking = false
                var plan = windowText.map { " \($0)" } ?? " this week"
                if let v = venueText { plan += " at \(v)" }
                appendAgent("☕️ It's on! You and \(profile.coreIdentity.name.components(separatedBy: " ").first ?? profile.coreIdentity.name) are meeting\(plan). I'll prep you before it — just show up.")
            }
        } catch {
            print("❌ [Handshake] accept failed: \(error)")
            await MainActor.run {
                isThinking = false
                appendAgent("Something hiccuped while booking — try once more?")
            }
        }
    }

    /// "Tuesday noon" → 下一个周二 12:00 的具体日期
    private func concreteDate(for window: String) -> Date? {
        let parts = window.split(separator: " ").map(String.init)
        guard parts.count == 2 else { return nil }
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        let hours = ["morning": 9, "noon": 12, "afternoon": 15, "evening": 18, "night": 20]
        guard let targetWeekday = weekdays[parts[0].lowercased()], let hour = hours[parts[1].lowercased()] else { return nil }
        var cal = Calendar.current
        cal.firstWeekday = 1
        let now = Date()
        for offset in 1...7 {
            if let candidate = cal.date(byAdding: .day, value: offset, to: now),
               cal.component(.weekday, from: candidate) == targetWeekday {
                return cal.date(bySettingHour: hour, minute: 0, second: 0, of: candidate)
            }
        }
        return nil
    }

    /// ☕ 见面前简报:检测即将到来的已接受 coffee chat,主动提供 prep

    /// ☕ 见面前简报:检测即将到来的已接受 coffee chat,主动提供 prep
    private func maybeOfferCoffeePrep() async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        let offered = Set(BrewMemoryStore.shared.load(userId: currentUser.id).prepOfferedNames ?? [])

        struct CoffeeInviteRow: Decodable {
            let senderId: String, receiverId: String, senderName: String?, receiverName: String?
            let scheduledDate: String?, location: String?
            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id", receiverId = "receiver_id"
                case senderName = "sender_name", receiverName = "receiver_name"
                case scheduledDate = "scheduled_date", location
            }
        }
        let rows: [CoffeeInviteRow]
        do {
            let uid = currentUser.id.lowercased()
            let response = try await supabaseService.supabase
                .from("coffee_chat_invitations")
                .select("sender_id,receiver_id,sender_name,receiver_name,scheduled_date,location")
                .eq("status", value: "accepted")
                .or("sender_id.eq.\(uid),receiver_id.eq.\(uid)")
                .gte("scheduled_date", value: ISO8601DateFormatter().string(from: Date()))
                .order("scheduled_date", ascending: true)
                .limit(3)
                .execute()
            rows = try JSONDecoder().decode([CoffeeInviteRow].self, from: response.data)
            print("☕️ [Prep] upcoming coffee rows: \(rows.count)")
        } catch {
            print("☕️ [Prep] query failed: \(error)")
            return false
        }
        guard !rows.isEmpty else { return false }

        for row in rows {
            let otherId = row.senderId == currentUser.id ? row.receiverId : row.senderId
            let otherName = (row.senderId == currentUser.id ? row.receiverName : row.senderName) ?? ""
            guard !offered.contains(otherName) || otherName.isEmpty else { continue }
            guard let supabaseProfile = try? await supabaseService.getProfile(userId: otherId) else { continue }
            let profile = supabaseProfile.toBrewNetProfile()
            let name = profile.coreIdentity.name
            guard !offered.contains(name) else { continue }

            // 友好时间串
            var whenText = "soon"
            if let ds = row.scheduledDate {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = iso.date(from: ds) ?? { iso.formatOptions = [.withInternetDateTime]; return iso.date(from: ds) }()
                if let date {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "EEEE, MMM d"
                    whenText = "on \(fmt.string(from: date))"
                }
            }

            await MainActor.run {
                messages.append(BrewMessage(kind: .agentText("☕️ Heads up — your coffee with \(name) is coming up \(whenText)\(row.location.map { " at \($0)" } ?? "").")))
                messages.append(BrewMessage(kind: .prepOffer(profile: profile, when: whenText, location: row.location)))
                history.append(BrewChatEntry(role: .agent, text: "Offered prep brief for upcoming coffee with \(name)."))
            }
            BrewMemoryStore.shared.recordPrepOffered(name: name, userId: currentUser.id)
            return true
        }
        return false
    }

    /// 🤝 关系跟进(留存核心):见过的人 >10 天没联系 → 提醒并可起草保持联系的话
    private func maybeOfferFollowUp() async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }

        struct CoffeeRow: Decodable {
            let senderId: String, receiverId: String, senderName: String?, receiverName: String?
            let scheduledDate: String?
            enum CodingKeys: String, CodingKey {
                case senderId = "sender_id", receiverId = "receiver_id"
                case senderName = "sender_name", receiverName = "receiver_name"
                case scheduledDate = "scheduled_date"
            }
        }
        let uid = currentUser.id.lowercased()
        let tenDaysAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-10 * 24 * 3600))
        guard let response = try? await supabaseService.supabase
            .from("coffee_chat_invitations")
            .select("sender_id,receiver_id,sender_name,receiver_name,scheduled_date")
            .eq("status", value: "accepted")
            .or("sender_id.eq.\(uid),receiver_id.eq.\(uid)")
            .not("scheduled_date", operator: .is, value: "null")
            .lte("scheduled_date", value: tenDaysAgo)   // 见面已过去 ≥10 天
            .order("scheduled_date", ascending: false)
            .limit(5)
            .execute(),
            let rows = try? JSONDecoder().decode([CoffeeRow].self, from: response.data) else { return false }

        for row in rows {
            let otherId = row.senderId == currentUser.id ? row.receiverId : row.senderId
            guard let supabaseProfile = try? await supabaseService.getProfile(userId: otherId) else { continue }
            let profile = supabaseProfile.toBrewNetProfile()
            let name = profile.coreIdentity.name
            guard !BrewMemoryStore.shared.hasFollowedUp(name: name, userId: currentUser.id) else { continue }

            var days = 14
            if let ds = row.scheduledDate {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = iso.date(from: ds) ?? { iso.formatOptions = [.withInternetDateTime]; return iso.date(from: ds) }()
                if let date { days = max(1, Int(Date().timeIntervalSince(date) / 86400)) }
            }

            let firstName = name.components(separatedBy: " ").first ?? name
            await MainActor.run {
                messages.append(BrewMessage(kind: .agentText("🤝 It's been about \(days) days since your coffee with \(firstName). A quick note now keeps the relationship warm — want me to draft one?")))
                messages.append(BrewMessage(kind: .followUpOffer(profile: profile, daysSince: days)))
                history.append(BrewChatEntry(role: .agent, text: "Offered a keep-in-touch follow-up for \(name)."))
                BrewMemoryStore.shared.recordFollowedUp(name: name, userId: currentUser.id)
            }
            return true
        }
        return false
    }

    /// 🤝 起草保持联系的话术
    private func draftFollowUpFor(profile: BrewNetProfile) async {
        await MainActor.run { isThinking = true }
        let text = await BrewAgentService.shared.draftFollowUp(requester: currentUserProfile, target: profile)
        let firstName = profile.coreIdentity.name.components(separatedBy: " ").first ?? profile.coreIdentity.name
        let fallback = "Hi \(firstName), really enjoyed our coffee — I've been thinking about what you said. Would love to stay in touch and hear how things are going on your end. Coffee again sometime?"
        await MainActor.run {
            isThinking = false
            messages.append(BrewMessage(kind: .followUpDraft(name: profile.coreIdentity.name, initialText: text ?? fallback)))
            history.append(BrewChatEntry(role: .agent, text: "Drafted a follow-up note for \(profile.coreIdentity.name)."))
        }
    }

    /// ☕ 生成并展示见面简报
    private func fetchPrepBrief(for profile: BrewNetProfile, when: String, location: String?) async {
        await MainActor.run { isThinking = true }
        let brief = await BrewAgentService.shared.meetingPrepBrief(
            requester: currentUserProfile,
            target: profile,
            when: when,
            location: location
        )
        await MainActor.run {
            isThinking = false
            if let brief {
                appendAgent(brief)
                appendAgent("Good luck — tell me how it went afterwards! 📊")
            } else {
                appendAgent("Couldn't pull my notes just now — try again in a moment.")
            }
        }
    }

    /// 🗓 双方空闲时段交集(确定性计算,无需 LLM)
    private func timeslotOverlap(me: BrewNetProfile?, them: BrewNetProfile) -> [String] {
        guard let me else { return [] }
        let mine = me.networkingPreferences.availableTimeslot
        let theirs = them.networkingPreferences.availableTimeslot
        let days: [(String, DayTimeslots, DayTimeslots)] = [
            ("Monday", mine.monday, theirs.monday),
            ("Tuesday", mine.tuesday, theirs.tuesday),
            ("Wednesday", mine.wednesday, theirs.wednesday),
            ("Thursday", mine.thursday, theirs.thursday),
            ("Friday", mine.friday, theirs.friday),
            ("Saturday", mine.saturday, theirs.saturday),
            ("Sunday", mine.sunday, theirs.sunday),
        ]
        var windows: [String] = []
        for (day, m, t) in days {
            if m.morning && t.morning { windows.append("\(day) morning") }
            if m.noon && t.noon { windows.append("\(day) noon") }
            if m.afternoon && t.afternoon { windows.append("\(day) afternoon") }
            if m.evening && t.evening { windows.append("\(day) evening") }
        }
        return windows
    }

    /// 💡 生成开场话题(报喜后的下一步动作)
    private func fetchStarters(for profile: BrewNetProfile) async {
        await MainActor.run { isThinking = true }
        let starters = await BrewAgentService.shared.conversationStarters(
            requester: currentUserProfile,
            target: profile
        )
        await MainActor.run {
            isThinking = false
            if let starters {
                appendAgent("Here's what I'd open with:\n\(starters)")
            } else {
                appendAgent("I couldn't reach my notes just now — try again in a moment.")
            }
        }
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
        if env["BREWNET_DEBUG_INTRO"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                messages.append(BrewMessage(kind: .agentText("Got someone specific in mind? I can reach out on your behalf — even if they're not on BrewNet yet.")))
                messages.append(BrewMessage(kind: .externalIntroSetup))
            }
            return
        }
        if env["BREWNET_DEBUG_WIN"] == "1" {
            Task {
                guard let sp = try? await supabaseService.getProfile(userId: "dbc9a570-a933-43ca-a205-6e367bf406dc") else { return }
                let p = sp.toBrewNetProfile()
                await MainActor.run {
                    messages.append(BrewMessage(kind: .agentText("Love to hear it! I'll look for more people like \(p.coreIdentity.name).")))
                    messages.append(BrewMessage(kind: .winCardOffer(profile: p)))
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { shareWinCard(for: p) }   // 自动弹分享面板便于验收
            }
            return
        }
        if env["BREWNET_DEBUG_INTRO"] == "2" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                messages.append(BrewMessage(kind: .externalIntroDraft(
                    targetName: "Alex Rivera",
                    targetContext: "PM at Stripe, ex-Google",
                    initialText: "Hi Alex — I'm building an AI networking agent and your work on Stripe's onboarding is exactly the kind of thing I'd love to learn from. Could I buy you a coffee this week?")))
            }
            return
        }
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

    private var themeColor: Color { Brew.brand }

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
                            .background(Capsule().fill(Brew.brandFill))
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    HStack(spacing: 5) {
                        // 🏢 真实公司 logo(Logo.dev,解析失败首字母兜底)
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            BrandLogoView(name: company, size: 15)
                        }
                        Text(headline)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(themeColor)
                            .lineLimit(2)
                    }
                    // 🤝 共同点前置 chip(同校/同城,1 秒可扫描)
                    if let connection = connectionChip {
                        Text(connection)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Brew.chipGreenText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Brew.chipGreenBg))
                    }
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
                                        Brew.gold,
                                        Brew.goldDeep
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
                            .fill(Brew.goldSoftBg)
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
                    .background(RoundedRectangle(cornerRadius: 12).fill(isEngaged ? Color.gray.opacity(0.15) : Brew.brandFill))
            }
            .disabled(isEngaged)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
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

    /// 同校/同城理由前置为徽章(从 reasons 里识别密度加权信号)
    private var connectionChip: String? {
        if reasons.contains(where: { $0.localizedCaseInsensitiveContains("same school") || $0.localizedCaseInsensitiveContains("fellow alum") }) {
            return "🎓 Same school"
        }
        if reasons.contains(where: { $0.localizedCaseInsensitiveContains("same city") || $0.localizedCaseInsensitiveContains("nearby") }) {
            return "📍 Same city"
        }
        return nil
    }

    private var avatar: some View {
        Group {
            if let urlString = profile.coreIdentity.profileImage, let url = URL(string: urlString) {
                CachedAsyncImagePhase(url: url) { phase in
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

// MARK: - 🌐 站外 Warm Intro:setup 卡(问"想约谁")

struct BrewExternalIntroSetupCard: View {
    var onDraft: (String, String) -> Void

    @State private var name = ""
    @State private var context = ""
    @State private var submitted = false

    private var themeColor: Color { Brew.brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeColor.opacity(0.7))
                Text("Reach someone new")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeColor.opacity(0.8))
            }

            TextField("Who? (name)", text: $name)
                .font(.system(size: 14))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Brew.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.12), lineWidth: 1))

            TextField("What do you know about them? (role, company, why them)", text: $context, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(2...4)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Brew.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.12), lineWidth: 1))

            Button {
                guard !name.trimmingCharacters(in: .whitespaces).isEmpty, !submitted else { return }
                submitted = true
                onDraft(name, context)
            } label: {
                Text("Draft the intro")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(
                        (name.trimmingCharacters(in: .whitespaces).isEmpty || submitted)
                        ? Color.gray.opacity(0.4) : Brew.brandFill))
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || submitted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeColor.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - 🌐 站外 Warm Intro:草稿卡(可编辑 → 生成分享链接)

struct BrewExternalIntroDraftCard: View {
    let title: String
    let initialText: String
    let helper: String
    let buttonLabel: String
    let doneLabel: String
    var onShare: (String) -> Void

    @State private var text: String
    @State private var didAct = false

    private var themeColor: Color { Brew.brand }

    // 站外 intro 默认文案
    init(targetName: String, initialText: String, onShare: @escaping (String) -> Void) {
        self.title = "Intro to \(targetName)"
        self.initialText = initialText
        self.helper = "They tap one link to say yes — no download needed. You'll get pinged the moment they do."
        self.buttonLabel = "Create link & share"
        self.doneLabel = "Link created"
        self.onShare = onShare
        _text = State(initialValue: initialText)
    }

    // 通用初始化(跟进话术等)
    init(title: String, initialText: String, helper: String, buttonLabel: String, doneLabel: String, onShare: @escaping (String) -> Void) {
        self.title = title
        self.initialText = initialText
        self.helper = helper
        self.buttonLabel = buttonLabel
        self.doneLabel = doneLabel
        self.onShare = onShare
        _text = State(initialValue: initialText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "paperplane.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeColor.opacity(0.7))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeColor.opacity(0.8))
                Spacer()
                Text("Edit freely")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(minHeight: 90)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Brew.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(themeColor.opacity(0.12), lineWidth: 1))

            Text(helper)
                .font(.system(size: 11))
                .foregroundColor(.gray)

            Button {
                guard !didAct else { return }
                didAct = true
                onShare(text)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text(didAct ? doneLabel : buttonLabel)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : Brew.brandFill))
            }
            .disabled(didAct)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeColor.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - 🌐🎉 站外 intro 被接受:回流报喜卡(含联系方式一键复制/邮件)

struct BrewExternalIntroAcceptedCard: View {
    let targetName: String
    let email: String?

    @State private var copied = false
    private var themeColor: Color { Brew.brand }
    private var firstName: String { targetName.components(separatedBy: " ").first ?? targetName }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Brew.teal.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Brew.teal)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(firstName) is in ☕️")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Text("They accepted your warm intro")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            if let email, !email.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 13))
                        .foregroundColor(themeColor.opacity(0.7))
                    Text(email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = email
                        withAnimation { copied = true }
                    } label: {
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(copied ? .gray : themeColor)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Brew.surfaceRaised))

                Link(destination: URL(string: "mailto:\(email)?subject=\(coffeeSubject)")!) {
                    Text("Email \(firstName) to lock in the coffee")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Brew.brandFill))
                }
            } else {
                Text("They didn't leave contact info — but they're expecting to hear from you. Reach out through the channel you sent this on.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brew.teal.opacity(0.25), lineWidth: 1))
    }

    private var coffeeSubject: String {
        "Coffee ☕️".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Coffee"
    }
}

// MARK: - 🏆 战绩可晒卡片(渲染成图片发 LinkedIn/朋友圈)

struct WinShareCard: View {
    let meName: String?
    let otherFirstName: String
    let otherRole: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部品牌条
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                Text("BrewNet")
                    .font(.system(size: 18, weight: .heavy))
                Spacer()
                Text("AI networking agent")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .padding(20)
            .background(Color(red: 0.40, green: 0.20, blue: 0.10))

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color(red: 0.40, green: 0.20, blue: 0.10))

                Text("Another great coffee ☕️")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(red: 0.25, green: 0.15, blue: 0.08))

                Text(bodyLine)
                    .font(.system(size: 17))
                    .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.22))
                    .fixedSize(horizontal: false, vertical: true)

                Text("My agent found them, broke the ice, and booked it. I just showed up.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(width: 340)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var bodyLine: String {
        let who = otherRole.map { "\(otherFirstName), \($0)" } ?? otherFirstName
        return "I just had a great coffee chat with \(who) — set up by Brew, my AI networking agent."
    }
}

// MARK: - 系统分享面板包装

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct BrewInviteDraftCard: View {
    let profile: BrewNetProfile
    let initialText: String
    let alreadySent: Bool
    var onSend: (String) -> Void
    var onCancel: () -> Void

    @State private var text: String
    @State private var didAct = false

    private var themeColor: Color { Brew.brand }

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
                .background(RoundedRectangle(cornerRadius: 10).fill(Brew.surfaceRaised))
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
                        .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : Brew.brandFill))
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeColor.opacity(0.25), lineWidth: 1.5)
        )
    }
}

// MARK: - Weekly Brew Card(☕ 每周一杯:一人 + 一个时间窗 + 一键成局)

struct WeeklyBrewCard: View {
    let profile: BrewNetProfile
    let reasons: [String]
    var matchPercent: Int? = nil
    let windowText: String?
    var venueText: String? = nil
    let isEngaged: Bool
    var onTap: () -> Void
    var onSetup: () -> Void
    var onSkip: () -> Void

    @State private var didAct = false
    private var themeColor: Color { Brew.brand }
    private var gold: Color { Brew.gold }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 周选头带
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(gold)
                Text("THIS WEEK'S BREW")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(1)
                    .foregroundColor(gold)
                Spacer()
                if let percent = matchPercent, percent > 0 {
                    Text("\(percent)% match")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(gold)
                }
            }

            BrewPickCard(
                profile: profile,
                reasons: reasons,
                rank: 1,
                matchPercent: nil,
                isEngaged: isEngaged,
                onTap: onTap,
                onConnect: onSetup
            )
            .allowsHitTesting(false)  // 内嵌卡只做展示,动作由下方按钮承担
            .overlay(Color.clear.contentShape(Rectangle()).onTapGesture(perform: onTap))

            if windowText != nil || venueText != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let window = windowText {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 14))
                                .foregroundColor(themeColor)
                            Text("You're both free **\(window)**")
                                .font(.system(size: 14))
                                .foregroundColor(themeColor)
                        }
                    }
                    if let venue = venueText {
                        HStack(spacing: 8) {
                            // ☕ 场地真实 logo
                            BrandLogoView(name: venue.components(separatedBy: " ·").first ?? venue, size: 16)
                            Text("**\(venue)**")
                                .font(.system(size: 14))
                                .foregroundColor(themeColor)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(gold.opacity(0.1)))
            }

            HStack(spacing: 10) {
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onSetup()
                } label: {
                    Label(windowText != nil ? "Set it up" : "Draft the invite", systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(
                                didAct ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(
                                    LinearGradient(colors: [Brew.goldFill, Brew.goldFillDeep],
                                                   startPoint: .top, endPoint: .bottom))
                            )
                        )
                }
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onSkip()
                } label: {
                    Text("Not this week")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(themeColor.opacity(0.08)))
                }
            }
            .disabled(didAct)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Brew.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(LinearGradient(colors: [gold.opacity(0.7), gold.opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: gold.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Incoming Proposal Card(🤝 双盲提案:对方 Brew 发来,拒绝无痕)

struct IncomingProposalCard: View {
    let profile: BrewNetProfile
    let windowText: String?
    var venueText: String? = nil
    var onTap: () -> Void
    var onAccept: () -> Void
    var onPass: () -> Void

    @State private var didAct = false
    private var themeColor: Color { Brew.brand }
    private var teal: Color { Brew.teal }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 12))
                    .foregroundColor(teal)
                Text("BREW HANDSHAKE")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(1)
                    .foregroundColor(teal)
                Spacer()
                Text("They won't see a no")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            BrewPickCard(
                profile: profile, reasons: [], rank: 1, matchPercent: nil,
                isEngaged: false, onTap: onTap, onConnect: onAccept
            )
            .allowsHitTesting(false)
            .overlay(Color.clear.contentShape(Rectangle()).onTapGesture(perform: onTap))

            if windowText != nil || venueText != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let window = windowText {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 14))
                                .foregroundColor(teal)
                            Text("Proposed: **\(window)** — accepting books it instantly")
                                .font(.system(size: 14))
                                .foregroundColor(themeColor)
                        }
                    }
                    if let venue = venueText {
                        HStack(spacing: 8) {
                            BrandLogoView(name: venue.components(separatedBy: " ·").first ?? venue, size: 16)
                            Text("**\(venue)**")
                                .font(.system(size: 14))
                                .foregroundColor(themeColor)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(teal.opacity(0.08)))
            }

            HStack(spacing: 10) {
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onAccept()
                } label: {
                    Label("I'm in", systemImage: "cup.and.saucer.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : Brew.tealFill))
                }
                Button {
                    guard !didAct else { return }
                    didAct = true
                    onPass()
                } label: {
                    Text("Pass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(themeColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(themeColor.opacity(0.08)))
                }
            }
            .disabled(didAct)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Brew.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(teal.opacity(0.4), lineWidth: 1.5))
        .shadow(color: teal.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Worth-It Card(📊 北极星指标:见面后一键回访)

struct BrewWorthItCard: View {
    let profile: BrewNetProfile
    var onAnswer: (Bool) -> Void
    var onNotMetYet: () -> Void

    @State private var didAct = false
    private var themeColor: Color { Brew.brand }

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
                        .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : Brew.brandFill))
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Brew.surface))
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
    private var themeColor: Color { Brew.brand }

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
                .fill(Brew.surface)
        )
        .onAppear { animating = true }
    }
}
