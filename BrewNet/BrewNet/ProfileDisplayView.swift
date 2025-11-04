import SwiftUI
import PhotosUI

struct ProfileDisplayView: View {
    @State var profile: BrewNetProfile
    var onEditProfile: (() -> Void)?
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    // State variables for matches and invitations
    @State private var showingMatches = false
    @State private var matches: [SupabaseMatch] = []
    @State private var isLoadingMatches = false
    
    @State private var showingSentInvitations = false
    @State private var sentInvitations: [SupabaseInvitation] = []
    @State private var isLoadingInvitations = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header with new layout
                ProfileHeaderView(
                    profile: profile,
                    onEditProfile: onEditProfile,
                    onProfileUpdated: { updatedProfile in
                        profile = updatedProfile
                    }
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Networking Preferences Section
                ProfileSectionView(
                    title: "Network Preferences",
                    icon: "clock.fill"
                ) {
                    NetworkingPreferencesDisplayView(preferences: profile.networkingPreferences)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMatches()
            loadSentInvitations()
        }
        .sheet(isPresented: $showingMatches) {
            NavigationStack {
                MatchesListView(matches: matches, isLoading: isLoadingMatches)
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            }
        }
        .sheet(isPresented: $showingSentInvitations) {
            NavigationStack {
                SentInvitationsListView(invitations: sentInvitations, isLoading: isLoadingInvitations)
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            }
        }
    }
    
