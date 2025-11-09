# 📍 Distance Display Coverage - 距离显示覆盖情况

## 概述

所有 ProfileCard 视图现在都正确显示当前用户与其他用户之间的距离。

## 修复内容

### ✅ 已修复的视图

| 视图名称 | 文件 | 使用场景 | 状态 |
|---------|------|---------|------|
| **UserProfileCardView** | UserProfileCardView.swift | Explore 页面的 Match 卡片 | ✅ 正常 |
| **PublicProfileCardView** | UserProfileCardView.swift | Connection Requests 列表 | ✅ 正常 |
| **ProfileCardSheetView** | ChatInterfaceView.swift | Chat 中点击头像查看 Profile | ✅ 正常 |
| **UserProfileCardSheetView** | ProfileDisplayView.swift | Profile 页面的卡片弹窗 | ✅ **刚修复** |

### 🔧 本次修复：UserProfileCardSheetView

**问题**：
- `currentUserLocation: nil` ❌ 硬编码为 nil
- `showDistance: false` ❌ 不显示距离

**修复内容**：
1. 添加 `@State private var currentUserLocation: String?`
2. 添加 `loadCurrentUserLocation()` 方法
3. 在 `.onAppear` 中调用 `loadCurrentUserLocation()`
4. 修改参数：
   - `currentUserLocation: currentUserLocation` ✅
   - `showDistance: true` ✅

**修复后代码**：
```swift
struct UserProfileCardSheetView: View {
    // ... 其他属性
    @State private var currentUserLocation: String?
    
    var body: some View {
        NavigationStack {
            // ...
            ProfileCardContentView(
                profile: profile,
                isConnection: isConnection,
                isProUser: displayIsPro,
                isVerified: resolvedVerifiedStatus,
                currentUserLocation: currentUserLocation,  // ✅ 修复
                showDistance: true,                         // ✅ 修复
                onWorkExperienceTap: { ... }
            )
            // ...
            .onAppear {
                loadCurrentUserLocation()  // ✅ 添加
                resolveVerifiedStatusIfNeeded()
            }
        }
    }
    
    // ✅ 新增方法
    private func loadCurrentUserLocation() {
        guard let currentUser = authManager.currentUser else {
            print("⚠️ [UserProfileCardSheet] 没有当前用户，无法加载位置")
            return
        }
        
        print("📍 [UserProfileCardSheet] 开始加载当前用户位置...")
        print("   - 当前用户 ID: \(currentUser.id)")
        
        Task {
            do {
                if let currentProfile = try await supabaseService.getProfile(userId: currentUser.id) {
                    let rawLocation = currentProfile.coreIdentity.location
                    print("   - [原始数据] coreIdentity.location: \(rawLocation ?? "nil")")
                    
                    let brewNetProfile = currentProfile.toBrewNetProfile()
                    await MainActor.run {
                        currentUserLocation = brewNetProfile.coreIdentity.location
                        print("✅ [UserProfileCardSheet] 已加载当前用户位置: \(brewNetProfile.coreIdentity.location ?? "nil")")
                        if brewNetProfile.coreIdentity.location == nil || brewNetProfile.coreIdentity.location?.isEmpty == true {
                            print("⚠️ [UserProfileCardSheet] 当前用户没有设置位置信息")
                        }
                    }
                } else {
                    print("⚠️ [UserProfileCardSheet] 无法获取当前用户 profile")
                }
            } catch {
                print("⚠️ [UserProfileCardSheet] 加载当前用户位置失败: \(error.localizedDescription)")
            }
        }
    }
}
```

## 所有视图的距离显示配置

### 1. UserProfileCardView (Explore 页面)

**文件**: `UserProfileCardView.swift`

**使用场景**: Explore 页面滑动查看 Match 卡片

**配置**:
```swift
struct UserProfileCardView: View {
    @State private var currentUserLocation: String?
    
    var body: some View {
        // ...
        ProfileCardContentView(
            profile: profile,
            isConnection: isConnection,
            isProUser: isPro,
            isVerified: isVerified,
            currentUserLocation: currentUserLocation,  // ✅
            showDistance: true,                         // ✅
            onWorkExperienceTap: { ... }
        )
        .onAppear {
            loadCurrentUserLocation()  // ✅
        }
    }
    
    private func loadCurrentUserLocation() {
        // 从 profiles 表加载当前用户的 core_identity.location
        // ...
    }
}
```

