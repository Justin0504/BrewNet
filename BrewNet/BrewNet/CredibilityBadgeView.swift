import SwiftUI

// MARK: - 信誉徽章显示组件

struct CredibilityBadgeView: View {
    let score: CredibilityScore
    let showDetails: Bool
    
    init(score: CredibilityScore, showDetails: Bool = false) {
        self.score = score
        self.showDetails = showDetails
    }
    
    var body: some View {
        if showDetails {
            detailedView
        } else {
            compactView
        }
    }
    
    // MARK: - Compact View (for profile cards)
    
    private var compactView: some View {
        HStack(spacing: 6) {
            Image(systemName: score.tier.icon)
                .font(.system(size: 14))
                .foregroundColor(tierColor)
            
            Text(String(format: "%.1f", score.overallScore))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tierColor)
            
            if let badge = tierBadgeText {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tierColor)
                    .cornerRadius(4)
            }
        }
    }
    
    // MARK: - Detailed View (for profile pages)
    
    private var detailedView: some View {
        VStack(spacing: 16) {
            // Score Header
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: score.tier.icon)
                        .font(.system(size: 40))
                        .foregroundColor(tierColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f", score.overallScore))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(tierColor)
                        
                        Text(score.tier.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                
                if !score.isBanned && !score.isFrozen {
                    tierBenefitsText
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .background(tierColor.opacity(0.1))
            .cornerRadius(12)
            
            // Status Alerts
            if score.isFrozen {
                frozenAlert
            }
            
            if score.isBanned {
                bannedAlert
            }
            
            // Score Breakdown
            if !score.isBanned {
                scoreBreakdownView
            }
            
            // Decay Warning
            decayWarning
        }
    }
    
    // MARK: - Score Breakdown
    
    private var scoreBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(spacing: 12) {
                breakdownRow(
                    title: "Average Rating",
                    value: String(format: "%.1f", score.averageRating),
                    weight: "70%",
                    icon: "star.fill",
                    color: .yellow
                )
                
                breakdownRow(
                    title: "Fulfillment Rate",
                    value: String(format: "%.0f%%", score.fulfillmentRate),
                    weight: "30%",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                Divider()
                
                HStack {
                    Text("Total Meetings")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("\(score.totalMeetings)")
                        .font(.system(size: 14, weight: .medium))
                }
                
                if score.totalNoShows > 0 {
                    HStack {
                        Text("No-Shows")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(score.totalNoShows)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func breakdownRow(title: String, value: String, weight: String, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                    Text(weight)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Alerts
    
    private var frozenAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Account Frozen")
                    .font(.system(size: 15, weight: .semibold))
                
                if let endDate = score.freezeEndDate {
                    Text("Unfreezes on \(formattedDate(endDate))")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var bannedAlert: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.red)
                
                Text("Account Banned")
                    .font(.system(size: 15, weight: .semibold))
            }
            
            if let reason = score.banReason {
                Text(reason)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var decayWarning: some View {
        let daysSince = CredibilityCalculator.daysSinceLastMeeting(lastMeetingDate: score.lastMeetingDate)
        
        if daysSince >= 10 {
            let warningColor: Color = daysSince >= 15 ? .red : .orange
            let warningIcon = daysSince >= 15 ? "exclamationmark.triangle.fill" : "clock.fill"
            
            HStack(spacing: 12) {
                Image(systemName: warningIcon)
                    .foregroundColor(warningColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    if daysSince >= 15 {
                        Text("Score Decaying")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(warningColor)
                        
                        Text("It's been \(daysSince) days since your last meeting. Meet someone soon to maintain your score!")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Decay Warning")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(warningColor)
                        
                        Text("\(15 - daysSince) days until your score starts decaying. Schedule a coffee chat!")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(warningColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var tierColor: Color {
        switch score.tier.color {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    private var tierBadgeText: String? {
        switch score.tier {
        case .highlyTrusted: return "VIP"
        case .wellTrusted: return "Trusted"
        case .alert, .lowTrust, .critical: return "!"
        case .banned: return "BANNED"
        default: return nil
        }
    }
    
    private var tierBenefitsText: Text {
        switch score.tier {
        case .highlyTrusted:
            return Text("🎉 Match priority +60% • PRO 30% off • Monthly free PRO lottery")
        case .wellTrusted:
            return Text("✨ Match priority +30% • PRO 20% off • 10-day PRO lottery")
        case .trusted:
            return Text("👍 Match priority +10% • PRO 10% off")
        case .alert:
            return Text("⚠️ Match priority -30% • Daily swipes limited to 3")
        case .lowTrust:
            return Text("❌ Match priority -60% • Daily swipes limited to 1 • Re-verify required")
        case .critical:
            return Text("🚨 Account frozen for 72h • Match priority -60% • Limited to 1 swipe/day")
        default:
            return Text("")
        }
    }
    
    // MARK: - Helpers
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct CredibilityBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Compact view
                CredibilityBadgeView(
                    score: sampleScore(.highlyTrusted),
                    showDetails: false
                )
                .padding()
                
                // Detailed view
                CredibilityBadgeView(
                    score: sampleScore(.highlyTrusted),
                    showDetails: true
                )
                .padding()
                
                CredibilityBadgeView(
                    score: sampleScore(.alert),
                    showDetails: true
                )
                .padding()
            }
        }
    }
    
    static func sampleScore(_ tier: CredibilityTier) -> CredibilityScore {
        var score = CredibilityScore(userId: "test")
        score.tier = tier
        
        switch tier {
        case .highlyTrusted:
            score.overallScore = 4.8
            score.averageRating = 4.9
            score.fulfillmentRate = 98
            score.totalMeetings = 25
        case .alert:
            score.overallScore = 1.8
            score.averageRating = 2.2
            score.fulfillmentRate = 75
            score.totalMeetings = 10
            score.totalNoShows = 3
        default:
            break
        }
        
        return score
    }
}

