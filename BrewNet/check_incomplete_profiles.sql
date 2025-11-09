-- 检查 profiles 表中不完整的数据
-- 这个脚本帮助诊断"The data couldn't be read because it is missing"错误

-- 1. 检查是否有缺失必需字段的 profiles
SELECT 
    id,
    user_id,
    CASE 
        WHEN core_identity IS NULL THEN 'Missing core_identity'
        WHEN professional_background IS NULL THEN 'Missing professional_background'
        WHEN networking_intention IS NULL THEN 'Missing networking_intention'
        WHEN networking_preferences IS NULL THEN 'Missing networking_preferences'
        WHEN personality_social IS NULL THEN 'Missing personality_social'
        WHEN privacy_trust IS NULL THEN 'Missing privacy_trust'
        ELSE 'OK'
    END as status
FROM profiles
WHERE 
    core_identity IS NULL 
    OR professional_background IS NULL
    OR networking_intention IS NULL
    OR networking_preferences IS NULL
    OR personality_social IS NULL
    OR privacy_trust IS NULL;

-- 2. 检查 core_identity 中是否缺少必需字段
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    core_identity->>'email' as email
FROM profiles
WHERE 
    core_identity->>'name' IS NULL 
    OR core_identity->>'name' = ''
    OR core_identity->>'email' IS NULL 
    OR core_identity->>'email' = '';

-- 3. 检查所有 profiles 的完整性统计
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN core_identity IS NULL THEN 1 END) as missing_core_identity,
    COUNT(CASE WHEN professional_background IS NULL THEN 1 END) as missing_professional_background,
    COUNT(CASE WHEN networking_intention IS NULL THEN 1 END) as missing_networking_intention,
    COUNT(CASE WHEN networking_preferences IS NULL THEN 1 END) as missing_networking_preferences,
    COUNT(CASE WHEN personality_social IS NULL THEN 1 END) as missing_personality_social,
    COUNT(CASE WHEN privacy_trust IS NULL THEN 1 END) as missing_privacy_trust,
    COUNT(CASE WHEN work_photos IS NULL THEN 1 END) as missing_work_photos,
    COUNT(CASE WHEN lifestyle_photos IS NULL THEN 1 END) as missing_lifestyle_photos
FROM profiles;

-- 4. 显示前10个完整的 profiles（用于对比）
SELECT 
    id,
    user_id,
    core_identity->>'name' as name,
    CASE 
        WHEN core_identity IS NOT NULL 
         AND professional_background IS NOT NULL 
         AND networking_intention IS NOT NULL 
         AND networking_preferences IS NOT NULL 
         AND personality_social IS NOT NULL 
         AND privacy_trust IS NOT NULL 
        THEN 'Complete'
        ELSE 'Incomplete'
    END as completeness
FROM profiles
ORDER BY created_at DESC
LIMIT 10;

-- 5. 检查是否有重复的 user_id
SELECT 
    user_id,
    COUNT(*) as profile_count
FROM profiles
GROUP BY user_id
HAVING COUNT(*) > 1;

