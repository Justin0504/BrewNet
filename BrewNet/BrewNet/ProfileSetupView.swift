import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var profileData = ProfileCreationData()
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showCompletion = false
    @State private var showDatabaseSetup = false
    @State private var isNavigating = false
    @State private var isLoadingExistingData = false
    @State private var isEditingExistingProfile = false // 标记是否是编辑已有 profile
    @State private var hasReachedBottom: [Int: Bool] = [:]
    @State private var scrollOffset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    
    private let totalSteps = 8
    
    // MARK: - Computed Properties
    private var progressPercentage: Int {
        Int(Double(currentStep) / Double(totalSteps) * 100)
    }
    
    private var canGoToNextStep: Bool {
        // Next button is always available (only disabled during navigation or loading)
        return true
    }
    
    private func checkIfReachedBottom() {
        // Check if content is scrollable
        guard contentHeight > 0 && scrollViewHeight > 0 else { 
            // If measurements aren't ready yet, we can't determine if scrolling is needed
            return 
        }
        
        // If content doesn't need scrolling (content fits in view), automatically allow next step
        let scrollableHeight = contentHeight - scrollViewHeight
        if scrollableHeight <= 10 { // 10pt tolerance for layout rounding
            // Content fits in view, no scrolling needed - allow next step
            hasReachedBottom[currentStep] = true
            return
        }
        
        // Check if scroll has reached bottom (with 50pt tolerance)
        let hasReached = scrollOffset >= scrollableHeight - 50
        
        if hasReached {
            hasReachedBottom[currentStep] = true
        }
    }
    
    private var progressHeaderView: some View {
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
                
                Text("\(progressPercentage)% Complete")
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
    }
    
    private var navigationButtonsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
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
                
                // Save Button
                Button(action: {
                    guard !isNavigating && !isLoading else { return }
                    
                    // Validate current step before saving
                    if let errorMessage = validateCurrentStep() {
                        showAlert(message: errorMessage)
                        return
                    }
                    
                    saveCurrentStep()
                }) {
                    Text("Save")
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
                .disabled(isNavigating || isLoading)
                .opacity((isNavigating || isLoading) ? 0.4 : 1.0)
                
                // Next Button
                Button(action: {
                    guard !isNavigating && !isLoading else {
                        print("⚠️ Button clicked but isNavigating=\(isNavigating) or isLoading=\(isLoading)")
                        return
                    }
                    
                    // Validate current step before proceeding
                    if let errorMessage = validateCurrentStep() {
                        showAlert(message: errorMessage)
                        return
                    }
                    
                    print("🔘 Button clicked: currentStep=\(currentStep), totalSteps=\(totalSteps)")
                    isNavigating = true
                    
                    if currentStep == totalSteps {
                        print("✅ Calling completeProfileSetup()...")
                        completeProfileSetup()
                        // 注意：completeProfileSetup 是异步的，isLoading 会在内部设置
                        // 不需要在这里重置 isNavigating，因为 completeProfileSetup 会处理状态
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep += 1
                        }
                        // Reset navigation state after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isNavigating = false
                        }
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
                .disabled(isNavigating || isLoading)
                .opacity((isNavigating || isLoading) ? 0.4 : 1.0)
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
                        Color(red: 0.98, green: 0.97, blue: 0.95),
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
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                            .scaleEffect(1.5)
                        
                        VStack(spacing: 12) {
                            Text("Loading Profile Data")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            Text("Please wait while we load your existing profile information...")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Spacer()
                    }
                } else {
                    // 添加加载覆盖层
                    ZStack {
                        VStack(spacing: 0) {
                            // Header with progress
                            progressHeaderView
                            .padding(.top, 20)
                            
                            // Content
                            ScrollViewReader { proxy in
                                GeometryReader { scrollGeometry in
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
                                                IndustryEditStep(profileData: $profileData)
                                                    .id("step-4")
                                            case 5:
                                                NetworkingPreferencesStep(profileData: $profileData)
                                                    .id("step-5")
                                            case 6:
                                                PersonalitySocialStep(profileData: $profileData)
                                                    .id("step-6")
                                            case 7:
                                                WorkAndLifestylePhotosStep(profileData: $profileData)
                                                    .id("step-7")
                                            case 8:
                                                PrivacyTrustStep(profileData: $profileData)
                                                    .id("step-8")
                                            default:
                                                EmptyView()
                                            }
                                        }
                                        .padding(.horizontal, 32)
                                        .padding(.top, 32)
                                        .padding(.bottom, 24)
                                        .background(
                                            GeometryReader { contentGeometry in
                                                Color.clear
                                                    .preference(key: ScrollOffsetPreferenceKey.self, value: contentGeometry.frame(in: .named("scroll")).minY)
                                                    .preference(key: ContentHeightPreferenceKey.self, value: contentGeometry.size.height)
                                            }
                                        )
                                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                                            scrollOffset = -value
                                            checkIfReachedBottom()
                                        }
                                        .onPreferenceChange(ContentHeightPreferenceKey.self) { value in
                                            contentHeight = value
                                            // Delay check to allow layout to settle
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                                checkIfReachedBottom()
                                            }
                                        }
                                        .onChange(of: currentStep) { newStep in
                                            // Reset bottom state when step changes
                                            hasReachedBottom[newStep] = false
                                            // Only scroll to top when step actually changes, not during picker interactions
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    proxy.scrollTo("step-\(newStep)", anchor: .top)
                                                }
                                                // Check if bottom reached after scroll animation
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                                    checkIfReachedBottom()
                                                }
                                            }
                                        }
                                    }
                                    .coordinateSpace(name: "scroll")
                                    .onAppear {
                                        scrollViewHeight = scrollGeometry.size.height
                                        // Check if bottom reached after layout completes
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            checkIfReachedBottom()
                                        }
                                    }
                                    .onChange(of: scrollGeometry.size.height) { newHeight in
                                        scrollViewHeight = newHeight
                                        // Delay check to allow layout to settle
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            checkIfReachedBottom()
                                        }
                                    }
                                }
                            }
                            
                            // Navigation buttons
                            navigationButtonsView
                            .padding(.bottom, 10)
                        }
                        
                        // 加载覆盖层 - 当保存 profile 时显示
                        if isLoading {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 24) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                
                                Text("Saving Profile...")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(32)
                            .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .cornerRadius(16)
                        }
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
        case 4: return "Industry Preferences"
        case 5: return "Networking Preferences"
        case 6: return "Personality & Social"
        case 7: return "Work & Lifestyle Photos"
        case 8: return "Privacy & Trust"
        default: return ""
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 1: return "Tell us about yourself - the basics that help others connect with you"
        case 2: return "Share your professional experience and expertise"
        case 3: return "Define your networking goals and intentions"
        case 4: return "Select industries you're interested in for recommendations"
        case 5: return "Set your networking preferences and availability"
        case 6: return "Show your personality and what makes you unique"
        case 7: return "Share your work and lifestyle - up to 10 photos each"
        case 8: return "Control your privacy and how others can discover you"
        default: return ""
        }
    }
    
    // MARK: - Validation
    private func validateCurrentStep() -> String? {
        switch currentStep {
        case 1: // Core Identity
            guard let coreIdentity = profileData.coreIdentity else {
                return "Please fill in all required fields: Name and Email are required."
            }
            if coreIdentity.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                return "Name is required. Please enter your full name."
            }
            if coreIdentity.email.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                return "Email is required. Please enter your email address."
            }
            // Basic email validation
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
            if !emailPredicate.evaluate(with: coreIdentity.email) {
                return "Please enter a valid email address."
            }
            return nil
            
        case 2: // Professional Background
            guard let professionalBackground = profileData.professionalBackground else {
                return "Please select your Industry (required field)."
            }
            if professionalBackground.industry == nil || professionalBackground.industry!.isEmpty {
                return "Industry is required. Please select your industry category and subcategory."
            }
            return nil
            
        case 3: // Networking Intention
            guard let networkingIntention = profileData.networkingIntention else {
                return "Please select at least one networking intention."
            }
            // Check if at least one intention is selected (primary or additional)
            // selectedIntention is not optional, so we check if additionalIntentions is not empty
            // or if selectedSubIntentions is not empty (which indicates an intention was selected)
            let hasIntention = !networkingIntention.additionalIntentions.isEmpty || !networkingIntention.selectedSubIntentions.isEmpty
            if !hasIntention {
                return "Please select at least one networking intention."
            }
            return nil
            
        case 4: // Industry Preferences
            // Step 4 is for Industry Preferences, which is stored in networkingIntention.industryPreferences
            guard let networkingIntention = profileData.networkingIntention else {
                return "Please set your networking preferences."
            }
            guard let industryPreferences = networkingIntention.industryPreferences else {
                return "Please set your networking preferences."
            }
            // Check if at least one industry preference is selected
            if industryPreferences.selections.isEmpty {
                return "Please select at least one industry preference."
            }
            // Check if selection count exceeds maximum (6)
            if industryPreferences.selections.count > 6 {
                return "You can select a maximum of 6 industry preferences. Please remove some selections."
            }
            return nil
            
        case 6: // Personality & Social
            // No required fields
            return nil
            
        case 7: // Work & Lifestyle Photos
            // No required fields
            return nil
            
        case 8: // Privacy & Trust
            // No required fields
            return nil
            
        default:
            return nil
        }
    }
    
    // MARK: - Profile Completion
    // MARK: - Save Current Step
    private func saveCurrentStep() {
        print("💾 saveCurrentStep() called for step \(currentStep)")
        
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            showAlert(message: "User not found. Please log in again.")
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // For step 4, force update industry preferences before saving
                if currentStep == 4 {
                    print("📋 Step 4: Forcing update of industry preferences before save...")
                    // Post a notification to trigger update in IndustryEditStep
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("ForceUpdateIndustryPreferences"), object: nil)
                    }
                    
                    // Wait a moment to ensure industry preferences are updated
                    print("⏳ Waiting for industry preferences to update...")
                    try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    
                    // Check if industry preferences were updated
                    await MainActor.run {
                        if let networkingIntention = self.profileData.networkingIntention {
                            if let industryPrefs = networkingIntention.industryPreferences {
                                print("✅ Industry preferences found: \(industryPrefs.selections.count) selections")
                            } else {
                                print("⚠️ Warning: networkingIntention exists but industryPreferences is nil")
                            }
                        } else {
                            print("⚠️ Warning: networkingIntention is nil in profileData")
                        }
                    }
                }
                
                // First, try to ensure the profiles table exists
                do {
                    try await supabaseService.createProfilesTable()
                } catch {
                    print("⚠️ 无法自动创建 profiles 表，请手动创建")
                }
                
                // Check if profile already exists
                let existingProfile = try await supabaseService.getProfile(userId: currentUser.id)
                
                let supabaseProfile: SupabaseProfile
                
                if let existing = existingProfile {
                    // Update existing profile with current step data
                    print("🔄 Saving current step data to existing profile...")
                    
                    // Merge networkingIntention properly to preserve industryPreferences
                    let existingIntention = existing.networkingIntention
                    
                    // Get the latest profileData on main thread
                    let currentProfileData = await MainActor.run {
                        return self.profileData
                    }
                    
                    let mergedNetworkingIntention: NetworkingIntention
                    if let newIntention = currentProfileData.networkingIntention {
                        // If new intention exists, merge it with existing, prioritizing new data
                        // For step 4, always use new industryPreferences if it exists
                        let finalIndustryPreferences: IndustryPreferencesData?
                        if currentStep == 4, let newPrefs = newIntention.industryPreferences {
                            finalIndustryPreferences = newPrefs
                            print("💾 [Step 4] Using new industryPreferences: \(newPrefs.selections.count) selections")
                        } else {
                            finalIndustryPreferences = newIntention.industryPreferences ?? existingIntention.industryPreferences
                        }
                        
                        mergedNetworkingIntention = NetworkingIntention(
                            selectedIntention: newIntention.selectedIntention,
                            additionalIntentions: newIntention.additionalIntentions,
                            selectedSubIntentions: newIntention.selectedSubIntentions,
                            careerDirection: newIntention.careerDirection ?? existingIntention.careerDirection,
                            skillDevelopment: newIntention.skillDevelopment ?? existingIntention.skillDevelopment,
                            industryTransition: newIntention.industryTransition ?? existingIntention.industryTransition,
                            industryPreferences: finalIndustryPreferences
                        )
                        print("💾 Merged networkingIntention - industryPreferences count: \(mergedNetworkingIntention.industryPreferences?.selections.count ?? 0)")
                    } else {
                        // Use existing intention if no new one
                        mergedNetworkingIntention = existingIntention
                        print("💾 Using existing networkingIntention - industryPreferences count: \(mergedNetworkingIntention.industryPreferences?.selections.count ?? 0)")
                    }
                    
                    let updatedProfile = SupabaseProfile(
                        id: existing.id,
                        userId: existing.userId,
                        coreIdentity: profileData.coreIdentity ?? existing.coreIdentity,
                        professionalBackground: profileData.professionalBackground ?? existing.professionalBackground,
                        networkingIntention: mergedNetworkingIntention,
                        networkingPreferences: profileData.networkingPreferences ?? existing.networkingPreferences,
                        personalitySocial: profileData.personalitySocial ?? existing.personalitySocial,
                        workPhotos: profileData.workPhotos ?? existing.workPhotos,
                        lifestylePhotos: profileData.lifestylePhotos ?? existing.lifestylePhotos,
                        privacyTrust: profileData.privacyTrust ?? existing.privacyTrust,
                        createdAt: existing.createdAt,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    
                    // Log industry preferences before saving
                    if let industryPrefs = updatedProfile.networkingIntention.industryPreferences {
                        print("💾 Saving profile with \(industryPrefs.selections.count) industry preferences")
                    } else {
                        print("⚠️ Warning: No industry preferences in profile being saved")
                    }
                    
                    supabaseProfile = try await supabaseService.updateProfile(profileId: existing.id, profile: updatedProfile)
                } else {
                    // Create new profile with current step data
                    print("🆕 Creating new profile with current step data...")
                    
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
                        workPhotos: updatedProfile.workPhotos,
                        lifestylePhotos: updatedProfile.lifestylePhotos,
                        privacyTrust: updatedProfile.privacyTrust,
                        createdAt: updatedProfile.createdAt,
                        updatedAt: updatedProfile.updatedAt
                    )
                    
                    let _ = try await supabaseService.createProfile(profile: supabaseProfile)
                }
                
                await MainActor.run {
                    isLoading = false
                    
                    // 重新加载保存后的数据到 profileData
                    print("🔄 Reloading saved profile data...")
                    profileData.coreIdentity = supabaseProfile.coreIdentity
                    profileData.professionalBackground = supabaseProfile.professionalBackground
                    profileData.networkingIntention = supabaseProfile.networkingIntention
                    profileData.networkingPreferences = supabaseProfile.networkingPreferences
                    profileData.personalitySocial = supabaseProfile.personalitySocial
                    profileData.workPhotos = supabaseProfile.workPhotos
                    profileData.lifestylePhotos = supabaseProfile.lifestylePhotos
                    profileData.privacyTrust = supabaseProfile.privacyTrust
                    
                    // Verify industry preferences were reloaded
                    if let reloadedPrefs = supabaseProfile.networkingIntention.industryPreferences {
                        print("✅ Profile data reloaded with \(reloadedPrefs.selections.count) industry preferences")
                    } else {
                        print("⚠️ Warning: Reloaded profile has no industry preferences")
                    }
                    
                    // 发送通知刷新 profile 数据
                    NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                    
                    // Post notification to reload industry preferences
                    NotificationCenter.default.post(name: NSNotification.Name("ProfileDataLoaded"), object: nil)
                    
                    // 直接关闭 edit profile 界面，不显示 Notice
                    print("✅ Profile saved successfully, closing edit profile view...")
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    let errorMessage = error.localizedDescription
                    print("❌ Save error: \(errorMessage)")
                    showAlert(message: "Failed to save: \(errorMessage)")
                }
            }
        }
    }
    
    private func completeProfileSetup() {
        print("🚀 completeProfileSetup() called")
        
        guard let currentUser = authManager.currentUser else {
            print("❌ No current user found")
            showAlert(message: "User not found. Please log in again.")
            isNavigating = false
            return
        }
        
        print("✅ Current user found: \(currentUser.id)")
        isLoading = true
        isNavigating = false // 重置导航状态，因为我们将显示加载指示器
        
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
                        workPhotos: profileData.workPhotos ?? existing.workPhotos,
                        lifestylePhotos: profileData.lifestylePhotos ?? existing.lifestylePhotos,
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
                        workPhotos: updatedProfile.workPhotos,
                        lifestylePhotos: updatedProfile.lifestylePhotos,
                        privacyTrust: updatedProfile.privacyTrust,
                        createdAt: updatedProfile.createdAt,
                        updatedAt: updatedProfile.updatedAt
                    )
                    
                    let _ = try await supabaseService.createProfile(profile: supabaseProfile)
                }
                
                // 只在首次创建 profile 时更新 setup status，编辑时不要更新
                let isFirstTimeSetup = existingProfile == nil
                
                if isFirstTimeSetup {
                    // Update user profile setup status (only for first-time setup)
                    do {
                        try await supabaseService.updateUserProfileSetupCompleted(userId: currentUser.id, completed: true)
                        print("✅ Profile setup status updated in Supabase")
                    } catch {
                        print("⚠️ Failed to update profile setup status in Supabase: \(error.localizedDescription)")
                        // Continue anyway, we'll update local state
                    }
                } else {
                    print("📝 Editing existing profile, skipping setup status update")
                }
                
                await MainActor.run {
                    isLoading = false
                    
                    // 无论是编辑还是首次设置，保存后都直接关闭 sheet
                    print("✅ Profile saved successfully, closing setup view...")
                    
                    // 只在首次设置时更新 auth manager（在 dismiss 之前，避免触发 ContentView 重新渲染）
                    if isFirstTimeSetup {
                        authManager.updateProfileSetupCompleted(true)
                    }
                    
                    // 先关闭 sheet
                    dismiss()
                    
                    // 延迟发送通知，确保 sheet 已完全关闭后再处理
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if isFirstTimeSetup {
                            // 首次设置：发送通知显示启动画面，然后进入主界面
                            print("🎬 首次设置完成，发送显示启动画面通知...")
                            NotificationCenter.default.post(name: NSNotification.Name("ShowSplashScreen"), object: nil)
                        } else {
                            // 编辑模式：只发送通知刷新 profile 数据
                            NotificationCenter.default.post(name: NSNotification.Name("ProfileUpdated"), object: nil)
                        }
                    }
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
            workPhotos: profileData.workPhotos ?? profile.workPhotos,
            lifestylePhotos: profileData.lifestylePhotos ?? profile.lifestylePhotos,
            privacyTrust: privacyTrust
        )
        
        print("🔧 Updated profile with collected data:")
        print("📝 Name: '\(coreIdentity.name)'")
        print("📧 Email: '\(coreIdentity.email)'")
        print("📱 Phone: '\(coreIdentity.phoneNumber ?? "nil")'")
        print("📄 Bio: '\(coreIdentity.bio ?? "nil")'")
        
        return updatedProfile
    }
    
    // MARK: - Load Existing Profile Data
    private func loadExistingProfileData() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ No current user found, skipping profile load")
            return
        }
        
        Task {
            do {
                isLoadingExistingData = true
                print("📥 Loading existing profile data for user: \(currentUser.id)")
                
                let existingProfile = try await supabaseService.getProfile(userId: currentUser.id)
                
                await MainActor.run {
                    if let profile = existingProfile {
                        print("✅ Found existing profile, loading data...")
                        
                        // Convert SupabaseProfile to ProfileCreationData
                        profileData = ProfileCreationData(
                            coreIdentity: profile.coreIdentity,
                            professionalBackground: profile.professionalBackground,
                            networkingIntention: profile.networkingIntention,
                            networkingPreferences: profile.networkingPreferences,
                            personalitySocial: profile.personalitySocial,
                            workPhotos: profile.workPhotos,
                            lifestylePhotos: profile.lifestylePhotos,
                            privacyTrust: profile.privacyTrust
                        )
                        
                        // Log industry preferences if they exist
                        if let industryPrefs = profile.networkingIntention.industryPreferences {
                            print("✅ Loaded \(industryPrefs.selections.count) industry preferences from database")
                            print("   Selections: \(industryPrefs.selections.map { "\($0.categoryName) > \($0.subcategoryName)" })")
                        } else {
                            print("ℹ️ No industry preferences found in existing profile")
                        }
                        
                        isEditingExistingProfile = true
                        isLoadingExistingData = false
                        
                        // Notify that profile data has been loaded
                        NotificationCenter.default.post(name: NSNotification.Name("ProfileDataLoaded"), object: nil)
                    } else {
                        print("ℹ️ No existing profile found, starting fresh")
                        isLoadingExistingData = false
                    }
                }
            } catch {
                await MainActor.run {
                    print("⚠️ Failed to load existing profile: \(error.localizedDescription)")
                    isLoadingExistingData = false
                    // Don't show error alert, just start fresh
                }
            }
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

}

