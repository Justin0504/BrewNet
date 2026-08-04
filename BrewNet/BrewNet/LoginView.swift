import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var forceRefresh = UUID()
    @State private var showingRegisterView = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景渐变
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95), // 米白色
                        Color.white
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Logo区域
                        VStack(spacing: 20) {
                            // Logo - 使用AppIcon中的图片
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: Color.brown.opacity(0.3), radius: 15, x: 0, y: 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white, lineWidth: 3)
                                )
                            
                            // 应用名称
                            Text("BrewNet")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1)) // 深棕色
                            
                            // 英文标语
                            VStack(spacing: 8) {
                                Text("Brew Your Rise.")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                            }
                        }
                        
                        Spacer()
                            .frame(height: 60)
                        
                        // 登录表单
                        VStack(spacing: 24) {
                            // 邮箱/手机号输入框
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email or Phone")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                TextField("Enter your email or phone", text: $email)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            // 密码输入框
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                
                                CustomPasswordField(text: $password, placeholder: "Enter your password")
                            }
                            
                            // 登录按钮
                            Button(action: {
                                performLogin()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Login")
                                            .font(.system(size: 18, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.6, green: 0.4, blue: 0.2), // 棕色
                                            Color(red: 0.4, green: 0.2, blue: 0.1)  // 深棕色
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(25)
                                .shadow(color: Color.brown.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                            
                            // 提示信息
                            VStack(spacing: 8) {
                                Text("New user? Create an account to get started!")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                Button(action: {
                                    showingRegisterView = true
                                }) {
                                    Text("Sign up now")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                        .underline()
                                }
                            }
                            .padding(.top, 8)
                            
                            // 其他登录方式
                            VStack(spacing: 16) {
                                Text("or")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.gray)
                                
                                // Apple Sign In按钮
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        request.requestedScopes = [.fullName, .email]
                                    },
                                    onCompletion: { result in
                                        handleAppleSignIn(result: result)
                                    }
                                )
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(25)
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.6 : 1.0)
                                
                                // 游客登录按钮
                                Button(action: {
                                    print("🔘 Guest login button clicked")
                                    print("🔘 Button click time: \(Date())")
                                    performGuestLogin()
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.4, green: 0.2, blue: 0.1)))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "person.badge.plus")
                                                .font(.title2)
                                        }
                                        Text("Guest Experience")
                                            .font(.system(size: 16, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .foregroundColor(Color(red: 0.4, green: 0.2, blue: 0.1))
                                    .cornerRadius(25)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color(red: 0.6, green: 0.4, blue: 0.2), lineWidth: 1)
                                    )
                                }
                                .disabled(isLoading)
                                .opacity(isLoading ? 0.6 : 1.0)
                                
                                // 游客登录说明
                                Text("Guest mode allows you to experience basic features, data will not be saved")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .id(forceRefresh) // 添加强制刷新ID
        .onReceive(authManager.$authState) { newState in
            print("🔐 LoginView received state change: \(newState)")
            switch newState {
            case .loading:
                print("🔐 LoginView state change: loading")
            case .authenticated(let user):
                print("🔐 LoginView state change: authenticated - \(user.name) (guest: \(user.isGuest))")
                print("🔐 LoginView should navigate to main view")
            case .unauthenticated:
                print("🔐 LoginView state change: unauthenticated")
            }
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingRegisterView) {
            RegisterView()
                .environmentObject(authManager)
        }
        .onAppear {
            #if DEBUG
            // 仅 Debug 构建:支持模拟器/UI 测试通过环境变量自动登录
            // 用法: SIMCTL_CHILD_BREWNET_AUTOLOGIN_EMAIL=... SIMCTL_CHILD_BREWNET_AUTOLOGIN_PASSWORD=... xcrun simctl launch ...
            let env = ProcessInfo.processInfo.environment
            if let autoEmail = env["BREWNET_AUTOLOGIN_EMAIL"],
               let autoPassword = env["BREWNET_AUTOLOGIN_PASSWORD"],
               !autoEmail.isEmpty, !autoPassword.isEmpty, !isLoading {
                print("🧪 [DEBUG] Auto-login via env vars: \(autoEmail)")
                email = autoEmail
                password = autoPassword
                performLogin()
            }
            #endif
        }
    }

    // MARK: - Login Functions
    private func performLogin() {
        guard !email.isEmpty && !password.isEmpty else {
            showAlert(message: "Please fill in complete login information")
            return
        }
        
        guard isValidEmail(email) else {
            showAlert(message: "Please enter a valid email address")
            return
        }
        
        isLoading = true
        
        Task {
            let result = await authManager.login(email: email, password: password)
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success(let user):
                    print("Login successful: \(user.name)")
                    // Login successful, can navigate to main view
                case .failure(let error):
                    showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func performGuestLogin() {
        print("🚀 Starting guest login...")
        isLoading = true
        
        Task {
            print("📡 Calling authManager.guestLogin()")
            let result = await authManager.guestLogin()
            
            await MainActor.run {
                self.isLoading = false
                
                switch result {
                case .success(let user):
                    print("✅ Guest login successful: \(user.name)")
                    print("🔄 Waiting for view navigation...")
                    // Force refresh interface
                    self.forceRefresh = UUID()
                    // Guest login successful, state will automatically update and trigger view navigation
                case .failure(let error):
                    print("❌ Guest login failed: \(error.localizedDescription)")
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }
    
    // Keep backward compatibility
    private func performQuickLogin() {
        performGuestLogin()
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        print("🔵 handleAppleSignIn called")
        switch result {
        case .success(let authorization):
            print("🍎 Apple Sign In authorization received")
            print("🔄 Setting isLoading = true")
            isLoading = true
            
            Task {
                print("📡 Calling authManager.signInWithApple()")
                let result = await authManager.signInWithApple(authorization: authorization)
                print("📡 authManager.signInWithApple() returned")
                
                await MainActor.run {
                    print("🔄 Setting isLoading = false")
                    isLoading = false
                    
                    switch result {
                    case .success(let user):
                        print("✅ Apple Sign In successful: \(user.name)")
                        print("🔄 Current auth state: \(authManager.authState)")
                        print("🔄 Should navigate to main view now")
                        // Login successful, will automatically navigate to main view
                    case .failure(let error):
                        print("❌ Apple Sign In failed: \(error.localizedDescription)")
                        showAlert(message: error.localizedDescription)
                    }
                }
            }
            
        case .failure(let error):
            print("❌ Apple Sign In error: \(error.localizedDescription)")
            showAlert(message: "Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - 自定义输入框样式
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.8, green: 0.7, blue: 0.6), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 预览
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
