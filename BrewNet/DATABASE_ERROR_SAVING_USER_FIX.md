# "Database error saving new user" 错误排查与修复

## 错误信息
```
错误类型: AuthError
错误信息: Database error saving new user
NSError 代码: 1
NSError 域: Auth.AuthError
```

---

## 问题分析

这个错误发生在 Supabase 的 `auth.signUp()` 调用时，表示 Supabase Auth 在尝试保存新用户到数据库时失败。

### 可能的原因

1. **数据库触发器失败** ⚠️⚠️⚠️
   - Supabase 可能在 `auth.users` 表上有触发器，在插入新用户时自动创建 `users` 表的记录
   - 如果触发器中的 SQL 有错误或表结构不匹配，会导致失败

2. **RLS (Row Level Security) 策略阻止** ⚠️⚠️
   - `users` 表的 RLS 策略可能阻止新用户插入
   - 需要检查 INSERT 策略

3. **表结构不匹配** ⚠️⚠️
   - `users` 表可能有 NOT NULL 约束的字段，但触发器没有提供值
   - 字段类型不匹配

4. **数据库连接问题** ⚠️
   - Supabase 服务暂时不可用
   - 网络连接问题

---

## 排查步骤

### 步骤 1: 检查 Supabase Dashboard

#### 1.1 检查数据库触发器

1. 登录 Supabase Dashboard
2. 进入 `Database` → `Triggers`
3. 查找与 `auth.users` 表相关的触发器
4. 检查触发器是否在 `INSERT` 时触发

**常见触发器名称**:
- `on_auth_user_created`
- `handle_new_user`
- `create_user_profile`

**检查触发器 SQL**:
```sql
-- 在 Supabase SQL Editor 中执行
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
   OR event_object_schema = 'auth';
```

#### 1.2 检查 users 表结构

1. 进入 `Table Editor` → `users`
2. 查看所有列及其约束：
   - NOT NULL 约束
   - DEFAULT 值
   - 数据类型

**必需字段检查清单**:
- [ ] `id` (UUID, PRIMARY KEY)
- [ ] `email` (TEXT, NOT NULL)
- [ ] `name` (TEXT, NOT NULL)
- [ ] `is_guest` (BOOLEAN, DEFAULT false)
- [ ] `profile_setup_completed` (BOOLEAN, DEFAULT false)
- [ ] `created_at` (TIMESTAMP, DEFAULT NOW())
- [ ] `last_login_at` (TIMESTAMP, DEFAULT NOW())
- [ ] `updated_at` (TIMESTAMP, DEFAULT NOW())
- [ ] `is_pro` (BOOLEAN, DEFAULT false)
- [ ] `likes_remaining` (INTEGER, DEFAULT 6)

#### 1.3 检查 RLS 策略

1. 进入 `Authentication` → `Policies`
2. 选择 `users` 表
3. 检查 INSERT 策略

**应该有的策略**:
```sql
-- 允许认证用户插入自己的记录
CREATE POLICY "Users can insert their own record"
ON users FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);

-- 或者允许服务角色插入（用于触发器）
CREATE POLICY "Service role can insert users"
ON users FOR INSERT
TO service_role
WITH CHECK (true);
```

---

### 步骤 2: 检查数据库触发器/函数

如果 Supabase 有自动创建 `users` 表记录的触发器，检查触发器函数：

```sql
-- 查找触发器函数
SELECT 
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_trigger t ON t.tgfoid = p.oid
WHERE t.tgname LIKE '%user%' 
   OR t.tgrelid = 'auth.users'::regclass;
```

**常见问题**:
- 触发器函数引用了不存在的列
- 触发器函数中的 SQL 语法错误
- 触发器函数没有处理 NULL 值

---

### 步骤 3: 测试手动插入

在 Supabase SQL Editor 中测试手动插入用户：

```sql
-- 测试插入（使用实际值替换）
INSERT INTO users (
    id,
    email,
    name,
    is_guest,
    profile_setup_completed,
    created_at,
    last_login_at,
    updated_at,
    is_pro,
    likes_remaining
) VALUES (
    gen_random_uuid(),
    'test@example.com',
    'Test User',
    false,
    false,
    NOW(),
    NOW(),
    NOW(),
    false,
    6
);
```

**如果插入失败**:
- 查看错误消息
- 检查哪个字段有问题
- 修复表结构或触发器

---

### 步骤 4: 检查 Postgres 日志

1. 进入 Supabase Dashboard
2. 进入 `Logs` → `Postgres Logs`
3. 查看最近的错误信息
4. 查找与用户创建相关的错误

---

## 解决方案

### 方案 1: 修复数据库触发器

如果 Supabase 有自动创建用户的触发器，确保触发器函数正确：

```sql
-- 示例：创建或替换触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (
        id,
        email,
        name,
        is_guest,
        profile_setup_completed,
        created_at,
        last_login_at,
        updated_at,
        is_pro,
        likes_remaining
    ) VALUES (
        NEW.id::text,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        false,
        false,
        NOW(),
        NOW(),
        NOW(),
        false,
        6
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
```

### 方案 2: 修复 RLS 策略

确保 RLS 策略允许插入：

```sql
-- 删除现有策略（如果需要）
DROP POLICY IF EXISTS "Users can insert their own record" ON users;

-- 创建新策略
CREATE POLICY "Users can insert their own record"
ON users FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id);

-- 或者允许服务角色插入（用于触发器）
CREATE POLICY "Service role can insert users"
ON users FOR INSERT
TO service_role
WITH CHECK (true);
```

### 方案 3: 禁用自动触发器，使用手动创建

如果触发器有问题，可以禁用触发器，改为在应用代码中手动创建：

1. **禁用触发器**:
```sql
ALTER TABLE auth.users DISABLE TRIGGER ALL;
-- 或者删除特定触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
```

2. **确保应用代码正确**:
   - `AuthManager.supabaseRegister()` 在 `signUp` 成功后调用 `createUser()`
   - 这已经在代码中实现了

### 方案 4: 检查表结构

确保 `users` 表有所有必需字段和正确的默认值：

```sql
-- 检查表结构
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 如果缺少字段，添加它们
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_pro BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS likes_remaining INTEGER DEFAULT 6;
```

---

## 快速修复检查清单

- [ ] 检查 Supabase Dashboard 中的数据库触发器
- [ ] 检查 `users` 表结构（所有必需字段）
- [ ] 检查 RLS 策略（允许 INSERT）
- [ ] 查看 Postgres 日志中的详细错误
- [ ] 测试手动插入用户记录
- [ ] 验证触发器函数没有错误
- [ ] 检查网络连接和 Supabase 服务状态

---

## 临时解决方案

如果问题持续存在，可以尝试：

1. **使用不同的邮箱地址注册**（排除邮箱相关问题）
2. **检查 Supabase 服务状态**（https://status.supabase.com）
3. **等待几分钟后重试**（可能是临时服务问题）
4. **联系 Supabase 支持**（如果是平台问题）

---

## 相关文件

- `AuthManager.swift` - 注册逻辑
- `SupabaseService.swift` - 数据库操作
- `add_brewnet_pro_columns.sql` - 数据库表结构

---

## 下一步

1. **立即检查**: Supabase Dashboard 中的触发器和 RLS 策略
2. **查看日志**: Postgres Logs 中的详细错误信息
3. **测试插入**: 在 SQL Editor 中测试手动插入
4. **修复问题**: 根据具体错误修复触发器或策略
5. **重新测试**: 尝试注册新用户

