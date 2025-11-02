import SwiftUI
import PhotosUI

struct ProfileDisplayView: View {
    @State var profile: BrewNetProfile
    var onEditProfile: (() -> Void)?
    
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
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.large)
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
                                Text("完成个人资料")
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
                                timeZone: profile.coreIdentity.timeZone,
                                availableTimeslot: profile.coreIdentity.availableTimeslot
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
