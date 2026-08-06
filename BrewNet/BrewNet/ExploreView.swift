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
    @State private var matchReasons: [String: [String]] = [:]  // userId → 证据式匹配理由(来自评分信号)
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
    @State private var currentUserIsPro: Bool? = nil  // ⭐ 缓存当前用户的 Pro 状态
    @State private var loadingMessageIndex = 0  // ⭐ 加载消息索引
    @State private var loadingProgress: Double = 0.0  // ⭐ 加载进度
    @State private var loadingTimer: Timer? = nil  // ⭐ 加载动画定时器
    @State private var showTalentScoutTip: Bool = false     // 新用户提示
    @State private var showAddMessagePrompt = false         // 显示添加消息提示窗
    @State private var profilePendingInvitation: BrewNetProfile? = nil  // 待发送邀请的profile

    
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }
    
    // ⭐ 动态加载消息
    private let loadingMessages = [
        "Scanning BrewNet profiles...",
        "Analyzing skills and experience...",
        "Matching your requirements...",
        "Finding perfect connections...",
        "Almost there..."
    ]
    
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
                
                // Talent Scout Tip Overlay - 全屏弹窗
                if showTalentScoutTip {
                    TalentScoutTipOverlay(isVisible: $showTalentScoutTip)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: OnboardingManager.shared.hasSeenTalentScoutTip) { hasSeenTip in
                // 监听状态变化，当重置引导时自动显示提示
                if !hasSeenTip {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTalentScoutTip = true
                    }
                }
            }
            .onAppear {
                // 显示新用户引导提示
                if !OnboardingManager.shared.hasSeenTalentScoutTip {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showTalentScoutTip = true
                    }
                }
                #if DEBUG
                // 仅 Debug 构建:环境变量自动触发一次 Scout 搜索(模拟器/UI 测试用)
                if let autoQuery = ProcessInfo.processInfo.environment["BREWNET_AUTOSCOUT_QUERY"],
                   !autoQuery.isEmpty, !hasSearched, !isLoading {
                    print("🧪 [DEBUG] Auto-scout via env var: \(autoQuery)")
                    descriptionText = autoQuery
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        runTalentScoutSearch()
                    }
                }
                #endif
            }
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
                        // 刷新用户信息
                        await authManager.refreshUser()
                        // 清除 Pro 状态缓存，强制重新检查
                        await MainActor.run {
                            currentUserIsPro = nil
                        }
                        // 重新加载 Pro 状态
                        preloadCurrentUserProStatus()
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
            Text("You've used all 6 connects for today. Upgrade to BrewNet Pro for unlimited connections and more exclusive features.")
        }
        .overlay {
            if showAddMessagePrompt {
                addMessagePromptView
            }
        }
        .onAppear {
            // 预加载当前用户的 Pro 状态，加快后续临时聊天检查速度
            preloadCurrentUserProStatus()
        }
        .onChange(of: authManager.currentUser?.isProActive) { isPro in
            // 当用户的 Pro 状态变化时，更新缓存
            if let isPro = isPro {
                currentUserIsPro = isPro
                print("✅ [Talent Scout] Pro 状态已更新: \(isPro ? "Pro用户" : "普通用户")")
            }
        }
    }
    
    // MARK: - Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    // 背景光效
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    themeColor.opacity(0.2),
                                    themeColor.opacity(0.0)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 8)
                        .opacity(showHeaderAnimation ? 1 : 0)
                    
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeColor,
                                    themeColor.opacity(0.7),
                                    themeColor
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .modifier(PulseAnimationModifier())
                }
                
                Text("Talent Scout")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeColor,
                                Color(red: 0.5, green: 0.3, blue: 0.15),
                                themeColor
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: themeColor.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .opacity(showHeaderAnimation ? 1 : 0)
        .scaleEffect(showHeaderAnimation ? 1 : 0.8)
        .offset(y: showHeaderAnimation ? 0 : -10)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showHeaderAnimation)
        .onAppear {
            withAnimation {
                showHeaderAnimation = true
            }
        }
    }
    
    private var descriptionSection: some View {
        Text("Tell your scout who you need. It searches, ranks the best fits, and shows you why each one matches.")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(themeColor)
            .opacity(showHeaderAnimation ? 1 : 0)
            .offset(y: showHeaderAnimation ? 0 : 10)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showHeaderAnimation)
    }
    
    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            // 渐变背景 + 玻璃态效果
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white,
                            Color.white.opacity(0.95)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: textEditorFocused ? [
                                    themeColor.opacity(0.8),
                                    themeColor.opacity(0.5)
                                ] : [
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: textEditorFocused ? 2.5 : 1.5
                        )
                )
                .shadow(
                    color: textEditorFocused ? themeColor.opacity(0.25) : Color.black.opacity(0.05),
                    radius: textEditorFocused ? 16 : 8,
                    x: 0,
                    y: textEditorFocused ? 6 : 4
                )
                .scaleEffect(textEditorFocused ? 1.02 : 1.0)
            
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
            
            // 字符计数（可选，显示在右下角）
            if !descriptionText.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(descriptionText.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(descriptionText.count > 500 ? .orange : .gray.opacity(0.6))
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                    }
                }
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
            HStack(spacing: 12) {
                if isLoading {
                    // 自定义加载动画：旋转的放大镜 + 粒子效果
                    ZStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        
                        // 旋转的放大镜图标
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isLoading)
                    }
                } else {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .modifier(PulseAnimationModifier())
                }
                Text(isLoading ? "Scouting..." : "Start Scouting")
                    .font(.system(size: 17, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(
                Group {
                    if isLoading {
                        // 加载时的渐变（更丰富的颜色）
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeColor,
                                themeColor.opacity(0.85),
                                themeColor.opacity(0.75)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        // 正常状态的丰富渐变
                        isSearchDisabled ? 
                        LinearGradient(
                            gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeColor,
                                Color(red: 0.5, green: 0.3, blue: 0.15),
                                themeColor.opacity(0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSearchDisabled ? Color.clear : themeColor.opacity(isLoading ? 0.4 : 0.35),
                radius: isLoading ? 12 : 8,
                x: 0,
                y: isLoading ? 6 : 4
            )
            .scaleEffect(isLoading ? 0.97 : 1.0)
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
                VStack(spacing: 16) {
                    // 骨架屏预览（显示3个骨架卡片）
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { index in
                            LoadingSkeletonCard(delay: Double(index) * 0.1)
                        }
                    }
                    .padding(.top, 8)
                    
                    // 加载状态指示器
                    VStack(spacing: 12) {
                        // 进度条
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [themeColor, themeColor.opacity(0.7)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * loadingProgress, height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: loadingProgress)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 20)
                        
                        // 动态加载消息
                        HStack(spacing: 12) {
                            // 旋转的放大镜图标
                            ZStack {
                                Circle()
                                    .stroke(themeColor.opacity(0.2), lineWidth: 3)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "sparkle.magnifyingglass")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(themeColor)
                                    .rotationEffect(.degrees(loadingProgress * 360))
                                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: loadingProgress)
                            }
                            
                            Text(loadingMessages[loadingMessageIndex])
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                                .id(loadingMessageIndex)  // 用于动画
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onAppear {
                    startLoadingAnimation()
                }
                .onDisappear {
                    stopLoadingAnimation()
                }
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
                    ZStack {
                        // 星星背景光效
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 15
                                )
                            )
                            .frame(width: 30, height: 30)
                            .blur(radius: 4)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.84, blue: 0.0),
                                        Color(red: 1.0, green: 0.75, blue: 0.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .modifier(PulseAnimationModifier())
                    }
                    
                    Text("Your scout's top picks")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeColor,
                                    Color(red: 0.5, green: 0.3, blue: 0.15)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: themeColor.opacity(0.1), radius: 1, x: 0, y: 1)
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
                        reasons: matchReasons[profile.userId] ?? [],
                        onTap: {
                            // 添加触觉反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            selectedProfile = profile
                        }
                    )
                    .opacity(showResults ? 1 : 0)
                    .offset(
                        x: showResults ? 0 : -20,
                        y: showResults ? 0 : 30
                    )
                    .scaleEffect(showResults ? 1 : 0.85)
                    .rotationEffect(.degrees(showResults ? 0 : -5))
                    .animation(
                        .spring(response: 0.7, dampingFraction: 0.75)
                        .delay(Double(entry.offset) * 0.08 + 0.15),
                        value: showResults
                    )
                    // ⭐ 添加光效动画（Top 3）
                    .overlay(
                        Group {
                            if entry.offset < 3 && showResults {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                rankBorderColorForIndex(entry.offset + 1).opacity(0.6),
                                                rankBorderColorForIndex(entry.offset + 1).opacity(0.0)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .opacity(showResults ? 1 : 0)
                                    .animation(
                                        .easeInOut(duration: 2.0)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(entry.offset) * 0.3),
                                        value: showResults
                                    )
                            }
                        }
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
    
    // ⭐ 辅助函数：根据排名索引获取边框颜色
    private func rankBorderColorForIndex(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // 金色
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // 银色
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)  // 铜色
        default: return themeColor
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
        loadingProgress = 0.0
        loadingMessageIndex = 0
        
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
                
                // ===== 共享搜索引擎(V2 规则排序 + V3 LLM 互惠精排,单一事实源)=====
                let outcome = try await ScoutSearchEngine.shared.search(
                    query: trimmed,
                    currentUserId: currentUser.id,
                    currentUserProfile: currentUserProfile,
                    topCount: 3,
                    progress: { p, idx in
                        loadingProgress = p
                        loadingMessageIndex = idx
                    }
                )

                let topEntries = outcome.top
                let finalValidProfiles = topEntries.map { $0.profile }
                let reasonsByUser = Dictionary(
                    topEntries.map { ($0.profile.userId, $0.reasons) },
                    uniquingKeysWith: { first, _ in first }
                )
                let topIds = finalValidProfiles.map { $0.userId }
                
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
                print("  ✅ Top \(finalValidProfiles.count) selected (engine llmRerank=\(outcome.llmRerankApplied))\n")
                
                await MainActor.run {
                    self.recommendedProfiles = finalValidProfiles
                    self.matchReasons = reasonsByUser
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
                    self.matchReasons = [:]
                    self.showResults = false
                    self.errorMessage = "Unable to complete the talent scout request. Please try again shortly."
                    print("❌ Talent Scout search failed: \(error.localizedDescription)")
                }
            }
        }
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
    
    /// V1.0 原始匹配分数计算（保留作为备用）
    private func computeMatchScore(
        for profile: BrewNetProfile,
        tokens: [String],
        numbers: [Double],
        currentUserProfile: BrewNetProfile?
    ) -> Double {
        var score: Double = 0.0
        let searchableText = ScoutSearchEngine.shared.aggregatedSearchableText(for: profile)
        // 确保所有 tokens 都转换为小写进行比较
        let tokenSet = Set(tokens.map { $0.lowercased() })
        
        for token in tokenSet {
            if token.count < 2 { continue }
            // 确保 token 是小写后再进行比较
            let lowercasedToken = token.lowercased()
            if searchableText.contains(lowercasedToken) {
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
        
        // 确保所有硬编码字符串都转换为小写进行比较
        if tokenSet.contains(where: { $0.lowercased().contains("mentor") || $0.lowercased().contains("mentoring") }) {
            if profile.networkingIntention.selectedIntention == .learnGrow ||
                profile.networkingIntention.selectedSubIntentions.contains(.skillDevelopment) ||
                profile.networkingIntention.selectedSubIntentions.contains(.careerDirection) {
                score += 1.5
            }
        }
        
        // 校友匹配逻辑：如果查询包含 alumni/alum 相关词汇
        if tokenSet.contains(where: { $0.lowercased().contains("alum") }) {
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
        
        // 确保所有硬编码字符串都转换为小写进行比较
        if tokenSet.contains("founder") || tokenSet.contains("startup") {
            if profile.professionalBackground.careerStage == .founder ||
                profile.networkingIntention.selectedIntention == .buildCollaborate {
                score += 1.0
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
        
        // 如果已经缓存了 Pro 状态，立即决定显示哪个界面
        if let isPro = currentUserIsPro {
            if isPro {
                selectedProfileForChat = profile
                showingTemporaryChat = true
            } else {
                showSubscriptionPayment = true
            }
            return
        }
        
        // 如果没有缓存，先检查 Pro 状态（优化：使用更快的检查方法）
        Task {
            let checkStart = Date()
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                let checkTime = Date().timeIntervalSince(checkStart) * 1000
                print("⏱️ [Talent Scout] Pro 状态检查耗时: \(String(format: "%.1f", checkTime))ms")
                
                await MainActor.run {
                    // 缓存 Pro 状态
                    currentUserIsPro = canChat
                    
                    if canChat {
                        selectedProfileForChat = profile
                        showingTemporaryChat = true
                    } else {
                        showSubscriptionPayment = true
                    }
                }
            } catch {
                print("❌ Talent Scout: failed to check temporary chat eligibility: \(error.localizedDescription)")
                // 如果检查失败，假设是 Pro 用户，保持界面打开
                await MainActor.run {
                    currentUserIsPro = true  // 假设是 Pro，避免重复检查
                    selectedProfileForChat = profile
                    showingTemporaryChat = true
                }
            }
        }
    }
    
    /// 预加载当前用户的 Pro 状态（在界面加载时调用）
    private func preloadCurrentUserProStatus() {
        guard let currentUser = authManager.currentUser else { return }
        guard currentUserIsPro == nil else { return }  // 如果已有缓存，跳过
        
        Task {
            do {
                let canChat = try await supabaseService.canSendTemporaryChat(userId: currentUser.id)
                await MainActor.run {
                    currentUserIsPro = canChat
                    print("✅ [Talent Scout] Pro 状态已预加载: \(canChat ? "Pro用户" : "普通用户")")
                }
            } catch {
                print("⚠️ [Talent Scout] 预加载 Pro 状态失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 加载动画管理
    
    /// 开始加载动画
    private func startLoadingAnimation() {
        // 重置状态
        loadingProgress = 0.0
        loadingMessageIndex = 0
        
        // 进度条动画（模拟进度）
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.isLoading {
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        // 渐进式增加进度（但不超过当前实际进度）
                        if self.loadingProgress < 0.95 {
                            self.loadingProgress += 0.02
                        }
                    }
                }
            } else {
                timer.invalidate()
            }
        }
        
        // 动态加载消息轮播
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if self.isLoading {
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.loadingMessageIndex = (self.loadingMessageIndex + 1) % self.loadingMessages.count
                    }
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
    /// 停止加载动画
    private func stopLoadingAnimation() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingProgress = 0.0
        loadingMessageIndex = 0
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
            
            // Check if this is the first like today - show prompt only on first like
            let isFirstLike = try await supabaseService.isFirstLikeToday(userId: currentUser.id)
            if isFirstLike {
                // Update the first_like_today to current date
                try await supabaseService.updateFirstLikeToday(userId: currentUser.id)
                
                await MainActor.run {
                    profilePendingInvitation = profile
                    showAddMessagePrompt = true
                }
                return // Stop here and wait for user action
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
    
    private func sendInvitationWithoutMessage(profile: BrewNetProfile) async {
        guard let currentUser = authManager.currentUser else { return }
        
        do {
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
                profilePendingInvitation = nil
            }
            
            print("✅ Invitation sent successfully (without message)")
        } catch {
            print("❌ Failed to send invitation: \(error.localizedDescription)")
            await MainActor.run {
                profilePendingInvitation = nil
            }
        }
    }
    
    // MARK: - Add Message Prompt View
    private var addMessagePromptView: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss when tapping outside
                }
            
            // Alert dialog
            VStack(spacing: 20) {
                // Title
                Text("ADD A MESSAGE TO YOUR INVITATION?")
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                
                // Message
                Text("Personalize your request by adding a message. People are more likely to accept requests that include a message.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Buttons
                VStack(spacing: 12) {
                    // Add a Message button
                    Button(action: {
                        showAddMessagePrompt = false
                        if let profile = profilePendingInvitation {
                            selectedProfileForChat = profile
                            showingTemporaryChat = true
                        }
                    }) {
                        Text("Add a Message")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .cornerRadius(25)
                    }
                    
                    // Send Anyway button
                    Button(action: {
                        showAddMessagePrompt = false
                        if let profile = profilePendingInvitation {
                            Task {
                                await sendInvitationWithoutMessage(profile: profile)
                            }
                        }
                    }) {
                        Text("Send Anyway")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color(red: 0.4, green: 0.2, blue: 0.1), lineWidth: 1.5)
                            )
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 340)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
    }
}

// MARK: - Result Card
struct TalentScoutResultCard: View {
    let profile: BrewNetProfile
    let rank: Int
    var isEngaged: Bool
    var reasons: [String] = []  // 证据式匹配理由(来自评分信号)
    var onTap: (() -> Void)? = nil
    
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // ⭐ 重新设计的排名徽章
                HStack(spacing: 6) {
                    ZStack {
                        // 渐变背景
                        RoundedRectangle(cornerRadius: rank <= 3 ? 14 : 12)
                            .fill(rankBadgeGradient)
                            .frame(width: rank <= 3 ? 50 : 45, height: rank <= 3 ? 28 : 26)
                            .shadow(
                                color: rank <= 3 ? Color.black.opacity(0.2) : Color.clear,
                                radius: rank <= 3 ? 4 : 0,
                                x: 0,
                                y: rank <= 3 ? 2 : 0
                            )
                        
                        HStack(spacing: 4) {
                            if rank <= 3 {
                                Image(systemName: rankIcon)
                                    .font(.system(size: rank == 1 ? 14 : 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("#\(rank)")
                                .font(.system(size: rank <= 3 ? 16 : 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    if isEngaged {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.green)
                            .font(.system(size: 20, weight: .bold))
                            .shadow(color: Color.green.opacity(0.3), radius: 4, x: 0, y: 2)
                            .scaleEffect(isHovered ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    }
                }
                
                Spacer()
                
                // ⭐ 匹配度指示器（模拟，实际应从评分计算）
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < matchScoreStars ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(index < matchScoreStars ? Color(red: 1.0, green: 0.84, blue: 0.0) : Color.gray.opacity(0.3))
                            .scaleEffect(isHovered && index < matchScoreStars ? 1.2 : 1.0)
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.6)
                                .delay(Double(index) * 0.05),
                                value: isHovered
                            )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
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
                        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    
                    HStack(spacing: 6) {
                        // 🏢 真实公司 logo
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            BrandLogoView(name: company, size: 16)
                        }
                        Text(primaryHeadline)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeColor,
                                        themeColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(2)
                    }
                    
                    if let location = profile.coreIdentity.location, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.red.opacity(0.7),
                                            Color.orange.opacity(0.6)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(location)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .opacity(isHovered ? 1.0 : 0.9)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                    }
                    
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(3)
                    }
                }
            }
            
            // ⭐ Why this match:证据式理由,让推荐可信而非黑箱
            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(themeColor.opacity(0.7))
                        Text("Why this match")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeColor.opacity(0.7))
                            .textCase(.uppercase)
                    }
                    ForEach(reasons.prefix(3), id: \.self) { reason in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeColor.opacity(0.85))
                                .padding(.top, 1)
                            Text(reason)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(themeColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeColor.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeColor.opacity(0.12), lineWidth: 1)
                )
                .padding(.top, 4)
            }

            if !skillsPreview.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(skillsPreview.enumerated()), id: \.element) { index, skill in
                        Text(skill)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeColor.opacity(isHovered ? 0.18 : 0.12),
                                        themeColor.opacity(isHovered ? 0.14 : 0.08)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                themeColor.opacity(isHovered ? 0.3 : 0.2),
                                                themeColor.opacity(isHovered ? 0.25 : 0.15)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isHovered ? 0.8 : 0.5
                                    )
                            )
                            .scaleEffect(isHovered ? 1.05 : 1.0)
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.7)
                                .delay(Double(index) * 0.05),
                                value: isHovered
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            // ⭐ 渐变背景 + 左侧彩色边框 + 光效
            ZStack(alignment: .leading) {
                // 主背景渐变（悬停时更亮）
                LinearGradient(
                    gradient: Gradient(colors: isHovered ? [
                        Color.white,
                        Color(red: 0.995, green: 0.99, blue: 0.98)
                    ] : [
                        Color.white,
                        Color(red: 0.99, green: 0.98, blue: 0.97)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 左侧彩色边框条（根据排名变色，悬停时更亮）
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                rankBorderColor,
                                rankBorderColor.opacity(isHovered ? 0.9 : 0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: isHovered ? 5 : 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                
                // 光效（悬停时显示）
                if isHovered && rank <= 3 {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    rankBorderColor.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                }
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: isHovered ? [
                            Color.white.opacity(0.9),
                            rankBorderColor.opacity(0.2),
                            Color.gray.opacity(0.1)
                        ] : [
                            Color.white.opacity(0.8),
                            Color.gray.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? 1.5 : 1
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        )
        .shadow(
            color: rank <= 3 ? 
                (isHovered ? Color.black.opacity(0.15) : Color.black.opacity(0.12)) :
                (isHovered ? Color.black.opacity(0.1) : Color.black.opacity(0.08)),
            radius: rank <= 3 ? (isHovered ? 16 : 12) : (isHovered ? 14 : 10),
            x: 0,
            y: rank <= 3 ? (isHovered ? 10 : 8) : (isHovered ? 8 : 6)
        )
        .scaleEffect(isPressed ? 0.97 : (isHovered ? 1.02 : 1.0))
        .offset(y: isPressed ? 2 : 0)
        .rotationEffect(.degrees(isHovered ? 0.5 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        // ⭐ 限制点击区域：只响应左侧 85% 的区域，右侧 15% 用于滑动
        .allowsHitTesting(false)  // 先禁用整个卡片的点击
        .overlay(
            GeometryReader { geometry in
                // 左侧可点击区域（85% 宽度）
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.clear)
                        .frame(width: geometry.size.width * 0.85)
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                        .onTapGesture {
                            // 触觉反馈
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            onTap?()
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 5)  // ⭐ 设置最小距离，允许滚动
                                .onChanged { value in
                                    // 只有在很小的移动范围内才认为是按压
                                    if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                            isPressed = true
                                            isHovered = true
                                        }
                                    } else {
                                        // 如果移动距离较大，取消按压状态，允许滚动
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                            isPressed = false
                                            isHovered = false
                                        }
                                    }
                                }
                                .onEnded { value in
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        isPressed = false
                                        isHovered = false
                                    }
                                    // 如果移动距离很小，认为是点击
                                    if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                        onTap?()
                                    }
                                }
                        )
                    
                    // 右侧空白区域（15% 宽度），不响应点击，用于滑动
                    Spacer()
                }
            }
            .allowsHitTesting(true)
        )
    }
    
    // ⭐ 排名徽章颜色（Top 3 特殊设计）
    private var rankBadgeGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.84, blue: 0.0),  // 金色
                    Color(red: 1.0, green: 0.75, blue: 0.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.75, green: 0.75, blue: 0.75),  // 银色
                    Color(red: 0.6, green: 0.6, blue: 0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.8, green: 0.5, blue: 0.2),  // 铜色
                    Color(red: 0.7, green: 0.4, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [themeColor, themeColor.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // ⭐ 排名图标
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return "star.fill"
        }
    }
    
    // ⭐ 匹配度星级（模拟，实际应从评分计算）
    private var matchScoreStars: Int {
        // 根据排名计算匹配度（Top 1 = 5星，Top 2-3 = 4星，其他 = 3星）
        switch rank {
        case 1: return 5
        case 2, 3: return 4
        default: return 3
        }
    }
    
    // ⭐ 排名边框颜色
    private var rankBorderColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)  // 金色
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)  // 银色
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)  // 铜色
        default: return themeColor
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

