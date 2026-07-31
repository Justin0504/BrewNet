import SwiftUI

// MARK: - Brew Onboarding(对话式建档)
//
// 新用户首次 setup 的默认路径:和 Brew 聊 5 个问题 → LLM 结构化抽取 →
// 走现有 createProfile / updateUserProfileSetupCompleted 保存链路。
// 最后一问("想认识谁")直接播种第一个 mission → 进入主界面时 Brew 立刻开工。
// 右上角"Use form instead"保留经典表单(ProfileSetupView 原样未动)。

struct BrewOnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService

    private struct OnboardingMessage: Identifiable {
        let id = UUID()
        let isAgent: Bool
        let text: String
    }

    private let questions = [
        "First up: what do you do right now? Role and company — or school if you're studying. Say it naturally.",
        "Where are you based? (city is enough)",
        "Where did you — or do you — study?",
        "What are you good at? A few skills or topics you could talk about for hours.",
        "Last one: who would you like to meet here, and what for? The moment you're in, I'll start scouting."
    ]

    @State private var messages: [OnboardingMessage] = []
    @State private var answers: [String] = []
    @State private var step = 0
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var showFormFallback = false
    @State private var didStart = false
    @FocusState private var inputFocused: Bool

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                messageList
                composer
            }
        }
        .fullScreenCover(isPresented: $showFormFallback) {
            ProfileSetupView()
        }
        .onAppear { startIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(themeColor.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(themeColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Brew")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(themeColor)
                Text(isProcessing ? "Setting you up…" : "Quick setup · \(min(step + 1, questions.count))/\(questions.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Button("Use form instead") {
                showFormFallback = true
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(themeColor.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                    if isProcessing {
                        HStack(spacing: 8) {
                            BrewTypingDots()
                        }
                        .id("processing")
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
        }
    }

    @ViewBuilder
    private func bubble(_ message: OnboardingMessage) -> some View {
        if message.isAgent {
            HStack(alignment: .bottom, spacing: 8) {
                ZStack {
                    Circle().fill(themeColor.opacity(0.12)).frame(width: 24, height: 24)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeColor)
                }
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 4, bottomTrailingRadius: 16, topTrailingRadius: 16)
                            .fill(Color.white)
                    )
                Spacer(minLength: 32)
            }
        } else {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(themeColor))
            }
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Type your answer…", text: $inputText, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...3)
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(themeColor.opacity(inputFocused ? 0.4 : 0.12), lineWidth: 1.2))

            Button {
                submitAnswer()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray.opacity(0.4) : themeColor)
            }
            .disabled(isProcessing || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Flow

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        let firstName = authManager.currentUser?.name.components(separatedBy: " ").first
        messages.append(OnboardingMessage(isAgent: true, text: "Hi\(firstName.map { " \($0)" } ?? "")! I'm Brew, your networking agent ☕️ Let's get you set up in about 2 minutes — just chat, no forms."))
        messages.append(OnboardingMessage(isAgent: true, text: questions[0]))
    }

    private func submitAnswer() {
        let answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, !isProcessing else { return }
        inputText = ""
        messages.append(OnboardingMessage(isAgent: false, text: answer))
        answers.append(answer)

        if step < questions.count - 1 {
            step += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                messages.append(OnboardingMessage(isAgent: true, text: questions[step]))
            }
        } else {
            // 全部答完 → 抽取 + 保存
            messages.append(OnboardingMessage(isAgent: true, text: "Perfect — give me a moment to put your profile together…"))
            isProcessing = true
            Task { await finishOnboarding() }
        }
    }

    // MARK: - Extraction & Save

    private func finishOnboarding() async {
        guard let currentUser = authManager.currentUser else { return }

        let qa = zip(questions, answers).map { (question: $0, answer: $1) }
        let extracted = await BrewAgentService.shared.extractOnboardingProfile(qa: qa)

        // 字段解析(LLM 结果优先,启发式兜底)
        func str(_ key: String) -> String? {
            guard let v = extracted?[key] as? String, !v.isEmpty, v.lowercased() != "null" else { return nil }
            return v
        }
        let jobTitle = str("job_title") ?? answers[0]
        let company = str("company")
        let school = str("school") ?? answers[2]
        let city = str("city") ?? answers[1]
        let industry = str("industry")
        let bio = str("bio")
        let mission = str("mission") ?? answers[4]

        var skills: [String]
        if let s = extracted?["skills"] as? [String], !s.isEmpty {
            skills = Array(s.prefix(8))
        } else {
            skills = answers[3]
                .components(separatedBy: CharacterSet(charactersIn: ",;、和/&"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            skills = Array(skills.prefix(8))
        }

        let (expLevel, careerStage) = mapLevels(str("experience_level"), answersJoined: answers.joined(separator: " "))
        let intention = mapIntention(str("intention"))

        // 组装档案(默认骨架 + 对话字段)
        let base = BrewNetProfile.createDefault(userId: currentUser.id)
        let supabaseProfile = SupabaseProfile(
            id: base.id,
            userId: base.userId,
            coreIdentity: CoreIdentity(
                name: currentUser.name,
                email: currentUser.email,
                phoneNumber: nil,
                profileImage: nil,
                bio: bio,
                pronouns: nil,
                location: city,
                personalWebsite: nil,
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: TimeZone.current.identifier
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: company,
                jobTitle: jobTitle,
                industry: industry,
                experienceLevel: expLevel,
                education: school,
                educations: nil,
                yearsOfExperience: nil,
                careerStage: careerStage,
                skills: skills,
                certifications: [],
                languagesSpoken: [],
                workExperiences: []
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: intention,
                additionalIntentions: [],
                selectedSubIntentions: [],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: base.networkingPreferences,
            personalitySocial: base.personalitySocial,
            workPhotos: base.workPhotos,
            lifestylePhotos: base.lifestylePhotos,
            privacyTrust: base.privacyTrust,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt
        )

        do {
            // 与表单路径一致:已有档案则更新,否则创建
            if let existing = try await supabaseService.getProfile(userId: currentUser.id) {
                let merged = SupabaseProfile(
                    id: existing.id, userId: existing.userId,
                    coreIdentity: supabaseProfile.coreIdentity,
                    professionalBackground: supabaseProfile.professionalBackground,
                    networkingIntention: supabaseProfile.networkingIntention,
                    networkingPreferences: existing.networkingPreferences,
                    personalitySocial: existing.personalitySocial,
                    workPhotos: existing.workPhotos,
                    lifestylePhotos: existing.lifestylePhotos,
                    privacyTrust: existing.privacyTrust,
                    createdAt: existing.createdAt,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                _ = try await supabaseService.updateProfile(profileId: existing.id, profile: merged)
            } else {
                _ = try await supabaseService.createProfile(profile: supabaseProfile)
            }
            try? await supabaseService.updateUserProfileSetupCompleted(userId: currentUser.id, completed: true)

            // 🌱 播种第一个 mission:进入主界面后 Brew 立刻开始第一次搜索
            BrewMemoryStore.shared.seedMission(goal: mission, userId: currentUser.id)

            await MainActor.run {
                isProcessing = false
                messages.append(OnboardingMessage(isAgent: true, text: "You're in! 🎉 I've saved your profile and your first mission — \"\(mission.prefix(80))\". Taking you in now…"))
                // 触发路由到 MainView(SplashScreenWrapper 监听此状态)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    authManager.updateProfileSetupCompleted(true)
                }
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                messages.append(OnboardingMessage(isAgent: true, text: "Hmm, something went wrong saving your profile. You can try again, or use the form — everything you told me is safe."))
                print("❌ [BrewOnboarding] save failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Enum Mapping

    private func mapLevels(_ level: String?, answersJoined: String) -> (ExperienceLevel, CareerStage) {
        let lower = answersJoined.lowercased()
        let isFounder = lower.contains("founder") || lower.contains("co-founder") || lower.contains("my startup")
        switch (level ?? "").lowercased() {
        case "student": return (.student, .earlyCareer)
        case "intern": return (.intern, .earlyCareer)
        case "entry": return (.entry, .earlyCareer)
        case "mid": return (.mid, isFounder ? .founder : .midLevel)
        case "senior": return (.senior, isFounder ? .founder : .manager)
        case "exec": return (.exec, isFounder ? .founder : .executive)
        default:
            if lower.contains("student") || lower.contains("university") || lower.contains("master") || lower.contains("phd") {
                return (.student, .earlyCareer)
            }
            return (.entry, isFounder ? .founder : .earlyCareer)
        }
    }

    private func mapIntention(_ intention: String?) -> NetworkingIntentionType {
        switch (intention ?? "").lowercased() {
        case "connect_share": return .connectShare
        case "build_collaborate": return .buildCollaborate
        case "unwind_chat": return .unwindChat
        default: return .learnGrow
        }
    }
}
