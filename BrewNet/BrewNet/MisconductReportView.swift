import SwiftUI

// MARK: - 举报严重不当行为界面

struct MisconductReportView: View {
    let reportedUserId: String
    let reportedUserName: String
    let meetingId: String?
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType: MisconductType?
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var needsFollowUp: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccessScreen: Bool = false
    
    init(reportedUserId: String, reportedUserName: String, meetingId: String? = nil) {
        self.reportedUserId = reportedUserId
        self.reportedUserName = reportedUserName
        self.meetingId = meetingId
    }
    
    var body: some View {
        if showSuccessScreen {
            ReportSubmittedView()
        } else {
            reportForm
        }
    }
    
    private var reportForm: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Report Serious Misconduct")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("Please describe what happened during your Coffee Chat.")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        Text("Your identity and report will be kept strictly confidential.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    // Misconduct Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type of Misconduct")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Select the category that best describes what happened:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        ForEach(MisconductType.allCases, id: \.self) { type in
                            MisconductTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: {
                                    selectedType = type
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Incident Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Incident Description")
                                .font(.system(size: 18, weight: .semibold))
                            Text("*")
                                .foregroundColor(.red)
                        }
                        
                        Text("Please provide details about what happened:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Location (Optional)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location of the Meeting (Optional)")
                            .font(.system(size: 18, weight: .semibold))
                        
                        TextField("e.g., Starbucks on Main Street", text: $location)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Evidence Upload
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upload Supporting Evidence (Optional)")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("You can upload screenshots, photos, or other relevant files.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            // TODO: Implement file picker
                        }) {
                            HStack {
                                Image(systemName: "paperclip")
                                Text("Attach Files")
                            }
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Follow-up
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $needsFollowUp) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Would you like BrewNet Safety Team to follow up with you?")
                                    .font(.system(size: 15))
                                Text("We may contact you for additional information")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .brown))
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Warning Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important Notice")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        
                        Text("False reports can result in account suspension. Only report serious misconduct that genuinely occurred. For normal dissatisfaction with the meeting, please use the regular rating system instead.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    
                    // Submit Button
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Submit Report")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(canSubmit ? Color.red : Color.gray)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
    
    private var canSubmit: Bool {
        selectedType != nil && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitReport() {
        guard let type = selectedType else { return }
        
        isSubmitting = true
        
        // TODO: Submit to backend
        let report = MisconductReport(
            reporterId: "current_user_id", // TODO: Get from auth
            reportedUserId: reportedUserId,
            meetingId: meetingId,
            misconductType: type,
            description: description,
            location: location.isEmpty ? nil : location,
            evidence: nil, // TODO: Upload files first
            needsFollowUp: needsFollowUp
        )
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showSuccessScreen = true
        }
    }
}

// MARK: - Misconduct Type Button

struct MisconductTypeButton: View {
    let type: MisconductType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<type.severity, id: \.self) { _ in
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(isSelected ? Color.red.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Report Submitted View

struct ReportSubmittedView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Report Received")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Our Safety Team is reviewing your case.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What happens next:")
                    .font(.system(size: 16, weight: .semibold))
                
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(icon: "person.badge.shield.checkmark", text: "Our team will review the report within 24-48 hours")
                    infoRow(icon: "envelope.fill", text: "You'll receive a notification once the review is complete")
                    infoRow(icon: "hand.raised.fill", text: "If verified, the reported user will be permanently banned")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Warning Box
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Urgent Situation?")
                        .font(.system(size: 15, weight: .semibold))
                }
                
                Text("If you feel unsafe or the situation is urgent, please contact local authorities immediately.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Close")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brown)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brown)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

struct MisconductReportView_Previews: PreviewProvider {
    static var previews: some View {
        MisconductReportView(
            reportedUserId: "user123",
            reportedUserName: "John Doe",
            meetingId: "meeting456"
        )
    }
}

