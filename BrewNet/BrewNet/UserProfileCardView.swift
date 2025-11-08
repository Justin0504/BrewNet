import SwiftUI

// MARK: - Distance Display View
struct DistanceDisplayView: View {
    let otherUserLocation: String?
    let currentUserLocation: String?
    @StateObject private var locationService = LocationService.shared
    @State private var distance: Double?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                        .scaleEffect(0.8)
                    Text("Calculating...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                .cornerRadius(8)
                .onAppear {
                    print("📊 [DistanceDisplay] UI显示: 加载中...")
                }
            } else if let distance = distance {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    Text(locationService.formatDistance(distance))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                .cornerRadius(8)
                .onAppear {
                    print("📊 [DistanceDisplay] UI显示: 距离 = \(locationService.formatDistance(distance))")
                }
            } else {
                // 如果距离计算失败或还在等待，显示提示信息
                if let otherLocation = otherUserLocation, !otherLocation.isEmpty {
                    if currentUserLocation == nil || currentUserLocation?.isEmpty == true {
                        // 当前用户位置未加载或未设置
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("Set your location to see distance")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.6))
                                .italic()
                        }
                        .padding(.top, 2)
                    } else {
                        // 计算失败，可能是地理编码问题 - 显示调试信息（开发时）
                        #if DEBUG
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.orange.opacity(0.6))
                            Text("Calculating distance...")
                                .font(.system(size: 11))
                                .foregroundColor(.orange.opacity(0.6))
                                .italic()
                        }
                        .padding(.top, 2)
                        #else
                        EmptyView()
                        #endif
                    }
                }
            }
        }
        .onAppear {
            print("👁️ [DistanceDisplay] onAppear 触发")
            print("   - otherUserLocation: \(otherUserLocation ?? "nil")")
            print("   - currentUserLocation: \(currentUserLocation ?? "nil")")
            calculateDistance()
        }
        .onChange(of: otherUserLocation) { newValue in
            print("🔄 [DistanceDisplay] otherUserLocation 变化: \(newValue ?? "nil")")
            calculateDistance()
        }
        .onChange(of: currentUserLocation) { newValue in
            print("🔄 [DistanceDisplay] currentUserLocation 变化: \(newValue ?? "nil")")
            calculateDistance()
        }
    }
    
    private func calculateDistance() {
        print("🔍 [DistanceDisplay] 开始计算距离...")
        print("   - 对方地址: \(otherUserLocation ?? "nil")")
        print("   - 当前用户地址: \(currentUserLocation ?? "nil")")
        
        guard let otherLocation = otherUserLocation, !otherLocation.isEmpty else {
            print("⚠️ [DistanceDisplay] 对方地址为空")
            distance = nil
            return
        }
        
        guard let currentLocation = currentUserLocation, !currentLocation.isEmpty else {
            print("⚠️ [DistanceDisplay] 当前用户地址为空，等待加载...")
            distance = nil
            return
        }
        
        // 如果两个地址相同，距离为0
        if otherLocation == currentLocation {
            print("✅ [DistanceDisplay] 两个地址相同，距离为 0")
            distance = 0.0
            return
        }
        
        print("📍 [DistanceDisplay] 开始地理编码和计算距离...")
        print("   - 调用 locationService.calculateDistanceBetweenAddresses")
        print("   - address1 (当前用户): '\(currentLocation)'")
        print("   - address2 (对方): '\(otherLocation)'")
        
        isLoading = true
        distance = nil // 清除之前的值
        
        locationService.calculateDistanceBetweenAddresses(
            address1: currentLocation,
            address2: otherLocation
        ) { calculatedDistance in
            print("🔔 [DistanceDisplay] 收到距离计算回调")
            print("   - calculatedDistance: \(calculatedDistance != nil ? "\(calculatedDistance!) km" : "nil")")
            
            DispatchQueue.main.async {
                print("🔄 [DistanceDisplay] 在主线程更新 UI")
                self.isLoading = false
                if let distance = calculatedDistance {
                    self.distance = distance
                    print("✅ [DistanceDisplay] ✅✅✅ 距离计算成功: \(self.locationService.formatDistance(distance)) ✅✅✅")
                    print("   - distance 状态变量已设置为: \(self.distance != nil ? "\(self.distance!)" : "nil")")
                } else {
                    self.distance = nil
                    print("⚠️ [DistanceDisplay] ⚠️⚠️⚠️ 距离计算失败 ⚠️⚠️⚠️")
                    print("   - 可能原因：地理编码失败、网络问题或地址格式不正确")
                }
            }
        }
    }
}

