import SwiftUI

// MARK: - 见面后评分界面

struct MeetingRatingView: View {
    let meetingId: String
    let otherUserId: String
    let otherUserName: String
    @Environment(\.dismiss) var dismiss
    
    @State private var rating: Double = 3.0
    @State private var selectedTags: Set<RatingTag> = []
    @State private var showReportSheet = false
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How was your Coffee Chat?")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("Please rate your in-person meeting. Your feedback helps BrewNet maintain a professional, safe, and high-quality networking environment.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    // Star Rating
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Rating")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Drag to set your overall experience rating.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        // Star Display
                        HStack(spacing: 8) {
                            ForEach(0..<5) { index in
                                ZStack {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.2))
                                    
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.yellow)
                                        .mask(
                                            GeometryReader { geometry in
                                                let starProgress = rating - Double(index)
                                                let fillWidth = geometry.size.width * min(max(starProgress, 0), 1)
                                                Rectangle()
                                                    .frame(width: fillWidth)
                                            }
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Slider
                        VStack(spacing: 8) {
                            Slider(value: $rating, in: 0.5...5.0, step: 0.5)
                                .accentColor(.yellow)
                            
                            Text(ratingDescription)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ratingColor)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Rating Scale Reference
                        VStack(alignment: .leading, spacing: 6) {
                            ratingReferenceRow(stars: "5.0 ★", description: "Excellent — Highly valuable conversation")
                            ratingReferenceRow(stars: "4.0 ★", description: "Good — Smooth and insightful")
                            ratingReferenceRow(stars: "3.0 ★", description: "Fair — Average experience")
                            ratingReferenceRow(stars: "2.0 ★", description: "Poor — Below expectations")
                            ratingReferenceRow(stars: "1.0 ★", description: "Very Poor — Would not meet again")
                            ratingReferenceRow(stars: "0.5 ★", description: "Unacceptable — Seriously negative experience")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Optional Tags
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Why this rating? (Optional)")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Select any reasons that apply. These tags help us improve recommendations.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        // Positive Tags
                        tagSection(title: "Positive", tags: positiveTags, color: .green)
                        
                        // Neutral Tags
                        tagSection(title: "Neutral", tags: neutralTags, color: .blue)
                        
                        // Negative Tags
                        tagSection(title: "Negative", tags: negativeTags, color: .orange)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Misconduct Report Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Serious Misconduct Report Section")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("If you experienced any of the following during your Coffee Chat, please report it immediately:")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            misconductBullet("Violence, threats, or intimidation")
                            misconductBullet("Sexual harassment, inappropriate comments, or unwanted physical contact")
                            misconductBullet("Stalking or invasion of privacy")
                            misconductBullet("Fraud, impersonation, or coercive sales")
                            misconductBullet("Any other behavior that clearly violates professional conduct")
                        }
                        .font(.system(size: 13))
                        
                        Text("If verified by our Safety Team:")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• The user's score will be reset to 0.0")
                            Text("• Their account will be permanently banned")
                            Text("• Their profile will be removed from all matching pools")
                            Text("• You will not be matched or contacted by this user again")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        
                        Button(action: {
                            showReportSheet = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Report Serious Misconduct")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Submit Button
                    Button(action: submitRating) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Submit Rating")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.brown)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .disabled(isSubmitting)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showReportSheet) {
                MisconductReportView(
                    reportedUserId: otherUserId,
                    reportedUserName: otherUserName,
                    meetingId: meetingId
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func ratingReferenceRow(stars: String, description: String) -> some View {
        HStack(spacing: 8) {
            Text(stars)
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            Text(description)
        }
    }
    
    private func tagSection(title: String, tags: [RatingTag], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        color: color,
                        action: {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private func misconductBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
    
    // MARK: - Computed Properties
    
    private var ratingDescription: String {
        switch rating {
        case 4.6...5.0: return "Excellent — \(String(format: "%.1f", rating)) ★"
        case 3.6..<4.6: return "Good — \(String(format: "%.1f", rating)) ★"
        case 2.6..<3.6: return "Fair — \(String(format: "%.1f", rating)) ★"
        case 1.6..<2.6: return "Poor — \(String(format: "%.1f", rating)) ★"
        case 0.6..<1.6: return "Very Poor — \(String(format: "%.1f", rating)) ★"
        default: return "Unacceptable — \(String(format: "%.1f", rating)) ★"
        }
    }
    
    private var ratingColor: Color {
        switch rating {
        case 4.0...5.0: return .green
        case 3.0..<4.0: return .blue
        case 2.0..<3.0: return .orange
        default: return .red
        }
    }
    
    private var positiveTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .positive }
    }
    
    private var neutralTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .neutral }
    }
    
    private var negativeTags: [RatingTag] {
        RatingTag.allCases.filter { $0.category == .negative }
    }
    
    // MARK: - Actions
    
    private func submitRating() {
        isSubmitting = true
        
        // TODO: Submit to backend
        // 1. Create MeetingRating record
        // 2. Update CredibilityScore for otherUser
        // 3. Check for GPS verification
        // 4. Apply anti-cheating checks
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSubmitting = false
            dismiss()
        }
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: RatingTag
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag.rawValue)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.2) : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? color : .gray)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Preview

struct MeetingRatingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingRatingView(
            meetingId: "meeting123",
            otherUserId: "user456",
            otherUserName: "John Doe"
        )
    }
}

