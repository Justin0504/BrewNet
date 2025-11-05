# Profile 页面显示逻辑完整分析

## 📋 概述

"Complete Your Profile"（完成您的个人资料）页面会在特定条件下显示，引导用户创建或完善个人资料。本文档详细说明了所有显示该页面的逻辑和条件。

---

## 🔄 应用导航流程

### 1. 应用入口 (BrewNetApp.swift)

```
BrewNetApp
  └─> ContentView
       ├─> 根据 authManager.authState 决定显示内容
       │   ├─> .loading → LoadingView
       │   ├─> .authenticated(user) → SplashScreenWrapperView
       │   └─> .unauthenticated → LoginView
```

**关键代码位置**: `BrewNetApp.swift:21-32`

---

### 2. 已认证用户流程 (ContentView.swift)

当用户已认证时，会显示 `SplashScreenWrapperView`：

```swift
case .authenticated(let user):
    SplashScreenWrapperView(
        user: user,
        isCheckingProfile: $isCheckingProfile,
        onProfileCheck: {
            checkProfileStatus(for: user)
        }
    )
```

**关键代码位置**: `ContentView.swift:24-32`

---

### 3. 启动画面包装器 (SplashScreenWrapperView.swift)

`SplashScreenWrapperView` 根据用户的 `profileSetupCompleted` 状态决定显示内容：

```swift
if showSplash && !hasLoaded {
    // 1. 显示启动画面
    SplashScreenView()
} else if isCheckingProfile {
    // 2. 正在检查 profile 状态（显示加载动画）
    ProgressView("Checking profile status...")
} else if user.profileSetupCompleted {
    // 3. 用户已完成 profile 设置 → 显示主界面
    MainView()
} else {
    // 4. 用户未完成 profile 设置 → 显示资料设置界面
    ProfileSetupView()
}
```

**关键代码位置**: `SplashScreenWrapperView.swift:14-54`

**决策逻辑**:
- ✅ `user.profileSetupCompleted == true` → 显示 `MainView`
- ❌ `user.profileSetupCompleted == false` → 显示 `ProfileSetupView`（完整的设置流程）

---

### 4. 主界面中的 Profile Tab (MainView.swift → ProfileView.swift)

在主界面中，用户可以通过底部 Tab Bar 切换到 Profile Tab：

```swift
// MainView.swift
TabView(selection: $selectedTab) {
    // ...
    NavigationStack {
        ProfileView()  // Tab 4: Profile
    }
    .tabItem {
        Image(systemName: "person.fill")
    }
    .tag(4)
}
```

**关键代码位置**: `MainView.swift:47-54`

---

### 5. ProfileView 的显示逻辑 (ProfileView.swift)

`ProfileView` 根据 `userProfile` 的状态显示不同的内容：

```swift
if isLoadingProfile {
    // 状态 1: 正在加载
    VStack {
        ProgressView()
        Text("Loading profile...")
    }
} else if let profile = userProfile {
    // 状态 2: 有 profile 数据 → 显示完整的 ProfileDisplayView
    ProfileDisplayView(profile: profile) {
        showingEditProfile = true
    }
} else {
    // 状态 3: 没有 profile 数据 → 显示 "Complete Your Profile" 提示页面
    VStack(spacing: 24) {
        Image(systemName: "person.circle")
        Text("Complete Your Profile")
        Text("Set up your profile to start networking with other professionals")
        Button("Set Up Profile") {
            // 点击后打开 ProfileSetupView
        }
    }
}
```

**关键代码位置**: `ProfileView.swift:18-86`

---

## 🎯 "Complete Your Profile" 页面显示的所有场景

### 场景 1: 首次登录后（通过 SplashScreenWrapperView）

**触发条件**:
- 用户已认证 (`authState == .authenticated`)
- 用户未完成 profile 设置 (`user.profileSetupCompleted == false`)

**显示位置**: `SplashScreenWrapperView.swift:48-53`

**显示内容**: 完整的 `ProfileSetupView`（不是提示页面，而是直接进入设置流程）

**流程**:
1. 用户登录成功
2. `ContentView` 检测到用户已认证
3. 显示 `SplashScreenWrapperView`
4. 检查 `user.profileSetupCompleted`
5. 如果为 `false`，直接显示 `ProfileSetupView`

---

### 场景 2: 在主界面 Profile Tab 中（通过 ProfileView）

**触发条件**:
- 用户在 `MainView` 中切换到 Profile Tab
- `ProfileView` 的 `loadUserProfile()` 执行
- `supabaseService.getProfile(userId:)` 返回 `nil` 或抛出错误
- `userProfile` 状态为 `nil`
- `isLoadingProfile` 为 `false`

**显示位置**: `ProfileView.swift:43-86`

**显示内容**: "Complete Your Profile" 提示页面，包含：
- 灰色人形图标
- "Complete Your Profile" 标题
- "Set up your profile to start networking with other professionals" 说明文字
- "Set Up Profile" 按钮

