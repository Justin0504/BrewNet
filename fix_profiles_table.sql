-- 修复 profiles 表架构问题
-- 这个脚本将修复 profiles 表中缺少的列

-- 首先检查当前表结构
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 如果 profiles 表不存在，创建它
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

-- 如果表已存在但缺少列，添加缺少的列
DO $$
BEGIN
    -- 检查并添加 core_identity 列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'core_identity'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ADD COLUMN core_identity JSONB;
        RAISE NOTICE 'Added core_identity column';
    END IF;

    -- 检查并添加 professional_background 列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'professional_background'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ADD COLUMN professional_background JSONB;
        RAISE NOTICE 'Added professional_background column';
    END IF;

    -- 检查并添加 networking_intent 列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'networking_intent'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ADD COLUMN networking_intent JSONB;
        RAISE NOTICE 'Added networking_intent column';
    END IF;

    -- 检查并添加 personality_social 列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'personality_social'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ADD COLUMN personality_social JSONB;
        RAISE NOTICE 'Added personality_social column';
    END IF;

    -- 检查并添加 privacy_trust 列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'privacy_trust'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ADD COLUMN privacy_trust JSONB;
        RAISE NOTICE 'Added privacy_trust column';
    END IF;
END $$;

-- 更新现有记录，为缺少的列设置默认值
UPDATE profiles 
SET 
    core_identity = '{}'::jsonb,
    professional_background = '{}'::jsonb,
    networking_intent = '{}'::jsonb,
    personality_social = '{}'::jsonb,
    privacy_trust = '{}'::jsonb
WHERE 
    core_identity IS NULL 
    OR professional_background IS NULL 
    OR networking_intent IS NULL 
    OR personality_social IS NULL 
    OR privacy_trust IS NULL;

-- 设置 NOT NULL 约束（如果列还不存在）
DO $$
BEGIN
    -- 为 core_identity 设置 NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'core_identity'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ALTER COLUMN core_identity SET NOT NULL;
    END IF;

    -- 为 professional_background 设置 NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'professional_background'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ALTER COLUMN professional_background SET NOT NULL;
    END IF;

    -- 为 networking_intent 设置 NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'networking_intent'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ALTER COLUMN networking_intent SET NOT NULL;
    END IF;

    -- 为 personality_social 设置 NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'personality_social'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ALTER COLUMN personality_social SET NOT NULL;
    END IF;

    -- 为 privacy_trust 设置 NOT NULL
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'profiles' 
        AND column_name = 'privacy_trust'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE profiles ALTER COLUMN privacy_trust SET NOT NULL;
    END IF;
END $$;

-- 启用行级安全
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 删除现有策略（如果存在）
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON profiles;

-- 创建新的策略
CREATE POLICY "Users can view their own profile" ON profiles 
    FOR SELECT USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can insert their own profile" ON profiles 
    FOR INSERT WITH CHECK (auth.uid()::text = user_id::text);

CREATE POLICY "Users can update their own profile" ON profiles 
    FOR UPDATE USING (auth.uid()::text = user_id::text);

CREATE POLICY "Users can delete their own profile" ON profiles 
    FOR DELETE USING (auth.uid()::text = user_id::text);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- 创建触发器函数（如果不存在）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at 
    BEFORE UPDATE ON profiles 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 验证修复结果
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 显示成功消息
SELECT '✅ Profiles 表修复完成！所有必需的列已添加。' as status;
