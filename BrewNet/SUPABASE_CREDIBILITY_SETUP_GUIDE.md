# Supabase 信誉评分系统配置指南

## 配置目标

确保新用户注册时自动创建 `credibility_scores` 记录，有两种方式：
1. **数据库触发器自动创建**（推荐）
2. **应用代码手动创建**（备用，已实现）

---

## 方案 1: 数据库触发器自动创建（推荐）✅

### 步骤 1: 执行完整的信誉系统 SQL 脚本

在 Supabase Dashboard → SQL Editor 中执行：

**文件**: `/Users/heady/Documents/BrewNet/BrewNet/create_credibility_system_tables.sql`

或者复制以下 SQL：

```sql
-- =============================================
-- 信誉评分系统完整设置
-- =============================================

-- 1. 创建信誉评分表
CREATE TABLE IF NOT EXISTS credibility_scores (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    overall_score DECIMAL(2,1) DEFAULT 3.0 CHECK (overall_score >= 0.0 AND overall_score <= 5.0),
    average_rating DECIMAL(2,1) DEFAULT 3.0 CHECK (average_rating >= 0.0 AND average_rating <= 5.0),
    fulfillment_rate DECIMAL(5,2) DEFAULT 100.0 CHECK (fulfillment_rate >= 0 AND fulfillment_rate <= 100),
    total_meetings INT DEFAULT 0 CHECK (total_meetings >= 0),
    total_no_shows INT DEFAULT 0 CHECK (total_no_shows >= 0),
    last_meeting_date TIMESTAMP WITH TIME ZONE,
    tier VARCHAR(50) DEFAULT 'Normal',
    is_frozen BOOLEAN DEFAULT FALSE,
    freeze_end_date TIMESTAMP WITH TIME ZONE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    gps_anomaly_count INT DEFAULT 0,
    mutual_high_rating_count INT DEFAULT 0,
    last_decay_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. 创建索引
CREATE INDEX IF NOT EXISTS idx_credibility_tier ON credibility_scores(tier);
CREATE INDEX IF NOT EXISTS idx_credibility_score ON credibility_scores(overall_score DESC);

-- 3. 启用 RLS
ALTER TABLE credibility_scores ENABLE ROW LEVEL SECURITY;

-- 4. 创建 RLS 策略
-- 所有人可以查看信誉评分（公开信息）
DROP POLICY IF EXISTS "任何人可以查看信誉评分" ON credibility_scores;
CREATE POLICY "任何人可以查看信誉评分"
ON credibility_scores FOR SELECT
TO authenticated
USING (true);

-- 服务角色可以插入（用于触发器）
DROP POLICY IF EXISTS "Service role can insert credibility scores" ON credibility_scores;
CREATE POLICY "Service role can insert credibility scores"
ON credibility_scores FOR INSERT
TO service_role
WITH CHECK (true);

-- 用户可以查看自己的详情
DROP POLICY IF EXISTS "用户可以查看自己的信誉评分详情" ON credibility_scores;
CREATE POLICY "用户可以查看自己的信誉评分详情"
ON credibility_scores FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 5. 创建触发器函数
CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 使用 BEGIN...EXCEPTION 块防止触发器失败导致用户创建失败
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

-- 6. 创建触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();

-- 7. 为现有用户创建信誉评分
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 8. 验证
SELECT 
    'auth.users 用户数' as metric,
    COUNT(*) as count
FROM auth.users
UNION ALL
SELECT 
    'credibility_scores 记录数',
    COUNT(*)
FROM credibility_scores;

-- 应该显示两个数字相等

-- =============================================
-- 完成
-- =============================================

DO $$
BEGIN
    RAISE NOTICE '✅ 信誉评分系统设置完成';
    RAISE NOTICE '✅ 新用户注册时会自动创建信誉评分记录';
    RAISE NOTICE '✅ 现有用户的信誉评分记录已补充';
END $$;
```

---

### 步骤 2: 验证触发器已创建

```sql
-- 检查触发器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';
```

**应该返回**:
- `trigger_name`: on_auth_user_created_create_credibility
- `event_manipulation`: INSERT
- `event_object_table`: users (在 auth schema)

---

### 步骤 3: 测试新用户注册

1. 在应用中注册新用户
2. 查询 `credibility_scores` 表：

