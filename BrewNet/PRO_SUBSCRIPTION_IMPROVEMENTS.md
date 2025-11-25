# BrewNet Pro 订阅逻辑改进总结

## 改进日期
2024-11-22

## 改进目标
1. 将非 Pro 用户的默认点赞次数从 10 改为 6
2. 完善 Pro 过期自动检测机制
3. 确保所有相关代码和数据库逻辑一致

---

## 一、新用户默认值

### 修改前
- `is_pro = false`
- `likes_remaining = 10`

### 修改后
- `is_pro = false`
- `likes_remaining = 6` ✅

### 涉及文件
1. **SupabaseService.swift**
   - 过期恢复：第 5274 行
   - 24小时重置：第 5334 行

2. **AuthManager.swift**
   - 默认参数：第 19 行
   - Guest 用户：第 264 行
   - 注册用户：第 435, 513, 601 行

3. **SupabaseModels.swift**
   - 默认参数：第 75 行
   - 解码默认值：第 124 行

4. **数据库脚本**
   - `add_brewnet_pro_columns.sql`：第 9, 24, 65 行
   - `quick_fix_pro.sql`：第 9 行

---

## 二、Pro 订阅激活逻辑

### 用户点击付费后的状态变化

**文件**: `SupabaseService.swift`  
**函数**: `upgradeUserToPro(userId:durationSeconds:)`  
**位置**: 第 5053-5118 行

```swift
// 更新用户为 Pro 状态
let update = ProUpdate(
    is_pro: true,                               // ✅ 设置为 true
    pro_start: formatter.string(from: proStart), // 当前时间
    pro_end: formatter.string(from: proEnd),     // 当前时间 + 订阅天数
    likes_remaining: 999999                      // 无限点赞
)
```

### 订阅示例

**订阅一周会员**:
- `pro_start` = 当前时间 (例如：2024-11-22T10:00:00Z)
- `pro_end` = 当前时间 + 7天 (2024-11-29T10:00:00Z)
- `is_pro` = true
- `likes_remaining` = 999999 (无限)

**状态判定**:
- 在 `pro_start` 和 `pro_end` 之间：`is_pro = true`
- 当前时间 > `pro_end`：自动检测后 `is_pro = false`

---

## 三、Pro 过期检测机制

### 3.1 手动检测函数

**文件**: `SupabaseService.swift`  
**函数**: `checkAndUpdateProExpiration(userId:)`  
**位置**: 第 5226-5290 行

**逻辑**:
```swift
// 1. 获取用户的 is_pro 和 pro_end
let isPro = json["is_pro"] as? Bool ?? false
let proEnd = parseProEndDate(proEndStr)

// 2. 如果 is_pro = true 且 pro_end < 当前时间
if proEnd < Date() {
    // 3. 更新为过期状态
    let update = ProExpireUpdate(
        is_pro: false,         // ❌ 设置为 false
        likes_remaining: 6     // ✅ 恢复为 6 次点赞（已修改）
    )
    
    // 4. 执行更新
    try await client
        .from("users")
        .update(update)
        .eq("id", value: userId)
        .execute()
}
```

### 3.2 自动检测机制

#### (1) 应用启动时自动检测 ✅

**文件**: `ContentView.swift`  
**位置**: 第 66-97 行

```swift
private func checkProfileStatus(for user: AppUser) {
    Task {
        // ✅ 新增：在应用启动时自动检测 Pro 过期
        do {
            let proExpired = try await supabaseService.checkAndUpdateProExpiration(userId: user.id)
            if proExpired {
                print("⚠️ [App启动] 检测到 Pro 已过期，已自动更新为 is_pro=false, likes_remaining=6")
                await authManager.refreshUser()
            }
        } catch {
            print("❌ [App启动] Pro 过期检测失败: \(error.localizedDescription)")
        }
        
        // 继续其他检查...
    }
}
```

**触发时机**: 每次应用启动并完成认证后

#### (2) 用户刷新时自动检测 ✅

**文件**: `AuthManager.swift`  
**函数**: `refreshUser()`  
**位置**: 第 915-941 行

```swift
func refreshUser() async {
    // ✅ 已有：在刷新用户时自动检测 Pro 过期
    if let supabaseService = supabaseService {
        do {
            let proExpired = try await supabaseService.checkAndUpdateProExpiration(userId: user.id)
            if proExpired {
                print("⚠️ [Auth] 检测到 Pro 已过期，已更新 Supabase 状态")
            }
        } catch {
            print("❌ [Auth] 检查 Pro 过期失败: \(error.localizedDescription)")
        }
    }
    
    // 刷新用户数据
    if let updatedUser = try await supabaseService?.getUser(id: user.id) {
        await MainActor.run {
            saveUser(updatedUser.toAppUser())
        }
    }
}
```

**触发时机**: 
- 用户完成付费后
- 用户主动刷新
- 其他需要刷新用户状态的场景

#### (3) 数据库批量过期检测（可选）

**文件**: `add_brewnet_pro_columns.sql`  
**函数**: `check_pro_expiration()`  
**位置**: 第 39-50 行

```sql
CREATE OR REPLACE FUNCTION check_pro_expiration()
RETURNS void AS $$
BEGIN
    UPDATE users
    SET is_pro = FALSE,
        likes_remaining = 6  -- ✅ 已修改为 6
    WHERE is_pro = TRUE 
    AND pro_end IS NOT NULL 
    AND pro_end < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
```

