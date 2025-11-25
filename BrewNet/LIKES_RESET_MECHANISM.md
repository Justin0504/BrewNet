# BrewNet 点赞重置机制详解

## 创建日期
2024-11-22

---

## 一、普通用户点赞规则

### 基本规则
- **初始点赞**: 新用户注册时 `likes_remaining = 6`
- **重置周期**: 每 24 小时
- **重置数量**: 重置为 6 次点赞
- **Pro 用户**: 无限点赞（`likes_remaining = 999999`）

---

## 二、点赞生命周期

### 1. 新用户状态
```
is_pro = false
likes_remaining = 6
likes_depleted_at = null
```

### 2. 使用点赞
```
每次点赞: likes_remaining - 1
例如：6 → 5 → 4 → 3 → 2 → 1 → 0
```

### 3. 点赞耗尽
```
likes_remaining = 0
likes_depleted_at = 当前时间（记录耗尽时刻）
```

### 4. 24小时后自动重置
```
当前时间 - likes_depleted_at >= 24小时
↓
likes_remaining = 6（重置）
likes_depleted_at = null（清空）
```

---

## 三、重置机制实现

### 3.1 实时重置（在点赞时检测）

**文件**: `SupabaseService.swift`  
**函数**: `decrementUserLikes(userId:)`  
**位置**: 第 5294-5377 行

**逻辑**:
```swift
func decrementUserLikes(userId: String) async throws -> Bool {
    // 1. 获取用户状态
    let isPro = json["is_pro"] as? Bool ?? false
    let likesRemaining = json["likes_remaining"] as? Int ?? 0
    let likesDepletedStr = json["likes_depleted_at"] as? String
    
    // 2. Pro 用户直接通过（无限点赞）
    if isPro {
        return true
    }
    
    // 3. 检查是否需要重置（已过24小时）
    if let depletedDate = parseDate(likesDepletedStr) {
        let hoursPassed = Date().timeIntervalSince(depletedDate) / 3600
        if hoursPassed >= 24 {
            // 重置为 6，然后扣减当前点赞（6 - 1 = 5）
            update(likes_remaining: 6, likes_depleted_at: nil)
            update(likes_remaining: 5)  // 扣减当前点赞
            return true
        }
    }
    
    // 4. 未过24小时，检查剩余点赞
    if likesRemaining <= 0 {
        return false  // 无剩余点赞
    }
    
    // 5. 扣减点赞
    let newLikesRemaining = likesRemaining - 1
    update(likes_remaining: newLikesRemaining)
    
    // 6. 如果耗尽，记录时间
    if newLikesRemaining == 0 {
        update(likes_depleted_at: 当前时间)
    }
    
    return true
}
```

**特点**:
- ✅ 在每次点赞前检查是否需要重置
- ✅ 自动重置并扣减当前点赞
- ✅ 记录耗尽时间以便下次重置

---

### 3.2 主动检测（应用启动时）

**文件**: `SupabaseService.swift`  
**函数**: `checkAndResetUserLikesIfNeeded(userId:)`  
**位置**: 第 5411-5497 行（新增）

**逻辑**:
```swift
func checkAndResetUserLikesIfNeeded(userId: String) async throws {
    // 1. 获取用户状态
    let isPro = json["is_pro"] as? Bool ?? false
    let likesRemaining = json["likes_remaining"] as? Int ?? 0
    let likesDepletedStr = json["likes_depleted_at"] as? String
    
    // 2. Pro 用户无需重置
    if isPro { return }
    
    // 3. 点赞未耗尽，无需重置
    guard let depletedStr = likesDepletedStr else { return }
    
    // 4. 检查是否已过 24 小时
    let hoursPassed = Date().timeIntervalSince(depletedDate) / 3600
    
    if hoursPassed >= 24 {
        // 5. 重置为 6
        update(likes_remaining: 6, likes_depleted_at: nil)
        print("✅ [Likes] 点赞数已重置: 0 -> 6")
        
        // 6. 发送通知更新 UI
        NotificationCenter.default.post(name: "UserLikesReset", ...)
    }
}
```

**调用位置**: `ContentView.swift` → `checkProfileStatus()`  
**触发时机**: 应用启动并认证成功后

**特点**:
- ✅ 主动检测，不需要用户点赞触发
- ✅ 用户打开应用时自动恢复点赞
- ✅ 发送通知更新 UI

---

### 3.3 数据库触发器（被动重置）