**流程**:
1. 用户点击 Profile Tab
2. `ProfileView.onAppear` 触发
3. 调用 `loadUserProfile()`
4. 从数据库获取 profile：
   ```swift
   if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
       self.userProfile = supabaseProfile.toBrewNetProfile()
   } else {
       self.userProfile = nil  // ← 这里会触发显示提示页面
   }
   ```
5. 如果 `userProfile == nil`，显示 "Complete Your Profile" 页面

**关键代码位置**: `ProfileView.swift:323-352`

---

## 🔍 Profile 数据加载逻辑

### loadUserProfile() 方法

```swift
private func loadUserProfile() {
    guard let currentUser = authManager.currentUser else {
        isLoadingProfile = false
        return
    }
    
    isLoadingProfile = true
    
    Task {
        do {
            // 尝试从 Supabase 获取 profile
            if let supabaseProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                await MainActor.run {
                    self.userProfile = supabaseProfile.toBrewNetProfile()
                    self.isLoadingProfile = false
                }
            } else {
                // 没有找到 profile → userProfile = nil
                await MainActor.run {
                    self.userProfile = nil
                    self.isLoadingProfile = false
                }
            }
        } catch {
            // 获取失败 → userProfile = nil
            print("❌ Failed to load user profile: \(error)")
            await MainActor.run {
                self.userProfile = nil
                self.isLoadingProfile = false
            }
        }
    }
}
```

**关键代码位置**: `ProfileView.swift:323-352`

---

### refreshUserProfile() 方法

用于静默刷新 profile 数据（不显示加载动画）：

```swift
private func refreshUserProfile(showLoading: Bool = false) {
    // 类似 loadUserProfile，但可以选择是否显示加载动画
    // 通常在收到 ProfileUpdated 通知时调用
}
```

**关键代码位置**: `ProfileView.swift:355-391`

---

## 📊 Profile 状态检查时机

### 1. ProfileView 首次显示时

```swift
.onAppear {
    if userProfile == nil {
        loadUserProfile()  // 首次加载
    } else {
        refreshUserProfile(showLoading: false)  // 刷新数据
    }
}
```

**关键代码位置**: `ProfileView.swift:90-99`

---

### 2. 收到 ProfileUpdated 通知时

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileUpdated"))) { _ in
    print("📨 ProfileView 收到 ProfileUpdated 通知 - 刷新 profile 数据")
    refreshUserProfile(showLoading: false)
}
```

**关键代码位置**: `ProfileView.swift:101-105`

**触发时机**:
- Profile 创建成功
- Profile 更新成功
- 头像上传成功

---

### 3. ContentView 中的 Profile 状态检查

```swift
private func checkProfileStatus(for user: AppUser) {
    Task {
        do {
            // 检查用户是否有 profile 数据
            let hasProfile = try await supabaseService.getProfile(userId: user.id) != nil
            
            await MainActor.run {
                if hasProfile && !user.profileSetupCompleted {
                    // 用户有 profile 数据但状态不正确，更新状态
                    authManager.updateProfileSetupCompleted(true)
                }
                
                isCheckingProfile = false
            }
        } catch {
            // 检查失败，隐藏检查界面
            isCheckingProfile = false
        }
    }
}
```

**关键代码位置**: `ContentView.swift:67-97`

**目的**: 同步 `user.profileSetupCompleted` 状态，确保数据库中的 profile 状态与用户对象一致

---

## 🎨 用户操作流程

### 场景 A: 首次登录用户

```
1. 用户登录
   ↓
2. ContentView 检测到 authenticated
   ↓
3. SplashScreenWrapperView 检查 profileSetupCompleted
   ↓
4. profileSetupCompleted == false
   ↓
5. 直接显示 ProfileSetupView（完整设置流程）
   ↓
6. 用户完成设置
   ↓
7. profileSetupCompleted = true
   ↓
8. 显示 MainView
```

---

### 场景 B: 已有账号但 Profile 被删除

```
1. 用户登录
   ↓
2. ContentView → SplashScreenWrapperView
   ↓
3. profileSetupCompleted == true（用户之前完成过）
   ↓
4. 显示 MainView
   ↓
5. 用户点击 Profile Tab
   ↓
6. ProfileView 加载 profile
   ↓
7. getProfile() 返回 nil（数据库中没有 profile）
   ↓
8. userProfile = nil
   ↓
9. 显示 "Complete Your Profile" 提示页面
   ↓
10. 用户点击 "Set Up Profile" 按钮
    ↓
11. 打开 ProfileSetupView（.sheet）
```

---

### 场景 C: Profile 创建失败

```
1. 用户在 ProfileSetupView 中填写信息
   ↓
2. 点击保存
   ↓
3. createProfile() 失败（网络错误、数据库错误等）
   ↓
4. 用户返回到 ProfileView
   ↓
