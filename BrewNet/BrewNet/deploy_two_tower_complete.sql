-- Two-Tower Recommendation System - Complete Deployment Script
-- ============================================================
-- 执行此脚本将一次性完成 Two-Tower 系统的所有数据库设置
-- 
-- 执行方式：
-- 1. 在 Supabase Dashboard 的 SQL Editor 中复制粘贴此文件内容
-- 2. 点击 "Run" 按钮执行
-- 
-- 预期时间：< 5 秒
-- ============================================================

BEGIN;

-- ============================================================
-- PART 1: 创建数据表
-- ============================================================

-- 1. 用户特征表
CREATE TABLE IF NOT EXISTS user_features (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    location VARCHAR(100),
    time_zone VARCHAR(50),
    industry VARCHAR(100),
    experience_level VARCHAR(50),
    career_stage VARCHAR(50),
    main_intention VARCHAR(50),
    skills JSONB DEFAULT '[]'::jsonb,
    hobbies JSONB DEFAULT '[]'::jsonb,
    values JSONB DEFAULT '[]'::jsonb,
    languages JSONB DEFAULT '[]'::jsonb,
    sub_intentions JSONB DEFAULT '[]'::jsonb,
    skills_to_learn JSONB DEFAULT '[]'::jsonb,
    skills_to_teach JSONB DEFAULT '[]'::jsonb,
    functions_to_learn JSONB DEFAULT '[]'::jsonb,
    functions_to_teach JSONB DEFAULT '[]'::jsonb,
    years_of_experience FLOAT DEFAULT 0,
    profile_completion FLOAT DEFAULT 0,
    is_verified INT DEFAULT 0,
    user_embedding FLOAT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_features_industry ON user_features(industry);
CREATE INDEX IF NOT EXISTS idx_user_features_intention ON user_features(main_intention);
CREATE INDEX IF NOT EXISTS idx_user_features_created ON user_features(created_at);

COMMENT ON TABLE user_features IS '用户特征表，用于 Two-Tower 推荐模型的特征存储';

-- 2. 用户交互表
CREATE TABLE IF NOT EXISTS user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL CHECK (interaction_type IN ('like', 'pass', 'match')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, target_user_id, interaction_type)
);

CREATE INDEX IF NOT EXISTS idx_interactions_user_type ON user_interactions(user_id, interaction_type);
CREATE INDEX IF NOT EXISTS idx_interactions_target ON user_interactions(target_user_id);
CREATE INDEX IF NOT EXISTS idx_interactions_created ON user_interactions(created_at);

COMMENT ON TABLE user_interactions IS '用户交互日志表，记录用户的 like/pass/match 行为';

