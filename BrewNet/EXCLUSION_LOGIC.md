# 用户排除逻辑说明

## 📋 问题诊断

当出现 "0 valid profiles from 0 recommendations" 时，说明推荐系统在计算推荐时就已经没有候选用户了。

## 🔍 排除逻辑分析

### 排除的用户类型

`getExcludedUserIds()` 函数会排除以下类型的用户：

#### 1. **已发送邀请的用户**（所有状态）
```swift
// 排除所有已发送邀请的用户（pending, accepted, rejected, cancelled）
let sentInvitations = try await getSentInvitations(userId: userId)
for invitation in sentInvitations {
    excludedUserIds.insert(invitation.receiverId)
}
```

**排除原因**：
- 已发送过邀请，不应该再次推荐
- 包括所有状态的邀请（pending, accepted, rejected, cancelled）

**可能的问题**：
- 如果用户发送了大量邀请，会导致大量用户被排除
- 被拒绝的邀请（rejected）的用户可能不应该永久排除

#### 2. **已收到且被拒绝的邀请的发送者**
```swift
// 排除所有已收到且被拒绝的邀请的发送者
let receivedInvitations = try await getReceivedInvitations(userId: userId)
let rejectedInvitations = receivedInvitations.filter { $0.status == .rejected }
for invitation in rejectedInvitations {
    excludedUserIds.insert(invitation.senderId)
}
```

**排除原因**：
- 用户拒绝了对方的邀请，不应该再次推荐

**可能的问题**：
- 这个逻辑可能过于严格，因为用户可能想重新考虑

#### 3. **已匹配的用户**（包括非活跃的）
```swift
// 排除所有已匹配的用户（包括活跃和非活跃的匹配）
let allMatches = try await getMatches(userId: userId, activeOnly: false)
for match in allMatches {
    if match.userId == userId {
        excludedUserIds.insert(match.matchedUserId)
    } else if match.matchedUserId == userId {
        excludedUserIds.insert(match.userId)
    }
}
```

**排除原因**：
- 已经匹配的用户不应该出现在推荐列表中

**这是合理的**，匹配的用户应该去聊天界面。

#### 4. **已交互过的用户**（like/pass/match）
```swift
// 从 user_interactions 表获取交互记录
let response = try await client
    .from("user_interactions")
    .select("target_user_id,interaction_type")
    .eq("user_id", value: userId)
    .execute()

// 排除所有 like、pass、match 类型的交互
for record in jsonArray {
    if let interactionType = record["interaction_type"] as? String,
       typeSet.contains(interactionType),  // like, pass, match
       let targetUserId = record["target_user_id"] as? String {
        excludedUserIds.insert(targetUserId)
    }
}
```

**排除原因**：
- 用户已经 Pass 或 Like 过的用户不应该再次推荐

**这是合理的**，但需要确保：
- Pass 操作确实被记录到 `user_interactions` 表
- 没有重复记录

---

## 🔍 问题排查步骤

### 1. 查看排除统计

运行应用后，查看控制台日志：

```
📊 Exclusion breakdown:
   - Sent invitations: X
   - Rejected invitations: X
   - Matches: X
   - Interactions: X
   - Total unique excluded: X
```

### 2. 查看候选用户统计

```
📊 Candidate analysis:
   - Total candidates from user_features table: X
   - Total excluded users: X
   - Excluded candidates: X/X
```

### 3. 诊断问题

#### 情况 A：候选用户数量为 0
```
📊 Processing 0 candidates (filtered from 0, excluded 0)
```

**可能原因**：
- `user_features` 表中没有其他用户
- 所有用户都在排除列表中

**解决方案**：
- 检查数据库中是否有其他用户
- 检查 `user_features` 表是否已同步用户数据

#### 情况 B：所有候选用户都被排除
```
📊 Processing 0 candidates (filtered from 100, excluded 100)
```

**可能原因**：
- 排除列表过大（192个用户）
- 所有候选用户都已被交互过

