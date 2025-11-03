# BrewNet 推荐系统流程说明

## 📋 概述

BrewNet 的推荐系统是一个多层次的社交网络匹配系统，结合了用户资料、网络意图、缓存优化和实时交互等功能。

## 🏗️ 系统架构

### 核心组件

1. **推荐引擎** (`BrewNetMatchesView.swift`)
2. **分类推荐** (`CategoryRecommendationsView.swift`)  
3. **探索页面** (`ExploreView.swift`)
4. **数据服务** (`SupabaseService.swift`)
5. **AI 助手** (`GeminiAIService.swift`)
6. **聊天界面** (`ChatInterfaceView.swift`)

---

## 🔄 推荐流程详解

### 阶段 1: 探索页面 (ExploreView)

#### 流程
```
用户打开 Explore 标签页
    ↓
加载当前用户资料 (loadUserProfile)
    ↓
加载各意图类别的用户数量统计 (loadUserCounts)
    ↓
显示分类卡片：
  - 用户自己的意图（优先显示，全宽卡片）
  - 其他 4 个意图类别（2x2 网格）
  - "Out of Orbit"（拓展推荐）
    ↓
用户点击某个类别卡片
    ↓
进入该分类的推荐列表
```

#### 数据来源
- **用户数量统计**: `getUserCountsByAllIntentions()` 
- **总用户数**: `getTotalUserCount()`
- **用户排序**: 基于用户自己的 `networkingIntention` 排序

---

### 阶段 2: 推荐列表加载 (BrewNetMatchesView / CategoryRecommendationsView)

#### 流程
```
视图出现 (onAppear)
    ↓
检查本地缓存 (loadCachedProfilesFromStorage)
    ↓
【分支判断】
├─ 如果有缓存且 < 5分钟
│    ↓
│   立即显示缓存数据
│    ↓
│   后台静默刷新 (refreshProfilesSilently)
│
└─ 如果没有缓存或已过期
     ↓
     显示加载状态
     ↓
     loadProfilesBatch(offset: 0, limit: 20)
```

#### 缓存策略

**持久化存储**:
- 键名: `"matches_cache_{userId}"`
- 时间戳: `"matches_cache_time_{userId}"`
- 有效期: 5 分钟
- 存储方式: UserDefaults + JSON 编码

**刷新策略**:
- 首次加载: 显示加载动画
- 缓存命中: 立即显示，后台更新
- 下拉刷新: 清空缓存重新加载

---

### 阶段 3: 后端数据获取 (SupabaseService)

#### getRecommendedProfiles 函数
```swift
func getRecommendedProfiles(userId: String, limit: Int, offset: Int) 
    → ([SupabaseProfile], totalInBatch, filteredCount)
```

**SQL 查询逻辑**:
```sql
SELECT * FROM profiles
WHERE user_id != :currentUserId
ORDER BY created_at DESC
LIMIT :limit OFFSET :offset
```

**分页实现**:
- 使用 Supabase PostgREST 的 `range(from:to:)` 方法
- 格式: `range: 0-19` 表示获取前 20 条

**数据过滤**:
- 排除当前用户
- 验证 JSONB 字段完整性（core_identity, professional_background 等）
- 过滤掉 null 或不完整的记录

**返回格式**:
- `profiles`: 成功解码的完整资料
- `totalInBatch`: 批次总数量
- `filteredCount`: 因数据不完整被过滤的数量

---

### 阶段 4: 卡片展示 (UserProfileCardView)

#### 数据转换流程
```
SupabaseProfile (数据库格式)
    ↓
toBrewNetProfile() 转换
    ↓
BrewNetProfile (Swift 模型)
    ↓
UserProfileCardView (UI 展示)
```

#### 显示内容层次
1. **Level 1 - 核心信息**: 头像、姓名、职业、行业
2. **Level 2 - 匹配线索**: 技能、兴趣、价值标签
3. **Level 3 - 深入了解**: 自我介绍、教育背景、工作经历

---

### 阶段 5: 用户交互 - 滑动行为

#### 左滑 (Pass)
```
左滑手势触发
    ↓
passProfile()
    ↓
添加到 passedProfiles 数组
    ↓
moveToNextProfile() → currentIndex += 1
    ↓
加载下一张卡片
```

#### 右滑 (Like)
```
右滑手势触发
    ↓
likeProfile()
    ↓
发送邀请到 Supabase:
  - senderId: 当前用户 ID
  - receiverId: 被点赞用户 ID
  - senderProfile: 当前用户资料快照
    ↓
检查双向邀请 (getPendingInvitations)
    ↓
【分支判断】
├─ 发现对方也给我发了邀请
│    ↓
│   自动接受双方邀请
│    ↓
│   数据库触发器创建匹配记录
│    ↓
│   显示 "It's a Match!" 提示
│    ↓
│   发送 UserMatched 通知
│
└─ 对方未给我发邀请
     ↓
     仅保存邀请记录
     ↓
     继续下一张卡片
```

---

### 阶段 6: 分页加载

#### 触发时机
1. 用户滑动到最后一张卡片
2. `noMoreProfilesView` 出现
3. 自动触发 `loadMoreProfiles()`

#### 加载策略
```swift
if currentIndex >= profiles.count - 3 {
    loadMoreProfiles()  // 预加载
}
```

