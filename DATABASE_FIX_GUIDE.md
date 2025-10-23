# 数据库修复指南

## 问题描述
您遇到的错误："Failed to save profile: Failed to create profile: Could not find the 'core_identity' column of 'profiles' in the schema cache" 表明数据库中的 `profiles` 表缺少必需的列。

## 解决方案

### 方法 1：使用快速修复脚本（推荐）

1. 打开 Supabase Dashboard
2. 进入 SQL Editor
3. 复制并执行以下 SQL 脚本：

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

### 方法 2：使用完整数据库设置脚本

如果您需要设置完整的数据库架构，可以使用项目根目录中的以下文件：

1. `complete_database_setup.sql` - 完整的数据库设置
2. `safe_database_setup.sql` - 安全的数据库设置
3. `fix_profiles_table.sql` - 详细的修复脚本

## 验证修复

执行修复脚本后，您可以：

1. 重新尝试创建用户资料
2. 检查应用是否不再显示错误
3. 验证用户资料可以正常保存

## 预防措施

为了避免将来出现类似问题，建议：

1. 使用项目提供的完整数据库设置脚本
2. 定期备份数据库
3. 在部署前测试数据库架构

## 技术支持

如果问题仍然存在，请检查：

1. Supabase 连接是否正常
2. 数据库权限是否正确设置
3. 网络连接是否稳定

修复完成后，您的 BrewNet 应用应该能够正常保存用户资料了！
