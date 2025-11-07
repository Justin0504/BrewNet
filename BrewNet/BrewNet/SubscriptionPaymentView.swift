import SwiftUI

// MARK: - Subscription Payment View
struct SubscriptionPaymentView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var selectedPlan: SubscriptionPlan = .threeMonths
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let currentUserId: String
    let onSubscriptionComplete: (() -> Void)?
    
    init(currentUserId: String, onSubscriptionComplete: (() -> Void)? = nil) {
        self.currentUserId = currentUserId
        self.onSubscriptionComplete = onSubscriptionComplete
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section
                        VStack(spacing: 12) {
                            // Hero image/graphic area
                            ZStack {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.95, green: 0.85, blue: 0.7),
                                        Color(red: 0.85, green: 0.75, blue: 0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(height: 200)
                                .cornerRadius(16)
                                
                                VStack(spacing: 8) {
                                    ProBadge(size: .large)
                                        .scaleEffect(2.0)
                                    
                                    Text("Match faster\nConnect smarter\nGrow further")
                                        .font(.system(size: 24, weight: .bold))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.white)
                                        .padding(.top, 24)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                        
                        // Pricing plans
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                PricingCard(
                                    plan: .oneWeek,
                                    isSelected: selectedPlan == .oneWeek,
                                    action: { selectedPlan = .oneWeek }
                                )
                                
                                PricingCard(
                                    plan: .oneMonth,
                                    isSelected: selectedPlan == .oneMonth,
                                    action: { selectedPlan = .oneMonth }
                                )
                            }
                            
                            HStack(spacing: 12) {
                                PricingCard(
                                    plan: .threeMonths,
                                    isSelected: selectedPlan == .threeMonths,
                                    action: { selectedPlan = .threeMonths }
                                )
                                
                                PricingCard(
                                    plan: .sixMonths,
                                    isSelected: selectedPlan == .sixMonths,
                                    action: { selectedPlan = .sixMonths }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Benefits list
                        VStack(alignment: .leading, spacing: 16) {
                            BenefitRow(icon: "infinity", text: "Unlimited likes")
                            BenefitRow(icon: "message.fill", text: "Initiate temporary chats")
                            BenefitRow(icon: "arrow.up.circle.fill", text: "Priority placement in request lists")
                            BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Boosted visibility in recommendations")
                            BenefitRow(icon: "slider.horizontal.3", text: "Access all premium filters")
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .padding(.bottom, 20) // 给底部按钮留出空间
                    }
                }
                
                // Fixed bottom section with button and terms
                VStack(spacing: 12) {
                    // Subscribe button
                    Button(action: {
                        Task {
                            await subscribeToPro()
                        }
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Get \(selectedPlan.duration) for \(selectedPlan.totalPrice)")
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.5, green: 0.3, blue: 0.7),
                                    Color(red: 0.6, green: 0.4, blue: 0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(28)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal, 20)
                    
                    // Terms text
                    Text("By tapping \"Subscribe,\" you agree to our Terms and understand that your subscription auto-renews for the same price and duration unless canceled (at any time) via App Store settings.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Subscribe Action
    private func subscribeToPro() async {
        isProcessing = true
        
        do {
            // Calculate Pro end date based on selected plan
            let duration = selectedPlan.durationInSeconds
            try await supabaseService.upgradeUserToPro(userId: currentUserId, durationSeconds: duration)
            
            // Dismiss and notify completion
            await MainActor.run {
                isProcessing = false
                onSubscriptionComplete?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to process subscription: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

// MARK: - Subscription Plan Model
enum SubscriptionPlan: CaseIterable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    
    var label: String {
        switch self {
        case .oneWeek: return "New"
        case .oneMonth: return "Save 47%"
        case .threeMonths: return "Save 65%"
        case .sixMonths: return "Save 71%"
        }
    }
    
    var duration: String {
        switch self {
        case .oneWeek: return "1 week"
        case .oneMonth: return "1 month"
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        }
    }
    
    var weeklyPrice: String {
        switch self {
        case .oneWeek: return "$19.99/wk"
        case .oneMonth: return "$10.49/wk"
        case .threeMonths: return "$6.99/wk"
        case .sixMonths: return "$5.83/wk"
        }
    }
    
    var totalPrice: String {
        switch self {
        case .oneWeek: return "$19.99"
        case .oneMonth: return "$41.96"
        case .threeMonths: return "$89.99"
        case .sixMonths: return "$149.99"
        }
    }
    
    var durationInSeconds: TimeInterval {
        switch self {
        case .oneWeek: return 7 * 24 * 60 * 60
        case .oneMonth: return 30 * 24 * 60 * 60
        case .threeMonths: return 90 * 24 * 60 * 60
        case .sixMonths: return 180 * 24 * 60 * 60
        }
    }
    
    var highlightColor: Color {
        switch self {
        case .threeMonths: return Color(red: 0.6, green: 0.4, blue: 0.8)
        default: return Color.clear
        }
    }
}

// MARK: - Pricing Card Component
struct PricingCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Label badge
                Text(plan.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .gray)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
                    .background(
                        isSelected
                            ? AnyView(Color(red: 0.6, green: 0.4, blue: 0.8))
                            : AnyView(Color.gray.opacity(0.1))
                    )
                    .cornerRadius(4)
                
                Spacer()
                
                // Duration
                Text(plan.duration)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .gray)
                
                // Price
                Text(plan.weeklyPrice)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .primary : .gray)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? Color(red: 0.6, green: 0.4, blue: 0.8)
                            : Color.gray.opacity(0.3),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.05) : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Benefit Row Component
struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 0.8))
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Pro Expiry Popup
struct ProExpiryPopup: View {
    @Environment(\.dismiss) var dismiss
    let onStayPro: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(8)
                    }
                }
                
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "star.slash.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                }
                
                // Title and message
                VStack(spacing: 12) {
                    Text("Your Pro has expired")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Continue enjoying unlimited likes, temporary chats, and premium features.")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Stay Pro button
                Button(action: {
                    dismiss()
                    onStayPro()
                }) {
                    Text("Stay Pro")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.84, blue: 0.0),
                                    Color(red: 1.0, green: 0.65, blue: 0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                }
                .padding(.horizontal)
                
                // Maybe later button
                Button(action: { dismiss() }) {
                    Text("Maybe Later")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
            )
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview
struct SubscriptionPaymentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SubscriptionPaymentView(currentUserId: "test-user-id")
            
            ProExpiryPopup(onStayPro: {})
        }
    }
}