**定时执行**（可选，需要 pg_cron 扩展）:
```sql
-- 每小时执行一次批量过期检测
SELECT cron.schedule('check-pro-expiration', '0 * * * *', 'SELECT check_pro_expiration();');
```

---

## 四、完整的 Pro 订阅生命周期

### 1. 新用户注册
```
is_pro = false
pro_start = null
pro_end = null
likes_remaining = 6
```

### 2. 订阅 Pro（例如：一周会员）
```
is_pro = true
pro_start = 2024-11-22T10:00:00Z
pro_end = 2024-11-29T10:00:00Z
likes_remaining = 999999（无限）
```

### 3. Pro 未过期期间
```
当前时间 <= pro_end
is_pro = true
likes_remaining = 999999（无限点赞）
```

### 4. Pro 过期后（自动检测）
```
当前时间 > pro_end
is_pro = false  ✅ 自动设置
likes_remaining = 6  ✅ 自动恢复
```

### 5. 普通用户点赞耗尽
```
likes_remaining = 0
likes_depleted_at = 当前时间
```

### 6. 24小时后自动重置
```
当前时间 - likes_depleted_at >= 24小时
likes_remaining = 6  ✅ 自动重置
likes_depleted_at = null
```

---

## 五、Pro 过期检测触发点

| 检测点 | 触发方式 | 频率 | 文件 | 函数 |
|--------|---------|------|------|------|
| **应用启动** | 用户认证成功后 | 每次启动 | `ContentView.swift` | `checkProfileStatus()` |
| **用户刷新** | 手动或自动刷新 | 按需 | `AuthManager.swift` | `refreshUser()` |
| **付费完成** | 订阅后刷新 | 单次 | `SubscriptionPaymentView.swift` | `onSubscriptionComplete` |
| **批量检测** | 定时任务（可选） | 每小时 | SQL | `check_pro_expiration()` |

---

## 六、验证清单

### 代码验证
- [x] SupabaseService.swift - 所有 `likes_remaining` 默认值改为 6
- [x] AuthManager.swift - 所有 `likesRemaining` 默认值改为 6
- [x] SupabaseModels.swift - 所有 `likesRemaining` 默认值改为 6
- [x] ContentView.swift - 应用启动时自动检测 Pro 过期
- [x] AuthManager.refreshUser() - 刷新时自动检测 Pro 过期
- [x] 所有文件通过语法检查

### 数据库验证
- [x] add_brewnet_pro_columns.sql - DEFAULT 6
- [x] add_brewnet_pro_columns.sql - 触发器重置为 6
- [x] add_brewnet_pro_columns.sql - check_pro_expiration() 设置为 6
- [x] quick_fix_pro.sql - DEFAULT 6

### 功能验证
- [ ] 新用户注册后 likes_remaining = 6
- [ ] 订阅 Pro 后 likes_remaining = 999999
- [ ] Pro 过期后自动变为 likes_remaining = 6
- [ ] 应用启动时检测并更新过期 Pro
- [ ] 用户刷新时检测并更新过期 Pro

---

## 七、数据库部署

### 执行顺序
1. 执行 `add_brewnet_pro_columns.sql` 更新数据库架构
2. （可选）配置 pg_cron 定时任务

### SQL 脚本位置
- `/Users/heady/Documents/BrewNet/BrewNet/add_brewnet_pro_columns.sql`
- `/Users/heady/Documents/BrewNet/BrewNet/quick_fix_pro.sql`

---

## 八、关键改进点

### ✅ 已完成
1. **统一点赞次数**: 所有非 Pro 用户默认 6 次点赞（之前是 10）
2. **过期恢复逻辑**: Pro 过期后自动恢复为 6 次点赞（之前是 10）
3. **24小时重置**: 点赞耗尽后 24 小时重置为 6 次（之前是 10）
4. **应用启动检测**: 每次启动时自动检测并更新过期的 Pro 订阅
5. **用户刷新检测**: 刷新用户数据时自动检测并更新过期的 Pro 订阅
6. **数据库批量检测**: 支持通过 SQL 函数批量更新过期 Pro 用户

### 🎯 核心逻辑
```
当前时间 > pro_end 时：
  ↓
自动检测并执行：
  - is_pro = false
  - likes_remaining = 6
```

---

## 九、测试建议

### 测试场景
1. **新用户注册**
   - 验证：`likes_remaining = 6`

2. **订阅一周 Pro**
   - 验证：`is_pro = true`, `likes_remaining = 999999`
   - 验证：`pro_end = 当前时间 + 7天`

3. **Pro 过期检测**
   - 设置：`pro_end` 为过去时间
   - 重启应用
   - 验证：`is_pro = false`, `likes_remaining = 6`

4. **点赞耗尽重置**
   - 使用：6 次点赞全部用完
   - 等待：24 小时
   - 验证：`likes_remaining = 6`

---

## 十、相关文档
- `BREWNET_PRO_COMPLETE.md` - Pro 功能完整文档
- `add_brewnet_pro_columns.sql` - 数据库架构脚本
- `PROBADGE_DISPLAY_ISSUE.md` - Pro Badge 显示逻辑

---

## 完成状态
✅ 所有修改已完成并通过语法检查  
✅ Pro 过期检测机制已改进  
✅ 默认点赞次数已统一改为 6