// MARK: - Step 1: Core Identity
struct CoreIdentityStep: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @Binding var profileData: ProfileCreationData
    @StateObject private var locationService = LocationService.shared
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var selectedCountryCode: CountryCode = .china
    @State private var bio = ""
    @State private var pronouns = ""
    @State private var location = ""
    @State private var personalWebsite = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil
    @State private var profileImageURL: String? = nil
    @State private var isUploadingImage = false
    
    // Resume import related state
    @State private var showDocumentPicker = false
    @State private var isParsingResume = false
    @State private var showResumeParseAlert = false
    @State private var resumeParseMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Import Resume Button
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    showDocumentPicker = true
                }) {
                    HStack {
                        if isParsingResume {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16))
                        }
                        Text(isParsingResume ? "Parsing Resume..." : "Import Resume (PDF/Word)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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
                    .cornerRadius(12)
                }
                .disabled(isParsingResume)
                
            }
            .padding(.bottom, 8)
            
            // Profile Image Upload
            VStack(spacing: 12) {
                Text("Profile Picture")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    // Profile Image Display
                    if let profileImageData = profileImageData, let uiImage = UIImage(data: profileImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 3)
                            )
                    } else if let existingImageURL = profileImageURL, !existingImageURL.isEmpty {
                        AsyncImage(url: URL(string: existingImageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 3)
                        )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(Color(red: 0.8, green: 0.7, blue: 0.6))
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 3)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                if isUploadingImage {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                }
                                Text(isUploadingImage ? "Uploading..." : "Choose Photo")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isUploadingImage ? Color.gray : Color(red: 0.6, green: 0.4, blue: 0.2))
                            .cornerRadius(12)
                        }
                        .disabled(isUploadingImage)
                        
                        if (profileImageData != nil || (profileImageURL != nil && !profileImageURL!.isEmpty)) && !isUploadingImage {
                            Button(action: {
                                profileImageData = nil
                                profileImageURL = nil
                                selectedPhotoItem = nil
                                updateProfileData()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                    Text("Remove")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.bottom, 8)
            
            // Name
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Full Name *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
                
                VStack(spacing: 8) {
                    // Country code selector
                    HStack {
                        Text("Country Code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Spacer()
                        
                        Picker("Country Code", selection: $selectedCountryCode) {
                            ForEach(CountryCode.allCases, id: \.self) { code in
                                Text(code.displayName).tag(code)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    
                    TextField("Enter your phone number", text: $phoneNumber)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.phonePad)
                }
            }
            
            // Bio
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio (LinkedIn-style headline)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                TextField("e.g., she/her, they/them", text: $pronouns)
                    .textFieldStyle(CustomTextFieldStyle())
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Location")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Spacer()
                    
                    // Use Current Location Button
                    Button(action: {
                        useCurrentLocation()
                    }) {
                        HStack(spacing: 4) {
                            if locationService.isLocating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                            }
                            Text("Use Current Location")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(locationService.isLocating)
                }
                
                TextField("e.g., San Francisco, CA, USA", text: $location)
                    .textFieldStyle(CustomTextFieldStyle())
                    .onChange(of: location) { newValue in
                        // 实时验证和格式化地址
                        validateAndFormatLocation(newValue)
                    }
                
                
                // Show location error if any
                if let error = locationService.locationError {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            
            // Personal Website
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Personal Website")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("(LinkedIn, GitHub, etc.)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                TextField("https://yourwebsite.com", text: $personalWebsite)
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
                
                // Parse phone number if it includes country code
                if let storedPhoneNumber = coreIdentity.phoneNumber, !storedPhoneNumber.isEmpty {
                    let (countryCode, localNumber) = parsePhoneNumber(storedPhoneNumber)
                    if let code = countryCode {
                        selectedCountryCode = code
                    }
                    phoneNumber = localNumber
                } else {
                    phoneNumber = ""
                }
                
                bio = coreIdentity.bio ?? ""
                pronouns = coreIdentity.pronouns ?? ""
                location = coreIdentity.location ?? ""
                personalWebsite = coreIdentity.personalWebsite ?? ""
                
                // Load existing profile image URL if available
                profileImageURL = coreIdentity.profileImage
            }
        }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    // First, set the image data for immediate display
                    await MainActor.run {
                        profileImageData = data
                    }
                    
                    // Upload image to Supabase Storage
                    if let userId = authManager.currentUser?.id {
                        do {
                            print("📤 Uploading profile image...")
                            isUploadingImage = true
                            
                            // Detect file extension from data or use jpg as default
                            let fileExtension = detectImageFormat(from: data) ?? "jpg"
                            
                            // Upload to Supabase Storage
                            let publicURL = try await supabaseService.uploadProfileImage(
                                userId: userId,
                                imageData: data,
                                fileExtension: fileExtension
                            )
                            
                            // Add cache busting parameter to ensure fresh image load
                            let urlWithCacheBuster = "\(publicURL)?t=\(Date().timeIntervalSince1970)"
                            
                            await MainActor.run {
                                // Set the new URL with cache buster
                                profileImageURL = urlWithCacheBuster
                                // Clear the local image data after successful upload
                                // This forces the UI to use the URL, ensuring consistency
                                profileImageData = nil
                                isUploadingImage = false
                                updateProfileData()
                                print("✅ Profile image uploaded successfully: \(urlWithCacheBuster)")
                            }
                        } catch {
                            await MainActor.run {
                                isUploadingImage = false
                                print("❌ Failed to upload profile image: \(error.localizedDescription)")
                                // Keep image data on error so user can see their selection
                                // Don't set URL on failure
                                updateProfileData()
                            }
                        }
                    } else {
                        // No user ID, just keep the local data
                        await MainActor.run {
                            print("⚠️ No user ID available for upload")
                        }
                    }
                }
            }
        }
        .onChange(of: name) { _ in updateProfileData() }
        .onChange(of: email) { _ in updateProfileData() }
        .onChange(of: phoneNumber) { _ in updateProfileData() }
        .onChange(of: selectedCountryCode) { _ in updateProfileData() }
        .onChange(of: bio) { _ in updateProfileData() }
        .onChange(of: pronouns) { _ in updateProfileData() }
        .onChange(of: location) { _ in updateProfileData() }
        .onChange(of: locationService.currentAddress) { newAddress in
            if let address = newAddress, !address.isEmpty {
                location = address
                updateProfileData()
                print("✅ [Location] 自动填入地址: \(address)")
            }
        }
        .onChange(of: personalWebsite) { _ in updateProfileData() }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(isPresented: $showDocumentPicker) { url in
                parseResume(from: url)
            }
        }
        .alert("Resume Import", isPresented: $showResumeParseAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resumeParseMessage)
        }
    }
    
    // MARK: - Parse Resume
    private func parseResume(from url: URL) {
        isParsingResume = true
        
        Task {
            do {
                let parsedResume = try await ResumeParser.parseResume(from: url)
                
                await MainActor.run {
                    // Fill in basic information (Step 1)
                    if let parsedName = parsedResume.name, !parsedName.isEmpty {
                        name = parsedName
                    }
                    if let parsedEmail = parsedResume.email, !parsedEmail.isEmpty {
                        email = parsedEmail
                    }
                    if let parsedPhone = parsedResume.phone, !parsedPhone.isEmpty {
                        phoneNumber = parsedPhone
                    }
                    if let parsedLocation = parsedResume.location, !parsedLocation.isEmpty {
                        location = parsedLocation
                    }
                    // Note: We don't auto-fill bio as user should write it themselves
                    if let parsedWebsite = parsedResume.personalWebsite, !parsedWebsite.isEmpty {
                        personalWebsite = parsedWebsite
                    }
                    
                    // Update profileData (including LinkedIn and GitHub URL)
                    if var coreIdentity = profileData.coreIdentity {
                        let updatedCoreIdentity = CoreIdentity(
                            name: name.isEmpty ? coreIdentity.name : name,
                            email: email.isEmpty ? coreIdentity.email : email,
                            phoneNumber: phoneNumber.isEmpty ? coreIdentity.phoneNumber : phoneNumber,
                            profileImage: coreIdentity.profileImage,
                            bio: coreIdentity.bio, // Keep existing bio, don't overwrite
                            pronouns: coreIdentity.pronouns,
                            location: location.isEmpty ? coreIdentity.location : location,
                            personalWebsite: personalWebsite.isEmpty ? coreIdentity.personalWebsite : personalWebsite,
                            githubUrl: parsedResume.githubUrl ?? coreIdentity.githubUrl,
                            linkedinUrl: parsedResume.linkedInUrl ?? coreIdentity.linkedinUrl,
                            timeZone: coreIdentity.timeZone
                        )
                        profileData.coreIdentity = updatedCoreIdentity
                    } else {
                        // If coreIdentity doesn't exist, create a new one
                        updateProfileData()
                    }
                    
                    // Fill in professional background information (Step 2)
                    var existingProfessionalBackground = profileData.professionalBackground
                    
                    let updatedProfessionalBackground = ProfessionalBackground(
                        currentCompany: existingProfessionalBackground?.currentCompany, // Don't auto-fill current company from resume
                        jobTitle: parsedResume.jobTitle ?? existingProfessionalBackground?.jobTitle,
                        industry: existingProfessionalBackground?.industry,
                        experienceLevel: existingProfessionalBackground?.experienceLevel ?? .entry,
                        education: existingProfessionalBackground?.education,
                        educations: {
                            var allEducations = existingProfessionalBackground?.educations ?? []
                            // Add new educations, avoiding duplicates
                            for newEdu in parsedResume.educations {
                                if !allEducations.contains(where: { $0.schoolName == newEdu.schoolName && $0.startYear == newEdu.startYear }) {
                                    allEducations.append(newEdu)
                                }
                            }
                            return allEducations.isEmpty ? nil : allEducations
                        }(),
                        yearsOfExperience: parsedResume.yearsOfExperience ?? existingProfessionalBackground?.yearsOfExperience,
                        careerStage: existingProfessionalBackground?.careerStage ?? .earlyCareer,
                        skills: {
                            var allSkills = existingProfessionalBackground?.skills ?? []
                            // Add new skills, avoiding duplicates
                            for newSkill in parsedResume.skills {
                                if !allSkills.contains(newSkill) {
                                    allSkills.append(newSkill)
                                }
                            }
                            return allSkills
                        }(),
                        certifications: {
                            var allCerts = existingProfessionalBackground?.certifications ?? []
                            // Add new certifications, avoiding duplicates
                            for newCert in parsedResume.certifications {
                                if !allCerts.contains(newCert) {
                                    allCerts.append(newCert)
                                }
                            }
                            return allCerts
                        }(),
                        languagesSpoken: {
                            var allLanguages = existingProfessionalBackground?.languagesSpoken ?? []
                            // Add new languages, avoiding duplicates
                            for newLang in parsedResume.languages {
                                if !allLanguages.contains(newLang) {
                                    allLanguages.append(newLang)
                                }
                            }
                            return allLanguages
                        }(),
                        workExperiences: {
                            var allExperiences = existingProfessionalBackground?.workExperiences ?? []
                            // Add new work experiences, avoiding duplicates
                            for newExp in parsedResume.workExperiences {
                                if !allExperiences.contains(where: { $0.companyName == newExp.companyName && $0.startYear == newExp.startYear }) {
                                    allExperiences.append(newExp)
                                }
                            }
                            return allExperiences
                        }()
                    )
                    profileData.professionalBackground = updatedProfessionalBackground
                    
                    // Show success message
                    resumeParseMessage = "Resume imported successfully! Please review and confirm the information is correct."
                    showResumeParseAlert = true
                    isParsingResume = false
                }
            } catch {
                await MainActor.run {
                    resumeParseMessage = "Failed to parse resume: \(error.localizedDescription)"
                    showResumeParseAlert = true
                    isParsingResume = false
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        print("📍 [Location] 点击了 Use Current Location 按钮")
        
        // 如果已经在定位中，忽略重复点击
        if locationService.isLocating {
            print("⚠️ [Location] 定位请求正在进行中，请稍候...")
            return
        }
        
        // 检查权限状态
        switch locationService.authorizationStatus {
        case .notDetermined:
            print("📍 [Location] 请求位置权限...")
            // 先设置 isLocating，这样权限授予后会自动获取位置
            locationService.isLocating = true
            locationService.requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 [Location] 开始获取当前位置...")
            // 先清空当前地址，确保 onChange 能触发
            locationService.currentAddress = nil
            
            // 获取位置
            locationService.getCurrentLocation()
            
            // 使用 Task 监听地址更新（作为 onChange 的补充）
            Task {
                // 等待最多 5 秒
                for _ in 0..<50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                    if let address = locationService.currentAddress, !address.isEmpty {
                        await MainActor.run {
                            if location != address {
                                location = address
                                updateProfileData()
                                print("✅ [Location] 通过 Task 更新地址: \(address)")
                            }
                        }
                        return
                    }
                    // 如果定位完成但地址为空，也停止等待
                    if !locationService.isLocating && locationService.currentAddress == nil {
                        break
                    }
                }
                print("⚠️ [Location] 等待地址更新超时")
            }
        case .denied, .restricted:
            locationService.locationError = "Location permission denied. Please enable it in Settings."
            print("⚠️ [Location] 位置权限被拒绝")
        @unknown default:
            locationService.locationError = "Unknown location permission status."
        }
    }
    
    private func validateAndFormatLocation(_ address: String) {
        guard !address.isEmpty else { return }
        
        // 检查地址格式并提供建议
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        let addressLower = trimmed.lowercased()
        
        // 检查是否包含国家信息
        let hasCountry = addressLower.contains("usa") || 
                        addressLower.contains("united states") || 
                        addressLower.contains("america") ||
                        addressLower.contains(", us") ||
                        addressLower.hasSuffix(" usa")
        
        // 如果地址格式是 "City, State" 但没有国家信息，可以提示用户
        if trimmed.contains(",") {
            let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && !hasCountry {
                // 格式：City, State - 建议添加国家
                print("💡 [Location] 地址格式建议: '\(trimmed)' 可以改进为 '\(trimmed), USA' 以提高地理编码成功率")
            }
        } else if !hasCountry {
            // 单部分地址，建议添加国家
            print("💡 [Location] 地址格式建议: '\(trimmed)' 建议使用 'City, State, Country' 格式")
        }
    }
    
    private func updateProfileData() {
        // Combine country code and phone number when saving
        let fullPhoneNumber: String?
        if phoneNumber.isEmpty {
            fullPhoneNumber = nil
        } else {
            fullPhoneNumber = "\(selectedCountryCode.code)\(phoneNumber)"
        }
        
        // Use profileImageURL if available, it contains the uploaded URL
        // profileImageURL is set after successful upload or loaded from existing profile
        let imageURL = profileImageURL
        
        let coreIdentity = CoreIdentity(
            name: name,
            email: email,
            phoneNumber: fullPhoneNumber,
            profileImage: imageURL,
            bio: bio.isEmpty ? nil : bio,
            pronouns: pronouns.isEmpty ? nil : pronouns,
            location: location.isEmpty ? nil : location,
            personalWebsite: personalWebsite.isEmpty ? nil : personalWebsite,
            githubUrl: nil,
            linkedinUrl: nil,
            timeZone: TimeZone.current.identifier
        )
        profileData.coreIdentity = coreIdentity
    }
    
    // Helper function to parse phone number with country code
    private func parsePhoneNumber(_ phoneNumber: String) -> (CountryCode?, String) {
        // Sort country codes by length (longest first) to match longer codes before shorter ones
        // This prevents "+886" from being matched as "+86"
        let sortedCodes = CountryCode.allCases.sorted { $0.code.count > $1.code.count }
        
        // Check if phone number starts with a country code
        for countryCode in sortedCodes {
            if phoneNumber.hasPrefix(countryCode.code) {
                let localNumber = String(phoneNumber.dropFirst(countryCode.code.count))
                return (countryCode, localNumber)
            }
        }
        // If no country code found, assume it's already a local number
        return (nil, phoneNumber)
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
        if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
            return "gif"
        }
        
        // Check for WebP
        if data.count >= 12 {
            let webpHeader = String(data: data[0..<12], encoding: .ascii)
            if webpHeader?.hasPrefix("RIFF") == true && String(data: data[8..<12], encoding: .ascii) == "WEBP" {
                return "webp"
            }
        }
        
        return nil
    }
}