// MARK: - User Profile Card View
struct UserProfileCardView: View {
    let profile: BrewNetProfile
    @Binding var dragOffset: CGSize
    @Binding var rotationAngle: Double
    let onSwipe: (SwipeDirection) -> Void
    let isConnection: Bool // Whether the current user is connected to this profile
    let isPro: Bool // Pro status from users table (passed from parent)
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var currentUserLocation: String?
    @State private var selectedWorkExperience: WorkExperience?
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    // Verify privacy settings are loaded
    private var privacySettings: VisibilitySettings {
        let settings = profile.privacyTrust.visibilitySettings
        // Log privacy settings for debugging
        print("🔒 Privacy Settings for \(profile.coreIdentity.name):")
        print("   - company: \(settings.company.rawValue)")
        print("   - skills: \(settings.skills.rawValue)")
        print("   - interests: \(settings.interests.rawValue)")
        print("   - location: \(settings.location.rawValue)")
        print("   - timeslot: \(settings.timeslot.rawValue)")
        print("   - email: \(settings.email.rawValue)")
        print("   - phone_number: \(settings.phoneNumber.rawValue)")
        print("   - isConnection: \(isConnection)")
        return settings
    }
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .frame(width: screenWidth - 40, height: screenHeight * 0.8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Level 1: Core Information Area
                    level1CoreInfoView
                    
                    // Level 2: Matching Clues
                    level2MatchingCluesView
                    
                    // Level 3: Deep Understanding
                    level3DeepUnderstandingView
                        // 只在最后一个元素上添加底部 padding，避免创建留白
                        .padding(.bottom, 110)
                }
                .frame(maxWidth: screenWidth - 40)
                .background(Color.white)
            }
            .frame(height: screenHeight * 0.8)
            .cornerRadius(20)
            
            // Swipe indicators
            if abs(dragOffset.width) > 50 {
                VStack {
                    if dragOffset.width > 0 {
                        SwipeIndicatorView(text: "LIKE", color: .green, systemImage: "heart.fill")
                            .rotationEffect(.degrees(-15))
                    } else {
                        SwipeIndicatorView(text: "PASS", color: .red, systemImage: "xmark")
                            .rotationEffect(.degrees(15))
                    }
                }
                .offset(x: dragOffset.width > 0 ? 20 : -20, y: 50)
            }
        }
        .offset(dragOffset)
        .rotationEffect(.degrees(rotationAngle))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    rotationAngle = Double(value.translation.width / 20)
                }
                .onEnded { value in
                    let threshold: CGFloat = 100
                    
                    if value.translation.width > threshold {
                        // Swipe right (Like)
                        withAnimation(.spring()) {
                            dragOffset = CGSize(width: screenWidth, height: value.translation.height)
                            rotationAngle = 15
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipe(.right)
                        }
                    } else if value.translation.width < -threshold {
                        // Swipe left (Pass)
                        withAnimation(.spring()) {
                            dragOffset = CGSize(width: -screenWidth, height: value.translation.height)
                            rotationAngle = -15
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipe(.left)
                        }
                    } else {
                        // Return to center
                        withAnimation(.spring()) {
                            dragOffset = .zero
                            rotationAngle = 0
                        }
                    }
                }
        )
        .onAppear {
            loadCurrentUserLocation()
        }
    }
    
    // MARK: - Load Current User Location
    private func loadCurrentUserLocation() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [UserProfileCard] 没有当前用户，无法加载位置")
            return
        }
        
        print("📍 [UserProfileCard] 开始加载当前用户位置...")
        print("   - 当前用户 ID: \(currentUser.id)")
        print("   - 当前用户邮箱: \(currentUser.email)")
        
        Task {
            do {
                if let currentProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    print("✅ [UserProfileCard] 成功获取 profile")
                    print("   - Profile ID: \(currentProfile.id)")
                    print("   - Core Identity Name: \(currentProfile.coreIdentity.name)")
                    print("   - Core Identity Email: \(currentProfile.coreIdentity.email)")
                    
                    // 检查原始数据
                    let rawLocation = currentProfile.coreIdentity.location
                    print("   - [原始数据] coreIdentity.location: \(rawLocation ?? "nil")")
                    print("   - [原始数据] location 是否为 nil: \(rawLocation == nil)")
                    print("   - [原始数据] location 是否为空字符串: \(rawLocation?.isEmpty == true)")
                    
                    let brewNetProfile = currentProfile.toBrewNetProfile()
                    await MainActor.run {
                        let newLocation = brewNetProfile.coreIdentity.location
                        print("   - [转换后] brewNetProfile.coreIdentity.location: \(newLocation ?? "nil")")
                        
                        // 检查值是否真的改变了
                        let oldLocation = currentUserLocation
                        print("   - [更新前] currentUserLocation: \(oldLocation ?? "nil")")
                        
                        currentUserLocation = newLocation
                        print("✅ [UserProfileCard] 已设置 currentUserLocation: \(newLocation ?? "nil")")
                        print("   - [更新后] currentUserLocation: \(self.currentUserLocation ?? "nil")")
                        
                        // 强制触发视图更新
                        if oldLocation != newLocation {
                            print("🔄 [UserProfileCard] 位置值已改变，应该触发 DistanceDisplayView 的 onChange")
                        }
                        
                        if newLocation == nil || newLocation?.isEmpty == true {
                            print("⚠️ [UserProfileCard] ⚠️⚠️⚠️ 当前用户没有设置位置信息 ⚠️⚠️⚠️")
                            print("⚠️ [UserProfileCard] 请前往 Profile Setup → Core Identity → Location 填写位置")
                            print("⚠️ [UserProfileCard] 或者点击 'Use Current Location' 按钮自动填充")
                            print("⚠️ [UserProfileCard] 因此无法显示距离信息")
                        } else {
                            print("✅ [UserProfileCard] 当前用户位置已设置: '\(newLocation!)'")
                            print("✅ [UserProfileCard] 可以计算距离")
                            // 延迟一小段时间后再次检查，确保 DistanceDisplayView 已更新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("🔍 [UserProfileCard] 延迟检查 - currentUserLocation: \(self.currentUserLocation ?? "nil")")
                            }
                        }
                    }
                } else {
                    print("⚠️ [UserProfileCard] 无法获取当前用户 profile")
                    print("⚠️ [UserProfileCard] 可能原因：")
                    print("   1. 用户还没有完成 Profile Setup")
                    print("   2. Profile 数据不存在于数据库中")
                }
            } catch {
                print("⚠️ [UserProfileCard] 加载当前用户位置失败: \(error.localizedDescription)")
                print("   - 错误类型: \(type(of: error))")
            }
        }
    }
    
    // MARK: - Level 1: Core Information Area
    private var level1CoreInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Image and Name Section
            HStack(alignment: .top, spacing: 16) {
                // Profile Image
                profileImageView
                
                // Name and Pronouns
                VStack(alignment: .leading, spacing: 8) {
                    // Name - 独立换行
                    HStack(spacing: 8) {
                        Text(profile.coreIdentity.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                        
                        if isPro {
                            ProBadge(size: .medium)
                        }
                    }
                    
                    // Pronouns - 独立一行
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Headline / Bio
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                    }
                }
                
                Spacer()
            }
            
            // Professional Info
            if shouldShowCompany {
                HStack(spacing: 8) {
                    if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                        Text(jobTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                        
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            Text("@")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            // Industry and Experience Level
            HStack(spacing: 8) {
                if let industry = profile.professionalBackground.industry, !industry.isEmpty {
                    Text(industry)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(nil)
                    
                    if profile.professionalBackground.experienceLevel != .entry {
                        Text("·")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text(profile.professionalBackground.experienceLevel.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Networking Intention Badge with Location and Distance
            VStack(alignment: .leading, spacing: 12) {
                NetworkingIntentionBadgeView(intention: profile.networkingIntention.selectedIntention)
                if !profile.networkingIntention.additionalIntentions.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.additionalIntentions, id: \.self) { extra in
                            Text(extra.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                }
                
                // Location and Distance (下方显示，字体与 intention 一样大)
                if shouldShowLocation, let location = profile.coreIdentity.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        // Location
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text(location)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        
                        // Distance display
                        DistanceDisplayView(
                            otherUserLocation: location,
                            currentUserLocation: currentUserLocation
                        )
                        .id("distance-\(location)-\(currentUserLocation ?? "nil")")
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    private var profileImageView: some View {
        ZStack {
            if let imageUrl = profile.coreIdentity.profileImage, !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderImageView
                    @unknown default:
                        placeholderImageView
                    }
                }
            } else {
                placeholderImageView
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 2)
        )
    }
    
    private var placeholderImageView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.4, blue: 0.2),
                Color(red: 0.4, green: 0.2, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        )
    }
    
    // MARK: - Level 2: Matching Clues
    private var level2MatchingCluesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // About Me
            if let selfIntro = profile.personalitySocial.selfIntroduction, !selfIntro.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("About Me")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    Text(selfIntro)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            
            // Education
            if let education = profile.professionalBackground.education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Education")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    Text(education)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            
            // Work Experience Chips
            if shouldShowCompany && !profile.professionalBackground.workExperiences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Work Experience")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.workExperiences) { workExp in
                            Button {
                                selectedWorkExperience = workExp
                            } label: {
                                HStack(spacing: 6) {
                                    Text(workExp.companyName)
                                        .font(.system(size: 15, weight: .semibold))
                                    if let position = workExp.position, !position.isEmpty {
                                        Text("·")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(position)
                                            .font(.system(size: 15))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .sheet(item: $selectedWorkExperience) { workExp in
                    WorkExperienceDetailSheet(
                        workExperience: workExp,
                        allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                        industry: profile.professionalBackground.industry
                    )
                }
            }
            
            // What I'm Looking For
            if !profile.networkingIntention.selectedSubIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("What I'm Looking For")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.selectedSubIntentions, id: \.self) { subIntention in
                            Text(subIntention.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Skills
            if shouldShowSkills && !profile.professionalBackground.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Skills & Expertise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Values
            if !profile.personalitySocial.valuesTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Vibe & Values")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.personalitySocial.valuesTags, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Hobbies & Interests
            if shouldShowInterests && !profile.personalitySocial.hobbies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Interests")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.personalitySocial.hobbies, id: \.self) { hobby in
                                Text(hobby)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Level 3: Deep Understanding
    private var level3DeepUnderstandingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Personal Website
            if let website = profile.coreIdentity.personalWebsite, !website.isEmpty,
               let websiteUrl = URL(string: website) {
                Link(destination: websiteUrl) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("View Portfolio")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Privacy Visibility Checks (strictly follows database privacy_trust.visibility_settings)
    // Only shows fields marked as "public" when isConnection is false
    private var shouldShowCompany: Bool {
        let settings = privacySettings
        let visible = settings.company.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Company hidden (not public): \(settings.company.rawValue)")
        }
        return visible
    }
    
    private var shouldShowSkills: Bool {
        let settings = privacySettings
        let visible = settings.skills.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Skills hidden (not public): \(settings.skills.rawValue)")
        }
        return visible
    }
    
    private var shouldShowInterests: Bool {
        let settings = privacySettings
        let visible = settings.interests.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Interests hidden (not public): \(settings.interests.rawValue)")
        }
        return visible
    }
    
    private var shouldShowLocation: Bool {
        let settings = privacySettings
        let visible = settings.location.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Location hidden (not public): \(settings.location.rawValue)")
        }
        return visible
    }
}

// MARK: - Supporting Views
struct NetworkingIntentionBadgeView: View {
    let intention: NetworkingIntentionType
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForIntention)
                .font(.system(size: 16))
            Text(intention.displayName)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(red: 0.6, green: 0.4, blue: 0.2))
        .cornerRadius(12)
    }
    
    private var iconForIntention: String {
        switch intention {
        case .learnGrow:
            return "book.fill"
        case .connectShare:
            return "person.2.fill"
        case .buildCollaborate:
            return "hand.raised.fill"
        case .unwindChat:
            return "cup.and.saucer.fill"
        }
    }
}

