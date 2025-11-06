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
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    private func loadSchedules() {
        guard let currentUser = authManager.currentUser else {
            isLoading = false
            return
        }
        
        isLoading = true
        Task {
            do {
                let fetchedSchedules = try await supabaseService.getCoffeeChatSchedules(userId: currentUser.id)
                await MainActor.run {
                    schedules = fetchedSchedules
                    isLoading = false
                }
            } catch {
                print("❌ Failed to load schedules: \(error.localizedDescription)")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.participantName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                    
                    Text(formatDate(schedule.scheduledDate))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                
                Text(schedule.location)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
            }
            
            if let notes = schedule.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

