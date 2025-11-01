import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var currentStep = 1
    @State private var profileData = ProfileCreationData()
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showCompletion = false
    @State private var showDatabaseSetup = false
    @State private var isNavigating = false
    @State private var isLoadingExistingData = false
    
    private let totalSteps = 6
    
    // MARK: - Computed Properties
    private var progressPercentage: Int {
        Int(Double(currentStep) / Double(totalSteps) * 100)
    }
    
    private var progressHeaderView: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: BrewTheme.secondaryBrown))
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .padding(.horizontal, 32)
            
            // Step indicator
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(progressPercentage)% Complete")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 32)
            
            // Step title
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(BrewTheme.primaryBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Step description
            Text(stepDescription)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var navigationButtonsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                if currentStep > 1 {
                    Button(action: {
                        guard !isNavigating else { return }
                        isNavigating = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep -= 1
                        }
                        // Reset navigation state after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isNavigating = false
                        }
                    }) {
                        Text("Previous")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BrewTheme.primaryBrown)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .background(Color.white)
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(BrewTheme.primaryBrown, lineWidth: 2)
                    )
                    .disabled(isNavigating)
                }
                
                Button(action: {
                    guard !isNavigating else { return }
                    isNavigating = true
                    
                    if currentStep == totalSteps {
                        completeProfileSetup()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                    }
                    
                    // Reset navigation state after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNavigating = false
                    }
                }) {
                    Text(currentStep == totalSteps ? "Complete Setup" : "Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(
BrewTheme.gradientPrimary()
                )
                .cornerRadius(25)
                .disabled(isNavigating || isLoading)
                .opacity((isNavigating || isLoading) ? 0.6 : 1.0)
            }
            .padding(.horizontal, 32)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        BrewTheme.background,
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if showCompletion {
                    ProfileCompletionView()
                } else if isLoadingExistingData {
                    // 数据加载等待界面
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // 加载动画
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: BrewTheme.secondaryBrown))
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 12) {
                            Text("Loading Profile Data")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(BrewTheme.primaryBrown)
                            
                            Text("Please wait while we load your existing profile information...")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header with progress
                        progressHeaderView
                        .padding(.top, 20)
                        
                        // Content
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 24) {
                                    switch currentStep {
                                    case 1:
                                        CoreIdentityStep(profileData: $profileData)
                                            .id("step-1")
                                    case 2:
                                        ProfessionalBackgroundStep(profileData: $profileData)
                                            .id("step-2")
                                    case 3:
                                        NetworkingIntentionStep(profileData: $profileData)
                                            .id("step-3")
                                    case 4:
                                        NetworkingPreferencesStep(profileData: $profileData)
                                            .id("step-4")
                                    case 5:
                                        PersonalitySocialStep(profileData: $profileData)
                                            .id("step-5")
                                    case 6:
                                        PrivacyTrustStep(profileData: $profileData)
                                            .id("step-6")
                                    default:
                                        EmptyView()
                                    }
                                }
                                .padding(.horizontal, 32)
                                .padding(.top, 32)
                                .onChange(of: currentStep) { newStep in
                                    // Only scroll to top when step actually changes, not during picker interactions
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo("step-\(newStep)", anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Navigation buttons
                        navigationButtonsView
                        .padding(.bottom, 50)
                    }
                }
            }
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showDatabaseSetup) {
            DatabaseSetupView()
                .environmentObject(SupabaseService.shared)
        }
        .onAppear {
            loadExistingProfileData()
        }
    }
    
    // MARK: - Step Information
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Core Identity"
        case 2: return "Professional Background"
        case 3: return "Networking Intention"
        case 4: return "Networking Preferences"
        case 5: return "Personality & Social"
        case 6: return "Privacy & Trust"
        default: return ""
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 1: return "Tell us about yourself - the basics that help others connect with you"
        case 2: return "Share your professional experience and expertise"
        case 3: return "Define your networking goals and intentions"
        case 4: return "Set your networking preferences and availability"
        case 5: return "Show your personality and what makes you unique"
        case 6: return "Control your privacy and how others can discover you"
        default: return ""
        }
    }
    
    // MARK: - Profile Completion
    private func completeProfileSetup() {
        guard let currentUser = authManager.currentUser else {
            showAlert(message: "User not found. Please log in again.")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // First, try to ensure the profiles table exists
                do {
                    try await supabaseService.createProfilesTable()
                } catch {
                    print("⚠️ 无法自动创建 profiles 表，请手动创建")
                    // Continue anyway, the error will be caught below if table doesn't exist
                }
                
                // Check if profile already exists
                let existingProfile = try await supabaseService.getProfile(userId: currentUser.id)
                
                let supabaseProfile: SupabaseProfile
                
                if let existing = existingProfile {
                    // Update existing profile
                    print("🔄 Updating existing profile...")
                    
                    let updatedProfile = SupabaseProfile(
                        id: existing.id,
                        userId: existing.userId,
                        coreIdentity: profileData.coreIdentity ?? existing.coreIdentity,
                        professionalBackground: profileData.professionalBackground ?? existing.professionalBackground,
                        networkingIntention: profileData.networkingIntention ?? existing.networkingIntention,
                        networkingPreferences: profileData.networkingPreferences ?? existing.networkingPreferences,
                        personalitySocial: profileData.personalitySocial ?? existing.personalitySocial,
                        privacyTrust: profileData.privacyTrust ?? existing.privacyTrust,
                        createdAt: existing.createdAt,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    
                    supabaseProfile = try await supabaseService.updateProfile(profileId: existing.id, profile: updatedProfile)
                } else {
                    // Create new profile
                    print("🆕 Creating new profile...")
                    
                    let profile = BrewNetProfile.createDefault(userId: currentUser.id)
                    let updatedProfile = updateProfileWithCollectedData(profile)
                    
                    supabaseProfile = SupabaseProfile(
                        id: updatedProfile.id,
                        userId: updatedProfile.userId,
                        coreIdentity: updatedProfile.coreIdentity,
                        professionalBackground: updatedProfile.professionalBackground,
                        networkingIntention: updatedProfile.networkingIntention,
                        networkingPreferences: updatedProfile.networkingPreferences,
                        personalitySocial: updatedProfile.personalitySocial,
                        privacyTrust: updatedProfile.privacyTrust,
                        createdAt: updatedProfile.createdAt,
                        updatedAt: updatedProfile.updatedAt
                    )
                    
                    let _ = try await supabaseService.createProfile(profile: supabaseProfile)
                }
                
                // Update user profile setup status
                do {
                    try await supabaseService.updateUserProfileSetupCompleted(userId: currentUser.id, completed: true)
                    print("✅ Profile setup status updated in Supabase")
                } catch {
                    print("⚠️ Failed to update profile setup status in Supabase: \(error.localizedDescription)")
                    // Continue anyway, we'll update local state
                }
                
                await MainActor.run {
                    // Update local auth manager - this is critical for UI state
                    authManager.updateProfileSetupCompleted(true)
                    isLoading = false
                    showCompletion = true
                    print("✅ Profile setup completed locally")
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = error.localizedDescription
                    print("❌ Profile creation error: \(errorMessage)")
                    
                    if errorMessage.contains("core_identity") || errorMessage.contains("profiles") {
                        // 数据库架构问题，显示修复指导
                        showAlert(message: "数据库架构问题：缺少 core_identity 列。请在 Supabase Dashboard 的 SQL Editor 中执行修复脚本。")
                    } else if errorMessage.contains("does not exist") || errorMessage.contains("profile_image") {
                        // 缺少列的问题
                        showAlert(message: "数据库架构问题：缺少必需的列。请执行 fix_missing_columns.sql 修复脚本。")
                    } else if errorMessage.contains("value too long") || errorMessage.contains("character varying") {
                        // 字段长度限制问题
                        showAlert(message: "输入内容过长：某些字段超过了数据库限制。请检查并缩短输入内容，或执行数据库修复脚本。")
                    } else if errorMessage.contains("row-level security") || errorMessage.contains("violates") {
                        // RLS 权限问题
                        showAlert(message: "权限问题：请执行 fix_rls_policies.sql 脚本修复行级安全策略。")
                    } else if errorMessage.contains("foreign key constraint") || errorMessage.contains("profiles_user_id_fkey") {
                        // 外键约束问题
                        showAlert(message: "外键约束问题：请执行 fix_foreign_key.sql 脚本修复外键约束。")
                    } else if errorMessage.contains("profiles") && errorMessage.contains("table") {
                        showDatabaseSetup = true
                    } else {
                        showAlert(message: "Failed to save profile: \(errorMessage)")
                    }
                }
            }
        }
    }
    
    private func updateProfileWithCollectedData(_ profile: BrewNetProfile) -> BrewNetProfile {
        // Update the profile with the collected data from each step
        var updatedProfile = profile
        
        // Use data from profileData (user input from forms)
        let coreIdentity = profileData.coreIdentity ?? profile.coreIdentity
        let professionalBackground = profileData.professionalBackground ?? profile.professionalBackground
        let networkingIntention = profileData.networkingIntention ?? profile.networkingIntention
        let networkingPreferences = profileData.networkingPreferences ?? profile.networkingPreferences
        let personalitySocial = profileData.personalitySocial ?? profile.personalitySocial
        let privacyTrust = profileData.privacyTrust ?? profile.privacyTrust
        
        updatedProfile = BrewNetProfile(
            id: profile.id,
            userId: profile.userId,
            createdAt: profile.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            coreIdentity: coreIdentity,
            professionalBackground: professionalBackground,
            networkingIntention: networkingIntention,
            networkingPreferences: networkingPreferences,
            personalitySocial: personalitySocial,
            privacyTrust: privacyTrust
        )
        
        print("🔧 Updated profile with collected data:")
        print("📝 Name: '\(coreIdentity.name)'")
        print("📧 Email: '\(coreIdentity.email)'")
        print("📱 Phone: '\(coreIdentity.phoneNumber ?? "nil")'")
        print("📄 Bio: '\(coreIdentity.bio ?? "nil")'")
        
        return updatedProfile
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    // MARK: - Load Existing Profile Data
    private func loadExistingProfileData() {
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            return
        }
        
        isLoadingExistingData = true
        
        Task {
            do {
                // Try to load existing profile from Supabase
                if let existingProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    print("✅ Found existing profile, loading data...")
                    
                    await MainActor.run {
                        // Convert SupabaseProfile to ProfileCreationData
                        profileData.coreIdentity = existingProfile.coreIdentity
                        profileData.professionalBackground = existingProfile.professionalBackground
                        profileData.networkingIntention = existingProfile.networkingIntention
                        profileData.networkingPreferences = existingProfile.networkingPreferences
                        profileData.personalitySocial = existingProfile.personalitySocial
                        profileData.privacyTrust = existingProfile.privacyTrust
                        
                        isLoadingExistingData = false
                    }
                } else {
                    print("ℹ️ No existing profile found, starting fresh")
                    await MainActor.run {
                        isLoadingExistingData = false
                    }
                }
            } catch {
                print("❌ Failed to load existing profile: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingExistingData = false
                }
            }
        }
    }
}