// MARK: - Loading Skeleton Card
struct LoadingSkeletonCard: View {
    let delay: Double
    @State private var isAnimating = false
    
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 排名徽章骨架
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 45, height: 26)
                
                Spacer()
                
                // 匹配度骨架
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(alignment: .top, spacing: 16) {
                // 头像骨架
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 8) {
                    // 姓名骨架
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 20)
                    
                    // 职位骨架
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 180, height: 16)
                    
                    // 位置骨架
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 100, height: 14)
                }
            }
            
            // 技能标签骨架
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 60, height: 24)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                isAnimating = true
            }
        }
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

// MARK: - Talent Scout Tip Overlay (全屏弹窗)
struct TalentScoutTipOverlay: View {
    @Binding var isVisible: Bool
    @State private var overlayOpacity: Double = 0
    @State private var typedText: String = ""
    @State private var showSearchBar = false
    @State private var showResults = false
    @State private var resultOffsets: [CGFloat] = [300, 300, 300]
    @State private var resultOpacities: [Double] = [0, 0, 0]
    
    private let themeColor = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let fullText = "alumni from Stanford"
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(overlayOpacity * 0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTip()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // 标题和说明
                VStack(spacing: 12) {
                    Text("Natural Language Search")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Describe who you want to meet")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.bottom, 40)
                
                // 模拟搜索界面
                VStack(spacing: 20) {
                    // 搜索框
                    if showSearchBar {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(themeColor.opacity(0.6))
                            
                            Text(typedText)
                                .font(.system(size: 17))
                                .foregroundColor(themeColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if typedText.count < fullText.count {
                                Text("|")
                                    .font(.system(size: 17))
                                    .foregroundColor(themeColor.opacity(0.3))
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 搜索结果
                    if showResults {
                        VStack(spacing: 12) {
                            ForEach(0..<3) { index in
                                HStack(spacing: 12) {
                                    // 模拟头像
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.6, green: 0.4, blue: 0.2),
                                                    Color(red: 0.4, green: 0.2, blue: 0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.white.opacity(0.8))
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 120, height: 14)
                                            
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 180, height: 12)
                                    }
                                    
                                    Spacer()
                                    
                                    // Stanford 徽章
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(themeColor.opacity(0.6))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                .offset(y: resultOffsets[index])
                                .opacity(resultOpacities[index])
                            }
                        }
                    }
                }
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                
                Spacer()
                
                // "Got it" 按钮
                Button(action: {
                    dismissTip()
                }) {
                    Text("Got it!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                overlayOpacity = 1
            }
            
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // 延迟0.5秒后显示搜索框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showSearchBar = true
            }
            
            // 开始打字动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startTypingAnimation()
            }
        }
    }
    
    private func startTypingAnimation() {
        guard typedText.count < fullText.count else {
            // 打字完成，显示搜索结果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResults = true
                animateResults()
            }
            
            // 3秒后重置动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                resetAnimation()
            }
            return
        }
        
        let nextIndex = typedText.count
        let nextChar = fullText[fullText.index(fullText.startIndex, offsetBy: nextIndex)]
        typedText.append(nextChar)
        
        // 继续打字，每个字符间隔0.1秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startTypingAnimation()
        }
    }
    
    private func animateResults() {
        // 依次显示三个结果
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    resultOffsets[i] = 0
                    resultOpacities[i] = 1
                }
            }
        }
    }
    
    private func resetAnimation() {
        // 重置所有状态
        withAnimation(.easeOut(duration: 0.3)) {
            showResults = false
            resultOffsets = [300, 300, 300]
            resultOpacities = [0, 0, 0]
        }
        
        typedText = ""
        
        // 重新开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startTypingAnimation()
        }
    }
    
    private func dismissTip() {
        OnboardingManager.shared.markTalentScoutTipAsSeen()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            overlayOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isVisible = false
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