import SwiftUI

// MARK: - Connection Requests View
struct ConnectionRequestsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var requests: [ConnectionRequest] = []
    @State private var isLoading = true
    @State private var selectedRequest: ConnectionRequest?
    @State private var showingSentInvitations = false
    @State private var sentInvitations: [SupabaseInvitation] = []
    @State private var isLoadingSentInvitations = false
    
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
            .sheet(isPresented: $showingSentInvitations) {
                NavigationStack {
                    SentInvitationsListView(invitations: sentInvitations, isLoading: isLoadingSentInvitations)
                        .environmentObject(authManager)
                        .environmentObject(supabaseService)
                }
            }
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
                loadSentInvitations()
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
            
            // Sent Invitations Icon
            Button(action: {
                showingSentInvitations = true
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(themeBrown)
            }
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
        guard let currentUser = authManager.currentUser else { return }
        
        // Remove from list
        if let index = requests.firstIndex(where: { $0.id == request.id }) {
            requests.remove(at: index)
        }
        
        Task {
            do {
                // 拒绝邀请（更新状态为 rejected）
                _ = try await supabaseService.rejectInvitation(
                    invitationId: request.id,
                    userId: currentUser.id
                )
                
                print("✅ Rejected invitation from \(request.requesterProfile.name)")
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ConnectionRequestRejected"),
                        object: nil,
                        userInfo: ["request": request]
                    )
                }
            } catch {
                print("❌ Failed to reject invitation: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleAccept(request: ConnectionRequest) {
        guard let currentUser = authManager.currentUser else { return }
        
        // 保存索引以便失败时恢复
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else { return }
        
        // Remove from list
        requests.remove(at: index)
        
        Task {
            do {
                // 接受邀请（这会自动创建匹配记录，因为数据库有触发器）
                _ = try await supabaseService.acceptInvitation(
                    invitationId: request.id,
                    userId: currentUser.id
                )
                
                print("✅ Accepted invitation from \(request.requesterProfile.name)")
                
                // 同时保存到本地数据库
                await MainActor.run {
                    _ = databaseManager.createMatchEntity(
                        userId: currentUser.id,
                        matchedUserId: request.requesterId,
                        matchedUserName: request.requesterProfile.name,
                        matchType: "invitation_based"
                    )
                    
                    // 发送通知：邀请已接受
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ConnectionRequestAccepted"),
                        object: nil,
                        userInfo: ["request": request]
                    )
                    
                    // 发送通知：导航到 Chat 界面
                    // 延迟一点时间确保匹配记录已创建
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToChat"),
                            object: nil,
                            userInfo: ["matchedUserId": request.requesterId]
                        )
                    }
                }
            } catch {
                print("❌ Failed to accept invitation: \(error.localizedDescription)")
                await MainActor.run {
                    // 如果失败，恢复列表
                    requests.insert(request, at: min(index, requests.count))
                }
            }
        }
    }
    
    // MARK: - Data Loading
    private func loadConnectionRequests() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        isLoading = true
        Task {
            do {
                // 从 Supabase 获取收到的待处理邀请
                let supabaseInvitations = try await supabaseService.getPendingInvitations(userId: currentUser.id)
                
                // 获取所有已匹配的用户ID，用于过滤
                var matchedUserIds: Set<String> = []
                do {
                    let matches = try await supabaseService.getActiveMatches(userId: currentUser.id)
                    for match in matches {
                        if match.userId == currentUser.id {
                            matchedUserIds.insert(match.matchedUserId)
                        } else if match.matchedUserId == currentUser.id {
                            matchedUserIds.insert(match.userId)
                        }
                    }
                } catch {
                    print("⚠️ Failed to fetch matches for filtering: \(error.localizedDescription)")
                }
                
                // 过滤掉已经匹配的邀请
                let filteredInvitations = supabaseInvitations.filter { invitation in
                    !matchedUserIds.contains(invitation.senderId)
                }
                
                print("📊 Filtered connection requests: \(filteredInvitations.count) remaining (removed \(supabaseInvitations.count - filteredInvitations.count) already matched)")
                
                // 转换为 ConnectionRequest 模型
                var convertedRequests: [ConnectionRequest] = []
                
                for invitation in filteredInvitations {
                    // 获取发送者的 profile 信息
                    var requesterProfile = ConnectionRequestProfile(
                        profilePhoto: nil,
                        name: "Unknown",
                        jobTitle: "",
                        company: "",
                        location: "",
                        bio: "",
                        expertise: [],
                        backgroundImage: nil
                    )
                    
                    // 从 senderProfile JSONB 中提取信息
                    if let senderProfile = invitation.senderProfile {
                        requesterProfile = ConnectionRequestProfile(
                            profilePhoto: senderProfile.profileImage,
                            name: senderProfile.name,
                            jobTitle: senderProfile.jobTitle ?? "",
                            company: senderProfile.company ?? "",
                            location: senderProfile.location ?? "",
                            bio: senderProfile.bio ?? "",
                            expertise: senderProfile.expertise ?? [],
                            backgroundImage: nil
                        )
                    } else {
                        // 如果没有 senderProfile，尝试从 profile 表获取
                        if let senderProfile = try? await supabaseService.getProfile(userId: invitation.senderId) {
                            let brewNetProfile = senderProfile.toBrewNetProfile()
                            requesterProfile = ConnectionRequestProfile(
                                profilePhoto: brewNetProfile.coreIdentity.profileImage,
                                name: brewNetProfile.coreIdentity.name,
                                jobTitle: brewNetProfile.professionalBackground.jobTitle ?? "",
                                company: brewNetProfile.professionalBackground.currentCompany ?? "",
                                location: brewNetProfile.coreIdentity.location ?? "",
                                bio: brewNetProfile.coreIdentity.bio ?? "",
                                expertise: brewNetProfile.professionalBackground.skills,
                                backgroundImage: nil
                            )
                        }
                    }
                    
                    // 解析创建时间
                    let dateFormatter = ISO8601DateFormatter()
                    let createdAt = dateFormatter.date(from: invitation.createdAt) ?? Date()
                    
                    let connectionRequest = ConnectionRequest(
                        id: invitation.id,
                        requesterId: invitation.senderId,
                        requesterName: requesterProfile.name,
                        requesterProfile: requesterProfile,
                        reasonForInterest: invitation.reasonForInterest,
                        createdAt: createdAt,
                        isFeatured: false // 可以根据需要设置
                    )
                    
                    convertedRequests.append(connectionRequest)
                }
                
                await MainActor.run {
                    self.requests = convertedRequests
                    self.isLoading = false
                    print("✅ Loaded \(convertedRequests.count) connection requests from database")
                }
                
            } catch {
                print("❌ Failed to load connection requests: \(error.localizedDescription)")
                await MainActor.run {
                    self.requests = []
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Load Sent Invitations
    private func loadSentInvitations() {
        guard let currentUser = authManager.currentUser else { return }
        
        isLoadingSentInvitations = true
        Task {
            do {
                let fetchedInvitations = try await supabaseService.getSentInvitations(userId: currentUser.id)
                await MainActor.run {
                    sentInvitations = fetchedInvitations
                    isLoadingSentInvitations = false
                    print("✅ Loaded \(fetchedInvitations.count) sent invitations")
                }
            } catch {
                print("❌ Failed to load sent invitations: \(error.localizedDescription)")
                await MainActor.run {
                    sentInvitations = []
                    isLoadingSentInvitations = false
                }
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
    
    @State private var showMessageSheet = false
    @State private var requesterProfile: BrewNetProfile?
    @State private var isLoadingProfile = true
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        if isLoadingProfile {
                            ProgressView()
                                .padding(.top, 100)
                        } else if let profile = requesterProfile {
                            // Reason for Interest Section (if exists)
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
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                            }
                            
                            // Profile Header (using PublicProfileView style)
                            PublicProfileHeaderView(profile: profile)
                                .padding(.horizontal, 16)
                                .padding(.top, request.reasonForInterest != nil ? 24 : 20)
                            
                            // Networking Preferences Section (Only show if timeslot is public)
                            if isVisible(profile.privacyTrust.visibilitySettings.timeslot) {
                                ProfileSectionView(
                                    title: "Network Preferences",
                                    icon: "clock.fill"
                                ) {
                                    NetworkingPreferencesDisplayView(preferences: profile.networkingPreferences)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            }
                            
                            // Professional Background Section (Only show public fields)
                            if hasAnyPublicProfessionalInfo(profile) {
                                ProfileSectionView(
                                    title: "Professional Background",
                                    icon: "briefcase.fill"
                                ) {
                                    PublicProfessionalBackgroundDisplayView(
                                        background: profile.professionalBackground,
                                        visibilitySettings: profile.privacyTrust.visibilitySettings
                                    )
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            }
                            
                            // Personality & Interests Section (Only show if interests is public)
                            if isVisible(profile.privacyTrust.visibilitySettings.interests) {
                                ProfileSectionView(
                                    title: "Personality & Interests",
                                    icon: "person.fill"
                                ) {
                                    PersonalitySocialDisplayView(personality: profile.personalitySocial)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                            }
                            
                            // Add padding at bottom for action buttons
                            Spacer()
                                .frame(height: 100)
                        }
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
            .sheet(isPresented: $showMessageSheet) {
                LeaveMessageView(
                    request: request,
                    onDismiss: { showMessageSheet = false },
                    onSend: { message in
                        handleSendMessage(message: message)
                        showMessageSheet = false
                        onMessage(request)
                    }
                )
                .environmentObject(authManager)
                .environmentObject(databaseManager)
                .environmentObject(supabaseService)
            }
            .onAppear {
                loadRequesterProfile()
            }
        }
    }
    
    // Helper to check if a field should be visible based on privacy settings
    private func isVisible(_ visibilityLevel: VisibilityLevel) -> Bool {
        return visibilityLevel == .public_
    }
    
    // Check if there's any public professional information to show
    private func hasAnyPublicProfessionalInfo(_ profile: BrewNetProfile) -> Bool {
        let vs = profile.privacyTrust.visibilitySettings
        return isVisible(vs.skills) || isVisible(vs.company)
    }
    
    // Load requester's full profile
    private func loadRequesterProfile() {
        isLoadingProfile = true
        Task {
            do {
                if let profile = try await supabaseService.getProfile(userId: request.requesterId) {
                    await MainActor.run {
                        requesterProfile = profile.toBrewNetProfile()
                        isLoadingProfile = false
                        print("✅ Loaded requester profile: \(profile.coreIdentity.name)")
                    }
                } else {
                    await MainActor.run {
                        isLoadingProfile = false
                        print("⚠️ Failed to load requester profile")
                    }
                }
            } catch {
                print("❌ Failed to load requester profile: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }
    
    private func handleSendMessage(message: String) {
        // 在真实应用中，这里会发送消息到后端
        print("💬 Sent message to \(request.requesterProfile.name): \(message)")
        
        // 可以创建一个未匹配的消息实体并保存到本地数据库
        // 在实际应用中，这会发送到 Supabase
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
                    showMessageSheet = true
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

// MARK: - Leave Message View
struct LeaveMessageView: View {
    let request: ConnectionRequest
    let onDismiss: () -> Void
    let onSend: (String) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var themeBrown: Color { BrewTheme.primaryBrown }
    private var themeBrownLight: Color { BrewTheme.secondaryBrown }
    private let maxMessageLength = 200
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top instruction area
                VStack(spacing: 16) {
                    // Profile info
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(themeBrownLight)
                        
                        Text("Leave a message for \(request.requesterProfile.name)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(themeBrown)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Text("You're not connected yet. This is your first step to reach out")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Info box
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(BrewTheme.accentColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Message Info")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeBrown)
                            Text("You can send each other messages up to \(maxMessageLength) characters")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(themeBrownLight.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                
                Divider()
                
                // Message input area
                VStack(alignment: .leading, spacing: 12) {
                    Text("Write your message")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeBrown)
                        .padding(.horizontal, 20)
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isTextFieldFocused ? themeBrown : Color.gray.opacity(0.3), lineWidth: 2)
                            )
                            .frame(height: 150)
                        
                        TextEditor(text: $messageText)
                            .font(.system(size: 16))
                            .padding(8)
                            .frame(height: 140)
                            .scrollContentBackground(.hidden)
                            .focused($isTextFieldFocused)
                            .onChange(of: messageText) { newValue in
                                if newValue.count > maxMessageLength {
                                    messageText = String(newValue.prefix(maxMessageLength))
                                }
                            }
                        
                        // Character counter overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(messageText.count)/\(maxMessageLength)")
                                    .font(.system(size: 12))
                                    .foregroundColor(messageText.count > maxMessageLength * 90 / 100 ? .orange : .gray)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 14))
                                .foregroundColor(BrewTheme.accentColor)
                            Text("Tips:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeBrown)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TipRow(text: "Introduce yourself and your professional background")
                            TipRow(text: "Explain why you share common interests")
                            TipRow(text: "Express your interest in collaboration or networking")
                        }
                        .padding(.leading, 22)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
                
                Spacer()
                
                // Send button
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: {
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend(messageText.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Send Message")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                        .background(
                            Group {
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Color.gray.opacity(0.5)
                                } else {
                                    BrewTheme.gradientPrimary()
                                }
                            }
                        )
                        .cornerRadius(12)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color.white)
            }
            .background(BrewTheme.background)
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
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BrewTheme.primaryBrown.opacity(0.3))
                .frame(width: 5, height: 5)
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.gray)
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

