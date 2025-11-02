import SwiftUI

// MARK: - Category Item Enum
enum CategoryItem: Identifiable {
    case intention(NetworkingIntentionType)
    case custom(String)
    
    var id: String {
        switch self {
        case .intention(let type):
            return type.rawValue
        case .custom(let name):
            return name
        }
    }
}

// MARK: - Explore Main View
struct ExploreMainView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var userProfile: BrewNetProfile?
    @State private var isLoadingProfile = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.98, green: 0.97, blue: 0.95)
                    .ignoresSafeArea()
                
                if isLoadingProfile {
                    // Loading state
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.6, green: 0.4, blue: 0.2)))
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Welcome Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Welcome to Explore")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    .padding(.horizontal, 20)
                            }
                            .padding(.top, 16)
                            
                            // Category Cards
                            let sortedCategories = getSortedCategories()
                            
                            VStack(spacing: 16) {
                                // First card - full width (user's selected category)
                                if let firstCategory = sortedCategories.first {
                                    ExploreCategoryCard(
                                        category: firstCategory,
                                        isFullWidth: true,
                                        colorIndex: 0
                                    )
                                    .padding(.horizontal, 20)
                                }
                                
                                // Remaining 4 cards - all same size, side by side in pairs
                                // This includes categories 2-4 + Out of Orbit
                                let remainingCategories = Array(sortedCategories.dropFirst())
                                let allRemainingCategories: [CategoryItem] = remainingCategories.map { .intention($0) } + [.custom("Out of Orbit")]
                                
                                ForEach(0..<2, id: \.self) { rowIndex in
                                    HStack(spacing: 16) {
                                        let startIndex = rowIndex * 2
                                        let endIndex = min(startIndex + 2, allRemainingCategories.count)
                                        
                                        ForEach(startIndex..<endIndex, id: \.self) { index in
                                            let item = allRemainingCategories[index]
                                            let colorIndex = index + 1 // Color index 1-4 for remaining categories
                                            
                                            Group {
                                                switch item {
                                                case .intention(let intention):
                                                    ExploreCategoryCard(
                                                        category: intention,
                                                        isFullWidth: false,
                                                        colorIndex: colorIndex
                                                    )
                                                case .custom(let name):
                                                    ExploreCategoryCard(
                                                        categoryName: name,
                                                        isFullWidth: false,
                                                        colorIndex: colorIndex
                                                    )
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    // MARK: - Get Sorted Categories
    private func getSortedCategories() -> [NetworkingIntentionType] {
        let allCategories: [NetworkingIntentionType] = [
            .learnGrow,
            .connectShare,
            .buildCollaborate,
            .unwindChat
        ]
        
        // If user has selected a main networking intention, put it first
        if let profile = userProfile {
            let mainIntention = profile.networkingIntention.selectedIntention
            var sorted = allCategories
            if let index = sorted.firstIndex(of: mainIntention) {
                sorted.remove(at: index)
                sorted.insert(mainIntention, at: 0)
            }
            return sorted
        }
        
        // Default order if no profile loaded
        return allCategories
    }
    
    // MARK: - Load User Profile
    private func loadUserProfile() {
        guard let currentUser = authManager.currentUser else {
            isLoadingProfile = false
            return
        }
        
        Task {
            do {
                if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    await MainActor.run {
                        self.userProfile = supabaseProfile.toBrewNetProfile()
                        self.isLoadingProfile = false
                    }
                } else {
                    await MainActor.run {
                        self.userProfile = nil
                        self.isLoadingProfile = false
                    }
                }
            } catch {
                print("❌ Failed to load user profile: \(error)")
                await MainActor.run {
                    self.userProfile = nil
                    self.isLoadingProfile = false
                }
            }
        }
    }
}

// MARK: - Explore Category Card
struct ExploreCategoryCard: View {
    let category: NetworkingIntentionType?
    let categoryName: String?
    let isFullWidth: Bool
    let colorIndex: Int
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseService: SupabaseService
    @State private var userCount: Int = Int.random(in: 100...2500)
    @State private var showCategoryDetail = false
    
    init(category: NetworkingIntentionType, isFullWidth: Bool, colorIndex: Int = 0) {
        self.category = category
        self.categoryName = nil
        self.isFullWidth = isFullWidth
        self.colorIndex = colorIndex
    }
    
    init(categoryName: String, isFullWidth: Bool, colorIndex: Int = 0) {
        self.category = nil
        self.categoryName = categoryName
        self.isFullWidth = isFullWidth
        self.colorIndex = colorIndex
    }
    
    var body: some View {
        Button(action: {
            showCategoryDetail = true
        }) {
            ZStack {
                // Card Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(categoryColor)
                    .frame(height: isFullWidth ? 200 : 180)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Top section with user count badge
                    HStack {
                        Spacer()
                        
                        // User count badge
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.white)
                            
                            Text(formatUserCount(userCount))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(14)
                    }
                    
                    Spacer()
                    
                    // Category icon (centered at top)
                    HStack {
                        categoryIcon
                            .font(.system(size: isFullWidth ? 48 : 40))
                            .foregroundColor(.white)
                            .opacity(0.9)
                        
                        Spacer()
                    }
                    
                    // Category name
                    Text(displayName)
                        .font(.system(size: isFullWidth ? 24 : 20, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(20)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .fullScreenCover(isPresented: $showCategoryDetail) {
            if let category = category {
                CategoryRecommendationsView(category: category)
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            } else {
                CategoryRecommendationsView(categoryName: categoryName ?? "Out of Orbit")
                    .environmentObject(authManager)
                    .environmentObject(supabaseService)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var displayName: String {
        if let category = category {
            return category.displayName
        } else if let categoryName = categoryName {
            return categoryName
        }
        return ""
    }
    
    // MARK: - Category Properties
    private var categoryColor: Color {
        // Use colorIndex to assign unique colors to all 5 categories
        // All colors are in the brown/beige theme
        switch colorIndex {
        case 0:
            // First category (user's selected) - Deep coffee brown
            return Color(red: 0.45, green: 0.3, blue: 0.2)
        case 1:
            // Second category - Medium coffee brown
            return Color(red: 0.6, green: 0.45, blue: 0.3)
        case 2:
            // Third category - Light coffee brown
            return Color(red: 0.75, green: 0.6, blue: 0.45)
        case 3:
            // Fourth category - Latte color
            return Color(red: 0.85, green: 0.75, blue: 0.65)
        case 4:
            // Fifth category (Out of Orbit) - Beige/cream
            return Color(red: 0.92, green: 0.88, blue: 0.8)
        default:
            // Fallback
            return Color(red: 0.7, green: 0.55, blue: 0.4)
        }
    }
    
    private var categoryIcon: Image {
        if let category = category {
            switch category {
            case .learnGrow:
                // Growth/learning icon - sparkles for learning and growth
                return Image(systemName: "sparkles")
            case .connectShare:
                // Connection icon - heart for connecting and sharing
                return Image(systemName: "heart.fill")
            case .buildCollaborate:
                // Collaboration icon - two people for building and collaborating
                return Image(systemName: "person.2.fill")
            case .unwindChat:
                // Chat/relax icon - coffee/chat for unwinding
                return Image(systemName: "cup.and.saucer.fill")
            }
        } else {
            // Out of Orbit icon - use something space/exploration related
            return Image(systemName: "globe.americas.fill")
        }
    }
    
    private func formatUserCount(_ count: Int) -> String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            if thousands >= 10 {
                return String(format: "%.0fK", thousands)
            } else {
                return String(format: "%.1fK", thousands)
            }
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Preview
struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreMainView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseService.shared)
    }
}

