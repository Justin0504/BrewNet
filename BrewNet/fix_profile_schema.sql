-- =====================================================
-- 修复 Profile Schema 问题
-- 检查和迁移旧数据结构
-- =====================================================

-- =====================================================
-- 1. 检查现有 profiles 表结构
-- =====================================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'profiles'
ORDER BY ordinal_position;

-- =====================================================
-- 2. 检查是否有旧字段名
-- =====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'networking_intent'
    ) THEN
        RAISE NOTICE '⚠️ 发现旧字段 networking_intent，需要迁移数据';
    ELSE
        RAISE NOTICE '✅ 没有旧字段 networking_intent';
    END IF;
END $$;

-- =====================================================
-- 3. 确保所有正确的字段都存在
-- =====================================================

-- 创建/更新 profiles 表为正确结构
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

-- 添加缺失的字段
DO $$
BEGIN
    -- networking_intention
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'networking_intention'
    ) THEN
        ALTER TABLE profiles ADD COLUMN networking_intention JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 networking_intention 字段';
    END IF;
    
    -- networking_preferences
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'networking_preferences'
    ) THEN
        ALTER TABLE profiles ADD COLUMN networking_preferences JSONB NOT NULL DEFAULT '{}'::jsonb;
        RAISE NOTICE '✅ 添加 networking_preferences 字段';
    END IF;
END $$;

-- =====================================================
-- 4. 迁移旧数据（如果有 networking_intent 字段）
-- =====================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'networking_intent'
    ) THEN
        RAISE NOTICE '开始迁移 networking_intent 数据...';
        
        -- 将 networking_intent 内容复制到 networking_intention 和 networking_preferences
        UPDATE profiles
        SET 
            networking_intention = COALESCE(networking_intent, '{}'::jsonb),
            networking_preferences = jsonb_build_object(
                'preferred_chat_format', COALESCE(networking_intent->>'preferred_chat_format', 'Either'),
                'available_timeslot', COALESCE(networking_intent->'available_timeslot', '{}'::jsonb),
                'preferred_chat_duration', networking_intent->>'preferred_chat_duration'
            )
        WHERE networking_intent IS NOT NULL;
        
        RAISE NOTICE '✅ 数据迁移完成';
        
        -- 可选：删除旧字段
        -- ALTER TABLE profiles DROP COLUMN networking_intent;
        -- RAISE NOTICE '✅ 删除旧字段 networking_intent';
    END IF;
END $$;

-- =====================================================
-- 5. 为现有记录设置默认值（如果字段为空）
-- =====================================================

UPDATE profiles 
SET 
    core_identity = COALESCE(core_identity, '{}'::jsonb),
    professional_background = COALESCE(professional_background, '{}'::jsonb),
    networking_intention = COALESCE(networking_intention, '{}'::jsonb),
    networking_preferences = COALESCE(networking_preferences, '{}'::jsonb),
    personality_social = COALESCE(personality_social, '{}'::jsonb),
    privacy_trust = COALESCE(privacy_trust, '{}'::jsonb)
WHERE 
    core_identity IS NULL OR
    professional_background IS NULL OR
    networking_intention IS NULL OR
    networking_preferences IS NULL OR
    personality_social IS NULL OR
    privacy_trust IS NULL;

-- =====================================================
-- 6. 设置 NOT NULL 约束
-- =====================================================

ALTER TABLE profiles 
    ALTER COLUMN core_identity SET NOT NULL,
    ALTER COLUMN professional_background SET NOT NULL,
    ALTER COLUMN networking_intention SET NOT NULL,
    ALTER COLUMN networking_preferences SET NOT NULL,
    ALTER COLUMN personality_social SET NOT NULL,
    ALTER COLUMN privacy_trust SET NOT NULL;

-- 如果字段还没有默认值，设置默认值
ALTER TABLE profiles 
    ALTER COLUMN core_identity SET DEFAULT '{}'::jsonb,
    ALTER COLUMN professional_background SET DEFAULT '{}'::jsonb,
    ALTER COLUMN networking_intention SET DEFAULT '{}'::jsonb,
    ALTER COLUMN networking_preferences SET DEFAULT '{}'::jsonb,
    ALTER COLUMN personality_social SET DEFAULT '{}'::jsonb,
    ALTER COLUMN privacy_trust SET DEFAULT '{}'::jsonb;

-- =====================================================
-- 7. 验证修复结果
-- =====================================================

DO $$
DECLARE
    v_correct_fields_count INTEGER;
    v_profile_count INTEGER;
BEGIN
    -- 检查字段数量
    SELECT COUNT(*) INTO v_correct_fields_count
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
    
    -- 检查记录数量
    SELECT COUNT(*) INTO v_profile_count
    FROM profiles;
    
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Profile Schema 修复结果';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE '正确字段数: % / 6', v_correct_fields_count;
    RAISE NOTICE 'Profile 记录数: %', v_profile_count;
    
    IF v_correct_fields_count = 6 THEN
        RAISE NOTICE '✅ 所有字段已正确配置！';
    ELSE
        RAISE NOTICE '❌ 仍有字段缺失或配置不正确';
    END IF;
    
    RAISE NOTICE '=====================================================';
END $$;

-- =====================================================
-- 8. 显示当前 profiles 表的数据示例
-- =====================================================

SELECT 
    id,
    user_id,
    CASE 
        WHEN core_identity IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as core_identity_status,
    CASE 
        WHEN professional_background IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as professional_background_status,
    CASE 
        WHEN networking_intention IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as networking_intention_status,
    CASE 
        WHEN networking_preferences IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as networking_preferences_status,
    CASE 
        WHEN personality_social IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as personality_social_status,
    CASE 
        WHEN privacy_trust IS NULL THEN 'NULL'
        ELSE 'JSONB'
    END as privacy_trust_status
FROM profiles
LIMIT 5;

-- =====================================================
-- 完成
-- =====================================================

-- 运行此脚本后，所有 profiles 记录都应该有正确的 JSONB 字段结构

