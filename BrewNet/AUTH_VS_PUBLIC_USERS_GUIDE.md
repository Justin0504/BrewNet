# auth.users vs public.users 完全指南

## Supabase 双表架构说明

---

## 一、两个表的区别

### 1. **auth.users** (Supabase Auth 系统表)

**用途**: Supabase 认证系统管理的表，存储认证相关信息

**字段**:
- `id` - 用户 UUID (主键)
- `email` - 邮箱地址（用于登录）
- `encrypted_password` - 加密后的密码
- `email_confirmed_at` - 邮箱确认时间
- `phone` - 手机号（可选）
- `raw_user_meta_data` - 用户元数据（JSON）
- `created_at` - 创建时间
- `updated_at` - 更新时间

**特点**:
- ✅ 由 Supabase Auth 服务自动管理
- ✅ 使用 `auth.signUp()` 自动插入
- ✅ 用于身份验证和授权
- ❌ 不应该直接插入或修改（通过 Auth API）
- ❌ 字段固定，不能自定义业务字段

**访问方式**:
```swift
// 注册
let response = try await client.auth.signUp(
    email: email,
    password: password,
    data: ["name": .string(name)]  // 保存到 raw_user_meta_data
)

// 登录
let response = try await client.auth.signIn(
    email: email,
    password: password
)
```

---

### 2. **public.users** (应用自定义业务表)

**用途**: 存储应用业务相关的用户信息

**字段** (自定义):
- `id` - 用户 UUID (外键引用 auth.users(id))
- `email` - 邮箱（冗余存储，便于查询）
- `name` - 用户姓名
- `phone_number` - 手机号
- `is_guest` - 是否游客
- `profile_image` - 头像 URL
- `bio` - 个人简介
- `company`, `job_title`, `location` - 职业信息
- `is_pro` - Pro 订阅状态
- `pro_start`, `pro_end` - Pro 订阅时间
- `likes_remaining` - 剩余点赞次数
- `created_at`, `updated_at` - 时间戳

**特点**:
- ✅ 完全自定义字段
- ✅ 可以直接插入、更新、删除
- ✅ 用于存储业务数据
- ✅ 可以关联其他业务表

**访问方式**:
```swift
// 插入
let response = try await client
    .from("users")
    .insert(user)
    .execute()

// 查询
let response = try await client
    .from("users")
    .select()
    .eq("id", value: userId)
    .execute()
```

---

## 二、注册流程分析

### 当前的注册流程（存在问题）

```
步骤 1: auth.signUp()
  ↓
插入到 auth.users 表 ✅
  ↓
触发器自动触发: on_auth_user_created_create_credibility
  ↓
执行函数: create_credibility_score_for_new_user()
  ↓
插入到 credibility_scores 表 ❌ 可能失败
  ↓
**如果触发器失败 → "Database error saving new user"**
  ↓
步骤 2: service.createUser(user)
  ↓
插入到 public.users 表
  ↓
✅ 完成注册
```

---

## 三、问题诊断

### 触发器失败的可能原因

从截图可以看到，`auth.users` 表上有一个触发器：

```
触发器名称: on_auth_user_created_create_credibility
事件: AFTER INSERT
表: auth.users (在 auth schema 中)
函数: create_credibility_score_for_new_user()
```

**该触发器的作用**:
```sql
CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO credibility_scores (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**可能失败的原因**:

#### 原因 1: `credibility_scores` 表不存在 ⚠️⚠️⚠️

**检查方法**:
```sql
-- 在 Supabase SQL Editor 中执行
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = 'credibility_scores'
);
```

**修复**:
```sql
-- 执行整个脚本创建表
-- 文件: create_credibility_system_tables.sql
```

#### 原因 2: RLS 策略阻止触发器插入 ⚠️⚠️

触发器使用 `SECURITY DEFINER`，应该绕过 RLS，但如果 RLS 配置不当仍可能失败。

**检查方法**:
```sql
-- 检查 credibility_scores 表的 RLS 策略
SELECT * FROM pg_policies WHERE tablename = 'credibility_scores';
```

**修复**:
```sql
-- 确保触发器函数有足够权限
ALTER FUNCTION create_credibility_score_for_new_user() SECURITY DEFINER;

