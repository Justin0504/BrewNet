-- =====================================================
-- BrewNet Profile 数据完整存储配置
-- 检查并完善所有 Profile 数据的存储表
-- =====================================================

-- =====================================================
-- 第一部分：检查现有配置
-- =====================================================

-- 1. 检查 profiles 表是否存在且包含所有必要字段
DO $$
DECLARE
    v_profile_table_exists BOOLEAN;
    v_core_identity_exists BOOLEAN;
    v_professional_background_exists BOOLEAN;
    v_networking_intention_exists BOOLEAN;
    v_networking_preferences_exists BOOLEAN;
    v_personality_social_exists BOOLEAN;
    v_privacy_trust_exists BOOLEAN;
BEGIN
    -- 检查表是否存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'profiles'
    ) INTO v_profile_table_exists;
    
    IF v_profile_table_exists THEN
        -- 检查各个 JSONB 字段
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'core_identity' AND data_type = 'jsonb'
        ) INTO v_core_identity_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'professional_background' AND data_type = 'jsonb'
        ) INTO v_professional_background_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'networking_intention' AND data_type = 'jsonb'
        ) INTO v_networking_intention_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'networking_preferences' AND data_type = 'jsonb'
        ) INTO v_networking_preferences_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'personality_social' AND data_type = 'jsonb'
        ) INTO v_personality_social_exists;
        
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'profiles' 
            AND column_name = 'privacy_trust' AND data_type = 'jsonb'
        ) INTO v_privacy_trust_exists;
        
        RAISE NOTICE '=====================================================';
        RAISE NOTICE 'Profile 表字段检查结果：';
        RAISE NOTICE '  core_identity: %', CASE WHEN v_core_identity_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '  professional_background: %', CASE WHEN v_professional_background_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '  networking_intention: %', CASE WHEN v_networking_intention_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '  networking_preferences: %', CASE WHEN v_networking_preferences_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '  personality_social: %', CASE WHEN v_personality_social_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '  privacy_trust: %', CASE WHEN v_privacy_trust_exists THEN '✅' ELSE '❌' END;
        RAISE NOTICE '=====================================================';
    ELSE
        RAISE NOTICE '❌ profiles 表不存在！';
    END IF;
END $$;

-- =====================================================
-- 第二部分：确保 profiles 表结构完整
-- =====================================================

-- 确保 profiles 表存在且结构正确
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    core_identity JSONB NOT NULL DEFAULT '{}'::jsonb,
    professional_background JSONB NOT NULL DEFAULT '{}'::jsonb,
    networking_intention JSONB NOT NULL DEFAULT '{}'::jsonb,
    networking_preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    personality_social JSONB NOT NULL DEFAULT '{}'::jsonb,
    privacy_trust JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 添加缺失的字段（如果不存在）
DO $$
BEGIN
    -- core_identity
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'core_identity') THEN
        ALTER TABLE profiles ADD COLUMN core_identity JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 core_identity 字段';
    END IF;
    
    -- professional_background
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'professional_background') THEN
        ALTER TABLE profiles ADD COLUMN professional_background JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 professional_background 字段';
    END IF;
    
    -- networking_intention
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'networking_intention') THEN
        ALTER TABLE profiles ADD COLUMN networking_intention JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 networking_intention 字段';
    END IF;
    
    -- networking_preferences
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'networking_preferences') THEN
        ALTER TABLE profiles ADD COLUMN networking_preferences JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 networking_preferences 字段';
    END IF;
    
    -- personality_social
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'personality_social') THEN
        ALTER TABLE profiles ADD COLUMN personality_social JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 personality_social 字段';
    END IF;
    
    -- privacy_trust
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'privacy_trust') THEN
        ALTER TABLE profiles ADD COLUMN privacy_trust JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 privacy_trust 字段';
    END IF;
END $$;

-- =====================================================
-- 第三部分：可选优化表（用于更高效的查询）
-- =====================================================

-- 注意：这些表是可选的，用于优化特定查询场景
-- 当前所有数据都存储在 profiles 表的 JSONB 字段中
-- 如果需要频繁查询工作经历或教育背景，可以考虑使用这些表

-- 工作经历表（可选，用于优化查询）
CREATE TABLE IF NOT EXISTS work_experiences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    position TEXT,
    start_year INTEGER NOT NULL,
    end_year INTEGER, -- NULL 表示当前工作
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_work_experiences_user_id ON work_experiences(user_id);
CREATE INDEX IF NOT EXISTS idx_work_experiences_profile_id ON work_experiences(profile_id);
CREATE INDEX IF NOT EXISTS idx_work_experiences_company ON work_experiences(company_name);

-- 启用 RLS
ALTER TABLE work_experiences ENABLE ROW LEVEL SECURITY;

-- RLS 策略
DROP POLICY IF EXISTS "Users can view their own work experiences" ON work_experiences;
DROP POLICY IF EXISTS "Users can manage their own work experiences" ON work_experiences;

CREATE POLICY "Users can view their own work experiences" ON work_experiences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own work experiences" ON work_experiences
    FOR ALL USING (auth.uid() = user_id);