```sql
-- 查找最新创建的用户
SELECT 
    au.id,
    au.email,
    cs.overall_score,
    cs.tier
FROM auth.users au
LEFT JOIN credibility_scores cs ON au.id = cs.user_id
ORDER BY au.created_at DESC
LIMIT 5;
```

**应该看到**: 新用户有 `overall_score = 3.0`, `tier = 'Normal'`

---

## 方案 2: 应用代码手动创建（备用）✅

**已实现**: 已在代码中添加了自动创建逻辑

### 实现位置

#### 1. SupabaseService.swift

**新增函数**: `ensureCredibilityScoreExists(userId:)`

**功能**:
- 检查用户是否已有信誉评分记录
- 如果没有，创建默认记录
- 如果创建失败，记录日志但不影响注册流程

**代码**:
```swift
/// 确保用户有信誉评分记录（如果没有则创建默认记录）
func ensureCredibilityScoreExists(userId: String) async throws {
    // 查询是否已存在
    let response = try await client
        .from("credibility_scores")
        .select("user_id")
        .eq("user_id", value: userId.lowercased())
        .execute()
    
    // 如果存在，直接返回
    if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
       !jsonArray.isEmpty {
        return
    }
    
    // 不存在，创建默认记录
    struct CredibilityScoreInsert: Encodable {
        let user_id: String
    }
    
    let insert = CredibilityScoreInsert(user_id: userId.lowercased())
    
    try await client
        .from("credibility_scores")
        .insert(insert)
        .execute()
}
```

#### 2. AuthManager.swift

**调用位置**: `supabaseRegister()` 函数中，在 `createUser()` 之后

**代码**:
```swift
let createdUser = try await service.createUser(user: supabaseUser)

// 确保用户有信誉评分记录 ✅ 新增
do {
    try await service.ensureCredibilityScoreExists(userId: user.id.uuidString)
    print("✅ [注册] 用户信誉评分记录已创建")
} catch {
    print("⚠️ [注册] 创建信誉评分失败，但不影响注册流程")
    // 不抛出错误，不影响注册流程
}

let appUser = createdUser.toAppUser()
```

---

## 两种方案对比

| 特性 | 数据库触发器 | 应用代码 |
|------|------------|---------|
| **执行时机** | `auth.signUp()` 后立即执行 | `createUser()` 之后手动调用 |
| **可靠性** | ⚠️ 触发器失败会导致注册失败 | ✅ 失败不影响注册流程 |
| **性能** | ✅ 数据库级别，更快 | ⚠️ 额外一次数据库操作 |
| **维护性** | ⚠️ 需要数据库访问权限 | ✅ 代码控制，更灵活 |
| **一致性** | ✅ 所有用户自动创建 | ✅ 代码保证创建 |

---

## 推荐配置

### 方案 A: 触发器 + 应用代码（双保险）✅

**配置**:
1. 执行上面的完整 SQL 脚本（创建表、触发器、策略）
2. 保留应用代码中的 `ensureCredibilityScoreExists()` 调用

**优点**:
- ✅ 大多数情况下触发器自动创建（快速）
- ✅ 触发器失败时应用代码兜底（可靠）
- ✅ 不影响注册流程

---

### 方案 B: 仅应用代码

**配置**:
1. 禁用触发器（避免触发器失败导致注册失败）
2. 依赖应用代码创建

**SQL**:
```sql
-- 禁用触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
```

**优点**:
- ✅ 避免触发器失败问题
- ✅ 应用完全控制逻辑

**缺点**:
- ⚠️ 需要额外一次数据库操作

---

## 立即执行的配置 SQL

### 完整配置（推荐）

在 Supabase Dashboard → SQL Editor 中执行：

