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
    
    private let totalSteps = 5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if showCompletion {
                    ProfileCompletionView()
                } else {
                    VStack(spacing: 0) {
                        // Header with progress
                        VStack(spacing: 16) {
                            // Progress bar
                            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                                .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                                .padding(.horizontal, 32)
                            
                            // Step indicator
                            HStack {
                                Text("Step \(currentStep) of \(totalSteps)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Spacer()
                                
                                Text("\(Int((Double(currentStep) / Double(totalSteps)) * 100))% Complete")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 32)
                            
                            // Step title
                            Text(stepTitle)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            // Step description
                            Text(stepDescription)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
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
                                        NetworkingIntentStep(profileData: $profileData)
                                            .id("step-3")
                                    case 4:
                                        PersonalitySocialStep(profileData: $profileData)
                                            .id("step-4")
                                    case 5:
                                        PrivacyTrustStep(profileData: $profileData)
                                            .id("step-5")
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
                                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                    }
                                    .background(Color.white)
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color(red: 0.4, green: 0.2, blue: 0.1), lineWidth: 2)
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
                                        // Scroll to top when moving to next step
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            // This will be handled by ScrollViewReader
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
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.6, green: 0.4, blue: 0.2),
                                            Color(red: 0.4, green: 0.2, blue: 0.1)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(25)
                                .disabled(isNavigating)
                            }
                            .padding(.horizontal, 32)
                        }
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
    }
    
    // MARK: - Step Information
    private var stepTitle: String {
        switch currentStep {
        case 1: return "Core Identity"
        case 2: return "Professional Background"
        case 3: return "Networking & Intent"
        case 4: return "Personality & Social"
        case 5: return "Privacy & Trust"
        default: return ""
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 1: return "Tell us about yourself - the basics that help others connect with you"
        case 2: return "Share your professional experience and expertise"
        case 3: return "What brings you to BrewNet? Let's align your networking goals"
        case 4: return "Show your personality and what makes you unique"
        case 5: return "Control your privacy and how others can discover you"
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
                
                // Create the complete profile
                let profile = BrewNetProfile.createDefault(userId: currentUser.id)
                
                // Update with collected data
                let updatedProfile = updateProfileWithCollectedData(profile)
                
                // Convert to Supabase format
                let supabaseProfile = SupabaseProfile(
                    id: updatedProfile.id,
                    userId: updatedProfile.userId,
                    coreIdentity: updatedProfile.coreIdentity,
                    professionalBackground: updatedProfile.professionalBackground,
                    networkingIntent: updatedProfile.networkingIntent,
                    personalitySocial: updatedProfile.personalitySocial,
                    privacyTrust: updatedProfile.privacyTrust,
                    createdAt: updatedProfile.createdAt,
                    updatedAt: updatedProfile.updatedAt
                )
                
                // Save to Supabase
                let _ = try await supabaseService.createProfile(profile: supabaseProfile)
                
                // Update user profile setup status
                try await supabaseService.updateUserProfileSetupCompleted(userId: currentUser.id, completed: true)
                
                await MainActor.run {
                    // Update local auth manager
                    authManager.updateProfileSetupCompleted(true)
                    isLoading = false
                    showCompletion = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("profiles") && errorMessage.contains("table") {
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
        let networkingIntent = profileData.networkingIntent ?? profile.networkingIntent
        let personalitySocial = profileData.personalitySocial ?? profile.personalitySocial
        let privacyTrust = profileData.privacyTrust ?? profile.privacyTrust
        
        updatedProfile = BrewNetProfile(
            id: profile.id,
            userId: profile.userId,
            createdAt: profile.createdAt,
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            coreIdentity: coreIdentity,
            professionalBackground: professionalBackground,
            networkingIntent: networkingIntent,
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
                Text("Full Name *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("Enter your full name", text: $name)
                    .textFieldStyle(CustomTextFieldStyle())
                    .autocapitalization(.words)
            }
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            // Phone Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("Enter your phone number", text: $phoneNumber)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.phonePad)
            }
            
            // Bio
            VStack(alignment: .leading, spacing: 8) {
                Text("Bio (LinkedIn-style headline)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., Product designer helping teams bridge creativity & data", text: $bio)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Pronouns
            VStack(alignment: .leading, spacing: 8) {
                Text("Pronouns")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., she/her, they/them", text: $pronouns)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., San Francisco, CA", text: $location)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Personal Website
            VStack(alignment: .leading, spacing: 8) {
                Text("Personal Website")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("https://yourwebsite.com", text: $personalWebsite)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            // GitHub URL
            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("https://github.com/username", text: $githubUrl)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            // LinkedIn URL
            VStack(alignment: .leading, spacing: 8) {
                Text("LinkedIn Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., Google", text: $currentCompany)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Job Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Job Title")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., Software Engineer", text: $jobTitle)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Industry
            VStack(alignment: .leading, spacing: 8) {
                Text("Industry *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Spacer()
                    
                    Button(action: {
                        showAddEducation = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Spacer()
                    
                    Button(action: {
                        showAddWorkExperience = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
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
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
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

// MARK: - Step 3: Networking Intent
struct NetworkingIntentStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var selectedIntents: Set<NetworkingIntentType> = []
    @State private var conversationTopics: [String] = []
    @State private var selectedCollaborationInterests: Set<CollaborationInterest> = []
    @State private var coffeeChatGoal = ""
    @State private var preferredChatFormat = ChatFormat.virtual
    @State private var preferredChatDuration = ""
    @StateObject private var selectionHelper = SelectionHelper()
    
    var body: some View {
        VStack(spacing: 20) {
            // Networking Intent
            VStack(alignment: .leading, spacing: 12) {
                Text("What brings you to BrewNet? *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(NetworkingIntentType.allCases, id: \.self) { intent in
                        Button(action: {
                            if selectedIntents.contains(intent) {
                                selectedIntents.remove(intent)
                            } else {
                                selectedIntents.insert(intent)
                            }
                        }) {
                            Text(intent.displayName)
                                .font(.system(size: 14))
                                .foregroundColor(selectedIntents.contains(intent) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedIntents.contains(intent) ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(16)
                        }
                    }
                }
            }
            
            // Conversation Topics
            VStack(alignment: .leading, spacing: 8) {
                Text("Topics you enjoy discussing")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("Select up to 6 topics (tap to add/remove)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                // All available topics
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(getAllTopics(), id: \.self) { topic in
                        Button(action: {
                            if selectionHelper.selectedTopics.contains(topic) {
                                selectionHelper.removeTopic(topic)
                            } else {
                                selectionHelper.addTopic(topic)
                            }
                        }) {
                            HStack {
                                Text(topic)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectionHelper.selectedTopics.contains(topic) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                if selectionHelper.selectedTopics.contains(topic) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectionHelper.selectedTopics.contains(topic) ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .disabled(selectionHelper.selectedTopics.count >= 6 && !selectionHelper.selectedTopics.contains(topic))
                        .opacity(selectionHelper.selectedTopics.count >= 6 && !selectionHelper.selectedTopics.contains(topic) ? 0.5 : 1.0)
                    }
                }
                
                if !selectionHelper.selectedTopics.isEmpty {
                    Text("Selected: \(selectionHelper.selectedTopics.count)/6")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Coffee Chat Goal
            VStack(alignment: .leading, spacing: 8) {
                Text("What's the question on the top of your head?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., How design teams can use AI responsibly", text: $coffeeChatGoal)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Preferred Chat Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Chat Format")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Picker("Chat Format", selection: $preferredChatFormat) {
                    ForEach(ChatFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .onAppear {
            // Load existing data if available
            if let networkingIntent = profileData.networkingIntent {
                selectedIntents = Set(networkingIntent.networkingIntent)
                conversationTopics = networkingIntent.conversationTopics
                selectedCollaborationInterests = Set(networkingIntent.collaborationInterest)
                coffeeChatGoal = networkingIntent.coffeeChatGoal ?? ""
                preferredChatFormat = networkingIntent.preferredChatFormat
                preferredChatDuration = networkingIntent.preferredChatDuration ?? ""
            }
        }
        .onChange(of: selectedIntents) { _ in updateProfileData() }
        .onChange(of: conversationTopics) { _ in updateProfileData() }
        .onChange(of: selectedCollaborationInterests) { _ in updateProfileData() }
        .onChange(of: coffeeChatGoal) { _ in updateProfileData() }
        .onChange(of: preferredChatFormat) { _ in updateProfileData() }
        .onChange(of: preferredChatDuration) { _ in updateProfileData() }
        .onChange(of: selectionHelper.selectedTopics) { _ in updateProfileData() }
    }
    
    private func getAllTopics() -> [String] {
        var allTopics: [String] = []
        for industry in IndustryOption.allCases {
            allTopics.append(contentsOf: DiscussionTopics.topicsForIndustry(industry))
        }
        return Array(Set(allTopics)).sorted()
    }
    
    private func updateProfileData() {
        let networkingIntent = NetworkingIntent(
            networkingIntent: Array(selectedIntents),
            conversationTopics: Array(selectionHelper.selectedTopics),
            collaborationInterest: Array(selectedCollaborationInterests),
            coffeeChatGoal: coffeeChatGoal.isEmpty ? nil : coffeeChatGoal,
            preferredChatFormat: preferredChatFormat,
            availableTimeslot: AvailableTimeslot.createDefault(),
            preferredChatDuration: preferredChatDuration.isEmpty ? nil : preferredChatDuration,
            introPromptAnswers: []
        )
        profileData.networkingIntent = networkingIntent
    }
}

// MARK: - Step 4: Personality & Social
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                                    .foregroundColor(selectionHelper.selectedValues.contains(value) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                if selectionHelper.selectedValues.contains(value) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectionHelper.selectedValues.contains(value) ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                                    .foregroundColor(selectionHelper.selectedHobbies.contains(hobby) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                if selectionHelper.selectedHobbies.contains(hobby) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectionHelper.selectedHobbies.contains(hobby) ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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

// MARK: - Step 5: Privacy & Trust
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Toggle("Allow data sharing for better recommendations", isOn: $dataSharingConsent)
                    .font(.system(size: 16))
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
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
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
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
                        Color(red: 0.6, green: 0.4, blue: 0.2),
                        Color(red: 0.4, green: 0.2, blue: 0.1)
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    TextField("Enter company name", text: $companyName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Position
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    TextField("e.g., Software Engineer, Marketing Manager", text: $position)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Start Year
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Year *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    TextField("Enter school name", text: $schoolName)
                        .textFieldStyle(CustomTextFieldStyle())
                }
                
                // Start Year
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Year *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
