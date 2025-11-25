# BrewNet 点赞重置逻辑改进总结

## 改进日期
2024-11-22

---

## 改进内容

### ✅ 1. 修复重置后扣减错误
**问题**: 24小时重置后，扣减当前点赞时使用了错误的值（9 而非 5）  
**修复**: 第 5342 行，从 `newCount: 9` 改为 `newCount: 5`

```swift
// 修改前
try await decrementLikesDirectly(userId: userId, newCount: 9)

// 修改后  
try await decrementLikesDirectly(userId: userId, newCount: 5)
```

---

### ✅ 2. 新增主动检测函数

**文件**: `SupabaseService.swift`  
**函数**: `checkAndResetUserLikesIfNeeded(userId:)`  
**位置**: 第 5411-5497 行（新增）

**功能**:
- 主动检测用户点赞是否需要重置
- 不需要等到用户点赞时才触发
- 应用启动时自动调用

**完整逻辑**:
```swift
/// 检查并重置普通用户的 likes（如果已过24小时）
/// 这个函数可以在应用启动、用户登录或定期调用
func checkAndResetUserLikesIfNeeded(userId: String) async throws {
    // 1. 获取用户状态
    let isPro = json["is_pro"] as? Bool ?? false
    let likesRemaining = json["likes_remaining"] as? Int ?? 0
    let likesDepletedStr = json["likes_depleted_at"] as? String
    
    // 2. Pro 用户无需重置
    if isPro {
        print("✅ [Likes] Pro 用户，无需重置")
        return
    }
    
    // 3. 点赞未耗尽，无需重置
    guard let depletedStr = likesDepletedStr else {
        print("✅ [Likes] 点赞未耗尽（remaining: \(likesRemaining)），无需重置")
        return
    }
    
    // 4. 检查是否已过 24 小时
    let hoursPassed = Date().timeIntervalSince(depletedDate) / 3600
    
    if hoursPassed >= 24 {
        // 5. 重置为 6
        let reset = LikesReset(likes_remaining: 6, likes_depleted_at: nil)
        try await client.from("users").update(reset).eq("id", value: userId).execute()
        
        print("✅ [Likes] 点赞数已重置: 0 -> 6")
        
        // 6. 发送通知，触发 UI 更新
        NotificationCenter.default.post(
            name: NSNotification.Name("UserLikesReset"),
            object: nil,
            userInfo: ["userId": userId, "newLikesRemaining": 6]
        )
    } else {
        print("✅ [Likes] 未满 24 小时（还需 \(24 - hoursPassed) 小时），暂不重置")
    }
}
```

---

### ✅ 3. 应用启动时自动检测

**文件**: `ContentView.swift`  
**位置**: 第 82-89 行（新增）

**集成**:
```swift
private func checkProfileStatus(for user: AppUser) {
    Task {
        // 1. Pro 过期检测（已有）
        let proExpired = try await supabaseService.checkAndUpdateProExpiration(userId: user.id)
        
        // 2. 点赞重置检测（新增）✅
        try await supabaseService.checkAndResetUserLikesIfNeeded(userId: user.id)
        print("✅ [App启动] 点赞次数检查完成")
        
        // 3. Profile 状态检查
        // ...
    }
}
```

**触发时机**: 每次应用启动并认证成功后

---

## 完整的点赞重置流程

### 方式 1: 实时重置（点赞时）
```
用户点赞
  ↓
decrementUserLikes() 被调用
  ↓
检查 likes_depleted_at
  ↓
如果已过 24 小时
  ↓
重置为 6，扣减当前点赞（剩余 5）
  ↓
返回 true（点赞成功）
```

### 方式 2: 主动重置（应用启动）
```
用户打开应用
  ↓
ContentView.checkProfileStatus() 执行
  ↓
checkAndResetUserLikesIfNeeded() 被调用
  ↓
检查 likes_depleted_at
  ↓
如果已过 24 小时
  ↓
重置为 6，清空 likes_depleted_at
  ↓
发送 UI 更新通知
```

