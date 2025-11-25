# 修复 first_like_today 字段不更新的问题

## 🔍 问题诊断

用户点赞/右滑后，数据库中 `users` 表的 `first_like_today` 字段没有更新。

## 📋 可能的原因

1. **数据库字段未创建** - SQL 脚本还没有在 Supabase 中运行
2. **RLS 策略阻止** - Row Level Security 策略不允许更新该字段
3. **权限问题** - 用户没有更新该字段的权限
4. **网络/连接问题** - 更新请求失败但未正确报错
5. **数据格式问题** - 日期格式不匹配

## 🛠️ 修复步骤

### 步骤 1: 确认数据库字段是否存在

在 Supabase SQL Editor 中运行：

```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'first_like_today';
```

**预期结果**: 应该返回一行数据
```
column_name       | data_type | is_nullable
first_like_today  | date      | YES
```

**如果没有返回任何数据**: 运行 `add_first_like_today_column.sql` 脚本

### 步骤 2: 检查 RLS 策略

```sql
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users'
AND cmd IN ('UPDATE', 'ALL')
ORDER BY policyname;
```

**检查是否有策略允许用户更新自己的数据**

如果没有合适的 UPDATE 策略，创建一个：

```sql
-- 允许用户更新自己的数据
CREATE POLICY "Users can update own data"
ON users FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
```

### 步骤 3: 手动测试更新

用你自己的用户 ID 替换 `YOUR_USER_ID`：

```sql
-- 测试更新
UPDATE users 
SET first_like_today = CURRENT_DATE 
WHERE id = 'YOUR_USER_ID';

-- 验证更新
SELECT id, name, first_like_today 
FROM users 
WHERE id = 'YOUR_USER_ID';
```

**如果更新成功**: 问题在于应用代码或调用逻辑
**如果更新失败**: 问题在于数据库权限或 RLS

### 步骤 4: 查看应用日志

在 Xcode 中查看控制台日志，搜索 `[First Like]` 关键词。

**预期看到的日志**:
```
🔍 [First Like] Checking if user XXX has liked today
✅ [First Like] No previous like recorded, this is first like today
🔄 [First Like] Starting update for user XXX
📅 [First Like] Today's date: 2024-01-15
✅ [First Like] Update response received
📊 [First Like] Response status: 200
✅ [First Like] Verified: first_like_today = 2024-01-15
✅ [First Like] Updated first_like_today to 2024-01-15 for user XXX
```

**如果看到错误日志**: 检查具体的错误信息

### 步骤 5: 常见问题修复

#### 问题 A: RLS 策略太严格

**症状**: 日志显示 "Update failed" 或 403/401 错误

**解决方案**: 
```sql
-- 临时禁用 RLS 进行测试（仅用于诊断，不要在生产环境保持禁用）
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- 或者修改策略允许更新 first_like_today
ALTER POLICY "existing_policy_name" ON users
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 测试后重新启用 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

#### 问题 B: 字段默认值问题

**症状**: 字段存在但始终为 NULL

**解决方案**:
```sql
-- 确保字段可以接受 NULL 和 DATE 值
ALTER TABLE users 
ALTER COLUMN first_like_today TYPE DATE,
ALTER COLUMN first_like_today SET DEFAULT NULL;
```

#### 问题 C: 时区问题

**症状**: 日期格式不匹配或解析失败

**解决方案**: 已在代码中使用统一的日期格式 `yyyy-MM-dd`

#### 问题 D: 网络超时

**症状**: 更新请求没有返回

**解决方案**: 
- 检查网络连接
- 增加超时时间
- 检查 Supabase 服务状态

## 🧪 完整测试脚本

在 Supabase SQL Editor 中运行此脚本进行完整测试：

```sql
-- 1. 检查字段
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name = 'first_like_today';

-- 2. 检查策略
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'users'
AND cmd IN ('UPDATE', 'ALL');

-- 3. 找一个测试用户
SELECT id, name, first_like_today 
FROM users 
ORDER BY created_at DESC 
LIMIT 1;

-- 4. 手动更新测试（用上面查到的 ID）
UPDATE users 
SET first_like_today = CURRENT_DATE 
WHERE id = (SELECT id FROM users ORDER BY created_at DESC LIMIT 1)
RETURNING id, name, first_like_today;

-- 5. 验证更新
SELECT id, name, first_like_today, updated_at
FROM users 
WHERE first_like_today IS NOT NULL
ORDER BY updated_at DESC
LIMIT 5;
```

## 📝 调试清单

- [ ] SQL 脚本已在 Supabase 中运行
- [ ] `first_like_today` 字段存在于 `users` 表
- [ ] RLS 策略允许用户更新自己的数据
- [ ] 手动 SQL UPDATE 测试成功
- [ ] 应用日志显示更新请求已发送
- [ ] 应用日志显示更新成功（状态码 200）
- [ ] 应用日志显示验证查询返回了更新后的日期
- [ ] 在 Supabase 数据库中手动查询能看到更新的数据

## 🚨 紧急修复

如果以上都无效，使用这个简化版本（绕过 Supabase 客户端）：

在 `SupabaseService.swift` 中添加备用方法：

```swift
func updateFirstLikeTodayDirect(userId: String) async throws {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayStr = dateFormatter.string(from: Date())
    
    // Direct SQL execution
    let sql = """
    UPDATE users 
    SET first_like_today = '\(todayStr)'
    WHERE id = '\(userId)'
    """
    
    let response = try await client.rpc("exec_sql", params: ["query": sql]).execute()
    print("✅ Direct SQL update completed")
}
```

## 📞 需要更多帮助？

如果以上步骤都无法解决问题，请提供：
1. Xcode 控制台的完整 `[First Like]` 日志
2. Supabase SQL 测试的结果截图
3. RLS 策略的输出
4. 用户表的结构信息

