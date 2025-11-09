import SwiftUI

// MARK: - Distance Display View
struct DistanceDisplayView: View {
    let otherUserLocation: String?
    let currentUserLocation: String?
    var accentColor: Color = Color(red: 0.6, green: 0.4, blue: 0.2)
    var textColor: Color = Color(red: 0.4, green: 0.2, blue: 0.1)
    var backgroundColor: Color? = Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.1)
    var font: Font = .system(size: 16, weight: .semibold)
    var loadingText: String = "Calculating..."
    
    @StateObject private var locationService = LocationService.shared
    @State private var distance: Double?
    @State private var isLoading = false
    @State private var debounceTask: DispatchWorkItem? // ⭐ 防抖动任务
    
    var body: some View {
        Group {
            if isLoading {
                styledContainer {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                            .scaleEffect(0.8)
                        Text(loadingText)
                            .font(font)
                            .foregroundColor(textColor)
                    }
                }
                .onAppear {
                    print("📊 [DistanceDisplay] UI显示: 加载中...")
                }
            } else if let distance = distance {
                styledContainer {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(accentColor)
                        Text(locationService.formatDistance(distance))
                            .font(font)
                            .foregroundColor(textColor)
                    }
                }
                .onAppear {
                    print("📊 [DistanceDisplay] UI显示: 距离 = \(locationService.formatDistance(distance))")
                }
            } else {
                if let otherLocation = otherUserLocation, !otherLocation.isEmpty {
                    if currentUserLocation == nil || currentUserLocation?.isEmpty == true {
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
        // ⭐ 取消之前的防抖动任务
        debounceTask?.cancel()
        
        print("🔍 [DistanceDisplay] 开始计算距离（使用防抖动）...")
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
        distance = nil
        
        locationService.calculateDistanceBetweenAddresses(
            address1: currentLocation,
            address2: otherLocation
        ) { calculatedDistance in
            print("🔔 [DistanceDisplay] 收到距离计算回调")
            print("   - calculatedDistance: \(calculatedDistance != nil ? "\(calculatedDistance!) km" : "nil")")
        // ⭐ 创建新的防抖动任务，延迟 0.3 秒执行
        let task = DispatchWorkItem { [self] in
            print("📍 [DistanceDisplay] 防抖动延迟后执行地理编码...")
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
                    isLoading = false
                    if let distance = calculatedDistance {
                        self.distance = distance
                        print("✅ [DistanceDisplay] ✅✅✅ 距离计算成功: \(locationService.formatDistance(distance)) ✅✅✅")
                        print("   - distance 状态变量已设置为: \(self.distance != nil ? "\(self.distance!)" : "nil")")
                    } else {
                        self.distance = nil
                        print("⚠️ [DistanceDisplay] ⚠️⚠️⚠️ 距离计算失败 ⚠️⚠️⚠️")
                        print("   - 可能原因：地理编码失败、网络问题或地址格式不正确")
                    }
                }
            }
        }
        
        debounceTask = task
        // ⭐ 延迟 0.3 秒执行，如果在这期间又有新的调用，旧任务会被取消
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
    
    @ViewBuilder
    private func styledContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let backgroundColor {
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .cornerRadius(8)
        } else {
            content()
        }
    }
}

// MARK: - Unified Profile Card Content
struct ProfileCardContentView: View {
    let profile: BrewNetProfile
    let isConnection: Bool
    let isProUser: Bool
    let isVerified: Bool?
    let currentUserLocation: String?
    var showDistance: Bool = true
    var onWorkExperienceTap: ((WorkExperience) -> Void)?
    
    private let themeBrown = Color(red: 0.4, green: 0.2, blue: 0.1)
    private let accentBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    private let mutedText = Color.gray
    private let headerSpacing: CGFloat = 12
    
    private var privacySettings: VisibilitySettings { profile.privacyTrust.visibilitySettings }
    
