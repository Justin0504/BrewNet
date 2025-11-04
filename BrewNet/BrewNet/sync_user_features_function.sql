-- Two-Tower User Features Sync Functions
-- Created: 2024-12-28
-- Purpose: 自动从 profiles 表同步数据到 user_features 表

-- ============================================================
-- 辅助函数：提取技能学习/教授列表
-- ============================================================
CREATE OR REPLACE FUNCTION extract_skills_from_development(dev_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    skill_record JSONB;
BEGIN
    -- 检查数据有效性
    IF dev_data IS NULL OR dev_data->'skills' IS NULL THEN
        RETURN result;
    END IF;
    
    -- 遍历 skills 数组
    FOR skill_record IN SELECT * FROM jsonb_array_elements(dev_data->'skills')
    LOOP
        -- 根据 mode 判断是 learn_in 还是 guide_in
        IF (skill_record->>mode)::boolean = true THEN
            result := result || jsonb_build_array(skill_record->>'skill_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 辅助函数：提取职能学习/教授列表
-- ============================================================
CREATE OR REPLACE FUNCTION extract_functions_from_direction(direction_data JSONB, mode TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB := '[]'::jsonb;
    func_record JSONB;
BEGIN
    -- 检查数据有效性
    IF direction_data IS NULL OR direction_data->'functions' IS NULL THEN
        RETURN result;
    END IF;
    
    -- 遍历 functions 数组
    FOR func_record IN SELECT * FROM jsonb_array_elements(direction_data->'functions')
    LOOP
        -- 根据 mode 判断是 learn_in 还是 guide_in
        -- 注意：functions 字段本身可能是数组，需要特殊处理
        IF jsonb_array_length(COALESCE(func_record->(mode), '[]'::jsonb)) > 0 THEN
            -- 如果有多个值，取第一个
            result := result || jsonb_build_array(func_record->>'function_name');
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 辅助函数：计算资料完整度
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_profile_completion(profile_data JSONB)
RETURNS FLOAT AS $$
DECLARE
    completed_fields INT := 0;
    total_fields INT := 20;  -- 总共 20 个重要字段
BEGIN
    -- Core Identity (5 个字段)
    IF (profile_data->'core_identity'->>'name') IS NOT NULL AND 
       (profile_data->'core_identity'->>'name') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'core_identity'->>'bio') IS NOT NULL AND
       (profile_data->'core_identity'->>'bio') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'core_identity'->>'location') IS NOT NULL AND
       (profile_data->'core_identity'->>'location') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'core_identity'->>'pronouns') IS NOT NULL THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'core_identity'->>'time_zone') IS NOT NULL THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- Professional Background (7 个字段)
    IF (profile_data->'professional_background'->>'job_title') IS NOT NULL AND
       (profile_data->'professional_background'->>'job_title') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'professional_background'->>'current_company') IS NOT NULL AND
       (profile_data->'professional_background'->>'current_company') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'professional_background'->>'industry') IS NOT NULL AND
       (profile_data->'professional_background'->>'industry') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF (profile_data->'professional_background'->>'education') IS NOT NULL AND
       (profile_data->'professional_background'->>'education') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'skills', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'languages_spoken', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'professional_background'->'work_experiences', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- Personality & Social (3 个字段)
    IF (profile_data->'personality_social'->>'self_introduction') IS NOT NULL AND
       (profile_data->'personality_social'->>'self_introduction') != '' THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'personality_social'->'hobbies', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'personality_social'->'values_tags', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- Networking Intention (2 个字段)
    IF (profile_data->'networking_intention'->>'selected_intention') IS NOT NULL THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    IF jsonb_array_length(COALESCE(profile_data->'networking_intention'->'selected_sub_intentions', '[]'::jsonb)) > 0 THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- Networking Preferences (2 个字段)
    IF (profile_data->'networking_preferences'->>'preferred_chat_format') IS NOT NULL THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- Available timeslot 总是有值，不检查
    
    IF (profile_data->'professional_background'->>'years_of_experience') IS NOT NULL THEN
        completed_fields := completed_fields + 1;
    END IF;
    
    -- 计算完成度百分比
    RETURN completed_fields::FLOAT / total_fields::FLOAT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 主触发器函数：同步用户特征
-- ============================================================
CREATE OR REPLACE FUNCTION sync_user_features()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_features (
        user_id,
        location,
        time_zone,
        industry,
        experience_level,
        career_stage,
        main_intention,
        skills,
        hobbies,
        values,
        languages,
        sub_intentions,
        skills_to_learn,
        skills_to_teach,
        functions_to_learn,
        functions_to_teach,
        years_of_experience,
        profile_completion,
        is_verified
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
        calculate_profile_completion(
            jsonb_build_object(
                'core_identity', NEW.core_identity,
                'professional_background', NEW.professional_background,
                'personality_social', NEW.personality_social,
                'networking_intention', NEW.networking_intention,
                'networking_preferences', NEW.networking_preferences,
                'privacy_trust', NEW.privacy_trust
            )
        ),
        CASE 
            WHEN NEW.privacy_trust->'verified_status' = '"verified_professional"' THEN 1 
            WHEN NEW.privacy_trust->'verified_status' = '"verified"' THEN 1 
            ELSE 0 
        END
    )
    ON CONFLICT (user_id) DO UPDATE
    SET
        location = EXCLUDED.location,
        time_zone = EXCLUDED.time_zone,
        industry = EXCLUDED.industry,
        experience_level = EXCLUDED.experience_level,
        career_stage = EXCLUDED.career_stage,
        main_intention = EXCLUDED.main_intention,
        skills = EXCLUDED.skills,
        hobbies = EXCLUDED.hobbies,
        values = EXCLUDED.values,
        languages = EXCLUDED.languages,
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
-- 创建触发器
-- ============================================================
DROP TRIGGER IF EXISTS trigger_sync_user_features ON profiles;

CREATE TRIGGER trigger_sync_user_features
    AFTER INSERT OR UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION sync_user_features();

-- 完成提示
DO $$
BEGIN
    RAISE NOTICE '✅ User features sync functions and trigger created successfully';
    RAISE NOTICE '   Trigger: trigger_sync_user_features on table: profiles';
    RAISE NOTICE '   Functions: extract_skills_from_development, extract_functions_from_direction, calculate_profile_completion, sync_user_features';
END $$;

