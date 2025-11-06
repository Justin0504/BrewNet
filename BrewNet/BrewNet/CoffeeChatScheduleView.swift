import SwiftUI

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
                    ScheduleCardView(schedule: schedule)
                        .environmentObject(supabaseService)
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
    @State private var participantAvatar: String = "person.circle.fill"
    @State private var isLoadingAvatar = false
    
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
        .onAppear {
            loadParticipantAvatar()
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
}

