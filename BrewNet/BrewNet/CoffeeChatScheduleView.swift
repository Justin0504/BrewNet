import SwiftUI
import CoreLocation

struct CoffeeChatScheduleView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.presentationMode) var presentationMode
    
    @State private var schedules: [CoffeeChatSchedule] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if schedules.isEmpty {
                    emptyStateView
                } else {
                    scheduleListView
                }
            }
            .navigationTitle("Coffee Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                loadSchedules()
            }
            .refreshable {
                loadSchedules()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CoffeeChatScheduleUpdated"))) { _ in
                print("🔄 [咖啡聊天] 收到日程更新通知，重新加载")
                loadSchedules()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2).opacity(0.5))
            
            Text("No Scheduled Coffee Chats")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            
            Text("Accepted coffee chat invitations will appear here")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var scheduleListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(schedules) { schedule in
                    ScheduleCardView(schedule: schedule, schedules: $schedules)
                        .environmentObject(supabaseService)
                        .environmentObject(authManager)
                        .id("schedule-\(schedule.id)-\(schedule.hasMet)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    private func loadSchedules() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [咖啡聊天] 当前用户为空，无法加载日程")
            isLoading = false
            return
        }
        
        print("🔄 [咖啡聊天] 开始加载日程")
        print("🔄 [咖啡聊天] 当前用户ID: \(currentUser.id)")
        print("🔄 [咖啡聊天] 当前用户ID类型: \(type(of: currentUser.id))")
        isLoading = true
        Task {
            do {
                let fetchedSchedules = try await supabaseService.getCoffeeChatSchedules(userId: currentUser.id)
                await MainActor.run {
                    print("📊 [咖啡聊天] 更新前 schedules.count = \(schedules.count)")
                    schedules = fetchedSchedules
                    print("📊 [咖啡聊天] 更新后 schedules.count = \(schedules.count)")
                    isLoading = false
                    print("✅ [咖啡聊天] 日程加载完成，共 \(fetchedSchedules.count) 条，isLoading = \(isLoading)")
                }
            } catch {
                print("❌ [咖啡聊天] 加载日程失败: \(error.localizedDescription)")
                print("❌ [咖啡聊天] 错误详情: \(error)")
                if let nsError = error as NSError? {
                    print("❌ [咖啡聊天] 错误域: \(nsError.domain)")
                    print("❌ [咖啡聊天] 错误代码: \(nsError.code)")
                    print("❌ [咖啡聊天] 错误信息: \(nsError.userInfo)")
                }
                await MainActor.run {
                    schedules = []
                    isLoading = false
                }
            }
        }
    }
}

struct ScheduleCardView: View {
    let schedule: CoffeeChatSchedule
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationService = LocationService.shared
    @State private var participantAvatar: String = "person.circle.fill"
    @State private var isLoadingAvatar = false
    @State private var showingDistanceAlert = false
    @State private var distanceCheckResult: DistanceCheckResult?
    @State private var isCheckingDistance = false
    @State private var alertRefreshID = UUID()
    @State private var showingCelebration = false
    @State private var hasMet: Bool
    @State private var viewRefreshID = UUID()
    @Binding var schedules: [CoffeeChatSchedule]
    
    init(schedule: CoffeeChatSchedule, schedules: Binding<[CoffeeChatSchedule]>) {
        self.schedule = schedule
        self._schedules = schedules
        self._hasMet = State(initialValue: schedule.hasMet)
        print("🔄 [ScheduleCardView] 初始化，hasMet = \(schedule.hasMet)")
    }
    
    // 计算属性：从 schedules 数组中获取最新的 schedule 数据
    private var currentSchedule: CoffeeChatSchedule {
        schedules.first(where: { $0.id == schedule.id }) ?? schedule
    }
    
    enum DistanceCheckResult: Equatable {
        case withinRange(distance: Double)
        case tooFar(distance: Double)
        case error(message: String)
        