-- 教育背景表（可选，用于优化查询）
CREATE TABLE IF NOT EXISTS education_backgrounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    school_name TEXT NOT NULL,
    degree_type TEXT NOT NULL,
    field_of_study TEXT,
    start_year INTEGER NOT NULL,
    end_year INTEGER, -- NULL 表示在读
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_education_backgrounds_user_id ON education_backgrounds(user_id);
CREATE INDEX IF NOT EXISTS idx_education_backgrounds_profile_id ON education_backgrounds(profile_id);
CREATE INDEX IF NOT EXISTS idx_education_backgrounds_school ON education_backgrounds(school_name);

-- 启用 RLS
ALTER TABLE education_backgrounds ENABLE ROW LEVEL SECURITY;

-- RLS 策略
DROP POLICY IF EXISTS "Users can view their own education" ON education_backgrounds;
DROP POLICY IF EXISTS "Users can manage their own education" ON education_backgrounds;

CREATE POLICY "Users can view their own education" ON education_backgrounds
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own education" ON education_backgrounds
    FOR ALL USING (auth.uid() = user_id);

-- 触发器函数（已存在则跳过）
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为工作经历表添加触发器
DROP TRIGGER IF EXISTS update_work_experiences_updated_at ON work_experiences CASCADE;
CREATE TRIGGER update_work_experiences_updated_at 
    BEFORE UPDATE ON work_experiences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 为教育背景表添加触发器
DROP TRIGGER IF EXISTS update_education_backgrounds_updated_at ON education_backgrounds CASCADE;
CREATE TRIGGER update_education_backgrounds_updated_at 
    BEFORE UPDATE ON education_backgrounds
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 第四部分：JSONB 索引优化（用于查询 JSONB 字段）
-- =====================================================

-- 为 JSONB 字段创建 GIN 索引以提高查询性能
-- 这些索引是可选的，但可以显著提高 JSONB 查询性能

-- core_identity 索引
CREATE INDEX IF NOT EXISTS idx_profiles_core_identity_gin 
ON profiles USING GIN (core_identity);

-- professional_background 索引（特别针对 skills, company 等字段）
CREATE INDEX IF NOT EXISTS idx_profiles_professional_background_gin 
ON profiles USING GIN (professional_background);

-- 为常用的 JSONB 路径创建表达式索引
-- 例如：查询特定技能的用户
CREATE INDEX IF NOT EXISTS idx_profiles_skills 
ON profiles USING GIN ((professional_background->'skills'));

-- 查询特定公司的用户
CREATE INDEX IF NOT EXISTS idx_profiles_current_company 
ON profiles ((professional_background->>'current_company'));

-- 查询特定位置的用户
CREATE INDEX IF NOT EXISTS idx_profiles_location 
ON profiles ((core_identity->>'location'));

-- =====================================================
-- 第五部分：验证完整性
-- =====================================================

DO $$
DECLARE
    v_all_fields_exist BOOLEAN;
    v_required_fields_count INTEGER;
BEGIN
    -- 检查所有必需字段是否存在
    SELECT COUNT(*) INTO v_required_fields_count
    FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'profiles'
    AND column_name IN (
        'core_identity', 
        'professional_background', 
        'networking_intention', 
        'networking_preferences', 
        'personality_social', 
        'privacy_trust'
    )
    AND data_type = 'jsonb';
    
    v_all_fields_exist := (v_required_fields_count = 6);
    
    RAISE NOTICE '';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE '最终验证结果';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE '必需字段数量: % / 6', v_required_fields_count;
    
    IF v_all_fields_exist THEN
        RAISE NOTICE '✅ 所有 Profile 字段都已正确配置！';
        RAISE NOTICE '';
        RAISE NOTICE 'Profile 数据存储方式：';
        RAISE NOTICE '  1. 所有数据存储在 profiles 表的 JSONB 字段中';
        RAISE NOTICE '  2. 可选表（work_experiences, education_backgrounds）已创建';
        RAISE NOTICE '  3. JSONB 索引已优化';
        RAISE NOTICE '';
        RAISE NOTICE '数据映射：';
        RAISE NOTICE '  ✅ Core Identity → core_identity JSONB';
        RAISE NOTICE '  ✅ Professional Background → professional_background JSONB';
        RAISE NOTICE '    - workExperiences → work_experiences 表（可选）';
        RAISE NOTICE '  ✅ Networking Intention → networking_intention JSONB';
        RAISE NOTICE '  ✅ Networking Preferences → networking_preferences JSONB';
        RAISE NOTICE '  ✅ Personality & Social → personality_social JSONB';
        RAISE NOTICE '  ✅ Privacy & Trust → privacy_trust JSONB';
    ELSE
        RAISE NOTICE '❌ 配置不完整，请检查缺失的字段';
    END IF;
    
    RAISE NOTICE '=====================================================';
END $$;

-- =====================================================
-- 完成
-- =====================================================

-- 所有 Profile 数据现在都有对应的存储位置：
-- 1. 主要数据存储在 profiles 表的 JSONB 字段中
-- 2. 可选表已创建用于优化查询（work_experiences, education_backgrounds）
-- 3. JSONB 索引已创建以提高查询性能