**日志标识**: `[UserProfileCard]`

### 2. PublicProfileCardView (Connection Requests)

**文件**: `UserProfileCardView.swift`

**使用场景**: Connection Requests 页面查看请求列表

**配置**:
```swift
struct PublicProfileCardView: View {
    @State private var currentUserLocation: String?
    
    var body: some View {
        // ...
        ProfileCardContentView(
            profile: profile,
            isConnection: isConnection,
            isProUser: displayIsPro,
            isVerified: displayIsVerified,
            currentUserLocation: currentUserLocation,  // ✅
            showDistance: showDistance,                 // ✅ (可配置)
            onWorkExperienceTap: nil
        )
        .onAppear {
            loadCurrentUserLocation()  // ✅
            resolveProStatusIfNeeded()
            resolveVerifiedStatusIfNeeded()
        }
    }
    
    private func loadCurrentUserLocation() {
        // 从 profiles 表加载当前用户的 core_identity.location
        // ...
    }
}
```

**日志标识**: `[PublicProfileCard]`

### 3. ProfileCardSheetView (Chat 界面)

**文件**: `ChatInterfaceView.swift`

**使用场景**: Chat 界面点击对方头像查看 Profile

**配置**:
```swift
struct ProfileCardSheetView: View {
    @State private var currentUserLocation: String?
    
    var body: some View {
        NavigationView {
            // ...
            ProfileCardContentView(
                profile: profile,
                isConnection: isConnection,
                isProUser: resolvedProStatus ?? false,
                isVerified: resolvedVerifiedStatus,
                currentUserLocation: currentUserLocation,  // ✅
                showDistance: true,                         // ✅
                onWorkExperienceTap: nil
            )
            .onAppear {
                loadCurrentUserLocation()  // ✅
                resolveProStatusIfNeeded()
                resolveVerifiedStatusIfNeeded()
            }
        }
    }
    
    private func loadCurrentUserLocation() {
        // 从 profiles 表加载当前用户的 core_identity.location
        // ...
    }
}
```

**日志标识**: `[ChatProfileCard]`

### 4. UserProfileCardSheetView (Profile 页面)

**文件**: `ProfileDisplayView.swift`

**使用场景**: Profile 页面的卡片弹窗（查看自己或他人的 Profile）

**配置**:
```swift
struct UserProfileCardSheetView: View {
    @State private var currentUserLocation: String?  // ✅ 新增
    
    var body: some View {
        NavigationStack {
            // ...
            ProfileCardContentView(
                profile: profile,
                isConnection: isConnection,
                isProUser: displayIsPro,
                isVerified: resolvedVerifiedStatus,
                currentUserLocation: currentUserLocation,  // ✅ 修复（之前是 nil）
                showDistance: true,                         // ✅ 修复（之前是 false）
                onWorkExperienceTap: { ... }
            )
            .onAppear {
                loadCurrentUserLocation()          // ✅ 新增
                resolveVerifiedStatusIfNeeded()
            }
        }
    }
    
    private func loadCurrentUserLocation() {  // ✅ 新增方法
        // 从 profiles 表加载当前用户的 core_identity.location
        // ...
    }
}
```

**日志标识**: `[UserProfileCardSheet]`

## 数据流

### 位置数据存储

```
Supabase Database
  ↓
profiles 表
  ↓
core_identity (JSONB)
  ↓
location (String)
  例如: "Union Square, San Francisco, CA"
```

### 数据加载流程

```
1. 视图 .onAppear
   ↓
2. loadCurrentUserLocation()
   ↓
3. supabaseService.getProfile(userId: currentUser.id)
   ↓
4. 获取 SupabaseProfile
   ↓
5. currentProfile.coreIdentity.location
   ↓
6. 转换为 BrewNetProfile
   ↓
7. brewNetProfile.coreIdentity.location
   ↓
8. currentUserLocation = location
   ↓
9. 传递给 ProfileCardContentView
   ↓
10. 传递给 DistanceDisplayView
   ↓
11. DistanceDisplayView.calculateDistance()
   ↓
12. LocationService.calculateDistanceBetweenAddresses()
   ↓
13. 显示距离
```

### 优化机制

