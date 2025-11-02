import SwiftUI

// MARK: - Category Recommendations View
struct CategoryRecommendationsView: View {
    let category: NetworkingIntentionType?
    let categoryName: String?
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var profiles: [UserProfile] = []
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle = 0.0
    @State private var showingMatchAlert = false
    @State private var matchedProfile: UserProfile?
    @State private var likedProfiles: [UserProfile] = []
    @State private var passedProfiles: [UserProfile] = []
    @State private var isLoading = true
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    init(category: NetworkingIntentionType) {
        self.category = category
        self.categoryName = nil
    }
    
    init(categoryName: String) {
        self.category = nil
        self.categoryName = categoryName
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                if isLoading {
                    // Loading state
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                            .scaleEffect(1.2)
                        Text("Loading recommendations...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    }
                } else if currentIndex < profiles.count {
                    // Cards Stack
                    ZStack {
                        // Next card (background)
                        if currentIndex + 1 < profiles.count {
                            ProfileCardView(
                                profile: profiles[currentIndex + 1],
                                dragOffset: .constant(.zero),
                                rotationAngle: .constant(0),
                                onSwipe: { _ in }
                            )
                            .scaleEffect(0.95)
                            .offset(y: 10)
                        }
                        
                        // Current card (foreground)
                        ProfileCardView(
                            profile: profiles[currentIndex],
                            dragOffset: $dragOffset,
                            rotationAngle: $rotationAngle,
                            onSwipe: handleSwipe
                        )
                    }
                    .frame(height: screenHeight * 0.8)
                    
                    // Action Buttons
                    actionButtonsView
                } else {
                    // No more profiles
                    noMoreProfilesView
                }
            }
        }
        .alert("It's a Match! 🎉", isPresented: $showingMatchAlert) {
            Button("Keep Swiping") {
                showingMatchAlert = false
            }
            Button("View Match") {
                showingMatchAlert = false
            }
        } message: {
            if let profile = matchedProfile {
                Text("You and \(profile.name) liked each other!")
            }
        }
        .onAppear {
            loadRecommendations()
        }
    }
    
    private var headerView: some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            Spacer()
            
            // Title and counter
            VStack(spacing: 4) {
                Text(displayTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                if !profiles.isEmpty {
                    Text("\(min(currentIndex + 1, profiles.count))/\(profiles.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 20, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var noMoreProfilesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text("No More Profiles")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("You've seen all available profiles in this category!\nCheck back later for new recommendations.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Back to Explore") {
                dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color(red: 0.4, green: 0.2, blue: 0.1))
            .cornerRadius(25)
        }
        .padding(40)
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
        .padding(.bottom, 40)
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
            moveToNextProfile()
        }
    }
    
    private func likeProfile() {
        if currentIndex < profiles.count {
            let profile = profiles[currentIndex]
            likedProfiles.append(profile)
            
            // Simulate match (random chance)
            if Bool.random() {
                matchedProfile = profile
                showingMatchAlert = true
                
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
    
    // MARK: - Computed Properties
    private var displayTitle: String {
        if let category = category {
            return category.displayName
        } else if let categoryName = categoryName {
            return categoryName
        }
        return "Recommendations"
    }
    
    // MARK: - Load Recommendations
    private func loadRecommendations() {
        isLoading = true
        
        guard let currentUser = authManager.currentUser else {
            // Fallback to sample profiles if no user
            self.profiles = sampleProfiles.shuffled()
            self.isLoading = false
            return
        }
        
        Task {
            do {
                // Try to fetch profiles from Supabase
                let supabaseProfiles = try await supabaseService.getRecommendedProfiles(userId: currentUser.id, limit: 50)
                
                // Filter profiles by the selected category (intention) if applicable
                let filteredProfiles: [SupabaseProfile]
                if let category = category {
                    // Filter by networking intention
                    filteredProfiles = supabaseProfiles.filter { profile in
                        profile.networkingIntention.selectedIntention == category
                    }
                } else {
                    // For "Out of Orbit" or other special categories, show all profiles (or random selection)
                    filteredProfiles = supabaseProfiles.shuffled()
                }
                
                // Convert SupabaseProfile to UserProfile
                var userProfiles: [UserProfile] = Array(filteredProfiles.prefix(20)).map { supabaseProfile in
                    let coreIdentity = supabaseProfile.coreIdentity
                    let professional = supabaseProfile.professionalBackground
                    
                    return UserProfile(
                        name: coreIdentity.name,
                        age: 0, // Age not stored in BrewNetProfile
                        company: professional.currentCompany ?? "Unknown",
                        jobTitle: professional.jobTitle ?? "Professional",
                        skills: professional.skills,
                        bio: coreIdentity.bio ?? "No bio available",
                        imageName: "profile\(Int.random(in: 1...5))",
                        location: coreIdentity.location ?? "Unknown",
                        education: professional.education ?? "Not specified",
                        interests: supabaseProfile.personalitySocial.hobbies
                    )
                }
                
                // If no profiles found with this intention, use sample profiles as fallback
                if userProfiles.isEmpty {
                    userProfiles = sampleProfiles.shuffled()
                }
                
                await MainActor.run {
                    self.profiles = userProfiles
                    self.isLoading = false
                }
            } catch {
                print("❌ Failed to load recommendations: \(error)")
                // Fallback to sample profiles on error
                await MainActor.run {
                    self.profiles = sampleProfiles.shuffled()
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview
struct CategoryRecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CategoryRecommendationsView(category: .learnGrow)
                .environmentObject(AuthManager())
                .environmentObject(SupabaseService.shared)
            
            CategoryRecommendationsView(categoryName: "Out of Orbit")
                .environmentObject(AuthManager())
                .environmentObject(SupabaseService.shared)
        }
    }
}

