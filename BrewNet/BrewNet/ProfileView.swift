import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var showLogoutAlert = false
    @State private var showUpgradeAlert = false
    @State private var viewedPosts: [Post] = []
    @State private var likedPosts: [Post] = []
    @State private var savedPosts: [Post] = []
    @State private var matchedUsers: [UserProfile] = []
    @State private var coffeeChatSchedules: [CoffeeChatSchedule] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // User Header
                userHeaderView
                
                // Tab Selection
                tabSelectionView
                
                // Content
                TabView(selection: $selectedTab) {
                    // Browse History
                    PostHistoryView(posts: viewedPosts)
                        .tag(0)
                    
                    // My Likes
                    LikedPostsView(posts: likedPosts)
                        .tag(1)
                    
                    // My Saved Posts
                    SavedPostsView(posts: savedPosts)
                        .tag(2)
                    
                    // Matched Users
                    MatchedUsersView(users: matchedUsers)
                        .tag(3)
                    
                    // Calendar Appointments
                    CalendarView(schedules: coffeeChatSchedules)
                        .tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Edit Profile") {
                            // Edit profile action
                        }
                        
                        Button("Settings") {
                            // Settings action
                        }
                        
                        Divider()
                        
                        Button(authManager.isCurrentUserGuest() ? "Exit Guest Mode" : "Logout", role: .destructive) {
                            showLogoutAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    }
                }
            }
        }
        .onAppear {
            loadUserData()
        }
        .alert("Confirm Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button(authManager.isCurrentUserGuest() ? "Exit Guest Mode" : "Logout", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text(authManager.isCurrentUserGuest() ? 
                 "Are you sure you want to exit guest mode? Your data will not be saved." : 
                 "Are you sure you want to logout?")
        }
        .alert("Upgrade to Regular User", isPresented: $showUpgradeAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Upgrade Later") { }
            Button("Upgrade Now") {
                // Navigate to registration page
            }
        } message: {
            Text("After upgrading to a regular user, your data will be permanently saved and you'll enjoy full functionality.")
        }
    }
    
    // MARK: - User Header View
    private var userHeaderView: some View {
        VStack(spacing: 16) {
            // User avatar and basic information
            VStack(spacing: 12) {
                // User avatar
                ZStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.2))
                    
                    // Guest indicator
                    if authManager.isCurrentUserGuest() {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 24, height: 24)
                                    )
                                    .offset(x: 8, y: 8)
                            }
                        }
                    }
                }
                
                if let user = authManager.currentUser {
                    VStack(spacing: 6) {
                        HStack {
                            Text(user.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            
                            if user.isGuest {
                                Text("Guest")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }
                        }
                        
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if user.isGuest {
                            Text("Guest mode - data will not be saved")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // Guest upgrade button
            if authManager.isCurrentUserGuest() {
                Button(action: {
                    showUpgradeAlert = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Upgrade to Regular User")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
    
    // MARK: - Tab Selection View
    private var tabSelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<5) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: tabIcon(for: index))
                                .font(.system(size: 16))
                            
                            Text(tabTitle(for: index))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(selectedTab == index ? Color(red: 0.4, green: 0.2, blue: 0.1) : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == index ? 
                            Color(red: 0.4, green: 0.2, blue: 0.1).opacity(0.1) : 
                            Color.clear
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "clock"
        case 1: return "heart.fill"
        case 2: return "bookmark.fill"
        case 3: return "person.2.fill"
        case 4: return "calendar"
        default: return "circle"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "History"
        case 1: return "Liked"
        case 2: return "Saved"
        case 3: return "Matches"
        case 4: return "Calendar"
        default: return ""
        }
    }
    
    // MARK: - Load User Data
    private func loadUserData() {
        // Load viewed posts (simulate data)
        viewedPosts = samplePosts.prefix(10).map { $0 }
        
        // Load liked posts (simulate data)
        likedPosts = samplePosts.filter { _ in Bool.random() }.prefix(5).map { $0 }
        
        // Load saved posts (simulate data)
        savedPosts = samplePosts.filter { _ in Bool.random() }.prefix(3).map { $0 }
        
        // Load matched users (simulate data)
        matchedUsers = sampleProfiles.filter { _ in Bool.random() }.prefix(4).map { $0 }
        
        // Load coffee chat schedules (simulate data)
        coffeeChatSchedules = sampleCoffeeChatSchedules
    }
}

// MARK: - Post History View
struct PostHistoryView: View {
    let posts: [Post]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(posts) { post in
                    PostCardView(post: post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}

// MARK: - Liked Posts View
struct LikedPostsView: View {
    let posts: [Post]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(posts) { post in
                    LikedPostCardView(post: post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}

// MARK: - Saved Posts View
struct SavedPostsView: View {
    let posts: [Post]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(posts) { post in
                    SavedPostCardView(post: post)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}

// MARK: - Matched Users View
struct MatchedUsersView: View {
    let users: [UserProfile]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(users) { user in
                    MatchedUserCardView(user: user)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    let schedules: [CoffeeChatSchedule]
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    var body: some View {
        VStack(spacing: 16) {
            // Calendar Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Spacer()
                
                Text(monthYearFormatter.string(from: currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            
            // Calendar Grid
            CalendarGridView(selectedDate: $selectedDate, currentMonth: $currentMonth, schedules: schedules)
            
            // Schedule List
            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming Coffee Chats")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .padding(.horizontal, 20)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSchedules) { schedule in
                            CoffeeChatScheduleCard(schedule: schedule)
                        }
                        
                        if filteredSchedules.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                
                                Text("No Coffee Chats Scheduled")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("Schedule your first coffee chat to get started!")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    private var filteredSchedules: [CoffeeChatSchedule] {
        let calendar = Calendar.current
        return schedules.filter { schedule in
            calendar.isDate(schedule.date, equalTo: selectedDate, toGranularity: .day)
        }
    }
}

// MARK: - Liked Post Card View
struct LikedPostCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                
                Text("Liked")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(timeAgoString(from: Date()))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            PostCardView(post: post)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Saved Post Card View
struct SavedPostCardView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .font(.system(size: 16))
                
                Text("Saved")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Spacer()
                
                Text(timeAgoString(from: Date()))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            PostCardView(post: post)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Matched User Card View
struct MatchedUserCardView: View {
    let user: UserProfile
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.6, green: 0.4, blue: 0.2),
                                Color(red: 0.4, green: 0.2, blue: 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(user.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    .lineLimit(1)
                
                Text(user.jobTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Text("Matched")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Calendar Grid View
struct CalendarGridView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let schedules: [CoffeeChatSchedule]
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        hasSchedule: hasScheduleOnDate(date),
                        onTap: {
                            selectedDate = date
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < monthLastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func hasScheduleOnDate(_ date: Date) -> Bool {
        return schedules.contains { schedule in
            calendar.isDate(schedule.date, inSameDayAs: date)
        }
    }
}

// MARK: - Calendar Day View
struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasSchedule: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if hasSchedule {
                    Circle()
                        .fill(isSelected ? .white : Color(red: 0.4, green: 0.2, blue: 0.1))
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                isSelected ? 
                Color(red: 0.4, green: 0.2, blue: 0.1) : 
                Color.clear
            )
            .cornerRadius(16)
        }
        .disabled(!calendar.isDate(date, equalTo: Date(), toGranularity: .month))
        .opacity(calendar.isDate(date, equalTo: Date(), toGranularity: .month) ? 1.0 : 0.3)
    }
}

// MARK: - Coffee Chat Schedule Card
struct CoffeeChatScheduleCard: View {
    let schedule: CoffeeChatSchedule
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(timeFormatter.string(from: schedule.date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text(dateFormatter.string(from: schedule.date))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .frame(width: 60)
            
            // Schedule details
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("with \(schedule.participantName)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text(schedule.location)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(schedule.status.color)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }
}

// MARK: - Coffee Chat Schedule Model
struct CoffeeChatSchedule: Identifiable, Codable {
    let id = UUID()
    let title: String
    let participantName: String
    let date: Date
    let location: String
    let status: ScheduleStatus
    
    init(title: String, participantName: String, date: Date, location: String, status: ScheduleStatus = .confirmed) {
        self.title = title
        self.participantName = participantName
        self.date = date
        self.location = location
        self.status = status
    }
}

// MARK: - Schedule Status
enum ScheduleStatus: String, Codable, CaseIterable {
    case confirmed = "confirmed"
    case pending = "pending"
    case cancelled = "cancelled"
    case completed = "completed"
    
    var color: Color {
        switch self {
        case .confirmed:
            return .green
        case .pending:
            return .orange
        case .cancelled:
            return .red
        case .completed:
            return .blue
        }
    }
    
    var displayName: String {
        switch self {
        case .confirmed:
            return "Confirmed"
        case .pending:
            return "Pending"
        case .cancelled:
            return "Cancelled"
        case .completed:
            return "Completed"
        }
    }
}

// MARK: - Sample Coffee Chat Schedules
let sampleCoffeeChatSchedules = [
    CoffeeChatSchedule(
        title: "Coffee Chat",
        participantName: "Sarah Chen",
        date: Date().addingTimeInterval(3600), // 1 hour from now
        location: "Starbucks Downtown",
        status: .confirmed
    ),
    CoffeeChatSchedule(
        title: "Networking Meetup",
        participantName: "Mike Rodriguez",
        date: Date().addingTimeInterval(86400), // Tomorrow
        location: "Blue Bottle Coffee",
        status: .pending
    ),
    CoffeeChatSchedule(
        title: "Career Discussion",
        participantName: "Emma Wilson",
        date: Date().addingTimeInterval(172800), // Day after tomorrow
        location: "Local Cafe",
        status: .confirmed
    ),
    CoffeeChatSchedule(
        title: "Tech Talk",
        participantName: "Alex Kim",
        date: Date().addingTimeInterval(-86400), // Yesterday
        location: "Peet's Coffee",
        status: .completed
    )
]

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthManager())
    }
}
