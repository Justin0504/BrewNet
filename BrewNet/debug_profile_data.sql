-- 完整的Profile数据完整性检查
-- 用于诊断 "Some profile data is incomplete" 错误

-- 1. 检查所有必需字段是否存在
SELECT 
    user_id,
    CASE 
        WHEN core_identity IS NULL THEN 'core_identity缺失'
        WHEN professional_background IS NULL THEN 'professional_background缺失'
        WHEN networking_intention IS NULL THEN 'networking_intention缺失'
        WHEN networking_preferences IS NULL THEN 'networking_preferences缺失'
        WHEN personality_social IS NULL THEN 'personality_social缺失'
        WHEN privacy_trust IS NULL THEN 'privacy_trust缺失'
        ELSE 'OK'
    END AS status,
    core_identity->'name' as name,
    core_identity->'email' as email
FROM profiles
WHERE 
    core_identity IS NULL 
    OR professional_background IS NULL 
    OR networking_intention IS NULL 
    OR networking_preferences IS NULL
    OR personality_social IS NULL
    OR privacy_trust IS NULL;

-- 2. 检查core_identity中的必需字段
SELECT 
    user_id,
    core_identity->'name' as name,
    core_identity->'email' as email,
    core_identity->'time_zone' as time_zone,
    CASE 
        WHEN core_identity->>'name' IS NULL OR core_identity->>'name' = '' THEN 'name缺失'
        WHEN core_identity->>'email' IS NULL OR core_identity->>'email' = '' THEN 'email缺失'
        WHEN core_identity->>'time_zone' IS NULL OR core_identity->>'time_zone' = '' THEN 'time_zone缺失'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    core_identity->>'name' IS NULL OR core_identity->>'name' = ''
    OR core_identity->>'email' IS NULL OR core_identity->>'email' = ''
    OR core_identity->>'time_zone' IS NULL OR core_identity->>'time_zone' = '';

-- 3. 检查professional_background中的必需字段
SELECT 
    user_id,
    core_identity->'name' as name,
    professional_background->'experience_level' as experience_level,
    professional_background->'career_stage' as career_stage,
    professional_background->'skills' as skills,
    CASE 
        WHEN professional_background->>'experience_level' IS NULL THEN 'experience_level缺失'
        WHEN professional_background->>'career_stage' IS NULL THEN 'career_stage缺失'
        WHEN professional_background->'skills' IS NULL THEN 'skills缺失(null)'
        WHEN jsonb_array_length(professional_background->'skills') = 0 THEN 'skills为空数组'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    professional_background->>'experience_level' IS NULL
    OR professional_background->>'career_stage' IS NULL
    OR professional_background->'skills' IS NULL
    OR (professional_background->'skills' IS NOT NULL AND jsonb_array_length(professional_background->'skills') = 0);

-- 4. 检查networking_intention中的必需字段
SELECT 
    user_id,
    core_identity->'name' as name,
    networking_intention->'selected_intention' as selected_intention,
    networking_intention->'selected_sub_intentions' as selected_sub_intentions,
    CASE 
        WHEN networking_intention->>'selected_intention' IS NULL THEN 'selected_intention缺失'
        WHEN networking_intention->'selected_sub_intentions' IS NULL THEN 'selected_sub_intentions缺失(null)'
        WHEN jsonb_array_length(networking_intention->'selected_sub_intentions') = 0 THEN 'selected_sub_intentions为空数组'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    networking_intention->>'selected_intention' IS NULL
    OR networking_intention->'selected_sub_intentions' IS NULL
    OR (networking_intention->'selected_sub_intentions' IS NOT NULL AND jsonb_array_length(networking_intention->'selected_sub_intentions') = 0);

-- 5. 检查networking_preferences中的必需字段（包括available_timeslot）
SELECT 
    user_id,
    core_identity->'name' as name,
    networking_preferences->'preferred_chat_format' as preferred_chat_format,
    networking_preferences->'available_timeslot' as available_timeslot,
    CASE 
        WHEN networking_preferences->>'preferred_chat_format' IS NULL THEN 'preferred_chat_format缺失'
        WHEN networking_preferences->'available_timeslot' IS NULL THEN 'available_timeslot缺失'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    networking_preferences->>'preferred_chat_format' IS NULL
    OR networking_preferences->'available_timeslot' IS NULL;

