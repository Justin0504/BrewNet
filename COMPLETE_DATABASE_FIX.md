# 完整数据库修复指南

## 问题描述
您遇到了多个数据库架构问题：
1. 缺少 `core_identity` 列
2. 字段长度限制问题
3. 缺少 `profile_image` 等列

## 解决方案

### 步骤 1：修复缺失的列

执行以下 SQL 脚本来添加所有缺失的列：

```sql
-- 修复缺失的列问题
-- 这个脚本将添加缺失的列到 users 表

-- 1. 首先检查当前 users 表结构
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. 添加缺失的列到 users 表
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_image TEXT,
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS company TEXT,
ADD COLUMN IF NOT EXISTS job_title TEXT,
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS skills TEXT,
ADD COLUMN IF NOT EXISTS interests TEXT,
ADD COLUMN IF NOT EXISTS profile_setup_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. 如果 created_at 列不存在，也添加它
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 4. 确保所有列都有正确的默认值
UPDATE users 
SET 
    profile_setup_completed = COALESCE(profile_setup_completed, FALSE),
    last_login_at = COALESCE(last_login_at, NOW()),
    updated_at = COALESCE(updated_at, NOW()),
    created_at = COALESCE(created_at, NOW())
WHERE 
    profile_setup_completed IS NULL 
    OR last_login_at IS NULL 
    OR updated_at IS NULL 
    OR created_at IS NULL;

-- 5. 创建触发器函数（如果不存在）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 6. 创建或更新触发器
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 7. 确保 RLS 已启用
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 8. 重新创建策略（如果不存在）
DROP POLICY IF EXISTS "Enable all operations for authenticated users" ON users;
DROP POLICY IF EXISTS "Enable all operations for anonymous users" ON users;

CREATE POLICY "Enable all operations for authenticated users" ON users 
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Enable all operations for anonymous users" ON users 
    FOR ALL USING (true) WITH CHECK (true);

-- 9. 创建索引
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_profile_setup_completed ON users(profile_setup_completed);

SELECT '✅ 缺失的列已添加！users 表现在包含所有必需的列。' as result;
```

### 步骤 2：修复字段长度限制

执行以下 SQL 脚本来移除字段长度限制：

```sql
-- 修复字段长度限制问题
-- 这个脚本将移除或增加字段的长度限制

-- 1. 修改 users 表的字段类型，移除长度限制
ALTER TABLE users 
ALTER COLUMN name TYPE TEXT,
ALTER COLUMN email TYPE TEXT,
ALTER COLUMN phone_number TYPE TEXT,
ALTER COLUMN profile_image TYPE TEXT,
ALTER COLUMN bio TYPE TEXT,
ALTER COLUMN company TYPE TEXT,
ALTER COLUMN job_title TYPE TEXT,
ALTER COLUMN location TYPE TEXT,
ALTER COLUMN skills TYPE TEXT,
ALTER COLUMN interests TYPE TEXT;

-- 2. 确保 profiles 表使用 JSONB 类型（无长度限制）
ALTER TABLE profiles 
ALTER COLUMN core_identity TYPE JSONB,
ALTER COLUMN professional_background TYPE JSONB,
ALTER COLUMN networking_intent TYPE JSONB,
ALTER COLUMN personality_social TYPE JSONB,
ALTER COLUMN privacy_trust TYPE JSONB;

SELECT '✅ 字段长度限制已修复！现在可以保存更长的文本内容了。' as result;
```

### 步骤 3：修复 profiles 表

执行以下 SQL 脚本来确保 profiles 表结构正确：

```sql
-- 快速修复 profiles 表问题
-- 请在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 如果 profiles 表不存在，创建完整的表
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL,
    professional_background JSONB NOT NULL,
    networking_intent JSONB NOT NULL,
    personality_social JSONB NOT NULL,
    privacy_trust JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 2. 如果表存在但缺少列，添加缺少的列
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS core_identity JSONB,
ADD COLUMN IF NOT EXISTS professional_background JSONB,
ADD COLUMN IF NOT EXISTS networking_intent JSONB,
ADD COLUMN IF NOT EXISTS personality_social JSONB,
ADD COLUMN IF NOT EXISTS privacy_trust JSONB;

-- 3. 为现有记录设置默认值
UPDATE profiles 
SET 
    core_identity = COALESCE(core_identity, '{}'::jsonb),
    professional_background = COALESCE(professional_background, '{}'::jsonb),
    networking_intent = COALESCE(networking_intent, '{}'::jsonb),
    personality_social = COALESCE(personality_social, '{}'::jsonb),
    privacy_trust = COALESCE(privacy_trust, '{}'::jsonb);

-- 4. 设置 NOT NULL 约束
ALTER TABLE profiles 
ALTER COLUMN core_identity SET NOT NULL,
ALTER COLUMN professional_background SET NOT NULL,
ALTER COLUMN networking_intent SET NOT NULL,
ALTER COLUMN personality_social SET NOT NULL,
ALTER COLUMN privacy_trust SET NOT NULL;

-- 5. 启用行级安全
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 6. 创建策略
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- 7. 创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

SELECT '✅ 修复完成！现在可以正常保存用户资料了。' as result;
```

## 执行顺序

1. **首先执行步骤 1** - 修复缺失的列
2. **然后执行步骤 2** - 修复字段长度限制
3. **最后执行步骤 3** - 修复 profiles 表

## 验证修复

执行所有脚本后：

1. 重新尝试创建用户资料
2. 检查是否还有任何错误
3. 验证所有功能正常工作

## 预防措施

为了避免将来出现类似问题：

1. 使用项目提供的完整数据库设置脚本
2. 定期备份数据库
3. 在部署前测试数据库架构
4. 使用 `TEXT` 类型而不是 `VARCHAR(n)` 类型

修复完成后，您的 BrewNet 应用应该能够正常保存用户资料了！
