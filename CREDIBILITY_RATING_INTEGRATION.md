# 信誉评分系统触发时机与集成方案

## 📍 当前流程分析

### 现有 Coffee Chat 确认流程（CoffeeChatScheduleView.swift）

```
用户查看日程
    ↓
点击 "We Met" 按钮
    ↓
GPS 距离验证（需要 < 100米）
    ↓
验证通过，点击 "Confirm"
    ↓
调用 confirmMet() → markCoffeeChatAsMet()
    ↓
数据库更新 hasMet = true
    ↓
显示庆祝动画（3秒）
    ↓
✅ 见面确认完成
```

## 🎯 评分系统触发时机

### 最佳触发点：**庆祝动画结束后**

**原因**：
1. ✅ 已经验证双方确实见面（GPS < 100米）
2. ✅ 用户心情愉悦（刚看完庆祝动画）
3. ✅ 自然的流程衔接（见面 → 庆祝 → 评分）
4. ✅ 避免打断确认流程

### 触发规则

#### 规则1：单方确认后，立即评分对方
```
用户A点击确认 → A评分B
```

#### 规则2：双方都确认后，各自评分
```
用户A确认 → A评分B
用户B确认 → B评分A
```

#### 规则3：评分窗口期（推荐）
- **即时评分**：确认后立即弹出（推荐）
- **延迟评分**：24小时内可以评分
- **超时**：48小时后不能评分

## 🔧 集成方案

### 方案1：立即评分（推荐）⭐

修改 `CoffeeChatScheduleView.swift` 中的 `confirmMet()` 函数：

```swift
// 在 confirmMet() 函数的最后，庆祝动画显示3秒后
private func confirmMet(scheduleId: String) {
    // ... 现有代码 ...
    
    await MainActor.run {
        // ... 现有的更新逻辑 ...
        
        // 显示庆祝视图
        showingCelebration = true
        
        // 3秒后自动关闭庆祝视图，并弹出评分界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showingCelebration = false
            }
            
            // 🆕 延迟0.5秒后弹出评分界面（让庆祝动画完全消失）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRatingSheet = true  // 触发评分
            }
        }
    }
}
```

在 `ScheduleCardView` 中添加状态：

```swift
struct ScheduleCardView: View {
    // ... 现有状态 ...
    @State private var showRatingSheet = false  // 🆕 评分界面显示状态
    
    var body: some View {
        cardWithCelebration
            // ... 现有代码 ...
            .sheet(isPresented: $showRatingSheet) {
                MeetingRatingView(
                    meetingId: schedule.id.uuidString,
                    otherUserId: schedule.participantId,
                    otherUserName: schedule.participantName
                )
            }
    }
}
```

### 方案2：手动评分入口

在 `ScheduleCardView` 中添加评分按钮（已见面但未评分时显示）：

```swift
private var ratingButton: some View {
    if hasMet && !hasRated {  // 🆕 需要添加 hasRated 状态
        Button(action: {
            showRatingSheet = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                Text("Rate This Meeting")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.orange.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
    }
}
```

### 方案3：评分提醒通知（后端）

```swift
// 确认见面24小时后，如果还没评分，发送推送通知
{
  "title": "How was your coffee chat?",
  "body": "Rate your meeting with {participantName} to help build a trusted community!",
  "data": {
    "type": "rating_reminder",
    "meetingId": "xxx",
    "participantId": "yyy"
  }
}
```

点击通知后打开评分界面：

```swift
// AppDelegate 或 NotificationService
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo
    
    if let type = userInfo["type"] as? String, type == "rating_reminder",
       let meetingId = userInfo["meetingId"] as? String,
       let participantId = userInfo["participantId"] as? String {
        // 导航到评分界面
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowRatingView"),
            object: nil,
            userInfo: ["meetingId": meetingId, "participantId": participantId]
        )
    }
    
    completionHandler()
}
```

## 📊 数据库改动

### 扩展 coffee_chat_schedules 表

```sql
ALTER TABLE coffee_chat_schedules
ADD COLUMN user_rated BOOLEAN DEFAULT FALSE,
ADD COLUMN participant_rated BOOLEAN DEFAULT FALSE,
ADD COLUMN user_rating_id UUID REFERENCES meeting_ratings(id),
ADD COLUMN participant_rating_id UUID REFERENCES meeting_ratings(id),
ADD COLUMN met_at TIMESTAMP;  -- 确认见面的时间

-- 索引
CREATE INDEX idx_unrated_meetings ON coffee_chat_schedules(has_met, user_rated)
WHERE has_met = TRUE AND user_rated = FALSE;
```

### 查询未评分的见面

```sql
-- 获取当前用户需要评分的见面
SELECT * FROM coffee_chat_schedules
WHERE user_id = :currentUserId
  AND has_met = TRUE
  AND user_rated = FALSE
  AND met_at > NOW() - INTERVAL '48 hours'  -- 48小时内
ORDER BY met_at DESC;
```

## 🔄 完整流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    Coffee Chat Schedule                      │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   "We Met" Button  (hasMet = false)                 │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   GPS Distance Check (< 100m)                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   Confirm Button                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   confirmMet() → markCoffeeChatAsMet()              │    │
│  │   - Update hasMet = true                             │    │
│  │   - Record met_at = now()                            │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   Celebration Animation (3 seconds)                  │    │
│  │   🎉 "Connection Successful!"                        │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   🆕 MeetingRatingView Sheet                         │    │
│  │   - Star rating (0.5-5.0)                            │    │
│  │   - Optional tags                                    │    │
│  │   - Report misconduct option                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   Submit Rating                                      │    │
│  │   - Create meeting_rating record                     │    │
│  │   - Update credibility_scores                        │    │
│  │   - Set user_rated = true                            │    │
│  └─────────────────────────────────────────────────────┘    │
│                           ↓                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │   ✅ Show checkmark (hasMet = true)                  │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 🎨 用户体验设计

