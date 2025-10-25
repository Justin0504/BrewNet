import SwiftUI

struct ProfileDisplayView: View {
    let profile: BrewNetProfile
    @State private var showingEditProfile = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                ProfileHeaderView(profile: profile)
                
                // Core Identity Section
                ProfileSectionView(
                    title: "About",
                    icon: "person.circle.fill"
                ) {
                    CoreIdentityDisplayView(identity: profile.coreIdentity)
                }
                
                // Professional Background Section
                ProfileSectionView(
                    title: "Professional Background",
                    icon: "briefcase.fill"
                ) {
                    ProfessionalBackgroundDisplayView(background: profile.professionalBackground)
                }
                
                // Networking Intention Section
                ProfileSectionView(
                    title: "Networking Intention",
                    icon: "network"
                ) {
                    NetworkingIntentionDisplayView(intention: profile.networkingIntention)
                }
                
                // Networking Preferences Section
                ProfileSectionView(
                    title: "Networking Preferences",
                    icon: "clock.fill"
                ) {
                    NetworkingPreferencesDisplayView(preferences: profile.networkingPreferences)
                }
                
                // Personality & Social Section
                ProfileSectionView(
                    title: "Personality & Interests",
                    icon: "heart.fill"
                ) {
                    PersonalitySocialDisplayView(personality: profile.personalitySocial)
                }
                
                // Privacy Settings Section
                ProfileSectionView(
                    title: "Privacy Settings",
                    icon: "lock.fill"
                ) {
                    PrivacyTrustDisplayView(privacy: profile.privacyTrust)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("My Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditProfile = true
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            ProfileSetupView()
        }
    }
}

// MARK: - Profile Header
struct ProfileHeaderView: View {
    let profile: BrewNetProfile
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: URL(string: profile.coreIdentity.profileImage ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 3)
            )
            
            // Name and Title
            VStack(spacing: 4) {
                Text(profile.coreIdentity.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                if let jobTitle = profile.professionalBackground.jobTitle {
                    Text(jobTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                if let company = profile.professionalBackground.currentCompany {
                    Text(company)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if let location = profile.coreIdentity.location {
                    HStack {
                        Image(systemName: "location")
                            .font(.system(size: 12))
                        Text(location)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray)
                }
            }
            
            // Bio
            if let bio = profile.coreIdentity.bio {
                Text(bio)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
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
            InfoRow(label: "Communication Style", value: personality.communicationStyle.displayName)
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
            ProfileDisplayView(profile: BrewNetProfile.createDefault(userId: "preview"))
        }
    }
}
