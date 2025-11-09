import SwiftUI

// MARK: - User Profile Model
struct UserProfile: Identifiable, Codable {
    let id: UUID
    let name: String
    let age: Int
    let company: String
    let jobTitle: String
    let skills: [String]
    let bio: String
    let imageName: String
    let location: String
    let education: String
    let interests: [String]
    
    init(name: String, age: Int, company: String, jobTitle: String, skills: [String], bio: String, imageName: String, location: String, education: String, interests: [String]) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.company = company
        self.jobTitle = jobTitle
        self.skills = skills
        self.bio = bio
        self.imageName = imageName
        self.location = location
        self.education = education
        self.interests = interests
    }
}

// MARK: - Swipe Direction
enum SwipeDirection {
    case left
    case right
    case none
}

// MARK: - Profile Card View
struct ProfileCardView: View {
    let profile: UserProfile
    @Binding var dragOffset: CGSize
    @Binding var rotationAngle: Double
    let onSwipe: (SwipeDirection) -> Void
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 0) {
                // Profile Image
                ZStack(alignment: .topTrailing) {
                    // Use placeholder image with gradient background
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.6, green: 0.4, blue: 0.2),
                                Color(red: 0.4, green: 0.2, blue: 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        VStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text(profile.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: screenHeight * 0.6)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                    
                    // Like/Pass indicators
                    if abs(dragOffset.width) > 50 {
                        VStack {
                            if dragOffset.width > 0 {
                                // Like indicator
                                VStack {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red)
                                    Text("LIKE")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(15)
                                .rotationEffect(.degrees(-15))
                            } else {
                                // Pass indicator
                                VStack {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(.red)
                                    Text("PASS")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(15)
                                .rotationEffect(.degrees(15))
                            }
                        }
                        .offset(x: dragOffset.width > 0 ? 20 : -20, y: 50)
                    }
                }
                
                // Profile Information
                VStack(alignment: .leading, spacing: 12) {
                    // Name and Age
                    HStack {
                        Text("\(profile.name), \(profile.age)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                        Spacer()
                    }
                    
                    // Company and Job Title
                    HStack {
                        Text("\(profile.company) · \(profile.jobTitle)")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    // Skills Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(profile.skills, id: \.self) { skill in
                                Text(skill)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    
                    // Bio
                    Text(profile.bio)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    // Location and Education
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            Text(profile.location)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Image(systemName: "graduationcap")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                            Text(profile.education)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(32)
            }
        }
        .frame(width: screenWidth - 8, height: screenHeight * 0.8)
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
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Sample Data
let sampleProfiles = [
    UserProfile(
        name: "Sarah Chen",
        age: 28,
        company: "TechCorp",
        jobTitle: "Product Manager",
        skills: ["Product Strategy", "User Research", "Agile", "Data Analysis"],
        bio: "Passionate about creating products that make a difference. Love hiking and trying new coffee shops on weekends.",
        imageName: "profile1",
        location: "San Francisco, CA",
        education: "Stanford University",
        interests: ["Technology", "Travel", "Coffee", "Hiking"]
    ),
    UserProfile(
        name: "Mike Rodriguez",
        age: 32,
        company: "StartupXYZ",
        jobTitle: "Software Engineer",
        skills: ["iOS Development", "Swift", "React Native", "Backend"],
        bio: "Full-stack developer with a passion for mobile apps. When I'm not coding, you'll find me playing guitar or exploring the city.",
        imageName: "profile2",
        location: "New York, NY",
        education: "MIT",
        interests: ["Music", "Technology", "Photography", "Fitness"]
    ),
    UserProfile(
        name: "Emma Wilson",
        age: 26,
        company: "DesignStudio",
        jobTitle: "UX Designer",
        skills: ["UI/UX Design", "Figma", "User Testing", "Prototyping"],
        bio: "Creative designer who believes good design can change the world. Love art galleries and weekend brunches.",
        imageName: "profile3",
        location: "Los Angeles, CA",
        education: "Art Center College",
        interests: ["Design", "Art", "Food", "Yoga"]
    ),
    UserProfile(
        name: "Alex Kim",
        age: 30,
        company: "FinanceCorp",
        jobTitle: "Data Scientist",
        skills: ["Python", "Machine Learning", "SQL", "Statistics"],
        bio: "Data enthusiast who loves finding patterns in numbers. Enjoy board games and trying new restaurants.",
        imageName: "profile4",
        location: "Seattle, WA",
        education: "University of Washington",
        interests: ["Data Science", "Board Games", "Food", "Travel"]
    ),
    UserProfile(
        name: "Lisa Zhang",
        age: 29,
        company: "MarketingPro",
        jobTitle: "Marketing Manager",
        skills: ["Digital Marketing", "Content Strategy", "Analytics", "Social Media"],
        bio: "Marketing strategist who loves storytelling and connecting with people. Coffee addict and book lover.",
        imageName: "profile5",
        location: "Austin, TX",
        education: "University of Texas",
        interests: ["Marketing", "Books", "Coffee", "Networking"]
    )
]

// MARK: - Preview
struct ProfileCardView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileCardView(
            profile: sampleProfiles[0],
            dragOffset: .constant(.zero),
            rotationAngle: .constant(0),
            onSwipe: { _ in }
        )
    }
}