**解决方案**：
1. 检查排除列表是否包含不应该排除的用户
2. 考虑放宽某些排除条件（例如：已拒绝的邀请发送者可以重新推荐）
3. 增加数据库中的用户数量

#### 情况 C：推荐系统返回 0 个推荐
```
📊 Filtered results: 0 valid profiles from 0 recommendations
```

**可能原因**：
- 推荐系统在计算时没有找到候选用户
- 所有候选用户都在排除列表中

---

## 🛠️ 可能的优化方案

### 方案 1：放宽排除条件

**已拒绝的邀请发送者可以重新推荐**：
```swift
// 当前：排除所有已收到且被拒绝的邀请的发送者
// 优化：可以移除这个排除条件，让被拒绝的邀请发送者可以重新推荐
```

**已发送但被拒绝的邀请接收者可以重新推荐**：
```swift
// 如果发送的邀请被拒绝了，可以重新推荐该用户
let rejectedSentInvitations = sentInvitations.filter { $0.status == .rejected }
// 从排除列表中移除这些用户
```

### 方案 2：增加候选用户数量

```swift
// 从 user_features 表获取更多候选用户
let allCandidates = try await supabaseService.getAllCandidateFeatures(
    excluding: userId,
    limit: 2000  // 从 1000 增加到 2000
)
```

### 方案 3：检查数据库用户数量

检查数据库中实际有多少用户：
```sql
-- 检查 users 表总数
SELECT COUNT(*) FROM users;

-- 检查 user_features 表总数
SELECT COUNT(*) FROM user_features;

-- 检查当前用户排除了多少用户
-- (通过查看 invitations, matches, user_interactions 表)
```

---

## 📊 当前排除逻辑总结

| 排除类型 | 排除原因 | 是否合理 | 建议 |
|---------|---------|---------|------|
| 已发送邀请（所有状态） | 避免重复推荐 | ✅ 合理 | 保持 |
| 已收到且被拒绝的邀请发送者 | 用户已拒绝 | ⚠️ 可能过于严格 | 考虑放宽 |
| 已匹配的用户 | 已经匹配 | ✅ 合理 | 保持 |
| 已交互的用户（pass/like） | 已交互过 | ✅ 合理 | 保持 |

---

## 🔧 调试命令

### 检查排除列表详情

在 Supabase Dashboard 中执行：

```sql
-- 查看当前用户发送的所有邀请
SELECT receiver_id, status, COUNT(*) 
FROM invitations 
WHERE sender_id = 'YOUR_USER_ID'
GROUP BY receiver_id, status;

-- 查看当前用户收到的所有邀请
SELECT sender_id, status, COUNT(*) 
FROM invitations 
WHERE receiver_id = 'YOUR_USER_ID'
GROUP BY sender_id, status;

-- 查看当前用户的所有匹配
SELECT user_id, matched_user_id, is_active 
FROM matches 
WHERE user_id = 'YOUR_USER_ID' OR matched_user_id = 'YOUR_USER_ID';

-- 查看当前用户的所有交互记录
SELECT target_user_id, interaction_type, COUNT(*) 
FROM user_interactions 
WHERE user_id = 'YOUR_USER_ID'
GROUP BY target_user_id, interaction_type;
```

### 检查候选用户数量

```sql
-- 查看 user_features 表中的用户总数
SELECT COUNT(*) FROM user_features;

-- 查看 user_features 表中的用户（不包括当前用户）
SELECT COUNT(*) FROM user_features WHERE user_id != 'YOUR_USER_ID';
```

---

## 💡 建议

1. **检查数据库用户数量**：如果用户总数少于排除列表（192），所有用户都会被排除
2. **检查排除列表**：192个排除用户可能包含重复或不应该排除的用户
3. **考虑放宽排除条件**：某些类型的排除可能过于严格
4. **添加用户数据**：如果数据库用户太少，需要添加更多用户

---

**最后更新**：2025-01-27