    private var shouldShowCompany: Bool {
        privacySettings.company.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowSkills: Bool {
        privacySettings.skills.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowInterests: Bool {
        privacySettings.interests.isVisible(isConnection: isConnection)
    }
    
    private var shouldShowLocation: Bool {
        privacySettings.location.isVisible(isConnection: isConnection)
    }

    private var shouldShowTimeslot: Bool {
        privacySettings.timeslot.isVisible(isConnection: isConnection)
    }

    private var hasAvailableTimes: Bool {
        let timeslot = profile.networkingPreferences.availableTimeslot
        let days = [timeslot.sunday, timeslot.monday, timeslot.tuesday, timeslot.wednesday, timeslot.thursday, timeslot.friday, timeslot.saturday]
        return days.contains { day in
            day.morning || day.noon || day.afternoon || day.evening || day.night
        }
    }
    
    private var verificationColor: Color {
        let defaultVerified = profile.privacyTrust.verifiedStatus != .unverified
        let displayVerified = isVerified ?? defaultVerified
        return displayVerified ? Color(red: 0.15, green: 0.43, blue: 0.85) : Color.gray.opacity(0.5)
    }
    
    private var sortedWorkExperiences: [WorkExperience] {
        profile.professionalBackground.workExperiences.sorted { lhs, rhs in
            let lhsEnd = lhs.endYear ?? Int.max
            let rhsEnd = rhs.endYear ?? Int.max
            if lhsEnd == rhsEnd {
                return lhs.startYear > rhs.startYear
            }
            return lhsEnd > rhsEnd
        }
    }
    
    private var sortedEducations: [Education] {
        (profile.professionalBackground.educations ?? []).sorted { lhs, rhs in
            let lhsEnd = lhs.endYear ?? Int.max
            let rhsEnd = rhs.endYear ?? Int.max
            if lhsEnd == rhsEnd {
                return lhs.startYear > rhs.startYear
            }
            return lhsEnd > rhsEnd
        }
    }
    
    private var latestEducation: Education? {
        sortedEducations.first
    }
    
    private var companySchoolString: String? {
        let company = profile.professionalBackground.currentCompany
        let school = latestEducation?.schoolName
        
        switch (company?.isEmpty == false ? company : nil, school?.isEmpty == false ? school : nil) {
        case let (.some(company), .some(school)):
            return "\(company) - \(school)"
        case let (.some(company), nil):
            return company
        case let (nil, .some(school)):
            return school
        default:
            return nil
        }
    }
    
    private var careerStageDisplay: String? {
        profile.professionalBackground.careerStage.displayName
    }
    
    @State private var measuredNameWidth: CGFloat = 0
    @State private var measuredPronounWidth: CGFloat = 0
    @State private var measuredBadgeWidth: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 24) {
            headerSection
            titleSection
            
            if !sortedWorkExperiences.isEmpty {
                experienceSection
            }
            
            if !sortedEducations.isEmpty || profile.professionalBackground.education != nil {
                educationSection
            }
            
            websiteSection
            
            if let workPhotos = profile.workPhotos?.photos, !workPhotos.isEmpty {
                photoSection(title: "Working Pics", photos: workPhotos)
            }
            
            networkingIntentionSection
            whatLookingForSection
            skillsSection
            
            if let lifestylePhotos = profile.lifestylePhotos?.photos, !lifestylePhotos.isEmpty {
                photoSection(title: "Life Pics", photos: lifestylePhotos)
            }
            
            aboutMeSection
            valuesSection
            interestsSection
            timeslotSection
            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                profileImageView
                
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 18))
                    .foregroundColor(verificationColor)
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
                    .offset(x: 6, y: 6)
            }
            
            VStack(spacing: 12) {
                ZStack {
                    Text(profile.coreIdentity.name)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(themeBrown)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .background(widthMeasurer($measuredNameWidth))
                    
                    if isProUser {
                        ProBadge(size: .medium)
                            .background(widthMeasurer($measuredBadgeWidth))
                            .offset(x: (measuredNameWidth / 2) + (measuredBadgeWidth / 2) + headerSpacing)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(maxWidth: .infinity)
                
                if let pronouns = profile.coreIdentity.pronouns, !pronouns.isEmpty {
                    Text(pronouns)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accentBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(accentBrown.opacity(0.12))
                        .cornerRadius(16)
                        .frame(maxWidth: .infinity)
                }
                
                if let bio = profile.coreIdentity.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 16))
                        .foregroundColor(themeBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(4)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.clear)
                        )
                        .background(accentBrown.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            if let industry = profile.professionalBackground.industry, !industry.isEmpty || careerStageDisplay != nil {
                HStack(spacing: 6) {
                    if let industry = profile.professionalBackground.industry, !industry.isEmpty {
                        Text(industry)
                    }
                    if let careerStage = careerStageDisplay, !careerStage.isEmpty {
                        if profile.professionalBackground.industry?.isEmpty == false {
                            Text("•")
                        }
                        Text(careerStage)
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(themeBrown)
            }
            
            if shouldShowCompany, let companySchool = companySchoolString {
                Text(companySchool)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(themeBrown)
            }
            
            if shouldShowLocation, let location = profile.coreIdentity.location, !location.isEmpty {
                VStack(spacing: 4) {
                    Text(location)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(mutedText)
                    
                    if showDistance {
                        DistanceDisplayView(
                            otherUserLocation: location,
                            currentUserLocation: currentUserLocation,
                            accentColor: mutedText,
                            textColor: mutedText,
                            backgroundColor: nil,
                            font: .system(size: 12, weight: .medium),
                            loadingText: "Locating..."
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }
    
    private var experienceSection: some View {
        sectionContainer(title: "Working Experience", icon: "briefcase.fill") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sortedWorkExperiences.prefix(3))) { workExp in
                    if let handler = onWorkExperienceTap {
                        Button {
                            handler(workExp)
                        } label: {
                            WorkExperienceRowView(workExp: workExp)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        WorkExperienceRowView(workExp: workExp)
                    }
                }
                
                if let years = profile.professionalBackground.yearsOfExperience {
                    Text("Total: \(String(format: "%.1f", years)) years of experience")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(mutedText)
                        .italic()
                }
            }
        }
    }
    
    private var educationSection: some View {
        sectionContainer(title: "Education", icon: "graduationcap.fill") {
            VStack(alignment: .leading, spacing: 12) {
                if !sortedEducations.isEmpty {
                    ForEach(sortedEducations) { education in
                        EducationRowView(education: education, themeColor: themeBrown, textColor: mutedText)
                    }
                } else if let legacyEducation = profile.professionalBackground.education, !legacyEducation.isEmpty {
                    Text(legacyEducation)
                        .font(.system(size: 15))
                        .foregroundColor(mutedText)
                }
            }
        }
    }
    
    @ViewBuilder
    private var websiteSection: some View {
        if let website = profile.coreIdentity.personalWebsite,
           !website.isEmpty,
           let url = URL(string: website) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .foregroundColor(accentBrown)
                    Text("View Portfolio")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentBrown)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(accentBrown.opacity(0.12))
                .cornerRadius(14)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private func photoSection(title: String, photos: [Photo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: title, icon: "photo.fill.on.rectangle.fill")
            ProfilePhotoCarousel(photos: photos, accentColor: accentBrown)
        }
    }
    
    private var networkingIntentionSection: some View {
        NetworkingIntentionDisplayView(intention: profile.networkingIntention)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var whatLookingForSection: some View {
        guard !profile.networkingIntention.selectedSubIntentions.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "What I'm Looking For", icon: "sparkles") {
                FlowLayout(spacing: 8) {
                    ForEach(profile.networkingIntention.selectedSubIntentions, id: \.self) { subIntention in
                        Text(subIntention.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(accentBrown)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accentBrown.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }
        )
    }
    
    private var skillsSection: some View {
        guard shouldShowSkills, !profile.professionalBackground.skills.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "Skills & Expertise", icon: "wrench.and.screwdriver.fill") {
                FlowLayout(spacing: 8) {
                    ForEach(profile.professionalBackground.skills, id: \.self) { skill in
                        Text(skill)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(themeBrown)
                            .cornerRadius(12)
                    }
                }
            }
        )
    }
    
    private var aboutMeSection: some View {
        guard let about = profile.personalitySocial.selfIntroduction, !about.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "About Me", icon: "hand.wave.fill") {
                Text(about)
                    .font(.system(size: 16))
                    .foregroundColor(mutedText)
                    .lineSpacing(4)
            }
        )
    }
    
    private var valuesSection: some View {
        guard !profile.personalitySocial.valuesTags.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "Vibe & Values", icon: "message.fill") {
                FlowLayout(spacing: 8) {
                    ForEach(profile.personalitySocial.valuesTags, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 15))
                            .foregroundColor(accentBrown)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accentBrown.opacity(0.12))
                            .cornerRadius(12)
                    }
                }
            }
        )
    }
    
    private var interestsSection: some View {
        guard shouldShowInterests, !profile.personalitySocial.hobbies.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "Interests", icon: "target") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(profile.personalitySocial.hobbies, id: \.self) { hobby in
                            Text(hobby)
                                .font(.system(size: 15))
                                .foregroundColor(accentBrown)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(accentBrown.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        )
    }

    private var timeslotSection: some View {
        guard shouldShowTimeslot, hasAvailableTimes else {
            return AnyView(EmptyView())
        }
        return AnyView(
            sectionContainer(title: "Available Times", icon: "calendar") {
                AvailableTimeslotGridView(
                    timeslot: profile.networkingPreferences.availableTimeslot,
                    accentColor: accentBrown,
                    inactiveColor: Color.gray.opacity(0.15),
                    textColor: themeBrown
                )
            }
        )
    }
    
    private var profileImageView: some View {
        ZStack {
            if let imageUrl = profile.coreIdentity.profileImage,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholderImageView
                    @unknown default:
                        placeholderImageView
                    }
                }
            } else {
                placeholderImageView
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(accentBrown.opacity(0.3), lineWidth: 3)
        )
    }
    
    private var placeholderImageView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                accentBrown,
                themeBrown
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .font(.system(size: 42))
                .foregroundColor(.white)
        )
    }
    
    private func sectionContainer<Content: View>(title: String, icon: String, iconIsEmoji: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: title, icon: icon, iconIsEmoji: iconIsEmoji)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func sectionHeader(title: String, icon: String, iconIsEmoji: Bool = false) -> some View {
        HStack(spacing: 8) {
            if iconIsEmoji {
                Text(icon)
                    .font(.system(size: 18))
                    .foregroundColor(accentBrown)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentBrown)
            }
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(themeBrown)
        }
    }
    
    // MARK: - Nested Views
    private func widthMeasurer(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    let width = geometry.size.width
                    if abs(binding.wrappedValue - width) > 0.5 {
                        binding.wrappedValue = width
                    }
                }
                .onChange(of: geometry.size.width) { width in
                    if abs(binding.wrappedValue - width) > 0.5 {
                        binding.wrappedValue = width
                    }
                }
        }
    }
    
    private struct EducationRowView: View {
        let education: Education
        let themeColor: Color
        let textColor: Color
        
        private var durationText: String {
            let endText = education.endYear.map { String($0) } ?? "Present"
            return "\(education.startYear)-\(endText)"
        }
        
        private var detailText: String? {
            if let field = education.fieldOfStudy, !field.isEmpty {
                return field
            }
            return education.degree.displayName
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(education.schoolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeColor)
                    
                    Spacer()
                    
                    Text(durationText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
                
                if let detail = detailText {
                    Text(detail)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
        }
    }
    
    private struct ProfilePhotoCarousel: View {
        let photos: [Photo]
        let accentColor: Color
        
        private var carouselHeight: CGFloat {
            let screenWidth = UIScreen.main.bounds.width
            let maxWidth = screenWidth - 96 // account for outer padding
            return min(maxWidth, 320)
        }
        
        var body: some View {
            let height = carouselHeight
            TabView {
                ForEach(photos) { photo in
                    ZStack(alignment: .topLeading) {
                        if let urlString = photo.imageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure, .empty:
                                    placeholder
                                @unknown default:
                                    placeholder
                                }
                            }
                        } else {
                            placeholder
                        }
                        
                        if let caption = photo.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(12)
                                .padding(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: height + 20)
        }
        
        private var placeholder: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(accentColor.opacity(0.15))
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundColor(accentColor)
                )
        }
    }

    private struct AvailableTimeslotGridView: View {
        let timeslot: AvailableTimeslot
        let accentColor: Color
        let inactiveColor: Color
        let textColor: Color

        private let dayOrder: [(String, KeyPath<AvailableTimeslot, DayTimeslots>)] = [
            ("SUN", \.sunday),
            ("MON", \.monday),
            ("TUE", \.tuesday),
            ("WED", \.wednesday),
            ("THU", \.thursday),
            ("FRI", \.friday),
            ("SAT", \.saturday)
        ]

        private let timeOrder: [(String, KeyPath<DayTimeslots, Bool>)] = [
            ("Morning", \.morning),
            ("Noon", \.noon),
            ("Afternoon", \.afternoon),
            ("Evening", \.evening),
            ("Night", \.night)
        ]

        private let labelWidth: CGFloat = 52
        private let columnSpacing: CGFloat = 6
        private let cellSize = CGSize(width: 28, height: 25)

        var body: some View {
            VStack(alignment: .leading, spacing: columnSpacing) {
                // Header
                HStack(spacing: columnSpacing) {
                    Text("")
                        .frame(width: labelWidth)
                    ForEach(dayOrder, id: \.0) { day in
                        Text(day.0)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(textColor)
                            .frame(width: cellSize.width, alignment: .center)
                    }
                }

                ForEach(timeOrder, id: \.0) { time in
                    HStack(spacing: columnSpacing) {
                        Text(time.0)
                            .font(.system(size: 11))
                            .foregroundColor(textColor)
                            .frame(width: labelWidth, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        ForEach(dayOrder, id: \.0) { day in
                            let dayTimes = timeslot[keyPath: day.1]
                            let isActive = dayTimes[keyPath: time.1]

                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isActive ? accentColor : inactiveColor)
                                .frame(width: cellSize.width, height: cellSize.height)
                        }
                    }
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
    let isVerified: Bool? // Verification status from user_features table
    let showsOuterFrame: Bool
    let cardWidth: CGFloat
    
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
    
    init(profile: BrewNetProfile,
         dragOffset: Binding<CGSize>,
         rotationAngle: Binding<Double>,
         onSwipe: @escaping (SwipeDirection) -> Void,
         isConnection: Bool,
         isPro: Bool,
         isVerified: Bool?,
         showsOuterFrame: Bool = true,
         cardWidth: CGFloat? = nil) {
        self.profile = profile
        self._dragOffset = dragOffset
        self._rotationAngle = rotationAngle
        self.onSwipe = onSwipe
        self.isConnection = isConnection
        self.isPro = isPro
        self.isVerified = isVerified
        self.showsOuterFrame = showsOuterFrame
        self.cardWidth = cardWidth ?? UIScreen.main.bounds.width - 32
    }
    
    var body: some View {
        ZStack {
            if showsOuterFrame {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                    .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
                    .frame(width: cardWidth, height: screenHeight * 0.82)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                ProfileCardContentView(
                    profile: profile,
                    isConnection: isConnection,
                    isProUser: isPro,
                    isVerified: isVerified,
                    currentUserLocation: currentUserLocation,
                    showDistance: true,
                    onWorkExperienceTap: { workExp in
                        selectedWorkExperience = workExp
                    }
                )
                .background(Color.white)
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .id("scroll-\(profile.id)")
            .frame(width: cardWidth, height: screenHeight * 0.82)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            
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
                .offset(x: dragOffset.width > 0 ? 24 : -24, y: 40)
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
        .sheet(item: $selectedWorkExperience) { workExp in
            WorkExperienceDetailSheet(
                workExperience: workExp,
                allSkills: Array(profile.professionalBackground.skills.prefix(8)),
                industry: profile.professionalBackground.industry
            )
        }
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
                        Text("Working Experience")
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let position = workExp.position {
                    Text(position)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            let startYearText = String(workExp.startYear)
            let endYearText = workExp.endYear.map { String($0) } ?? "Present"
            Text(verbatim: "\(startYearText)-\(endYearText)")
                .font(.system(size: 15, weight: .semibold))
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
    var isConnection: Bool = false
    var isProUser: Bool? = nil
    var showDistance: Bool = true
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    
    @State private var currentUserLocation: String?
    @State private var resolvedProStatus: Bool?
    @State private var resolvedVerifiedStatus: Bool?
    
    private var displayIsPro: Bool {
        isProUser ?? resolvedProStatus ?? false
    }
    
    private var displayIsVerified: Bool? {
        resolvedVerifiedStatus
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ProfileCardContentView(
                profile: profile,
                isConnection: isConnection,
                isProUser: displayIsPro,
                isVerified: displayIsVerified,
                currentUserLocation: currentUserLocation,
                showDistance: showDistance,
                onWorkExperienceTap: nil
            )
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .onAppear {
            loadCurrentUserLocation()
            resolveProStatusIfNeeded()
            resolveVerifiedStatusIfNeeded()
        }
    }
    
    private func loadCurrentUserLocation() {
        guard let currentUser = authManager.currentUser else { return }
        
        Task {
            do {
                if let currentProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let brewProfile = currentProfile.toBrewNetProfile()
                    await MainActor.run {
                        currentUserLocation = brewProfile.coreIdentity.location
                    }
                }
            } catch {
                print("⚠️ [PublicProfileCard] Failed to load current user location: \(error.localizedDescription)")
            }
        }
    }
    
    private func resolveProStatusIfNeeded() {
        guard isProUser == nil, resolvedProStatus == nil else { return }
        
        Task {
            do {
                let proIds = try await supabaseService.getProUserIds(from: [profile.userId])
                await MainActor.run {
                    resolvedProStatus = proIds.contains(profile.userId)
                }
            } catch {
                print("⚠️ [PublicProfileCard] Failed to resolve Pro status: \(error.localizedDescription)")
            }
        }
    }
    
    private func resolveVerifiedStatusIfNeeded() {
        guard resolvedVerifiedStatus == nil else { return }
        
        Task {
            do {
                let verifiedIds = try await supabaseService.getVerifiedUserIds(from: [profile.userId])
                await MainActor.run {
                    resolvedVerifiedStatus = verifiedIds.contains(profile.userId)
                }
            } catch {
                print("⚠️ [PublicProfileCard] Failed to resolve verification status: \(error.localizedDescription)")
            }
        }
    }
}

struct LegacyPublicProfileCardView: View {
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
                        Text("Working Experience")
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
        let startYearText = String(workExperience.startYear)
        if let end = workExperience.endYear {
            let endYearText = String(end)
            return "\(startYearText) - \(endYearText)"
        } else {
            return "\(startYearText) - Present"
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
                        Label {
                            Text(verbatim: durationText)
                        } icon: {
                            Image(systemName: "calendar.badge.clock")
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        
                        if let industry = industry, !industry.isEmpty {
                            Label {
                                Text(verbatim: industry)
                            } icon: {
                                Image(systemName: "building.2.fill")
                            }
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
            .navigationTitle("Working Experience")
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
            isPro: true,
            isVerified: true
        )
    }
}