### 评分界面标题

```
"How was your coffee chat with {participantName}?"
```

### 评分完成后的反馈

```swift
// 评分提交成功后显示
struct RatingSuccessView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Thank You!")
                .font(.system(size: 24, weight: .bold))
            
            Text("Your feedback helps build a trusted community")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
```

### 跳过评分选项

```swift
// 在评分界面底部添加
Button("Skip for Now") {
    dismiss()
}
.font(.system(size: 14))
.foregroundColor(.gray)
.padding(.bottom, 8)
```

## 🔐 防止滥用

### 规则1：只能评分确认见面的用户

```swift
// 检查是否可以评分
func canRate(scheduleId: String) -> Bool {
    guard let schedule = getSchedule(scheduleId) else { return false }
    
    // 必须已经确认见面
    guard schedule.hasMet else { return false }
    
    // 不能重复评分
    guard !schedule.userRated else { return false }
    
    // 48小时内有效
    guard let metAt = schedule.metAt,
          Date().timeIntervalSince(metAt) < 48 * 3600 else {
        return false
    }
    
    return true
}
```

### 规则2：双方独立评分，互不可见

```swift
// 用户A的评分不会影响用户B的评分
// 只有在双方都提交后，才会更新各自的信誉评分
```

### 规则3：评分后不可修改

```swift
// 一旦提交评分，不能修改
// 防止用户事后报复性改分
```

## 📱 UI集成清单

### ✅ 已完成
- [x] CredibilitySystem.swift - 数据模型
- [x] MeetingRatingView.swift - 评分界面
- [x] MisconductReportView.swift - 举报系统
- [x] CredibilityBadgeView.swift - 信誉徽章

### 🔲 待集成
- [ ] 修改 `CoffeeChatScheduleView.swift`
  - [ ] 添加 `showRatingSheet` 状态
  - [ ] 在 `confirmMet()` 后触发评分
  - [ ] 添加 `.sheet(isPresented: $showRatingSheet)`
- [ ] 添加 `hasRated` 状态到 `CoffeeChatSchedule` 模型
- [ ] 创建后端 API
  - [ ] `POST /api/meetings/{id}/rate` - 提交评分
  - [ ] `GET /api/meetings/pending-ratings` - 获取待评分列表
  - [ ] `PUT /api/schedules/{id}/rating-status` - 更新评分状态
- [ ] 数据库迁移
  - [ ] 添加评分相关字段到 `coffee_chat_schedules`
  - [ ] 创建 `meeting_ratings` 表
  - [ ] 创建 `credibility_scores` 表
- [ ] 推送通知（可选）
  - [ ] 24小时后发送评分提醒
  - [ ] 点击通知打开评分界面

## 💡 推荐实施步骤

### Phase 1: 核心评分流程（必须）
1. 修改 `CoffeeChatScheduleView.swift`，在确认见面后弹出评分界面
2. 创建后端 API 接收评分数据
3. 实现信誉评分计算逻辑

### Phase 2: 完善用户体验（重要）
4. 在个人主页显示信誉徽章
5. 在匹配卡片上显示简化徽章
6. 添加"待评分"列表页面

### Phase 3: 高级功能（可选）
7. 评分提醒推送通知
8. 评分统计和分析
9. 信誉等级权益兑现（PRO折扣、匹配加成）

## 🚀 快速开始代码

### 最小化集成（5分钟）

```swift
// 1. 在 ScheduleCardView 中添加状态
@State private var showRatingSheet = false

// 2. 修改 confirmMet() 函数
DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
    showingCelebration = false
    showRatingSheet = true  // 🆕 触发评分
}

// 3. 在 body 中添加 sheet
.sheet(isPresented: $showRatingSheet) {
    MeetingRatingView(
        meetingId: schedule.id.uuidString,
        otherUserId: schedule.participantId,
        otherUserName: schedule.participantName
    )
}
```

完成！现在用户确认见面后会自动弹出评分界面。

## ❓ 常见问题

### Q: 如果用户跳过评分怎么办？
A: 保留评分入口，用户可以在48小时内随时回来评分。超过48小时后，评分窗口关闭，默认为"无评分"（不影响信誉分）。

### Q: 用户可以不评分吗？
A: 可以。但为了鼓励评分，可以设置激励：
- 评分后获得积分奖励
- 连续10次评分解锁特殊徽章
- 评分率高的用户获得更高的匹配优先级

### Q: 如何防止恶意低分？
A: 
1. 评分需要GPS验证，确保真实见面
2. 举报系统用于处理严重问题
3. 评分标签用于分析评分合理性
4. 后台监控异常评分模式

### Q: 双方评分会相互影响吗？
A: 不会。双方独立评分，互不可见，防止报复性评分。

## 📝 总结

**最佳触发时机**：
- ✅ **确认见面（confirmMet）后 3.5秒**
- ✅ 庆祝动画结束后立即弹出
- ✅ 自然流畅的用户体验

**集成难度**：
- 🟢 简单：只需要3行代码即可触发评分界面
- 🟡 中等：完整集成需要后端支持
- 🔴 复杂：高级功能需要推送通知和数据分析

**下一步**：
修改 `CoffeeChatScheduleView.swift`，添加评分触发逻辑！

