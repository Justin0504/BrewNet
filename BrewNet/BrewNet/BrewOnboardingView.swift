import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Brew Onboarding(对话式建档 · 完全体)
//
// 设计原则:对话是框架,控件是词汇。
//   问答(事实)+ 📄 简历导入(结构化长尾)+ 📷 照片内嵌卡 + 🗓 时段格子
// 全部发生在与 Brew 的同一条对话流里;经典表单仍可经右上角回退。
// 最后一问播种第一个 mission → 进主界面 Brew 立刻开工。

struct BrewOnboardingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService

    private struct OnboardingMessage: Identifiable {
        enum Kind {
            case agentText(String)
            case userText(String)
            case resumeOffer          // 📄 简历导入按钮卡
            case photoCard            // 📷 照片选择卡
            case timeslotCard         // 🗓 空闲时段 chips 卡
        }
        let id = UUID()
        let kind: Kind
    }

    private enum Phase {
        case questions, photo, timeslot, saving, done
    }

    private let questions = [
        "First up: what do you do right now? Role and company — or school if you're studying. Say it naturally.",
        "Where are you based? (city is enough)",
        "Where did you — or do you — study?",
        "What are you good at? A few skills or topics you could talk about for hours.",
        "Last one: who would you like to meet here, and what for? The moment you're in, I'll start scouting."
    ]

    @State private var messages: [OnboardingMessage] = []
    @State private var answers: [String] = ["", "", "", "", ""]
    @State private var step = 0
    @State private var phase: Phase = .questions
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var showFormFallback = false
    @State private var didStart = false
    @FocusState private var inputFocused: Bool

    // 富建档素材
    @State private var parsedResume: ParsedResume?
    @State private var showResumeImporter = false
    @State private var isParsingResume = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoURL: String?
    @State private var isUploadingPhoto = false
    @State private var timeslotChoices: Set<String> = []

    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var backgroundColor: Color { Color(red: 0.98, green: 0.97, blue: 0.95) }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                messageList
                if phase == .questions { composer }
            }
        }
        .sheet(isPresented: $showFormFallback) {
            ProfileSetupView()
        }
        .fileImporter(
            isPresented: $showResumeImporter,
            allowedContentTypes: [UTType.pdf,
                                  UTType(filenameExtension: "docx") ?? .data,
                                  UTType(filenameExtension: "doc") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await importResume(from: url) }
            }
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task { await uploadPickedPhoto(item) }
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
                Text(headerSubtitle)
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

    private var headerSubtitle: String {
        switch phase {
        case .questions: return isParsingResume ? "Reading your resume…" : "Quick setup · \(min(step + 1, questions.count))/\(questions.count)"
        case .photo: return "One photo — big difference"
        case .timeslot: return "When are you free?"
        case .saving: return "Setting you up…"
        case .done: return "All set!"
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                    if isProcessing || isParsingResume {
                        HStack(spacing: 8) { BrewTypingDots() }.id("processing")
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
        switch message.kind {
        case .agentText(let text):
            HStack(alignment: .bottom, spacing: 8) {
                ZStack {
                    Circle().fill(themeColor.opacity(0.12)).frame(width: 24, height: 24)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(themeColor)
                }
                Text(text)
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
        case .resumeOffer:
            Button {
                showResumeImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                    Text("Or drop your resume — I'll read it (PDF/Word)")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(themeColor.opacity(0.3), lineWidth: 1.2))
            }
            .disabled(parsedResume != nil)
        case .photoCard:
            VStack(alignment: .leading, spacing: 10) {
                if let url = photoURL {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: url)) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else { Color.gray.opacity(0.2) }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        Text("Looking sharp ✓")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeColor)
                    }
                } else {
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: 8) {
                                if isUploadingPhoto {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.fill").font(.system(size: 14))
                                }
                                Text(isUploadingPhoto ? "Uploading…" : "Choose a photo")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(themeColor))
                        }
                        .disabled(isUploadingPhoto)
                        Button("Skip for now") {
                            advanceToTimeslot()
                        }
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    }
                }
            }
        case .timeslotCard:
            TimeslotChipsCard(
                choices: $timeslotChoices,
                onDone: {
                    Task { await finishOnboarding() }
                }
            )
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
        messages.append(OnboardingMessage(kind: .agentText("Hi\(firstName.map { " \($0)" } ?? "")! I'm Brew, your networking agent ☕️ Let's get you set up in about 2 minutes — just chat, no forms.")))
        messages.append(OnboardingMessage(kind: .resumeOffer))
        messages.append(OnboardingMessage(kind: .agentText(questions[0])))
    }

    private func submitAnswer() {
        let answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, !isProcessing, phase == .questions else { return }
        inputText = ""
        messages.append(OnboardingMessage(kind: .userText(answer)))
        answers[step] = answer
        advanceQuestion()
    }

    /// 走到下一个未回答的问题;问完 → 照片阶段
    private func advanceQuestion() {
        var next = step + 1
        while next < questions.count, !answers[next].isEmpty { next += 1 }
        if next < questions.count {
            step = next
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                messages.append(OnboardingMessage(kind: .agentText(questions[next])))
            }
        } else {
            advanceToPhoto()
        }
    }

    private func advanceToPhoto() {
        phase = .photo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            messages.append(OnboardingMessage(kind: .agentText("Almost done! Add a photo — invites from profiles with photos get accepted about 3× more.")))
            messages.append(OnboardingMessage(kind: .photoCard))
        }
    }

    private func advanceToTimeslot() {
        guard phase == .photo else { return }
        phase = .timeslot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            messages.append(OnboardingMessage(kind: .agentText("Last thing: when are you usually free for coffee? Tap all that apply — this lets me propose times that just work.")))
            messages.append(OnboardingMessage(kind: .timeslotCard))
        }
    }

    // MARK: - Resume Import

    private func importResume(from url: URL) async {
        await MainActor.run { isParsingResume = true }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let parsed = try await ResumeParser.parseResume(from: url)
            await MainActor.run {
                parsedResume = parsed
                isParsingResume = false
                messages.append(OnboardingMessage(kind: .userText("📄 Resume imported")))

                // 简历预填:角色/学校/技能 → 跳过对应问题
                var known: [String] = []
                if let title = parsed.jobTitle {
                    answers[0] = [title, parsed.currentCompany.map { "at \($0)" }].compactMap { $0 }.joined(separator: " ")
                    known.append(answers[0])
                }
                if let loc = parsed.location, !loc.isEmpty { answers[1] = loc }
                if let school = parsed.educations.first?.schoolName {
                    answers[2] = school
                    known.append(school)
                }
                if !parsed.skills.isEmpty { answers[3] = parsed.skills.joined(separator: ", ") }

                let ack = known.isEmpty
                    ? "Got your resume — nice! A couple of quick questions to fill the gaps."
                    : "Got it — \(known.joined(separator: ", ")). Impressive! Just the gaps left:"
                messages.append(OnboardingMessage(kind: .agentText(ack)))
                // 从当前位置重新找未答问题
                step = -1
                advanceQuestion()
            }
        } catch {
            await MainActor.run {
                isParsingResume = false
                messages.append(OnboardingMessage(kind: .agentText("Hmm, I couldn't read that file — let's just chat instead. \(questions[step])")))
            }
            print("❌ [BrewOnboarding] resume parse failed: \(error)")
        }
    }

    // MARK: - Photo Upload

    private func uploadPickedPhoto(_ item: PhotosPickerItem) async {
        guard let currentUser = authManager.currentUser else { return }
        await MainActor.run { isUploadingPhoto = true }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(domain: "photo", code: 1)
            }
            let url = try await supabaseService.uploadProfileImage(userId: currentUser.id, imageData: data)
            await MainActor.run {
                photoURL = url
                isUploadingPhoto = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                advanceToTimeslot()
            }
        } catch {
            await MainActor.run {
                isUploadingPhoto = false
                messages.append(OnboardingMessage(kind: .agentText("Upload hiccuped — you can add it later from your profile. Moving on!")))
                advanceToTimeslot()
            }
            print("❌ [BrewOnboarding] photo upload failed: \(error)")
        }
    }

    // MARK: - Timeslot Mapping

    private func builtTimeslot() -> AvailableTimeslot {
        func day(_ isWeekend: Bool) -> DayTimeslots {
            let p = isWeekend ? "we" : "wd"
            return DayTimeslots(
                morning: timeslotChoices.contains("\(p)_morning"),
                noon: timeslotChoices.contains("\(p)_noon"),
                afternoon: timeslotChoices.contains("\(p)_afternoon"),
                evening: timeslotChoices.contains("\(p)_evening"),
                night: false
            )
        }
        let wd = day(false), we = day(true)
        return AvailableTimeslot(sunday: we, monday: wd, tuesday: wd, wednesday: wd,
                                 thursday: wd, friday: wd, saturday: we)
    }

    // MARK: - Extraction & Save

    private func finishOnboarding() async {
        guard let currentUser = authManager.currentUser else { return }
        await MainActor.run {
            phase = .saving
            isProcessing = true
            messages.append(OnboardingMessage(kind: .agentText("Perfect — give me a moment to put your profile together…")))
        }

        let qa = zip(questions, answers).filter { !$0.1.isEmpty }.map { (question: $0, answer: $1) }
        let extracted = await BrewAgentService.shared.extractOnboardingProfile(qa: qa)

        func str(_ key: String) -> String? {
            guard let v = extracted?[key] as? String, !v.isEmpty, v.lowercased() != "null" else { return nil }
            return v
        }
        // 合并优先级:简历(结构化)> LLM 抽取 > 原话
        let jobTitle = parsedResume?.jobTitle ?? str("job_title") ?? answers[0]
        let company = parsedResume?.currentCompany ?? str("company")
        let school = parsedResume?.educations.first?.schoolName ?? str("school") ?? answers[2]
        let city = parsedResume?.location ?? str("city") ?? answers[1]
        let industry = str("industry")
        let bio = str("bio") ?? parsedResume?.bio
        let mission = str("mission") ?? answers[4]

        var skills: [String]
        if let rSkills = parsedResume?.skills, !rSkills.isEmpty {
            skills = Array(rSkills.prefix(10))
        } else if let s = extracted?["skills"] as? [String], !s.isEmpty {
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

        let base = BrewNetProfile.createDefault(userId: currentUser.id)
        let timeslot = timeslotChoices.isEmpty ? base.networkingPreferences.availableTimeslot : builtTimeslot()

        let supabaseProfile = SupabaseProfile(
            id: base.id,
            userId: base.userId,
            coreIdentity: CoreIdentity(
                name: currentUser.name,
                email: currentUser.email,
                phoneNumber: parsedResume?.phone,
                profileImage: photoURL,
                bio: bio,
                pronouns: nil,
                location: city,
                personalWebsite: parsedResume?.personalWebsite,
                githubUrl: parsedResume?.githubUrl,
                linkedinUrl: parsedResume?.linkedInUrl,
                timeZone: TimeZone.current.identifier
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: company,
                jobTitle: jobTitle,
                industry: industry,
                experienceLevel: expLevel,
                education: school,
                educations: parsedResume.map { $0.educations.isEmpty ? nil : $0.educations } ?? nil,
                yearsOfExperience: parsedResume?.yearsOfExperience,
                careerStage: careerStage,
                skills: skills,
                certifications: parsedResume?.certifications ?? [],
                languagesSpoken: parsedResume?.languages ?? [],
                workExperiences: parsedResume?.workExperiences ?? []
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: intention,
                additionalIntentions: [],
                selectedSubIntentions: [],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: base.networkingPreferences.preferredChatFormat,
                availableTimeslot: timeslot,
                preferredChatDuration: base.networkingPreferences.preferredChatDuration
            ),
            personalitySocial: base.personalitySocial,
            workPhotos: base.workPhotos,
            lifestylePhotos: base.lifestylePhotos,
            privacyTrust: base.privacyTrust,
            createdAt: base.createdAt,
            updatedAt: base.updatedAt
        )

        do {
            if let existing = try await supabaseService.getProfile(userId: currentUser.id) {
                let merged = SupabaseProfile(
                    id: existing.id, userId: existing.userId,
                    coreIdentity: supabaseProfile.coreIdentity,
                    professionalBackground: supabaseProfile.professionalBackground,
                    networkingIntention: supabaseProfile.networkingIntention,
                    networkingPreferences: supabaseProfile.networkingPreferences,
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

            BrewMemoryStore.shared.seedMission(goal: mission, userId: currentUser.id)

            await MainActor.run {
                isProcessing = false
                phase = .done
                messages.append(OnboardingMessage(kind: .agentText("You're in! 🎉 I've saved your profile and your first mission — \"\(mission.prefix(80))\". Taking you in now…")))
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    authManager.updateProfileSetupCompleted(true)
                }
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                phase = .questions
                messages.append(OnboardingMessage(kind: .agentText("Hmm, something went wrong saving your profile. You can try again, or use the form — everything you told me is safe.")))
            }
            print("❌ [BrewOnboarding] save failed: \(error.localizedDescription)")
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

// MARK: - Timeslot Chips Card(🗓 8 个 chip → AvailableTimeslot)

struct TimeslotChipsCard: View {
    @Binding var choices: Set<String>
    var onDone: () -> Void

    @State private var didAct = false
    private var themeColor: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }

    private let rows: [(label: String, prefix: String)] = [
        ("Weekdays", "wd"), ("Weekends", "we")
    ]
    private let slots: [(label: String, key: String)] = [
        ("Morning", "morning"), ("Noon", "noon"), ("Afternoon", "afternoon"), ("Evening", "evening")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows, id: \.prefix) { row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    HStack(spacing: 8) {
                        ForEach(slots, id: \.key) { slot in
                            let key = "\(row.prefix)_\(slot.key)"
                            let on = choices.contains(key)
                            Button {
                                if on { choices.remove(key) } else { choices.insert(key) }
                            } label: {
                                Text(slot.label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(on ? .white : themeColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(on ? themeColor : themeColor.opacity(0.08)))
                            }
                        }
                    }
                }
            }
            Button {
                guard !didAct else { return }
                didAct = true
                onDone()
            } label: {
                Text(choices.isEmpty ? "Skip — I'll add later" : "Done ✓")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(didAct ? Color.gray.opacity(0.4) : themeColor))
            }
            .disabled(didAct)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(themeColor.opacity(0.12), lineWidth: 1))
    }
}