// MARK: - Step 2: Professional Background
struct ProfessionalBackgroundStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var currentCompany = ""
    @State private var jobTitle = ""
    @State private var selectedIndustry: IndustryOption? = nil // 保持向后兼容
    @State private var selectedCategory: IndustryCategory? = nil // 一级分类
    @State private var selectedSubcategory: String? = nil // 二级分类
    @State private var experienceLevel = ExperienceLevel.entry
    @State private var education = ""
    @State private var yearsOfExperience: Int? = nil
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
            
            // Industry - 两级选择
            VStack(alignment: .leading, spacing: 12) {
                Text("Industry *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                // 一级分类选择
                Menu {
                    ForEach(IndustryData.categories, id: \.id) { category in
                        Button(category.name) {
                            selectedCategory = category
                            selectedSubcategory = nil // 重置二级分类
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory?.name ?? "Select category")
                            .foregroundColor(selectedCategory == nil ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 二级分类选择（只有选择了一级分类后才显示）
                if let category = selectedCategory {
                    Menu {
                        ForEach(category.subcategories, id: \.self) { subcategory in
                            Button(subcategory) {
                                selectedSubcategory = subcategory
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSubcategory ?? "Select subcategory")
                                .foregroundColor(selectedSubcategory == nil ? .gray : .primary)
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
                
                Picker("Years of Experience", selection: Binding(
                    get: { yearsOfExperience ?? 0 },
                    set: { yearsOfExperience = $0 == 0 ? nil : $0 }
                )) {
                    Text("0 year").tag(0)
                    ForEach(YearOptions.yearsOfExperienceOptions.filter { $0 > 0 }, id: \.self) { years in
                        Text("\(years) year\(years == 1 ? "" : "s")").tag(years)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Skills *")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                // Add custom skill input
                HStack(spacing: 12) {
                    TextField("Add custom skill", text: $newSkill)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocorrectionDisabled()
                    
                    Button(action: {
                        let trimmedSkill = newSkill.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedSkill.isEmpty && !skills.contains(trimmedSkill) {
                            skills.append(trimmedSkill)
                            newSkill = ""
                        }
                    }) {
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .cornerRadius(8)
                    }
                    .disabled(newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
                
                // Selected skills
                if !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(skills, id: \.self) { skill in
                                HStack(spacing: 6) {
                                    Text(skill)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    
                                    Button(action: {
                                        skills.removeAll { $0 == skill }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .cornerRadius(16)
                            }
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
                
                // 尝试从industry字段加载两级分类
                if let industry = professionalBackground.industry {
                    // 尝试解析格式 "一级分类 > 二级分类" 或只包含二级分类
                    if industry.contains(" > ") {
                        let parts = industry.components(separatedBy: " > ")
                        if parts.count == 2 {
                            let categoryName = parts[0]
                            let subcategoryName = parts[1]
                            selectedCategory = IndustryData.categories.first { $0.name == categoryName }
                            selectedSubcategory = subcategoryName
                        }
                    } else {
                        // 尝试匹配二级分类
                        for category in IndustryData.categories {
                            if category.subcategories.contains(industry) {
                                selectedCategory = category
                                selectedSubcategory = industry
                                break
                            }
                        }
                    }
                    
                    // 如果没有匹配到，尝试旧的IndustryOption格式（向后兼容）
                    if selectedCategory == nil {
                        selectedIndustry = IndustryOption.allCases.first { $0.rawValue == industry }
                    }
                }
                
                experienceLevel = professionalBackground.experienceLevel
                education = professionalBackground.education ?? ""
                if let years = professionalBackground.yearsOfExperience {
                    yearsOfExperience = Int(years)
                } else {
                    yearsOfExperience = nil
                }
                careerStage = professionalBackground.careerStage
                skills = professionalBackground.skills
                certifications = professionalBackground.certifications
                languages = professionalBackground.languagesSpoken
                educations = professionalBackground.educations ?? []
                workExperiences = professionalBackground.workExperiences
            }
        }
        .onChange(of: currentCompany) { _ in updateProfileData() }
        .onChange(of: jobTitle) { _ in updateProfileData() }
        .onChange(of: selectedIndustry) { _ in updateProfileData() }
        .onChange(of: selectedCategory) { _ in updateProfileData() }
        .onChange(of: selectedSubcategory) { _ in updateProfileData() }
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
        // 优先使用新的两级分类，如果没有则使用旧的IndustryOption
        var industryValue: String? = nil
        if let category = selectedCategory, let subcategory = selectedSubcategory {
            // 保存格式：一级分类 > 二级分类
            industryValue = "\(category.name) > \(subcategory)"
        } else if let oldIndustry = selectedIndustry {
            // 向后兼容：使用旧的IndustryOption
            industryValue = oldIndustry.rawValue
        }
        
        let professionalBackground = ProfessionalBackground(
            currentCompany: currentCompany.isEmpty ? nil : currentCompany,
            jobTitle: jobTitle.isEmpty ? nil : jobTitle,
            industry: industryValue,
            experienceLevel: experienceLevel,
            education: education.isEmpty ? nil : education,
            educations: educations.isEmpty ? nil : educations,
            yearsOfExperience: yearsOfExperience != nil && yearsOfExperience! > 0 ? Double(yearsOfExperience!) : nil,
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
    @State private var timeslotTimezone = TimeZone.current.identifier // 默认使用当前位置时区
    
    var body: some View {
        VStack(spacing: 24) {
            // Preferred Chat Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Chat Format")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                HStack(spacing: 8) {
                    ForEach(ChatFormat.allCases, id: \.self) { format in
                        Button(action: {
                            preferredChatFormat = format
                        }) {
                            Text(format.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(preferredChatFormat == format ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(preferredChatFormat == format ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Timezone Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Timezone")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("Select the timezone for your available timeslots")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                TimezonePicker(selectedTimezone: $timeslotTimezone)
            }
            
            // Available Timeslot Matrix
            VStack(alignment: .leading, spacing: 16) {
                Text("Available Timeslots")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
        .onChange(of: timeslotTimezone) { _ in updateProfileData() }
    }
    
    private func loadExistingData() {
        if let networkingPreferences = profileData.networkingPreferences {
            preferredChatFormat = networkingPreferences.preferredChatFormat
            preferredChatDuration = networkingPreferences.preferredChatDuration ?? ""
            availableTimeslot = networkingPreferences.availableTimeslot
            timeslotTimezone = networkingPreferences.timeslotTimezone ?? TimeZone.current.identifier
        }
    }
    
    private func updateProfileData() {
        let networkingPreferences = NetworkingPreferences(
            preferredChatFormat: preferredChatFormat,
            availableTimeslot: availableTimeslot,
            preferredChatDuration: preferredChatDuration.isEmpty ? nil : preferredChatDuration,
            timeslotTimezone: timeslotTimezone
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
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Time slot rows
            ForEach(Array(timeSlots.enumerated()), id: \.offset) { timeIndex, timeSlot in
                HStack(spacing: 2) {
                    Text(timeSlot)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
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
                .fill(isSelected ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
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

// MARK: - Timezone Picker
struct TimezonePicker: View {
    @Binding var selectedTimezone: String
    @State private var searchText = ""
    @State private var showingPicker = false
    
    private var commonTimezones: [(identifier: String, displayName: String)] {
        let timezoneData: [(identifier: String, name: String)] = [
            ("America/New_York", "Eastern Time (ET)"),
            ("America/Chicago", "Central Time (CT)"),
            ("America/Denver", "Mountain Time (MT)"),
            ("America/Los_Angeles", "Pacific Time (PT)"),
            ("America/Phoenix", "Arizona Time (MST)"),
            ("America/Anchorage", "Alaska Time (AKT)"),
            ("Pacific/Honolulu", "Hawaii Time (HST)"),
            ("Europe/London", "London (GMT)"),
            ("Europe/Paris", "Paris (CET)"),
            ("Europe/Berlin", "Berlin (CET)"),
            ("Asia/Shanghai", "Shanghai (CST)"),
            ("Asia/Tokyo", "Tokyo (JST)"),
            ("Asia/Hong_Kong", "Hong Kong (HKT)"),
            ("Asia/Singapore", "Singapore (SGT)"),
            ("Australia/Sydney", "Sydney (AEST)"),
            ("America/Toronto", "Toronto (EST)"),
            ("America/Vancouver", "Vancouver (PST)"),
            ("America/Mexico_City", "Mexico City (CST)"),
            ("America/Sao_Paulo", "São Paulo (BRT)"),
            ("Asia/Dubai", "Dubai (GST)"),
            ("Asia/Mumbai", "Mumbai (IST)"),
            ("Asia/Seoul", "Seoul (KST)"),
        ]
        
        return timezoneData.compactMap { (identifier, name) -> (identifier: String, displayName: String)? in
            guard let tz = TimeZone(identifier: identifier) else { return nil }
            let offset = tz.secondsFromGMT()
            let hours = offset / 3600
            let minutes = abs(offset % 3600) / 60
            let sign = hours >= 0 ? "+" : "-"
            let offsetString = String(format: "%@%02d:%02d", sign, abs(hours), minutes)
            return (identifier: identifier, displayName: "\(name) (GMT\(offsetString))")
        }
    }
    
    private var allTimezones: [(identifier: String, displayName: String)] {
        let common = commonTimezones
        let all = TimeZone.knownTimeZoneIdentifiers.compactMap { identifier -> (identifier: String, displayName: String)? in
            guard let tz = TimeZone(identifier: identifier) else { return nil }
            let offset = tz.secondsFromGMT()
            let hours = offset / 3600
            let minutes = abs(offset % 3600) / 60
            let sign = hours >= 0 ? "+" : "-"
            let offsetString = String(format: "%@%02d:%02d", sign, abs(hours), minutes)
            return (identifier: identifier, displayName: "\(identifier.replacingOccurrences(of: "_", with: " ")) (GMT\(offsetString))")
        }
        return common + all.filter { tz in !common.contains { $0.identifier == tz.identifier } }
    }
    
    private var filteredTimezones: [(identifier: String, displayName: String)] {
        if searchText.isEmpty {
            return commonTimezones
        }
        return allTimezones.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) || $0.identifier.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var currentDisplayName: String {
        if let tz = TimeZone(identifier: selectedTimezone) {
            let offset = tz.secondsFromGMT()
            let hours = offset / 3600
            let minutes = abs(offset % 3600) / 60
            let sign = hours >= 0 ? "+" : "-"
            let offsetString = String(format: "%@%02d:%02d", sign, abs(hours), minutes)
            return "\(selectedTimezone.replacingOccurrences(of: "_", with: " ")) (GMT\(offsetString))"
        }
        return selectedTimezone
    }
    
    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack {
                Text(currentDisplayName)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingPicker) {
            NavigationView {
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search timezone", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.05))
                    
                    // Timezone list
                    List {
                        ForEach(filteredTimezones, id: \.identifier) { timezone in
                            Button(action: {
                                selectedTimezone = timezone.identifier
                                showingPicker = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(timezone.displayName)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedTimezone == timezone.identifier {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .navigationTitle("Select Timezone")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingPicker = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Industry Edit
struct IndustryEditStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var industrySelections: [IndustryEditSelection] = []
    @State private var isUpdatingFromData = false
    @State private var hasLoadedInitialData = false
    
    var body: some View {
        VStack(spacing: 0) {
            IndustryEditView(industrySelections: $industrySelections)
        }
        .onAppear {
            print("📥 [IndustryEditStep] onAppear called")
            // Reset the flag when view appears to ensure fresh load
            hasLoadedInitialData = false
            // Load immediately when view appears, with a delay to ensure profileData is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("📥 [IndustryEditStep] Delayed load triggered")
                loadIndustryPreferences()
                hasLoadedInitialData = true
            }
        }
        .onChange(of: profileData.networkingIntention?.industryPreferences) { newPrefs in
            // Only reload if this change was NOT made by our own updateProfileData() call
            // Check if the new preferences match our current selections
            if !isUpdatingFromData {
                let currentSelectionIds = Set(industrySelections.map { "\($0.categoryName)-\($0.subcategoryName)" })
                let newPrefIds = Set((newPrefs?.selections ?? []).map { "\($0.categoryName)-\($0.subcategoryName)" })
                
                // Only reload if the data is actually different (e.g., loaded from database)
                // OR if this is the first time loading data
                if currentSelectionIds != newPrefIds || !hasLoadedInitialData {
                    print("📥 [IndustryEditStep] profileData.networkingIntention.industryPreferences changed externally")
                    loadIndustryPreferences()
                    hasLoadedInitialData = true
                } else {
                    print("ℹ️ [IndustryEditStep] industryPreferences changed but matches current selections, skipping reload")
                }
            }
        }
        .onChange(of: profileData.networkingIntention) { newIntention in
            // Only reload if networkingIntention was nil and now has data, or if it's a different instance
            if !isUpdatingFromData {
                if let prefs = newIntention?.industryPreferences {
                    let currentSelectionIds = Set(industrySelections.map { "\($0.categoryName)-\($0.subcategoryName)" })
                    let newPrefIds = Set(prefs.selections.map { "\($0.categoryName)-\($0.subcategoryName)" })
                    
                    // Load if different OR if this is first time loading
                    if currentSelectionIds != newPrefIds || !hasLoadedInitialData {
                        print("📥 [IndustryEditStep] profileData.networkingIntention changed with different preferences")
                        print("   Found industryPreferences in newIntention: \(prefs.selections.count) selections")
                        loadIndustryPreferences()
                        hasLoadedInitialData = true
                    }
                } else if !industrySelections.isEmpty {
                    // If networkingIntention exists but has no preferences, and we have selections, don't clear them
                    // This might be a temporary state during update
                    print("ℹ️ [IndustryEditStep] networkingIntention changed but no preferences, keeping current selections")
                }
            }
        }
        .onChange(of: industrySelections) { newSelections in
            // Only update profileData if this change was made by user interaction, not from loading
            if !isUpdatingFromData {
                print("🔄 Industry selections changed: \(newSelections.count) selections")
                updateProfileData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ForceUpdateIndustryPreferences"))) { _ in
            print("🔔 Received ForceUpdateIndustryPreferences notification")
            updateProfileData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileDataLoaded"))) { _ in
            print("🔔 Received ProfileDataLoaded notification, reloading industry preferences")
            // Load immediately when profile data is loaded
            loadIndustryPreferences()
            hasLoadedInitialData = true
        }
    }
    
    private func loadIndustryPreferences() {
        print("📥 [IndustryEditStep] loadIndustryPreferences() called")
        print("   profileData.networkingIntention is nil: \(profileData.networkingIntention == nil)")
        
        // Load existing industry preferences from profileData
        if let networkingIntention = profileData.networkingIntention {
            print("   networkingIntention exists")
            if let existing = networkingIntention.industryPreferences {
                print("   industryPreferences exists with \(existing.selections.count) selections")
                let loadedSelections = existing.selections.map { selection in
                    IndustryEditSelection(
                        categoryName: selection.categoryName,
                        subcategoryName: selection.subcategoryName
                    )
                }
                
                print("   Loaded selections: \(loadedSelections.map { "\($0.categoryName) > \($0.subcategoryName)" })")
                print("   Current industrySelections count: \(industrySelections.count)")
                
                // Check if selections are different before updating to avoid unnecessary UI updates
                let currentSelectionIds = Set(industrySelections.map { $0.id })
                let loadedSelectionIds = Set(loadedSelections.map { $0.id })
                
                // Always update if selections are different OR if we haven't loaded initial data yet
                if currentSelectionIds != loadedSelectionIds || !hasLoadedInitialData {
                    // Temporarily disable onChange trigger during loading
                    isUpdatingFromData = true
                    
                    // Always update to ensure UI reflects the saved state
                    industrySelections = loadedSelections
                    print("✅ [IndustryEditStep] Set industrySelections to \(industrySelections.count) items")
                    print("   Updated selections: \(industrySelections.map { "\($0.categoryName) > \($0.subcategoryName)" })")
                    
                    // Re-enable onChange trigger after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isUpdatingFromData = false
                    }
                    
                    // Auto-expand categories with selections
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ExpandCategoriesWithSelections"),
                            object: nil,
                            userInfo: ["selections": loadedSelections]
                        )
                    }
                } else {
                    print("ℹ️ [IndustryEditStep] Selections unchanged, skipping update")
                    // Even if unchanged, ensure categories are expanded
                    if !loadedSelections.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ExpandCategoriesWithSelections"),
                                object: nil,
                                userInfo: ["selections": loadedSelections]
                            )
                        }
                    }
                }
            } else {
                print("⚠️ [IndustryEditStep] networkingIntention exists but industryPreferences is nil")
                // Only clear if we have selections but no preferences (data mismatch)
                if !industrySelections.isEmpty {
                    isUpdatingFromData = true
                    industrySelections = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isUpdatingFromData = false
                    }
                }
            }
        } else {
            print("⚠️ [IndustryEditStep] profileData.networkingIntention is nil")
            // Only clear if we have selections but no networkingIntention (data mismatch)
            if !industrySelections.isEmpty {
                isUpdatingFromData = true
                industrySelections = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isUpdatingFromData = false
                }
            }
        }
    }
    
    private func updateProfileData() {
        // Convert IndustryEditSelection to IndustryPreferencesData
        let preferences = IndustryPreferencesData(
            selections: industrySelections.map { selection in
                IndustryPreferenceSelection(
                    categoryName: selection.categoryName,
                    subcategoryName: selection.subcategoryName
                )
            }
        )
        
        print("💾 [IndustryEditStep] Updating profileData with \(preferences.selections.count) industry preferences")
        print("   Selections: \(industrySelections.map { "\($0.categoryName) > \($0.subcategoryName)" })")
        
        // Temporarily set flag to prevent onChange from triggering reload
        isUpdatingFromData = true
        
        // Update networkingIntention with industry preferences
        if var networkingIntention = profileData.networkingIntention {
            networkingIntention.industryPreferences = preferences
            profileData.networkingIntention = networkingIntention
            print("✅ [IndustryEditStep] Updated existing networkingIntention with industry preferences")
        } else {
            // Create a default networkingIntention if it doesn't exist
            let defaultIntention = NetworkingIntention(
                selectedIntention: .learnGrow,
                additionalIntentions: [],
                selectedSubIntentions: [],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil,
                industryPreferences: preferences
            )
            profileData.networkingIntention = defaultIntention
            print("✅ [IndustryEditStep] Created new networkingIntention with industry preferences")
        }
        
        // Re-enable onChange after a brief delay to allow the update to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isUpdatingFromData = false
        }
        
        // Verify the update
        if let updated = profileData.networkingIntention?.industryPreferences {
            print("✅ [IndustryEditStep] Verified: profileData now has \(updated.selections.count) industry preferences")
            print("   Updated selections: \(updated.selections.map { "\($0.categoryName) > \($0.subcategoryName)" })")
        } else {
            print("⚠️ [IndustryEditStep] Warning: profileData.networkingIntention.industryPreferences is still nil after update")
        }
    }
}

// MARK: - Step 3: Networking Intention
struct NetworkingIntentionStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var selectedIntentions: [NetworkingIntentionType] = [.learnGrow]
    @State private var primaryIntention: NetworkingIntentionType = .learnGrow
    @State private var selectedSubIntentions: [SubIntentionType] = []
    @State private var refreshID = UUID()
    @State private var isLoadingFromData = false // 防止循环更新
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
                Text("Select your networking intentions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(NetworkingIntentionType.allCases, id: \.self) { intention in
                Button(action: {
                    if let index = selectedIntentions.firstIndex(of: intention) {
                        selectedIntentions.remove(at: index)
                        let availableSubs = Set(orderedSubIntentions())
                        selectedSubIntentions = selectedSubIntentions.filter { availableSubs.contains($0) }
                        if primaryIntention == intention {
                            primaryIntention = orderedSelectedIntentions().first ?? .learnGrow
                        }
                        if selectedIntentions.isEmpty {
                            primaryIntention = .learnGrow
                            selectedIntentions = [.learnGrow]
                            selectedSubIntentions.removeAll()
                        }
                    } else {
                        selectedIntentions.append(intention)
                        if orderedSelectedIntentions().count == 1 {
                            primaryIntention = intention
                        }
                    }
                    updateProfileData()
                }) {
                            VStack(spacing: 8) {
                                Text(getIntentionDescription(intention))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedIntentions.contains(intention) ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(selectedIntentions.contains(intention) ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Sub-intention Selection
            if !selectedIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select sub-intentions (up to 8):")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(groupedSubIntentionsData().enumerated()), id: \.element.0) { index, group in
                            let (intention, subIntentions) = group

                            VStack(alignment: .leading, spacing: 12) {
                                if index > 0 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }

                                Text(getIntentionDescription(intention))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.12))
                                    .cornerRadius(10)

                                VStack(spacing: 8) {
                                    ForEach(subIntentions, id: \.self) { subIntention in
                                        Button(action: {
                                            if let index = selectedSubIntentions.firstIndex(of: subIntention) {
                                                selectedSubIntentions.remove(at: index)
                                                updateProfileData()
                                            } else if selectedSubIntentions.count < 8 {
                                                selectedSubIntentions.append(subIntention)
                                                updateProfileData()
                                            }
                                        }) {
                                            let isSelected = selectedSubIntentions.contains(subIntention)

                                            HStack {
                                                Text(subIntention.displayName)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(isSelected ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))

                                                Spacer()

                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? Color(red: 0.6, green: 0.4, blue: 0.2) : Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                        .id("\(subIntention.rawValue)-\(refreshID)") // 使用 refreshID 强制刷新
                                        .onAppear {
                                            let isSelected = selectedSubIntentions.contains(subIntention)
                                            print("🔍 Button '\(subIntention.displayName)' appeared - isSelected: \(isSelected)")
                                            print("   selectedSubIntentions Set: \(selectedSubIntentions.map { $0.rawValue })")
                                            print("   subIntention rawValue: '\(subIntention.rawValue)'")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Detailed Forms based on selected sub-intentions
            if !selectedSubIntentions.isEmpty {
                VStack(spacing: 16) {
                    ForEach(orderedSelectedSubIntentions(), id: \.self) { subIntention in
                        switch subIntention {
                        case .industryTransition:
                            EmptyView()
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
        .id(refreshID) // 使用 refreshID 强制刷新视图
        .onAppear {
            print("📍 NetworkingIntentionStep appeared")
            print("   Current selectedSubIntentions: \(selectedSubIntentions.map { $0.rawValue })")
            loadExistingData()
            // 延迟一点再次检查，确保数据已加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔄 Delayed reload check...")
                loadExistingData()
            }
            // 再延迟一点，确保数据完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 Final reload check...")
                loadExistingData()
            }
        }
        .onChange(of: profileData.networkingIntention?.selectedSubIntentions ?? []) { newValue in
            // 监听 sub-intentions 数组的变化（更可靠的触发方式）
            // 当 profileData 从服务器加载完成后，重新加载 UI 状态
            print("🔄 ProfileData networking intention sub-intentions changed: \(newValue.map { $0.rawValue })")
            
            // 只有当新值不为空或者是第一次加载时才重新加载
            // 避免因为用户操作导致的空数组覆盖已有数据
            if !newValue.isEmpty || selectedSubIntentions.isEmpty {
                print("   → Reloading UI state...")
                loadExistingData()
            } else {
                print("   → Skipping reload (empty array but Set already has data)")
            }
        }
        .onChange(of: selectedSubIntentions) { newValue in
            // 当 selectedSubIntentions 更新时，打印当前状态用于调试
            print("📊 selectedSubIntentions Set updated: \(newValue.map { $0.rawValue })")
        }
        .onChange(of: selectedSubIntentions) { _ in updateProfileData() }
        .onChange(of: selectedIntentions) { _ in updateProfileData() }
        .onChange(of: marketingFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: productTechFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: dataAnalyticsFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: financeConsultingFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: operationsHRFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: creativeMediaFunctions) { _ in updateCareerDirectionData() }
        .onChange(of: skills) { _ in updateSkillDevelopmentData() }
        .onChange(of: industries) { _ in updateIndustryTransitionData() }
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
        // 防止循环更新
        guard !isLoadingFromData else {
            print("⚠️ Already loading from data, skipping...")
            return
        }
        
        guard let networkingIntention = profileData.networkingIntention else {
            print("⚠️ No networking intention data found in profileData")
            return
        }
        
        isLoadingFromData = true
        defer { isLoadingFromData = false }
        
        print("🔄 Loading existing networking intention data...")
        print("   Selected intention: \(networkingIntention.selectedIntention)")
        print("   Selected sub-intentions count: \(networkingIntention.selectedSubIntentions.count)")
        print("   Sub-intentions: \(networkingIntention.selectedSubIntentions.map { $0.rawValue })")
        
        // 更新意图集合
        let additionalOrdered = NetworkingIntentionType.allCases.filter { networkingIntention.additionalIntentions.contains($0) }
        let allIntentions = [networkingIntention.selectedIntention] + additionalOrdered.filter { $0 != networkingIntention.selectedIntention }
        selectedIntentions = allIntentions.isEmpty ? [.learnGrow] : allIntentions
        primaryIntention = networkingIntention.selectedIntention
        
        // 然后更新 selectedSubIntentions
        let validSubIntentions = networkingIntention.selectedSubIntentions.filter { intent in
            orderedSelectedIntentions().flatMap { $0.subIntentions }.contains(intent)
        }
        let newSubIntentions = orderedSubIntentions().filter { validSubIntentions.contains($0) }
        
        print("   📋 Before update:")
        print("      - Current selectedSubIntentions: \(selectedSubIntentions.map { $0.rawValue })")
        print("      - New sub-intentions from data: \(networkingIntention.selectedSubIntentions.map { $0.rawValue })")
        print("      - New Set: \(newSubIntentions.map { $0.rawValue })")
        
        selectedSubIntentions = newSubIntentions
        
        // 强制刷新视图
        refreshID = UUID()
        
        print("   ✅ UI state updated:")
        print("      - selectedIntentions: \(selectedIntentions.map { $0.displayName })")
        print("      - selectedSubIntentions count: \(selectedSubIntentions.count)")
        print("      - selectedSubIntentions: \(selectedSubIntentions.map { $0.rawValue })")
        print("      - Checking if cofounderMatch is selected: \(selectedSubIntentions.contains(.cofounderMatch))")
        
        // 验证每个 sub-intention 是否正确加载
        for subIntention in networkingIntention.selectedSubIntentions {
            let isInSet = selectedSubIntentions.contains(subIntention)
            print("      - '\(subIntention.rawValue)' in Set: \(isInSet)")
            if !isInSet {
                print("      ⚠️ WARNING: Sub-intention '\(subIntention.rawValue)' not found in Set!")
            }
        }
        
        // 验证所有可能的 sub-intentions
        for possibleSubIntention in SubIntentionType.allCases {
            if networkingIntention.selectedSubIntentions.contains(possibleSubIntention) {
                let isInSet = selectedSubIntentions.contains(possibleSubIntention)
                print("      - Checking '\(possibleSubIntention.rawValue)': \(isInSet)")
            }
        }
        
        careerDirectionData = networkingIntention.careerDirection
        skillDevelopmentData = networkingIntention.skillDevelopment
        industryTransitionData = networkingIntention.industryTransition
        
        // Load career direction functions from data
        if let careerData = careerDirectionData {
            loadCareerDirectionFunctions(from: careerData)
        }
        
        // Load skill development from data
        if let skillData = skillDevelopmentData {
            skills = skillData.skills
        }
        
        // Load industry transition from data
        if let industryData = industryTransitionData {
            industries = industryData.industries
        }
    }
    
    private func loadCareerDirectionFunctions(from data: CareerDirectionData) {
        // Reset all functions
        marketingFunctions = [:]
        productTechFunctions = [:]
        dataAnalyticsFunctions = [:]
        financeConsultingFunctions = [:]
        operationsHRFunctions = [:]
        creativeMediaFunctions = [:]
        
        // Load from CareerDirectionData
        for functionSelection in data.functions {
            var options: [String] = []
            if !functionSelection.learnIn.isEmpty {
                options.append("learn")
            }
            if !functionSelection.guideIn.isEmpty {
                options.append("guide")
            }
            
            let functionName = functionSelection.functionName
            
            // Determine which dictionary to use based on function name
            if ["Brand Marketing", "Digital Marketing", "Social Media Operations", "Content Strategy"].contains(functionName) {
                marketingFunctions[functionName] = options
            } else if ["Product Management", "Product Operations", "Front-end Development", "UX / UI Design", "Product Data Analytics", "Backend Development"].contains(functionName) {
                productTechFunctions[functionName] = options
            } else if ["Data Analyst", "Growth Analyst", "Marketing Data", "Business Intelligence", "Machine Learning Ops", "Research Analyst"].contains(functionName) {
                dataAnalyticsFunctions[functionName] = options
            } else if ["Investment Banking", "Equity Research", "VC / PE Analyst", "Strategy Consulting", "Corporate Finance", "Financial Planning"].contains(functionName) {
                financeConsultingFunctions[functionName] = options
            } else if ["Project Management", "Business Operations", "Supply Chain", "HR / Talent Acquisition", "Training & L&D", "Organizational Development"].contains(functionName) {
                operationsHRFunctions[functionName] = options
            } else if ["Copywriting", "PR & Communications", "Art Direction", "Video Editing / Motion Design", "Creative Strategy", "Advertising Production"].contains(functionName) {
                creativeMediaFunctions[functionName] = options
            }
        }
    }
    
    private func updateCareerDirectionData() {
        var allFunctions: [FunctionSelection] = []
        
        // Combine all function dictionaries
        let allFunctionDicts: [String: [String]] = marketingFunctions
            .merging(productTechFunctions) { (_, new) in new }
            .merging(dataAnalyticsFunctions) { (_, new) in new }
            .merging(financeConsultingFunctions) { (_, new) in new }
            .merging(operationsHRFunctions) { (_, new) in new }
            .merging(creativeMediaFunctions) { (_, new) in new }
        
        for (functionName, options) in allFunctionDicts {
            let learnIn = options.contains("learn") ? ["learn"] : []
            let guideIn = options.contains("guide") ? ["guide"] : []
            allFunctions.append(FunctionSelection(
                functionName: functionName,
                learnIn: learnIn,
                guideIn: guideIn
            ))
        }
        
        careerDirectionData = allFunctions.isEmpty ? nil : CareerDirectionData(functions: allFunctions)
        updateProfileData()
    }
    
    private func updateSkillDevelopmentData() {
        skillDevelopmentData = skills.isEmpty ? nil : SkillDevelopmentData(skills: skills)
        updateProfileData()
    }
    
    private func updateIndustryTransitionData() {
        industryTransitionData = industries.isEmpty ? nil : IndustryTransitionData(industries: industries)
        updateProfileData()
    }
    
    private func orderedSelectedIntentions() -> [NetworkingIntentionType] {
        NetworkingIntentionType.allCases.filter { selectedIntentions.contains($0) }
    }
    
    private func orderedSubIntentions() -> [SubIntentionType] {
        var seen: Set<SubIntentionType> = []
        return orderedSelectedIntentions().flatMap { intention in
            intention.subIntentions.compactMap { sub in
                guard !seen.contains(sub) else { return nil }
                seen.insert(sub)
                return sub
            }
        }
    }
    
    private func orderedSelectedSubIntentions() -> [SubIntentionType] {
        orderedSubIntentions().filter { selectedSubIntentions.contains($0) }
    }
    
    private func groupedSubIntentionsData() -> [(NetworkingIntentionType, [SubIntentionType])] {
        let availableSubIntentions = orderedSubIntentions()
        var result: [(NetworkingIntentionType, [SubIntentionType])] = []

        for intention in orderedSelectedIntentions() {
            let subIntentions = availableSubIntentions.filter { intention.subIntentions.contains($0) }
            if !subIntentions.isEmpty {
                result.append((intention, subIntentions))
            }
        }

        return result
    }

    private func updateProfileData() {
        // 如果正在从数据加载，不要更新 profileData（避免循环）
        guard !isLoadingFromData else {
            print("⚠️ Skipping updateProfileData while loading from data")
            return
        }
        
        print("📝 Updating profileData with current UI state:")
        print("   selectedIntentions: \(orderedSelectedIntentions().map { $0.displayName })")
        print("   selectedSubIntentions: \(orderedSelectedSubIntentions().map { $0.rawValue })")
        
        if !selectedIntentions.contains(primaryIntention) {
            primaryIntention = orderedSelectedIntentions().first ?? .learnGrow
        }
        let additional = orderedSelectedIntentions().filter { $0 != primaryIntention }
        
        // Preserve existing industryPreferences when updating from Step 3
        let existingIndustryPreferences = profileData.networkingIntention?.industryPreferences
        if let existing = existingIndustryPreferences {
            print("📋 [NetworkingIntentionStep] Preserving \(existing.selections.count) industry preferences")
        }
        
        let networkingIntention = NetworkingIntention(
            selectedIntention: primaryIntention,
            additionalIntentions: additional,
            selectedSubIntentions: orderedSelectedSubIntentions(),
            careerDirection: careerDirectionData,
            skillDevelopment: skillDevelopmentData,
            industryTransition: industryTransitionData,
            industryPreferences: existingIndustryPreferences // Preserve existing industryPreferences
        )
        profileData.networkingIntention = networkingIntention
        
        print("   ✅ profileData updated")
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
    var onUpdate: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select the functions or roles where you'd like to receive or offer career direction.")
                .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
            
            // Marketing & Branding
            FunctionSection(
                title: "Marketing & Branding",
                functions: ["Brand Marketing", "Digital Marketing", "Social Media Operations", "Content Strategy"],
                selectedFunctions: $functions,
                onUpdate: onUpdate
            )
            
            // Product & Tech
            FunctionSection(
                title: "Product & Tech",
                functions: ["Product Management", "Product Operations", "Front-end Development", "UX / UI Design", "Product Data Analytics", "Backend Development"],
                selectedFunctions: $productTech,
                onUpdate: onUpdate
            )
            
            // Data & Analytics
            FunctionSection(
                title: "Data & Analytics",
                functions: ["Data Analyst", "Growth Analyst", "Marketing Data", "Business Intelligence", "Machine Learning Ops", "Research Analyst"],
                selectedFunctions: $dataAnalytics,
                onUpdate: onUpdate
            )
            
            // Finance & Consulting
            FunctionSection(
                title: "Finance & Consulting",
                functions: ["Investment Banking", "Equity Research", "VC / PE Analyst", "Strategy Consulting", "Corporate Finance", "Financial Planning"],
                selectedFunctions: $financeConsulting,
                onUpdate: onUpdate
            )
            
            // Operations & HR
            FunctionSection(
                title: "Operations & HR",
                functions: ["Project Management", "Business Operations", "Supply Chain", "HR / Talent Acquisition", "Training & L&D", "Organizational Development"],
                selectedFunctions: $operationsHR,
                onUpdate: onUpdate
            )
            
            // Creative & Media
            FunctionSection(
                title: "Creative & Media",
                functions: ["Copywriting", "PR & Communications", "Art Direction", "Video Editing / Motion Design", "Creative Strategy", "Advertising Production"],
                selectedFunctions: $creativeMedia,
                onUpdate: onUpdate
            )
        }
    }
}

// MARK: - Function Section
struct FunctionSection: View {
    let title: String
    let functions: [String]
    @Binding var selectedFunctions: [String: [String]]
    var onUpdate: (() -> Void)? = nil
    
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
            Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
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
                                onUpdate?()
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
                                onUpdate?()
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
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
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
                            .foregroundColor(learnIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
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
                            .foregroundColor(guideIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
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
    var onUpdate: (() -> Void)? = nil
    
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
                            onUpdate?()
                        }
                    }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            // Common skills
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(commonSkills, id: \.self) { skill in
                    if !skills.contains(where: { $0.skillName == skill }) {
                        Button(action: {
                            skills.append(SkillSelection(skillName: skill, learnIn: false, guideIn: false))
                            onUpdate?()
                        }) {
                            Text("+ \(skill)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
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
                                onUpdate?()
                            },
                            onUpdate: onUpdate
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
    var onUpdate: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(skill.skillName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Spacer()
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Learn in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        skill.learnIn.toggle()
                        onUpdate?()
                    }) {
                        Image(systemName: skill.learnIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(skill.learnIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("Guide in")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        skill.guideIn.toggle()
                        onUpdate?()
                    }) {
                        Image(systemName: skill.guideIn ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16))
                            .foregroundColor(skill.guideIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
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
    var onUpdate: (() -> Void)? = nil
    
    private let industryOptions = [
        "Technology",
        "Finance",
        "Marketing & Media",
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
                                    var updated = industries[index]
                                    updated.learnIn = isSelected
                                    industries[index] = updated
                                } else {
                                    industries.append(IndustrySelection(industryName: industry, learnIn: isSelected, guideIn: false))
                                }
                                onUpdate?()
                            }
                        ),
                        guideIn: Binding(
                            get: { industries.first(where: { $0.industryName == industry })?.guideIn ?? false },
                            set: { isSelected in
                                if let index = industries.firstIndex(where: { $0.industryName == industry }) {
                                    var updated = industries[index]
                                    updated.guideIn = isSelected
                                    industries[index] = updated
                                } else {
                                    industries.append(IndustrySelection(industryName: industry, learnIn: false, guideIn: isSelected))
                                }
                                onUpdate?()
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
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
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
                            .foregroundColor(learnIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
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
                            .foregroundColor(guideIn ? Color(red: 0.6, green: 0.4, blue: 0.2) : .gray)
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
    @State private var selfIntroduction = ""
    @State private var newHobby = "" // 用于自定义 hobby 输入
    @StateObject private var selectionHelper = SelectionHelper()
    @State private var scrollOffset: CGFloat = 0
    @State private var pickerFrame: CGRect = .zero
    
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
            
            // Hobbies
            VStack(alignment: .leading, spacing: 12) {
                Text("Hobbies & Interests")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("Select up to 6 hobbies (tap to add/remove)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                // Add custom hobby input
                HStack(spacing: 12) {
                    TextField("Add custom hobby", text: $newHobby)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocorrectionDisabled()
                    
                    Button(action: {
                        let trimmedHobby = newHobby.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedHobby.isEmpty && 
                           !selectionHelper.selectedHobbies.contains(trimmedHobby) &&
                           selectionHelper.selectedHobbies.count < 6 {
                            selectionHelper.addHobby(trimmedHobby)
                            newHobby = ""
                        }
                    }) {
                        Text("Add")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                            .cornerRadius(8)
                    }
                    .disabled(newHobby.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectionHelper.selectedHobbies.count >= 6)
                    .opacity(newHobby.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectionHelper.selectedHobbies.count >= 6 ? 0.5 : 1.0)
                }
                
                // Suggested hobbies (only show those not already selected)
                let availableSuggestions = HobbiesOptions.popularHobbies.filter { !selectionHelper.selectedHobbies.contains($0) }
                if !availableSuggestions.isEmpty {
                    Text("Suggested:")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(availableSuggestions, id: \.self) { hobby in
                            Button(action: {
                                if selectionHelper.selectedHobbies.count < 6 {
                                    selectionHelper.addHobby(hobby)
                                }
                            }) {
                                Text(hobby)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .disabled(selectionHelper.selectedHobbies.count >= 6)
                            .opacity(selectionHelper.selectedHobbies.count >= 6 ? 0.5 : 1.0)
                        }
                    }
                }
                
                // Selected hobbies
                if !selectionHelper.selectedHobbies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Selected:")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text("\(selectionHelper.selectedHobbies.count)/6")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(Array(selectionHelper.selectedHobbies).sorted(), id: \.self) { hobby in
                                HStack(spacing: 6) {
                                    Text(hobby)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    
                                    Button(action: {
                                        selectionHelper.removeHobby(hobby)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }
            
        }
        .onAppear {
            // Load existing data if available
            if let personalitySocial = profileData.personalitySocial {
                selectionHelper.selectedHobbies = Set(personalitySocial.hobbies)
                selfIntroduction = personalitySocial.selfIntroduction ?? ""
            }
        }
        .onChange(of: selectionHelper.selectedHobbies) { _ in updateProfileData() }
        .onChange(of: selfIntroduction) { _ in updateProfileData() }
    }
    
    private func updateProfileData() {
        let existingPersonality = profileData.personalitySocial
        let personalitySocial = PersonalitySocial(
            icebreakerPrompts: [],
            valuesTags: [], // 清空 values
            hobbies: Array(selectionHelper.selectedHobbies),
            preferredMeetingVibe: existingPersonality?.preferredMeetingVibe ?? .casual,
            preferredMeetingVibes: existingPersonality?.preferredMeetingVibes ?? [],
            selfIntroduction: selfIntroduction.isEmpty ? nil : selfIntroduction
        )
        profileData.personalitySocial = personalitySocial
    }
}

// MARK: - Step 6: Work & Lifestyle Photos
struct WorkAndLifestylePhotosStep: View {
    @Binding var profileData: ProfileCreationData
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedPhotoType: PhotoType = .work
    @State private var workPhotos: [Photo] = []
    @State private var lifestylePhotos: [Photo] = []
    @State private var selectedPhotoItems: [PhotosPickerItem?] = Array(repeating: nil, count: 10)
    @State private var imageDataArray: [Data?] = Array(repeating: nil, count: 10)
    @State private var captions: [String] = Array(repeating: "", count: 10)
    @State private var isUploading: [Int: Bool] = [:]
    @State private var uploadedImageURLs: [Int: String] = [:]
    @State private var currentPageIndex: Int = 0
    @State private var previousPhotoType: PhotoType = .work
    
    private struct PhotoUIState {
        var selectedItems: [PhotosPickerItem?] = Array(repeating: nil, count: 10)
        var imageData: [Data?] = Array(repeating: nil, count: 10)
        var captions: [String] = Array(repeating: "", count: 10)
        var isUploading: [Int: Bool] = [:]
        var uploadedURLs: [Int: String] = [:]
    }
    
    @State private var storedUIStates: [PhotoType: PhotoUIState] = [
        .work: PhotoUIState(),
        .lifestyle: PhotoUIState()
    ]
    
    enum PhotoType: String, CaseIterable {
        case work = "Work Photos"
        case lifestyle = "Lifestyle Photos"
    }
    
    // 获取当前类型的照片
    private var currentPhotos: [Photo] {
        selectedPhotoType == .work ? workPhotos : lifestylePhotos
    }
    
    // 计算总页面数
    private var totalPages: Int {
        let validPhotosCount = currentPhotos.filter { $0.imageUrl != nil && !($0.imageUrl?.isEmpty ?? true) }.count
        let uploadingCount = imageDataArray.enumerated().filter { $0.element != nil && uploadedImageURLs[$0.offset] == nil }.count
        let totalItems = validPhotosCount + uploadingCount
        return max(1, min(totalItems + (totalItems < 10 ? 1 : 0), 10))
    }
    
    // 判断是否显示下一张箭头
    private func shouldShowNextArrow(for index: Int) -> Bool {
        let hasImage = (uploadedImageURLs[index] != nil && !uploadedImageURLs[index]!.isEmpty) || imageDataArray[index] != nil
        let isNotLastPage = index < totalPages - 1
        let hasMoreSpace = totalPages < 10 || index < 9
        return hasImage && isNotLastPage && hasMoreSpace
    }
    
    private func saveCurrentUIState(for type: PhotoType? = nil) {
        let targetType = type ?? selectedPhotoType
        let state = PhotoUIState(
            selectedItems: selectedPhotoItems,
            imageData: imageDataArray,
            captions: captions,
            isUploading: isUploading,
            uploadedURLs: uploadedImageURLs
        )
        storedUIStates[targetType] = state
    }
    
    private func restoreUIState(for type: PhotoType) {
        if let state = storedUIStates[type] {
            selectedPhotoItems = state.selectedItems
            imageDataArray = state.imageData
            captions = state.captions
            isUploading = state.isUploading
            uploadedImageURLs = state.uploadedURLs
        } else {
            selectedPhotoItems = Array(repeating: nil, count: 10)
            imageDataArray = Array(repeating: nil, count: 10)
            captions = Array(repeating: "", count: 10)
            isUploading = [:]
            uploadedImageURLs = [:]
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Photo type selector
            Picker("Photo Type", selection: $selectedPhotoType) {
                ForEach(PhotoType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
            .onChange(of: selectedPhotoType) { newType in
                print("🔄 切换照片类型到: \(newType.rawValue)")
                saveCurrentUIState(for: previousPhotoType)
                restoreUIState(for: newType)
                // 加载新类型的数据（旧类型的数据已经在上传和编辑时自动保存了）
                loadExistingPhotos()
                currentPageIndex = 0
                previousPhotoType = newType
            }
            
            // 始终使用 TabView 显示，支持翻页
            ZStack {
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        HighlightUploadCard(
                            selectedPhotoItem: $selectedPhotoItems[index],
                            imageData: $imageDataArray[index],
                            caption: $captions[index],
                            isUploading: Binding(
                                get: { isUploading[index] ?? false },
                                set: { isUploading[index] = $0 }
                            ),
                            uploadedImageURL: Binding(
                                get: { uploadedImageURLs[index] },
                                set: { uploadedImageURLs[index] = $0 }
                            ),
                            photoType: selectedPhotoType, // 传递照片类型
                            onImageSelected: { item in
                                selectedPhotoItems[index] = item
                                loadImageData(for: index, item: item)
                            },
                            onRemove: {
                                removePhoto(at: index)
                                // 如果删除后还有图片，保持在当前页面，否则回到第一页
                                if currentPhotos.isEmpty && imageDataArray.allSatisfy({ $0 == nil }) {
                                    currentPageIndex = 0
                                } else if currentPageIndex >= totalPages - 1 {
                                    currentPageIndex = max(0, totalPages - 2)
                                }
                            },
                            onCaptionChanged: { newCaption in
                                captions[index] = newCaption
                                updateProfileData()
                            },
                            showNextArrow: shouldShowNextArrow(for: index)
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 420) // 固定高度：280 (图片) + 20 (间距) + 100 (输入框) + 20 (padding)
                
                // 右侧箭头按钮（若隐若现）
                if shouldShowNextArrow(for: currentPageIndex) {
                    HStack {
                        Spacer()
                        Button(action: {
                            // 切换到下一页
                            if currentPageIndex < totalPages - 1 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPageIndex = currentPageIndex + 1
                                }
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(16)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.2))
                                        .blur(radius: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 140) // 垂直居中在图片区域
                    }
                    .frame(height: 420)
                    .allowsHitTesting(true)
                }
            }
        }
        .onAppear {
            restoreUIState(for: selectedPhotoType)
            loadExistingPhotos()
        }
        .onChange(of: profileData.workPhotos) { _ in
            // 当 profileData.workPhotos 更新时（比如从数据库重新加载），刷新显示
            print("🔄 profileData.workPhotos 变化，重新加载...")
            loadExistingPhotos()
        }
        .onChange(of: profileData.lifestylePhotos) { _ in
            // 当 profileData.lifestylePhotos 更新时（比如从数据库重新加载），刷新显示
            print("🔄 profileData.lifestylePhotos 变化，重新加载...")
            loadExistingPhotos()
        }
        .onChange(of: imageDataArray) { _ in
            // 当图片数据加载完成时，自动上传
            for index in 0..<10 {
                if imageDataArray[index] != nil && uploadedImageURLs[index] == nil && !(isUploading[index] ?? false) {
                    uploadImage(for: index)
                }
            }
        }
        .onChange(of: uploadedImageURLs) { _ in
            // 当图片上传成功后，强制刷新视图
            let validCount = currentPhotos.filter { $0.imageUrl != nil && !($0.imageUrl?.isEmpty ?? true) }.count
            let uploadingCount = imageDataArray.enumerated().filter { $0.element != nil && uploadedImageURLs[$0.offset] == nil }.count
            let totalItems = validCount + uploadingCount
            
            print("🔄 [\(selectedPhotoType.rawValue)] uploadedImageURLs 变化，validCount: \(validCount), uploadingCount: \(uploadingCount), totalItems: \(totalItems)")
        }
        .onChange(of: workPhotos) { _ in
            print("🔄 [Work Photos] 更新，数量: \(workPhotos.count)")
        }
        .onChange(of: lifestylePhotos) { _ in
            print("🔄 [Lifestyle Photos] 更新，数量: \(lifestylePhotos.count)")
        }
    }
    
    private func loadExistingPhotos() {
        print("📥 loadExistingPhotos() 被调用，selectedPhotoType: \(selectedPhotoType.rawValue)")
        
        // 加载 Work Photos
        if let existingWorkPhotos = profileData.workPhotos {
            workPhotos = existingWorkPhotos.photos
            print("📥 加载了 \(workPhotos.count) 张 Work Photos")
        } else {
            workPhotos = []
            print("📥 没有 Work Photos 数据")
        }
        
        // 加载 Lifestyle Photos
        if let existingLifestylePhotos = profileData.lifestylePhotos {
            lifestylePhotos = existingLifestylePhotos.photos
            print("📥 加载了 \(lifestylePhotos.count) 张 Lifestyle Photos")
        } else {
            lifestylePhotos = []
            print("📥 没有 Lifestyle Photos 数据")
        }
        
        // 清空UI状态
        selectedPhotoItems = Array(repeating: nil, count: 10)
        imageDataArray = Array(repeating: nil, count: 10)
        captions = Array(repeating: "", count: 10)
        uploadedImageURLs = [:]
        
        // 根据当前选择的类型加载对应的照片
        let photos = currentPhotos
        print("📥 当前类型 [\(selectedPhotoType.rawValue)] 有 \(photos.count) 张照片")
        
        for (index, photo) in photos.enumerated() {
            if index < 10 {
                captions[index] = photo.caption ?? ""
                if let imageUrl = photo.imageUrl {
                    uploadedImageURLs[index] = imageUrl
                    print("📥 [\(selectedPhotoType.rawValue)][\(index)] 加载图片: \(imageUrl)")
                }
            }
        }
        
        // 如果有照片，设置当前页面为第一个
        if !photos.isEmpty {
            currentPageIndex = 0
        }
        
        print("📥 loadExistingPhotos() 完成，uploadedImageURLs 数量: \(uploadedImageURLs.count)")
        saveCurrentUIState()
    }
    
    private func loadImageData(for index: Int, item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            do {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        imageDataArray[index] = data
                        // 自动上传
                        uploadImage(for: index)
                        saveCurrentUIState()
                    }
                }
            } catch {
                print("❌ Failed to load image: \(error.localizedDescription)")
            }
        }
    }
    
    private func uploadImage(for index: Int) {
        guard let imageData = imageDataArray[index],
              let currentUser = authManager.currentUser else { return }
        
        isUploading[index] = true
        
        Task {
            do {
                let photoType = selectedPhotoType == .work ? "work" : "lifestyle"
                let fileName = "\(photoType)_photo_\(currentUser.id)_\(UUID().uuidString).jpg"
                let imageURL = try await supabaseService.uploadMomentImage(
                    userId: currentUser.id,
                    imageData: imageData,
                    fileName: fileName
                )
                
                await MainActor.run {
                    uploadedImageURLs[index] = imageURL
                    isUploading[index] = false
                    
                    // 根据当前类型更新对应的照片数组
                    var photos = selectedPhotoType == .work ? workPhotos : lifestylePhotos
                    
                    // 确保数组有足够的元素
                    while photos.count <= index {
                        photos.append(Photo(id: UUID().uuidString, imageUrl: nil, caption: nil))
                    }
                    
                    // 更新或创建 photo
                    let photo = Photo(
                        id: photos[index].id,
                        imageUrl: imageURL,
                        caption: captions[index].isEmpty ? nil : captions[index]
                    )
                    
                    photos[index] = photo
                    
                    // 回写到对应的数组
                    if selectedPhotoType == .work {
                        workPhotos = photos
                    } else {
                        lifestylePhotos = photos
                    }
                    
                    updateProfileData()
                    saveCurrentUIState()
                    
                    print("✅ [\(photoType)] 图片上传成功，URL: \(imageURL)")
                    print("✅ [\(photoType)] 当前 uploadedImageURLs[\(index)]: \(uploadedImageURLs[index] ?? "nil")")
                }
            } catch {
                print("❌ Failed to upload image: \(error.localizedDescription)")
                await MainActor.run {
                    isUploading[index] = false
                }
            }
        }
    }
    
    private func removePhoto(at index: Int) {
        // 根据当前类型移除对应照片
        var photos = selectedPhotoType == .work ? workPhotos : lifestylePhotos
        
        if index < photos.count {
            photos.remove(at: index)
        }
        
        // 回写到对应的数组
        if selectedPhotoType == .work {
            workPhotos = photos
        } else {
            lifestylePhotos = photos
        }
        
        // 清空对应位置的 UI 数据
        selectedPhotoItems[index] = nil
        imageDataArray[index] = nil
        captions[index] = ""
        uploadedImageURLs[index] = nil
        isUploading[index] = false
        
        updateProfileData()
        saveCurrentUIState()
    }
    
    private func updateProfileData() {
        print("💾 updateProfileData() 被调用，当前类型: \(selectedPhotoType.rawValue)")
        
        // 首先，根据当前选择的类型，将 UI 中的 captions 和 uploadedImageURLs 同步回对应的数组
        if selectedPhotoType == .work {
            // 更新 workPhotos 数组，使用当前 UI 的数据
            var updatedPhotos: [Photo] = []
            
            // 遍历 uploadedImageURLs，创建或更新 Photo 对象
            for index in 0..<10 {
                if let imageUrl = uploadedImageURLs[index], !imageUrl.isEmpty {
                    // 如果该位置有图片 URL
                    let existingId = (index < workPhotos.count) ? workPhotos[index].id : UUID().uuidString
                    let photo = Photo(
                        id: existingId,
                        imageUrl: imageUrl,
                        caption: captions[index].isEmpty ? nil : captions[index]
                    )
                    updatedPhotos.append(photo)
                    print("   💾 [Work][\(index)] 保存: URL=\(imageUrl), Caption=\(photo.caption ?? "nil")")
                }
            }
            
            workPhotos = updatedPhotos
        } else {
            // 更新 lifestylePhotos 数组，使用当前 UI 的数据
            var updatedPhotos: [Photo] = []
            
            // 遍历 uploadedImageURLs，创建或更新 Photo 对象
            for index in 0..<10 {
                if let imageUrl = uploadedImageURLs[index], !imageUrl.isEmpty {
                    // 如果该位置有图片 URL
                    let existingId = (index < lifestylePhotos.count) ? lifestylePhotos[index].id : UUID().uuidString
                    let photo = Photo(
                        id: existingId,
                        imageUrl: imageUrl,
                        caption: captions[index].isEmpty ? nil : captions[index]
                    )
                    updatedPhotos.append(photo)
                    print("   💾 [Lifestyle][\(index)] 保存: URL=\(imageUrl), Caption=\(photo.caption ?? "nil")")
                }
            }
            
            lifestylePhotos = updatedPhotos
        }
        
        // 最后，保存到 profileData
        profileData.workPhotos = workPhotos.isEmpty ? nil : PhotoCollection(photos: workPhotos)
        profileData.lifestylePhotos = lifestylePhotos.isEmpty ? nil : PhotoCollection(photos: lifestylePhotos)
        
        print("💾 最终 Work Photos 数量: \(workPhotos.count)")
        print("💾 最终 Lifestyle Photos 数量: \(lifestylePhotos.count)")
    }
}

// MARK: - Highlight Upload Card
struct HighlightUploadCard: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var imageData: Data?
    @Binding var caption: String
    @Binding var isUploading: Bool
    @Binding var uploadedImageURL: String?
    let photoType: WorkAndLifestylePhotosStep.PhotoType // 新增：照片类型
    let onImageSelected: (PhotosPickerItem) -> Void
    let onRemove: () -> Void
    let onCaptionChanged: (String) -> Void
    let showNextArrow: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 图片区域 - 更大的尺寸
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    .frame(height: 280)
                
                // 优先显示本地选择的图片（立即显示，不等待上传）
                if let data = imageData, let uiImage = UIImage(data: data) {
                    ZStack {
                        // 显示本地图片
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 280)
                            .clipped()
                            .cornerRadius(16)
                            .overlay(alignment: .bottom) {
                                deleteButton
                            }
                        
                        // 如果正在上传，显示上传进度覆盖层
                        if isUploading {
                            Color.black.opacity(0.3)
                                .cornerRadius(16)
                            
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                    }
                } else if let imageURL = uploadedImageURL, !imageURL.isEmpty {
                    // 显示已上传的图片（当本地图片数据被清除后）
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 280)
                                .clipped()
                                .cornerRadius(16)
                                .overlay(alignment: .bottom) {
                                    deleteButton
                                }
                        case .failure:
                            Image(systemName: "photo.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // 空状态 - 显示图标和描述文案
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        
                        VStack(spacing: 8) {
                            Text(photoType == .work ? "Show your professional side." : "Add a glimpse of your everyday life.")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .multilineTextAlignment(.center)
                            
                            Text(photoType == .work 
                                ? "Upload a photo that represents you at work — in the office, at a project, or doing what you love professionally."
                                : "A casual or candid photo that shows your personality outside of work — coffee moments, hobbies, or travels.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.15).opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 20)
                }
                
                // 图片选择器覆盖层 - 只在图片区域，不延伸到文本框
                if uploadedImageURL == nil && imageData == nil {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Color.clear
                            .frame(height: 280)
                            .contentShape(Rectangle())
                    }
                    .onChange(of: selectedPhotoItem) { newItem in
                        if let item = newItem {
                            onImageSelected(item)
                        }
                    }
                }
            }
            
            // 文字输入框 - 更大的尺寸
            TextField("Write something", text: $caption, axis: .vertical)
                .font(.system(size: 16))
                .padding(16)
                .background(Color(red: 0.98, green: 0.97, blue: 0.95))
                .cornerRadius(12)
                .frame(minHeight: 100)
                .lineLimit(4...8)
                .onChange(of: caption) { newValue in
                    onCaptionChanged(newValue)
                }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        if uploadedImageURL != nil || imageData != nil {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Step 7: Privacy & Trust
struct PrivacyTrustStep: View {
    @Binding var profileData: ProfileCreationData
    @State private var companyVisibility = VisibilityLevel.public_
    @State private var emailVisibility = VisibilityLevel.private_
    @State private var phoneNumberVisibility = VisibilityLevel.private_
    @State private var locationVisibility = VisibilityLevel.public_
    @State private var skillsVisibility = VisibilityLevel.public_
    @State private var interestsVisibility = VisibilityLevel.public_
    @State private var timeslotVisibility = VisibilityLevel.connectionsOnly
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
                    
                    PrivacyToggleRow(
                        title: "Timeslot",
                        visibility: $timeslotVisibility
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
                timeslotVisibility = privacyTrust.visibilitySettings.timeslot
                dataSharingConsent = privacyTrust.dataSharingConsent
            }
        }
        .onChange(of: companyVisibility) { _ in updateProfileData() }
        .onChange(of: emailVisibility) { _ in updateProfileData() }
        .onChange(of: phoneNumberVisibility) { _ in updateProfileData() }
        .onChange(of: locationVisibility) { _ in updateProfileData() }
        .onChange(of: skillsVisibility) { _ in updateProfileData() }
        .onChange(of: interestsVisibility) { _ in updateProfileData() }
        .onChange(of: timeslotVisibility) { _ in updateProfileData() }
        .onChange(of: dataSharingConsent) { _ in updateProfileData() }
    }
    
    private func updateProfileData() {
        let visibilitySettings = VisibilitySettings(
            company: companyVisibility,
            email: emailVisibility,
            phoneNumber: phoneNumberVisibility,
            location: locationVisibility,
            skills: skillsVisibility,
            interests: interestsVisibility,
            timeslot: timeslotVisibility
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
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Picker("Visibility", selection: $visibility) {
                ForEach(VisibilityLevel.allCases, id: \.self) { level in
                    Text(level.displayName)
                        .font(.system(size: 14))
                        .tag(level)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(minWidth: 140)
            .fixedSize()
            .onTapGesture {
                // Prevent any unwanted scroll behavior when picker is tapped
            }
        }
        .padding(.horizontal, 12)
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
    
    private func formatDate(year: Int, month: Int?) -> String {
        if let month = month {
            return "\(YearOptions.shortMonthName(for: month)) \(String(year))"
        }
        return String(year)
    }
    
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
                    Text(formatDate(year: education.startYear, month: education.startMonth))
                    if let endYear = education.endYear {
                        Text("- \(formatDate(year: endYear, month: education.endMonth))")
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
    
    private func formatDate(year: Int, month: Int?) -> String {
        if let month = month {
            return "\(YearOptions.shortMonthName(for: month)) \(String(year))"
        }
        return String(year)
    }
    
    private var isValidWorkExperience: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard workExperience.startYear <= currentYear else { return false }
        if let endYear = workExperience.endYear, workExperience.startYear > endYear {
            return false
        }
        return true
    }
    
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
                    Text(formatDate(year: workExperience.startYear, month: workExperience.startMonth))
                    if let endYear = workExperience.endYear {
                        Text("- \(formatDate(year: endYear, month: workExperience.endMonth))")
                    } else {
                        Text("- Present")
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
                
                if !isValidWorkExperience {
                    Text("Invalid year settings")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
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
    @State private var startMonth: Int? = YearOptions.currentMonth
    @State private var endYear: Int? = YearOptions.currentYear
    @State private var endMonth: Int? = YearOptions.currentMonth
    @State private var position = ""
    @State private var isPresent = false
    @State private var skillInput = ""
    @State private var addedSkills: [String] = []
    @State private var responsibilities = ""
    @State private var validationError: String?
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var isValidYears: Bool {
        guard startYear <= currentYear else {
            validationError = "Start year cannot be in the future."
            return false
        }
        
        if let endYear = endYear, !isPresent {
            if startYear > endYear {
                validationError = "Start year must be before or equal to end year."
                return false
            }
            // 如果年份相同，检查月份
            if startYear == endYear {
                let startM = startMonth ?? 1
                let endM = endMonth ?? 12
                if startM > endM {
                    validationError = "Start month must be before or equal to end month when years are the same."
                    return false
                }
            }
        }
        
        validationError = nil
        return true
    }
    
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
                
                // Key Skills
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Skills")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    HStack(spacing: 10) {
                        TextField("Add a skill", text: $skillInput, onCommit: addSkill)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        Button("Add") {
                            addSkill()
                        }
                        .disabled(skillInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(skillInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.4, green: 0.2, blue: 0.1))
                        .cornerRadius(12)
                    }
                    
                    if !addedSkills.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                            ForEach(addedSkills, id: \.self) { skill in
                                HStack(spacing: 6) {
                                    Text(skill)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    Button(action: { removeSkill(skill) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // Role Highlights
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role Highlights")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $responsibilities)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        
                        if responsibilities.isEmpty {
                            Text("Summarize key responsibilities or achievements...")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        }
                    }
                }
                
                // Start Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Date *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    HStack(spacing: 8) {
                        // Start Year
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Year")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Picker("Start Year", selection: $startYear) {
                                ForEach(YearOptions.workExperienceYears, id: \.self) { year in
                                    Text(verbatim: String(year))
                                        .tag(year)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Start Month
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Month")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Picker("Start Month", selection: Binding(
                                get: { startMonth ?? YearOptions.currentMonth },
                                set: { startMonth = $0 }
                            )) {
                                Text("Not specified")
                                    .tag(Int?.none)
                                ForEach(YearOptions.months, id: \.self) { month in
                                    Text(YearOptions.shortMonthName(for: month))
                                        .tag(Int?.some(month))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // End Date or Present
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("End Date")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Spacer()
                        
                        Toggle("Currently working", isOn: $isPresent)
                            .font(.system(size: 14))
                    }
                    .onChange(of: isPresent) { newValue in
                        if newValue {
                            endYear = nil
                            endMonth = nil
                        } else {
                            if endYear == nil {
                                endYear = YearOptions.currentYear
                            }
                            if endMonth == nil {
                                endMonth = YearOptions.currentMonth
                            }
                        }
                    }
                    
                    if !isPresent {
                        HStack(spacing: 8) {
                            // End Year
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Year")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Picker("End Year", selection: Binding(
                                    get: { endYear ?? YearOptions.currentYear },
                                    set: { endYear = $0 }
                                )) {
                                    ForEach(YearOptions.workExperienceYears, id: \.self) { year in
                                        Text(verbatim: String(year))
                                            .tag(year)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // End Month
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Month")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Picker("End Month", selection: Binding(
                                    get: { endMonth ?? YearOptions.currentMonth },
                                    set: { endMonth = $0 }
                                )) {
                                    Text("Not specified").tag(Int?.none)
                                    ForEach(YearOptions.months, id: \.self) { month in
                                        Text(YearOptions.shortMonthName(for: month)).tag(Int?.some(month))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if let validationError {
                    Text(validationError)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
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
                        guard isValidYears else { return }
                        
                        let workExperience = WorkExperience(
                            companyName: companyName,
                            startYear: startYear,
                            startMonth: startMonth,
                            endYear: isPresent ? nil : endYear,
                            endMonth: isPresent ? nil : endMonth,
                            position: position.isEmpty ? nil : position,
                            highlightedSkills: addedSkills,
                            responsibilities: responsibilities.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : responsibilities.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(workExperience)
                        dismiss()
                    }
                    .disabled(companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addSkill() {
        let trimmed = skillInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !addedSkills.contains(trimmed) {
            addedSkills.append(trimmed)
        }
        skillInput = ""
    }
    
    private func removeSkill(_ skill: String) {
        addedSkills.removeAll { $0 == skill }
    }
}

// MARK: - Add Education View
struct AddEducationView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Education) -> Void
    
    @State private var schoolName = ""
    @State private var startYear = YearOptions.currentYear
    @State private var startMonth: Int? = YearOptions.currentMonth
    @State private var endYear: Int? = YearOptions.currentYear
    @State private var endMonth: Int? = YearOptions.currentMonth
    @State private var degree = DegreeType.bachelor
    @State private var fieldOfStudy = ""
    @State private var isPresent = false
    @State private var validationError: String?
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var isValidYears: Bool {
        guard startYear <= currentYear else {
            validationError = "Start year cannot be in the future."
            return false
        }
        
        if let endYear = endYear, !isPresent {
            if startYear > endYear {
                validationError = "Start year must be before or equal to end year."
                return false
            }
            // 如果年份相同，检查月份
            if startYear == endYear {
                let startM = startMonth ?? 1
                let endM = endMonth ?? 12
                if startM > endM {
                    validationError = "Start month must be before or equal to end month when years are the same."
                    return false
                }
            }
        }
        
        validationError = nil
        return true
    }
    
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
                
                // Start Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Date *")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    HStack(spacing: 8) {
                        // Start Year
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Year")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Picker("Start Year", selection: $startYear) {
                                ForEach(YearOptions.years, id: \.self) { year in
                                    Text(verbatim: String(year))
                                        .tag(year)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Start Month
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Month")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Picker("Start Month", selection: Binding(
                                get: { startMonth ?? YearOptions.currentMonth },
                                set: { startMonth = $0 }
                            )) {
                                Text("Not specified")
                                    .tag(Int?.none)
                                ForEach(YearOptions.months, id: \.self) { month in
                                    Text(YearOptions.shortMonthName(for: month))
                                        .tag(Int?.some(month))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // End Date or Present
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("End Date")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        
                        Spacer()
                        
                        Toggle("Currently studying", isOn: $isPresent)
                            .font(.system(size: 14))
                    }
                    .onChange(of: isPresent) { newValue in
                        if newValue {
                            endYear = nil
                            endMonth = nil
                        } else {
                            if endYear == nil {
                                endYear = YearOptions.currentYear
                            }
                            if endMonth == nil {
                                endMonth = YearOptions.currentMonth
                            }
                        }
                    }
                    
                    if !isPresent {
                        HStack(spacing: 8) {
                            // End Year
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Year")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Picker("End Year", selection: Binding(
                                    get: { endYear ?? YearOptions.currentYear },
                                    set: { endYear = $0 }
                                )) {
                                    ForEach(YearOptions.years, id: \.self) { year in
                                        Text(verbatim: String(year))
                                            .tag(year)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // End Month
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Month")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                Picker("End Month", selection: Binding(
                                    get: { endMonth ?? YearOptions.currentMonth },
                                    set: { endMonth = $0 }
                                )) {
                                    Text("Not specified").tag(Int?.none)
                                    ForEach(YearOptions.months, id: \.self) { month in
                                        Text(YearOptions.shortMonthName(for: month)).tag(Int?.some(month))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
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
                
                if let validationError {
                    Text(validationError)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
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
                        guard isValidYears else { return }
                        
                        let education = Education(
                            schoolName: schoolName,
                            startYear: startYear,
                            startMonth: startMonth,
                            endYear: isPresent ? nil : endYear,
                            endMonth: isPresent ? nil : endMonth,
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

// MARK: - Preference Keys for Scroll Detection
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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

