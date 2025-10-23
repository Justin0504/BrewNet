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
                
                // Networking Intent Section
                ProfileSectionView(
                    title: "Networking Goals",
                    icon: "network"
                ) {
                    NetworkingIntentDisplayView(intent: profile.networkingIntent)
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

// MARK: - Networking Intent Display
struct NetworkingIntentDisplayView: View {
    let intent: NetworkingIntent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !intent.networkingIntent.isEmpty {
                TagsDisplayView(
                    title: "Networking Goals",
                    tags: intent.networkingIntent.map { $0.displayName }
                )
            }
            
            if !intent.conversationTopics.isEmpty {
                TagsDisplayView(
                    title: "Conversation Topics",
                    tags: intent.conversationTopics
                )
            }
            
            if !intent.collaborationInterest.isEmpty {
                TagsDisplayView(
                    title: "Collaboration Interests",
                    tags: intent.collaborationInterest.map { $0.displayName }
                )
            }
            
            if let goal = intent.coffeeChatGoal {
                InfoRow(label: "Coffee Chat Goal", value: goal)
            }
            
            InfoRow(label: "Preferred Format", value: intent.preferredChatFormat.displayName)
            
            if let duration = intent.preferredChatDuration {
                InfoRow(label: "Preferred Duration", value: duration)
            }
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