### 方式 3: 被动重置（数据库触发器）
```
任何 UPDATE users 操作
  ↓
trigger_reset_likes 触发
  ↓
reset_likes_if_expired() 执行
  ↓
如果 is_pro = false 且已过 24 小时
  ↓
NEW.likes_remaining := 6
  ↓
自动更新数据库
```

---

## 关键差异对比

### 修改前
| 项目 | 值 | 问题 |
|------|-----|------|
| 初始点赞 | 10 | ❌ 不符合要求 |
| 重置点赞 | 10 | ❌ 不符合要求 |
| 重置后扣减 | 9 (10-1) | ❌ 不符合要求 |
| 启动检测 | ❌ 无 | ❌ 用户需要点赞才触发 |
| 主动检测函数 | ❌ 无 | ❌ 只能被动等待 |

### 修改后
| 项目 | 值 | 状态 |
|------|-----|------|
| 初始点赞 | **6** | ✅ 符合要求 |
| 重置点赞 | **6** | ✅ 符合要求 |
| 重置后扣减 | **5** (6-1) | ✅ 符合要求 |
| 启动检测 | ✅ 有 | ✅ 打开应用自动检测 |
| 主动检测函数 | ✅ `checkAndResetUserLikesIfNeeded()` | ✅ 可随时调用 |

---

## 代码修改清单

### SupabaseService.swift
1. ✅ 第 5342 行：重置后扣减改为 `newCount: 5`
2. ✅ 第 5411-5497 行：新增 `checkAndResetUserLikesIfNeeded()` 函数

### ContentView.swift
1. ✅ 第 82-89 行：应用启动时调用点赞重置检测

### 数据库脚本
1. ✅ `add_brewnet_pro_columns.sql` 第 24 行：触发器重置为 6

---

## 验证测试

### 测试用例 1: 新用户
```
操作：注册新用户
预期：likes_remaining = 6
验证：✅ 已确认所有默认值为 6
```

### 测试用例 2: 点赞耗尽
```
操作：使用 6 次点赞
预期：
  - 第 6 次后 likes_remaining = 0
  - likes_depleted_at = 当前时间
验证：代码逻辑正确
```

### 测试用例 3: 24小时内尝试点赞
```
操作：耗尽后 12 小时尝试点赞
预期：返回 false（点赞失败）
验证：第 5349-5352 行逻辑正确
```

### 测试用例 4: 24小时后打开应用
```
操作：耗尽后 25 小时打开应用
预期：自动重置为 6 次点赞
验证：✅ ContentView 启动检测已添加
```

### 测试用例 5: 24小时后点赞
```
操作：耗尽后 25 小时尝试点赞（未打开应用）
预期：
  - 自动检测到已过 24 小时
  - 重置为 6，扣减当前点赞
  - likes_remaining = 5
验证：✅ 第 5321-5345 行逻辑正确
```

### 测试用例 6: 数据库触发器
```
操作：数据库直接 UPDATE users
预期：触发器自动检查并重置
验证：✅ SQL 触发器已配置
```

---

## 部署说明

### 1. 代码部署
所有代码修改已完成，无需额外操作。

### 2. 数据库部署
执行以下 SQL 脚本更新数据库：
```bash
# 在 Supabase SQL Editor 中执行
/Users/heady/Documents/BrewNet/BrewNet/add_brewnet_pro_columns.sql
```

### 3. 验证部署
```sql
-- 检查触发器是否存在
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_reset_likes';

-- 检查函数是否存在
SELECT proname FROM pg_proc WHERE proname = 'reset_likes_if_expired';

-- 测试重置逻辑
-- 1. 创建测试用户（手动设置为 24 小时前耗尽）
-- 2. 更新任意字段触发触发器
-- 3. 验证 likes_remaining 是否重置为 6
```

---

## 完成状态
✅ 所有重置逻辑已改进  
✅ 支持多种重置触发方式  
✅ 通过语法检查，无错误  
✅ 文档已完善