-- 或者临时禁用 RLS（不推荐）
ALTER TABLE credibility_scores DISABLE ROW LEVEL SECURITY;
```

#### 原因 3: 外键约束问题 ⚠️

`credibility_scores.user_id` 引用 `auth.users(id)`，如果引用有问题可能失败。

**检查方法**:
```sql
-- 检查外键约束
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE contype = 'f' AND conrelid = 'credibility_scores'::regclass;
```

---

## 四、解决方案

### 方案 1: 临时禁用触发器（推荐） ✅

这是最快的解决方案，可以让注册功能立即恢复。

```sql
-- 在 Supabase SQL Editor 中执行

-- 禁用触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 注意：禁用后，新用户不会自动创建 credibility_scores 记录
-- 可以在应用代码中手动创建，或稍后批量创建
```

**优点**: 
- ✅ 立即解决注册失败问题
- ✅ 不影响其他功能

**缺点**:
- ❌ 新用户不会自动有信誉评分记录
- ❌ 需要在代码中或稍后补充

---

### 方案 2: 修复触发器（完整解决）

**步骤 1**: 检查 `credibility_scores` 表是否存在

```sql
-- 如果表不存在，执行完整脚本
-- 文件: /Users/heady/Documents/BrewNet/BrewNet/create_credibility_system_tables.sql
```

**步骤 2**: 修复 RLS 策略

```sql
-- 确保触发器可以插入
ALTER TABLE credibility_scores ENABLE ROW LEVEL SECURITY;