-- 3. 推荐缓存表
CREATE TABLE IF NOT EXISTS recommendation_cache (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    recommended_user_ids JSONB,
    scores JSONB,
    model_version VARCHAR(50) DEFAULT 'baseline',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_cache_expires ON recommendation_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_cache_model ON recommendation_cache(model_version);

COMMENT ON TABLE recommendation_cache IS '推荐结果缓存表，提高推荐响应速度';

-- ============================================================
-- PART 2: 创建辅助函数
-- ============================================================

-- 提取技能学习/教授列表
CREATE OR REPLACE FUNCTION extract_skills_from_development(dev_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    skill_record JSONB;
BEGIN
    IF dev_data IS NULL OR dev_data->'skills' IS NULL THEN
        RETURN result;
    END IF;
    
    FOR skill_record IN SELECT * FROM jsonb_array_elements(dev_data->'skills')
    LOOP
        IF (skill_record->>mode)::boolean = true THEN
            result := result || jsonb_build_array(skill_record->>'skill_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 提取职能学习/教授列表
CREATE OR REPLACE FUNCTION extract_functions_from_direction(direction_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    func_record JSONB;
BEGIN
    IF direction_data IS NULL OR direction_data->'functions' IS NULL THEN
        RETURN result;
    END IF;
    
    FOR func_record IN SELECT * FROM jsonb_array_elements(direction_data->'functions')
    LOOP
        IF jsonb_array_length(COALESCE(func_record->(mode), '[]'::jsonb)) > 0 THEN
            result := result || jsonb_build_array(func_record->>'function_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 计算资料完整度
CREATE OR REPLACE FUNCTION calculate_profile_completion(profile_data JSONB)
RETURNS FLOAT AS $$
DECLARE
    completed_fields INT := 0;
    total_fields INT := 20;
BEGIN
    IF (profile_data->'core_identity'->>'name') IS NOT NULL AND (profile_data->'core_identity'->>'name') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'bio') IS NOT NULL AND (profile_data->'core_identity'->>'bio') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'location') IS NOT NULL AND (profile_data->'core_identity'->>'location') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'pronouns') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'core_identity'->>'time_zone') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'job_title') IS NOT NULL AND (profile_data->'professional_background'->>'job_title') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'current_company') IS NOT NULL AND (profile_data->'professional_background'->>'current_company') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'industry') IS NOT NULL AND (profile_data->'professional_background'->>'industry') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'education') IS NOT NULL AND (profile_data->'professional_background'->>'education') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'skills', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'languages_spoken', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'work_experiences', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'personality_social'->>'self_introduction') IS NOT NULL AND (profile_data->'personality_social'->>'self_introduction') != '' THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'personality_social'->'hobbies', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'personality_social'->'values_tags', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'networking_intention'->>'selected_intention') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF jsonb_array_length(COALESCE(profile_data->'networking_intention'->'selected_sub_intentions', '[]'::jsonb)) > 0 THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'networking_preferences'->>'preferred_chat_format') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    IF (profile_data->'professional_background'->>'years_of_experience') IS NOT NULL THEN completed_fields := completed_fields + 1; END IF;
    
    RETURN completed_fields::FLOAT / total_fields::FLOAT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PART 3: 创建同步触发器函数
-- ============================================================

CREATE OR REPLACE FUNCTION sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_features (
        user_id, location, time_zone, industry, experience_level, career_stage, main_intention,
        skills, hobbies, values, languages, sub_intentions,
        skills_to_learn, skills_to_teach, functions_to_learn, functions_to_teach,
        years_of_experience, profile_completion, is_verified
    ) VALUES (
        NEW.user_id,
        NEW.core_identity->>'location',
        NEW.core_identity->>'time_zone',
        NEW.professional_background->>'industry',
        NEW.professional_background->>'experience_level',
        NEW.professional_background->>'career_stage',
        NEW.networking_intention->>'selected_intention',
        NEW.professional_background->'skills',
        NEW.personality_social->'hobbies',
        NEW.personality_social->'values_tags',
        NEW.professional_background->'languages_spoken',
        NEW.networking_intention->'selected_sub_intentions',
        extract_skills_from_development(NEW.networking_intention->'skill_development', 'learn_in'),
        extract_skills_from_development(NEW.networking_intention->'skill_development', 'guide_in'),
        extract_functions_from_direction(NEW.networking_intention->'career_direction', 'learn_in'),
        extract_functions_from_direction(NEW.networking_intention->'career_direction', 'guide_in'),
        COALESCE((NEW.professional_background->>'years_of_experience')::FLOAT, 0),
        calculate_profile_completion(NEW::jsonb),
        CASE 
            WHEN NEW.privacy_trust->'verified_status' = '"verified_professional"' THEN 1 
            WHEN NEW.privacy_trust->'verified_status' = '"verified"' THEN 1 
            ELSE 0 
        END
    )
    ON CONFLICT (user_id) DO UPDATE
    SET location = EXCLUDED.location, time_zone = EXCLUDED.time_zone,
        industry = EXCLUDED.industry, experience_level = EXCLUDED.experience_level,
        career_stage = EXCLUDED.career_stage, main_intention = EXCLUDED.main_intention,
        skills = EXCLUDED.skills, hobbies = EXCLUDED.hobbies,
        values = EXCLUDED.values, languages = EXCLUDED.languages,
        sub_intentions = EXCLUDED.sub_intentions,
        skills_to_learn = EXCLUDED.skills_to_learn,
        skills_to_teach = EXCLUDED.skills_to_teach,
        functions_to_learn = EXCLUDED.functions_to_learn,
        functions_to_teach = EXCLUDED.functions_to_teach,
        years_of_experience = EXCLUDED.years_of_experience,
        profile_completion = EXCLUDED.profile_completion,
        is_verified = EXCLUDED.is_verified,
        updated_at = NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PART 4: 创建触发器