        static func == (lhs: DistanceCheckResult, rhs: DistanceCheckResult) -> Bool {
            switch (lhs, rhs) {
            case (.withinRange(let d1), .withinRange(let d2)):
                return d1 == d2
            case (.tooFar(let d1), .tooFar(let d2)):
                return d1 == d2
            case (.error(let m1), .error(let m2)):
                return m1 == m2
            default:
                return false
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Avatar and Name
            HStack(spacing: 14) {
                // Avatar with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.9, green: 0.85, blue: 0.8),
                                    Color(red: 0.85, green: 0.8, blue: 0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    AvatarView(avatarString: participantAvatar, size: 50)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(schedule.participantName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                        
                        Text(formatDate(schedule.scheduledDate))
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                        
                        Spacer()
                        
                        // 根据 hasMet 显示 ✅ 或 "We Met" 按钮
                        // 使用最新的 schedule 数据或本地 hasMet 状态
                        let shouldShowCheckmark = hasMet || currentSchedule.hasMet
                        
                        if shouldShowCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.3))
                                .id("met-status-\(shouldShowCheckmark)")
                                .onAppear {
                                    print("✅ [UI] ✅ 图标已显示，hasMet = \(hasMet), currentSchedule.hasMet = \(currentSchedule.hasMet)")
                                }
                        } else {
                            Button(action: {
                                markAsMet(scheduleId: schedule.id.uuidString)
                            }) {
                                Text("We Met")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.98, green: 0.96, blue: 0.94),
                                                Color(red: 0.95, green: 0.92, blue: 0.88)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 0.8, green: 0.7, blue: 0.6),
                                                        Color(red: 0.7, green: 0.6, blue: 0.5)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .id("met-status-\(shouldShowCheckmark)")
                        }
                    }
                }
                