```sql
-- =============================================
-- 信誉评分系统快速配置
-- =============================================

-- 步骤 1: 创建表（如果不存在）
CREATE TABLE IF NOT EXISTS credibility_scores (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    overall_score DECIMAL(2,1) DEFAULT 3.0,
    average_rating DECIMAL(2,1) DEFAULT 3.0,
    fulfillment_rate DECIMAL(5,2) DEFAULT 100.0,
    total_meetings INT DEFAULT 0,
    total_no_shows INT DEFAULT 0,
    last_meeting_date TIMESTAMP WITH TIME ZONE,
    tier VARCHAR(50) DEFAULT 'Normal',
    is_frozen BOOLEAN DEFAULT FALSE,
    freeze_end_date TIMESTAMP WITH TIME ZONE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    gps_anomaly_count INT DEFAULT 0,
    mutual_high_rating_count INT DEFAULT 0,
    last_decay_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 步骤 2: 启用 RLS 并创建策略
ALTER TABLE credibility_scores ENABLE ROW LEVEL SECURITY;

-- ⚠️ 重要：必须先删除现有策略，再创建（PostgreSQL 不支持 IF NOT EXISTS）
DROP POLICY IF EXISTS "任何人可以查看信誉评分" ON credibility_scores;
CREATE POLICY "任何人可以查看信誉评分"
ON credibility_scores FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Service role can insert" ON credibility_scores;
DROP POLICY IF EXISTS "Service role can insert credibility scores" ON credibility_scores;
CREATE POLICY "Service role can insert credibility scores"
ON credibility_scores FOR INSERT
TO service_role
WITH CHECK (true);

DROP POLICY IF EXISTS "用户可以查看自己的信誉评分详情" ON credibility_scores;
CREATE POLICY "用户可以查看自己的信誉评分详情"
ON credibility_scores FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 步骤 3: 创建触发器函数（带错误处理）
CREATE OR REPLACE FUNCTION create_credibility_score_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- 使用 BEGIN...EXCEPTION 防止失败阻止用户创建
    BEGIN
        INSERT INTO credibility_scores (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
        
        RAISE NOTICE '✅ 为新用户创建信誉评分: %', NEW.id;
    EXCEPTION WHEN OTHERS THEN
        -- 记录错误但不阻止用户创建
        RAISE WARNING '⚠️ 创建信誉评分失败（用户 %）: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 步骤 4: 创建触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;
CREATE TRIGGER on_auth_user_created_create_credibility
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION create_credibility_score_for_new_user();

-- 步骤 5: 为现有用户补充信誉评分
INSERT INTO credibility_scores (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM credibility_scores)
ON CONFLICT (user_id) DO NOTHING;

-- 步骤 6: 验证配置
SELECT 
    'auth.users 总数' as metric,
    COUNT(*)::text as count
FROM auth.users
UNION ALL
SELECT 
    'credibility_scores 总数',
    COUNT(*)::text
FROM credibility_scores
UNION ALL
SELECT 
    '缺少评分的用户数',
    COUNT(*)::text
FROM auth.users au
LEFT JOIN credibility_scores cs ON au.id = cs.user_id
WHERE cs.user_id IS NULL;

-- 步骤 7: 检查触发器
SELECT 
    trigger_name,
    event_manipulation,
    event_object_schema || '.' || event_object_table as full_table_name,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';

-- =============================================
-- 完成提示
-- =============================================

DO $$
DECLARE
    v_auth_count INT;
    v_credibility_count INT;
    v_missing_count INT;
BEGIN
    SELECT COUNT(*) INTO v_auth_count FROM auth.users;
    SELECT COUNT(*) INTO v_credibility_count FROM credibility_scores;
    SELECT COUNT(*) INTO v_missing_count
    FROM auth.users au
    LEFT JOIN credibility_scores cs ON au.id = cs.user_id
    WHERE cs.user_id IS NULL;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE '✅ 信誉评分系统配置完成';
    RAISE NOTICE '==============================================';
    RAISE NOTICE 'auth.users 总数: %', v_auth_count;
    RAISE NOTICE 'credibility_scores 总数: %', v_credibility_count;
    RAISE NOTICE '缺少评分的用户: %', v_missing_count;
    
    IF v_missing_count = 0 THEN
        RAISE NOTICE '✅ 所有用户都有信誉评分记录';
    ELSE
        RAISE NOTICE '⚠️ 还有 % 个用户缺少信誉评分', v_missing_count;
    END IF;
    
    RAISE NOTICE '==============================================';
    RAISE NOTICE '下一步：在应用中注册新用户进行测试';
    RAISE NOTICE '==============================================';
END $$;
```

---

## 方案 2: 仅使用应用代码

如果不想使用触发器（避免触发器失败影响注册），可以禁用触发器：

```sql
-- 禁用触发器
DROP TRIGGER IF EXISTS on_auth_user_created_create_credibility ON auth.users;

-- 但仍需要创建表和策略
-- 执行上面的步骤 1-2（创建表和 RLS 策略）
```

