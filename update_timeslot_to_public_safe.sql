-- ============================================
-- 安全更新脚本：将 profiles 表中所有记录的 
-- privacy_trust.visibility_settings.timeslot 更新为 "public"
-- ============================================

-- 步骤 1: 查看更新前的数据（可选，用于验证）
-- SELECT 
--     user_id,
--     privacy_trust->'visibility_settings'->>'timeslot' as current_timeslot,
--     privacy_trust->'visibility_settings' as current_visibility_settings
-- FROM profiles
-- WHERE privacy_trust IS NOT NULL
-- ORDER BY user_id
-- LIMIT 10;

-- 步骤 2: 备份当前数据（建议先执行）
-- CREATE TABLE profiles_backup_timeslot AS 
-- SELECT * FROM profiles;

-- 步骤 3: 更新已有 visibility_settings 的记录
UPDATE profiles
SET privacy_trust = jsonb_set(
    privacy_trust,
    '{visibility_settings,timeslot}',
    '"public"',
    true
)
WHERE privacy_trust IS NOT NULL
  AND privacy_trust ? 'visibility_settings'
  AND (
    privacy_trust->'visibility_settings'->>'timeslot' IS NULL
    OR privacy_trust->'visibility_settings'->>'timeslot' != 'public'
  );

-- 步骤 4: 为没有 visibility_settings 的记录添加它
UPDATE profiles
SET privacy_trust = jsonb_set(
    COALESCE(privacy_trust, '{}'::jsonb),
    '{visibility_settings}',
    COALESCE(privacy_trust->'visibility_settings', '{}'::jsonb) || 
    jsonb_build_object(
        'timeslot', 'public',
        'company', COALESCE(privacy_trust->'visibility_settings'->>'company', 'public'),
        'email', COALESCE(privacy_trust->'visibility_settings'->>'email', 'public'),
        'phone_number', COALESCE(privacy_trust->'visibility_settings'->>'phone_number', 'public'),
        'location', COALESCE(privacy_trust->'visibility_settings'->>'location', 'public'),
        'skills', COALESCE(privacy_trust->'visibility_settings'->>'skills', 'public'),
        'interests', COALESCE(privacy_trust->'visibility_settings'->>'interests', 'public')
    ),
    true
)
WHERE privacy_trust IS NOT NULL
  AND NOT (privacy_trust ? 'visibility_settings');

-- 步骤 5: 验证更新结果
SELECT 
    COUNT(*) as total_profiles,
    COUNT(CASE WHEN privacy_trust->'visibility_settings'->>'timeslot' = 'public' THEN 1 END) as public_timeslot_count,
    COUNT(CASE WHEN privacy_trust->'visibility_settings'->>'timeslot' != 'public' OR privacy_trust->'visibility_settings'->>'timeslot' IS NULL THEN 1 END) as non_public_timeslot_count
FROM profiles
WHERE privacy_trust IS NOT NULL;

-- 步骤 6: 查看更新后的示例数据（可选）
-- SELECT 
--     user_id,
--     privacy_trust->'visibility_settings'->>'timeslot' as timeslot_value,
--     privacy_trust->'visibility_settings' as visibility_settings
-- FROM profiles
-- WHERE privacy_trust IS NOT NULL
-- ORDER BY user_id
-- LIMIT 10;

-- ============================================
-- 如果需要回滚，可以使用备份表：
-- DROP TABLE IF EXISTS profiles;
-- ALTER TABLE profiles_backup_timeslot RENAME TO profiles;
-- ============================================

