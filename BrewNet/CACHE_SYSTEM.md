# 推荐系统缓存架构说明

## 📋 目录

- [概述](#概述)
- [缓存存储](#缓存存储)
- [数据结构](#数据结构)
- [缓存生命周期](#缓存生命周期)
- [加载流程](#加载流程)
- [验证机制](#验证机制)
- [用户交互更新](#用户交互更新)
- [两种数据源](#两种数据源)
- [最佳实践](#最佳实践)

---

## 概述

推荐页面使用**双层缓存系统**，结合**内存缓存**和**持久化存储**，提供快速响应和离线体验。

### 核心特性

- ✅ **快速响应**：优先使用缓存，立即显示数据
- ✅ **实时验证**：后台验证并过滤已交互用户
- ✅ **状态同步**：Pass/Like 后立即更新缓存
- ✅ **位置记忆**：保存浏览位置，切换 tab 后恢复
- ✅ **数据一致性**：多重过滤确保不显示已交互用户

---

## 缓存存储

### 存储方式

使用 **UserDefaults** 进行持久化存储，每个用户独立缓存。

### 物理位置

- **真机**：`~/Library/Preferences/com.yourcompany.BrewNet.plist`
- **模拟器**：`~/Library/Developer/CoreSimulator/Devices/[DeviceID]/data/Containers/Data/Application/[AppID]/Library/Preferences/com.yourcompany.BrewNet.plist`

### 存储的键值对

每个用户有 4 个独立的键：

| 键名 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `matches_cache_{userId}` | Data (JSON) | 缓存的 profiles 数据 | `[BrewNetProfile]` 的 JSON 编码 |
| `matches_cache_time_{userId}` | Date | 缓存时间戳 | `2025-01-27 10:30:00` |
| `matches_cache_source_{userId}` | Bool | **缓存来源标识** | `true` = 推荐系统，`false` = 传统分页 |
| `matches_current_index_{userId}` | Int | 当前浏览位置 | `5` (第 6 个 profile) |

### 示例

假设用户 ID 是 `abc123`：

```
matches_cache_abc123          → [Profile1, Profile2, ...]
matches_cache_time_abc123     → 2025-01-27 10:30:00
matches_cache_source_abc123   → true
matches_current_index_abc123  → 5
```

---

## 数据结构

### 内存缓存（运行时内存）

**存储位置**：应用运行时的内存（RAM）中，存储在 SwiftUI 的 `@State` 属性中

**存储位置详解**：
- **物理位置**：iOS 应用的进程内存空间（Heap）
- **生命周期**：与应用视图生命周期绑定，视图销毁时释放
- **存储方式**：Swift 对象实例，存储在堆内存中
- **访问速度**：极快（直接内存访问）

**内存缓存变量**：

```swift
@State private var profiles: [BrewNetProfile] = []        // 当前显示的 profiles（主缓存）
@State private var cachedProfiles: [BrewNetProfile] = []  // 缓存数据（备份缓存）
@State private var currentIndex = 0                        // 当前索引位置
@State private var lastLoadTime: Date? = nil               // 上次加载时间
@State private var isCacheFromRecommendation = false      // 是否来自推荐系统
@State private var hasAppearedBefore = false               // 是否已经显示过
@State private var passedProfiles: [BrewNetProfile] = []   // 已拒绝的用户（交互缓存）
@State private var likedProfiles: [BrewNetProfile] = []   // 已喜欢的用户（交互缓存）
```

**内存缓存说明**：

1. **`profiles`** - 主显示缓存
   - 当前在 UI 上显示的 profiles 列表
   - 从 `cachedProfiles` 复制或过滤而来
   - 用户交互会直接修改这个数组

2. **`cachedProfiles`** - 备份缓存
   - 完整的缓存数据（从持久化存储加载或从服务器获取）
   - 用于验证、过滤和恢复
   - 切换 tab 时作为数据源

3. **`passedProfiles`** - 交互缓存
   - 当前会话中已拒绝的用户
   - 用于快速过滤，避免重复显示
   - 仅在内存中，不持久化

4. **`likedProfiles`** - 交互缓存
   - 当前会话中已喜欢的用户
   - 用于快速过滤，避免重复显示
   - 仅在内存中，不持久化

**内存缓存的生命周期**：

```
视图创建 (onAppear)
  ↓
从持久化存储加载到内存缓存
  ↓
运行时使用内存缓存
  ↓
用户交互时更新内存缓存
  ↓
视图销毁 (onDisappear)
  ↓
内存缓存释放（Swift 自动管理）
```

**内存缓存 vs 持久化缓存**：

| 特性 | 内存缓存 | 持久化缓存 |
|------|---------|-----------|
| 存储位置 | RAM（内存） | UserDefaults（磁盘） |
| 访问速度 | 极快（纳秒级） | 较快（毫秒级） |
| 生命周期 | 视图生命周期 | 应用生命周期 |
| 数据持久性 | 应用关闭后丢失 | 应用关闭后保留 |
| 存储容量 | 受限于设备内存 | 受限于磁盘空间 |

### 缓存数据内容

```swift
struct BrewNetProfile: Codable {
    let id: String
    let userId: String
    let coreIdentity: CoreIdentity
    let professionalBackground: ProfessionalBackground
    let networkingIntention: NetworkingIntention
    // ... 其他字段
}
```

---

## 缓存生命周期

### 缓存有效期

- **有效期**：5 分钟（300 秒）
- **过期后**：自动失效，需要重新加载

### 缓存来源标记

- `isCacheFromRecommendation = true`：来自推荐系统（Two-Tower 模型）
  - ✅ 高质量数据，优先使用
  - ✅ 会进行快速验证和完整验证
  - ✅ 会保存到持久化存储
  
- `isCacheFromRecommendation = false`：来自传统分页
  - ⚠️ 质量较低，作为回退
  - ⚠️ 不会保存到持久化存储
  - ⚠️ 会被清除并重新加载推荐数据

### 缓存更新时机

1. ✅ 从推荐系统加载新数据后
2. ✅ Pass 用户后（立即更新）
3. ✅ 完整验证后（如果有效用户足够）
4. ✅ 切换 tab 时（保存当前索引）

### 缓存清除时机

1. ❌ 缓存过期（超过 5 分钟）
2. ❌ 缓存不是来自推荐系统
3. ❌ 有效用户太少（< 3 个）
4. ❌ Like 用户后（清除推荐缓存）
5. ❌ 验证失败时

---

## 加载流程

### 流程图

```
onAppear
  ↓
loadCachedProfilesFromStorage()
  ↓
检查缓存是否有效？
  ├─ 有缓存 + 来自推荐系统 + 5分钟内
  │  ├─ 切换 tab 回来
  │  │  ├─ 立即显示缓存
  │  │  ├─ quickValidateAndFilterCache() (快速验证)
  │  │  └─ validateAndDisplayCache() (完整验证)
  │  └─ 首次登录
  │     ├─ 显示加载状态
  │     ├─ quickValidateAndFilterCache() (等待完成)
  │     └─ validateAndDisplayCache() (后台验证)
  └─ 无缓存或过期
     └─ loadProfiles() (重新加载)
```

### 详细步骤

#### 1. 加载缓存 (`loadCachedProfilesFromStorage`)

```swift
1. 从 UserDefaults 读取缓存数据
2. 检查时间戳（是否在 5 分钟内）
3. 恢复缓存来源标记（isCacheFromRecommendation）
4. 恢复上次的索引位置
```

#### 2. 切换 Tab 回来

```swift
1. 立即显示缓存（profiles = cachedProfiles）
2. 恢复上次的索引位置
3. 启动快速验证（quickValidateAndFilterCache）
4. 后台完整验证（validateAndDisplayCache）
```

#### 3. 首次登录

```swift
1. 显示加载状态（isLoading = true）
2. 等待快速验证完成（quickValidateAndFilterCache）
3. 验证完成后显示数据
4. 后台完整验证（validateAndDisplayCache）
```

---

## 验证机制

### 快速验证 (`quickValidateAndFilterCache`)

**用途**：切换 tab 回来时立即过滤已拒绝的用户

**流程**：
1. 从服务器获取 `excludedUserIds`（包括已 pass 的用户）
2. 过滤缓存：移除已排除的用户和无效测试用户
3. 更新显示：立即更新 `profiles` 和 `cachedProfiles`
4. 调整索引：保持当前索引或切换到有效位置

**特点**：
- ⚡ 快速响应（异步但优先执行）
- ✅ 立即过滤已交互用户
- 🔄 不影响 UI 流畅度

### 完整验证 (`validateAndDisplayCache`)

**用途**：深度验证缓存，确保数据一致性

**流程**：
1. 获取排除列表：
   - `getExcludedUserIds()` - 已 pass/like 的用户
   - `getActiveMatches()` - 已匹配的用户
2. 多重过滤：
   - ✅ 服务器端排除列表
   - ✅ 本地 `passedProfiles`
   - ✅ 本地 `likedProfiles`
   - ✅ 无效测试用户（如 "123"）
3. 更新缓存：
   - 如果有效用户 ≥ 3 个：更新缓存并保存
   - 如果有效用户 < 3 个：清除缓存并重新加载
4. 后台刷新：静默刷新推荐列表

**特点**：
- 🔍 深度验证
- 🛡️ 多重过滤确保数据一致性
- 🔄 后台静默刷新

---

## 用户交互更新

### Pass（拒绝）用户时

```swift
1. 从 profiles 中移除
2. 从 cachedProfiles 中移除
3. 立即调用 saveCachedProfilesToStorage() 更新持久化缓存
4. 异步记录到服务器（recordPass）
```

**关键代码**：
```swift
private func passProfile() {
    // 立即从列表中移除
    profiles.remove(at: currentIndex)
    cachedProfiles.removeAll { $0.userId == profile.userId }
    
    // 立即更新持久化缓存
    saveCachedProfilesToStorage(isFromRecommendation: isCacheFromRecommendation)
    
    // 异步记录到服务器
    Task {
        await recommendationService.recordPass(...)
    }
}
```

### Like（喜欢）用户时

```swift
1. 记录到 likedProfiles
2. 发送邀请到服务器
3. 清除本地和服务器端推荐缓存
4. 检查是否匹配（双向邀请）
```

**关键代码**：
```swift
private func likeProfile() {
    // 记录 Like
    likedProfiles.append(profile)
    
    // 发送邀请
    let invitation = try await supabaseService.sendInvitation(...)
    
    // 清除缓存
    cachedProfiles.removeAll()
    profiles.removeAll { $0.userId == profile.userId }
    
    // 清除持久化缓存
    UserDefaults.standard.removeObject(forKey: cacheKey)
    
    // 清除服务器端缓存
    try await supabaseService.clearRecommendationCache(...)
}
```

---

## 两种数据源

### 推荐系统（Two-Tower 模型）

**特点**：
- ✅ 使用机器学习模型
- ✅ 按推荐分数排序
- ✅ 个性化推荐
- ✅ 高质量数据
- ✅ 会缓存（5 分钟）

**代码**：
```swift
let recommendations = try await recommendationService.getRecommendations(
    for: currentUser.id,
    limit: 20
)

let sortedRecommendations = recommendations.sorted { $0.score > $1.score }
saveCachedProfilesToStorage(isFromRecommendation: true)
```

### 传统分页（Traditional Pagination）

**特点**：
- ⚠️ 按时间顺序查询数据库
- ⚠️ 使用 `offset` 和 `limit` 分页
- ⚠️ 无个性化
- ⚠️ 质量较低
- ❌ **不缓存**（作为回退方案）

**代码**：
```swift
let (supabaseProfiles, totalInBatch, filteredCount) = try await 
    supabaseService.getRecommendedProfiles(
        userId: currentUser.id,
        limit: limit,
        offset: offset
    )

// 注意：传统模式不更新缓存
// 不清除缓存，但也不保存传统模式的结果
```

### 对比表

| 特性 | 推荐系统 | 传统分页 |
|------|---------|---------|
| 排序方式 | 按推荐分数 | 按时间（`updated_at`） |
| 数据来源 | 机器学习模型 | 数据库直接查询 |
| 个性化 | ✅ 有 | ❌ 无 |
| 分页方式 | 固定数量返回 | `offset` + `limit` |
| 缓存策略 | ✅ 缓存（5分钟） | ❌ 不缓存 |
| 使用场景 | 主要方式 | 回退/备用 |

---

## 最佳实践

### 1. 缓存策略

- ✅ **优先使用推荐系统缓存**：质量更高，个性化更好
- ✅ **快速验证优先**：切换 tab 时立即过滤
- ✅ **完整验证后台进行**：不阻塞 UI
- ❌ **传统分页不缓存**：避免低质量数据覆盖缓存

### 2. 状态同步

- ✅ **立即更新缓存**：Pass 用户后立即更新持久化缓存
- ✅ **多重过滤**：服务器端 + 本地状态双重检查
- ✅ **索引管理**：保存和恢复浏览位置

### 3. 错误处理

- ✅ **缓存过期**：自动清除并重新加载
- ✅ **验证失败**：回退到重新加载
- ✅ **数据不足**：清除缓存并加载新数据

### 4. 性能优化

- ✅ **5 分钟缓存**：平衡数据新鲜度和性能
- ✅ **异步验证**：不阻塞 UI 线程
- ✅ **快速响应**：优先显示缓存，后台验证

---

## 总结

推荐系统缓存架构采用**双层缓存**（内存 + 持久化）和**双重验证**（快速 + 完整）机制，确保：

1. **快速响应**：优先使用缓存，立即显示
2. **数据准确**：多重过滤确保不显示已交互用户
3. **状态一致**：Pass/Like 后立即同步缓存
4. **体验流畅**：保存位置，切换 tab 后恢复

该架构在保证快速响应的同时，确保数据的准确性和一致性，为用户提供流畅的推荐体验。

---

**最后更新**：2025-01-27

