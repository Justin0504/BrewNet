import SwiftUI

// MARK: - BrewNet Matches View (New implementation with BrewNetProfile)
struct BrewNetMatchesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var profiles: [BrewNetProfile] = []
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle = 0.0
    @State private var showingMatchAlert = false
    @State private var matchedProfile: BrewNetProfile?
    @State private var likedProfiles: [BrewNetProfile] = []
    @State private var passedProfiles: [BrewNetProfile] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMoreProfiles = true
    @State private var isConnection: Bool = false // Whether the viewer is connected to profiles
    @State private var errorMessage: String?
    @State private var totalFetched = 0
    @State private var totalFiltered = 0
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Loading indicator
                if isLoading {
                    ProgressView()
                        .frame(height: screenHeight * 0.6)
                }
                // Cards Stack
                else if currentIndex < profiles.count {
                    ZStack {
                        // Next card (background)
                        if currentIndex + 1 < profiles.count {
                            UserProfileCardView(
                                profile: profiles[currentIndex + 1],
                                dragOffset: .constant(.zero),
                                rotationAngle: .constant(0),
                                onSwipe: { _ in },
                                isConnection: isConnection
                            )
                            .scaleEffect(0.95)
                            .offset(y: 10)
                        }
                        
                        // Current card (foreground)
                        UserProfileCardView(
                            profile: profiles[currentIndex],
                            dragOffset: $dragOffset,
                            rotationAngle: $rotationAngle,
                            onSwipe: handleSwipe,
                            isConnection: isConnection
                        )
                    }
                    .frame(height: screenHeight * 0.8)
                    .padding(.top, 50) // 添加顶部padding避免和状态栏重叠
                } else {
                    // No more profiles
                    noMoreProfilesView
                }
                
                // Loading more indicator
                if isLoadingMore {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading more profiles...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 20)
                }
                
                Spacer()
            }
            
            // Error message
            if let errorMessage = errorMessage {
                VStack {
                    Spacer()
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                }
            }
            
            // Action Buttons - 保持在卡片上层（只在有卡片时显示）
            if !isLoading && currentIndex < profiles.count {
                VStack {
                    Spacer()
                    actionButtonsView
                        .padding(.bottom, 40) // 放在底部，距离底部一点距离
                }
            }
        }
        .onAppear {
            loadProfiles()
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
            Button("Keep Swiping") {
                showingMatchAlert = false
            }
            Button("View Match") {
                // Navigate to match details
                showingMatchAlert = false
            }
        } message: {
            if let profile = matchedProfile {
                Text("You and \(profile.coreIdentity.name) liked each other!")
            }
        }
    }
    
    private var noMoreProfilesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text(hasMoreProfiles ? "Loading More..." : "No More Profiles")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            if hasMoreProfiles {
                Text("You've seen \(profiles.count) profiles.\nLoading more from database...")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            } else {
                Text("You've seen all available profiles!\n\(profiles.count) profiles loaded.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            if totalFiltered > 0 {
                Text("Note: \(totalFiltered) profiles were filtered due to incomplete data")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if hasMoreProfiles {
                Button("Load More") {
                    loadMoreProfiles()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                .cornerRadius(25)
            } else {
                Button("Refresh") {
                    refreshProfiles()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                .cornerRadius(25)
            }
        }
        .padding(40)
        .frame(height: screenHeight * 0.6)
        .onAppear {
            // 自动加载更多（如果还有数据）
            if hasMoreProfiles && !isLoadingMore {
                loadMoreProfiles()
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 40) {
            // Pass button
            Button(action: {
                swipeLeft()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .disabled(currentIndex >= profiles.count)
            
            // Like button
            Button(action: {
                swipeRight()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                }
            }
            .disabled(currentIndex >= profiles.count)
        }
    }
    
    private func handleSwipe(_ direction: SwipeDirection) {
        switch direction {
        case .left:
            passProfile()
        case .right:
            likeProfile()
        case .none:
            break
        }
    }
    
    private func swipeLeft() {
        withAnimation(.spring()) {
            dragOffset = CGSize(width: -screenWidth, height: 0)
            rotationAngle = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            passProfile()
        }
    }
    
    private func swipeRight() {
        withAnimation(.spring()) {
            dragOffset = CGSize(width: screenWidth, height: 0)
            rotationAngle = 15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            likeProfile()
        }
    }
    
    private func passProfile() {
        if currentIndex < profiles.count {
            let profile = profiles[currentIndex]
            passedProfiles.append(profile)
            
            // TODO: Send pass action to backend
            print("Passed profile: \(profile.id)")
            
            moveToNextProfile()
        }
    }
    
    private func likeProfile() {
        if currentIndex < profiles.count {
            let profile = profiles[currentIndex]
            likedProfiles.append(profile)
            
            // TODO: Send like action to backend
            print("Liked profile: \(profile.id)")
            
            // Simulate match (random chance)
            if Bool.random() {
                matchedProfile = profile
                showingMatchAlert = true
                
                // Add to matched profiles if it's a match
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserMatched"),
                    object: nil,
                    userInfo: ["profile": profile]
                )
            }
            
            moveToNextProfile()
        }
    }
    
    private func moveToNextProfile() {
        currentIndex += 1
        dragOffset = .zero
        rotationAngle = 0
    }
    
    private func loadProfiles() {
        isLoading = true
        errorMessage = nil
        currentIndex = 0
        profiles.removeAll()
        totalFetched = 0
        totalFiltered = 0
        
        Task {
            await loadProfilesBatch(offset: 0, limit: 200, isInitial: true)
        }
    }
    
    private func loadMoreProfiles() {
        guard !isLoadingMore && hasMoreProfiles else { return }
        
        isLoadingMore = true
        
        Task {
            await loadProfilesBatch(offset: profiles.count, limit: 200, isInitial: false)
        }
    }
    
    private func loadProfilesBatch(offset: Int, limit: Int, isInitial: Bool) async {
        do {
            // Get current user ID
            guard let currentUser = authManager.currentUser else {
                await MainActor.run {
                    errorMessage = "Please log in to view profiles"
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }
            
            // Load actual profiles from Supabase with offset and limit
            let (supabaseProfiles, totalInBatch, filteredCount) = try await supabaseService.getRecommendedProfiles(
                userId: currentUser.id,
                limit: limit,
                offset: offset
            )
            
            // Convert SupabaseProfile to BrewNetProfile
            let brewNetProfiles = supabaseProfiles.map { $0.toBrewNetProfile() }
            
            await MainActor.run {
                if isInitial {
                    profiles = brewNetProfiles
                    isLoading = false
                    print("✅ Initially loaded \(brewNetProfiles.count) profiles from Supabase")
                } else {
                    profiles.append(contentsOf: brewNetProfiles)
                    isLoadingMore = false
                    print("✅ Loaded \(brewNetProfiles.count) more profiles (total: \(profiles.count))")
                }
                
                totalFetched += totalInBatch
                totalFiltered += filteredCount
                
                // 如果返回的数量少于请求的数量，说明没有更多了
                if supabaseProfiles.count < limit {
                    hasMoreProfiles = false
                    print("ℹ️ No more profiles available. Total loaded: \(profiles.count), Filtered: \(totalFiltered)")
                } else {
                    hasMoreProfiles = true
                }
                
                // 如果当前没有卡片显示，确保从第一条开始
                if currentIndex >= profiles.count && !profiles.isEmpty {
                    currentIndex = 0
                }
            }
            
        } catch {
            print("❌ Failed to load profiles: \(error.localizedDescription)")
            await MainActor.run {
                if isInitial {
                    errorMessage = "Failed to load profiles: \(error.localizedDescription)"
                    isLoading = false
                } else {
                    isLoadingMore = false
                }
            }
        }
    }
    
    private func refreshProfiles() {
        currentIndex = 0
        hasMoreProfiles = true
        likedProfiles.removeAll()
        passedProfiles.removeAll()
        loadProfiles()
    }
    
    // MARK: - Sample Data
    private func createSampleBrewNetProfiles() -> [BrewNetProfile] {
        let now = ISO8601DateFormatter().string(from: Date())
        
        // Sample Profile 1 - Full profile
        let profile1 = BrewNetProfile(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: "Sarah Chen",
                email: "sarah@example.com",
                phoneNumber: nil,
                profileImage: nil,
                bio: "Passionate Product Manager bridging design and data",
                pronouns: "She/Her",
                location: "San Francisco, CA",
                personalWebsite: "https://sarahchen.com",
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: "America/Los_Angeles",
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    monday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    tuesday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                )
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: "Google",
                jobTitle: "Product Designer",
                industry: "Technology (Software, Data, AI, IT)",
                experienceLevel: .senior,
                education: "Stanford University · M.S. in Human-Computer Interaction",
                yearsOfExperience: 8.5,
                careerStage: .manager,
                skills: ["Product Strategy", "User Research", "UX Design", "Data Analysis", "Agile"],
                certifications: [],
                languagesSpoken: ["English", "Mandarin"],
                workExperiences: [
                    WorkExperience(
                        companyName: "Google",
                        startYear: 2021,
                        endYear: nil,
                        position: "Senior Product Designer"
                    ),
                    WorkExperience(
                        companyName: "Adobe",
                        startYear: 2020,
                        endYear: 2021,
                        position: "Product Designer"
                    ),
                    WorkExperience(
                        companyName: "StartupCo",
                        startYear: 2018,
                        endYear: 2020,
                        position: "UX Designer"
                    )
                ]
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .learnGrow,
                selectedSubIntentions: [.careerDirection, .skillDevelopment],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .virtual,
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    monday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    tuesday: DayTimeslots(morning: false, noon: true, afternoon: false, evening: false, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: true, evening: false, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: false, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                ),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: ["Curious", "Empathetic", "Collaborative"],
                hobbies: ["Coffee Culture", "Photography", "Hiking"],
                preferredMeetingVibe: .reflective,
                selfIntroduction: "I love bridging design and data to solve real-world problems. When I'm not designing products, you'll find me exploring coffee shops or capturing moments with my camera."
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .verifiedProfessional,
                dataSharingConsent: true,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
        
        // Sample Profile 2 - Minimal profile
        let profile2 = BrewNetProfile(
            id: UUID().uuidString,
            userId: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            coreIdentity: CoreIdentity(
                name: "Mike Rodriguez",
                email: "mike@example.com",
                phoneNumber: nil,
                profileImage: nil,
                bio: "Full-stack developer building the future",
                pronouns: "He/Him",
                location: "New York, NY",
                personalWebsite: nil,
                githubUrl: nil,
                linkedinUrl: nil,
                timeZone: "America/New_York",
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    monday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    tuesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                )
            ),
            professionalBackground: ProfessionalBackground(
                currentCompany: "StartupXYZ",
                jobTitle: "Software Engineer",
                industry: "Technology (Software, Data, AI, IT)",
                experienceLevel: .mid,
                education: "MIT · B.S. in Computer Science",
                yearsOfExperience: 5.0,
                careerStage: .midLevel,
                skills: ["iOS Development", "Swift", "React Native", "Backend"],
                certifications: [],
                languagesSpoken: ["English", "Spanish"],
                workExperiences: [
                    WorkExperience(
                        companyName: "StartupXYZ",
                        startYear: 2020,
                        endYear: nil,
                        position: "Software Engineer"
                    ),
                    WorkExperience(
                        companyName: "TechCorp",
                        startYear: 2019,
                        endYear: 2020,
                        position: "Junior Developer"
                    )
                ]
            ),
            networkingIntention: NetworkingIntention(
                selectedIntention: .learnGrow,
                selectedSubIntentions: [.careerDirection, .skillDevelopment],
                careerDirection: nil,
                skillDevelopment: nil,
                industryTransition: nil
            ),
            networkingPreferences: NetworkingPreferences(
                preferredChatFormat: .either,
                availableTimeslot: AvailableTimeslot(
                    sunday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    monday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    tuesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    wednesday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    thursday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    friday: DayTimeslots(morning: false, noon: false, afternoon: false, evening: true, night: false),
                    saturday: DayTimeslots(morning: true, noon: false, afternoon: false, evening: false, night: false)
                ),
                preferredChatDuration: nil
            ),
            personalitySocial: PersonalitySocial(
                icebreakerPrompts: [],
                valuesTags: ["Innovative", "Passionate"],
                hobbies: ["Guitar", "Coding Side Projects"],
                preferredMeetingVibe: .casual,
                selfIntroduction: "Passionate about mobile apps and building great user experiences."
            ),
            privacyTrust: PrivacyTrust(
                visibilitySettings: VisibilitySettings.createDefault(),
                verifiedStatus: .verifiedProfessional,
                dataSharingConsent: true,
                reportPreferences: ReportPreferences(allowReports: true, reportCategories: [])
            )
        )
        
        return [profile1, profile2]
    }
}

// MARK: - Preview
struct BrewNetMatchesView_Previews: PreviewProvider {
    static var previews: some View {
        BrewNetMatchesView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