-- 6. 检查personality_social中的必需字段
SELECT 
    user_id,
    core_identity->'name' as name,
    personality_social->'icebreaker_prompts' as icebreaker_prompts,
    personality_social->'values_tags' as values_tags,
    personality_social->'hobbies' as hobbies,
    personality_social->'preferred_meeting_vibe' as preferred_meeting_vibe,
    CASE 
        WHEN personality_social->'icebreaker_prompts' IS NULL THEN 'icebreaker_prompts缺失'
        WHEN personality_social->'values_tags' IS NULL THEN 'values_tags缺失'
        WHEN personality_social->'hobbies' IS NULL THEN 'hobbies缺失'
        WHEN personality_social->>'preferred_meeting_vibe' IS NULL THEN 'preferred_meeting_vibe缺失'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    personality_social->'icebreaker_prompts' IS NULL
    OR personality_social->'values_tags' IS NULL
    OR personality_social->'hobbies' IS NULL
    OR personality_social->>'preferred_meeting_vibe' IS NULL;

-- 7. 检查privacy_trust中的必需字段
SELECT 
    user_id,
    core_identity->'name' as name,
    privacy_trust->'visibility_settings' as visibility_settings,
    privacy_trust->'verified_status' as verified_status,
    privacy_trust->'data_sharing_consent' as data_sharing_consent,
    privacy_trust->'report_preferences' as report_preferences,
    CASE 
        WHEN privacy_trust->'visibility_settings' IS NULL THEN 'visibility_settings缺失'
        WHEN privacy_trust->>'verified_status' IS NULL THEN 'verified_status缺失'
        WHEN privacy_trust->'data_sharing_consent' IS NULL THEN 'data_sharing_consent缺失'
        WHEN privacy_trust->'report_preferences' IS NULL THEN 'report_preferences缺失'
        ELSE 'OK'
    END AS status
FROM profiles
WHERE 
    privacy_trust->'visibility_settings' IS NULL
    OR privacy_trust->>'verified_status' IS NULL
    OR privacy_trust->'data_sharing_consent' IS NULL
    OR privacy_trust->'report_preferences' IS NULL;

-- 8. 统计总体情况
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN core_identity IS NULL THEN 1 END) as missing_core_identity,
    COUNT(CASE WHEN professional_background IS NULL THEN 1 END) as missing_professional_background,
    COUNT(CASE WHEN networking_intention IS NULL THEN 1 END) as missing_networking_intention,
    COUNT(CASE WHEN networking_preferences IS NULL THEN 1 END) as missing_networking_preferences,
    COUNT(CASE WHEN personality_social IS NULL THEN 1 END) as missing_personality_social,
    COUNT(CASE WHEN privacy_trust IS NULL THEN 1 END) as missing_privacy_trust,
    COUNT(CASE WHEN 
        core_identity IS NOT NULL 
        AND professional_background IS NOT NULL 
        AND networking_intention IS NOT NULL 
        AND networking_preferences IS NOT NULL
        AND personality_social IS NOT NULL
        AND privacy_trust IS NOT NULL
    THEN 1 END) as complete_profiles
FROM profiles;

-- 9. 列出前10个不完整的profile详细信息
SELECT 
    user_id,
    core_identity->'name' as name,
    core_identity->'email' as email,
    created_at,
    updated_at,
    CASE WHEN core_identity IS NULL THEN '❌' ELSE '✅' END as has_core_identity,
    CASE WHEN professional_background IS NULL THEN '❌' ELSE '✅' END as has_professional_bg,
    CASE WHEN networking_intention IS NULL THEN '❌' ELSE '✅' END as has_networking_intention,
    CASE WHEN networking_preferences IS NULL THEN '❌' ELSE '✅' END as has_networking_prefs,
    CASE WHEN personality_social IS NULL THEN '❌' ELSE '✅' END as has_personality_social,
    CASE WHEN privacy_trust IS NULL THEN '❌' ELSE '✅' END as has_privacy_trust
FROM profiles
WHERE 
    core_identity IS NULL 
    OR professional_background IS NULL 
    OR networking_intention IS NULL 
    OR networking_preferences IS NULL
    OR personality_social IS NULL
    OR privacy_trust IS NULL
ORDER BY updated_at DESC
LIMIT 10;

-- 10. 检查是否有旧版available_timeslot在core_identity中（应该在networking_preferences中）
SELECT 
    user_id,
    core_identity->'name' as name,
    'available_timeslot在core_identity中（错误位置）' as issue
FROM profiles
WHERE core_identity ? 'available_timeslot';