// MARK: - Step 1: Core Identity
struct CoreIdentityStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var bio = ""
    @State private var pronouns = ""
    @State private var location = ""
    @State private var personalWebsite = ""
    @State private var githubUrl = ""
    @State private var linkedinUrl = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Name
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Full Name *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Spacer()
                    
                    Text("\(name.count)/100")
                        .font(.system(size: 12))
                        .foregroundColor(name.count > 100 ? .red : .gray)
                }
                
                TextField("Enter your full name", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.words)
                    .onChange(of: name) { newValue in
                        // 限制长度
                        if newValue.count > 100 {
                            name = String(newValue.prefix(100))
                        }
                    }
            }
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Phone Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("Enter your phone number", text: $phoneNumber)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.phonePad)
            }
            
            // Bio
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio (LinkedIn-style headline)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Spacer()
                    
                    Text("\(bio.count)/500")
                        .font(.system(size: 12))
                        .foregroundColor(bio.count > 500 ? .red : .gray)
                }
                
                TextField("e.g., Product designer helping teams bridge creativity & data", text: $bio)
                    .textFieldStyle(CustomTextFieldStyle())
                    .onChange(of: bio) { newValue in
                        // 限制长度
                        if newValue.count > 500 {
                            bio = String(newValue.prefix(500))
                        }
                    }
                
                if bio.count > 400 {
                    Text("⚠️ 简介过长，建议缩短到500字符以内")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
            
            // Pronouns
            VStack(alignment: .leading, spacing: 8) {
                Text("Pronouns")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("e.g., she/her, they/them", text: $pronouns)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("e.g., San Francisco, CA", text: $location)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Personal Website
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Website")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("https://yourwebsite.com", text: $personalWebsite)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            // GitHub URL
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("https://github.com/username", text: $githubUrl)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            // LinkedIn URL
            VStack(alignment: .leading, spacing: 8) {
                Text("LinkedIn Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("https://linkedin.com/in/username", text: $linkedinUrl)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
        }
        .onAppear {
            // Load existing data if available
            if let coreIdentity = profileData.coreIdentity {
                name = coreIdentity.name
                email = coreIdentity.email
                phoneNumber = coreIdentity.phoneNumber ?? ""
                bio = coreIdentity.bio ?? ""
                pronouns = coreIdentity.pronouns ?? ""
                location = coreIdentity.location ?? ""
                personalWebsite = coreIdentity.personalWebsite ?? ""
                githubUrl = coreIdentity.githubUrl ?? ""
                linkedinUrl = coreIdentity.linkedinUrl ?? ""
            }
        }
        .onChange(of: name) { _ in updateProfileData() }
        .onChange(of: email) { _ in updateProfileData() }
        .onChange(of: phoneNumber) { _ in updateProfileData() }
        .onChange(of: bio) { _ in updateProfileData() }
        .onChange(of: pronouns) { _ in updateProfileData() }
        .onChange(of: location) { _ in updateProfileData() }
        .onChange(of: personalWebsite) { _ in updateProfileData() }
        .onChange(of: githubUrl) { _ in updateProfileData() }
        .onChange(of: linkedinUrl) { _ in updateProfileData() }
    }
    
    private func updateProfileData() {
        let coreIdentity = CoreIdentity(
            name: name,
            email: email,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            profileImage: nil,
            bio: bio.isEmpty ? nil : bio,
            pronouns: pronouns.isEmpty ? nil : pronouns,
            location: location.isEmpty ? nil : location,
            personalWebsite: personalWebsite.isEmpty ? nil : personalWebsite,
            githubUrl: githubUrl.isEmpty ? nil : githubUrl,
            linkedinUrl: linkedinUrl.isEmpty ? nil : linkedinUrl,
            timeZone: TimeZone.current.identifier,
            availableTimeslot: AvailableTimeslot.createDefault()
        )
        profileData.coreIdentity = coreIdentity
    }
}

// MARK: - Step 2: Professional Background
struct ProfessionalBackgroundStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var currentCompany = ""
    @State private var jobTitle = ""
    @State private var selectedIndustry: IndustryOption? = nil
    @State private var experienceLevel = ExperienceLevel.entry
    @State private var education = ""
    @State private var yearsOfExperience = ""
    @State private var careerStage = CareerStage.earlyCareer
    @State private var skills: [String] = []
    @State private var newSkill = ""
    @State private var certifications: [String] = []
    @State private var newCertification = ""
    @State private var languages: [String] = []
    @State private var newLanguage = ""
    @State private var educations: [Education] = []
    @State private var showAddEducation = false
    @State private var workExperiences: [WorkExperience] = []
    @State private var showAddWorkExperience = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Current Company
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Company")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("e.g., Google", text: $currentCompany)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Job Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Job Title")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("e.g., Software Engineer", text: $jobTitle)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Industry
            VStack(alignment: .leading, spacing: 8) {
                Text("Industry *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Menu {
                    ForEach(IndustryOption.allCases, id: \.self) { industry in
                        Button(industry.displayName) {
                            selectedIndustry = industry
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedIndustry?.displayName ?? "Select your industry")
                            .foregroundColor(selectedIndustry == nil ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Experience Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Experience Level")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Picker("Experience Level", selection: $experienceLevel) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Years of Experience
            VStack(alignment: .leading, spacing: 8) {
                Text("Years of Experience")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                TextField("e.g., 3.5", text: $yearsOfExperience)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .onChange(of: yearsOfExperience) { newValue in
                        // Only allow numbers and decimal point
                        let filtered = newValue.filter { $0.isNumber || $0 == "." }
                        if filtered != newValue {
                            yearsOfExperience = filtered
                        }
                    }
            }
            
            // Education
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Education")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Spacer()
                    
                    Button(action: {
                        showAddEducation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(BrewTheme.secondaryBrown)
                            .clipShape(Circle())
                    }
                }
                
                if educations.isEmpty {
                    Text("No education added yet")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(educations) { education in
                        EducationCard(education: education) {
                            educations.removeAll { $0.id == education.id }
                        }
                    }
                }
            }
            
            // Work Experience
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Work Experience")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Spacer()
                    
                    Button(action: {
                        showAddWorkExperience = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(BrewTheme.secondaryBrown)
                            .clipShape(Circle())
                    }
                }
                
                if workExperiences.isEmpty {
                    Text("No work experience added yet")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(workExperiences) { workExperience in
                        WorkExperienceCard(workExperience: workExperience) {
                            workExperiences.removeAll { $0.id == workExperience.id }
                        }
                    }
                }
            }
            
            // Skills
            VStack(alignment: .leading, spacing: 8) {
                Text("Skills *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                HStack {
                    TextField("Add a skill", text: $newSkill)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    Button("Add") {
                        if !newSkill.isEmpty && !skills.contains(newSkill) {
                            skills.append(newSkill)
                            newSkill = ""
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                }
                
                if !skills.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(skills, id: \.self) { skill in
                            HStack {
                                Text(skill)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                
                                Button(action: {
                                    skills.removeAll { $0 == skill }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(BrewTheme.secondaryBrown)
                            .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .onAppear {
            // Load existing data if available
            if let professionalBackground = profileData.professionalBackground {
                currentCompany = professionalBackground.currentCompany ?? ""
                jobTitle = professionalBackground.jobTitle ?? ""
                selectedIndustry = IndustryOption.allCases.first { $0.rawValue == professionalBackground.industry }
                experienceLevel = professionalBackground.experienceLevel
                education = professionalBackground.education ?? ""
                yearsOfExperience = professionalBackground.yearsOfExperience?.description ?? ""
                careerStage = professionalBackground.careerStage
                skills = professionalBackground.skills
                certifications = professionalBackground.certifications
                languages = professionalBackground.languagesSpoken
                workExperiences = professionalBackground.workExperiences
            }
        }
        .onChange(of: currentCompany) { _ in updateProfileData() }
        .onChange(of: jobTitle) { _ in updateProfileData() }
        .onChange(of: selectedIndustry) { _ in updateProfileData() }
        .onChange(of: experienceLevel) { _ in updateProfileData() }
        .onChange(of: education) { _ in updateProfileData() }
        .onChange(of: yearsOfExperience) { _ in updateProfileData() }
        .onChange(of: careerStage) { _ in updateProfileData() }
        .onChange(of: skills) { _ in updateProfileData() }
        .onChange(of: certifications) { _ in updateProfileData() }
        .onChange(of: languages) { _ in updateProfileData() }
        .onChange(of: educations) { _ in updateProfileData() }
        .onChange(of: workExperiences) { _ in updateProfileData() }
        .sheet(isPresented: $showAddEducation) {
            AddEducationView { newEducation in
                educations.append(newEducation)
            }
        }
        .sheet(isPresented: $showAddWorkExperience) {
            AddWorkExperienceView { newWorkExperience in
                workExperiences.append(newWorkExperience)
            }
        }
    }
    
    private func updateProfileData() {
        let professionalBackground = ProfessionalBackground(
            currentCompany: currentCompany.isEmpty ? nil : currentCompany,
            jobTitle: jobTitle.isEmpty ? nil : jobTitle,
            industry: selectedIndustry?.rawValue,
            experienceLevel: experienceLevel,
            education: education.isEmpty ? nil : education,
            yearsOfExperience: Double(yearsOfExperience),
            careerStage: careerStage,
            skills: skills,
            certifications: certifications,
            languagesSpoken: languages,
            workExperiences: workExperiences
        )
        profileData.professionalBackground = professionalBackground
    }
}

// MARK: - Step 4: Networking Preferences
struct NetworkingPreferencesStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var preferredChatFormat = ChatFormat.virtual
    @State private var preferredChatDuration = ""
    @State private var availableTimeslot = AvailableTimeslot.createDefault()
    
    var body: some View {
        VStack(spacing: 24) {
            // Preferred Chat Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Chat Format")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                HStack(spacing: 8) {
                    ForEach(ChatFormat.allCases, id: \.self) { format in
                        Button(action: {
                            preferredChatFormat = format
                        }) {
                            Text(format.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(preferredChatFormat == format ? .white : BrewTheme.primaryBrown)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(preferredChatFormat == format ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Available Timeslot Matrix
            VStack(alignment: .leading, spacing: 16) {
                Text("Available Timeslots")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Text("Select your available times for networking")
                                .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                TimeslotMatrix(availableTimeslot: $availableTimeslot)
            }
        }
        .onAppear {
            loadExistingData()
        }
        .onChange(of: preferredChatFormat) { _ in updateProfileData() }
        .onChange(of: preferredChatDuration) { _ in updateProfileData() }
        .onChange(of: availableTimeslot) { _ in updateProfileData() }
    }
    
    private func loadExistingData() {
        if let networkingPreferences = profileData.networkingPreferences {
            preferredChatFormat = networkingPreferences.preferredChatFormat
            preferredChatDuration = networkingPreferences.preferredChatDuration ?? ""
            availableTimeslot = networkingPreferences.availableTimeslot
        }
    }
    
    private func updateProfileData() {
        let networkingPreferences = NetworkingPreferences(
            preferredChatFormat: preferredChatFormat,
            availableTimeslot: availableTimeslot,
            preferredChatDuration: preferredChatDuration.isEmpty ? nil : preferredChatDuration
        )
        profileData.networkingPreferences = networkingPreferences
    }
}

// MARK: - Timeslot Matrix
struct TimeslotMatrix: View {
    @Binding var availableTimeslot: AvailableTimeslot
    
    private let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private let timeSlots = ["Morning", "Noon", "Afternoon", "Evening", "Night"]
    
    var body: some View {
        VStack(spacing: 6) {
            // Header row with days
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 60)
                
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Time slot rows
            ForEach(Array(timeSlots.enumerated()), id: \.offset) { timeIndex, timeSlot in
                HStack(spacing: 2) {
                    Text(timeSlot)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                        .frame(width: 60, alignment: .leading)
                    
                    ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, _ in
                        TimeslotCell(
                            isSelected: getTimeslotValue(dayIndex: dayIndex, timeIndex: timeIndex),
                            onTap: {
                                toggleTimeslot(dayIndex: dayIndex, timeIndex: timeIndex)
                            }
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
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
        case 0: return availableTimeslot.sunday
        case 1: return availableTimeslot.monday
        case 2: return availableTimeslot.tuesday
        case 3: return availableTimeslot.wednesday
        case 4: return availableTimeslot.thursday
        case 5: return availableTimeslot.friday
        case 6: return availableTimeslot.saturday
        default: return DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false)
        }
    }
    
    private func toggleTimeslot(dayIndex: Int, timeIndex: Int) {
        let currentValue = getTimeslotValue(dayIndex: dayIndex, timeIndex: timeIndex)
        let newValue = !currentValue
        
        let newTimeslot = createUpdatedTimeslot(dayIndex: dayIndex, timeIndex: timeIndex, newValue: newValue)
        availableTimeslot = newTimeslot
    }
    
    private func createUpdatedTimeslot(dayIndex: Int, timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        switch dayIndex {
        case 0: return updateSundayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 1: return updateMondayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 2: return updateTuesdayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 3: return updateWednesdayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 4: return updateThursdayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 5: return updateFridayTimeslot(timeIndex: timeIndex, newValue: newValue)
        case 6: return updateSaturdayTimeslot(timeIndex: timeIndex, newValue: newValue)
        default: return availableTimeslot
        }
    }
    
    private func updateSundayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newSunday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.sunday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.sunday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.sunday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.sunday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.sunday.night
        )
        return AvailableTimeslot(
            sunday: newSunday,
            monday: availableTimeslot.monday,
            tuesday: availableTimeslot.tuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: availableTimeslot.thursday,
            friday: availableTimeslot.friday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateMondayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newMonday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.monday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.monday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.monday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.monday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.monday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: newMonday,
            tuesday: availableTimeslot.tuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: availableTimeslot.thursday,
            friday: availableTimeslot.friday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateTuesdayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newTuesday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.tuesday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.tuesday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.tuesday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.tuesday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.tuesday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: availableTimeslot.monday,
            tuesday: newTuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: availableTimeslot.thursday,
            friday: availableTimeslot.friday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateWednesdayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newWednesday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.wednesday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.wednesday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.wednesday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.wednesday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.wednesday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: availableTimeslot.monday,
            tuesday: availableTimeslot.tuesday,
            wednesday: newWednesday,
            thursday: availableTimeslot.thursday,
            friday: availableTimeslot.friday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateThursdayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newThursday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.thursday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.thursday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.thursday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.thursday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.thursday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: availableTimeslot.monday,
            tuesday: availableTimeslot.tuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: newThursday,
            friday: availableTimeslot.friday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateFridayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newFriday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.friday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.friday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.friday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.friday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.friday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: availableTimeslot.monday,
            tuesday: availableTimeslot.tuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: availableTimeslot.thursday,
            friday: newFriday,
            saturday: availableTimeslot.saturday
        )
    }
    
    private func updateSaturdayTimeslot(timeIndex: Int, newValue: Bool) -> AvailableTimeslot {
        let newSaturday = DayTimeslots(
            morning: timeIndex == 0 ? newValue : availableTimeslot.saturday.morning,
            noon: timeIndex == 1 ? newValue : availableTimeslot.saturday.noon,
            afternoon: timeIndex == 2 ? newValue : availableTimeslot.saturday.afternoon,
            evening: timeIndex == 3 ? newValue : availableTimeslot.saturday.evening,
            night: timeIndex == 4 ? newValue : availableTimeslot.saturday.night
        )
        return AvailableTimeslot(
            sunday: availableTimeslot.sunday,
            monday: availableTimeslot.monday,
            tuesday: availableTimeslot.tuesday,
            wednesday: availableTimeslot.wednesday,
            thursday: availableTimeslot.thursday,
            friday: availableTimeslot.friday,
            saturday: newSaturday
        )
    }
}

// MARK: - Timeslot Cell
struct TimeslotCell: View {
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Rectangle()
                .fill(isSelected ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                .frame(width: 30, height: 30)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 3: Networking Intention
struct NetworkingIntentionStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var selectedIntention: NetworkingIntentionType = .learnGrow
    @State private var selectedSubIntentions: Set<SubIntentionType> = []
    @State private var careerDirectionData: CareerDirectionData? = nil
    @State private var skillDevelopmentData: SkillDevelopmentData? = nil
    @State private var industryTransitionData: IndustryTransitionData? = nil
    
    // Career Direction Data
    @State private var marketingFunctions: [String: [String]] = [:]
    @State private var productTechFunctions: [String: [String]] = [:]
    @State private var dataAnalyticsFunctions: [String: [String]] = [:]
    @State private var financeConsultingFunctions: [String: [String]] = [:]
    @State private var operationsHRFunctions: [String: [String]] = [:]
    @State private var creativeMediaFunctions: [String: [String]] = [:]
    
    // Skill Development Data
    @State private var skills: [SkillSelection] = []
    @State private var newSkill = ""
    
    // Industry Transition Data
    @State private var industries: [IndustrySelection] = []
    
    var body: some View {
        VStack(spacing: 24) {
            // Main Intention Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("What's your main networking intention? *")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(NetworkingIntentionType.allCases, id: \.self) { intention in
                        Button(action: {
                            selectedIntention = intention
                            selectedSubIntentions.removeAll()
                        }) {
                            VStack(spacing: 8) {
                                Text(getIntentionDescription(intention))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedIntention == intention ? .white : BrewTheme.primaryBrown)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(selectedIntention == intention ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Sub-intention Selection
            if !selectedIntention.subIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select your sub-intentions:")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                        ForEach(selectedIntention.subIntentions, id: \.self) { subIntention in
                            Button(action: {
                                if selectedSubIntentions.contains(subIntention) {
                                    selectedSubIntentions.remove(subIntention)
                                } else {
                                    selectedSubIntentions.insert(subIntention)
                                }
                            }) {
                                HStack {
                                    Text(subIntention.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(selectedSubIntentions.contains(subIntention) ? .white : BrewTheme.primaryBrown)
                                    
                                    Spacer()
                                    
                                    if selectedSubIntentions.contains(subIntention) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedSubIntentions.contains(subIntention) ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            
            // Detailed Forms based on selected sub-intentions
            if !selectedSubIntentions.isEmpty {
                VStack(spacing: 16) {
                    ForEach(Array(selectedSubIntentions), id: \.self) { subIntention in
                        switch subIntention {
                        case .careerDirection:
                            CareerDirectionForm(functions: $marketingFunctions, productTech: $productTechFunctions, dataAnalytics: $dataAnalyticsFunctions, financeConsulting: $financeConsultingFunctions, operationsHR: $operationsHRFunctions, creativeMedia: $creativeMediaFunctions)
                        case .skillDevelopment:
                            SkillDevelopmentForm(skills: $skills, newSkill: $newSkill)
                        case .industryTransition:
                            IndustryTransitionForm(industries: $industries)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
        .onChange(of: selectedIntention) { _ in updateProfileData() }
        .onChange(of: selectedSubIntentions) { _ in updateProfileData() }
        .onChange(of: careerDirectionData) { _ in updateProfileData() }
        .onChange(of: skillDevelopmentData) { _ in updateProfileData() }
        .onChange(of: industryTransitionData) { _ in updateProfileData() }
    }
    
    private func getIntentionDescription(_ intention: NetworkingIntentionType) -> String {
        switch intention {
        case .learnGrow:
            return "🎓 Learn & Grow"
        case .connectShare:
            return "🤝 Connect & Share"
        case .buildCollaborate:
            return "🚀 Build & Collaborate"
        case .unwindChat:
            return "⛱️ Unwind & Chat"
        }
    }
    
    private func loadExistingData() {
        if let networkingIntention = profileData.networkingIntention {
            selectedIntention = networkingIntention.selectedIntention
            selectedSubIntentions = Set(networkingIntention.selectedSubIntentions)
            careerDirectionData = networkingIntention.careerDirection
            skillDevelopmentData = networkingIntention.skillDevelopment
            industryTransitionData = networkingIntention.industryTransition
        }
    }
    
    private func updateProfileData() {
        let networkingIntention = NetworkingIntention(
            selectedIntention: selectedIntention,
            selectedSubIntentions: Array(selectedSubIntentions),
            careerDirection: careerDirectionData,
            skillDevelopment: skillDevelopmentData,
            industryTransition: industryTransitionData
        )
        profileData.networkingIntention = networkingIntention
    }
}

// MARK: - Career Direction Form
struct CareerDirectionForm: View {
    @Binding var functions: [String: [String]]
    @Binding var productTech: [String: [String]]
    @Binding var dataAnalytics: [String: [String]]
    @Binding var financeConsulting: [String: [String]]
    @Binding var operationsHR: [String: [String]]
    @Binding var creativeMedia: [String: [String]]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select the functions or roles where you'd like to receive or offer career direction.")
                .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
            
            // Marketing & Branding
            FunctionSection(
                title: "Marketing & Branding",
                functions: ["Brand Marketing", "Digital Marketing", "Social Media Operations", "Content Strategy"],
                selectedFunctions: $functions
            )
            
            // Product & Tech
            FunctionSection(
                title: "Product & Tech",
                functions: ["Product Management", "Product Operations", "Front-end Development", "UX / UI Design", "Product Data Analytics", "Backend Development"],
                selectedFunctions: $productTech
            )
            
            // Data & Analytics
            FunctionSection(
                title: "Data & Analytics",
                functions: ["Data Analyst", "Growth Analyst", "Marketing Data", "Business Intelligence", "Machine Learning Ops", "Research Analyst"],
                selectedFunctions: $dataAnalytics
            )
            
            // Finance & Consulting
            FunctionSection(
                title: "Finance & Consulting",
                functions: ["Investment Banking", "Equity Research", "VC / PE Analyst", "Strategy Consulting", "Corporate Finance", "Financial Planning"],
                selectedFunctions: $financeConsulting
            )
            
            // Operations & HR
            FunctionSection(
                title: "Operations & HR",
                functions: ["Project Management", "Business Operations", "Supply Chain", "HR / Talent Acquisition", "Training & L&D", "Organizational Development"],
                selectedFunctions: $operationsHR
            )
            
            // Creative & Media
            FunctionSection(
                title: "Creative & Media",
                functions: ["Copywriting", "PR & Communications", "Art Direction", "Video Editing / Motion Design", "Creative Strategy", "Advertising Production"],
                selectedFunctions: $creativeMedia
            )
        }
    }
}

// MARK: - Function Section
struct FunctionSection: View {
    let title: String
    let functions: [String]
    @Binding var selectedFunctions: [String: [String]]
    
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
            Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BrewTheme.primaryBrown)
                
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(functions, id: \.self) { function in
                    FunctionRow(
                        functionName: function,
                        learnIn: Binding(
                            get: { selectedFunctions[function]?.contains("learn") ?? false },
                            set: { isSelected in
                                if isSelected {
                                    if selectedFunctions[function] == nil {
                                        selectedFunctions[function] = ["learn"]
                                    } else if !selectedFunctions[function]!.contains("learn") {
                                        selectedFunctions[function]?.append("learn")
                                    }
                                } else {
                                    selectedFunctions[function]?.removeAll { $0 == "learn" }
                                    if selectedFunctions[function]?.isEmpty == true {
                                        selectedFunctions[function] = nil
                                    }
                                }
                            }
                        ),
                        guideIn: Binding(
                            get: { selectedFunctions[function]?.contains("guide") ?? false },
                            set: { isSelected in
                                if isSelected {
                                    if selectedFunctions[function] == nil {
                                        selectedFunctions[function] = ["guide"]
                                    } else if !selectedFunctions[function]!.contains("guide") {
                                        selectedFunctions[function]?.append("guide")
                                    }
                                } else {
                                    selectedFunctions[function]?.removeAll { $0 == "guide" }
                                    if selectedFunctions[function]?.isEmpty == true {
                                        selectedFunctions[function] = nil
                                    }
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Function Row
struct FunctionRow: View {
    let functionName: String
    @Binding var learnIn: Bool
    @Binding var guideIn: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(functionName)
                .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BrewTheme.primaryBrown)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Learn in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        learnIn.toggle()
                    }) {
                        Image(systemName: learnIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(learnIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Guide in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        guideIn.toggle()
                    }) {
                        Image(systemName: guideIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(guideIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Skill Development Form
struct SkillDevelopmentForm: View {
    @Binding var skills: [SkillSelection]
    @Binding var newSkill: String
    
    private let commonSkills = ["Product Strategy", "Presentation Skills", "Data Analytics", "AIGC", "Project Management", "Leadership", "Communication", "Problem Solving"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("List the skills you'd like to learn or share.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            // Add new skill
            HStack {
                TextField("Add a skill", text: $newSkill)
                    .textFieldStyle(CustomTextFieldStyle())
                
                Button("Add") {
                    if !newSkill.isEmpty && !skills.contains(where: { $0.skillName == newSkill }) {
                        skills.append(SkillSelection(skillName: newSkill, learnIn: false, guideIn: false))
                        newSkill = ""
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(BrewTheme.primaryBrown)
            }
            
            // Common skills
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(commonSkills, id: \.self) { skill in
                    if !skills.contains(where: { $0.skillName == skill }) {
                        Button(action: {
                            skills.append(SkillSelection(skillName: skill, learnIn: false, guideIn: false))
                        }) {
                            Text("+ \(skill)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(BrewTheme.secondaryBrown)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(BrewTheme.secondaryBrown.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                }
            }
            
            // Selected skills
            if !skills.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                    ForEach(skills.indices, id: \.self) { index in
                        SkillRow(
                            skill: $skills[index],
                            onDelete: {
                                skills.remove(at: index)
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Skill Row
struct SkillRow: View {
    @Binding var skill: SkillSelection
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(skill.skillName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(BrewTheme.primaryBrown)
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Learn in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        skill.learnIn.toggle()
                    }) {
                        Image(systemName: skill.learnIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(skill.learnIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Guide in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        skill.guideIn.toggle()
                    }) {
                        Image(systemName: skill.guideIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(skill.guideIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Industry Transition Form
struct IndustryTransitionForm: View {
    @Binding var industries: [IndustrySelection]
    
    private let industryOptions = [
        "Technology (Software, Data, AI, IT)",
        "Finance (Banking, Investment, FinTech)",
        "Marketing & Media (Advertising, PR, Content)",
        "Consulting & Strategy",
        "Education & Research",
        "Healthcare & Biotech",
        "Manufacturing & Engineering",
        "Internet & E-Commerce",
        "Government & Public Sector",
        "Arts, Design & Entertainment"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select the industries you'd like to transition into/ learn about or offer transition advice/ experience for.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 8) {
                ForEach(industryOptions, id: \.self) { industry in
                    IndustryRow(
                        industryName: industry,
                        learnIn: Binding(
                            get: { industries.first(where: { $0.industryName == industry })?.learnIn ?? false },
                            set: { isSelected in
                                if let index = industries.firstIndex(where: { $0.industryName == industry }) {
                                    industries[index].learnIn = isSelected
                                } else {
                                    industries.append(IndustrySelection(industryName: industry, learnIn: isSelected, guideIn: false))
                                }
                            }
                        ),
                        guideIn: Binding(
                            get: { industries.first(where: { $0.industryName == industry })?.guideIn ?? false },
                            set: { isSelected in
                                if let index = industries.firstIndex(where: { $0.industryName == industry }) {
                                    industries[index].guideIn = isSelected
                                } else {
                                    industries.append(IndustrySelection(industryName: industry, learnIn: false, guideIn: isSelected))
                                }
                            }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Industry Row
struct IndustryRow: View {
    let industryName: String
    @Binding var learnIn: Bool
    @Binding var guideIn: Bool
    
    var body: some View {
        HStack {
            Text(industryName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(BrewTheme.primaryBrown)
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Learn in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        learnIn.toggle()
                    }) {
                        Image(systemName: learnIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(learnIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Guide in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        guideIn.toggle()
                    }) {
                        Image(systemName: guideIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(guideIn ? BrewTheme.secondaryBrown : .gray)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Step 5: Personality & Social
struct PersonalitySocialStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var preferredMeetingVibe = MeetingVibe.casual
    @State private var communicationStyle = CommunicationStyle.collaborative
    @State private var selfIntroduction = ""
    @StateObject private var selectionHelper = SelectionHelper()
    
    var body: some View {
        VStack(spacing: 20) {
            // Self Introduction
            VStack(alignment: .leading, spacing: 8) {
                Text("Self Introduction")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Text("Tell us about yourself professionally (e.g., Senior Software Engineer @ Meta, familiar with Redis, K8s, etc.)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                TextEditor(text: $selfIntroduction)
                    .frame(minHeight: 100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Values Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Values that describe you *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Text("Select up to 6 values (tap to add/remove)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                // All available values
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(ValuesOptions.allValues, id: \.self) { value in
                        Button(action: {
                            if selectionHelper.selectedValues.contains(value) {
                                selectionHelper.removeValue(value)
                            } else {
                                selectionHelper.addValue(value)
                            }
                        }) {
                            HStack {
                                Text(value)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectionHelper.selectedValues.contains(value) ? .white : BrewTheme.primaryBrown)
                                
                                if selectionHelper.selectedValues.contains(value) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectionHelper.selectedValues.contains(value) ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .disabled(selectionHelper.selectedValues.count >= 6 && !selectionHelper.selectedValues.contains(value))
                        .opacity(selectionHelper.selectedValues.count >= 6 && !selectionHelper.selectedValues.contains(value) ? 0.5 : 1.0)
                    }
                }
                
                if !selectionHelper.selectedValues.isEmpty {
                    Text("Selected: \(selectionHelper.selectedValues.count)/6")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Hobbies
            VStack(alignment: .leading, spacing: 8) {
                Text("Hobbies & Interests")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Text("Select up to 6 hobbies (tap to add/remove)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                // All available hobbies
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(HobbiesOptions.allHobbies, id: \.self) { hobby in
                        Button(action: {
                            if selectionHelper.selectedHobbies.contains(hobby) {
                                selectionHelper.removeHobby(hobby)
                            } else {
                                selectionHelper.addHobby(hobby)
                            }
                        }) {
                            HStack {
                                Text(hobby)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectionHelper.selectedHobbies.contains(hobby) ? .white : BrewTheme.primaryBrown)
                                
                                if selectionHelper.selectedHobbies.contains(hobby) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectionHelper.selectedHobbies.contains(hobby) ? BrewTheme.secondaryBrown : Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .disabled(selectionHelper.selectedHobbies.count >= 6 && !selectionHelper.selectedHobbies.contains(hobby))
                        .opacity(selectionHelper.selectedHobbies.count >= 6 && !selectionHelper.selectedHobbies.contains(hobby) ? 0.5 : 1.0)
                    }
                }
                
                if !selectionHelper.selectedHobbies.isEmpty {
                    Text("Selected: \(selectionHelper.selectedHobbies.count)/6")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Preferred Meeting Vibe
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Meeting Vibe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Picker("Meeting Vibe", selection: $preferredMeetingVibe) {
                    ForEach(MeetingVibe.allCases, id: \.self) { vibe in
                        Text(vibe.displayName).tag(vibe)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onTapGesture {
                    // Prevent any unwanted scroll behavior when picker is tapped
                }
            }
            
            // Communication Style
            VStack(alignment: .leading, spacing: 8) {
                Text("Communication Style")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Picker("Communication Style", selection: $communicationStyle) {
                    ForEach(CommunicationStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .onTapGesture {
                    // Prevent any unwanted scroll behavior when picker is tapped
                }
            }
        }
        .onAppear {
            // Load existing data if available
            if let personalitySocial = profileData.personalitySocial {
                selectionHelper.selectedValues = Set(personalitySocial.valuesTags)
                selectionHelper.selectedHobbies = Set(personalitySocial.hobbies)
                preferredMeetingVibe = personalitySocial.preferredMeetingVibe
                communicationStyle = personalitySocial.communicationStyle
                selfIntroduction = personalitySocial.selfIntroduction ?? ""
            }
        }
        .onChange(of: selectionHelper.selectedValues) { _ in updateProfileData() }
        .onChange(of: selectionHelper.selectedHobbies) { _ in updateProfileData() }
        .onChange(of: preferredMeetingVibe) { _ in updateProfileData() }
        .onChange(of: communicationStyle) { _ in updateProfileData() }
        .onChange(of: selfIntroduction) { _ in updateProfileData() }
    }
    
    private func updateProfileData() {
        let personalitySocial = PersonalitySocial(
            icebreakerPrompts: [],
            valuesTags: Array(selectionHelper.selectedValues),
            hobbies: Array(selectionHelper.selectedHobbies),
            preferredMeetingVibe: preferredMeetingVibe,
            communicationStyle: communicationStyle,
            selfIntroduction: selfIntroduction.isEmpty ? nil : selfIntroduction
        )
        profileData.personalitySocial = personalitySocial
    }
}

// MARK: - Step 6: Privacy & Trust
struct PrivacyTrustStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var companyVisibility = VisibilityLevel.public_
    @State private var emailVisibility = VisibilityLevel.private_
    @State private var phoneNumberVisibility = VisibilityLevel.private_
    @State private var locationVisibility = VisibilityLevel.public_
    @State private var skillsVisibility = VisibilityLevel.public_
    @State private var interestsVisibility = VisibilityLevel.public_
    @State private var dataSharingConsent = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Visibility Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                VStack(spacing: 12) {
                    PrivacyToggleRow(
                        title: "Company",
                        visibility: $companyVisibility
                    )
                    
                    PrivacyToggleRow(
                        title: "Email",
                        visibility: $emailVisibility
                    )
                    
                    PrivacyToggleRow(
                        title: "Phone Number",
                        visibility: $phoneNumberVisibility
                    )
                    
                    PrivacyToggleRow(
                        title: "Location",
                        visibility: $locationVisibility
                    )
                    
                    PrivacyToggleRow(
                        title: "Skills",
                        visibility: $skillsVisibility
                    )
                    
                    PrivacyToggleRow(
                        title: "Interests",
                        visibility: $interestsVisibility
                    )
                }
            }
            
            // Data Sharing Consent
            VStack(alignment: .leading, spacing: 12) {
                Text("Data Sharing")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Toggle("Allow data sharing for better recommendations", isOn: $dataSharingConsent)
                    .font(.system(size: 16))
                    .toggleStyle(SwitchToggleStyle(tint: BrewTheme.secondaryBrown))
            }
        }
        .onAppear {
            // Load existing data if available
            if let privacyTrust = profileData.privacyTrust {
                companyVisibility = privacyTrust.visibilitySettings.company
                emailVisibility = privacyTrust.visibilitySettings.email
                phoneNumberVisibility = privacyTrust.visibilitySettings.phoneNumber
                locationVisibility = privacyTrust.visibilitySettings.location
                skillsVisibility = privacyTrust.visibilitySettings.skills
                interestsVisibility = privacyTrust.visibilitySettings.interests
                dataSharingConsent = privacyTrust.dataSharingConsent
            }
        }
        .onChange(of: companyVisibility) { _ in updateProfileData() }
        .onChange(of: emailVisibility) { _ in updateProfileData() }
        .onChange(of: phoneNumberVisibility) { _ in updateProfileData() }
        .onChange(of: locationVisibility) { _ in updateProfileData() }
        .onChange(of: skillsVisibility) { _ in updateProfileData() }
        .onChange(of: interestsVisibility) { _ in updateProfileData() }
        .onChange(of: dataSharingConsent) { _ in updateProfileData() }
    }
    
    private func updateProfileData() {
        let visibilitySettings = VisibilitySettings(
            company: companyVisibility,
            email: emailVisibility,
            phoneNumber: phoneNumberVisibility,
            location: locationVisibility,
            skills: skillsVisibility,
            interests: interestsVisibility
        )
        
        let privacyTrust = PrivacyTrust(
            visibilitySettings: visibilitySettings,
            verifiedStatus: .unverified,
            dataSharingConsent: dataSharingConsent,
            reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
        )
        profileData.privacyTrust = privacyTrust
    }
}

// MARK: - Privacy Toggle Row
struct PrivacyToggleRow: View {
    let title: String
    @Binding var visibility: VisibilityLevel
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(BrewTheme.primaryBrown)
            
            Spacer()
            
            Picker("Visibility", selection: $visibility) {
                ForEach(VisibilityLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)
            .onTapGesture {
                // Prevent any unwanted scroll behavior when picker is tapped
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Profile Completion View
struct ProfileCompletionView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showAnimation = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.2))
                    .scaleEffect(showAnimation ? 1.0 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showAnimation)
                
                VStack(spacing: 12) {
                    Text("Profile Setup Complete!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(BrewTheme.primaryBrown)
                        .multilineTextAlignment(.center)
                    
                    Text("Start your networking journey!")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Continue button
            Button("Start Networking") {
                // The auth state will automatically update and show MainView
                // No need to manually navigate
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        BrewTheme.secondaryBrown,
                        BrewTheme.primaryBrown
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Color.brown.opacity(0.3), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showAnimation = true
                }
            }
        }
    }
}

// MARK: - Education Card
struct EducationCard: View {
    let education: Education
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(education.schoolName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                Text(education.degree.displayName)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                HStack {
                    Text(education.startYear, format: .number.grouping(.never))
                    if let endYear = education.endYear {
                        Text("- \(endYear, format: .number.grouping(.never))")
                    } else {
                        Text("- Present")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Work Experience Card
struct WorkExperienceCard: View {
    let workExperience: WorkExperience
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workExperience.companyName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BrewTheme.primaryBrown)
                
                if let position = workExperience.position {
                    Text(position)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(workExperience.startYear, format: .number.grouping(.never))
                    if let endYear = workExperience.endYear {
                        Text("- \(endYear, format: .number.grouping(.never))")
                    } else {
                        Text("- Present")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Add Work Experience View
struct AddWorkExperienceView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (WorkExperience) -> Void
    
    @State private var companyName = ""
    @State private var startYear = YearOptions.currentYear
    @State private var endYear: Int? = YearOptions.currentYear
    @State private var position = ""
    @State private var isPresent = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Company Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Company Name *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    TextField("Enter company name", text: $companyName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Position
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    TextField("e.g., Software Engineer, Marketing Manager", text: $position)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Start Year
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Year *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Picker("Start Year", selection: $startYear) {
                        ForEach(YearOptions.workExperienceYears, id: \.self) { year in
                            Text(year, format: .number.grouping(.never)).tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // End Year or Present
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("End Year")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BrewTheme.primaryBrown)
                        
                        Spacer()
                        
                        Toggle("Currently working", isOn: $isPresent)
                            .font(.system(size: 14))
                    }
                    
                    if !isPresent {
                        Picker("End Year", selection: Binding(
                            get: { endYear ?? YearOptions.currentYear },
                            set: { endYear = $0 }
                        )) {
                            ForEach(YearOptions.workExperienceYears, id: \.self) { year in
                                Text(year, format: .number.grouping(.never)).tag(year)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Work Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let workExperience = WorkExperience(
                            companyName: companyName,
                            startYear: startYear,
                            endYear: isPresent ? nil : endYear,
                            position: position.isEmpty ? nil : position
                        )
                        onSave(workExperience)
                        dismiss()
                    }
                    .disabled(companyName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Education View
struct AddEducationView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Education) -> Void
    
    @State private var schoolName = ""
    @State private var startYear = YearOptions.currentYear
    @State private var endYear: Int? = YearOptions.currentYear
    @State private var degree = DegreeType.bachelor
    @State private var fieldOfStudy = ""
    @State private var isPresent = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // School Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("School/University/College Name *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    TextField("Enter school name", text: $schoolName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Start Year
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Year *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Picker("Start Year", selection: $startYear) {
                        ForEach(YearOptions.years, id: \.self) { year in
                            Text(year, format: .number.grouping(.never)).tag(year)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // End Year or Present
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("End Year")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BrewTheme.primaryBrown)
                        
                        Spacer()
                        
                        Toggle("Currently studying", isOn: $isPresent)
                            .font(.system(size: 14))
                    }
                    
                    if !isPresent {
                        Picker("End Year", selection: Binding(
                            get: { endYear ?? YearOptions.currentYear },
                            set: { endYear = $0 }
                        )) {
                            ForEach(YearOptions.years, id: \.self) { year in
                                Text(year, format: .number.grouping(.never)).tag(year)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Degree
                VStack(alignment: .leading, spacing: 8) {
                    Text("Degree *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    Picker("Degree", selection: $degree) {
                        ForEach(DegreeType.allCases, id: \.self) { degree in
                            Text(degree.displayName).tag(degree)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Field of Study
                VStack(alignment: .leading, spacing: 8) {
                    Text("Field of Study")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(BrewTheme.primaryBrown)
                    
                    TextField("e.g., Computer Science, Business Administration", text: $fieldOfStudy)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let education = Education(
                            schoolName: schoolName,
                            startYear: startYear,
                            endYear: isPresent ? nil : endYear,
                            degree: degree,
                            fieldOfStudy: fieldOfStudy.isEmpty ? nil : fieldOfStudy
                        )
                        onSave(education)
                        dismiss()
                    }
                    .disabled(schoolName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}