struct WorkExperienceRowView: View {
    let workExp: WorkExperience
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workExp.companyName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let position = workExp.position {
                    Text(position)
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text("\(workExp.startYear)\(workExp.endYear != nil ? "-\(workExp.endYear!)" : "-Present")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

struct SwipeIndicatorView: View {
    let text: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .padding()
        .background(Color.white.opacity(0.9))
        .cornerRadius(15)
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = FlowResult(
            in: maxWidth,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        let size: CGSize
        let frames: [CGRect]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var currentPosition: CGPoint = .zero
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentPosition.x > 0 && currentPosition.x + size.width > maxWidth {
                    currentPosition.x = 0
                    currentPosition.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: currentPosition, size: size))
                lineHeight = max(lineHeight, size.height)
                maxX = max(maxX, currentPosition.x + size.width)
                currentPosition.x += size.width + spacing
            }
            
            self.size = CGSize(width: maxX, height: currentPosition.y + lineHeight)
            self.frames = frames
        }
    }
}

// MARK: - Public Profile Card View (Unified style for Connection Requests and Sent Invitations)
struct PublicProfileCardView: View {
    let profile: BrewNetProfile
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var currentUserLocation: String?
    @State private var selectedWorkExperience: WorkExperience?
    
    // For public views, isConnection is always false (only show public fields)
    private let isConnection: Bool = false
    