    private func loadMatches() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingMatches = true
        Task {
            do {
                let fetchedMatches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                
                // 过滤掉自己（不应该出现在匹配列表中）
                let filteredMatches = fetchedMatches.filter { match in
                    // 确定对方用户ID
                    let otherUserId: String
                    if match.userId == currentUser.id {
                        otherUserId = match.matchedUserId
                    } else {
                        otherUserId = match.userId
                    }
                    
                    // 确保对方用户不是当前用户（防御性检查）
                    let isValid = otherUserId != currentUser.id && !otherUserId.isEmpty
                    
                    if !isValid {
                        print("⚠️ Filtering out invalid match: user_id=\(match.userId), matched_user_id=\(match.matchedUserId), currentUser=\(currentUser.id)")
                    }
                    
                    return isValid
                }
                
                // 去重：确保每个匹配用户只显示一次
                // 因为数据库中可能有两条记录（user_id=A,matched_user_id=B 和 user_id=B,matched_user_id=A）
                var seenUserIds = Set<String>()
                let uniqueMatches = filteredMatches.filter { match in
                    // 确定对方用户ID
                    let otherUserId: String
                    if match.userId == currentUser.id {
                        otherUserId = match.matchedUserId
                    } else {
                        otherUserId = match.userId
                    }
                    
                    // 如果这个用户已经处理过，跳过
                    if seenUserIds.contains(otherUserId) {
                        print("⚠️ Skipping duplicate match for user: \(otherUserId)")
                        return false
                    }
                    
                    seenUserIds.insert(otherUserId)
                    return true
                }
                
                await MainActor.run {
                    matches = uniqueMatches
                    isLoadingMatches = false
                    print("✅ Loaded \(uniqueMatches.count) unique matches (from \(fetchedMatches.count) total, after filtering \(filteredMatches.count))")
                }
            } catch {
                print("❌ Failed to load matches: \(error.localizedDescription)")
                await MainActor.run {
                    matches = []
                    isLoadingMatches = false
                }
            }
        }
    }
    
    private func loadSentInvitations() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingInvitations = true
        Task {
            do {
                let fetchedInvitations = try await supabaseService.getSentInvitations(userId: currentUser.id)
                
                // 去重：对于同一个 receiver_id，只保留最新的邀请
                var uniqueInvitations: [SupabaseInvitation] = []
                var seenReceiverIds: Set<String> = []
                
                // 按创建时间排序，最新的在前
                let sortedInvitations = fetchedInvitations.sorted { inv1, inv2 in
                    let date1 = ISO8601DateFormatter().date(from: inv1.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: inv2.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
                
                // 只保留每个 receiver_id 的第一个（最新的）
                for invitation in sortedInvitations {
                    if !seenReceiverIds.contains(invitation.receiverId) {
                        uniqueInvitations.append(invitation)
                        seenReceiverIds.insert(invitation.receiverId)
                    }
                }
                
                await MainActor.run {
                    sentInvitations = uniqueInvitations
                    isLoadingInvitations = false
                    print("✅ Loaded \(uniqueInvitations.count) unique sent invitations (removed \(fetchedInvitations.count - uniqueInvitations.count) duplicates)")
                }
            } catch {
                print("❌ Failed to load sent invitations: \(error.localizedDescription)")
                await MainActor.run {
                    sentInvitations = []
                    isLoadingInvitations = false
                }
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let profile: BrewNetProfile
    var onEditProfile: (() -> Void)?
    var onProfileUpdated: ((BrewNetProfile) -> Void)?
    
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingImage = false
    
    // 计算资料完成度百分比
    private var profileCompletionPercentage: Int {
        var completedFields = 0
        var totalFields = 0
        
        // Core Identity
        totalFields += 4
        if !profile.coreIdentity.name.isEmpty { completedFields += 1 }
        if !profile.coreIdentity.email.isEmpty { completedFields += 1 }
        if profile.coreIdentity.profileImage != nil { completedFields += 1 }
        if profile.coreIdentity.bio != nil && !profile.coreIdentity.bio!.isEmpty { completedFields += 1 }
        
        // Professional Background
        totalFields += 2
        if profile.professionalBackground.currentCompany != nil { completedFields += 1 }
        if profile.professionalBackground.jobTitle != nil { completedFields += 1 }
        
        // Education
        totalFields += 1
        if profile.professionalBackground.education != nil && !profile.professionalBackground.education!.isEmpty { completedFields += 1 }
        
        guard totalFields > 0 else { return 0 }
        return Int((Double(completedFields) / Double(totalFields)) * 100)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Avatar + Progress Circle on left, Name + Age + Icons on right
            HStack(alignment: .top, spacing: 16) {
                // Left: Profile Image with Progress Circle
                ZStack {
                    // Progress Circle (outer, red)
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    // Progress Circle (filled portion, red)
                    Circle()
                        .trim(from: 0, to: CGFloat(profileCompletionPercentage) / 100)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    // Profile Image (inner)
                    AsyncImage(url: URL(string: profile.coreIdentity.profileImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    
                    // Percentage badge at bottom
                    VStack {
                        Spacer()
                        Text("\(profileCompletionPercentage)%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white)
                            .cornerRadius(8)
                            .offset(y: 5)
                    }
                    .frame(width: 100, height: 100)
                }
                
                // Right: Name, Age, Icons, and Company/Title button
                VStack(alignment: .leading, spacing: 8) {
                    // Name and Age (横向并列)
                    HStack(spacing: 4) {
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                        
                        // Age would need to be calculated from birthdate if available
                        // For now, we'll skip it if not available
                    }
                    
                    // Icons row (横向并列)
                    HStack(spacing: 12) {
                        // Camera icon (blue) - 可点击更换头像
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                if isUploadingImage {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                        }
                        
                        // Verification icon (grey)
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .frame(width: 24, height: 24)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    // Company/School and Title button (在图标下面，白色背景，可点击编辑)
                    Button(action: {
                        onEditProfile?()
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .foregroundColor(BrewTheme.primaryBrown)
                                .font(.system(size: 14))
                            
                            // 优先显示公司，如果没有则显示学校
                            if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                                Text(company)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            } else if let education = profile.professionalBackground.education, !education.isEmpty {
                                // 如果没有公司，显示学校
                                Text(education)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                // 如果都没有，显示占位符
                                Text("Complete Your Profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.white)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                guard let newItem = newItem else { return }
                
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        isUploadingImage = true
                    }
                    
                    // Upload image to Supabase Storage
                    if let userId = authManager.currentUser?.id {
                        do {
                            print("📤 Uploading profile image...")
                            
                            // Detect file extension from data or use jpg as default
                            let fileExtension = detectImageFormat(from: data) ?? "jpg"
                            
                            // Upload to Supabase Storage
                            let publicURL = try await supabaseService.uploadProfileImage(
                                userId: userId,
                                imageData: data,
                                fileExtension: fileExtension
                            )
                            
                            // Update profile with new image URL
                            let updatedCoreIdentity = CoreIdentity(
                                name: profile.coreIdentity.name,
                                email: profile.coreIdentity.email,
                                phoneNumber: profile.coreIdentity.phoneNumber,
                                profileImage: publicURL,
                                bio: profile.coreIdentity.bio,
                                pronouns: profile.coreIdentity.pronouns,
                                location: profile.coreIdentity.location,
                                personalWebsite: profile.coreIdentity.personalWebsite,
                                githubUrl: profile.coreIdentity.githubUrl,
                                linkedinUrl: profile.coreIdentity.linkedinUrl,
                                timeZone: profile.coreIdentity.timeZone
                            )
                            
                            // Create updated profile
                            let updatedProfile = BrewNetProfile(
                                id: profile.id,
                                userId: profile.userId,
                                createdAt: profile.createdAt,
                                updatedAt: ISO8601DateFormatter().string(from: Date()),
                                coreIdentity: updatedCoreIdentity,
                                professionalBackground: profile.professionalBackground,
                                networkingIntention: profile.networkingIntention,
                                networkingPreferences: profile.networkingPreferences,
                                personalitySocial: profile.personalitySocial,
                                privacyTrust: profile.privacyTrust
                            )
                            
                            // Update in Supabase
                            let supabaseProfile = SupabaseProfile(
                                id: profile.id,
                                userId: profile.userId,
                                coreIdentity: updatedCoreIdentity,
                                professionalBackground: profile.professionalBackground,
                                networkingIntention: profile.networkingIntention,
                                networkingPreferences: profile.networkingPreferences,
                                personalitySocial: profile.personalitySocial,
                                privacyTrust: profile.privacyTrust,
                                createdAt: profile.createdAt,
                                updatedAt: ISO8601DateFormatter().string(from: Date())
                            )
                            
                            _ = try await supabaseService.updateProfile(profileId: profile.id, profile: supabaseProfile)
                            
                            await MainActor.run {
                                isUploadingImage = false
                                onProfileUpdated?(updatedProfile)
                                print("✅ Profile image uploaded and updated successfully: \(publicURL)")
                                // Post notification to refresh profile
                                NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                            }
                        } catch {
                            await MainActor.run {
                                isUploadingImage = false
                                print("❌ Failed to upload profile image: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to detect image format from data
    private func detectImageFormat(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        // Check for JPEG
        if data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
            return "jpg"
        }
        
        // Check for PNG
        if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return "png"
        }
        
        // Check for GIF
        if String(data: data.prefix(6), encoding: .ascii) == "GIF89a" || String(data: data.prefix(6), encoding: .ascii) == "GIF87a" {
            return "gif"
        }
        
        return nil
    }
}

// MARK: - Profile Section Container
struct ProfileSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Core Identity Display
struct CoreIdentityDisplayView: View {
    let identity: CoreIdentity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let pronouns = identity.pronouns {
                InfoRow(label: "Pronouns", value: pronouns)
            }
            
            InfoRow(label: "Email", value: identity.email)
            
            if let phoneNumber = identity.phoneNumber {
                InfoRow(label: "Phone", value: phoneNumber)
            }
            
            InfoRow(label: "Time Zone", value: identity.timeZone)
        }
    }
}

// MARK: - Professional Background Display
struct ProfessionalBackgroundDisplayView: View {
    let background: ProfessionalBackground
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let industry = background.industry {
                InfoRow(label: "Industry", value: industry)
            }
            
            InfoRow(label: "Experience Level", value: background.experienceLevel.displayName)
            
            if let years = background.yearsOfExperience {
                InfoRow(label: "Years of Experience", value: "\(years) years")
            }
            
            InfoRow(label: "Career Stage", value: background.careerStage.displayName)
            
            if let education = background.education {
                InfoRow(label: "Education", value: education)
            }
            
            if !background.skills.isEmpty {
                SkillsDisplayView(skills: background.skills)
            }
            
            if !background.certifications.isEmpty {
                CertificationsDisplayView(certifications: background.certifications)
            }
            
            if !background.languagesSpoken.isEmpty {
                LanguagesDisplayView(languages: background.languagesSpoken)
            }
        }
    }
}

// MARK: - Networking Intention Display
struct NetworkingIntentionDisplayView: View {
    let intention: NetworkingIntention
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Main Intention", value: intention.selectedIntention.displayName)
            
            if let careerDirection = intention.careerDirection {
                CareerDirectionDisplayView(data: careerDirection)
            }
            
            if let skillDevelopment = intention.skillDevelopment {
                SkillDevelopmentDisplayView(data: skillDevelopment)
            }
            
            if let industryTransition = intention.industryTransition {
                IndustryTransitionDisplayView(data: industryTransition)
            }
        }
    }
}

// MARK: - Networking Preferences Display
struct NetworkingPreferencesDisplayView: View {
    let preferences: NetworkingPreferences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Preferred Format", value: preferences.preferredChatFormat.displayName)
            
            if let duration = preferences.preferredChatDuration {
                InfoRow(label: "Preferred Duration", value: duration)
            }
            
            AvailableTimeslotDisplayView(timeslot: preferences.availableTimeslot)
        }
    }
}

// MARK: - Career Direction Display
struct CareerDirectionDisplayView: View {
    let data: CareerDirectionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Career Direction")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.functions, id: \.functionName) { function in
                VStack(alignment: .leading, spacing: 4) {
                    Text(function.functionName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if !function.learnIn.isEmpty {
                        Text("Learn in: \(function.learnIn.joined(separator: ", "))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    if !function.guideIn.isEmpty {
                        Text("Guide in: \(function.guideIn.joined(separator: ", "))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Skill Development Display
struct SkillDevelopmentDisplayView: View {
    let data: SkillDevelopmentData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.skills, id: \.skillName) { skill in
                HStack {
                    Text(skill.skillName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if skill.learnIn {
                        Text("Learn")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if skill.guideIn {
                        Text("Guide")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

// MARK: - Industry Transition Display
struct IndustryTransitionDisplayView: View {
    let data: IndustryTransitionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Industries")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            ForEach(data.industries, id: \.industryName) { industry in
                HStack {
                    Text(industry.industryName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if industry.learnIn {
                        Text("Learn")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if industry.guideIn {
                        Text("Guide")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
}

// MARK: - Available Timeslot Display
struct AvailableTimeslotDisplayView: View {
    let timeslot: AvailableTimeslot
    
    private let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let timeSlots = ["Morning", "Noon", "Afternoon", "Evening", "Night"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Times")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            VStack(spacing: 4) {
                // Header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: 60)
                    
                    ForEach(days, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Time slot rows
                ForEach(Array(timeSlots.enumerated()), id: \.offset) { timeIndex, timeSlot in
                    HStack(spacing: 0) {
                        Text(timeSlot)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 60, alignment: .leading)
                        
                        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, _ in
                            Rectangle()
                                .fill(getTimeslotValue(dayIndex: dayIndex, timeIndex: timeIndex) ? Color.blue : Color.gray.opacity(0.1))
                                .frame(width: 20, height: 20)
                                .cornerRadius(3)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
    
    private func getTimeslotValue(dayIndex: Int, timeIndex: Int) -> Bool {
        let dayTimeslots = getDayTimeslots(dayIndex: dayIndex)
        switch timeIndex {
        case 0: return dayTimeslots.morning
        case 1: return dayTimeslots.noon
        case 2: return dayTimeslots.afternoon
        case 3: return dayTimeslots.evening
        case 4: return dayTimeslots.night
        default: return false
        }
    }
    
    private func getDayTimeslots(dayIndex: Int) -> DayTimeslots {
        switch dayIndex {
        case 0: return timeslot.sunday
        case 1: return timeslot.monday
        case 2: return timeslot.tuesday
        case 3: return timeslot.wednesday
        case 4: return timeslot.thursday
        case 5: return timeslot.friday
        case 6: return timeslot.saturday
        default: return DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false)
        }
    }
}

// MARK: - Personality & Social Display
struct PersonalitySocialDisplayView: View {
    let personality: PersonalitySocial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !personality.valuesTags.isEmpty {
                TagsDisplayView(
                    title: "Values",
                    tags: personality.valuesTags
                )
            }
            
            if !personality.hobbies.isEmpty {
                TagsDisplayView(
                    title: "Hobbies & Interests",
                    tags: personality.hobbies
                )
            }
            
            InfoRow(label: "Meeting Vibe", value: personality.preferredMeetingVibe.displayName)
        }
    }
}

// MARK: - Privacy & Trust Display
struct PrivacyTrustDisplayView: View {
    let privacy: PrivacyTrust
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(label: "Data Sharing", value: privacy.dataSharingConsent ? "Enabled" : "Disabled")
            InfoRow(label: "Verification Status", value: privacy.verifiedStatus.displayName)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Visibility Settings")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                VStack(alignment: .leading, spacing: 4) {
                    VisibilityRow(label: "Company", level: privacy.visibilitySettings.company)
                    VisibilityRow(label: "Email", level: privacy.visibilitySettings.email)
                    VisibilityRow(label: "Phone", level: privacy.visibilitySettings.phoneNumber)
                    VisibilityRow(label: "Location", level: privacy.visibilitySettings.location)
                    VisibilityRow(label: "Skills", level: privacy.visibilitySettings.skills)
                    VisibilityRow(label: "Interests", level: privacy.visibilitySettings.interests)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Spacer()
        }
    }
}

struct TagsDisplayView: View {
    let title: String
    let tags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct SkillsDisplayView: View {
    let skills: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Skills")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    Text(skill)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.2, green: 0.6, blue: 0.8))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct CertificationsDisplayView: View {
    let certifications: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certifications")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(certifications, id: \.self) { cert in
                    Text(cert)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.8, green: 0.4, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct LanguagesDisplayView: View {
    let languages: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Languages")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(languages, id: \.self) { language in
                    Text(language)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.4, green: 0.6, blue: 0.2))
                        .cornerRadius(16)
                }
            }
        }
    }
}

struct VisibilityRow: View {
    let label: String
    let level: VisibilityLevel
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            Text(level.displayName)
                .font(.system(size: 12))
                .foregroundColor(level == .public_ ? .green : level == .connectionsOnly ? .orange : .red)
            
            Spacer()
        }
    }
}

// MARK: - Matches List View
struct MatchesListView: View {
    let matches: [SupabaseMatch]
    let isLoading: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if matches.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text("No Matches Yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("Start sending invitations to find your matches!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                List {
                    ForEach(matches) { match in
                        MatchRowView(match: match)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("My Matches")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
    }
}

// MARK: - Match Row View
struct MatchRowView: View {
    let match: SupabaseMatch
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @State private var matchedUserProfile: BrewNetProfile?
    
    // 确定应该显示的用户ID和名称
    private var displayUserId: String {
        guard let currentUser = authManager.currentUser else {
            return match.matchedUserId
        }
        // 如果当前用户是 user_id，则显示 matched_user_id
        // 如果当前用户是 matched_user_id，则显示 user_id
        if match.userId == currentUser.id {
            return match.matchedUserId
        } else {
            return match.userId
        }
    }
    
    private var displayUserName: String {
        if let profile = matchedUserProfile {
            return profile.coreIdentity.name
        }
        // 如果还没加载到 profile，使用匹配记录中的名称
        guard let currentUser = authManager.currentUser else {
            return match.matchedUserName
        }
        // 如果当前用户是 user_id，matched_user_name 就是对方的名字
        if match.userId == currentUser.id {
            return match.matchedUserName
        } else {
            // 如果当前用户是 matched_user_id，matched_user_name 是当前用户的名字
            // 需要返回 user_id 对应的用户名，但我们暂时返回一个占位符
            return "Loading..."
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayUserName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text(match.matchType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                if let createdAt = parseDate(match.createdAt) {
                    Text("Matched \(formatDate(createdAt))")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Match indicator
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
        }
        .padding(.vertical, 8)
        .onAppear {
            loadMatchedUserProfile()
        }
    }
    
    private func loadMatchedUserProfile() {
        Task {
            // 加载应该显示的用户信息
            if let profile = try? await supabaseService.getProfile(userId: displayUserId) {
                await MainActor.run {
                    matchedUserProfile = profile.toBrewNetProfile()
                }
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Sent Invitations List View
struct SentInvitationsListView: View {
    let invitations: [SupabaseInvitation]
    let isLoading: Bool
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else if invitations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    Text("No Sent Invitations")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("Start exploring and send invitations to connect!")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                List {
                    ForEach(invitations) { invitation in
                        SentInvitationRowView(invitation: invitation)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Sent Invitations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
    }
}

// MARK: - Sent Invitation Row View
struct SentInvitationRowView: View {
    let invitation: SupabaseInvitation
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var receiverProfile: BrewNetProfile?
    @State private var showingProfileCard = false
    
    var body: some View {
        Button(action: {
            if receiverProfile != nil {
                showingProfileCard = true
            }
        }) {
            HStack(spacing: 12) {
                // Avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(receiverProfile?.coreIdentity.name ?? "Loading...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(invitation.status.rawValue.capitalized)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    if let createdAt = parseDate(invitation.createdAt) {
                        Text("Sent \(formatDate(createdAt))")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadReceiverProfile()
        }
        .sheet(isPresented: $showingProfileCard) {
            if let profile = receiverProfile {
                PublicProfileView(profile: profile)
                    .environmentObject(supabaseService)
            }
        }
    }
    
    private var statusColor: Color {
        switch invitation.status {
        case .pending:
            return .orange
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    private var statusIcon: String {
        switch invitation.status {
        case .pending:
            return "clock.fill"
        case .accepted:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }
    
    private func loadReceiverProfile() {
        Task {
            if let profile = try? await supabaseService.getProfile(userId: invitation.receiverId) {
                await MainActor.run {
                    receiverProfile = profile.toBrewNetProfile()
                }
            }
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Public Profile View (Read-only view for viewing other users' profiles)
struct PublicProfileView: View {
    let profile: BrewNetProfile
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            // Use unified PublicProfileCardView
            PublicProfileCardView(profile: profile)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
        }
    }
}

// MARK: - Public Professional Background Display View
struct PublicProfessionalBackgroundDisplayView: View {
    let background: ProfessionalBackground
    let visibilitySettings: VisibilitySettings
    
    // Helper to check if a field should be visible based on privacy settings
    private func isVisible(_ visibilityLevel: VisibilityLevel) -> Bool {
        return visibilityLevel == .public_
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only show skills if public
            if isVisible(visibilitySettings.skills) && !background.skills.isEmpty {
                SkillsDisplayView(skills: background.skills)
            }
            
            // Note: Other fields like industry, experience level, career stage, etc.
            // don't have individual privacy controls, so we can show them
            if let industry = background.industry {
                InfoRow(label: "Industry", value: industry)
            }
            
            InfoRow(label: "Experience Level", value: background.experienceLevel.displayName)
            
            if let years = background.yearsOfExperience {
                InfoRow(label: "Years of Experience", value: "\(years) years")
            }
            
            InfoRow(label: "Career Stage", value: background.careerStage.displayName)
            
            if let education = background.education {
                InfoRow(label: "Education", value: education)
            }
            
            if !background.certifications.isEmpty {
                CertificationsDisplayView(certifications: background.certifications)
            }
            
            if !background.languagesSpoken.isEmpty {
                LanguagesDisplayView(languages: background.languagesSpoken)
            }
        }
    }
}

// MARK: - Public Profile Header View
struct PublicProfileHeaderView: View {
    let profile: BrewNetProfile
    
    // Helper to check if a field should be visible based on privacy settings
    private func isVisible(_ visibilityLevel: VisibilityLevel) -> Bool {
        return visibilityLevel == .public_
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Avatar on left, Name on right
            HStack(alignment: .top, spacing: 16) {
                // Left: Profile Image
                ZStack {
                    AsyncImage(url: URL(string: profile.coreIdentity.profileImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                }
                
                // Right: Name and basic info
                VStack(alignment: .leading, spacing: 8) {
                    // Name (always visible)
                    HStack(spacing: 4) {
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    // Pronouns (always visible)
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Location (only if public)
                    if isVisible(profile.privacyTrust.visibilitySettings.location),
                       let location = profile.coreIdentity.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Company/School and Title button (only if company is public)
                    if isVisible(profile.privacyTrust.visibilitySettings.company) {
                        HStack {
                            // 优先显示公司，如果没有则显示学校
                            if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                                Text(company)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            } else if let education = profile.professionalBackground.education, !education.isEmpty {
                                // 如果没有公司，显示学校
                                Text(education)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                
                                // 如果有 title，显示在后面
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text(" · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.white)
        .onAppear {
            print("🌍 显示公开 Profile: \(profile.coreIdentity.name)")
        }
    }
}

// MARK: - Preview
struct ProfileDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileDisplayView(profile: BrewNetProfile.createDefault(userId: "preview")) {
                // Preview doesn't need action
            }
        }
    }
}
