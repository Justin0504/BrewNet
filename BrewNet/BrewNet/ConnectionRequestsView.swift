import SwiftUI

// MARK: - Connection Requests View
struct ConnectionRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var requests: [ConnectionRequest] = []
    @State private var isLoading = true
    @State private var selectedRequest: ConnectionRequest?
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                BrewTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    topBarView()
                    
                    // Main Content
                    if isLoading {
                        loadingView()
                    } else if requests.isEmpty {
                        noMoreRequestsView()
                    } else {
                        // List View
                        listView()
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedRequest) { request in
                ConnectionRequestDetailView(
                    request: request,
                    onDismiss: { selectedRequest = nil },
                    onAccept: { request in
                        handleAccept(request: request)
                        selectedRequest = nil
                    },
                    onReject: { request in
                        handleReject(request: request)
                        selectedRequest = nil
                    },
                    onMessage: { request in
                        // Handle message action
                        selectedRequest = nil
                    }
                )
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
            }
            .onAppear {
                loadConnectionRequests()
            }
        }
    }
    
    // MARK: - Top Bar
    @ViewBuilder
    private func topBarView() -> some View {
        HStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 18))
                    .foregroundColor(BrewTheme.accentColor)
                
                Text("Connection Requests (\(requests.count))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeBrown)
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
                .progressViewStyle(CircularProgressViewStyle(tint: themeBrownLight))
                .scaleEffect(1.2)
            
            Text("Loading connection requests...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List View
    @ViewBuilder
    private func listView() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(requests) { request in
                    CompactRequestCard(request: request)
                        .onTapGesture {
                            selectedRequest = request
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - No More Requests View
    @ViewBuilder
    private func noMoreRequestsView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(themeBrownLight)
            
            Text("All Done!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(themeBrown)
            
            Text("You've reviewed all connection requests.\nCheck back later for new requests!")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Actions
    private func handleReject(request: ConnectionRequest) {
        // Remove from list
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests.remove(at: index)
        }
        
        Task { @MainActor in
            // In real app: call backend to reject
            print("Rejected request from \(request.requesterProfile.name)")
        }
    }
    
    private func handleAccept(request: ConnectionRequest) {
        // Remove from list
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests.remove(at: index)
        }
        
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
        }
    }
    
    // MARK: - Data Loading
    private func loadConnectionRequests() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.requests = ConnectionRequest.sampleRequests
                self.isLoading = false
            }
        }
    }
}

// MARK: - Compact Request Card
struct CompactRequestCard: View {
    let request: ConnectionRequest
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Photo
            ZStack(alignment: .topTrailing) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(BrewTheme.secondaryBrown)
                
                // Verified badge if featured
                if request.isFeatured {
                    Circle()
                        .fill(BrewTheme.accentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 5, y: -5)
                }
            }
            
            // Profile Info
            VStack(alignment: .leading, spacing: 6) {
                // Name with Online Status
                HStack(spacing: 8) {
                    Text(request.requesterProfile.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeBrown)
                    
                    // Online indicator
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Active now")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Reason for interest
                if let reason = request.reasonForInterest {
                    Text(reason)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Company and Location
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(request.requesterProfile.company)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                // Time ago
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(request.timeAgo)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Connection Request Detail View
struct ConnectionRequestDetailView: View {
    let request: ConnectionRequest
    let onDismiss: () -> Void
    let onAccept: (ConnectionRequest) -> Void
    let onReject: (ConnectionRequest) -> Void
    let onMessage: (ConnectionRequest) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BrewTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header with Photo
                        profileHeaderView()
                        
                        // Profile Details
                        profileDetailsView()
                        
                        // Add padding at bottom for action buttons
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Bottom Action Buttons
                VStack {
                    Spacer()
                    bottomActionButtons()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(themeBrown)
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
        }
    }
    
    @ViewBuilder
    private func profileHeaderView() -> some View {
        ZStack(alignment: .topTrailing) {
            // Background with gradient
            RoundedRectangle(cornerRadius: 0)
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
                .frame(height: 400)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)
                
                // Profile Photo
                ZStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 140))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
                }
                .padding(.bottom, 20)
                
                // Name and Job Title
                VStack(spacing: 12) {
                    Text(request.requesterProfile.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(request.requesterProfile.jobTitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    
                    // Company and Location
                    HStack(spacing: 20) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.2")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            Text(request.requesterProfile.company)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                            Text(request.requesterProfile.location)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Online Status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Active now")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            
            // Featured Professional Tag overlay
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
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }
            }
        }
    }
    
    @ViewBuilder
    private func profileDetailsView() -> some View {
        VStack(spacing: 24) {
            // Reason for Interest
            if let reason = request.reasonForInterest {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(BrewTheme.accentColor)
                        Text("Reason for Interest")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(themeBrown)
                    }
                    
                    Text(reason)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
                .frame(minHeight: 100)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            
            // Bio
            VStack(alignment: .leading, spacing: 12) {
                Text("About")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeBrown)
                
                Text(request.requesterProfile.bio)
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }
            .frame(minHeight: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // Expertise Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Expertise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeBrown)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(request.requesterProfile.expertise, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeBrown)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
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
            .frame(minHeight: 100)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private func bottomActionButtons() -> some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 0) {
                Spacer()
                
                // Decline Button
                Button(action: {
                    onReject(request)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Message Button
                Button(action: {
                    onMessage(request)
                }) {
                    Image(systemName: "message")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeBrown)
                        .frame(width: 58, height: 58)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(themeBrown, lineWidth: 2)
                        )
                }
                
                Spacer()
                
                // Accept Button
                Button(action: {
                    onAccept(request)
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(BrewTheme.gradientPrimary())
                        .clipShape(Circle())
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .background(Color.white)
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