    // Verify privacy settings are loaded from database
    private var privacySettings: VisibilitySettings {
        let settings = profile.privacyTrust.visibilitySettings
        // Log privacy settings for debugging
        print("🔒 Public Profile Privacy Settings for \(profile.coreIdentity.name):")
        print("   - company: \(settings.company.rawValue) -> visible: \(settings.company.isVisible(isConnection: false))")
        print("   - skills: \(settings.skills.rawValue) -> visible: \(settings.skills.isVisible(isConnection: false))")
        print("   - interests: \(settings.interests.rawValue) -> visible: \(settings.interests.isVisible(isConnection: false))")
        print("   - location: \(settings.location.rawValue) -> visible: \(settings.location.isVisible(isConnection: false))")
        print("   - timeslot: \(settings.timeslot.rawValue) -> visible: \(settings.timeslot.isVisible(isConnection: false))")
        return settings
    }
    
    var body: some View {
        ZStack {
            // Background - Same card style as UserProfileCardView
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Level 1: Core Information Area
                    level1CoreInfoView
                    
                    // Level 2: Matching Clues
                    level2MatchingCluesView
                    
                    // Level 3: Deep Understanding
                    level3DeepUnderstandingView
                }
            }
            .cornerRadius(20)
        }
        .onAppear {
            loadCurrentUserLocation()
        }
    }
    
    // MARK: - Load Current User Location
    private func loadCurrentUserLocation() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [PublicProfileCard] 没有当前用户，无法加载位置")
            return
        }
        
        print("📍 [PublicProfileCard] 开始加载当前用户位置...")
        print("   - 当前用户 ID: \(currentUser.id)")
        
        Task {
            do {
                if let currentProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let rawLocation = currentProfile.coreIdentity.location
                    print("   - [原始数据] coreIdentity.location: \(rawLocation ?? "nil")")
                    
                    let brewNetProfile = currentProfile.toBrewNetProfile()
                    await MainActor.run {
                        currentUserLocation = brewNetProfile.coreIdentity.location
                        print("✅ [PublicProfileCard] 已加载当前用户位置: \(brewNetProfile.coreIdentity.location ?? "nil")")
                        if brewNetProfile.coreIdentity.location == nil || brewNetProfile.coreIdentity.location?.isEmpty == true {
                            print("⚠️ [PublicProfileCard] 当前用户没有设置位置信息，请前往 Profile Setup 填写位置")
                        }
                    }
                } else {
                    print("⚠️ [PublicProfileCard] 无法获取当前用户 profile")
                }
            } catch {
                print("⚠️ [PublicProfileCard] 加载当前用户位置失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Level 1: Core Information Area (same as UserProfileCardView)
    private var level1CoreInfoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Profile Image and Name Section
            HStack(alignment: .top, spacing: 16) {
                // Profile Image
                profileImageView
                
                // Name and Pronouns
                VStack(alignment: .leading, spacing: 8) {
                    // Name - 独立换行
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .lineLimit(nil)
                    
                    // Pronouns - 独立一行
                    if let pronouns = profile.coreIdentity.pronouns {
                        Text(pronouns)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Headline / Bio
                    if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            .lineLimit(nil)
                    }
                }
                
                Spacer()
            }
            
            // Professional Info (only if company is public)
            if shouldShowCompany {
                HStack(spacing: 8) {
                    if let jobTitle = profile.professionalBackground.jobTitle, !jobTitle.isEmpty {
                        Text(jobTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(nil)
                        
                        if let company = profile.professionalBackground.currentCompany, !company.isEmpty {
                            Text("@")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
            }
            
            // Industry and Experience Level
            HStack(spacing: 8) {
                if let industry = profile.professionalBackground.industry, !industry.isEmpty {
                    Text(industry)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(nil)
                    
                    if profile.professionalBackground.experienceLevel != .entry {
                        Text("·")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text(profile.professionalBackground.experienceLevel.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer(minLength: 0)
            }
            
            // Networking Intention Badge with Location and Distance
            VStack(alignment: .leading, spacing: 12) {
                NetworkingIntentionBadgeView(intention: profile.networkingIntention.selectedIntention)
                if !profile.networkingIntention.additionalIntentions.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.additionalIntentions, id: \.self) { extra in
                            Text(extra.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                }
                
                // Location and Distance (下方显示，字体与 intention 一样大)
                if shouldShowLocation, let location = profile.coreIdentity.location, !location.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        // Location
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text(location)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        }
                        
                        // Distance display
                        DistanceDisplayView(
                            otherUserLocation: location,
                            currentUserLocation: currentUserLocation
                        )
                        .id("distance-\(location)-\(currentUserLocation ?? "nil")")
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    private var profileImageView: some View {
        ZStack {
            if let imageUrl = profile.coreIdentity.profileImage, !imageUrl.isEmpty,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        placeholderImageView
                    @unknown default:
                        placeholderImageView
                    }
                }
            } else {
                placeholderImageView
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.3), lineWidth: 2)
        )
    }
    
    private var placeholderImageView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.4, blue: 0.2),
                Color(red: 0.4, green: 0.2, blue: 0.1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
        )
    }
    
    // MARK: - Level 2: Matching Clues (same as UserProfileCardView)
    private var level2MatchingCluesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // About Me
            if let selfIntro = profile.personalitySocial.selfIntroduction, !selfIntro.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("About Me")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    Text(selfIntro)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
            }
            
            // Education
            if let education = profile.professionalBackground.education, !education.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Education")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    Text(education)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            
            // Work Experience Chips
            if shouldShowCompany && !profile.professionalBackground.workExperiences.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Work Experience")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.workExperiences) { workExp in
                            Button {
                                selectedWorkExperience = workExp
                            } label: {
                                HStack(spacing: 6) {
                                    Text(workExp.companyName)
                                        .font(.system(size: 15, weight: .semibold))
                                    if let position = workExp.position, !position.isEmpty {
                                        Text("·")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white.opacity(0.6))
                                        Text(position)
                                            .font(.system(size: 15))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .sheet(item: $selectedWorkExperience) { workExp in
                    WorkExperienceDetailSheet(
                        workExperience: workExp,
                        allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                        industry: profile.professionalBackground.industry
                    )
                }
            }
            
            // What I'm Looking For
            if !profile.networkingIntention.selectedSubIntentions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("What I'm Looking For")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.networkingIntention.selectedSubIntentions, id: \.self) { subIntention in
                            Text(subIntention.displayName)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Skills (only if public)
            if shouldShowSkills && !profile.professionalBackground.skills.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Skills & Expertise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.professionalBackground.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Values
            if !profile.personalitySocial.valuesTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Vibe & Values")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.personalitySocial.valuesTags, id: \.self) { value in
                            Text(value)
                                .font(.system(size: 15))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Hobbies & Interests (only if public)
            if shouldShowInterests && !profile.personalitySocial.hobbies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("Interests")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.personalitySocial.hobbies, id: \.self) { hobby in
                                Text(hobby)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
    }
    
    // MARK: - Level 3: Deep Understanding (same as UserProfileCardView)
    private var level3DeepUnderstandingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
            
            // Personal Website
            if let website = profile.coreIdentity.personalWebsite, !website.isEmpty,
               let websiteUrl = URL(string: website) {
                Link(destination: websiteUrl) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                        Text("View Portfolio")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 30)
        .background(Color.white)
    }
    
    // MARK: - Privacy Visibility Checks (strictly follows database privacy_trust.visibility_settings)
    private var shouldShowCompany: Bool {
        let settings = privacySettings
        let visible = settings.company.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Company hidden due to privacy: \(settings.company.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowSkills: Bool {
        let settings = privacySettings
        let visible = settings.skills.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Skills hidden due to privacy: \(settings.skills.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowInterests: Bool {
        let settings = privacySettings
        let visible = settings.interests.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Interests hidden due to privacy: \(settings.interests.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
    
    private var shouldShowLocation: Bool {
        let settings = privacySettings
        let visible = settings.location.isVisible(isConnection: isConnection)
        if !visible {
            print("   ⚠️ Location hidden due to privacy: \(settings.location.rawValue), isConnection: \(isConnection)")
        }
        return visible
    }
}

struct WorkExperienceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workExperience: WorkExperience
    let allSkills: [String]
    let industry: String?
    
    private var durationText: String {
        if let end = workExperience.endYear {
            return "\(workExperience.startYear) - \(end)"
        } else {
            return "\(workExperience.startYear) - Present"
        }
    }
    
    private var displaySkills: [String] {
        if !workExperience.highlightedSkills.isEmpty {
            return workExperience.highlightedSkills
        }
        return allSkills
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workExperience.companyName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        if let position = workExperience.position, !position.isEmpty {
                            Text(position)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Label(durationText, systemImage: "calendar.badge.clock")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        if let industry = industry, !industry.isEmpty {
                            Label(industry, systemImage: "building.2.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !displaySkills.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Skills")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            FlowLayout(spacing: 8) {
                                ForEach(displaySkills, id: \.self) { skill in
                                    Text(skill)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    if let responsibilities = workExperience.responsibilities, !responsibilities.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Role Highlights")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text(responsibilities)
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Role Highlights")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text("Reach out to learn more about this role and the projects they led during this time.")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.98, green: 0.97, blue: 0.95))
            .navigationTitle("Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview
struct UserProfileCardView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileCardView(
            profile: BrewNetProfile.createDefault(userId: "test"),
            dragOffset: .constant(.zero),
            rotationAngle: .constant(0),
            onSwipe: { _ in },
            isConnection: false,
            isPro: true
        )
    }
}

