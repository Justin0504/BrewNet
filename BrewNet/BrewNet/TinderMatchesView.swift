import SwiftUI

struct TinderMatchesView: View {
    @State private var profiles: [UserProfile] = sampleProfiles
    @State private var currentIndex = 0
    @State private var dragOffset = CGSize.zero
    @State private var rotationAngle = 0.0
    @State private var showingMatchAlert = false
    @State private var matchedProfile: UserProfile?
    @State private var likedProfiles: [UserProfile] = []
    @State private var passedProfiles: [UserProfile] = []
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Cards Stack
                ZStack {
                    if currentIndex < profiles.count {
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
                    } else {
                        // No more profiles
                        noMoreProfilesView
                    }
                }
                .frame(height: screenHeight * 0.8)
                
                // Action Buttons
                actionButtonsView
            }
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
                Text("You and \(profile.name) liked each other!")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Menu button
            Button(action: {
                // Menu action
            }) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            Spacer()
            
            // Title and counter
            VStack(spacing: 4) {
                Text("Daily Recommendations")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text("\(currentIndex + 1)/\(profiles.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Settings button
            Button(action: {
                // Settings action
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var noMoreProfilesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text("No More Profiles")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("You've seen all available profiles!\nCheck back later for new recommendations.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
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
                
                // Add to matched profiles if it's a match
                // In a real app, this would be handled by a data manager
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
    
    private func refreshProfiles() {
        currentIndex = 0
        profiles = sampleProfiles.shuffled()
        likedProfiles.removeAll()
        passedProfiles.removeAll()
    }
}

// MARK: - Preview
struct TinderMatchesView_Previews: PreviewProvider {
    static var previews: some View {
        TinderMatchesView()
    }
}