1. **地理编码缓存**
   - 相同地址只编码一次
   - 缓存 CLLocation 结果

2. **距离缓存**
   - 相同地址对只计算一次
   - 双向缓存（A->B 和 B->A）

3. **请求去重**
   - 并发请求合并
   - 只发起一次地理编码

4. **防抖动**
   - 50ms 延迟
   - 避免极短时间内的重复计算

## 日志说明

### 正常流程日志

```
📍 [UserProfileCardSheet] 开始加载当前用户位置...
   - 当前用户 ID: 7a9380a5-d34d-40de-8e44-f1002aa5512a
   - [原始数据] coreIdentity.location: Union Square, San Francisco, CA
✅ [UserProfileCardSheet] 已加载当前用户位置: Union Square, San Francisco, CA

👁️ [DistanceDisplay] onAppear 触发
   - otherUserLocation: Seattle, WA
   - currentUserLocation: Union Square, San Francisco, CA
🔍 [DistanceDisplay] 开始计算距离（使用防抖动）...
   - 对方地址: Seattle, WA
   - 当前用户地址: Union Square, San Francisco, CA
⚡️ [距离缓存] 命中缓存: Union Square, San Francisco, CA <-> Seattle, WA = 1,094 km
✅ [DistanceDisplay] ✅✅✅ 距离计算成功: 1,094 km ✅✅✅
```

### 如果当前用户没有设置位置

```
📍 [UserProfileCardSheet] 开始加载当前用户位置...
   - 当前用户 ID: 7a9380a5-d34d-40de-8e44-f1002aa5512a
   - [原始数据] coreIdentity.location: nil
✅ [UserProfileCardSheet] 已加载当前用户位置: nil
⚠️ [UserProfileCardSheet] 当前用户没有设置位置信息

👁️ [DistanceDisplay] onAppear 触发
   - otherUserLocation: Seattle, WA
   - currentUserLocation: nil
🔍 [DistanceDisplay] 开始计算距离（使用防抖动）...
   - 对方地址: Seattle, WA
   - 当前用户地址: nil
⚠️ [DistanceDisplay] 当前用户地址为空，等待加载...

UI 显示: "Set your location to see distance"
```

## 测试验证

### 测试场景

1. **Explore 页面**
   - 滑动查看 Match 卡片
   - 应显示距离

2. **Connection Requests 页面**
   - 查看连接请求列表
   - 应显示距离

3. **Chat 界面**
   - 点击对方头像
   - 查看 Profile Card
   - 应显示距离

4. **Profile 页面**
   - 点击卡片
   - 查看详细信息
   - **应显示距离**（✅ 本次修复）

### 验证步骤

1. **设置位置**
   - 进入 Profile → Edit Profile
   - 设置 Location 字段
   - 例如：`Union Square, San Francisco, CA`

2. **查看 Match 卡片**
   - 进入 Explore 页面
   - 查看其他用户的卡片
   - 确认显示距离

3. **查看 Profile**
   - 点击任意卡片查看详细信息
   - **确认显示距离**（之前不显示，现在应该显示）

4. **查看日志**
   - 确认看到类似：
     ```
     📍 [UserProfileCardSheet] 开始加载当前用户位置...
     ✅ [UserProfileCardSheet] 已加载当前用户位置: Union Square, San Francisco, CA
     ```

## 相关文档

- **`LOCATION_SETUP_GUIDE.md`** - 位置设置指南
- **`DISTANCE_CALCULATION_OPTIMIZATION.md`** - 距离计算性能优化
- **`check_user_location.sql`** - 数据库位置检查脚本

## 总结

### ✅ 修复完成

所有 ProfileCard 视图现在都正确显示距离：
- ✅ Explore 页面 Match 卡片
- ✅ Connection Requests 列表
- ✅ Chat 界面 Profile Card
- ✅ Profile 页面卡片弹窗（本次修复）

### 🎯 效果

- **覆盖率**: 100% 的 ProfileCard 视图都显示距离
- **一致性**: 所有视图使用统一的加载逻辑
- **性能**: 利用多层缓存机制，快速响应
- **用户体验**: 用户在任何地方查看 Profile 都能看到距离信息

---

**修复时间**: 2025-11-09

**修复文件**: `ProfileDisplayView.swift`

**相关 Commit**: 添加 UserProfileCardSheetView 的距离显示功能

