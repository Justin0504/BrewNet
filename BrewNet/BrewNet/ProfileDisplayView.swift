import SwiftUI
import PhotosUI

struct ProfileDisplayView: View {
    @State var profile: BrewNetProfile
    var onEditProfile: (() -> Void)?
    var onProfileUpdated: ((BrewNetProfile) -> Void)?
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    // State variables for matches and invitations
    @State private var showingMatches = false
    @State private var matches: [SupabaseMatch] = []
    @State private var isLoadingMatches = false
    
    @State private var showingSentInvitations = false
    @State private var sentInvitations: [SupabaseInvitation] = []
    @State private var isLoadingInvitations = false
    
    // State variable for showing profile card
    @State private var showingProfileCard = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header with new layout
                ProfileHeaderView(
                    profile: profile,
                    onEditProfile: onEditProfile,
                    onProfileUpdated: { updatedProfile in
                        profile = updatedProfile
                        // 同时调用父视图的回调，确保更新同步
                        onProfileUpdated?(updatedProfile)
                    },
                    onShowProfileCard: {
                        showingProfileCard = true
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
        .sheet(isPresented: $showingProfileCard) {
            // 显示用户自己的 profile 卡片
            // 使用 isConnection: true 来显示 connections_only 的内容（因为是自己查看自己）
            // 但 private 的内容仍然不会显示（符合隐私设置）
            UserProfileCardSheetView(
                profile: profile,
                isConnection: true // 自己查看自己，所以 connections_only 的内容也应该显示
            )
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
    var onShowProfileCard: (() -> Void)?
    
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isUploadingImage = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    
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
            // 整个区域包装成可点击的 Button
            Button(action: {
                onShowProfileCard?()
            }) {
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
                        
                        // Company/School and Title display (仅显示，不可点击)
                        HStack {
                            // 优先显示公司，如果没有则显示学校
                            if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text("\(company) · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                } else {
                                    Text(company)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            } else if let education = profile.professionalBackground.education, !education.isEmpty {
                                // 如果没有公司，显示学校
                                if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                                    Text("\(education) · \(jobTitle)")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                } else {
                                    Text(education)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            } else {
                                // 如果都没有，显示占位符
                                Text("Complete Your Profile")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
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
                    
                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
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
                            
                            // Update in Supabase database
                            let updatedSupabaseProfile = try await supabaseService.updateProfile(profileId: profile.id, profile: supabaseProfile)
                            print("✅ Profile updated in database successfully")
                            
                            // Verify the update by reloading from database
                            if let verifiedProfile = try? await supabaseService.getProfile(userId: profile.userId) {
                                let verifiedBrewNetProfile = verifiedProfile.toBrewNetProfile()
                                print("✅ Verified profile update from database, new image URL: \(verifiedBrewNetProfile.coreIdentity.profileImage ?? "nil")")
                            
                            await MainActor.run {
                                isUploadingImage = false
                                    // Update with verified profile from database
                                    onProfileUpdated?(verifiedBrewNetProfile)
                                    showSuccessAlert = true
                                print("✅ Profile image uploaded and updated successfully: \(publicURL)")
                                // Post notification to refresh profile
                                NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                                }
                            } else {
                                // If verification fails, still update with what we have
                                await MainActor.run {
                                    isUploadingImage = false
                                    onProfileUpdated?(updatedProfile)
                                    showSuccessAlert = true
                                    print("✅ Profile image uploaded and updated (verification skipped): \(publicURL)")
                                    NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                                }
                            }
                        } catch {
                            await MainActor.run {
                                isUploadingImage = false
                                errorMessage = "Failed to update profile image: \(error.localizedDescription)"
                                showErrorAlert = true
                                print("❌ Failed to upload profile image: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Profile image updated successfully!")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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

// MARK: - User Profile Card Sheet View
struct UserProfileCardSheetView: View {
    let profile: BrewNetProfile
    let isConnection: Bool // Whether the current user is connected to this profile
    
    @Environment(\.dismiss) var dismiss
    
    // Verify privacy settings are loaded from database
    private var privacySettings: VisibilitySettings {
        let settings = profile.privacyTrust.visibilitySettings
        // Log privacy settings for debugging
        print("🔒 Profile Page Privacy Settings for \(profile.coreIdentity.name):")
        print("   - company: \(settings.company.rawValue) -> visible: \(settings.company.isVisible(isConnection: isConnection))")
        print("   - skills: \(settings.skills.rawValue) -> visible: \(settings.skills.isVisible(isConnection: isConnection))")
        print("   - interests: \(settings.interests.rawValue) -> visible: \(settings.interests.isVisible(isConnection: isConnection))")
        print("   - location: \(settings.location.rawValue) -> visible: \(settings.location.isVisible(isConnection: isConnection))")
        print("   - timeslot: \(settings.timeslot.rawValue) -> visible: \(settings.timeslot.isVisible(isConnection: isConnection))")
        print("   - isConnection: \(isConnection)")
        return settings
    }
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .frame(width: screenWidth - 40, height: screenHeight * 0.85)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Level 1: Core Information Area
                        level1CoreInfoView
                        
                        // Level 2: Matching Clues
                        level2MatchingCluesView
                        
                        // Level 3: Deep Understanding
                        level3DeepUnderstandingView
                    }
                    .frame(maxWidth: screenWidth - 40)
                }
                .frame(height: screenHeight * 0.85)
                .cornerRadius(20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Level 1: Core Information Area
    private var level1CoreInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Image and Name Section
            HStack(alignment: .top, spacing: 16) {
                // Profile Image
                profileImageView
                
                // Name and Pronouns
                VStack(alignment: .leading, spacing: 8) {
                    // Name - 独立换行
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .lineLimit(nil)
                    
                    // Pronouns - 独立一行
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Headline / Bio
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                    }
                }
                
                Spacer()
            }
            
            // Professional Info (only if company visibility is public or connections_only)
            if shouldShowCompany {
                HStack(spacing: 8) {
                    if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                        Text(jobTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                        
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            Text("@")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            // Industry and Experience Level
            HStack(spacing: 8) {
                if let industry = profile.professionalBackground.industry, !industry.isEmpty {
                    Text(industry)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(nil)
                    
                    if profile.professionalBackground.experienceLevel != .entry {
                        Text("·")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text(profile.professionalBackground.experienceLevel.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Networking Intention Badge
            NetworkingIntentionBadgeView(intention: profile.networkingIntention.selectedIntention)
            
            // Preferred Chat Format
            HStack(spacing: 8) {
                // Chat Format Icon
                Image(systemName: chatFormatIcon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Text(profile.networkingPreferences.preferredChatFormat.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                
                Spacer()
            }
            
            // Available Timeslot Grid (same UI as Profile page)
            if shouldShowTimeslot {
                AvailableTimeslotDisplayView(timeslot: profile.networkingPreferences.availableTimeslot)
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    private var profileImageView: some View {
        ZStack {
            if let imageUrl = profile.coreIdentity.profileImage, !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderImageView
                    @unknown default:
                        placeholderImageView
                    }
                }
            } else {
                placeholderImageView
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 2)
        )
    }
    
    private var placeholderImageView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.4, blue: 0.2),
                Color(red: 0.4, green: 0.2, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        )
    }
    
    private var chatFormatIcon: String {
        switch profile.networkingPreferences.preferredChatFormat {
        case .virtual:
            return "video.fill"
        case .inPerson:
            return "person.2.fill"
        case .either:
            return "repeat"
        }
    }
    
    // MARK: - Level 2: Matching Clues
    private var level2MatchingCluesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // Sub-Intentions
            if !profile.networkingIntention.selectedSubIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("What I'm Looking For")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.selectedSubIntentions, id: \.self) { subIntention in
                            Text(subIntention.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Skills (only if public or connections_only)
            if shouldShowSkills && !profile.professionalBackground.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Skills & Expertise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Values
            if !profile.personalitySocial.valuesTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Vibe & Values")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.personalitySocial.valuesTags, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Hobbies & Interests (only if public or connections_only)
            if shouldShowInterests && !profile.personalitySocial.hobbies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Interests")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.personalitySocial.hobbies, id: \.self) { hobby in
                                Text(hobby)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            
            // Preferred Meeting Vibe
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Meeting Vibe:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    Text(profile.personalitySocial.preferredMeetingVibe.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Level 3: Deep Understanding
    private var level3DeepUnderstandingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // Self Introduction
            if let selfIntro = profile.personalitySocial.selfIntroduction, !selfIntro.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("About Me")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    Text(selfIntro)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            
            // Education
            if let education = profile.professionalBackground.education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Education")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    Text(education)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            
            // Work Experience (summary)
            if !profile.professionalBackground.workExperiences.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Experience")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ForEach(profile.professionalBackground.workExperiences.prefix(3), id: \.id) { workExp in
                        WorkExperienceRowView(workExp: workExp)
                    }
                    
                    if let yearsOfExp = profile.professionalBackground.yearsOfExperience {
                        Text("Total: \(String(format: "%.1f", yearsOfExp)) years of experience")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            }
            
            // Personal Website
            if let website = profile.coreIdentity.personalWebsite, !website.isEmpty,
               let websiteUrl = URL(string: website) {
                Link(destination: websiteUrl) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("View Portfolio")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Location (only if public or connections_only)
            if shouldShowLocation, let location = profile.coreIdentity.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Text(location)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 30)
        .background(Color.white)
    }
    
    // MARK: - Privacy Visibility Checks (strictly follows database privacy_trust.visibility_settings)
    // Shows fields marked as "public" or "connections_only" when isConnection is true
    private var shouldShowCompany: Bool {
        let settings = privacySettings
        let visible = settings.company.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Company hidden: \(settings.company.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowSkills: Bool {
        let settings = privacySettings
        let visible = settings.skills.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Skills hidden: \(settings.skills.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowInterests: Bool {
        let settings = privacySettings
        let visible = settings.interests.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Interests hidden: \(settings.interests.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowLocation: Bool {
        let settings = privacySettings
        let visible = settings.location.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Location hidden: \(settings.location.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowTimeslot: Bool {
        let settings = privacySettings
        let visible = settings.timeslot.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Timeslot hidden: \(settings.timeslot.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
}

// Note: NetworkingIntentionBadgeView, WorkExperienceRowView, and FlowLayout are defined in UserProfileCardView.swift
// They are reused here to avoid code duplication

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