                Spacer()
            }
            
            // Divider with gradient
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3),
                    Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.3)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.vertical, 4)
            
            // Location
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.3))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.6, green: 0.45, blue: 0.3))
                }
                
                Text(schedule.location)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            // Notes
            if let notes = schedule.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                        .padding(.top, 2)
                    
                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                        .lineLimit(3)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.12), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.9, green: 0.85, blue: 0.8).opacity(0.4),
                            Color(red: 0.85, green: 0.8, blue: 0.75).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .id("schedule-card-\(schedule.id)-\(hasMet)-\(viewRefreshID)")
        .onAppear {
            loadParticipantAvatar()
        }
        .overlay {
            if showingDistanceAlert {
                customDistanceAlert
            }
        }
        .onChange(of: distanceCheckResult) { newValue in
            print("🔄 [We Met] distanceCheckResult 变化: \(newValue != nil ? "有值" : "nil")")
            if newValue != nil {
                // 当有结果时，无论 isCheckingDistance 状态如何，都显示 alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    alertRefreshID = UUID()
                    showingDistanceAlert = true
                    print("✅ [We Met] onChange: 已设置 showingDistanceAlert = true")
                }
            }
        }
        .onChange(of: isCheckingDistance) { newValue in
            print("🔄 [We Met] isCheckingDistance 变化: \(newValue)")
            if !newValue && distanceCheckResult != nil {
                // 当检查完成且有结果时，确保 alert 显示
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    alertRefreshID = UUID()
                    showingDistanceAlert = true
                    print("✅ [We Met] onChange isCheckingDistance: 已设置 showingDistanceAlert = true")
                }
            }
        }
        .overlay {
            if showingCelebration {
                celebrationView
            }
        }
    }
    
    // MARK: - Custom Distance Alert
    private var customDistanceAlert: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isCheckingDistance {
                        showingDistanceAlert = false
                        distanceCheckResult = nil
                    }
                }
            
            VStack(spacing: 20) {
                Text("We Met")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                if isCheckingDistance {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Checking distance...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                } else if let result = distanceCheckResult {
                    switch result {
                    case .withinRange(let distance):
                        let distanceText = locationService.formatDistance(distance)
                        VStack(spacing: 16) {
                            Text("You are \(distanceText) apart.")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text("You can confirm that you met!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    print("🔄 [Alert] Cancel 按钮被点击")
                                    showingDistanceAlert = false
                                    distanceCheckResult = nil
                                }) {
                                    Text("Cancel")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(red: 0.95, green: 0.92, blue: 0.88))
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    print("🔄 [Alert] Confirm 按钮被点击")
                                    showingDistanceAlert = false
                                    confirmMet(scheduleId: schedule.id.uuidString)
                                }) {
                                    Text("Confirm")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.6, green: 0.4, blue: 0.2),
                                                    Color(red: 0.4, green: 0.2, blue: 0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(12)
                                }
                            }
                        }
                    case .tooFar(let distance):
                        let distanceText = locationService.formatDistance(distance)
                        VStack(spacing: 16) {
                            Text("You are \(distanceText) apart.")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            Text("You haven't met yet and cannot confirm.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                            
                            Button(action: {
                                showingDistanceAlert = false
                                distanceCheckResult = nil
                            }) {
                                Text("OK")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.6, green: 0.4, blue: 0.2),
                                                Color(red: 0.4, green: 0.2, blue: 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    case .error(let message):
                        VStack(spacing: 16) {
                            Text(message)
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.6, green: 0.3, blue: 0.2))
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                showingDistanceAlert = false
                                distanceCheckResult = nil
                            }) {
                                Text("OK")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.6, green: 0.4, blue: 0.2),
                                                Color(red: 0.4, green: 0.2, blue: 0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Calculating distance...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .frame(width: 320)
            .id(alertRefreshID)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showingDistanceAlert)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: distanceCheckResult)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCheckingDistance)
    }
    
    // MARK: - Celebration View
    private var celebrationView: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showingCelebration = false
                    }
                }
            
            VStack(spacing: 24) {
                // 咖啡图标动画
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    .scaleEffect(showingCelebration ? 1.2 : 0.8)
                    .rotationEffect(.degrees(showingCelebration ? 10 : -10))
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: showingCelebration)
                
                // 祝福话语
                VStack(spacing: 12) {
                    Text("Connection Successful!")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text("You've successfully connected with \(schedule.participantName)!")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text("May your coffee chat be filled with great conversations!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(red: 0.6, green: 0.5, blue: 0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .opacity(showingCelebration ? 1.0 : 0.0)
                .offset(y: showingCelebration ? 0 : 20)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: showingCelebration)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.96, blue: 0.94),
                                Color(red: 0.95, green: 0.92, blue: 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.9, green: 0.85, blue: 0.8),
                                Color(red: 0.85, green: 0.8, blue: 0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .scaleEffect(showingCelebration ? 1.0 : 0.8)
            .opacity(showingCelebration ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showingCelebration)
        }
    }
    
    // MARK: - Confirm Met
    private func confirmMet(scheduleId: String) {
        print("✅ [We Met] 确认标记为已见面，scheduleId: \(scheduleId)")
        
        // 先关闭对话框
        showingDistanceAlert = false
        distanceCheckResult = nil
        
        // 获取当前用户 ID
        guard let currentUserId = authManager.currentUser?.id else {
            print("❌ [We Met] 当前用户为空，无法更新")
            return
        }
        print("✅ [We Met] 当前用户ID: \(currentUserId)")
        print("✅ [We Met] schedule.id: \(schedule.id)")
        print("✅ [We Met] schedule.id.uuidString: \(schedule.id.uuidString)")
        print("✅ [We Met] schedule.userId: \(schedule.userId)")
        print("✅ [We Met] schedule.participantId: \(schedule.participantId)")
        
        Task {
            do {
                // 更新数据库
                print("🔄 [We Met] 开始更新数据库，scheduleId: \(scheduleId)")
                try await supabaseService.markCoffeeChatAsMet(scheduleId: scheduleId, currentUserId: currentUserId)
                print("✅ [We Met] 数据库更新成功")
                
                // 更新本地状态并重新加载 schedules
                await MainActor.run {
                    print("🔄 [We Met] 更新本地状态...")
                    
                    // 立即更新本地 hasMet 状态（用于立即显示 ✅）
                    hasMet = true
                    print("✅ [We Met] hasMet 状态已更新: \(hasMet)")
                    
                    // 更新 schedules 数组中的对应项
                    if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
                        var updatedSchedule = schedules[index]
                        let newSchedule = CoffeeChatSchedule(
                            id: updatedSchedule.id,
                            userId: updatedSchedule.userId,
                            participantId: updatedSchedule.participantId,
                            participantName: updatedSchedule.participantName,
                            scheduledDate: updatedSchedule.scheduledDate,
                            location: updatedSchedule.location,
                            notes: updatedSchedule.notes,
                            createdAt: updatedSchedule.createdAt,
                            hasMet: true
                        )
                        
                        // 创建新数组以触发 SwiftUI 更新
                        var newSchedules = schedules
                        newSchedules[index] = newSchedule
                        schedules = newSchedules
                        
                        print("✅ [We Met] schedules 数组已更新，hasMet = \(schedules[index].hasMet)")
                        print("✅ [We Met] 当前 schedules 中对应项的 hasMet: \(schedules.first(where: { $0.id == schedule.id })?.hasMet ?? false)")
                    } else {
                        print("⚠️ [We Met] 未找到对应的 schedule 在数组中")
                    }
                    
                    // 强制刷新视图 ID
                    viewRefreshID = UUID()
                    print("✅ [We Met] viewRefreshID 已更新: \(viewRefreshID)")
                    
                    // 显示庆祝视图
                    print("🎉 [We Met] 显示庆祝视图")
                    showingCelebration = true
                    
                    // 立即发送通知触发重新加载（不等待3秒）
                    print("🔄 [We Met] 立即发送通知触发重新加载")
                    NotificationCenter.default.post(name: NSNotification.Name("CoffeeChatScheduleUpdated"), object: nil)
                    
                    // 3秒后自动关闭庆祝视图
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        print("🔄 [We Met] 3秒后关闭庆祝视图")
                        withAnimation {
                            showingCelebration = false
                        }
                    }
                }
            } catch {
                print("❌ [We Met] 标记失败: \(error.localizedDescription)")
                print("❌ [We Met] 错误详情: \(error)")
                await MainActor.run {
                    distanceCheckResult = .error(message: "Failed to mark as met: \(error.localizedDescription)")
                    showingDistanceAlert = true
                }
            }
        }
    }
    
    private func loadParticipantAvatar() {
        Task {
            do {
                if let profile = try await supabaseService.getProfile(userId: schedule.participantId) {
                    await MainActor.run {
                        participantAvatar = profile.coreIdentity.profileImage ?? "person.circle.fill"
                    }
                } else {
                    print("⚠️ [日程卡片] 无法获取参与者资料")
                }
            } catch {
                print("⚠️ [日程卡片] 无法加载参与者头像: \(error.localizedDescription)")
                // 保持默认头像
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func markAsMet(scheduleId: String) {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [We Met] 当前用户为空")
            return
        }
        
        print("🔄 [We Met] 开始距离检查...")
        isCheckingDistance = true
        showingDistanceAlert = true
        distanceCheckResult = nil
        
        Task {
            // 设置总超时时间为10秒
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10秒
                await MainActor.run {
                    if isCheckingDistance {
                        print("⏰ [We Met] 距离检查超时")
                        isCheckingDistance = false
                        distanceCheckResult = .error(message: "距离检查超时。请稍后重试，或确保位置权限已开启。")
                        alertRefreshID = UUID()
                    }
                }
            }
            
            do {
                // 1. 检查位置权限
                print("📍 [We Met] 检查位置权限...")
                let authStatus = locationService.authorizationStatus
                
                if authStatus == .notDetermined {
                    // 请求权限
                    locationService.requestLocationPermission()
                    // 等待权限响应（最多等待2秒）
                    for _ in 0..<20 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        if locationService.authorizationStatus != .notDetermined {
                            break
                        }
                    }
                }
                
                // 2. 获取当前用户的实时GPS位置（如果权限已授予）
                var currentUserGPS: CLLocation? = nil
                if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways || 
                   locationService.authorizationStatus == .authorizedWhenInUse || 
                   locationService.authorizationStatus == .authorizedAlways {
                    print("📍 [We Met] 获取当前用户的实时GPS位置...")
                    locationService.getCurrentLocation()
                    
                    // 等待获取当前位置（最多等待3秒）
                    for _ in 0..<30 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                        if let location = locationService.currentLocation {
                            currentUserGPS = location
                            print("✅ [We Met] 获取到当前用户GPS位置: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                            break
                        }
                        // 检查是否有错误
                        if let error = locationService.locationError {
                            print("⚠️ [We Met] 获取GPS位置时出错: \(error)")
                            break
                        }
                    }
                    
                    // 如果获取到GPS位置，更新到数据库
                    if let gps = currentUserGPS {
                        try? await supabaseService.updateUserRealTimeLocation(
                            userId: currentUser.id,
                            latitude: gps.coordinate.latitude,
                            longitude: gps.coordinate.longitude
                        )
                    }
                } else {
                    print("⚠️ [We Met] 位置权限未授予，将使用地址计算距离")
                }
                
                // 3. 获取对方的实时GPS位置
                print("📍 [We Met] 获取参与者的实时GPS位置...")
                let participantGPS = try? await supabaseService.getUserRealTimeLocation(userId: schedule.participantId)
                
                // 4. 计算距离
                if let currentGPS = currentUserGPS, let partGPS = participantGPS {
                    // 双方都有实时GPS位置，直接计算
                    print("✅ [We Met] 双方都有实时GPS位置，计算实时距离")
                    let distanceInMeters = locationService.calculateDistanceInMeters(
                        from: currentGPS,
                        to: CLLocation(latitude: partGPS.latitude, longitude: partGPS.longitude)
                    )
                    
                    timeoutTask.cancel()
                    await MainActor.run {
                        isCheckingDistance = false
                        print("📏 [We Met] 实时距离: \(locationService.formatDistance(distanceInMeters / 1000.0))")
                        
                        // 直接设置结果，自定义 alert 会自动更新
                        if distanceInMeters < 100 {
                            distanceCheckResult = .withinRange(distance: distanceInMeters / 1000.0)
                        } else {
                            distanceCheckResult = .tooFar(distance: distanceInMeters / 1000.0)
                        }
                        
                        // 强制刷新 alert
                        alertRefreshID = UUID()
                        print("✅ [We Met] 实时距离检查完成，alert 已更新")
                    }
                } else {
                    // 如果没有实时GPS位置，使用地址作为后备方案
                    print("⚠️ [We Met] 没有实时GPS位置，使用地址计算距离")
                    
                    let currentUserProfile = try await supabaseService.getProfile(userId: currentUser.id)
                    let currentUserLocation = currentUserProfile?.coreIdentity.location
                    
                    let participantProfile = try await supabaseService.getProfile(userId: schedule.participantId)
                    let participantLocation = participantProfile?.coreIdentity.location
                    
                    print("📍 [We Met] 当前用户地址: \(currentUserLocation ?? "nil")")
                    print("📍 [We Met] 参与者地址: \(participantLocation ?? "nil")")
                    
                    guard let userLoc = currentUserLocation, !userLoc.isEmpty,
                          let partLoc = participantLocation, !partLoc.isEmpty else {
                        timeoutTask.cancel()
                        await MainActor.run {
                            isCheckingDistance = false
                            let errorMsg = authStatus == .denied || authStatus == .restricted
                                ? "无法获取位置信息。请在设置中开启位置权限，或确保双方都已设置位置地址。"
                                : "无法获取位置信息。请确保双方都已设置位置，或开启位置权限以使用实时GPS位置。"
                            
                            distanceCheckResult = .error(message: errorMsg)
                            alertRefreshID = UUID()
                        }
                        return
                    }
                    
                    // 使用地址计算距离（带超时）
                    let distanceResult = await withCheckedContinuation { continuation in
                        var hasResumed = false
                        
                        locationService.calculateDistanceBetweenAddresses(
                            address1: userLoc,
                            address2: partLoc
                        ) { distance in
                            guard !hasResumed else { return }
                            hasResumed = true
                            continuation.resume(returning: distance)
                        }
                        
                        // 设置5秒超时
                        Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                    
                    timeoutTask.cancel()
                    await MainActor.run {
                        isCheckingDistance = false
                        
                        guard let distance = distanceResult else {
                            print("❌ [We Met] 距离计算返回 nil 或超时")
                            distanceCheckResult = .error(message: "无法计算距离。请检查位置信息是否正确，或稍后重试。")
                            alertRefreshID = UUID()
                            return
                        }
                        
                        print("📏 [We Met] 地址距离（公里）: \(distance)")
                        print("📏 [We Met] 地址距离（格式化）: \(locationService.formatDistance(distance))")
                        
                        // 判断距离是否小于100米（注意：distance是公里，需要转换为米）
                        let distanceInMeters = distance * 1000.0
                        print("📏 [We Met] 距离（米）: \(distanceInMeters)")
                        
                        // 直接设置结果，自定义 alert 会自动更新
                        if distanceInMeters < 100 {
                            print("✅ [We Met] 距离小于100米，可以确认见面")
                            distanceCheckResult = .withinRange(distance: distance)
                        } else {
                            print("⚠️ [We Met] 距离大于等于100米，不能确认见面")
                            distanceCheckResult = .tooFar(distance: distance)
                        }
                        
                        // 强制刷新 alert
                        alertRefreshID = UUID()
                        print("✅ [We Met] 地址距离检查完成，alert 已更新")
                    }
                }
            } catch {
                timeoutTask.cancel()
                print("❌ [We Met] 获取位置信息失败: \(error.localizedDescription)")
                await MainActor.run {
                    isCheckingDistance = false
                    distanceCheckResult = .error(message: "获取位置信息失败: \(error.localizedDescription)")
                    alertRefreshID = UUID()
                }
            }
        }
    }
}