5. userProfile == nil（因为创建失败）
   ↓
6. 显示 "Complete Your Profile" 提示页面
```

---

## 🔑 关键状态变量

### 1. authManager.authState

**类型**: `AuthState` (enum)

**可能值**:
- `.loading` - 正在检查认证状态
- `.authenticated(user)` - 已认证
- `.unauthenticated` - 未认证

**作用**: 决定 `ContentView` 显示什么内容

---

### 2. user.profileSetupCompleted

**类型**: `Bool`

**作用**: 决定 `SplashScreenWrapperView` 显示 `MainView` 还是 `ProfileSetupView`

**设置位置**:
- 用户注册时：默认为 `false`
- Profile 创建成功时：设置为 `true`
- `ContentView.checkProfileStatus()` 中：同步状态

---

### 3. ProfileView.userProfile

**类型**: `BrewNetProfile?` (可选)

**作用**: 决定 `ProfileView` 显示 `ProfileDisplayView` 还是 "Complete Your Profile" 提示页面

**更新时机**:
- `loadUserProfile()` - 首次加载
- `refreshUserProfile()` - 刷新数据
- 收到 `ProfileUpdated` 通知时

---

### 4. ProfileView.isLoadingProfile

**类型**: `Bool`

**作用**: 控制显示加载动画还是内容

**显示逻辑**:
- `true` → 显示 `ProgressView` + "Loading profile..."
- `false` → 根据 `userProfile` 显示内容

---

## 📝 数据库查询逻辑

### SupabaseService.getProfile()

```swift
func getProfile(userId: String) async throws -> SupabaseProfile? {
    // 从 profiles 表查询
    // SELECT * FROM profiles WHERE user_id = userId
    // 如果找到 → 返回 SupabaseProfile
    // 如果没找到 → 返回 nil
    // 如果出错 → 抛出异常
}
```

**返回结果**:
- `SupabaseProfile` - 找到 profile
- `nil` - 没有找到 profile
- 抛出异常 - 查询失败

**关键代码位置**: `SupabaseService.swift:638`

---

## 🎯 总结

### "Complete Your Profile" 页面显示的条件

**唯一显示位置**: `ProfileView.swift:43-86`

**显示条件**（必须同时满足）:
1. ✅ 用户在 `MainView` 的 Profile Tab 中
2. ✅ `isLoadingProfile == false`（加载完成）
3. ✅ `userProfile == nil`（没有 profile 数据）

**不会显示的情况**:
- 用户首次登录时，如果 `profileSetupCompleted == false`，会直接显示 `ProfileSetupView`（不是提示页面）
- 如果 `isLoadingProfile == true`，会显示加载动画
- 如果 `userProfile != nil`，会显示 `ProfileDisplayView`

---

### 数据流程

```
数据库 (profiles 表)
    ↓
SupabaseService.getProfile()
    ↓
ProfileView.loadUserProfile()
    ↓
userProfile 状态更新
    ↓
SwiftUI 视图自动更新
    ↓
显示相应内容
```

---

## 🔄 相关通知

### ProfileUpdated 通知

**发送位置**: 
- Profile 创建成功后
- Profile 更新成功后
- 头像上传成功后

**监听位置**: `ProfileView.swift:101-105`

**作用**: 自动刷新 profile 数据，无需手动刷新

---

## 📌 注意事项

1. **状态同步**: `user.profileSetupCompleted` 和数据库中的 profile 可能存在不一致，`ContentView.checkProfileStatus()` 会尝试同步

2. **错误处理**: 如果 `getProfile()` 抛出异常，`userProfile` 会被设置为 `nil`，从而显示提示页面

3. **加载状态**: `isLoadingProfile` 确保在加载完成前不显示提示页面

4. **按钮功能**: "Set Up Profile" 按钮目前没有实现功能（代码注释："This will be handled by the ContentView routing"），但可以通过 `.sheet` 打开 `ProfileSetupView`

---

## 🎨 UI 元素

### "Complete Your Profile" 页面包含：

1. **图标**: `Image(systemName: "person.circle")` - 灰色人形图标
2. **标题**: "Complete Your Profile" - 棕色粗体文字
3. **说明**: "Set up your profile to start networking with other professionals" - 灰色文字
4. **按钮**: "Set Up Profile" - 棕色渐变背景的圆角按钮

**样式代码位置**: `ProfileView.swift:44-82`

---

## 🔗 相关文件

- `BrewNetApp.swift` - 应用入口
- `ContentView.swift` - 主路由逻辑
- `SplashScreenWrapperView.swift` - 启动画面和路由
- `MainView.swift` - 主界面（Tab Bar）
- `ProfileView.swift` - Profile 页面（包含提示页面）
- `ProfileSetupView.swift` - Profile 设置流程
- `ProfileDisplayView.swift` - Profile 显示页面
- `SupabaseService.swift` - Profile 数据服务

