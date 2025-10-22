import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedAuthMethod: AuthMethod = .email
    
    enum AuthMethod: String, CaseIterable {
        case email = "Email"
        case phone = "Phone"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 40)
                        
                        // Header
                        VStack(spacing: 16) {
                            // Back button
                            HStack {
                                Button(action: {
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 16, weight: .medium))
                                        Text("Back")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // Logo and title
                            VStack(spacing: 12) {
                                Image("Logo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.brown.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Text("Join BrewNet")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                Text("Connect with professionals over coffee")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Registration form
                        VStack(spacing: 24) {
                            // Auth method selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sign up with")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                Picker("Auth Method", selection: $selectedAuthMethod) {
                                    ForEach(AuthMethod.allCases, id: \.self) { method in
                                        Text(method.displayName).tag(method)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            
                            // Name field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                TextField("Enter your full name", text: $name)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                            
                            // Email or Phone field
                            VStack(alignment: .leading, spacing: 8) {
                                Text(selectedAuthMethod == .email ? "Email Address" : "Phone Number")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                if selectedAuthMethod == .email {
                                    TextField("Enter your email", text: $email)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                } else {
                                    TextField("Enter your phone number", text: $phoneNumber)
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .keyboardType(.phonePad)
                                }
                            }
                            
                            // Password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                // 临时使用 SecureField 进行测试
                                SecureField("Create a password", text: $password)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocorrectionDisabled()
                                    .textContentType(.none)
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)
                            }
                            
                            // Confirm password field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                // 临时使用 SecureField 进行测试
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocorrectionDisabled()
                                    .textContentType(.none)
                                    .disableAutocorrection(true)
                                    .autocapitalization(.none)
                            }
                            
                            // Debug info (temporary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Debug Info:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Name: '\(name)' (\(name.isEmpty ? "Empty" : "OK"))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Email: '\(email)' (\(email.isEmpty ? "Empty" : "OK"))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Password: '\(password)' (\(password.isEmpty ? "Empty" : "OK"))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Confirm: '\(confirmPassword)' (\(confirmPassword.isEmpty ? "Empty" : "OK"))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Form Valid: \(isFormValid ? "YES" : "NO")")
                                    .font(.caption2)
                                    .foregroundColor(isFormValid ? .green : .red)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Register button
                            Button(action: {
                                performRegistration()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Create Account")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.6, green: 0.4, blue: 0.2),
                                            Color(red: 0.4, green: 0.2, blue: 0.1)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(25)
                                .shadow(color: Color.brown.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isLoading || !isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.6)
                            
                            // Terms and conditions
                            VStack(spacing: 8) {
                                Text("By creating an account, you agree to our")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                
                                HStack(spacing: 4) {
                                    Button("Terms of Service") {
                                        // Open terms
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    
                                    Text("and")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    Button("Privacy Policy") {
                                        // Open privacy policy
                                    }
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Form Validation
    private var isFormValid: Bool {
        let nameValid = !name.isEmpty
        let passwordValid = !password.isEmpty && password.count >= 6
        let confirmPasswordValid = !confirmPassword.isEmpty && password == confirmPassword
        
        let emailValid = selectedAuthMethod == .email ? (!email.isEmpty && isValidEmail(email)) : true
        let phoneValid = selectedAuthMethod == .phone ? (!phoneNumber.isEmpty && isValidPhoneNumber(phoneNumber)) : true
        
        let isValid = nameValid && passwordValid && confirmPasswordValid && emailValid && phoneValid
        
        // 调试信息
        print("🔍 Form Validation:")
        print("  Name: \(name) - Valid: \(nameValid)")
        print("  Password: \(password) - Valid: \(passwordValid)")
        print("  Confirm Password: \(confirmPassword) - Valid: \(confirmPasswordValid)")
        print("  Email: \(email) - Valid: \(emailValid)")
        print("  Phone: \(phoneNumber) - Valid: \(phoneValid)")
        print("  Overall: \(isValid)")
        
        return isValid
    }
    
    // MARK: - Registration
    private func performRegistration() {
        guard isFormValid else {
            showAlert(message: "Please fill in all fields correctly")
            return
        }
        
        isLoading = true
        
        Task {
            let result: Result<AppUser, AuthError>
            
            if selectedAuthMethod == .email {
                result = await authManager.register(email: email, password: password, name: name)
            } else {
                result = await authManager.registerWithPhone(phoneNumber: phoneNumber, password: password, name: name)
            }
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success(let user):
                    print("Registration successful: \(user.name)")
                    // Registration successful, will automatically navigate to main view
                case .failure(let error):
                    showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Validation Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Remove all non-digit characters
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        // Check if it's a valid length (7-15 digits)
        return digitsOnly.count >= 7 && digitsOnly.count <= 15
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Custom Text Field Style (moved to LoginView.swift to avoid duplication)

// MARK: - Preview
struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(AuthManager())
    }
}
