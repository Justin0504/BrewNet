# 添加消息提示弹窗功能 (Add Message Prompt Feature)

## 功能概述

在用户**当天首次**点赞/右滑用户卡片时，触发一个提示弹窗，鼓励用户在发送连接邀请时附加个性化消息。

## 实现细节

### 1. 触发机制
- **触发条件**: 用户当天首次点赞/右滑
- **触发时机**: 用户点赞或右滑用户卡片时，在扣减配额之后
- **数据记录**: 在 Supabase `users` 表的 `first_like_today` 字段记录当天首次点赞的日期
- **实现位置**: 
  - `BrewNetMatchesView.swift` - 主推荐页面
  - `ExploreView.swift` - AI Headhunter 搜索结果
  - `CategoryRecommendationsView.swift` - 分类推荐页面

### 2. 弹窗UI设计

#### 标题
- **文案**: "ADD A MESSAGE TO YOUR INVITATION?"
- **样式**: 大写、加粗、18pt、居中对齐

#### 内容
- **文案**: "Personalize your request by adding a message. People are more likely to accept requests that include a message."
- **样式**: 14pt、次要颜色、居中对齐

#### 按钮

1. **Add a Message** (主按钮)
   - 白色文字 + 棕色背景 (`Color(red: 0.4, green: 0.2, blue: 0.1)`)
   - 点击后打开临时消息界面 (`TemporaryChatFromProfileView`)
   - 与现有的 "Temporary Message" 按钮功能相同

2. **Send Anyway** (次按钮)
   - 棕色文字 + 白色背景 + 棕色边框
   - 点击后直接发送邀请（不附加消息）
   - 与直接点赞/右滑的效果相同

### 3. 用户流程

#### 场景 1: 当天首次点赞（触发弹窗）
```
用户点赞/右滑 
  → 检查配额 
  → 检查是否为当天首次点赞
  → 是首次 → 更新 first_like_today 为今天日期
  → 显示弹窗
  → 用户选择:
     A. "Add a Message" → 打开临时消息界面 → 发送消息 + 邀请
     B. "Send Anyway" → 直接发送邀请（无消息）
```

#### 场景 2: 当天非首次点赞（不触发弹窗）
```
用户点赞/右滑 
  → 检查配额 
  → 检查是否为当天首次点赞
  → 不是首次（first_like_today 已是今天）
  → 直接发送邀请（无消息）
  → 卡片移除，显示下一张
```

### 4. 技术实现

#### 数据库字段
```sql
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS first_like_today DATE;
```

#### SupabaseService 新增函数
```swift
// 检查是否为当天首次点赞
func isFirstLikeToday(userId: String) async throws -> Bool

// 更新首次点赞日期为今天
func updateFirstLikeToday(userId: String) async throws
```

#### 状态变量
```swift
@State private var showAddMessagePrompt = false
@State private var profilePendingInvitation: BrewNetProfile? = nil
```

#### 核心逻辑 (以 BrewNetMatchesView 为例)
```swift
// 在 likeProfile() 函数中添加
let isFirstLike = try await supabaseService.isFirstLikeToday(userId: currentUser.id)
if isFirstLike {
    // 更新首次点赞日期
    try await supabaseService.updateFirstLikeToday(userId: currentUser.id)
    
    await MainActor.run {
        profilePendingInvitation = profile
        showAddMessagePrompt = true
        // 重置动画
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = .zero
            rotationAngle = 0
        }
    }
    return // 停止，等待用户操作
}
```

#### 辅助函数
```swift
private func sendInvitationWithoutMessage(profile: BrewNetProfile) async {
    // 记录点赞行为
    // 发送邀请
    // 更新UI（移除卡片、重置状态等）
    // 处理互相匹配逻辑
}
```

### 5. 修改的文件

1. **add_first_like_today_column.sql** (新建)
   - 添加 `first_like_today` 字段到 `users` 表
   - 创建索引以提升查询性能

2. **BrewNet/SupabaseService.swift**
   - 添加 `isFirstLikeToday()` 函数：检查是否为当天首次点赞
   - 添加 `updateFirstLikeToday()` 函数：更新首次点赞日期

3. **BrewNet/BrewNetMatchesView.swift**
   - 添加状态变量
   - 修改 `likeProfile()` 函数使用新的首次点赞检查机制
   - 添加 `sendInvitationWithoutMessage()` 函数
   - 添加 `addMessagePromptView` UI组件

4. **BrewNet/ExploreView.swift**
   - 添加状态变量
   - 修改 `handleCoffeeChatConnect()` 函数使用新的首次点赞检查机制
   - 添加 `sendInvitationWithoutMessage()` 函数
   - 添加 `addMessagePromptView` UI组件

5. **BrewNet/CategoryRecommendationsView.swift**
   - 添加状态变量
   - 修改 `likeProfile()` 函数使用新的首次点赞检查机制
   - 添加 `sendInvitationWithoutMessage()` 函数
   - 添加 `addMessagePromptView` UI组件

## 产品价值

1. **提高连接质量**: 鼓励用户发送个性化消息，提升邀请接受率
2. **精准时机**: 在用户当天首次使用时提示，既不打扰又能教育用户
3. **用户教育**: 通过文案提示，让用户了解附加消息的好处
4. **灵活选择**: 用户可以选择添加消息或快速发送
5. **每日一次**: 避免重复打扰，保持良好的用户体验

## 部署步骤

1. **运行 SQL 脚本**:
   ```bash
   # 在 Supabase SQL Editor 中运行
   psql < add_first_like_today_column.sql
   ```

2. **验证数据库更改**:
   - 检查 `users` 表是否有 `first_like_today` 字段
   - 确认字段类型为 `DATE`

3. **部署代码**: 
   - 推送代码到远程仓库
   - 构建并发布新版本

## 测试建议

1. **数据库测试**:
   - 验证 `first_like_today` 字段已正确添加
   - 测试字段的读写功能

2. **功能测试**:
   - 验证用户当天首次点赞时弹窗显示
   - 验证用户当天第二次点赞时弹窗不显示
   - 测试跨天后，首次点赞再次显示弹窗
   - 测试两个按钮的功能是否正常

3. **UI测试**:
   - 确认弹窗在三个不同场景下都能正常显示
   - 检查卡片动画和状态重置是否流畅

4. **边界测试**:
   - 测试配额用完时的行为
   - 测试网络错误时的处理
   - 验证配额扣减逻辑（弹窗触发前已扣减）

## 未来优化方向

1. **个性化触发**: 可以基于用户历史消息发送率决定是否显示提示
2. **A/B 测试**: 测试不同文案或显示频率的效果
3. **数据分析**: 跟踪弹窗显示后的消息发送率和接受率变化
4. **智能提醒**: 对于从不发消息的用户，可以增加提示频率

