# Invitations 和 Matches Supabase 配置说明

## 概述

已完成为 BrewNet 应用配置 Supabase 数据库，用于存储用户发送的邀请（invitations）、收到的邀请和匹配（matches）信息。

## 📋 已完成的工作

### 1. 数据库表结构

#### invitations 表
- `id`: UUID 主键
- `sender_id`: 发送者用户ID（外键引用 users 表）
- `receiver_id`: 接收者用户ID（外键引用 users 表）
- `status`: 状态（pending, accepted, rejected, cancelled）
- `reason_for_interest`: 邀请原因（可选）
- `sender_profile`: 发送者简要资料（JSONB）
- `created_at`: 创建时间
- `updated_at`: 更新时间

#### matches 表
- `id`: UUID 主键
- `user_id`: 用户ID（外键引用 users 表）
- `matched_user_id`: 匹配用户ID（外键引用 users 表）
- `matched_user_name`: 匹配用户姓名
- `match_type`: 匹配类型（mutual, invitation_based, recommended）
- `is_active`: 是否活跃
- `created_at`: 创建时间
- `updated_at`: 更新时间

### 2. Swift 模型

已在 `SupabaseModels.swift` 中添加：

- `SupabaseInvitation`: 邀请模型
- `InvitationStatus`: 邀请状态枚举
- `InvitationProfile`: 邀请资料模型
- `SupabaseMatch`: 匹配模型（已更新）
- `MatchType`: 匹配类型枚举

### 3. 服务方法

已在 `SupabaseService.swift` 中添加完整的方法集：

#### Invitation 操作方法：
- `sendInvitation()`: 发送邀请
- `getSentInvitations()`: 获取发送的邀请
- `getReceivedInvitations()`: 获取收到的邀请
- `getPendingInvitations()`: 获取待处理的邀请
- `acceptInvitation()`: 接受邀请
- `rejectInvitation()`: 拒绝邀请
- `cancelInvitation()`: 取消邀请
- `getInvitation()`: 获取单个邀请

#### Match 操作方法：
- `createMatch()`: 创建匹配
- `getMatches()`: 获取所有匹配
- `getActiveMatches()`: 获取活跃匹配
- `getMatchStats()`: 获取匹配统计
- `deactivateMatch()`: 取消匹配
- `checkMatchExists()`: 检查是否已匹配
- `getMatch()`: 获取单个匹配

### 4. 数据库触发器

SQL 脚本包含自动触发器：
- 当邀请状态变为 `accepted` 时，自动创建双向匹配记录
- 自动更新 `updated_at` 时间戳

### 5. 行级安全策略（RLS）

已为两个表配置完整的 RLS 策略：
- 用户只能查看自己发送/收到的邀请
- 用户只能查看与自己相关的匹配
- 适当的插入、更新、删除权限控制

## 🚀 使用步骤

### 步骤 1: 在 Supabase Dashboard 中执行 SQL 脚本

1. 打开 Supabase Dashboard
2. 进入 SQL Editor
3. 复制并执行 `create_invitations_and_matches_tables.sql` 文件中的所有 SQL 语句

### 步骤 2: 验证表创建

在 SQL Editor 中执行：

```sql
-- 检查 invitations 表
SELECT * FROM invitations LIMIT 1;

-- 检查 matches 表
SELECT * FROM matches LIMIT 1;
```

### 步骤 3: 在代码中使用

#### 发送邀请示例：

```swift
let service = SupabaseService.shared

// 创建邀请资料
let senderProfile = InvitationProfile(
    name: "John Doe",
    jobTitle: "Senior Developer",
    company: "Tech Corp",
    location: "San Francisco",
    bio: "Passionate developer",
    profileImage: nil,
    expertise: ["iOS", "Swift"]
)

// 发送邀请
let invitation = try await service.sendInvitation(
    senderId: currentUserId,
    receiverId: targetUserId,
    reasonForInterest: "Interested in networking",
    senderProfile: senderProfile
)
```

#### 获取邀请示例：

```swift
// 获取收到的待处理邀请
let pendingInvitations = try await service.getPendingInvitations(userId: currentUserId)

// 获取发送的邀请
let sentInvitations = try await service.getSentInvitations(userId: currentUserId)

// 接受邀请
let accepted = try await service.acceptInvitation(
    invitationId: invitation.id,
    userId: currentUserId
)
// 注意：接受邀请后，触发器会自动创建匹配记录
```

#### 获取匹配示例：

```swift
// 获取所有活跃匹配
let matches = try await service.getActiveMatches(userId: currentUserId)

// 获取匹配统计
let stats = try await service.getMatchStats(userId: currentUserId)
print("Total: \(stats.total), Active: \(stats.active)")

// 检查是否已匹配
let exists = try await service.checkMatchExists(
    userId1: currentUserId,
    userId2: otherUserId
)
```

## 🔒 安全特性

1. **行级安全（RLS）**: 用户只能访问自己的数据
2. **唯一约束**: 防止重复邀请和匹配
3. **外键约束**: 确保数据完整性
4. **自动触发器**: 确保数据一致性

## 📝 注意事项

1. **JSONB 字段**: `sender_profile` 字段存储为 JSONB，确保在发送时正确格式化
2. **双向匹配**: 当邀请被接受时，系统会自动为双方创建匹配记录
3. **状态管理**: 邀请状态只能按照预定义的流程变更（pending → accepted/rejected/cancelled）
4. **匹配去重**: 系统会自动检查并防止创建重复的活跃匹配

## 🐛 故障排除

如果遇到问题：

1. **表不存在**: 确保已执行 SQL 脚本
2. **权限错误**: 检查 RLS 策略是否正确配置
3. **JSONB 解析错误**: 确保 `sender_profile` 数据格式正确
4. **触发器未触发**: 检查数据库触发器是否已创建

## 📚 相关文件

- `create_invitations_and_matches_tables.sql`: SQL 脚本
- `SupabaseModels.swift`: 数据模型
- `SupabaseService.swift`: 服务方法
- `SupabaseConfig.swift`: 配置和表枚举

## ✅ 测试建议

建议测试以下场景：

1. 发送邀请并验证数据存储
2. 接受/拒绝邀请并验证状态变更
3. 验证接受邀请后自动创建匹配
4. 测试查询发送/收到的邀请
5. 测试匹配查询和统计功能
6. 验证 RLS 策略（用户只能访问自己的数据）

---

完成时间: 2025年1月
版本: 1.0