-- ============================================================

DROP TRIGGER IF EXISTS trigger_sync_user_features ON profiles;

CREATE TRIGGER trigger_sync_user_features
    AFTER INSERT OR UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_features();

-- ============================================================
-- PART 5: 初始化数据（为现有用户同步特征）
-- ============================================================

-- 为所有现有 profiles 创建 user_features 记录
INSERT INTO user_features (
    user_id, location, time_zone, industry, experience_level, career_stage, main_intention,
    skills, hobbies, values, languages, sub_intentions,
    skills_to_learn, skills_to_teach, functions_to_learn, functions_to_teach,
    years_of_experience, profile_completion, is_verified
)
SELECT 
    user_id,
    core_identity->>'location' as location,
    core_identity->>'time_zone' as time_zone,
    professional_background->>'industry' as industry,
    professional_background->>'experience_level' as experience_level,
    professional_background->>'career_stage' as career_stage,
    networking_intention->>'selected_intention' as main_intention,
    professional_background->'skills' as skills,
    personality_social->'hobbies' as hobbies,
    personality_social->'values_tags' as values,
    professional_background->'languages_spoken' as languages,
    networking_intention->'selected_sub_intentions' as sub_intentions,
    extract_skills_from_development(networking_intention->'skill_development', 'learn_in') as skills_to_learn,
    extract_skills_from_development(networking_intention->'skill_development', 'guide_in') as skills_to_teach,
    extract_functions_from_direction(networking_intention->'career_direction', 'learn_in') as functions_to_learn,
    extract_functions_from_direction(networking_intention->'career_direction', 'guide_in') as functions_to_teach,
    COALESCE((professional_background->>'years_of_experience')::FLOAT, 0) as years_of_experience,
    calculate_profile_completion(row_to_json(p.*)::jsonb) as profile_completion,
    CASE 
        WHEN privacy_trust->'verified_status' = '"verified_professional"' THEN 1 
        WHEN privacy_trust->'verified_status' = '"verified"' THEN 1 
        ELSE 0 
    END as is_verified
FROM profiles p
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================
-- PART 6: 验证和报告
-- ============================================================

COMMIT;

DO $$
DECLARE
    profiles_count INT;
    features_count INT;
    sync_rate NUMERIC;
BEGIN
    SELECT COUNT(*) INTO profiles_count FROM profiles;
    SELECT COUNT(*) INTO features_count FROM user_features;
    
    IF profiles_count > 0 THEN
        sync_rate := ROUND((features_count::NUMERIC / profiles_count::NUMERIC * 100)::NUMERIC, 2);
    ELSE
        sync_rate := 0;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE '✅ Two-Tower Recommendation System Deployed!';
    RAISE NOTICE '==================================================';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Statistics:';
    RAISE NOTICE '   - Profiles: %', profiles_count;
    RAISE NOTICE '   - User Features Synced: %', features_count;
    RAISE NOTICE '   - Sync Rate: %', sync_rate || '%';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Tables created: user_features, user_interactions, recommendation_cache';
    RAISE NOTICE '✅ Functions created: extract_skills, extract_functions, calculate_completion, sync_features';
    RAISE NOTICE '✅ Trigger created: trigger_sync_user_features';
    RAISE NOTICE '✅ Data initialized: Existing profiles synced';
    RAISE NOTICE '';
    RAISE NOTICE '🎉 Deployment Complete!';
    RAISE NOTICE '==================================================';
END $$;