-- 添加服务角色插入策略
DROP POLICY IF EXISTS "Service role can insert credibility scores" ON credibility_scores;
CREATE POLICY "Service role can insert credibility scores"
ON credibility_scores FOR INSERT
TO service_role
WITH CHECK (true);
```

**步骤 3**: 重新创建触发器

```sql
-- 删除旧触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 重新创建函数（带错误处理）
CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    BEGIN
        INSERT INTO credibility_scores (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        -- 记录错误但不阻止用户创建
        RAISE WARNING 'Failed to create credibility score for user %: %', NEW.id, SQLERRM;
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 重新创建触发器
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();
```

---

### 方案 3: 延迟创建信誉评分

不在注册时创建，而是在用户首次需要时创建。

**修改触发器**:
```sql
-- 完全删除触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
```

**在应用代码中创建**:
```swift
// 在 SupabaseService 中添加函数
func ensureCredibilityScoreExists(userId: String) async throws {
    // 检查是否已存在
    let existing = try await getCredibilityScore(userId: userId)
    
    if existing == nil {
        // 创建默认信誉评分
        try await client
            .from("credibility_scores")
            .insert(["user_id": userId])
            .execute()
    }
}

// 在获取信誉评分时调用
func getCredibilityScore(userId: String) async throws -> CredibilityScore? {
    // 首先确保记录存在
    try? await ensureCredibilityScoreExists(userId: userId)
    
    // 然后查询
    // ...
}
```

---

## 五、标准做法对比

### Supabase 推荐架构

```
auth.users (Auth 表)
  ├─ id (UUID)
  ├─ email
  ├─ encrypted_password
  └─ raw_user_meta_data (JSON)

    ↓ (触发器自动同步)

public.users (业务表)
  ├─ id (UUID) REFERENCES auth.users(id)
  ├─ email (冗余)
  ├─ name
  ├─ ... (所有业务字段)
  
    ↓ (业务关联)
    
其他业务表
  ├─ profiles (REFERENCES public.users)
  ├─ credibility_scores (REFERENCES auth.users)
  └─ ...
```

### BrewNet 当前架构问题

**问题**: 
- `public.users` 表通过应用代码手动创建（`service.createUser()`）
- `credibility_scores` 表通过触发器自动创建
- 如果触发器失败，`auth.signUp()` 就会失败

**建议改进**:
1. 所有自动创建都通过触发器（一致性）
2. 或者所有创建都通过应用代码（可控性）
3. 触发器只做非关键操作，失败不应阻止注册

---

## 六、立即修复方案

### 快速修复 SQL（推荐执行）

```sql
-- =============================================
-- 快速修复：删除可能导致注册失败的触发器
-- =============================================

-- 1. 临时禁用 credibility_scores 触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 2. 验证触发器已删除
SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'users' OR event_object_schema = 'auth';

-- 3. 测试注册
-- 现在应该可以正常注册了

-- =============================================
-- 后续：手动为现有用户创建信誉评分
-- =============================================

-- 为所有 public.users 中的用户创建信誉评分（如果不存在）
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 验证
SELECT COUNT(*) FROM credibility_scores;
```

---

## 七、注册流程对比

### ❌ 当前流程（有问题）

```
用户点击注册
  ↓
auth.signUp() 开始
  ↓
插入到 auth.users ✅
  ↓
触发器: on_auth_user_created_create_credibility
  ↓
插入到 credibility_scores ❌ 失败！
  ↓
auth.signUp() 回滚并失败
  ↓
显示错误: "Database error saving new user"
  ↓
❌ 注册失败
```

### ✅ 修复后流程

```
用户点击注册
  ↓
auth.signUp() 开始
  ↓
插入到 auth.users ✅
  ↓
（触发器已禁用，不执行）
  ↓
auth.signUp() 成功
  ↓
service.createUser() 执行
  ↓
插入到 public.users ✅
  ↓
✅ 注册成功
```

---

## 八、什么时候用哪个表？

### 使用 auth.users 的场景

1. **认证操作** (通过 Supabase Auth API)
   - 注册: `auth.signUp()`
   - 登录: `auth.signIn()`
   - 登出: `auth.signOut()`
   - 密码重置: `auth.resetPasswordForEmail()`

2. **授权检查**
   - RLS 策略: `auth.uid()` 获取当前用户 ID
   - 外键引用: 某些表直接引用 `auth.users(id)`

3. **认证状态查询**
   - 获取当前登录用户: `auth.getUser()`

### 使用 public.users 的场景

1. **业务数据操作** (通过 Supabase Database API)
   - 创建用户记录: `from("users").insert()`
   - 更新用户信息: `from("users").update()`
   - 查询用户列表: `from("users").select()`

2. **业务逻辑**
   - 用户资料展示
   - Pro 订阅管理
   - Likes 计数管理
   - 用户关系（matches, invitations）

---

## 九、BrewNet 的正确使用方式

### 注册时

```swift
// 步骤 1: 创建认证用户（auth.users）
let authResponse = try await client.auth.signUp(
    email: email,
    password: password,
    data: ["name": .string(name)]
)

// 步骤 2: 创建业务用户（public.users）
let supabaseUser = SupabaseUser(
    id: authResponse.user.id.uuidString,
    email: email,
    name: name,
    // ... 其他业务字段
)

let createdUser = try await service.createUser(user: supabaseUser)
```

### 登录时

```swift
// 步骤 1: 认证（auth.users）
let authResponse = try await client.auth.signIn(
    email: email,
    password: password
)

// 步骤 2: 获取业务数据（public.users）
let user = try await service.getUser(id: authResponse.user.id.uuidString)
```

### 业务操作时

```swift
// 总是使用 public.users
let user = try await service.getUser(id: userId)  // ✅
let profiles = try await service.getRecommendedProfiles()  // ✅
try await service.updateUserToPro()  // ✅
```

---

## 十、立即执行的修复 SQL

```sql
-- =============================================
-- 紧急修复：禁用导致注册失败的触发器
-- =============================================

-- 查看当前触发器
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth';

-- 禁用 credibility 触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 验证触发器已删除
SELECT 
    trigger_name
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';
-- 应该返回空结果

-- =============================================
-- 验证注册功能
-- =============================================

-- 尝试在应用中注册新用户
-- 应该成功！

-- =============================================
-- 后续：为现有用户补充信誉评分
-- =============================================

-- 创建 credibility_scores 表（如果不存在）
-- 执行 create_credibility_system_tables.sql

-- 为所有用户创建信誉评分
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 验证所有用户都有信誉评分
SELECT 
    'Total auth users' as metric,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'Users with credibility scores',
    COUNT(*)
FROM credibility_scores;
```

---

## 十一、总结

### 关键概念

| 表 | 用途 | 操作方式 | 何时使用 |
|---|------|---------|---------|
| **auth.users** | 认证信息 | Auth API (`auth.signUp`, `auth.signIn`) | 登录、注册、认证 |
| **public.users** | 业务数据 | Database API (`from("users").insert()`) | 用户信息、Pro 状态、业务逻辑 |

### 当前问题

- ✅ **正确**: 使用 `auth.signUp()` 创建认证用户
- ✅ **正确**: 使用 `service.createUser()` 创建业务用户
- ❌ **问题**: `auth.users` 上的触发器失败导致注册失败

### 解决方案

1. **立即**: 禁用 `on_auth_user_created_create_credibility` 触发器
2. **验证**: 测试注册功能
3. **后续**: 手动或通过应用代码创建信誉评分记录

---

## 执行顺序

1. 复制上面的"立即执行的修复 SQL"
2. 在 Supabase Dashboard → SQL Editor 中执行
3. 重新测试注册功能
4. 注册应该成功！

问题的根本原因是 **auth.users 的触发器失败**，而不是使用了错误的表。