**应用代码已实现** (`ensureCredibilityScoreExists()`)，会在注册后自动调用。

---

## 验证配置成功

### 1. 检查表是否存在

```sql
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public'
    AND table_name = 'credibility_scores'
) as table_exists;
```

**应该返回**: `table_exists = true`

---

### 2. 检查 RLS 策略

```sql
SELECT 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'credibility_scores';
```

**应该返回**:
- "任何人可以查看信誉评分" (SELECT, authenticated)
- "Service role can insert" (INSERT, service_role)
- "用户可以查看自己的信誉评分详情" (ALL, authenticated)

---

### 3. 检查触发器是否生效

```sql
-- 查看触发器函数
SELECT 
    proname as function_name,
    prosrc as function_code
FROM pg_proc
WHERE proname = 'create_credibility_score_for_new_user';

-- 查看触发器
SELECT * FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created_create_credibility';
```

---

### 4. 测试触发器

在 SQL Editor 中模拟创建用户：

```sql
-- 开始事务（测试后可回滚）
BEGIN;

-- 插入测试用户到 auth.users（需要特殊权限，可能失败）
-- 改为测试应用层面的注册

-- 查询最新用户的信誉评分
SELECT 
    au.id,
    au.email,
    au.created_at as user_created,
    cs.user_id,
    cs.overall_score,
    cs.tier,
    cs.created_at as score_created
FROM auth.users au
LEFT JOIN credibility_scores cs ON au.id = cs.user_id
ORDER BY au.created_at DESC
LIMIT 5;

-- 回滚测试
ROLLBACK;
```

---

## 故障排查

### 问题 1: 触发器创建失败

**错误**: "permission denied"

**解决**:
```sql
-- 授予函数执行权限
ALTER FUNCTION create_credibility_score_for_new_user() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION create_credibility_score_for_new_user() TO service_role;
```

---

### 问题 2: 触发器插入失败

**错误**: "RLS policy violation"

**解决**:
```sql
-- 确保服务角色可以插入
DROP POLICY IF EXISTS "Service role can insert" ON credibility_scores;
CREATE POLICY "Service role can insert"
ON credibility_scores FOR INSERT
TO service_role
WITH CHECK (true);

-- 或者对触发器使用 SECURITY DEFINER
-- 函数定义中已包含 SECURITY DEFINER
```

---

### 问题 3: 表不存在

**错误**: "relation credibility_scores does not exist"

**解决**:
执行完整的 `create_credibility_system_tables.sql` 脚本

---

## 测试清单

执行完配置后，按顺序测试：

- [ ] 1. 表已创建：`SELECT * FROM credibility_scores LIMIT 1;`
- [ ] 2. RLS 策略存在：`SELECT * FROM pg_policies WHERE tablename = 'credibility_scores';`
- [ ] 3. 触发器函数存在：`SELECT * FROM pg_proc WHERE proname = 'create_credibility_score_for_new_user';`
- [ ] 4. 触发器已创建：`SELECT * FROM information_schema.triggers WHERE trigger_name = 'on_auth_user_created_create_credibility';`
- [ ] 5. 现有用户已补充评分：`SELECT COUNT(*) FROM credibility_scores;`
- [ ] 6. 新用户注册测试：在应用中注册新用户，查询是否自动创建评分
- [ ] 7. 验证默认值：新用户的 `overall_score = 3.0`, `tier = 'Normal'`

---

## 应用代码已完成 ✅

**已添加**:
1. `SupabaseService.ensureCredibilityScoreExists(userId:)` - 确保信誉评分存在
2. `AuthManager.supabaseRegister()` - 注册后自动调用创建信誉评分

**特点**:
- ✅ 自动创建，无需手动调用
- ✅ 失败不影响注册流程
- ✅ 双保险：触发器 + 应用代码

---

## 下一步

1. **立即执行**: 复制上面的 "完整配置 SQL" 到 Supabase SQL Editor
2. **点击运行**: 执行 SQL 脚本
3. **验证**: 查看执行结果和通知消息
4. **测试**: 在应用中注册新用户
5. **确认**: 查询 `credibility_scores` 表，确认新用户有记录

配置完成后，新用户将自动拥有默认信誉评分（3.0 分，Normal 等级）。