#### 分页参数
- 初始加载: `offset=0, limit=20`（快速显示）
- 后续加载: `offset=currentCount, limit=200`（批量加载）
- 终止条件: `返回数量 < limit`

---

### 阶段 7: 匹配后流程

#### 数据库匹配记录
```sql
INSERT INTO matches (
    user_id,
    matched_user_id,
    matched_user_name,
    match_type,
    is_active
) VALUES (...)
```

#### Chat 视图集成
```
收到 "UserMatched" 通知
    ↓
ChatInterfaceView 监听
    ↓
重新加载匹配列表 (loadChatSessionsFromDatabase)
    ↓
获取活跃匹配 (getActiveMatches)
    ↓
为每个匹配创建 ChatSession
    ↓
显示在聊天列表顶部
```

---

## 🔧 高级功能

### 1. AI 推荐引擎 (GeminiAIService)

**用途**: 生成破冰话题建议

**生成类型**:
- `iceBreaker`: 开场话题
- `followUp`: 跟进问题
- `compliment`: 赞美话题
- `sharedInterest`: 共同兴趣
- `question`: 一般性问题

**当前实现**: 模拟响应（返回预定义建议）
**真实实现**: 调用 Gemini Pro API

---

### 2. 隐私控制 (PrivacyTrust)

**可见性设置**:
- `company`: 公司信息
- `skills`: 技能列表
- `interests`: 兴趣爱好
- `location`: 位置信息
- `timeslot`: 可用时段

**显示规则**:
- `isConnection = true`: 已匹配用户，显示更多信息
- `isConnection = false`: 未匹配用户，仅显示公开信息

---

### 3. 性能优化

**缓存层**:
- 内存缓存: `cachedProfiles` 数组
- 持久化缓存: UserDefaults JSON
- 缓存失效: 5 分钟自动刷新

**并发加载**:
- 使用 `Task` 异步加载
- Profile 详细信息并发获取
- 避免阻塞 UI 线程

**数据去重**:
- 使用 `Set<String>` 跟踪已处理用户
- 确保每个用户只显示一次

---

## 📊 数据流图

```
┌─────────────────┐
│   ExploreView   │  ← 用户选择类别
└────────┬────────┘
         │
         ↓
┌─────────────────────────┐
│ CategoryRecommendations │  ← 分类推荐 OR 全部推荐
│     / MatchesView       │
└────────┬────────────────┘
         │
         ↓
┌─────────────────────────┐
│  loadCachedProfiles     │  ← 检查本地缓存
└────────┬────────────────┘
         │
         ↓
    【缓存命中？】
    ├─ 是 → 立即显示 + 后台刷新
    └─ 否 → 显示加载状态
         │
         ↓
┌─────────────────────────┐
│  SupabaseService        │
│  getRecommendedProfiles │
└────────┬────────────────┘
         │
         ↓
┌─────────────────────────┐
│  Supabase Database      │  ← PostgreSQL + JSONB
│  (profiles table)       │
└────────┬────────────────┘
         │
         ↓
┌─────────────────────────┐
│  数据解码与过滤         │  ← 验证完整性
└────────┬────────────────┘
         │
         ↓
┌─────────────────────────┐
│  toBrewNetProfile       │  ← 转换为 Swift 模型
└────────┬────────────────┘
         │
         ↓
┌─────────────────────────┐
│  UserProfileCardView    │  ← UI 渲染
└────────┬────────────────┘
         │
         ↓
    【用户交互】
    ├─ 左滑 → Pass → 下一张
    └─ 右滑 → Like → 发邀请 → 检查双向 → 创建匹配
         │
         ↓
┌─────────────────────────┐
│  ChatInterfaceView      │  ← 匹配成功后
└─────────────────────────┘
```

---

## 🎯 关键特性总结

1. **智能缓存**: 5 分钟有效期，优先显示缓存，后台静默更新
2. **分页加载**: 初始 20 条快速显示，后续 200 条批量加载
3. **双向匹配**: 检测互相邀请，自动创建匹配记录
4. **隐私分层**: 根据连接状态显示不同级别的信息
5. **实时通知**: 匹配成功自动通知聊天界面
6. **数据验证**: 过滤不完整的用户资料
7. **并发优化**: 异步加载，避免阻塞 UI

---

## 📝 数据模型

### 核心数据结构
- `BrewNetProfile`: 完整的用户资料（6 个层次）
- `SupabaseProfile`: 数据库 JSONB 格式
- `ChatSession`: 聊天会话（包含用户和消息）
- `SupabaseMatch`: 匹配记录

### 数据库表
- `profiles`: 用户资料（JSONB 存储）
- `invitations`: 邀请记录
- `matches`: 匹配记录
- `users`: 用户基础信息

---

## 🔍 调试建议

1. 查看控制台日志输出的 emoji 标记
2. 检查缓存有效期和刷新时机
3. 验证 JSONB 字段完整性
4. 监控分页加载的数量和偏移量
5. 观察双向匹配的触发条件

---

## 📖 相关文件索引

- **UI**: `BrewNetMatchesView.swift`, `CategoryRecommendationsView.swift`, `ExploreView.swift`
- **服务**: `SupabaseService.swift`, `GeminiAIService.swift`
- **模型**: `ProfileModels.swift`, `SupabaseModels.swift`
- **聊天**: `ChatInterfaceView.swift`
- **数据库**: `DatabaseManager.swift`

---

**最后更新**: 2024-12-28
**版本**: 1.0

