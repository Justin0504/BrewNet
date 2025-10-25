-- 快速修复 profiles 表问题
-- 请在 Supabase Dashboard 的 SQL Editor 中执行此脚本

-- 1. 首先检查当前表结构
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. 如果 profiles 表不存在，创建完整的表
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

-- 3. 如果表存在但缺少列，添加缺少的列
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS core_identity JSONB,
ADD COLUMN IF NOT EXISTS professional_background JSONB,
ADD COLUMN IF NOT EXISTS networking_intent JSONB,
ADD COLUMN IF NOT EXISTS personality_social JSONB,
ADD COLUMN IF NOT EXISTS privacy_trust JSONB;

-- 4. 为现有记录设置默认值
UPDATE profiles 
SET 
    core_identity = COALESCE(core_identity, '{}'::jsonb),
    professional_background = COALESCE(professional_background, '{}'::jsonb),
    networking_intent = COALESCE(networking_intent, '{}'::jsonb),
    personality_social = COALESCE(personality_social, '{}'::jsonb),
    privacy_trust = COALESCE(privacy_trust, '{}'::jsonb);

-- 5. 设置 NOT NULL 约束
ALTER TABLE profiles 
ALTER COLUMN core_identity SET NOT NULL,
ALTER COLUMN professional_background SET NOT NULL,
ALTER COLUMN networking_intent SET NOT NULL,
ALTER COLUMN personality_social SET NOT NULL,
ALTER COLUMN privacy_trust SET NOT NULL;

-- 6. 启用行级安全
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 7. 创建策略
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

-- 8. 创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- 9. 验证修复结果
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT '✅ 修复完成！现在可以正常保存用户资料了。' as result;