**文件**: `add_brewnet_pro_columns.sql`  
**函数**: `reset_likes_if_expired()`  
**位置**: 第 17-30 行

**逻辑**:
```sql
CREATE OR REPLACE FUNCTION reset_likes_if_expired()
RETURNS TRIGGER AS $$
BEGIN
    -- 在 users 表更新前触发
    IF NEW.is_pro = FALSE AND 
       NEW.likes_depleted_at IS NOT NULL AND 
       (CURRENT_TIMESTAMP - NEW.likes_depleted_at) >= INTERVAL '24 hours' THEN
        NEW.likes_remaining := 6;  -- ✅ 重置为 6
        NEW.likes_depleted_at := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**触发器**:
```sql
CREATE TRIGGER trigger_reset_likes
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION reset_likes_if_expired();
```

**特点**:
- ✅ 任何对 `users` 表的更新都会触发检查
- ✅ 数据库层面保证数据一致性
- ✅ 作为后备保护机制

---

## 四、重置检测优先级

### 触发顺序（多层保护）

```
1. 【最优先】应用启动时主动检测
   ↓
   ContentView.checkProfileStatus()
   → checkAndResetUserLikesIfNeeded()
   
2. 【次优先】用户点赞时实时检测
   ↓
   decrementUserLikes()
   → 自动检查并重置
   
3. 【兜底】数据库触发器被动检测
   ↓
   任何 UPDATE users 操作
   → reset_likes_if_expired() 触发器
```

---

## 五、时间线示例

### 场景：用户耗尽点赞后再次使用

```
Day 1 - 10:00 AM
├─ 用户使用第 6 次点赞
├─ likes_remaining = 0
└─ likes_depleted_at = 2024-11-22T10:00:00Z

Day 1 - 14:00 PM (4小时后)
├─ 用户尝试点赞
├─ 检查：hoursPassed = 4 < 24
└─ ❌ 返回 false（点赞失败）

Day 2 - 10:30 AM (24.5小时后)
├─ 用户打开应用
├─ checkAndResetUserLikesIfNeeded() 自动执行
├─ 检查：hoursPassed = 24.5 >= 24
├─ 重置：likes_remaining = 6
├─ 清空：likes_depleted_at = null
└─ ✅ 用户恢复 6 次点赞

Day 2 - 11:00 AM
├─ 用户点赞
├─ likes_remaining = 5
└─ ✅ 点赞成功
```

---

## 六、核心改进点

### ✅ 已改进
1. **统一点赞次数**: 从 10 改为 6
2. **主动检测**: 应用启动时自动检测并重置
3. **实时检测**: 点赞时自动检测并重置
4. **数据库保护**: 触发器确保数据一致性
5. **UI 通知**: 重置后发送通知更新界面

### 🎯 核心逻辑
```
普通用户（is_pro = false）:
  - 初始: 6 次点赞
  - 耗尽后: 记录耗尽时间
  - 24小时后: 自动重置为 6 次
  - 检测点: 应用启动 + 点赞时 + 数据库更新
```

---

## 七、相关代码位置

| 功能 | 文件 | 函数/位置 | 说明 |
|------|------|----------|------|
| **扣减点赞** | SupabaseService.swift | `decrementUserLikes()` 第 5294 行 | 实时检测并重置 |
| **主动重置** | SupabaseService.swift | `checkAndResetUserLikesIfNeeded()` 第 5411 行 | 应用启动时调用 |
| **启动检测** | ContentView.swift | `checkProfileStatus()` 第 82-88 行 | 启动时触发 |
| **数据库触发器** | add_brewnet_pro_columns.sql | `reset_likes_if_expired()` 第 17 行 | 数据库层保护 |
| **默认值** | add_brewnet_pro_columns.sql | `DEFAULT 6` 第 9 行 | 新用户默认 |

---

## 八、测试清单

### 测试场景
- [ ] 新用户注册后有 6 次点赞
- [ ] 使用 6 次点赞后变为 0
- [ ] 耗尽后立即尝试点赞失败
- [ ] 24 小时后打开应用自动重置为 6
- [ ] 24 小时后点赞自动重置为 6（如果未打开应用）
- [ ] Pro 用户无限点赞（不受 24 小时限制）
- [ ] Pro 过期后恢复为 6 次点赞

---

## 完成状态
✅ 所有逻辑已改进并通过语法检查  
✅ 支持应用启动时主动检测  
✅ 支持点赞时实时检测  
✅ 数据库触发器作为兜底保护

