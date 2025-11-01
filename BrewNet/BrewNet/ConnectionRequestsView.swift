import SwiftUI

// MARK: - Connection Requests View
struct ConnectionRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var requests: [ConnectionRequest] = []
    @State private var currentIndex = 0
    @State private var actionAnimation: Bool = false
    @State private var isLoading = true
    @State private var dragOffset: CGSize = .zero
    @State private var rotationAngle: Double = 0.0
    @Environment(\.dismiss) var dismiss
    
    private var themeBrown: Color { Color(red: 0.4, green: 0.2, blue: 0.1) }
    private var themeBrownLight: Color { Color(red: 0.6, green: 0.4, blue: 0.2) }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                topBarView()
                
                // Main Content
                if isLoading {
                    loadingView()
                } else if currentIndex < requests.count {
                    // Profile Card
                    profileCardView()
                } else {
                    // No More Requests
                    noMoreRequestsView()
                }
                
                Spacer()
                
                // Bottom Action Area
                if currentIndex < requests.count && !isLoading && abs(dragOffset.width) > 10 {
                    bottomActionArea()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadConnectionRequests()
        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder
    private func topBarView() -> some View {
        HStack {
            // Title with Icon (centered, no back button)
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.0)) // Orange color
                
                Text("Connection Requests (\(requests.count))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Loading View
    @ViewBuilder
    private func loadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                .scaleEffect(1.2)
            
            Text("Loading connection requests...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Profile Card
    @ViewBuilder
    private func profileCardView() -> some View {
        if currentIndex >= requests.count {
            Text("No request available")
                .foregroundColor(.gray)
        } else {
            let request = requests[currentIndex]
            let profile = request.requesterProfile
            
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Card
                    ZStack {
                        // Background with gradient
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeBrownLight,
                                        themeBrown.opacity(0.9)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                // Optional background image overlay (blurred)
                                Group {
                                    if profile.backgroundImage != nil {
                                        // In a real app, load the image
                                        EmptyView()
                                    }
                                }
                            )
                            .frame(height: 350)
                        
                        VStack(spacing: 0) {
                            // Featured Professional Tag
                            if request.isFeatured {
                                HStack {
                                    Spacer()
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                        
                                        Text("Featured Professional")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(themeBrown)
                                    .cornerRadius(12)
                                    .padding(.top, 16)
                                    .padding(.trailing, 16)
                                }
                            }
                            
                            Spacer()
                            
                            // Profile Photo
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 120, height: 120)
                                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeBrownLight)
                            }
                            .padding(.bottom, 20)
                            
                            // Name and Job Title
                            VStack(spacing: 8) {
                                Text(profile.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(profile.jobTitle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                // Company and Location
                                HStack(spacing: 16) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "building.2")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text(profile.company)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "location")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.9))
                                        Text(profile.location)
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                            
                            // Reason for Interest
                            if let reason = request.reasonForInterest {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    
                                    Text(reason)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(themeBrown)
                                .cornerRadius(20)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(rotationAngle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                rotationAngle = Double(value.translation.width / 20)
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 120
                                if value.translation.width > threshold {
                                    withAnimation(.spring()) {
                                        dragOffset = CGSize(width: 800, height: value.translation.height)
                                        rotationAngle = 15
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        handleAccept()
                                        dragOffset = .zero
                                        rotationAngle = 0
                                    }
                                } else if value.translation.width < -threshold {
                                    withAnimation(.spring()) {
                                        dragOffset = CGSize(width: -800, height: value.translation.height)
                                        rotationAngle = -15
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        handleReject()
                                        dragOffset = .zero
                                        rotationAngle = 0
                                    }
                                } else {
                                    withAnimation(.spring()) {
                                        dragOffset = .zero
                                        rotationAngle = 0
                                    }
                                }
                            }
                    )
                    
                    // Profile Details Section
                    let isSwiping = abs(dragOffset.width) > 10
                    VStack(alignment: .leading, spacing: 20) {
                        // Bio
                        Text(profile.bio)
                            .font(.system(size: 16))
                            .foregroundColor(themeBrown)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Expertise Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Expertise")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeBrown)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(profile.expertise, id: \.self) { skill in
                                        Text(skill)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(themeBrown)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(themeBrown.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(themeBrown, lineWidth: 1)
                                            )
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Time and Remaining Requests — compact and stylish
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.gray)
                                Text(request.timeAgo)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            if currentIndex < requests.count - 1 {
                                let remaining = requests.count - currentIndex - 1
                                HStack(spacing: 6) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(themeBrown)
                                    Text("\(remaining)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(themeBrown.opacity(0.1))
                                        .foregroundColor(themeBrown)
                                        .cornerRadius(6)
                                    Text(remaining == 1 ? "request left" : "requests left")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                    }
                    .opacity(isSwiping ? 0 : 1)
                    .animation(.easeInOut(duration: 0.15), value: isSwiping)
                }
            }
            .opacity(actionAnimation ? 0.3 : 1.0)
            .scaleEffect(actionAnimation ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: actionAnimation)
        }
    }
    
    // MARK: - Bottom Action Area
    @ViewBuilder
    private func bottomActionArea() -> some View {
        VStack(spacing: 16) {
            // Action Buttons
            HStack(spacing: 40) {
                // Reject Button
                Button(action: { handleReject() }) {
                    ZStack {
                        let highlighted = dragOffset.width < -20
                        Circle()
                            .fill(highlighted ? Color.red : Color.white)
                            .frame(width: highlighted ? 68 : 60, height: highlighted ? 68 : 60)
                            .shadow(color: (highlighted ? Color.red : Color.black).opacity(0.15), radius: highlighted ? 8 : 5, x: 0, y: 2)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: highlighted ? 26 : 24, weight: .bold))
                            .foregroundColor(highlighted ? .white : .red)
                    }
                }
                
                // Accept Button
                Button(action: { handleAccept() }) {
                    ZStack {
                        let highlighted = dragOffset.width > 20
                        Circle()
                            .fill(highlighted ? themeBrown : Color.white)
                            .frame(width: highlighted ? 78 : 70, height: highlighted ? 78 : 70)
                            .shadow(color: (highlighted ? themeBrown : Color.black).opacity(0.2), radius: highlighted ? 10 : 6, x: 0, y: 4)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: highlighted ? 30 : 28, weight: .bold))
                            .foregroundColor(highlighted ? .white : themeBrown)
                    }
                }
            }
            .padding(.bottom, 8)
            
            // Call to Action Text (dynamic by swipe direction)
            if currentIndex < requests.count {
                let request = requests[currentIndex]
                Text(ctaMessage(for: request))
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 40)
        .opacity(abs(dragOffset.width) > 10 ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
    }
    
    // MARK: - No More Requests View
    @ViewBuilder
    private func noMoreRequestsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
            
            Text("All Done!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("You've reviewed all connection requests.\nCheck back later for new requests!")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Actions
    private func handleReject() {
        guard currentIndex < requests.count else { return }
        
        // Animate rejection
        withAnimation(.easeInOut(duration: 0.3)) { actionAnimation = true }
        
        Task { @MainActor in
            // In real app: call backend to reject
            moveToNextRequest()
        }
    }
    
    private func handleAccept() {
        guard currentIndex < requests.count else { return }
        let request = requests[currentIndex]
        
        // Animate acceptance
        withAnimation(.easeInOut(duration: 0.3)) { actionAnimation = true }
        
        Task { @MainActor in
            if let currentUser = authManager.currentUser {
                _ = databaseManager.createMatchEntity(
                    userId: currentUser.id,
                    matchedUserId: request.requesterId,
                    matchedUserName: request.requesterProfile.name,
                    matchType: "connection_request"
                )
                NotificationCenter.default.post(
                    name: NSNotification.Name("ConnectionRequestAccepted"),
                    object: nil,
                    userInfo: ["request": request]
                )
            }
            moveToNextRequest()
        }
    }
    
    private func moveToNextRequest() {
        withAnimation(.easeInOut(duration: 0.2)) { actionAnimation = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
        }
    }
    
    // MARK: - CTA Message Helper
    private func ctaMessage(for request: ConnectionRequest) -> String {
        if dragOffset.width > 20 {
            return "Release to accept and connect with \(request.requesterProfile.name)"
        } else if dragOffset.width < -20 {
            return "Release to skip and see the next request"
        } else {
            return "Swipe to decide or tap a button"
        }
    }
    
    // MARK: - Data Loading
    private func loadConnectionRequests() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // simulate delay
            await MainActor.run {
                self.requests = ConnectionRequest.sampleRequests
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview
struct ConnectionRequestsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRequestsView()
            .environmentObject(AuthManager())
            .environmentObject(DatabaseManager.shared)
            .environmentObject(SupabaseService.shared)
    }
}

